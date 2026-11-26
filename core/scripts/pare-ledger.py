#!/usr/bin/env python3
"""pare-ledger: the only writer of the /pare ledgers.

Subcommands
  run          read ONE JSON object on stdin, validate it against the closed v1
               run schema, append it as one compact line to the runs ledger
  bench        same for the v1 bench schema, appended to the bench ledger
  hook-status  print "on" and exit 0 if the switch file exists, else print "off"
               and exit 1

Paths
  runs ledger   ${FORGE_PARE_LEDGER:-${XDG_STATE_HOME:-$HOME/.local/state}/forge/pare/runs.jsonl}
                (FORGE_PARE_LEDGER must be an absolute path or "off")
  bench ledger  bench.jsonl in the same directory as the runs ledger
  switch file   ${XDG_STATE_HOME:-$HOME/.local/state}/forge/pare/smith-hook-on
                Absent by default and never created by this script. To enable
                the smith hook:   touch "${XDG_STATE_HOME:-$HOME/.local/state}/forge/pare/smith-hook-on"
                (create the directory first if needed); remove the file to disable.
  FORGE_PARE_LEDGER=off: run/bench validate, write nothing, exit 0 and say so on stderr.

Behaviour
  The ledger directory is created mode 700, the file mode 600. Each append takes
  an exclusive fcntl.flock and writes the line plus "\\n" with a single os.write.
  Validation failure exits 2; each message names the field path and the problem
  and never prints a value (not even an offending key name). Exit 1 is an I/O
  failure. Only the schema fields are stored: no code or file contents.

Import (public API, side-effect free; other scripts load this file via importlib)
  SHA_RE, SLUG_RE (task ids and project slugs), TS_RE, parse_ts(s) -> datetime|None,
  SIDES, METRIC_KEYS (the 8 metric names, ordered), MAX_INT (2**53-1),
  runs_path() -> abs path | None (None when FORGE_PARE_LEDGER=off; ValueError on a
  relative path; empty = unset), bench_path(), state_dir(),
  validate_run(obj) -> list[str], validate_bench(obj) -> list[str] (error strings,
  empty list = valid).

Append safety
  The ledger directory must be owned by the current user (else refused) and is
  chmod 700 if wider. The file is opened O_WRONLY|O_APPEND|O_CREAT|O_NOFOLLOW (a
  symlinked ledger is refused), fstat must show a regular file owned by the user,
  and it is fchmod 600 if wider.

Schemas (v1, closed: unknown or missing keys are errors; "int" means a
non-negative int, not a bool, at most 2**53-1; v must be the int 1 (not 1.0, not
true); ts values are strict UTC YYYY-MM-DDTHH:MM:SSZ; sha is 7-64 hex characters;
"relpath" has no leading "/" or ":" (git pathspec magic) and no ".." segment, at
most 4096 chars; string caps: session 128, task/slug 40, tool name 64, export
name 200, package name 214, advisory id 200, absolute paths 4096)
  run:   v=1, ts, started_at (<= ts), session str|null, repo (absolute path),
         scope relpath ("." allowed), trigger smith|patch|standalone,
         commit_before sha, commit_after sha|null,
         tools {name: version} (version matches ^[0-9A-Za-z.+_-]{1,64}$),
         coverage_pct number 0-100|null, report_only bool,
         report_only_reason low_coverage|no_tool|tests_red|dirty_tree|null (null
         iff report_only is false),
         cuts {proven {candidates,tried,kept,reverted},
               judgement {candidates,proposed,approved,kept,reverted}}
           proven: kept+reverted <= tried;
           judgement: kept+reverted <= approved <= proposed,
         removed {lines,files,exports,packages},
         removed_items {files [relpath], exports [{module relpath, name str}],
                        packages [str]},
         before, after: {source_tokens,packages,advisories,bundle_bytes,build_ms,
                         test_ms,typecheck_ms,test_count} each int|null,
         advisory_ids_removed [str],
         guards {tests_green_after,test_count_drop,config_changed} bools,
         pass_seconds int, outcome completed|report_only|aborted|failed
         Cross-checks: report_only == (outcome == "report_only"); report_only
         true => cuts.proven.kept == cuts.judgement.kept == 0;
         removed.files/exports/packages == len of the matching removed_items
         list; |pass_seconds - (ts - started_at)| <= 5 seconds.
  bench: v=1, ts, repo, pass_ts, side pre|post|noise, commit sha,
         task (SLUG_RE ^[a-z0-9][a-z0-9-]{0,39}$), run int >= 1, input_tokens,
         output_tokens, cache_creation_tokens, cache_read_tokens (int),
         passed bool|null, seconds int, session str|null
Python 3 stdlib only.
"""
import datetime as dt
import fcntl
import json
import math
import os
import re
import stat
import sys

