#!/usr/bin/env python3
"""pare-measure: measure a repo scope before and after a paring pass, with
established tools instead of hand-rolled counters.

Prints one JSON object to stdout; counts and reasons go to stderr only, never
file contents. Exit 0 even when some measures are null; exit 2 on bad arguments
(repo not a git work tree, scope escaping the repo). Writes nothing in the repo.

Usage
  pare-measure.py --repo <abs> --scope <rel> [--build CMD] [--test CMD]
                  [--typecheck CMD] [--test-count CMD] [--bundle <rel path>]
                  [--runs N (default 3)] [--timeout SECONDS (default 900)]

Output (one JSON object)
  {"metrics": {the 8 METRIC_KEYS: int|null}, "advisory_ids": [...],
   "tools": {...}, "missing": [...]}
  `metrics` has exactly the keys of a pare-ledger run record's before/after
  objects (METRIC_KEYS is imported from pare-ledger.py in the same directory), so
  it can be copied straight in.
  source_tokens  repomix on the scope (tokenizer o200k_base), total token count
  packages       unique declared direct dependencies, counted per ecosystem and
                 added up. JS: package.json (dependencies, devDependencies,
                 optionalDependencies, peerDependencies), names unique across all
                 groups. Python: pyproject.toml ([project] dependencies +
                 optional-dependencies, [tool.poetry] dependencies, group and dev
                 dependencies, python excluded) and requirements*.txt (comments
                 and option lines starting with "-" such as -r, -e, -c,
                 --index-url are skipped), names normalised per PEP 503
                 (lowercase, runs of - _ . become -) and unique across all of
                 them. Read from the repo root and the scope dir; null when no
                 manifest is found
  advisories     unique vulnerability ids from osv-scanner (exit 1 = found some).
                 NOTE: osv-scanner queries osv.dev over the network with the
                 dependency list, so this measure sends package names and
                 versions off the machine
  advisory_ids   those ids, sorted
  bundle_bytes   total bytes of the file or directory tree (symlinks not
                 followed); --bundle is resolved with realpath and must stay
                 inside the repo, else exit 2
  build_ms, test_ms, typecheck_ms
                 median of N runs, via hyperfine --export-json; without hyperfine
                 the command is timed N times here and the median taken
  test_count     --test-count CMD must print only the count: its last non-empty
                 stdout line must be a bare integer (e.g. "42"), otherwise null
                 and the reason goes to stderr
  tools          {name: version token from the first line of "<tool> --version"
                 (matches the ledger's ^[0-9A-Za-z.+_-]{1,64}$, else "unknown")},
                 only tools used
  missing        sorted names of tools or measures that could not be read

null means not read (tool absent, command not given, command failed); never 0.
Commands run with cwd = repo, output discarded (test-count: stdout read), each
under --timeout, in their own process group (start_new_session); on timeout the
whole group is sent SIGKILL.

Tool output read (repomix, osv-scanner, hyperfine are not guaranteed installed;
see the notes beside each parser).
"""
import argparse
import importlib.util
import json
import os
import re
import shutil
import signal
import statistics
import subprocess
import sys
import tempfile
import time

try:
    import tomllib
except ImportError:  # python < 3.11
    tomllib = None

ANSI = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
_NAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*")
_COUNT = re.compile(r"^\s*(\d+)\s*$")


def _load_ledger():
    path = os.path.join(os.path.dirname(os.path.realpath(__file__)), "pare-ledger.py")
    spec = importlib.util.spec_from_file_location("pare_ledger", path)
    mod = importlib.util.module_from_spec(spec)
    sys.dont_write_bytecode = True
    spec.loader.exec_module(mod)
    return mod


_LEDGER = _load_ledger()
METRIC_KEYS = _LEDGER.METRIC_KEYS
MAX_INT = _LEDGER.MAX_INT


def log(msg):
    print("pare-measure: " + msg, file=sys.stderr)


def run_group(cmd, cwd, timeout, shell=False, capture=False):
    """Run in a new session; on timeout SIGKILL the whole process group.

    Returns (returncode, stdout, stderr), or None on timeout or launch error."""
    pipe = subprocess.PIPE if capture else subprocess.DEVNULL
    try:
        p = subprocess.Popen(cmd, cwd=cwd, shell=shell,
                             executable="/bin/bash" if shell else None,
                             stdin=subprocess.DEVNULL, stdout=pipe, stderr=pipe,
                             text=True, errors="replace", start_new_session=True)
    except Exception:
        return None
    try:
        out, err = p.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(p.pid, signal.SIGKILL)
        except OSError:
            pass
        try:
            p.communicate(timeout=10)
        except Exception:
            pass
        return None
    except Exception:
        try:
            os.killpg(p.pid, signal.SIGKILL)
        except OSError:
            pass
        return None
    return p.returncode, out or "", err or ""


