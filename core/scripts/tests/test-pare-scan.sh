#!/usr/bin/env bash
#
# Tests for pare-scan.py. Synthetic ledgers, allow-list, transcripts and temp git
# repos in a temp HOME; never reads the real membrane, ledgers or git config.
# Run:  bash core/scripts/tests/test-pare-scan.sh      (non-zero on failure)

HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.."
SCAN="$HERE/pare-scan.py"
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
export PYTHONDONTWRITEBYTECODE=1
mkdir -p "$TMPD/home"
export HOME="$TMPD/home"
unset XDG_STATE_HOME XDG_CONFIG_HOME

python3 -B -I - "$SCAN" "$TMPD" <<'PY'
import datetime as dt
import importlib.util
import json
import os
import re
import shutil
import stat
import subprocess
import sys
from fractions import Fraction

SCAN, T = sys.argv[1], sys.argv[2]
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("scan", SCAN)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
lspec = importlib.util.spec_from_file_location("ledger", os.path.join(os.path.dirname(SCAN), "pare-ledger.py"))
LG = importlib.util.module_from_spec(lspec)
lspec.loader.exec_module(LG)

bad = 0
def chk(name, got, want=True):
    global bad
    ok = got == want
    print(("PASS  " if ok else "FAIL  ") + name + ("" if ok else "  (got=%r want=%r)" % (got, want)))
    bad += (not ok)

# ------------------------------------------------------------------ layout
R1 = T + "/repos/proj-a"
R1X = T + "/repos/proj-a-extra"
R2 = T + "/repos/proj-b"
RU = T + "/repos/unlisted"
for d in (R1, R1 + "/sub/dir", R1X, R2, RU, T + "/state", T + "/cfg"):
    os.makedirs(d, exist_ok=True)
MEM = T + "/mem"
os.makedirs(MEM + "/projects/p1/SES-A1/subagents", exist_ok=True)
LEDGER, BENCHF, ALLOW = T + "/state/runs.jsonl", T + "/state/bench.jsonl", T + "/cfg/projects.json"
SNAP = T + "/state/snapshot.json"
GITCFG = T + "/gitconfig"
open(GITCFG, "w").write("[user]\n\tname = Test User\n\temail = test@example.invalid\n[init]\n\tdefaultBranch = main\n")
BASE_ENV = dict(os.environ, GIT_CONFIG_GLOBAL=GITCFG, GIT_CONFIG_NOSYSTEM="1")

# ------------------------------------------------------------------ git repo
def git(*args, date=None):
    env = dict(BASE_ENV)
    if date:
        env["GIT_AUTHOR_DATE"] = env["GIT_COMMITTER_DATE"] = date
    r = subprocess.run(["git", "-C", R1] + list(args), env=env, capture_output=True, text=True)
    assert r.returncode == 0, (args, r.stderr)
    return r.stdout.strip()
def put(name, text, mode="w"):
    with open(R1 + "/" + name, mode) as f:
        f.write(text)
def commit(msg, date):
    git("add", "-A")
    git("commit", "-q", "-m", msg, date=date)
    return git("rev-parse", "HEAD")

git("init", "-q")
put("old1.txt", "one\n"); put("old2.txt", "two\n"); put("old3.txt", "three\n")
put("mod.py", "def gone_fn():\n    pass\ndef other_fn():\n    pass\ndef late_fn():\n    pass\ndef alive(): pass\n")
c0 = commit("c0", "2026-10-01T09:00:00Z")
git("checkout", "-q", "-b", "side")
put("side.txt", "side\n")
cx = commit("side", "2026-11-12T09:00:00Z")
git("checkout", "-q", "main")
for f in ("old1.txt", "old2.txt", "old3.txt"):
    os.remove(R1 + "/" + f)
put("mod.py", "def alive(): pass\n")
c1 = commit("c1 removals", "2026-11-02T10:00:00Z")
put("old1.txt", "one again\n")
put("mod.py", "export function gone_fn() {}\nx = 1  # other_fn\nconst val = other_fn(3)\ncall_site_fn(1)\n"
    "def decl_fn():\n    pass\n", "a")