MAX_INPUT = 4 * 1024 * 1024
MAX_INT = 2 ** 53 - 1
TS_RE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")
SHA_RE = re.compile(r"^[0-9a-fA-F]{7,64}$")
SLUG_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,39}$")
_TOOLVER = re.compile(r"^[0-9A-Za-z.+_-]{1,64}$")
_TS_FMT = "%Y-%m-%dT%H:%M:%SZ"

TRIGGERS = ("smith", "patch", "standalone")
REASONS = ("low_coverage", "no_tool", "tests_red", "dirty_tree")
OUTCOMES = ("completed", "report_only", "aborted", "failed")
SIDES = ("pre", "post", "noise")
METRIC_KEYS = ("source_tokens", "packages", "advisories", "bundle_bytes",
               "build_ms", "test_ms", "typecheck_ms", "test_count")

# ------------------------------------------------------------------ validators


def parse_ts(s):
    """Strict UTC "YYYY-MM-DDTHH:MM:SSZ" -> datetime, else None."""
    if not isinstance(s, str) or not TS_RE.match(s):
        return None
    try:
        return dt.datetime.strptime(s, _TS_FMT)
    except ValueError:
        return None


def _is_int(x):
    return isinstance(x, int) and not isinstance(x, bool) and 0 <= x <= MAX_INT


def _keys(obj, path, want, errs):
    """Check obj is a dict with exactly the keys in want; never names a key."""
    if not isinstance(obj, dict):
        errs.append("%s: must be an object" % (path or "$"))
        return False
    if any(not isinstance(k, str) for k in obj):
        errs.append("%s: non-string key" % (path or "$"))
        return False
    missing = [k for k in want if k not in obj]
    for k in missing:
        errs.append("%s: missing key" % (_j(path, k)))
    extra = sum(1 for k in obj if k not in want)
    if extra:
        errs.append("%s: %d unknown key(s)" % (path or "$", extra))
    return not missing


def _j(path, k):
    return "%s.%s" % (path, k) if path else k


def _int(obj, k, path, errs, nullable=False, minimum=0):
    v = obj[k]
    p = _j(path, k)
    if v is None and nullable:
        return
    if not _is_int(v):
        errs.append("%s: must be a non-negative integer (max 2**53-1)%s" % (p, " or null" if nullable else ""))
    elif v < minimum:
        errs.append("%s: below minimum" % p)


def _bool(obj, k, path, errs, nullable=False):
    v = obj[k]
    if v is None and nullable:
        return
    if not isinstance(v, bool):
        errs.append("%s: must be a boolean%s" % (_j(path, k), " or null" if nullable else ""))


def _str(obj, k, path, errs, nullable=False, maxlen=4096):
    v = obj[k]
    if v is None and nullable:
        return
    if not isinstance(v, str):
        errs.append("%s: must be a string%s" % (_j(path, k), " or null" if nullable else ""))
    elif len(v) > maxlen:
        errs.append("%s: longer than %d characters" % (_j(path, k), maxlen))


def _enum(obj, k, path, errs, allowed):
    v = obj[k]
    if not isinstance(v, str) or v not in allowed:
        errs.append("%s: not an allowed value" % _j(path, k))


def _ts(obj, k, path, errs):
    if parse_ts(obj[k]) is None:
        errs.append("%s: must be a UTC timestamp YYYY-MM-DDTHH:MM:SSZ" % _j(path, k))
        return False
    return True


def _sha(obj, k, path, errs, nullable=False):
    v = obj[k]
    if v is None and nullable:
        return
    if not isinstance(v, str) or not SHA_RE.match(v):
        errs.append("%s: must be a 7-64 hex sha%s" % (_j(path, k), " or null" if nullable else ""))