def tool_version(name, tools):
    r = run_group([name, "--version"], None, 30, capture=True)
    out = ((r[1] or r[2]).strip().splitlines()) if r else []
    m = None
    if out:
        m = (re.search(r"(?<![0-9A-Za-z.])\d+\.\d+[0-9A-Za-z.+_-]*", out[0])
             or re.search(r"\d[0-9A-Za-z.+_-]*", out[0]))
    tools[name] = m.group(0)[:64] if m else "unknown"


def run_quiet(cmd, cwd, timeout, shell=False):
    """Run discarding output. Returns exit code, or None on timeout/launch error."""
    r = run_group(cmd, cwd, timeout, shell=shell)
    return r[0] if r else None


# --- source tokens ---------------------------------------------------------
def measure_tokens(scope_abs, timeout, tools):
    if not shutil.which("repomix"):
        return None
    tool_version("repomix", tools)
    with tempfile.TemporaryDirectory() as td:
        out = os.path.join(td, "pack.xml")
        r = run_group(["repomix", scope_abs, "--output", out, "--token-count-encoding", "o200k_base"],
                      td, timeout, capture=True)
        if r is None or r[0] != 0:
            return None
        # repomix prints "Total Tokens: 12,345 tokens" in its summary (stdout).
        m = re.search(r"Total Tokens:\s*([\d,]+)", ANSI.sub("", r[1]))
        if m:
            return int(m.group(1).replace(",", ""))
    return None


# --- packages --------------------------------------------------------------
def _py_name(spec):
    """PEP 503 normalised project name from a PEP 508 string or a bare name."""
    m = _NAME.match(spec.strip())
    return re.sub(r"[-_.]+", "-", m.group(0).lower()) if m else None


def _pkg_json(path, js, py):
    with open(path, encoding="utf-8") as f:
        d = json.load(f)
    for k in ("dependencies", "devDependencies", "optionalDependencies", "peerDependencies"):
        js.update(str(n) for n in (d.get(k) or {}))
    return True


def _pyproject(path, js, py):
    if tomllib is None:
        return False
    with open(path, "rb") as f:
        d = tomllib.load(f)
    names = []
    proj = d.get("project") or {}
    names += [x for x in (proj.get("dependencies") or []) if isinstance(x, str)]
    for v in (proj.get("optional-dependencies") or {}).values():
        names += [x for x in v if isinstance(x, str)]
    poetry = (d.get("tool") or {}).get("poetry") or {}
    groups = [poetry.get("dependencies"), poetry.get("dev-dependencies")]
    groups += [g.get("dependencies") for g in (poetry.get("group") or {}).values()]
    for g in groups:
        names += [k for k in (g or {}) if k.lower() != "python"]
    py.update(n for n in map(_py_name, names) if n)
    return True


def _reqs(path, js, py):
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            s = line.strip()
            if not s or s.startswith("#") or s.startswith("-"):
                continue
            n = _py_name(s)
            if n:
                py.add(n)
    return True


def count_packages(dirs):
    js, py = set(), set()
    found = False
    seen = set()
    for d in dirs:
        d = os.path.realpath(d)
        if d in seen or not os.path.isdir(d):
            continue
        seen.add(d)
        for name in sorted(os.listdir(d)):
            path = os.path.join(d, name)
            if not os.path.isfile(path):
                continue
            try:
                if name == "package.json":
                    ok = _pkg_json(path, js, py)
                elif name == "pyproject.toml":
                    ok = _pyproject(path, js, py)
                elif re.fullmatch(r"requirements.*\.txt", name):
                    ok = _reqs(path, js, py)
                else:
                    continue
            except Exception:
                log("could not parse a manifest (%s)" % name)
                continue
            found = found or ok
    return len(js) + len(py) if found else None


# --- advisories ------------------------------------------------------------
def measure_advisories(repo, timeout, tools):
    if not shutil.which("osv-scanner"):
        return None, None
    tool_version("osv-scanner", tools)
    r = run_group(["osv-scanner", "scan", "source", "-r", repo, "--format", "json"],
                  None, timeout, capture=True)
    if r is None or r[0] not in (0, 1):  # 1 = vulnerabilities found
        return None, None
    try:
        data = json.loads(r[1] or "{}")
    except ValueError:
        return None, None
    ids = set()
    # results[].packages[].vulnerabilities[].id
    for r in data.get("results") or []:
        for pk in r.get("packages") or []:
            for v in pk.get("vulnerabilities") or []:
                if v.get("id"):
                    ids.add(str(v["id"]))
    return len(ids), sorted(ids)


# --- timing ----------------------------------------------------------------
def measure_ms(cmd, repo, runs, timeout, tools):
    if shutil.which("hyperfine"):
        tool_version("hyperfine", tools)
        with tempfile.TemporaryDirectory() as td:
            js = os.path.join(td, "h.json")
            r = run_group(["hyperfine", "--runs", str(runs), "--export-json", js,
                           "--shell=bash", "--", cmd], repo, timeout * runs)
            if r is None or r[0] != 0:
                return None
            try:
                with open(js) as f:
                    # results[0].median is in seconds
                    return round(float(json.load(f)["results"][0]["median"]) * 1000)
            except Exception:
                return None
    times = []
    for _ in range(runs):
        t0 = time.monotonic()
        rc = run_quiet(cmd, repo, timeout, shell=True)
        if rc != 0:
            return None
        times.append(time.monotonic() - t0)
    return round(statistics.median(times) * 1000)