c2 = commit("c2 re-add within window", "2026-11-10T12:00:00Z")
put("old2.txt", "two again\n")
put("mod.py", "export function late_fn() {}\n", "a")
c3 = commit("c3 re-add after window", "2026-12-15T12:00:00Z")

# ------------------------------------------------------------------ ledgers
def jl(path, recs, extra=()):
    with open(path, "w") as f:
        for r in recs:
            f.write((r if isinstance(r, str) else json.dumps(r)) + "\n")
def met(vals):
    return {k: vals.get(k) for k in m.MEASURES}
def run(ts, started, session, repo, ca, valid=True, **kw):
    r = {"v": 1, "ts": ts, "started_at": started, "session": session, "repo": repo,
         "scope": ".", "trigger": "standalone", "commit_before": "b" * 40, "commit_after": ca,
         "tools": {"toolname-secret": "1.0.0"}, "coverage_pct": 80, "report_only": False,
         "report_only_reason": None,
         "cuts": {"proven": {"candidates": 0, "tried": 0, "kept": 0, "reverted": 0},
                  "judgement": {"candidates": 0, "proposed": 0, "approved": 0, "kept": 0, "reverted": 0}},
         "removed": {"lines": 0, "files": 0, "exports": 0, "packages": 0},
         "removed_items": {"files": [], "exports": [], "packages": []},
         "before": met({}), "after": met({}), "advisory_ids_removed": [],
         "guards": {"tests_green_after": True, "test_count_drop": False, "config_changed": False},
         "pass_seconds": int(m.epoch(ts) - m.epoch(started)), "outcome": "completed"}
    r.update(kw)
    errs = LG.validate_run(r)
    chk("fixture run %s %s" % (ts, "is valid" if valid else "is deliberately invalid") + ("" if (valid and not errs) or not valid else " " + "; ".join(errs)), bool(errs), not valid)
    return r
def cuts(pk, pr, jk, jr):
    return {"proven": {"candidates": pk + pr, "tried": pk + pr, "kept": pk, "reverted": pr},
            "judgement": {"candidates": jk + jr, "proposed": jk + jr, "approved": jk + jr, "kept": jk, "reverted": jr}}
RO = dict(report_only=True, report_only_reason="low_coverage", outcome="report_only")

NOV = ["source_tokens", "packages", "advisories", "bundle_bytes", "build_ms", "test_ms", "typecheck_ms", "test_count"]
a1_before = met({"source_tokens": 1000, "packages": 10, "advisories": 3, "bundle_bytes": 2000,
                 "build_ms": 100, "test_ms": 500, "typecheck_ms": 50, "test_count": None})
a1_after = met({"source_tokens": 900, "packages": 9, "advisories": 2, "bundle_bytes": 1950,
                "build_ms": 95, "test_ms": 400, "typecheck_ms": 48, "test_count": 30})
a2_before = met({"source_tokens": 900})
a2_after = met({"source_tokens": 850, "packages": 8, "advisories": 1, "bundle_bytes": 1900,
                "build_ms": 90, "test_ms": None, "typecheck_ms": 45, "test_count": 31})
a4_before = {k: 100 + i for i, k in enumerate(m.MEASURES)}
a5_after = {k: 50 + i for i, k in enumerate(m.MEASURES)}

A1 = run("2026-11-02T10:30:00Z", "2026-11-02T10:00:00Z", "SES-A1", R1, c1,
         cuts=cuts(3, 1, 1, 1), removed={"lines": 100, "files": 3, "exports": 3, "packages": 2},
         removed_items={"files": ["old1.txt", "old2.txt", "old3.txt"],
                        "exports": [{"module": "mod.py", "name": "gone_fn"},
                                    {"module": "mod.py", "name": "other_fn"},
                                    {"module": "mod.py", "name": "late_fn"}],
                        "packages": ["pkg-x", "pkg-y"]},
         before=a1_before, after=a1_after, advisory_ids_removed=["ADV-SECRET-1", "ADV-SECRET-2"])
A2 = run("2026-11-20T09:00:00Z", "2026-11-20T08:30:00Z", "SES-A2", R1, cx,
         cuts=cuts(0, 0, 0, 0), removed={"lines": 7, "files": 0, "exports": 0, "packages": 0},
         before=a2_before, after=a2_after, guards={"tests_green_after": True, "test_count_drop": True, "config_changed": False}, **RO)
