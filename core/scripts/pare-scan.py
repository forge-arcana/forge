#!/usr/bin/env python3
"""pare-scan: what is the pare pass (dead-code removal) delivering, per project
and month? Reads (read-only) the pass run ledger, the bench ledger, the project
allow-list, the session transcripts and each repo's git history; writes one
anonymous JSON snapshot of count tables.

Inputs
  runs ledger the path pare-ledger.py resolves (FORGE_PARE_LEDGER, absolute, or
              the default under XDG_STATE_HOME); the bench ledger is bench.jsonl
              beside it. Paths, field schemas and constants come from pare-ledger.py
              (imported from this directory); every ledger line is checked with its
              validate_run / validate_bench and an invalid line is a bad line.
              A missing file reads as empty; an unreadable path is an error (exit 2).
              FORGE_PARE_LEDGER=off: no ledger is read, no snapshot is written (the
              tables are empty; print and --json still work) and stderr says so.
              A relative FORGE_PARE_LEDGER is an error (exit 2); nothing is ever
              written relative to the working directory.
  allow-list  ${FORGE_PARE_PROJECTS:-${XDG_CONFIG_HOME:-$HOME/.config}/forge/pare/projects.json}
              {"<abs repo path>": "<slug>"}; records for an unlisted repo are left
              out of every table and counted (count only) on stderr. A missing or
              unusable allow-list leaves everything out (exit 0, a stderr note).
  transcripts ${FORGE_MEMBRANE:-$HOME/.claude}/projects/**/*.jsonl (recursive);
              a missing projects directory is an error (exit 2), not "no usage"
  git         `git -C <repo>` read-only (GIT_LITERAL_PATHSPECS=1), regret check
Output
  {"v":1,"asof":...,"tables":{"months","measures","bench","passes"}}; printed
  with --json, written atomically (mode 600) to <ledger dir>/snapshot.json
  unless --no-write. stderr carries counts and reasons only, never a path or
  file name. Rows are sorted by key, every column is in every row, every
  value is an int or a key string, never null (a reading not taken is a missing
  row or a 0 in a counted column). No repo path, session id, commit, advisory
  id, task id, tool name, verdict, rate or money is ever written.

Method and limits
  Month and day are Europe/London of the run's ts (a bench record's own ts for
  bench_tokens; a session's first matching record for sessions).
  pass_tokens: input + output + cache_creation + cache_read tokens of assistant
  turns of the run's session inside [started_at, ts], one turn per message id +
  requestId (max per field across streamed records and across transcripts,
  subagent transcripts included).
  months: for each project, a row for every month from its first pass month
  through the current London month (of --now) that has a pass, a bench record or
  at least one session; sessions and bench_tokens fill those months too (all
  sessions in the allow-listed repo count; bench runs keep no transcripts).
  Regret (REGRET_DAYS after the run's ts, repo HEAD): a removed file is regretted
  when a commit in commit_after..HEAD inside the window adds a file at that path;
  a removed export when such a commit adds, in that module, a line that DECLARES
  the name (optional export/default/async, then def, class, function, const, let,
  var, type, interface or enum, then the name); a call site does not count.
  Pathspecs are literal and textconv/ext-diff are off. Needs commit_after
  reachable from HEAD and a readable repo; otherwise the run is "not read"
  (regret_read excludes it). regret_items_checked counts the removed files and
  exports of the runs whose regret was read.
  measures: per (project, month, measure), before and after are sums over that
  month's runs with outcome "completed", counting only runs where both the
  before and the after value are non-null (same-run pairs); a row exists only
  when at least one run counts.
  advisories_removed is the length of the run's top-level advisory_ids_removed.
  Commit time filtering is done on the committer date, in this script, which is
  the same rule as git's --since/--until without its ordering quirks.
  bench: groups of bench records by (repo, pass_ts); emitted only when every
  task has >= BENCH_MIN_RUNS runs on each of pre, post and noise. Medians and
  means are exact fractions rounded half up. When several groups share a
  (project, pass_month, run_month) key only the one with the latest pass_ts is
  kept; the dropped groups are counted on stderr. tasks_checked is the number of
  tasks in which every run on every side has a non-null passed.
Python 3 stdlib only.
"""
import argparse
import datetime as dt
import importlib.util
import json
import math
import os
import re
import subprocess
import sys
import tempfile
from fractions import Fraction
from zoneinfo import ZoneInfo


