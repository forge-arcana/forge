#!/usr/bin/env bash
#
# Tests for llm-delegate-scan.py. Synthetic transcripts and ledger in a temp
# HOME; never reads the real membrane or ledger.
# Run:  bash core/scripts/tests/test-llm-delegate-scan.sh      (non-zero on failure)

HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.."
SCAN="$HERE/llm-delegate-scan.py"
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
export PYTHONDONTWRITEBYTECODE=1   # never leave __pycache__ beside the script under test
mkdir -p "$TMPD/home"; export HOME="$TMPD/home"
export FORGE_MEMBRANE="$TMPD/mem"
export FORGE_LLM_LEDGER="$TMPD/state/calls.jsonl"
unset XDG_STATE_HOME
mkdir -p "$FORGE_MEMBRANE/projects/p1/S1/subagents" "$TMPD/state"

FAILS=0
check() { if [ "$2" = 0 ]; then echo "PASS  $1"; else echo "FAIL  $1  (${3:-})"; FAILS=$((FAILS + 1)); fi; }
eq() { [ "$2" = "$3" ] && check "$1" 0 || check "$1" 1 "got=$2 want=$3"; }

# --- fixture generator (all synthetic) -----------------------------------
python3 -I - "$TMPD" <<'PY'
import json, math, sys
T = sys.argv[1]
SES = "S1"
def ts(h, m=0, s=0, day=10): return "2026-07-%02dT%02d:%02d:%02d.000Z" % (day, h, m, s)
def asst(mid, t, out, blocks, sess=SES, req=None):
    return {"type": "assistant", "sessionId": sess, "timestamp": t, "requestId": req or "r" + mid,
            "message": {"id": mid, "role": "assistant", "model": "m-test",
                        "usage": {"output_tokens": out}, "content": blocks}}
def bash(tid, cmd): return {"type": "tool_use", "id": tid, "name": "Bash", "input": {"command": cmd}}
def res(tid, t, text, err=False, sess=SES):
    return {"type": "user", "sessionId": sess, "timestamp": t, "message": {"role": "user", "content": [
        {"type": "tool_result", "tool_use_id": tid, "content": text, "is_error": err}]}}
def write(tid, content): return {"type": "tool_use", "id": tid, "name": "Write", "input": {"file_path": "/x/f", "content": content}}
def edit(tid, new): return {"type": "tool_use", "id": tid, "name": "Edit", "input": {"file_path": "/x/f", "old_string": "a", "new_string": new}}
H = "/srv/forge/core/scripts/llm-delegate.sh"
def lines(tag, n): return "\n".join("%s output line number %d here" % (tag, i) for i in range(n))
A, B, C, D, G, Hh = (lines("alpha", 5), lines("beta", 4), "llm-delegate.sh: no reachable endpoint found",
                     lines("delta", 4), lines("gamma", 3) + "\n[200 tokens, 4.0s, 50.0 tok/s, model: m-stat]", lines("eta", 4))
main = []
# A used (10:00, session ledger)
main += [asst("a1", ts(10), 60, [bash("tA", H + " 'make a thing'")]), res("tA", ts(10, 0, 5), A),
         asst("a2", ts(10, 2), 11, [write("wA", "header\n" + A + "\nfooter")])]
# B redone (11:00, ledger without session), then 3 counted + 1 beyond-cap edit turns; the b4 turn is
# one message id streamed as three records with different timestamps and growing output_tokens
txt = lambda s: {"type": "text", "text": s}
b4s = [asst("b4", ts(11, 4, 0), 5, [write("wB2", "unrelated rewrite line one number two")]),
       asst("b4", ts(11, 4, 2), 18, [txt("x")]), asst("b4", ts(11, 4, 5), 30, [txt("y")])]
main += [asst("b1", ts(11), 50, [bash("tB", "env X=1 bash " + H + " < /tmp/p")]), res("tB", ts(11, 0, 5), B),
         asst("b2", ts(11, 2), 25, [edit("wB1", "completely different code appears right here")]),
         *b4s,
         asst("b5", ts(11, 5), 35, [write("wB3", "another unrelated rewrite line three")]),
         asst("b6", ts(11, 6), 99, [write("wB4", "fourth unrelated rewrite beyond the cap")])]