def _abs(obj, k, path, errs):
    v = obj[k]
    if (not isinstance(v, str) or not v.startswith("/") or "\x00" in v
            or len(v) > 4096):
        errs.append("%s: must be an absolute path" % _j(path, k))


def _rel_ok(v, allow_dot):
    if (not isinstance(v, str) or not v or "\x00" in v or len(v) > 4096
            or v.startswith("/") or v.startswith(":")):
        return False
    if v == ".":
        return allow_dot
    return ".." not in v.split("/")


def _rel(obj, k, path, errs, allow_dot=False):
    if not _rel_ok(obj[k], allow_dot):
        errs.append("%s: must be a repo-relative path (no leading '/' or ':', no '..')" % _j(path, k))


def _counts(obj, k, path, errs, names):
    """Validate obj[k] as an object of non-negative ints named by names."""
    p = _j(path, k)
    sub = obj[k]
    if not _keys(sub, p, names, errs):
        return None
    ok = True
    for n in names:
        if not _is_int(sub[n]):
            errs.append("%s: must be a non-negative integer" % _j(p, n))
            ok = False
    return sub if ok else None


def _list(obj, k, path, errs):
    v = obj[k]
    if not isinstance(v, list):
        errs.append("%s: must be an array" % _j(path, k))
        return []
    return v


def _metrics(obj, k, path, errs):
    p = _j(path, k)
    m = obj[k]
    if not _keys(m, p, METRIC_KEYS, errs):
        return
    for n in METRIC_KEYS:
        if m[n] is not None and not _is_int(m[n]):
            errs.append("%s: must be a non-negative integer or null" % _j(p, n))


RUN_KEYS = ("v", "ts", "started_at", "session", "repo", "scope", "trigger",
            "commit_before", "commit_after", "tools", "coverage_pct", "report_only",
            "report_only_reason", "cuts", "removed", "removed_items", "before", "after",
            "advisory_ids_removed", "guards", "pass_seconds", "outcome")