def measure_count(cmd, repo, timeout):
    r = run_group(cmd, repo, timeout, shell=True, capture=True)
    if r is None:
        log("test_count: command failed to run or timed out")
        return None
    if r[0] != 0:
        log("test_count: command exited non-zero")
        return None
    lines = [ln for ln in r[1].splitlines() if ln.strip()]
    m = _COUNT.match(lines[-1]) if lines else None
    if not m:
        log("test_count: last non-empty stdout line is not a bare integer")
        return None
    n = int(m.group(1))
    if n > MAX_INT:
        log("test_count: value out of range")
        return None
    return n


# --- bundle ----------------------------------------------------------------
def measure_bundle(path):
    if os.path.islink(path):
        return os.lstat(path).st_size
    if os.path.isfile(path):
        return os.path.getsize(path)
    if not os.path.isdir(path):
        return None
    total = 0
    for root, dirs, files in os.walk(path, followlinks=False):
        for n in files + [d for d in dirs if os.path.islink(os.path.join(root, d))]:
            try:
                total += os.lstat(os.path.join(root, n)).st_size
            except OSError:
                pass
    return total


def inside(base, path):
    return path == base or path.startswith(base + os.sep)


def main():
    ap = argparse.ArgumentParser(description="Measure a repo scope with established tools.")
    ap.add_argument("--repo", required=True)
    ap.add_argument("--scope", required=True)
    ap.add_argument("--build")
    ap.add_argument("--test")
    ap.add_argument("--typecheck")
    ap.add_argument("--test-count")
    ap.add_argument("--bundle")
    ap.add_argument("--runs", type=int, default=3)
    ap.add_argument("--timeout", type=int, default=900)
    try:
        a = ap.parse_args()
    except SystemExit as e:
        sys.exit(2 if e.code else 0)
    if a.runs < 1 or a.timeout < 1:
        log("--runs and --timeout must be positive")
        sys.exit(2)

    repo = os.path.realpath(a.repo)
    if not os.path.isabs(a.repo) or not os.path.isdir(repo):
        log("--repo must be an absolute directory")
        sys.exit(2)
    try:
        g = subprocess.run(["git", "-C", repo, "rev-parse", "--is-inside-work-tree"],
                           capture_output=True, text=True)
        ok = g.returncode == 0 and g.stdout.strip() == "true"
    except OSError:
        ok = False
    if not ok:
        log("--repo is not a git work tree")
        sys.exit(2)
    scope = os.path.realpath(os.path.join(repo, a.scope))
    if os.path.isabs(a.scope) or not inside(repo, scope) or not os.path.isdir(scope):
        log("--scope must be a directory inside the repo")
        sys.exit(2)
    bundle = None
    if a.bundle:
        bundle = os.path.realpath(os.path.join(repo, a.bundle))
        if os.path.isabs(a.bundle) or not inside(repo, bundle):
            log("--bundle must be a path inside the repo")
            sys.exit(2)

    tools, missing = {}, set()
    res = {}

    res["source_tokens"] = measure_tokens(scope, a.timeout, tools)
    if res["source_tokens"] is None:
        missing.add("source_tokens")
        if "repomix" not in tools:
            missing.add("repomix")

    res["packages"] = count_packages([repo, scope])
    if res["packages"] is None:
        missing.add("packages")

    n, ids = measure_advisories(repo, a.timeout, tools)
    res["advisories"], res["advisory_ids"] = n, ids if ids is not None else []
    if n is None:
        missing.add("advisories")
        if "osv-scanner" not in tools:
            missing.add("osv-scanner")

    if bundle is not None:
        res["bundle_bytes"] = measure_bundle(bundle)
    else:
        res["bundle_bytes"] = None
    if res["bundle_bytes"] is None:
        missing.add("bundle_bytes")

    for key, cmd in (("build_ms", a.build), ("test_ms", a.test), ("typecheck_ms", a.typecheck)):
        res[key] = measure_ms(cmd, repo, a.runs, a.timeout, tools) if cmd else None
        if res[key] is None:
            missing.add(key)

    res["test_count"] = measure_count(a.test_count, repo, a.timeout) if a.test_count else None
    if res["test_count"] is None:
        missing.add("test_count")

    out = {"metrics": {k: res[k] for k in METRIC_KEYS},
           "advisory_ids": res["advisory_ids"],
           "tools": dict(sorted(tools.items())),
           "missing": sorted(missing)}
    out["missing"] = sorted(missing)
    log("missing: %s" % (", ".join(out["missing"]) or "none"))
    print(json.dumps(out))


if __name__ == "__main__":
    main()