# C fallback (12:00) then a rewrite turn within 10 min
main += [asst("c1", ts(12), 40, [bash("tC", "testgate -- " + H + " --x 'p'")]), res("tC", ts(12, 0, 5), C, True),
         asst("c2", ts(12, 3), 50, [write("wC", "the assistant wrote this itself entirely")])]
# D unknown (13:00), two tool_use blocks in one turn (wrap split), nothing after
main += [asst("d1", ts(13), 100, [bash("tD", "echo p | " + H), bash("tD2", "ls /tmp")]), res("tD", ts(13, 0, 5), D)]
# H: 23:30 UTC in summer = 00:30 next London day
main += [asst("h1", ts(23, 30), 20, [bash("tH", H + " 'x'")]), res("tH", ts(23, 30, 5), Hh)]
# non-executing mentions (must not count)
main += [asst("n1", ts(18), 5, [bash("tN1", "cat " + H)]), asst("n2", ts(18, 1), 5, [bash("tN2", "git log -- " + H)]),
         asst("n3", ts(18, 2), 5, [bash("tN3", "grep -n curl " + H + " | head")])]
with open(T + "/mem/projects/p1/S1.jsonl", "w") as f:
    f.write("not json at all\n")
    for r in main: f.write(json.dumps(r) + "\n")
# G: older than ledger, stat line only, in a subagent transcript
sub = [asst("g1", ts(17), 30, [bash("tG", H + " 'x'")]), res("tG", ts(17, 0, 5), G),
       asst("g2", ts(17, 1), 9, [write("wG", lines("gamma", 3))])]
with open(T + "/mem/projects/p1/S1/subagents/agent-1.jsonl", "w") as f:
    for r in sub: f.write(json.dumps(r) + "\n")
def L(t, **k):
    d = {"v": 1, "ts": t, "wall_ms": 0, "model": "m-test", "eval_tokens": 0, "prompt_tokens": 0, "exit": 0,
         "outcome": "ok", "session": None}; d.update(k); return json.dumps(d)
led = [L(ts(10, 0, 3), session=SES, eval_tokens=100, prompt_tokens=10, wall_ms=2000),
       L(ts(11, 0, 3), eval_tokens=80, prompt_tokens=20, wall_ms=3000),
       L(ts(12, 0, 3), session=SES, exit=1, outcome="unreachable", wall_ms=100),
       L(ts(13, 0, 3), eval_tokens=60, prompt_tokens=30, wall_ms=4000),
       L(ts(23, 30, 3), eval_tokens=10, wall_ms=1000),
       L(ts(16), eval_tokens=40, prompt_tokens=5, wall_ms=1000, outcome="truncated"),
       "garbage {{", "[1,2]"]
open(T + "/state/calls.jsonl", "w").write("\n".join(led) + "\n")
ex = {"wA": math.ceil(len(A) / 4), "wB": math.ceil(len(B) / 4), "wC": math.ceil(len(C) / 4),
      "wD": math.ceil(len(D) / 4), "wG": math.ceil(len(G) / 4), "wH": math.ceil(len(Hh) / 4)}
json.dump(ex, open(T + "/exp.json", "w"))
PY

