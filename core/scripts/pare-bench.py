#!/usr/bin/env python3
"""pare-bench.py - paired headless benchmark for a /pare pass.

Runs the same fixed agent tasks on the code before a pare pass (pre), after it
(post), and on pre again (noise, the noise floor). Sides are interleaved and
rotated per round (hyperfine-style paired design) to cancel drift. Each good
run is handed to pare-ledger.py's `bench` subcommand as one v1 JSON object.

Tasks file (--tasks), JSON with 3 to 5 tasks:
  {"tasks": [{"id": "<slug>", "prompt": "<text>", "check": "<bash cmd>" | null}]}
A check judges the ANSWER, not the tree: it runs under bash in a fresh empty
temp dir (never the worktree or repo), gets the agent's final answer text on
stdin, is not told the side (PARE_BENCH_SIDE is unset), has a 120 s timeout and
is killed as a process group. Exit 0 = passed. It must not touch git or the
repo. null means no check (passed is recorded as null).

--pass-ts must equal the ts of the pare-ledger run record being credited; it is
validated (YYYY-MM-DDTHH:MM:SSZ, a real date) before any work. --repo is stored
as its realpath.

Each run is `claude -p <prompt> --output-format json --tools Read,Grep,Glob
--permission-mode dontAsk --permission-prompts none --safe-mode
--no-session-persistence --strict-mcp-config --mcp-config '{"mcpServers":{}}'
--disallowedTools 'mcp__*' [--model <m>]` in a worktree. Confinement:
  --tools Read,Grep,Glob       read-only built-in toolset
  --permission-mode            dontAsk (default); env PARE_BENCH_PERMISSION_MODE
                               may set only dontAsk or plan, else exit 2
  --permission-prompts none    never ask
  --safe-mode                  no hooks, CLAUDE.md, skills or plugins
  --no-session-persistence     no session transcripts
  --strict-mcp-config + empty --mcp-config + --disallowedTools 'mcp__*'
                               no MCP servers or tools
Binary overridable with env PARE_BENCH_CLAUDE. Three worktrees (pre, post, and
a separate noise tree at the pre commit) are reset (checkout -f, clean -fdx)
after every run. Agents and checks run in their own process group (killed on
timeout, exit or SIGTERM/SIGHUP/SIGINT); stale pare-bench-* worktrees from
earlier runs are removed at start.

Exit codes: 0 ok, 2 bad input, 3 ledger writer failed, 4 too few good runs.
stderr carries counts and reasons only, never prompt text or model output.
"""
import argparse
import fcntl
import importlib.util
import json
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("pare_ledger", os.path.join(HERE, "pare-ledger.py"))
_ledger = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_ledger)
SHA_RE, SLUG_RE, parse_ts, SIDES = _ledger.SHA_RE, _ledger.SLUG_RE, _ledger.parse_ts, _ledger.SIDES

PREFIX = "pare-bench-"
MIN_GOOD = 3
CHECK_TIMEOUT = 120
PERMISSION_MODES = ("dontAsk", "plan")


def die(code, msg):
    print("pare-bench: " + msg, file=sys.stderr)
    sys.exit(code)


def now_iso():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _on_signal(signum, _frame):
    sys.exit(128 + signum)


def load_tasks(path):
    try:
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, ValueError):
        die(2, "tasks file unreadable or not JSON")
    tasks = data.get("tasks") if isinstance(data, dict) else None
    if not isinstance(tasks, list) or not 3 <= len(tasks) <= 5:
        die(2, "tasks file needs a 'tasks' list of 3 to 5 entries")
    seen = set()
    for i, t in enumerate(tasks):
        if not isinstance(t, dict):
            die(2, "task %d is not an object" % i)
        tid, prompt, check = t.get("id"), t.get("prompt"), t.get("check")
        if not isinstance(tid, str) or not SLUG_RE.fullmatch(tid):
            die(2, "task %d has an invalid id" % i)
        if tid in seen:
            die(2, "duplicate task id: " + tid)
        seen.add(tid)
        if not isinstance(prompt, str) or not prompt.strip():
            die(2, "task %s needs a non-empty prompt" % tid)
        if check is not None and (not isinstance(check, str) or not check.strip()):
            die(2, "task %s check must be a command string or null" % tid)
    return tasks


def git(repo, *args):
    return subprocess.run(["git", "-C", repo] + list(args), capture_output=True, text=True)


def resolve_commit(repo, ref):
    r = git(repo, "rev-parse", "--verify", "--quiet", ref + "^{commit}")
    sha = r.stdout.strip()
    if r.returncode != 0 or not SHA_RE.fullmatch(sha):
        die(2, "cannot resolve commit for " + "".join(c if c.isalnum() or c in "._-" else "?" for c in ref)[:60])
    return sha


def plan(tasks, runs):
    out = []
    for r in range(1, runs + 1):
        off = (r - 1) % len(SIDES)
        order = SIDES[off:] + SIDES[:off]
        for t in tasks:
            for side in order:
                out.append((r, t["id"], side))
    return out