A3 = run("2026-07-31T23:30:00Z", "2026-07-31T23:00:00Z", "SES-A3", R1, None,
         cuts=cuts(1, 0, 0, 0), removed={"lines": 4, "files": 1, "exports": 0, "packages": 0},
         removed_items={"files": ["gone.txt"], "exports": [], "packages": []})
A4 = run("2026-12-10T12:00:00Z", "2026-12-10T11:00:00Z", "SES-A4", R1, None,
         cuts=cuts(0, 0, 1, 0), removed={"lines": 20, "files": 0, "exports": 0, "packages": 0},
         before=a4_before, after=met({"source_tokens": 90}),
         guards={"tests_green_after": False, "test_count_drop": False, "config_changed": True})
A5 = run("2026-12-10T15:00:00Z", "2026-12-10T14:00:00Z", "SES-A5", R1, None,
         cuts=cuts(0, 0, 0, 0), removed={"lines": 30, "files": 0, "exports": 0, "packages": 0},
         after=a5_after, advisory_ids_removed=["ADV-SECRET-3"], **RO)
# a second scope in the same month: its pairs are summed with A1's, never mixed across runs
A6 = run("2026-11-25T10:00:00Z", "2026-11-25T09:00:00Z", None, R1, None, scope="pkg/web",
         before=met({"source_tokens": 300, "packages": 5, "test_ms": 40}),
         after=met({"source_tokens": 250, "packages": 4}))
# a failed run with a full pair: excluded from measures
A7 = run("2026-11-26T10:00:00Z", "2026-11-26T09:00:00Z", None, R1, None, outcome="failed",
         before=met({"source_tokens": 5000}), after=met({"source_tokens": 4000}))
B1 = run("2026-11-05T12:00:00Z", "2026-11-05T11:00:00Z", "SES-BR", R2 + "/", "abc1234def")
U1 = run("2026-11-06T12:00:00Z", "2026-11-06T11:00:00Z", "SES-U1", RU, None)
BADRUN = run("2026-11-07T12:00:00Z", "2026-11-07T11:00:00Z", None, R1, None, valid=False, outcome="ok")
jl(LEDGER, [A1, A2, A3, A4, A5, A6, A7, B1, U1, BADRUN, "not json {{", "[1,2]", {"ts": "bad", "repo": R1}])
json.dump({R1: "proj-a", R2: "proj-b", "/nope/x": "Bad Slug!"}, open(ALLOW, "w"))

def brec(repo, pts, side, task, n, total, passed, ts, valid=True):
    r = {"v": 1, "ts": ts, "repo": repo, "pass_ts": pts, "side": side, "commit": "d" * 40, "task": task,
         "run": n, "input_tokens": 1, "output_tokens": 2, "cache_creation_tokens": 3,
         "cache_read_tokens": total - 6, "passed": passed, "seconds": 3, "session": None}
    if valid:
        assert not LG.validate_bench(r), LG.validate_bench(r)
    return r
P1 = "2026-11-02T10:30:00Z"
N3, D3 = "2026-11-03T10:00:00Z", "2026-12-03T10:00:00Z"
bench = []
for task, side, vals, flags in [
        ("task-secret-1", "pre", [100, 200, 300], [True, True, False]),
        ("task-secret-1", "post", [50, 60, 70], [True, True, True]),
        ("task-secret-1", "noise", [190, 200, 210], [True, True, True]),
        ("task-secret-2", "pre", [400, 500, 600, 700], [True, False, False, False]),
        ("task-secret-2", "post", [100, 100, 100], [True, True, None]),
        ("task-secret-2", "noise", [450, 500, 550], [None, None, None])]:
    for i, (v, p) in enumerate(zip(vals, flags)):
        last = task == "task-secret-2" and side == "noise" and i == 2
        bench.append(brec(R1, P1, side, task, i + 1, v, p, D3 if last else N3))
P2 = "2026-12-10T12:00:00Z"
for side, k in (("pre", 3), ("post", 3), ("noise", 2)):
    for i in range(k):
        bench.append(brec(R1, P2, side, "task-secret-1", i + 1, 10, True, "2026-12-11T10:00:00Z"))