def validate_run(obj):
    errs = []
    if not _keys(obj, "", RUN_KEYS, errs):
        return errs
    if type(obj["v"]) is not int or obj["v"] != 1:
        errs.append("v: must be the integer 1")
    ts_ok = _ts(obj, "ts", "", errs)
    st_ok = _ts(obj, "started_at", "", errs)
    if ts_ok and st_ok and obj["started_at"] > obj["ts"]:
        errs.append("started_at: later than ts")
    _str(obj, "session", "", errs, nullable=True, maxlen=128)
    _abs(obj, "repo", "", errs)
    _rel(obj, "scope", "", errs, allow_dot=True)
    _enum(obj, "trigger", "", errs, TRIGGERS)
    _sha(obj, "commit_before", "", errs)
    _sha(obj, "commit_after", "", errs, nullable=True)

    tools = obj["tools"]
    if not isinstance(tools, dict):
        errs.append("tools: must be an object")
    else:
        if any(not isinstance(v, str) or not _TOOLVER.match(v) for v in tools.values()):
            errs.append("tools: values must match ^[0-9A-Za-z.+_-]{1,64}$")
        if any(not isinstance(k, str) or not 1 <= len(k) <= 64 for k in tools):
            errs.append("tools: keys must be strings of 1-64 characters")

    cov = obj["coverage_pct"]
    if cov is not None:
        if (isinstance(cov, bool) or not isinstance(cov, (int, float))
                or not math.isfinite(cov) or cov < 0 or cov > 100):
            errs.append("coverage_pct: must be a number 0-100 or null")
    _bool(obj, "report_only", "", errs)
    reason = obj["report_only_reason"]
    if reason is not None and (not isinstance(reason, str) or reason not in REASONS):
        errs.append("report_only_reason: not an allowed value")
    elif isinstance(obj["report_only"], bool):
        if obj["report_only"] and reason is None:
            errs.append("report_only_reason: required when report_only is true")
        if not obj["report_only"] and reason is not None:
            errs.append("report_only_reason: must be null when report_only is false")
    outcome = obj["outcome"]
    if (isinstance(obj["report_only"], bool) and isinstance(outcome, str)
            and outcome in OUTCOMES and obj["report_only"] != (outcome == "report_only")):
        errs.append("report_only: must be true exactly when outcome is report_only")

    cuts = obj["cuts"]
    pr = ju = None
    if _keys(cuts, "cuts", ("proven", "judgement"), errs):
        pr = _counts(cuts, "proven", "cuts", errs, ("candidates", "tried", "kept", "reverted"))
        if pr and pr["kept"] + pr["reverted"] > pr["tried"]:
            errs.append("cuts.proven: kept + reverted exceeds tried")
        ju = _counts(cuts, "judgement", "cuts", errs,
                     ("candidates", "proposed", "approved", "kept", "reverted"))
        if ju:
            if ju["kept"] + ju["reverted"] > ju["approved"]:
                errs.append("cuts.judgement: kept + reverted exceeds approved")
            if ju["approved"] > ju["proposed"]:
                errs.append("cuts.judgement: approved exceeds proposed")
    if obj["report_only"] is True and pr and ju and (pr["kept"] != 0 or ju["kept"] != 0):
        errs.append("cuts: kept must be 0 when report_only is true")
    rem = _counts(obj, "removed", "", errs, ("lines", "files", "exports", "packages"))

    ri = obj["removed_items"]
    if _keys(ri, "removed_items", ("files", "exports", "packages"), errs):
        lens = {}
        for n in ("files", "exports", "packages"):
            lst = ri[n]
            if isinstance(lst, list):
                lens[n] = len(lst)
        if rem:
            for n, c in lens.items():
                if rem[n] != c:
                    errs.append("removed.%s: must equal the length of removed_items.%s" % (n, n))
        for i, f in enumerate(_list(ri, "files", "removed_items", errs)):
            if not _rel_ok(f, False):
                errs.append("removed_items.files[%d]: must be a repo-relative path (no leading '/' or ':', no '..')" % i)
        for i, e in enumerate(_list(ri, "exports", "removed_items", errs)):
            p = "removed_items.exports[%d]" % i
            if _keys(e, p, ("module", "name"), errs):
                _rel(e, "module", p, errs)
                _str(e, "name", p, errs, maxlen=200)
        for i, s in enumerate(_list(ri, "packages", "removed_items", errs)):
            if not isinstance(s, str) or len(s) > 214:
                errs.append("removed_items.packages[%d]: must be a string of at most 214 characters" % i)

    _metrics(obj, "before", "", errs)
    _metrics(obj, "after", "", errs)
    for i, s in enumerate(_list(obj, "advisory_ids_removed", "", errs)):
        if not isinstance(s, str) or len(s) > 200:
            errs.append("advisory_ids_removed[%d]: must be a string of at most 200 characters" % i)
    g = obj["guards"]
    if _keys(g, "guards", ("tests_green_after", "test_count_drop", "config_changed"), errs):
        for n in ("tests_green_after", "test_count_drop", "config_changed"):
            _bool(g, n, "guards", errs)
    _int(obj, "pass_seconds", "", errs)
    _enum(obj, "outcome", "", errs, OUTCOMES)
    if ts_ok and st_ok and _is_int(obj["pass_seconds"]):
        span = (parse_ts(obj["ts"]) - parse_ts(obj["started_at"])).total_seconds()
        if abs(obj["pass_seconds"] - span) > 5:
            errs.append("pass_seconds: not within 5 seconds of ts minus started_at")
    return errs


BENCH_KEYS = ("v", "ts", "repo", "pass_ts", "side", "commit", "task", "run",
              "input_tokens", "output_tokens", "cache_creation_tokens",
              "cache_read_tokens", "passed", "seconds", "session")


def validate_bench(obj):
    errs = []
    if not _keys(obj, "", BENCH_KEYS, errs):
        return errs
    if type(obj["v"]) is not int or obj["v"] != 1:
        errs.append("v: must be the integer 1")
    _ts(obj, "ts", "", errs)
    _abs(obj, "repo", "", errs)
    _ts(obj, "pass_ts", "", errs)
    _enum(obj, "side", "", errs, SIDES)
    _sha(obj, "commit", "", errs)
    if not isinstance(obj["task"], str) or not SLUG_RE.match(obj["task"]):
        errs.append("task: must match ^[a-z0-9][a-z0-9-]{0,39}$")
    _int(obj, "run", "", errs, minimum=1)
    for n in ("input_tokens", "output_tokens", "cache_creation_tokens",
              "cache_read_tokens", "seconds"):
        _int(obj, n, "", errs)
    _bool(obj, "passed", "", errs, nullable=True)
    _str(obj, "session", "", errs, nullable=True, maxlen=128)
    return errs