def _load_ledger():
    here = os.path.dirname(os.path.realpath(__file__))
    spec = importlib.util.spec_from_file_location("pare_ledger", os.path.join(here, "pare-ledger.py"))
    mod = importlib.util.module_from_spec(spec)
    sys.dont_write_bytecode = True
    spec.loader.exec_module(mod)
    return mod


L = _load_ledger()
SIDES = L.SIDES

LONDON = ZoneInfo("Europe/London")
REGRET_DAYS = 30        # window after a pass in which a re-added removal is regretted
BENCH_MIN_RUNS = 3      # runs per task per side for a bench group to count
GIT_TIMEOUT = 30        # seconds per git call
MEASURES = list(L.METRIC_KEYS)
USAGE_FIELDS = ["input_tokens", "output_tokens", "cache_creation_input_tokens",
                "cache_read_input_tokens"]
BENCH_FIELDS = ["input_tokens", "output_tokens", "cache_creation_tokens", "cache_read_tokens"]
DECL_KW = r"(def|class|function|const|let|var|type|interface|enum)"
MONTH_COLS = ["passes", "proven_kept", "proven_reverted", "judgement_kept",
              "judgement_reverted", "reverts", "cuts_kept", "cuts_regretted",
              "regret_read", "regret_items_checked", "guard_trips", "lines_removed",
              "files_removed", "exports_removed", "packages_removed",
              "advisories_removed", "pass_tokens", "pass_cost_read", "bench_tokens",
              "sessions", "window_closed"]


# ---------------------------------------------------------------- pure helpers

def parse_iso(s):
    """Tolerant ISO time (transcripts, --now): epoch seconds or None."""
    if not isinstance(s, str):
        return None
    try:
        d = dt.datetime.fromisoformat(s.replace("Z", "+00:00"))
    except ValueError:
        return None
    if d.tzinfo is None:
        d = d.replace(tzinfo=dt.timezone.utc)
    return d.timestamp()


def epoch(s):
    """Ledger timestamp (strict, via pare-ledger) -> epoch seconds, or None."""
    d = L.parse_ts(s)
    return None if d is None else d.replace(tzinfo=dt.timezone.utc).timestamp()


def london_month(epoch):
    return dt.datetime.fromtimestamp(epoch, LONDON).strftime("%Y-%m")


def london_day(epoch):
    return dt.datetime.fromtimestamp(epoch, LONDON).strftime("%Y-%m-%d")


def _i(v):
    """Tolerant int: anything that is not a plain number reads as 0."""
    if isinstance(v, bool):
        return 0
    try:
        return int(v or 0)
    except (TypeError, ValueError, OverflowError):
        return 0


def _num(v):
    """int, or None when the value is missing or not a plain number."""
    if isinstance(v, bool) or v is None:
        return None
    try:
        return int(v)
    except (TypeError, ValueError, OverflowError):
        return None


def _d(v):
    return v if isinstance(v, dict) else {}


def norm_repo(p):
    if not isinstance(p, str) or not p:
        return None
    return p.rstrip("/") or "/"


def rnd(f):
    """Round a Fraction half up."""
    return int(math.floor(f + Fraction(1, 2)))