# an older complete group sharing P1's (project, pass month, run month) key: dropped
P0 = "2026-11-01T10:00:00Z"
for side in ("pre", "post", "noise"):
    for i in range(3):
        bench.append(brec(R1, P0, side, "task-old", i + 1, 10, True, "2026-12-02T10:00:00Z"))
# a lone bench record in a month with no pass (incomplete group, tokens still counted)
bench.append(brec(R1, "2026-09-10T10:00:00Z", "pre", "task-s", 1, 50, True, "2026-09-10T10:00:00Z"))
bench.append(brec(RU, P1, "pre", "task-u", 1, 999, True, N3))
bench.append(brec(R1, P1, "pre", "task-bad", 1, 999, True, N3, valid=False) | {"side": "sideways"})
chk("deliberately bad bench line is invalid", bool(LG.validate_bench(bench[-1])))
jl(BENCHF, bench + ["garbage"])

# ------------------------------------------------------------------ transcripts
def asst(sess, mid, rid, ts, usage, cwd=None):
    r = {"type": "assistant", "sessionId": sess, "timestamp": ts, "requestId": rid,
         "message": {"id": mid, "role": "assistant", "usage": usage, "content": []}}
    if cwd:
        r["cwd"] = cwd
    return r
def usr(sess, ts, cwd):
    return {"type": "user", "sessionId": sess, "timestamp": ts, "cwd": cwd, "message": {"role": "user", "content": "x"}}
def U(i=0, o=0, cc=0, cr=0):
    return {"input_tokens": i, "output_tokens": o, "cache_creation_input_tokens": cc, "cache_read_input_tokens": cr}
def wr(path, recs):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write("not json\n")
        for r in recs:
            f.write(json.dumps(r) + "\n")
P = MEM + "/projects/p1/"
wr(P + "SES-A1.jsonl", [
    usr("SES-A1", "2026-11-02T10:00:00Z", R1),
    asst("SES-A1", "m1", "r1", "2026-11-02T10:05:00Z", U(10, 5, 100, 1000)),
    asst("SES-A1", "m1", "r1", "2026-11-02T10:05:02Z", U(10, 20, 100, 1000)),
    asst("SES-A1", "m2", "r2", "2026-11-02T09:59:59Z", U(1000)),
    asst("SES-A1", "m3", "r3", "2026-11-02T10:30:01Z", U(2000)),
    asst("SES-A1", "m5", "r5", "2026-11-02T10:30:00Z", U(7)),
    asst("SES-A1", "m6", "r6", "2026-11-02T10:00:00Z", U(3)),
])
wr(P + "SES-A1/subagents/agent-1.jsonl", [
    asst("SES-A1", "m4", "r4", "2026-11-02T10:10:00Z", U(1, 2, 3, 4)),
    asst("SES-A1", "m1", "r1", "2026-11-02T10:05:03Z", U(10, 20, 100, 1000)),
])
wr(P + "SES-X.jsonl", [asst("SES-X", "mx", "rx", "2026-11-02T10:05:00Z", U(5000))])
wr(P + "SES-S2.jsonl", [usr("SES-S2", "2026-11-15T09:00:00Z", R1 + "/sub/dir")])
wr(P + "SES-A2.jsonl", [usr("SES-A2", "2026-11-20T08:30:00Z", R1)])
wr(P + "SES-B1.jsonl", [usr("SES-B1", "2026-11-03T09:00:00Z", R1)])
wr(P + "SES-U.jsonl", [usr("SES-U", "2026-11-04T09:00:00Z", R1X), usr("SES-U", "2026-11-04T09:01:00Z", RU)])
wr(P + "SES-A3.jsonl", [asst("SES-A3", "m7", "r7", "2026-07-31T23:10:00Z", U(0, 50), cwd=R1)])
wr(P + "SES-S3.jsonl", [usr("SES-S3", "2026-12-05T09:00:00Z", R1), usr("SES-S3", "2026-07-31T23:30:00Z", R1)])
wr(P + "SES-S4.jsonl", [usr("SES-S4", "2026-10-05T09:00:00Z", R1)])
wr(P + "SES-S5.jsonl", [usr("SES-S5", "2026-06-05T09:00:00Z", R1)])
wr(P + "SES-A4.jsonl", [asst("SES-A4", "m8", "r8", "2026-12-10T11:30:00Z", U(100), cwd=R1)])