# ------------------------------------------------------------------------ I/O


def _state_home():
    xdg = os.environ.get("XDG_STATE_HOME")
    if xdg:
        return xdg
    return os.path.join(os.path.expanduser("~"), ".local", "state")


def _pare_dir():
    return os.path.join(_state_home(), "forge", "pare")


def runs_path():
    """Absolute runs ledger path, or None when disabled (FORGE_PARE_LEDGER=off).

    Raises ValueError for a relative FORGE_PARE_LEDGER. Empty counts as unset."""
    env = os.environ.get("FORGE_PARE_LEDGER")
    if env == "off":
        return None
    if env:
        if not os.path.isabs(env):
            raise ValueError("FORGE_PARE_LEDGER must be an absolute path or 'off'")
        return env
    return os.path.join(_pare_dir(), "runs.jsonl")


def state_dir():
    """Directory holding the ledgers (the runs ledger's dir, or the default dir)."""
    p = runs_path()
    return os.path.dirname(p) if p else _pare_dir()


def bench_path():
    """bench.jsonl beside the runs ledger, or None when disabled."""
    p = runs_path()
    return os.path.join(os.path.dirname(p), "bench.jsonl") if p else None


def _append(path, line):
    d = os.path.dirname(path)
    os.makedirs(d, mode=0o700, exist_ok=True)
    uid = os.geteuid()
    ds = os.stat(d)
    if not stat.S_ISDIR(ds.st_mode) or ds.st_uid != uid:
        raise OSError("ledger directory not owned by the current user")
    if ds.st_mode & 0o077:
        os.chmod(d, 0o700)
    fd = os.open(path, os.O_WRONLY | os.O_APPEND | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    try:
        fs = os.fstat(fd)
        if not stat.S_ISREG(fs.st_mode) or fs.st_uid != uid:
            raise OSError("ledger is not a regular file owned by the current user")
        if fs.st_mode & 0o077:
            os.fchmod(fd, 0o600)
        fcntl.flock(fd, fcntl.LOCK_EX)
        data = (line + "\n").encode("ascii")
        n = os.write(fd, data)
        if n != len(data):
            raise OSError("short write")
    finally:
        os.close(fd)


def _cmd_write(kind):
    validate = validate_run if kind == "run" else validate_bench
    raw = sys.stdin.buffer.read(MAX_INPUT + 1)
    if len(raw) > MAX_INPUT:
        sys.stderr.write("pare-ledger: input too large\n")
        return 2
    try:
        obj = json.loads(raw.decode("utf-8"))
    except (ValueError, UnicodeDecodeError):
        sys.stderr.write("pare-ledger: stdin is not valid JSON\n")
        return 2
    errs = validate(obj)
    if errs:
        for e in errs:
            sys.stderr.write("pare-ledger: %s\n" % e)
        return 2
    try:
        runs = runs_path()
    except ValueError as e:
        sys.stderr.write("pare-ledger: %s\n" % e)
        return 2
    if runs is None:
        sys.stderr.write("pare-ledger: FORGE_PARE_LEDGER=off, validated, nothing written\n")
        return 0
    path = runs if kind == "run" else bench_path()
    line = json.dumps(obj, separators=(",", ":"), ensure_ascii=True, allow_nan=False)
    try:
        _append(path, line)
    except OSError as e:
        sys.stderr.write("pare-ledger: cannot append (%s)\n" % e.__class__.__name__)
        return 1
    return 0


def _cmd_hook_status():
    if os.path.exists(os.path.join(_pare_dir(), "smith-hook-on")):
        print("on")
        return 0
    print("off")
    return 1


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if len(argv) != 1 or argv[0] not in ("run", "bench", "hook-status"):
        sys.stderr.write("usage: pare-ledger.py run|bench|hook-status\n")
        return 2
    if argv[0] == "hook-status":
        return _cmd_hook_status()
    return _cmd_write(argv[0])


if __name__ == "__main__":
    sys.exit(main())