def ledger_cmd():
    w = os.environ.get("PARE_LEDGER_WRITER") or os.path.join(HERE, "pare-ledger.py")
    return [sys.executable, "-I", w, "bench"]


def write_record(rec):
    p = subprocess.run(ledger_cmd(), input=json.dumps(rec), capture_output=True, text=True)
    if p.returncode != 0:
        die(3, "ledger writer exited %d; stopping" % p.returncode)


def nonneg_int(v, required=False):
    if v is None:
        if required:
            raise ValueError
        return 0
    if isinstance(v, bool) or not isinstance(v, int) or v < 0:
        raise ValueError
    return v


def kill_group(pid):
    try:
        os.killpg(pid, signal.SIGKILL)
    except (ProcessLookupError, PermissionError):
        pass


def run_group(cmd, cwd, timeout, stdin_text=None, env=None):
    """Run cmd in its own session; kill the whole group on timeout, error or exit.

    Returns (returncode, stdout). Raises subprocess.TimeoutExpired or OSError.
    """
    p = subprocess.Popen(cmd, cwd=cwd, env=env, text=True, start_new_session=True,
                         stdin=subprocess.PIPE if stdin_text is not None else subprocess.DEVNULL,
                         stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    try:
        out, _ = p.communicate(input=stdin_text, timeout=timeout)
        return p.returncode, out
    finally:
        kill_group(p.pid)
        try:
            p.communicate(timeout=5)
        except (subprocess.TimeoutExpired, ValueError, OSError):
            pass


def run_agent(claude, prompt, cwd, timeout, model=None, permission_mode="dontAsk"):
    """Return (usage dict, session, result text) or raise RuntimeError with a short reason."""
    cmd = [claude, "-p", prompt, "--output-format", "json",
           "--tools", "Read,Grep,Glob",
           "--permission-mode", permission_mode,
           "--permission-prompts", "none",
           "--safe-mode", "--no-session-persistence",
           "--strict-mcp-config", "--mcp-config", '{"mcpServers":{}}',
           "--disallowedTools", "mcp__*"]
    if model:
        cmd += ["--model", model]
    try:
        rc, out = run_group(cmd, cwd, timeout)
    except subprocess.TimeoutExpired:
        raise RuntimeError("agent timeout")
    except OSError:
        raise RuntimeError("agent binary not runnable")
    if rc != 0:
        raise RuntimeError("agent exit %d" % rc)
    try:
        doc = json.loads(out)
    except ValueError:
        raise RuntimeError("agent output not JSON")
    if not isinstance(doc, dict) or doc.get("is_error") is True:
        raise RuntimeError("agent reported error or unexpected shape")
    u = doc.get("usage")
    if not isinstance(u, dict):
        raise RuntimeError("usage missing")
    try:
        usage = {
            "input_tokens": nonneg_int(u.get("input_tokens"), True),
            "output_tokens": nonneg_int(u.get("output_tokens"), True),
            "cache_creation_tokens": nonneg_int(u.get("cache_creation_input_tokens")),
            "cache_read_tokens": nonneg_int(u.get("cache_read_input_tokens")),
        }
    except ValueError:
        raise RuntimeError("usage fields missing or malformed")
    sid = doc.get("session_id")
    res = doc.get("result")
    return usage, sid if isinstance(sid, str) and sid else None, res if isinstance(res, str) else ""


def run_check(check, answer, scratch):
    """Judge the answer: bash in a fresh empty dir, answer on stdin, side unknown."""
    d = tempfile.mkdtemp(prefix="chk-", dir=scratch)
    env = {k: v for k, v in os.environ.items() if k != "PARE_BENCH_SIDE"}
    env["GIT_CEILING_DIRECTORIES"] = d
    try:
        rc, _ = run_group(["bash", "-c", check], d, CHECK_TIMEOUT, stdin_text=answer, env=env)
        return rc == 0
    except (subprocess.TimeoutExpired, OSError):
        return False
    finally:
        shutil.rmtree(d, ignore_errors=True)


def reset_tree(path, sha):
    git(path, "checkout", "-f", "--detach", sha)
    git(path, "clean", "-fdx")


def clean_stale(repo):
    """Remove worktrees left by an earlier killed run (own temp prefix only)."""
    tmproot = os.path.realpath(tempfile.gettempdir())
    r = git(repo, "worktree", "list", "--porcelain")
    for line in r.stdout.splitlines():
        if not line.startswith("worktree "):
            continue
        path = line[len("worktree "):]
        parent = os.path.dirname(path)
        if os.path.basename(parent).startswith(PREFIX) and \
                os.path.realpath(os.path.dirname(parent)) == tmproot:
            git(repo, "worktree", "remove", "--force", path)
            shutil.rmtree(parent, ignore_errors=True)
    git(repo, "worktree", "prune")


def take_lock(repo):
    """Exclusive per-repo lock so a second run cannot reap a live run's worktrees."""
    r = git(repo, "rev-parse", "--git-common-dir")
    if r.returncode != 0 or not r.stdout.strip():
        die(2, "cannot resolve git common dir")
    cdir = os.path.join(repo, r.stdout.strip())
    try:
        fd = os.open(os.path.join(cdir, "pare-bench.lock"),
                     os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    except OSError:
        die(2, "cannot open the repo lock file")
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        os.close(fd)
        die(2, "another pare-bench run holds this repo")
    return fd


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--repo", required=True)
    ap.add_argument("--tasks", required=True)
    ap.add_argument("--pre", required=True)
    ap.add_argument("--post", required=True)
    ap.add_argument("--pass-ts", required=True)
    ap.add_argument("--runs", type=int, default=3)
    ap.add_argument("--timeout", type=int, default=900)
    ap.add_argument("--model", default=None)
    ap.add_argument("--dry-run", action="store_true")
    try:
        a = ap.parse_args()
    except SystemExit as e:
        sys.exit(2 if e.code else 0)

    perm = os.environ.get("PARE_BENCH_PERMISSION_MODE", "dontAsk")
    if perm not in PERMISSION_MODES:
        die(2, "PARE_BENCH_PERMISSION_MODE must be one of: " + ", ".join(PERMISSION_MODES))
    if a.runs < MIN_GOOD:
        die(2, "--runs must be at least %d" % MIN_GOOD)
    if a.timeout < 1:
        die(2, "--timeout must be positive")
    if not os.path.isabs(a.repo) or not os.path.isdir(a.repo):
        die(2, "--repo must be an absolute directory")
    a.repo = os.path.realpath(a.repo)
    if git(a.repo, "rev-parse", "--git-dir").returncode != 0:
        die(2, "--repo is not a git repository")
    if parse_ts(a.pass_ts) is None:
        die(2, "--pass-ts must be a real UTC time like YYYY-MM-DDTHH:MM:SSZ")
    tasks = load_tasks(a.tasks)
    pre_sha = resolve_commit(a.repo, a.pre)
    post_sha = resolve_commit(a.repo, a.post)
    steps = plan(tasks, a.runs)

    if a.dry_run:
        print("planned runs: %d (%d tasks x %d sides x %d rounds)"
              % (len(steps), len(tasks), len(SIDES), a.runs))
        for r, tid, side in steps:
            print("round %d %s %s" % (r, tid, side))
        return 0

    for sig in (signal.SIGTERM, signal.SIGHUP, signal.SIGINT):
        signal.signal(sig, _on_signal)
    claude = os.environ.get("PARE_BENCH_CLAUDE") or "claude"
    by_id = {t["id"]: t for t in tasks}
    good = {(t["id"], s): 0 for t in tasks for s in SIDES}
    failed = {}
    lock_fd = take_lock(a.repo)
    tmp = None
    added = []
    try:
        clean_stale(a.repo)
        tmp = tempfile.mkdtemp(prefix=PREFIX)
        trees = {}
        commits = {"pre": pre_sha, "post": post_sha, "noise": pre_sha}
        for side in ("pre", "post", "noise"):
            path = os.path.join(tmp, side)
            r = git(a.repo, "worktree", "add", "--detach", path, commits[side])
            if r.returncode != 0:
                die(2, "could not create %s worktree" % side)
            added.append(path)
            trees[side] = path

        for r, tid, side in steps:
            t = by_id[tid]
            cwd = trees[side]
            t0 = time.monotonic()
            try:
                try:
                    usage, sid, answer = run_agent(claude, t["prompt"], cwd, a.timeout,
                                                   a.model, perm)
                finally:
                    reset_tree(cwd, commits[side])
            except RuntimeError as e:
                failed[(tid, side)] = failed.get((tid, side), 0) + 1
                print("pare-bench: run failed task=%s side=%s run=%d: %s"
                      % (tid, side, r, e), file=sys.stderr)
                continue
            seconds = int(round(time.monotonic() - t0))
            passed = run_check(t["check"], answer, tmp) if t.get("check") else None
            rec = {"v": 1, "ts": now_iso(), "repo": a.repo, "pass_ts": a.pass_ts,
                   "side": side, "commit": commits[side], "task": tid, "run": r}
            rec.update(usage)
            rec.update({"passed": passed, "seconds": seconds, "session": sid})
            write_record(rec)
            good[(tid, side)] += 1
    finally:
        for path in added:
            git(a.repo, "worktree", "remove", "--force", path)
        git(a.repo, "worktree", "prune")
        if tmp:
            shutil.rmtree(tmp, ignore_errors=True)
        os.close(lock_fd)

    short = sorted("%s/%s=%d" % (k[0], k[1], v) for k, v in good.items() if v < MIN_GOOD)
    nfail = sum(failed.values())
    print("pare-bench: %d good runs, %d failed" % (sum(good.values()), nfail), file=sys.stderr)
    if short:
        print("pare-bench: fewer than %d good runs: %s" % (MIN_GOOD, ", ".join(short)),
              file=sys.stderr)
        return 4
    return 0


if __name__ == "__main__":
    sys.exit(main())