# ------------------------------------------------------------------ run helper
ENV = dict(os.environ, FORGE_MEMBRANE=MEM, FORGE_PARE_LEDGER=LEDGER, FORGE_PARE_PROJECTS=ALLOW,
           GIT_CONFIG_GLOBAL=GITCFG, GIT_CONFIG_NOSYSTEM="1", PYTHONDONTWRITEBYTECODE="1")
NOW = "2026-12-20T00:00:00Z"
def scan(*args, env=None, cwd=None):
    e = dict(ENV)
    e.update(env or {})
    r = subprocess.run(["python3", "-B", "-I", SCAN] + list(args), env=e, capture_output=True, text=True, cwd=cwd)
    return r.returncode, r.stdout, r.stderr

# ------------------------------------------------------------------ pure helpers
chk("rnd half up", m.rnd(Fraction(5, 2)), 3)
chk("rnd below half", m.rnd(Fraction(7, 3)), 2)
chk("median even is the mean of the middle two", m.median([1, 2, 3, 6]), Fraction(5, 2))
chk("median odd", m.median([9, 1, 5]), Fraction(5))
chk("london month, summer midnight", m.london_month(m.parse_iso("2026-07-31T23:30:00Z")), "2026-08")
chk("london month, winter", m.london_month(m.parse_iso("2026-01-31T23:30:00Z")), "2026-01")

# ------------------------------------------------------------------ regret, one item at a time
def one(files=(), exports=(), ca=None, ts="2026-11-02T10:30:00Z", repo=R1):
    return {"repo": repo, "ts": m.parse_iso(ts),
            "rec": {"commit_after": ca or c1, "removed_items": {"files": list(files), "exports": list(exports)}}}
def ex(name, module="mod.py"):
    return [{"module": module, "name": name}]
chk("regret: file re-added within 30 days counts", m.regret_count(one(files=["old1.txt"])), (1, 1))
chk("regret: file re-added after 30 days does not", m.regret_count(one(files=["old2.txt"])), (0, 1))
chk("regret: file never re-added does not", m.regret_count(one(files=["old3.txt"])), (0, 1))
chk("regret: export re-added counts", m.regret_count(one(exports=ex("gone_fn"))), (1, 1))
chk("regret: unrelated line naming it does not", m.regret_count(one(exports=ex("other_fn"))), (0, 1))
chk("regret: a call site is not a declaration", m.regret_count(one(exports=ex("call_site_fn"))), (0, 1))
chk("regret: a declaration is", m.regret_count(one(exports=ex("decl_fn"))), (1, 1))
chk("regret: checked counts files and exports", m.regret_count(one(files=["old1.txt", "old3.txt"], exports=ex("decl_fn"))), (2, 3))
chk("regret: export re-added after window does not", m.regret_count(one(exports=ex("late_fn"))), (0, 1))
chk("regret: name must match whole word", m.regret_count(one(exports=ex("gone"))), (0, 1))
chk("regret: window start is the run ts (re-add before it does not count)",
    m.regret_count(one(files=["old1.txt"], ts="2026-11-10T12:00:01Z")), (0, 1))
chk("regret: window end is inclusive", m.regret_count(one(files=["old1.txt"], ts="2026-10-11T12:00:00Z")), (1, 1))
chk("regret: pathspec magic in a file item is literal (':/' does not match an unrelated added file)",
    m.regret_count(one(files=[":/"])), (0, 1))
chk("regret: pathspec magic in an export module is literal",
    m.regret_count(one(exports=ex("gone_fn", ":/"))), (0, 1))
chk("regret: commit_after not an ancestor is not read", m.regret_count(one(files=["old1.txt"], ca=cx)), None)
chk("regret: unknown commit is not read", m.regret_count(one(ca="1234567" * 2)), None)
chk("regret: non-git dir is not read", m.regret_count(one(repo=R2)), None)
chk("regret: missing dir is not read", m.regret_count(one(repo=T + "/nowhere")), None)
chk("regret: no commit_after is not read", m.regret_count({"repo": R1, "ts": 0, "rec": {}}), None)