def median(vals):
    s = sorted(vals)
    n = len(s)
    if n % 2:
        return Fraction(s[n // 2])
    return Fraction(s[n // 2 - 1] + s[n // 2], 2)


def mean(vals):
    return sum((Fraction(v) for v in vals), Fraction(0)) / len(vals)


def advisories_removed(rec):
    v = rec.get("advisory_ids_removed")
    return len(v) if isinstance(v, list) else 0


def guard_tripped(rec):
    g = _d(rec.get("guards"))
    return int(g.get("tests_green_after") is False or bool(g.get("test_count_drop"))
               or bool(g.get("config_changed")))


# --------------------------------------------------------------------- inputs

def read_jsonl(path):
    """-> (dict records, bad line count). Missing file = empty; other errors raise."""
    recs, bad = [], 0
    try:
        fh = open(path, "r", encoding="utf-8", errors="replace")
    except FileNotFoundError:
        return recs, bad
    with fh:
        for raw in fh:
            raw = raw.strip()
            if not raw:
                continue
            try:
                rec = json.loads(raw)
            except ValueError:
                bad += 1
                continue
            if isinstance(rec, dict):
                recs.append(rec)
            else:
                bad += 1
    return recs, bad


def read_allow(path):
    """-> {normalised repo: slug}, note (str or None)."""
    try:
        with open(path, "r", encoding="utf-8") as fh:
            data = json.load(fh)
    except FileNotFoundError:
        return {}, "allow-list missing; every record left out"
    except (OSError, ValueError):
        return {}, "allow-list unreadable; every record left out"
    if not isinstance(data, dict):
        return {}, "allow-list is not an object; every record left out"
    out = {}
    for k, v in data.items():
        k = norm_repo(k)
        if k and isinstance(v, str) and L.SLUG_RE.match(v):
            out[k] = v
    return out, None


def allow_path():
    p = os.environ.get("FORGE_PARE_PROJECTS")
    if p:
        return p
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.join(os.path.expanduser("~"), ".config")
    return os.path.join(base, "forge/pare/projects.json")


def match_slug(cwd, allow):
    """Slug of the deepest allow-listed repo that is cwd or an ancestor of it."""
    p = cwd.rstrip("/") or "/"
    while True:
        if p in allow:
            return allow[p]
        parent = os.path.dirname(p)
        if parent == p or not parent:
            return None
        p = parent


def scan_transcripts(root, allow, want_sessions):
    """-> (turns by session, first record epoch per (session, slug)).
    turns[session] = {turn key: [ts, in, out, cc, cr]} with max per field."""
    turns, first = {}, {}
    uniq = 0
    for d, _dirs, files in os.walk(root, onerror=lambda _e: None):
        for f in sorted(files):
            if not f.endswith(".jsonl"):
                continue
            path = os.path.join(d, f)
            stem = os.path.splitext(f)[0]
            try:
                fh = open(path, "r", encoding="utf-8", errors="replace")
            except OSError:
                continue
            with fh:
                try:
                    for line in fh:
                        if '"cwd"' not in line and '"usage"' not in line:
                            continue
                        try:
                            rec = json.loads(line)
                        except ValueError:
                            continue
                        if not isinstance(rec, dict):
                            continue
                        ts = parse_iso(rec.get("timestamp"))
                        if ts is None:
                            continue
                        sess = rec.get("sessionId") or stem
                        cwd = rec.get("cwd")
                        if isinstance(cwd, str) and cwd:
                            slug = match_slug(cwd, allow)
                            if slug is not None:
                                k = (sess, slug)
                                if k not in first or ts < first[k]:
                                    first[k] = ts
                        msg = rec.get("message")
                        if sess in want_sessions and isinstance(msg, dict) \
                                and msg.get("role") == "assistant" \
                                and isinstance(msg.get("usage"), dict):
                            mid, rid = msg.get("id"), rec.get("requestId")
                            if mid or rid:
                                key = "%s|%s" % (mid or "", rid or "")
                            else:
                                uniq += 1
                                key = "u%d" % uniq
                            vals = [_i(msg["usage"].get(u)) for u in USAGE_FIELDS]
                            t = turns.setdefault(sess, {})
                            cur = t.get(key)
                            if cur is None:
                                t[key] = [ts] + vals
                            else:
                                cur[0] = min(cur[0], ts)
                                for j, v in enumerate(vals):
                                    cur[j + 1] = max(cur[j + 1], v)
                except OSError:
                    continue
    return turns, first


# --------------------------------------------------------------------- regret

def _git(repo, args):
    env = dict(os.environ, LC_ALL="C", GIT_TERMINAL_PROMPT="0", GIT_LITERAL_PATHSPECS="1")
    return subprocess.run(["git", "-C", repo] + args, capture_output=True, env=env,
                          timeout=GIT_TIMEOUT)


def regret_count(run):
    """(items regretted, items checked) for one run, or None when not readable."""
    rec = run["rec"]
    ca, repo = rec.get("commit_after"), run["repo"]
    if not isinstance(ca, str) or not L.SHA_RE.match(ca) or not os.path.isdir(repo):
        return None
    start = run["ts"]
    end = start + REGRET_DAYS * 86400
    items = _d(rec.get("removed_items"))
    files = [p for p in (items.get("files") if isinstance(items.get("files"), list) else [])
             if isinstance(p, str) and p and "\0" not in p]
    exports = [e for e in (items.get("exports") if isinstance(items.get("exports"), list) else [])
               if isinstance(e, dict) and isinstance(e.get("module"), str) and e["module"]
               and "\0" not in e["module"] and isinstance(e.get("name"), str) and e["name"]]
    try:
        anc = _git(repo, ["merge-base", "--is-ancestor", ca, "HEAD"])
        if anc.returncode != 0:
            return None
        rng = "%s..HEAD" % ca
        n = 0
        for p in files:
            r = _git(repo, ["log", "--diff-filter=A", "--no-renames", "--format=%ct", rng, "--", p])
            if r.returncode != 0:
                return None
            if any(start <= _i(x) <= end for x in r.stdout.decode("utf-8", "replace").split()):
                n += 1
        added_by_module = {}
        for e in exports:
            m = e["module"]
            if m not in added_by_module:
                r = _git(repo, ["log", "-p", "--no-textconv", "--no-ext-diff", "--no-color",
                                "--no-renames", "--format=%x01%ct", rng, "--", m])
                if r.returncode != 0:
                    return None
                added, inwin = [], False
                for line in r.stdout.decode("utf-8", "replace").split("\n"):
                    if line.startswith("\x01"):
                        inwin = start <= _i(line[1:]) <= end
                    elif inwin and line.startswith("+") and not line.startswith("+++"):
                        added.append(line[1:])
                added_by_module[m] = added
            pat = re.compile(r"^\s*(export\s+)?(default\s+)?(async\s+)?" + DECL_KW + r"\s+"
                             + re.escape(e["name"]) + r"\b")
            if any(pat.match(a) for a in added_by_module[m]):
                n += 1
        return n, len(files) + len(exports)
    except (OSError, subprocess.SubprocessError):
        return None


# --------------------------------------------------------------------- tables

def build_months(runs, regret, turns, bench_recs, first, now):
    months = {}
    for r in runs:
        k = (r["slug"], r["month"])
        months.setdefault(k, dict({c: 0 for c in MONTH_COLS}, window_closed=1))
    first_pass = {}
    for (slug, month) in months:
        if slug not in first_pass or month < first_pass[slug]:
            first_pass[slug] = month
    now_month = london_month(now)
    pass_keys = set(months)

    def row(k):
        if k[0] not in first_pass or k[1] < first_pass[k[0]]:
            return None
        if k not in pass_keys and k[1] > now_month:
            return None
        return months.setdefault(k, dict({c: 0 for c in MONTH_COLS}, window_closed=1))

    for r in runs:
        rec = r["rec"]
        m = months[(r["slug"], r["month"])]
        cuts = _d(rec.get("cuts"))
        pv, jd = _d(cuts.get("proven")), _d(cuts.get("judgement"))
        pk, pr, jk, jr = _i(pv.get("kept")), _i(pv.get("reverted")), _i(jd.get("kept")), _i(jd.get("reverted"))
        rem = _d(rec.get("removed"))
        m["passes"] += 1
        m["proven_kept"] += pk
        m["proven_reverted"] += pr
        m["judgement_kept"] += jk
        m["judgement_reverted"] += jr
        m["reverts"] += pr + jr
        m["cuts_kept"] += pk + jk
        reg = regret.get(r["idx"])
        if reg is not None:
            m["regret_read"] += 1
            m["cuts_regretted"] += reg[0]
            m["regret_items_checked"] += reg[1]
        m["guard_trips"] += guard_tripped(rec)
        m["lines_removed"] += _i(rem.get("lines"))
        m["files_removed"] += _i(rem.get("files"))
        m["exports_removed"] += _i(rem.get("exports"))
        m["packages_removed"] += _i(rem.get("packages"))
        m["advisories_removed"] += advisories_removed(rec)
        sess, st = rec.get("session"), r["started"]
        if isinstance(sess, str) and st is not None:
            sel = [t for t in turns.get(sess, {}).values() if st <= t[0] <= r["ts"]]
            if sel:
                m["pass_cost_read"] += 1
                m["pass_tokens"] += sum(sum(t[1:]) for t in sel)
        if r["ts"] + REGRET_DAYS * 86400 > now:
            m["window_closed"] = 0
    for b in bench_recs:
        mr = row((b["slug"], london_month(b["ts"])))
        if mr is not None:
            mr["bench_tokens"] += b["total"]
    for (_sess, slug), ts in first.items():
        mr = row((slug, london_month(ts)))
        if mr is not None:
            mr["sessions"] += 1
    rows = [dict(project=k[0], month=k[1], **v) for k, v in months.items()]
    rows.sort(key=lambda r: (r["project"], r["month"]))
    return rows


def build_measures(runs):
    sums = {}
    for r in runs:
        rec = r["rec"]
        if rec.get("outcome") != "completed":
            continue
        before, after = _d(rec.get("before")), _d(rec.get("after"))
        for meas in MEASURES:
            b, a = _num(before.get(meas)), _num(after.get(meas))
            if b is not None and a is not None:
                cur = sums.setdefault((r["slug"], r["month"], meas), [0, 0])
                cur[0] += b
                cur[1] += a
    rows = [{"project": k[0], "month": k[1], "measure": k[2], "before": v[0], "after": v[1]}
            for k, v in sums.items()]
    rows.sort(key=lambda r: (r["project"], r["month"], r["measure"]))
    return rows


def build_bench(bench_recs):
    """-> (rows, incomplete groups, groups dropped for sharing a key)."""
    groups = {}
    for b in bench_recs:
        groups.setdefault((b["repo"], b["pass_ts"]), []).append(b)
    best, incomplete, dropped = {}, 0, 0
    for (_repo, pass_ts), recs in groups.items():
        tasks = {}
        for b in recs:
            tasks.setdefault(b["task"], {s: [] for s in SIDES})[b["side"]].append(b)
        if not tasks or any(len(t[s]) < BENCH_MIN_RUNS for t in tasks.values() for s in SIDES):
            incomplete += 1
            continue
        med = {s: [median([b["total"] for b in t[s]]) for t in tasks.values()] for s in SIDES}
        floors = [abs(p - n) for p, n in zip(med["pre"], med["noise"])]

        def passed(side):
            return sum(1 for t in tasks.values()
                       if sum(1 for b in t[side] if b["passed"] is True) * 2 > len(t[side]))
        pm = epoch(pass_ts)
        row = {
            "project": recs[0]["slug"],
            "pass_month": london_month(pm),
            "run_month": london_month(max(b["ts"] for b in recs)),
            "pre_median": rnd(mean(med["pre"])),
            "post_median": rnd(mean(med["post"])),
            "noise_floor": rnd(mean(floors)),
            "runs_pre": min(len(t["pre"]) for t in tasks.values()),
            "runs_post": min(len(t["post"]) for t in tasks.values()),
            "tasks": len(tasks),
            "tasks_checked": sum(1 for t in tasks.values()
                                 if all(b["passed"] is not None for s in SIDES for b in t[s])),
            "tasks_passed_pre": passed("pre"),
            "tasks_passed_post": passed("post"),
        }
        key = (row["project"], row["pass_month"], row["run_month"])
        cur = best.get(key)
        if cur is None:
            best[key] = (pm, row)
        else:
            dropped += 1
            if pm > cur[0]:
                best[key] = (pm, row)
    rows = [v[1] for v in best.values()]
    rows.sort(key=lambda r: (r["project"], r["pass_month"], r["run_month"]))
    return rows, incomplete, dropped


def build_passes(runs, now):
    by = {}
    for r in runs:
        by.setdefault((r["slug"], london_day(r["ts"])), []).append(r)
    rows = []
    for (slug, day), rs in by.items():
        for seq, r in enumerate(sorted(rs, key=lambda r: r["ts"]), 1):
            rec = r["rec"]
            rows.append({"project": slug, "day": day, "seq": seq,
                         "window_closed": int(r["ts"] + REGRET_DAYS * 86400 <= now),
                         "guard_tripped": guard_tripped(rec),
                         "report_only": int(bool(rec.get("report_only")))})
    rows.sort(key=lambda r: (r["project"], r["day"], r["seq"]))
    return rows


def load_runs(recs, allow):
    """-> (runs, bad, unlisted)."""
    runs, bad, unlisted = [], 0, 0
    for rec in recs:
        if L.validate_run(rec):
            bad += 1
            continue
        ts, repo = epoch(rec["ts"]), norm_repo(rec["repo"])
        if ts is None or repo is None:
            bad += 1
            continue
        slug = allow.get(repo)
        if slug is None:
            unlisted += 1
            continue
        runs.append({"idx": len(runs), "rec": rec, "ts": ts, "repo": repo, "slug": slug,
                     "started": epoch(rec["started_at"]), "month": london_month(ts)})
    return runs, bad, unlisted


def load_bench(recs, allow):
    """-> (records, bad, unlisted)."""
    out, bad, unlisted = [], 0, 0
    for rec in recs:
        if L.validate_bench(rec):
            bad += 1
            continue
        ts, repo, pts = epoch(rec["ts"]), norm_repo(rec["repo"]), rec["pass_ts"]
        if ts is None or repo is None or epoch(pts) is None:
            bad += 1
            continue
        slug = allow.get(repo)
        if slug is None:
            unlisted += 1
            continue
        out.append({"slug": slug, "repo": repo, "pass_ts": pts, "side": rec["side"], "ts": ts,
                    "task": rec["task"], "passed": rec["passed"],
                    "total": sum(_i(rec.get(f)) for f in BENCH_FIELDS)})
    return out, bad, unlisted


def write_snapshot(state_dir, doc):
    os.makedirs(state_dir, mode=0o700, exist_ok=True)
    target = os.path.join(state_dir, "snapshot.json")
    fd, tmp = tempfile.mkstemp(dir=state_dir, prefix=".tmp-", suffix=".json")
    try:
        with os.fdopen(fd, "w") as fh:
            json.dump(doc, fh, indent=2, sort_keys=True)
            fh.write("\n")
        os.chmod(tmp, 0o600)
        os.replace(tmp, target)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def main(argv=None):
    ap = argparse.ArgumentParser(description="Snapshot of what the pare pass delivers, per project and month.")
    ap.add_argument("--json", action="store_true", help="print the snapshot JSON")
    ap.add_argument("--no-write", action="store_true", help="do not write snapshot.json")
    ap.add_argument("--now", help="ISO time to use as now (test hook)")
    a = ap.parse_args(argv)
    now = dt.datetime.now(dt.timezone.utc).timestamp()
    if a.now:
        now = parse_iso(a.now)
        if now is None:
            ap.error("bad --now")
    try:
        runs_file = L.runs_path()
    except ValueError:
        print("pare-scan: FORGE_PARE_LEDGER must be an absolute path or 'off'", file=sys.stderr)
        return 2
    empty = {"months": [], "measures": [], "bench": [], "passes": []}
    tables, state_dir = empty, None
    if runs_file is None:
        print("pare-scan: FORGE_PARE_LEDGER=off; no ledger read, no snapshot written", file=sys.stderr)
        a.no_write = True
    else:
        membrane = os.environ.get("FORGE_MEMBRANE") or os.path.join(os.path.expanduser("~"), ".claude")
        root = os.path.join(membrane, "projects")
        if not os.path.isdir(root):
            print("pare-scan: transcripts directory not found", file=sys.stderr)
            return 2
        state_dir = L.state_dir()
        try:
            run_recs, bad_runs = read_jsonl(runs_file)
            bench_raw, bad_bench = read_jsonl(L.bench_path())
            allow, note = read_allow(allow_path())
            if note:
                print("pare-scan: %s" % note, file=sys.stderr)
            runs, bad_r, unl_r = load_runs(run_recs, allow)
            bench, bad_b, unl_b = load_bench(bench_raw, allow)
            sessions_wanted = {r["rec"]["session"] for r in runs if isinstance(r["rec"].get("session"), str)}
            turns, first = scan_transcripts(root, allow, sessions_wanted)
            regret = {}
            for r in runs:
                v = regret_count(r)
                if v is not None:
                    regret[r["idx"]] = v
            bench_rows, incomplete, dropped = build_bench(bench)
            tables = {
                "months": build_months(runs, regret, turns, bench, first, now),
                "measures": build_measures(runs),
                "bench": bench_rows,
                "passes": build_passes(runs, now),
            }
            if unl_r + unl_b:
                print("pare-scan: %d records left out (repo not in allow-list)" % (unl_r + unl_b), file=sys.stderr)
            if bad_runs + bad_bench + bad_r + bad_b:
                print("pare-scan: %d bad ledger lines skipped" % (bad_runs + bad_bench + bad_r + bad_b), file=sys.stderr)
            if incomplete:
                print("pare-scan: %d incomplete bench groups left out" % incomplete, file=sys.stderr)
            if dropped:
                print("pare-scan: %d bench groups dropped (older pass sharing a month key)" % dropped, file=sys.stderr)
        except OSError as e:
            print("pare-scan: I/O error (%s)" % e.__class__.__name__, file=sys.stderr)
            return 2
    doc = {"v": 1, "asof": dt.datetime.fromtimestamp(now, dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
           "tables": tables}
    if not a.no_write:
        try:
            write_snapshot(state_dir, doc)
        except OSError as e:
            print("pare-scan: I/O error (%s)" % e.__class__.__name__, file=sys.stderr)
            return 2
    if a.json:
        print(json.dumps(doc, indent=2, sort_keys=True))
    else:
        print("pare-scan: " + ", ".join("%s %d" % (k, len(v)) for k, v in sorted(tables.items())))
    return 0


if __name__ == "__main__":
    sys.exit(main())