jget() { python3 -I -c 'import json,sys
d=json.load(open(sys.argv[1]))
for k in sys.argv[2].split("."): d=d[k]
print(json.dumps(d) if isinstance(d,(dict,list)) else d)' "$1" "$2"; }
wrapexp() { python3 -I -c 'import json,sys
e=json.load(open(sys.argv[1])); print(eval(sys.argv[2],{},e))' "$TMPD/exp.json" "$1"; }

# --- unit tests of pure functions -----------------------------------------
python3 -I - "$SCAN" <<'PY'
import importlib.util, sys, datetime as dt
sys.dont_write_bytecode = True   # python -I ignores PYTHONDONTWRITEBYTECODE
spec = importlib.util.spec_from_file_location("scan", sys.argv[1]); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
bad = 0
def chk(name, got, want):
    global bad
    ok = got == want
    print(("PASS  " if ok else "FAIL  ") + name + ("" if ok else "  (got=%r want=%r)" % (got, want)))
    bad += (not ok)
P = "/srv/forge/core/scripts/llm-delegate.sh"
for name, cmd, want in [
    ("classify: direct path", P + " 'x'", True),
    ("classify: bash path", "bash " + P + " --a b", True),
    ("classify: sh path", "sh " + P, True),
    ("classify: env prefix", "env FOO=1 BAR=2 " + P + " x", True),
    ("classify: inline VAR=", "FOO=1 " + P + " x", True),
    ("classify: testgate --", "testgate -- " + P + " x", True),
    ("classify: piped into it", "echo hi | " + P, True),
    ("classify: command substitution", "OUT=$(" + P + " 'x')", True),
    ("classify: after &&", "true && " + P + " x", True),
    ("classify: bash -c", "bash -c '" + P + " x'", True),
    ("classify: cat", "cat " + P, False),
    ("classify: grep", "grep -n curl " + P, False),
    ("classify: rg", "rg foo " + P, False),
    ("classify: head/tail/sed/wc/ls", "head -5 " + P + " ; tail " + P + " ; sed -n 1p " + P + " ; wc -l " + P + " ; ls -l " + P, False),
    ("classify: git", "git log -- " + P, False),
    ("classify: editor", "vim " + P, False),
    ("classify: pipe from cat", "cat " + P + " | head", False),
    ("classify: heredoc body mention", "cat <<'EOF'\n" + P + " x\nEOF", False),
    ("classify: not mentioned", "ls", False),
    ("classify: double-quoted command substitution", 'OUT="$(' + P + " 'x')\"", True),
    ("classify: double-quoted backticks", 'OUT="`' + P + ' x`"', True),
    ("classify: bash -lc", 'bash -lc "' + P + ' x"', True),
    ("classify: bash -ec", "bash -ec '" + P + " x'", True),
    ("classify: bash -n does not execute", "bash -n " + P, False),
    ("classify: sh -n does not execute", "sh -n " + P, False),
    ("classify: timeout -s KILL", "timeout -s KILL 600 " + P + " x", True),
    ("classify: timeout --signal=KILL", "timeout --signal=KILL 600 " + P + " x", True),
    ("classify: timeout plain duration", "timeout 600 " + P + " x", True),
    ("classify: herestring does not start a heredoc", "cat <<< word\n" + P + " x\nword", True),
    ("classify: << in arithmetic is not a heredoc", "x=$((1<<N))\n" + P + " x\nN", True),
    ("classify: commit message heredoc in substitution", "git commit -m \"$(cat <<'EOF'\n" + P + " x\nEOF\n)\"", False),
    ("classify: quoted substitution that only reads it", 'echo "$(cat ' + P + ')"', False),
]: chk(name, m.classify_command(cmd), want)
# pairing: same session first, then nearest in time whatever the session; one-to-one; +-30 s edge
C = lambda s, e, sess="s": {"start": s, "end": e, "session": sess}
Lg = lambda t, sess=None: {"_ts": t, "session": sess}
chk("pair: session mismatch inside window pairs by time", m.pair_ledger([C(100, 105)], [Lg(102, "other")]), ({0: 0}, []))
chk("pair: two calls 10 s apart pair one-to-one with their own lines",
    m.pair_ledger([C(100, 160), C(110, 170)], [Lg(101, "s"), Lg(111, "s")]), ({0: 0, 1: 1}, []))
chk("pair: same session wins over a nearer foreign line", m.pair_ledger([C(100, 105)], [Lg(100, "x"), Lg(120, "s")]), ({0: 1}, [0]))
chk("pair: edge start-30 pairs", m.pair_ledger([C(100, 105)], [Lg(70)])[0], {0: 0})
chk("pair: start-31 does not", m.pair_ledger([C(100, 105)], [Lg(69)])[0], {})
chk("pair: end+30 pairs", m.pair_ledger([C(100, 105)], [Lg(135)])[0], {0: 0})
chk("pair: end+31 does not", m.pair_ledger([C(100, 105)], [Lg(136)])[0], {})
chk("pair: a line is used once", m.pair_ledger([C(100, 105), C(101, 106)], [Lg(102)]), ({1: 0}, []))
chk("stat line", m.parse_stat_line("a\n[12 tokens, 3.5s, 3.4 tok/s, model: q]\n"), (12, 3.5, "q"))
chk("exit: code marker", m.infer_exit("x\n[exited with code 2]", False), 2)
chk("exit: helper stderr", m.infer_exit("llm-delegate.sh: empty response from endpoint", False), 1)
chk("exit: stat line is ok", m.infer_exit("[1 tokens, 1.0s, 1.0 tok/s, model: q]", False), 0)
L = ["abcdefghijkl%d" % i for i in range(5)]
chk("overlap: 3 of 5", m.overlap_fraction(L, [set(L[:3])]), 0.6)
chk("overlap: union of edits", m.overlap_fraction(L, [set(L[:2]), set(L[2:4])]), 0.8)
chk("class: used at 60%", m.classify_call(0, L, 0.6, True), "used")
chk("class: 59% is unknown/redone", m.classify_call(0, L, 0.59, True), "unknown")
chk("class: redone under 20%", m.classify_call(0, L, 0.19, True), "redone")
chk("class: no edit is unknown", m.classify_call(0, L, 0.0, False), "unknown")
chk("class: short text needs all", m.classify_call(0, L[:2], 0.5, True), "unknown")
chk("class: short text all present", m.classify_call(0, L[:2], 1.0, True), "used")
chk("class: nonzero exit", m.classify_call(1, L, 1.0, True), "fallback")
chk("london: summer 23:30Z is next day", str(m.london_day(m.parse_ts("2026-07-10T23:30:00Z"))), "2026-07-11")
chk("london: winter 23:30Z same day", str(m.london_day(m.parse_ts("2026-01-10T23:30:00Z"))), "2026-01-10")
d = dt.date(2026, 7, 20)
def rows(calls, net, n=1):
    return {d - dt.timedelta(days=i): {"calls": calls // n, "net_tokens": net // n} for i in range(n)}
chk("verdict: 9 calls", m.verdict(rows(9, 500), d)["verdict"], "too-little-data")
chk("verdict: 10 calls net +1", m.verdict(rows(10, 1), d)["verdict"], "helping")
chk("verdict: 10 calls net 0", m.verdict(rows(10, 0), d)["verdict"], "burning")
chk("verdict: 10 calls net -1", m.verdict(rows(10, -1), d)["verdict"], "burning")
r = rows(5, 10); r[d - dt.timedelta(days=13)] = {"calls": 5, "net_tokens": 10}; r[d - dt.timedelta(days=14)] = {"calls": 50, "net_tokens": -999}
v = m.verdict(r, d)
chk("verdict: 14-day boundary", (v["trailing_calls"], v["trailing_net_tokens"], v["verdict"]), (10, 20, "helping"))
sys.exit(1 if bad else 0)
PY
UNIT=$?; [ "$UNIT" = 0 ] || FAILS=$((FAILS + 1))

# --- end-to-end -----------------------------------------------------------
OUT="$TMPD/state/daily/2026-07-10.json"
python3 -I "$SCAN" --date 2026-07-10 >"$TMPD/stdout.txt" 2>"$TMPD/stderr.txt"
eq "run exits 0" "$?" 0
[ -s "$OUT" ] && check "daily file written" 0 || check "daily file written" 1
eq "file mode 600" "$(stat -c %a "$OUT")" 600
eq "no temp files left" "$(ls -A "$TMPD/state/daily" | grep -c '^\.tmp')" 0
n() { jget "$OUT" "numbers.$1"; }
eq "calls (A,B,C,D,G + 1 unattributed)" "$(n calls)" 6
eq "ok" "$(n ok)" 5
eq "fallback (C)" "$(n fallback)" 1
eq "truncated" "$(n truncated)" 1
eq "unattributed ledger line" "$(n unattributed)" 1
eq "used (A, G)" "$(n used)" 2
eq "redone (B)" "$(n redone)" 1
eq "unknown (D)" "$(n unknown)" 1
eq "success rate" "$(n success_rate_pct)" 83.3
eq "fallback rate" "$(n fallback_rate_pct)" 16.7
eq "local tokens (100+80+60+40+200 stat)" "$(n local_tokens)" 480
eq "local prompt tokens" "$(n local_prompt_tokens)" 65
eq "local seconds (10.1 ledger + 4.0 stat)" "$(n local_seconds)" 14
eq "saved (A full 100 + G stat 200)" "$(n saved_tokens)" 300
WRAP=$(wrapexp "60+wA + 50+wB + 40+wC + 100//2+wD + 30+wG")
eq "wrap (split across 2 blocks for D, dedup'd turns)" "$(n wrap_tokens)" "$WRAP"
eq "redo (B 25+30+35 capped at 3, deduped; C 50)" "$(n redo_tokens)" 140
eq "net" "$(n net_tokens)" "$((300 - WRAP - 140))"
eq "bad ledger lines" "$(n bad_ledger_lines)" 2
eq "transcripts scanned" "$(n transcripts_scanned)" 2
eq "skipped transcripts" "$(n skipped_transcripts)" 0
eq "join misses (G has no ledger line but the ledger had begun)" "$(n join_misses)" 1
eq "models from ledger and stat" "$(jget "$OUT" models)" '{"m-stat": 1, "m-test": 5}'
eq "verdict too little data" "$(jget "$OUT" verdict.verdict)" too-little-data
eq "trailing calls" "$(jget "$OUT" verdict.trailing_calls)" 6
eq "method present" "$(jget "$OUT" method | grep -c 'trailing 14 days')" 1
grep -q 'm-test\|m-stat' "$TMPD/stdout.txt" && check "text output names no model id" 1 || check "text output names no model id" 0
eq "text summary is 6-10 lines" "$([ "$(wc -l <"$TMPD/stdout.txt")" -ge 6 ] && [ "$(wc -l <"$TMPD/stdout.txt")" -le 10 ] && echo yes)" yes
eq "method is built from the constants" "$(jget "$OUT" method | grep -c 'used >=60%, redone <20%; under 3 distinct lines')" 1

# day boundary: H (23:30Z) lands on 2026-07-11; trailing includes 07-10
python3 -I "$SCAN" --date 2026-07-11 --json >"$TMPD/j11.json"
eq "next-day call count" "$(jget "$TMPD/j11.json" numbers.calls)" 1
eq "next-day unknown" "$(jget "$TMPD/j11.json" numbers.unknown)" 1
eq "next-day wrap" "$(jget "$TMPD/j11.json" numbers.wrap_tokens)" "$(wrapexp "20+wH")"
eq "next-day trailing calls" "$(jget "$TMPD/j11.json" verdict.trailing_calls)" 7
eq "--json to stdout and file both" "$(jget "$TMPD/state/daily/2026-07-11.json" numbers.calls)" 1

# quiet day: all zeros, file still written
python3 -I "$SCAN" --date 2026-07-12 >/dev/null
Q="$TMPD/state/daily/2026-07-12.json"
eq "quiet day calls" "$(jget "$Q" numbers.calls)" 0
eq "quiet day rates" "$(jget "$Q" numbers.success_rate_pct)/$(jget "$Q" numbers.fallback_rate_pct)" "0/0"
eq "quiet day net" "$(jget "$Q" numbers.net_tokens)" 0
eq "quiet day verdict" "$(jget "$Q" verdict.verdict)" too-little-data
eq "quiet day trailing calls" "$(jget "$Q" verdict.trailing_calls)" 7

# --no-write
rm -rf "$TMPD/state/daily"
python3 -I "$SCAN" --date 2026-07-10 --no-write --json >"$TMPD/nw.json"
eq "--no-write still prints" "$(jget "$TMPD/nw.json" numbers.calls)" 6
[ -e "$TMPD/state/daily" ] && check "--no-write writes nothing" 1 || check "--no-write writes nothing" 0

# a since/until range prints a list, writes N files; bad ledger lines land on the last day only
python3 -I "$SCAN" --since 2026-07-10 --until 2026-07-12 >/dev/null
eq "range writes 3 files" "$(ls "$TMPD/state/daily" | wc -l)" 3
eq "bad ledger lines only on the report date" "$(jget "$TMPD/state/daily/2026-07-10.json" numbers.bad_ledger_lines)/$(jget "$TMPD/state/daily/2026-07-11.json" numbers.bad_ledger_lines)/$(jget "$TMPD/state/daily/2026-07-12.json" numbers.bad_ledger_lines)" "0/0/2"
BF_STATE="$TMPD/bfstate"
python3 -I "$SCAN" --backfill 3 --state-dir "$BF_STATE" >/dev/null
eq "backfill writes 3 files" "$(ls "$BF_STATE/daily" | wc -l)" 3

# S10: the modes are mutually exclusive
for combo in "--date 2026-07-10 --backfill 2" "--date 2026-07-10 --since 2026-07-09" "--backfill 2 --until 2026-07-10" "--backfill 2 --since 2026-07-09"; do
  python3 -I "$SCAN" $combo --no-write >/dev/null 2>"$TMPD/mx.err"
  eq "exclusive: $combo" "$?/$(grep -c 'not allowed with' "$TMPD/mx.err")" "2/1"
done
python3 -I "$SCAN" --since 2026-07-10 --until 2026-07-11 --no-write >/dev/null 2>&1
eq "since+until together is one mode" "$?" 0

# old transcript is skipped by mtime
touch -d "2026-01-01" "$FORGE_MEMBRANE/projects/p1/S1.jsonl" "$FORGE_MEMBRANE/projects/p1/S1/subagents/agent-1.jsonl"
python3 -I "$SCAN" --date 2026-07-10 --no-write --json >"$TMPD/old.json"
eq "stale transcripts skipped (only the ledger line remains)" "$(jget "$TMPD/old.json" numbers.calls)/$(jget "$TMPD/old.json" numbers.unattributed)" "5/5"

# missing ledger is fine
FORGE_LLM_LEDGER="$TMPD/none/calls.jsonl" python3 -I "$SCAN" --date 2026-07-10 --no-write --json >"$TMPD/nl.json"
eq "missing ledger exits 0" "$?" 0
eq "missing ledger: no calls (transcripts stale)" "$(jget "$TMPD/nl.json" numbers.calls)" 0

# missing ledger, fresh transcripts: calls still counted, exit inferred
touch "$FORGE_MEMBRANE/projects/p1/S1.jsonl" "$FORGE_MEMBRANE/projects/p1/S1/subagents/agent-1.jsonl"
FORGE_LLM_LEDGER="$TMPD/none/calls.jsonl" python3 -I "$SCAN" --date 2026-07-10 --no-write --json >"$TMPD/nl2.json"
eq "no ledger: transcript calls counted" "$(jget "$TMPD/nl2.json" numbers.calls)" 5
eq "no ledger: fallback inferred from helper stderr" "$(jget "$TMPD/nl2.json" numbers.fallback)" 1
eq "no ledger: unattributed 0" "$(jget "$TMPD/nl2.json" numbers.unattributed)" 0

# empty ledger file, bad args
: >"$TMPD/state/calls.jsonl"
python3 -I "$SCAN" --date 2026-07-10 --no-write --json >"$TMPD/el.json"
eq "empty ledger exits 0" "$?" 0
python3 -I "$SCAN" --date nonsense >/dev/null 2>&1
eq "bad date is an error" "$([ $? -ne 0 ] && echo err)" err

# --- scenario cases (own membrane + ledger each; 2026-07-14) ----------------
python3 -I - "$TMPD" <<'PY'
import json, math, os, sys
T = sys.argv[1]
H = "/srv/forge/core/scripts/llm-delegate.sh"
def ts(h, m=0, s=0): return "2026-07-14T%02d:%02d:%02d.000Z" % (h, m, s)
def asst(mid, t, out, blocks, sess):
    return {"type": "assistant", "sessionId": sess, "timestamp": t, "requestId": "r" + mid,
            "message": {"id": mid, "role": "assistant", "usage": {"output_tokens": out}, "content": blocks}}
def bash(tid, cmd): return {"type": "tool_use", "id": tid, "name": "Bash", "input": {"command": cmd}}
def write(tid, c): return {"type": "tool_use", "id": tid, "name": "Write", "input": {"file_path": "/x/f", "content": c}}
def res(tid, t, text, sess):
    return {"type": "user", "sessionId": sess, "timestamp": t, "message": {"role": "user", "content": [
        {"type": "tool_result", "tool_use_id": tid, "content": text, "is_error": False}]}}
def case(name, sess, recs, led=None, fname=None):
    d = "%s/c/%s" % (T, name)
    os.makedirs(d + "/mem/projects/p", exist_ok=True)
    with open("%s/mem/projects/p/%s.jsonl" % (d, fname or sess), "w") as f:
        for r in recs: f.write(json.dumps(r) + "\n")
    if led is not None:
        with open(d + "/calls.jsonl", "w") as f:
            for l in led: f.write(json.dumps(l) + "\n")
def L(t, **k):
    d = {"v": 1, "ts": t, "wall_ms": 1000, "model": "m-test", "eval_tokens": 5, "prompt_tokens": 1,
         "exit": 0, "outcome": "ok", "session": None}; d.update(k); return d
OKTXT = "[5 tokens, 1.0s, 5.0 tok/s, model: m-stat]"
one = lambda sess: [asst("a1", ts(10), 20, [bash("t1", H + " 'x'")], sess), res("t1", ts(10, 0, 5), OKTXT, sess)]
# S5a: ledger line carries another session id, inside the window: pairs by time, counts once
case("s5a", "S5", one("S5"), [L(ts(10, 0, 3), session="OTHER")])
# S5b: the ledger had begun (08:00) but has nothing near the call: counted once from the transcript, flagged
case("s5b", "S5", one("S5"), [L(ts(8))])
# S5c: the call predates the ledger (12:00): not a miss
case("s5c", "S5", one("S5"), [L(ts(12))])
# S6: three fallbacks within two minutes, then three edit turns: redo is the turns' sum once
FB = "llm-delegate.sh: no reachable Ollama endpoint found"
rec = []
for i, (m, s) in enumerate([(0, 0), (0, 40), (1, 20)]):
    rec += [asst("f%d" % i, ts(10, m, s), 10, [bash("tf%d" % i, H + " 'x'")], "S6"), res("tf%d" % i, ts(10, m, s + 5), FB, "S6")]
for i, (m, out) in enumerate([(2, 10), (3, 20), (4, 40)]):
    rec.append(asst("e%d" % i, ts(10, m), out, [write("we%d" % i, "line of code number %d is here" % i)], "S6"))
case("s6", "S6", rec)
# S8: one message id streamed as three records, growing output_tokens
sr = [asst("m1", ts(10, 0, 0), 5, [bash("t8", H + " 'x'")], "S8"), asst("m1", ts(10, 0, 1), 18, [{"type": "text", "text": "x"}], "S8"),
      asst("m1", ts(10, 0, 2), 30, [{"type": "text", "text": "y"}], "S8"), res("t8", ts(10, 0, 5), OKTXT, "S8")]
case("s8", "S8", sr)
open(T + "/c/s8/wrap", "w").write(str(30 + math.ceil(len(OKTXT) / 4)))
# S3: a malformed output_tokens counts as 0; an unreadable sibling transcript is skipped
bad = one("S3"); bad[0]["message"]["usage"]["output_tokens"] = "oops"
case("s3", "S3", bad)
open(T + "/c/s3/wrap", "w").write(str(math.ceil(len(OKTXT) / 4)))
with open(T + "/c/s3/mem/projects/p/unreadable.jsonl", "w") as f: f.write(json.dumps({"note": H}) + "\n")
os.chmod(T + "/c/s3/mem/projects/p/unreadable.jsonl", 0)
# S4: a good file, then a degraded rerun
case("s4", "S4", one("S4"))
PY
cj() { python3 -I "$SCAN" --date 2026-07-14 --no-write --json "$@"; }   # uses FORGE_MEMBRANE / FORGE_LLM_LEDGER from the caller
runcase() { # NAME -> JSON in $TMPD/c/NAME/out.json
  FORGE_MEMBRANE="$TMPD/c/$1/mem" FORGE_LLM_LEDGER="$TMPD/c/$1/calls.jsonl" cj >"$TMPD/c/$1/out.json" 2>"$TMPD/c/$1/err.txt"
}
cn() { jget "$TMPD/c/$1/out.json" "numbers.$2"; }

# S5: pairing and join misses
runcase s5a
eq "s5a session mismatch inside window: one call, no unattributed" "$(cn s5a calls)/$(cn s5a unattributed)/$(cn s5a join_misses)" "1/0/0"
eq "s5a ledger counters used" "$(cn s5a local_tokens)" 5
runcase s5b
eq "s5b no match after the ledger began: counted once + flagged" "$(cn s5b calls)/$(cn s5b unattributed)/$(cn s5b join_misses)" "2/1/1"
runcase s5c
eq "s5c call before the ledger began: not a miss" "$(cn s5c calls)/$(cn s5c unattributed)/$(cn s5c join_misses)" "2/1/0"

# S6: redo is not multiplied across consecutive fallbacks
runcase s6
eq "s6 three fallbacks" "$(cn s6 fallback)" 3
eq "s6 redo = 10+20+40 once" "$(cn s6 redo_tokens)" 70

# S8: one streamed message counts once at its largest output_tokens
runcase s8
eq "s8 streamed turn: wrap at the largest record" "$(cn s8 wrap_tokens)" "$(cat "$TMPD/c/s8/wrap")"

# S3: unreadable transcript skipped and counted; malformed output_tokens is 0
if [ "$(id -u)" = 0 ]; then
  echo "SKIP  unreadable transcript (running as root, permissions not enforced)"
  rm -f "$TMPD/c/s3/mem/projects/p/unreadable.jsonl"
  runcase s3
else
  runcase s3
  eq "s3 unreadable transcript skipped, run succeeds" "$(cn s3 skipped_transcripts)/$(cn s3 transcripts_scanned)/$(cn s3 calls)" "1/1/1"
fi
eq "s3 malformed output_tokens reads as 0" "$(cn s3 wrap_tokens)" "$(cat "$TMPD/c/s3/wrap")"
chmod 600 "$TMPD/c/s3/mem/projects/p/unreadable.jsonl" 2>/dev/null

# S2: a missing membrane is an error, not "no usage"
FORGE_MEMBRANE="$TMPD/nomem" FORGE_LLM_LEDGER="$TMPD/c/s5a/calls.jsonl" python3 -I "$SCAN" --date 2026-07-14 --no-write >/dev/null 2>"$TMPD/nomem.err"
eq "missing membrane exits 2" "$?" 2
eq "missing membrane names the path" "$(grep -c "$TMPD/nomem/projects" "$TMPD/nomem.err")" 1

# S1: FORGE_LLM_LEDGER=off reads no ledger and writes under the state dir, never cwd
mkdir -p "$TMPD/cwd"
( cd "$TMPD/cwd" && FORGE_MEMBRANE="$TMPD/c/s5b/mem" FORGE_LLM_LEDGER=off python3 -I "$SCAN" --date 2026-07-14 --json >"$TMPD/off.json" 2>/dev/null )
eq "off: nothing written in cwd" "$(ls -A "$TMPD/cwd" | wc -l)" 0
[ -s "$HOME/.local/state/forge/llm-delegate/daily/2026-07-14.json" ] && check "off: daily file under the default state dir" 0 || check "off: daily file under the default state dir" 1
eq "off: no ledger read (transcript call only)" "$(jget "$TMPD/off.json" numbers.calls)/$(jget "$TMPD/off.json" numbers.unattributed)" "1/0"
( cd "$TMPD/cwd" && FORGE_MEMBRANE="$TMPD/c/s5b/mem" FORGE_LLM_LEDGER=off python3 -I "$SCAN" --date 2026-07-14 --state-dir "$TMPD/sd" >/dev/null 2>&1 )
[ -s "$TMPD/sd/daily/2026-07-14.json" ] && [ "$(ls -A "$TMPD/cwd" | wc -l)" = 0 ] && check "--state-dir honoured" 0 || check "--state-dir honoured" 1

# S4: a degraded rerun keeps the good file; --force replaces it
S4="$TMPD/c/s4"
run4() { FORGE_MEMBRANE="$S4/mem" FORGE_LLM_LEDGER="$S4/calls.jsonl" python3 -I "$SCAN" --date 2026-07-14 --state-dir "$S4/state" "$@" >/dev/null 2>"$S4/err.txt"; }
run4
eq "s4 first run attributed calls" "$(jget "$S4/state/daily/2026-07-14.json" numbers.calls)" 1
rm -f "$S4/mem/projects/p/S4.jsonl"
run4
eq "s4 degraded rerun exits 0" "$?" 0
eq "s4 degraded rerun keeps the good file" "$(jget "$S4/state/daily/2026-07-14.json" numbers.calls)" 1
eq "s4 says so on stderr, one line" "$(wc -l <"$S4/err.txt")/$(grep -c 'kept existing' "$S4/err.txt")" "1/1"
run4 --force
eq "s4 --force replaces it" "$(jget "$S4/state/daily/2026-07-14.json" numbers.calls)" 0

echo
if [ "$FAILS" = 0 ]; then echo "all passed"; else echo "$FAILS FAILED"; exit 1; fi