# ------------------------------------------------------------------ bench key uniqueness (unit)
def bgroup(pts, ts, tok):
    return [{"slug": "p", "repo": "/r", "pass_ts": pts, "side": sd, "ts": m.epoch(ts), "task": "t",
             "passed": True, "total": tok} for sd in ("pre", "post", "noise") for _ in range(3)]
g_old, g_new = bgroup("2026-11-01T00:00:00Z", "2026-12-02T00:00:00Z", 10), bgroup("2026-11-02T00:00:00Z", "2026-12-03T00:00:00Z", 20)
for order, label in ((g_old + g_new, "older first"), (g_new + g_old, "newer first")):
    rows, inc, dropped = m.build_bench(order)
    chk("bench: same key keeps only the latest pass_ts (%s)" % label, (len(rows), rows[0]["pre_median"], dropped, inc), (1, 20, 1, 0))
rows, _, dropped = m.build_bench(g_old + bgroup("2026-12-01T00:00:00Z", "2026-12-03T00:00:00Z", 30))
chk("bench: different pass months are different keys", (len(rows), dropped), (2, 0))

# ------------------------------------------------------------------ end to end
rc, out, err = scan("--json", "--now", NOW)
chk("run exits 0", rc, 0)
doc = json.loads(out)
chk("snapshot written", os.path.exists(SNAP))
chk("snapshot file mode 600", stat.S_IMODE(os.stat(SNAP).st_mode), 0o600)
chk("snapshot equals stdout", json.load(open(SNAP)), doc)
chk("no temp files left", [f for f in os.listdir(T + "/state") if f.startswith(".tmp")], [])
chk("v and asof", (doc["v"], doc["asof"]), (1, "2026-12-20T00:00:00Z"))
chk("tables present", sorted(doc["tables"]), ["bench", "measures", "months", "passes"])

def mrow(project, month, **kw):
    r = {c: 0 for c in m.MONTH_COLS}
    r.update(kw, project=project, month=month)
    return r
exp_months = [
    mrow("proj-a", "2026-08", passes=1, proven_kept=1, cuts_kept=1, lines_removed=4, files_removed=1,
         pass_tokens=50, pass_cost_read=1, sessions=2, window_closed=1),
    mrow("proj-a", "2026-09", bench_tokens=50, window_closed=1),
    mrow("proj-a", "2026-10", sessions=1, window_closed=1),
    mrow("proj-a", "2026-11", passes=4, proven_kept=3, proven_reverted=1, judgement_kept=1,
         judgement_reverted=1, reverts=2, cuts_kept=4, cuts_regretted=2, regret_read=1,
         regret_items_checked=6, guard_trips=1,
         lines_removed=107, files_removed=3, exports_removed=3, packages_removed=2,
         advisories_removed=2, pass_tokens=1150, pass_cost_read=1, bench_tokens=4830, sessions=4,
         window_closed=0),
    mrow("proj-a", "2026-12", passes=2, judgement_kept=1,
         cuts_kept=1, guard_trips=1, lines_removed=50, advisories_removed=1, pass_tokens=100, pass_cost_read=1, bench_tokens=720,
         sessions=1, window_closed=0),
    mrow("proj-b", "2026-11", passes=1, window_closed=1),
]
chk("months table (gap months with only sessions or bench get a row; sessions before the first pass do not)",
    doc["tables"]["months"], exp_months)

# Nov: A1 + A6 summed pairwise (A2 report_only and A7 failed excluded; null side = pair skipped);
# Dec: A4 completed, only source_tokens has both sides
exp_measures = []
for k, (b, a) in {"source_tokens": (1300, 1150), "packages": (15, 13), "advisories": (3, 2),
                  "bundle_bytes": (2000, 1950), "build_ms": (100, 95), "test_ms": (500, 400),
                  "typecheck_ms": (50, 48)}.items():
    exp_measures.append({"project": "proj-a", "month": "2026-11", "measure": k, "before": b, "after": a})
exp_measures.append({"project": "proj-a", "month": "2026-12", "measure": "source_tokens", "before": 100, "after": 90})
exp_measures.sort(key=lambda r: (r["project"], r["month"], r["measure"]))
chk("measures table", doc["tables"]["measures"], exp_measures)

chk("bench table (older same-key group and incomplete groups left out; tasks_checked 1 of 2)", doc["tables"]["bench"], [{
    "project": "proj-a", "pass_month": "2026-11", "run_month": "2026-12", "pre_median": 375,
    "post_median": 80, "noise_floor": 25, "runs_pre": 3, "runs_post": 3, "tasks": 2, "tasks_checked": 1,
    "tasks_passed_pre": 1, "tasks_passed_post": 2}])

def prow(day, seq, wc, gt, ro, project="proj-a"):
    return {"project": project, "day": day, "seq": seq, "window_closed": wc, "guard_tripped": gt, "report_only": ro}
chk("passes table", doc["tables"]["passes"], [
    prow("2026-08-01", 1, 1, 0, 0), prow("2026-11-02", 1, 1, 0, 0), prow("2026-11-20", 1, 0, 1, 1),
    prow("2026-11-25", 1, 0, 0, 0), prow("2026-11-26", 1, 0, 0, 0),
    prow("2026-12-10", 1, 0, 1, 0), prow("2026-12-10", 2, 0, 0, 1), prow("2026-11-05", 1, 1, 0, 0, "proj-b")])

chk("stderr: unlisted count only", "2 records left out (repo not in allow-list)" in err and R1 not in err and RU not in err)
chk("stderr: bad ledger lines counted (4 runs ledger + 2 bench)", "6 bad ledger lines skipped" in err)
chk("stderr: incomplete bench groups counted", "2 incomplete bench groups left out" in err)
chk("stderr: dropped same-key bench group counted", "1 bench groups dropped" in err)

# leaks
blob = out + open(SNAP).read()
secrets = [T, "repos/", "SES-", "toolname-secret", "ADV-SECRET", "task-secret", "pkg-x", "old1.txt", "gone_fn",
           "outcome", "verdict", c0, c1, c2, c3, cx, c1[:7], "b" * 40, "d" * 40, "abc1234def"]
leaks = [s for s in secrets if s in blob]
chk("snapshot holds no path, session, sha, advisory, task, tool or item name", leaks, [])
def walk(v, path=""):
    if isinstance(v, dict):
        for k, x in v.items():
            yield from walk(x, path + "/" + k)
    elif isinstance(v, list):
        for x in v:
            yield from walk(x, path)
    else:
        yield path, v
vals = list(walk(doc["tables"]))
chk("no null, no bool, no float: only ints and strings", [p for p, v in vals if type(v) not in (int, str)], [])
for t in ("months", "measures", "bench", "passes"):
    keysets = {tuple(sorted(r)) for r in doc["tables"][t]}
    chk("every row of %s has the same columns" % t, len(keysets), 1)

chk("months columns", sorted(doc["tables"]["months"][0]), sorted(["project", "month"] + m.MONTH_COLS))
chk("regret_items_checked and tasks_checked are columns",
    ("regret_items_checked" in doc["tables"]["months"][0], "tasks_checked" in doc["tables"]["bench"][0]), (True, True))

# --now drives window_closed (the latest Nov pass, A7 at 26 Nov 10:00, closes its month at +30 days)
rc, out2, _ = scan("--json", "--no-write", "--now", "2026-12-26T10:00:00Z")
d2 = json.loads(out2)
chk("now at the window end (inclusive): Nov closed", [r["window_closed"] for r in d2["tables"]["months"] if r["month"] == "2026-11" and r["project"] == "proj-a"], [1])
chk("now at the window end: the 26 Nov pass closed", [r["window_closed"] for r in d2["tables"]["passes"] if r["day"] == "2026-11-26"], [1])
rc, out3, _ = scan("--json", "--no-write", "--now", "2026-12-26T09:59:59Z")
chk("one second earlier: Nov open", [r["window_closed"] for r in json.loads(out3)["tables"]["months"] if r["month"] == "2026-11" and r["project"] == "proj-a"], [0])
rc, out4, _ = scan("--json", "--no-write", "--now", "2027-02-01T00:00:00Z")
chk("far future: every month closed", {r["window_closed"] for r in json.loads(out4)["tables"]["months"]}, {1})
rc, out5, _ = scan("--json", "--no-write")
chk("real clock: asof shape", bool(re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ", json.loads(out5)["asof"])))

# --no-write
os.remove(SNAP)
rc, _, _ = scan("--no-write", "--now", NOW)
chk("--no-write writes nothing", (rc, os.path.exists(SNAP)), (0, False))
rc, txt, _ = scan("--now", NOW)
chk("plain run prints a short summary and writes", (rc, txt.count("\n"), os.path.exists(SNAP)), (0, 1, True))

# allow-list missing / unlisted / bench sessions
rc, out6, err6 = scan("--json", "--no-write", "--now", NOW, env={"FORGE_PARE_PROJECTS": T + "/cfg/none.json"})
chk("missing allow-list: exit 0, all tables empty, stderr note",
    (rc, json.loads(out6)["tables"], "allow-list missing" in err6),
    (0, {"months": [], "measures": [], "bench": [], "passes": []}, True))

# bench runs keep no transcripts: with no bench ledger the session count is unchanged
jl(BENCHF, [])
rc, out7, _ = scan("--json", "--no-write", "--now", NOW)
nov = [r for r in json.loads(out7)["tables"]["months"] if r["project"] == "proj-a" and r["month"] == "2026-11"][0]
chk("without bench ledger: sessions unchanged, no bench tokens", (nov["sessions"], nov["bench_tokens"]), (4, 0))

# errors
rc, _, err8 = scan("--no-write", env={"FORGE_MEMBRANE": T + "/nomem"})
chk("missing transcripts dir exits 2 with a reason and no path", (rc, "transcripts directory not found" in err8, T in err8, "nomem" in err8), (2, True, False, False))
rc, _, err9 = scan("--no-write", env={"FORGE_PARE_LEDGER": T + "/state"})
chk("unusable ledger path exits 2, stderr names the error class only", (rc, T in err9, "IsADirectoryError" in err9), (2, False, True))

# FORGE_PARE_LEDGER=off and relative paths
CW = T + "/cwd"
os.makedirs(CW, exist_ok=True)
if os.path.exists(SNAP):
    os.remove(SNAP)
rc, outo, erro = scan("--json", "--now", NOW, env={"FORGE_PARE_LEDGER": "off"}, cwd=CW)
chk("ledger off: exit 0, empty tables on stdout, stderr note",
    (rc, json.loads(outo)["tables"], "FORGE_PARE_LEDGER=off" in erro),
    (0, {"months": [], "measures": [], "bench": [], "passes": []}, True))
chk("ledger off: nothing written in cwd, state dir or HOME state",
    (os.listdir(CW), os.path.exists(SNAP), os.path.exists(os.environ["HOME"] + "/.local")), ([], False, False))
rc, outp, _ = scan(env={"FORGE_PARE_LEDGER": "off"}, cwd=CW)
chk("ledger off: plain run still prints a summary", (rc, outp.startswith("pare-scan: ")), (0, True))
rc, _, errr = scan("--now", NOW, env={"FORGE_PARE_LEDGER": "rel/runs.jsonl"}, cwd=CW)
chk("relative ledger path: exit 2, nothing written in cwd, no path echoed",
    (rc, os.listdir(CW), "rel/runs" in errr), (2, [], False))
rc, _, _ = scan("--now", NOW, env={"FORGE_PARE_LEDGER": "runs.jsonl"}, cwd=CW)
chk("bare relative ledger name: exit 2, cwd untouched", (rc, os.listdir(CW)), (2, []))
rc, out10, _ = scan("--json", "--no-write", "--now", NOW, env={"FORGE_PARE_LEDGER": T + "/state/absent.jsonl"})
chk("missing ledger: exit 0, empty tables", (rc, json.loads(out10)["tables"]["months"]), (0, []))
rc, _, _ = scan("--now", "garbage")
chk("bad --now is an argument error", rc, 2)

# replacing an existing snapshot keeps mode 600
scan("--now", NOW)
os.chmod(SNAP, 0o644)
scan("--now", NOW)
chk("replacing keeps mode 600", stat.S_IMODE(os.stat(SNAP).st_mode), 0o600)

sys.exit(1 if bad else 0)
PY
RC=$?
echo
if [ "$RC" = 0 ]; then echo "all passed"; else echo "FAILED"; exit 1; fi
