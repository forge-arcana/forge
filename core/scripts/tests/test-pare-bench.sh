#!/usr/bin/env bash
# Tests for pare-bench.py. Uses a stub agent binary and a stub ledger writer;
# the real claude binary is never run. Synthetic data only.
export PYTHONDONTWRITEBYTECODE=1
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BENCH="$HERE/../pare-bench.py"
PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); echo "PASS: $1"; }
bad() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi; }

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir "$T/tmp"
export TMPDIR="$T/tmp"
export GIT_CONFIG_GLOBAL="$T/gitconfig"
export GIT_CONFIG_NOSYSTEM=1
git config --global user.name "Test User"
git config --global user.email "test@example.invalid"
git config --global init.defaultBranch main

REPO="$T/repo"
git init -q "$REPO"
echo one >"$REPO/a.txt"
git -C "$REPO" add a.txt
git -C "$REPO" commit -q -m first
PRE="$(git -C "$REPO" rev-parse HEAD)"
echo two >"$REPO/b.txt"
git -C "$REPO" add b.txt
git -C "$REPO" commit -q -m second
POST="$(git -C "$REPO" rev-parse HEAD)"

# stub agent. Env knobs: STUB_ARGV (log argv), STUB_COUNT, STUB_FAIL_FROM, STUB_FAIL_DIR,
# STUB_LS (log tree listing), STUB_DIRTY (dirty the tree), STUB_NOUSAGE (1 none, 2 no output_tokens),
# STUB_SLEEP + STUB_PIDS (sleep, record pids).
cat >"$T/claude-stub" <<'EOF'
#!/usr/bin/env bash
prompt="$2"
dir="$(basename "$PWD")"
echo "stub saw prompt: $prompt" >&2
if [ -n "$STUB_ARGV" ]; then printf '%s\n' "$*" >>"$STUB_ARGV"; fi
if [ "$1" != "-p" ]; then exit 7; fi
if [ -n "$STUB_LS" ]; then echo "$(ls | tr '\n' ' ')|$(cat a.txt)" >>"$STUB_LS"; fi
if [ -n "$STUB_DIRTY" ]; then echo junk >dirty.txt; echo changed >a.txt; fi
if [ -n "$STUB_SLEEP" ]; then
  echo "$$" >>"$STUB_PIDS"
  sleep 300 &
  echo "$!" >>"$STUB_PIDS"
  wait
fi
n=0
if [ -n "$STUB_COUNT" ]; then
  n=$(( $(cat "$STUB_COUNT" 2>/dev/null || echo 0) + 1 ))
  echo "$n" >"$STUB_COUNT"
fi
if [ -n "$STUB_FAIL_FROM" ] && [ "$n" -ge "$STUB_FAIL_FROM" ]; then exit 1; fi
if [ -n "$STUB_FAIL_DIR" ] && [ "$dir" = "$STUB_FAIL_DIR" ]; then echo "not json"; exit 0; fi
if [ "$dir" = "post" ]; then i=80; else i=100; fi
case "$STUB_NOUSAGE" in
  1) printf '{"type":"result","is_error":false,"result":"ANS:%s"}\n' "$prompt"; exit 0 ;;
  2) printf '{"type":"result","is_error":false,"result":"ANS:%s","usage":{"input_tokens":5}}\n' "$prompt"; exit 0 ;;
esac
printf '{"type":"result","is_error":false,"result":"ANS:%s","session_id":"sess-%s-%s","usage":{"input_tokens":%s,"output_tokens":7,"cache_creation_input_tokens":3,"cache_read_input_tokens":11}}\n' "$prompt" "$dir" "$$" "$i"
EOF
chmod +x "$T/claude-stub"

cat >"$T/writer-stub.py" <<'EOF'
import os, sys
if len(sys.argv) < 2 or sys.argv[1] != "bench":
    sys.exit(9)
with open(os.environ["WRITER_OUT"], "a") as f:
    f.write(sys.stdin.read().strip() + "\n")
EOF

cat >"$T/tasks.json" <<'EOF'
{"tasks":[
 {"id":"alpha","prompt":"SECRETPROMPT-alpha find things","check":"grep -q 'find things'"},
 {"id":"beta","prompt":"SECRETPROMPT-beta find more","check":"grep -q NO-SUCH-TEXT"},
 {"id":"gamma","prompt":"SECRETPROMPT-gamma find other","check":null}
]}
EOF

export PARE_BENCH_CLAUDE="$T/claude-stub"
export PARE_LEDGER_WRITER="$T/writer-stub.py"
export WRITER_OUT="$T/out.jsonl"
TS="2026-01-02T03:04:05Z"

run_bench() { python3 -B -I "$BENCH" --repo "$REPO" --tasks "${TASKS:-$T/tasks.json}" --pre "$PRE" --post "$POST" --pass-ts "$TS" "$@"; }
wt_count() { git -C "$REPO" worktree list | wc -l | tr -d ' '; }

# 1. happy path
: >"$WRITER_OUT"
run_bench >"$T/o1" 2>"$T/e1"
check "happy path exit 0" "$?" "0"
check "27 records" "$(wc -l <"$WRITER_OUT" | tr -d ' ')" "27"
check "worktrees removed" "$(wt_count)" "1"
check "branch untouched" "$(git -C "$REPO" rev-parse HEAD)" "$POST"
python3 -B -I - "$WRITER_OUT" "$PRE" "$POST" "$REPO" "$TS" <<'EOF' >"$T/pyres" 2>&1
import json, sys
path, pre, post, repo, ts = sys.argv[1:]
recs = [json.loads(l) for l in open(path)]
errs = []
keys = {"v","ts","repo","pass_ts","side","commit","task","run","input_tokens","output_tokens",
        "cache_creation_tokens","cache_read_tokens","passed","seconds","session"}
for r in recs:
    if set(r) != keys: errs.append("keys")
    if r["v"] != 1 or r["repo"] != repo or r["pass_ts"] != ts: errs.append("meta")
    want = {"pre": (pre, 100), "post": (post, 80), "noise": (pre, 100)}[r["side"]]
    if (r["commit"], r["input_tokens"]) != want: errs.append("side/commit/usage " + r["side"])
    if (r["output_tokens"], r["cache_creation_tokens"], r["cache_read_tokens"]) != (7, 3, 11): errs.append("tokens")
    if not (isinstance(r["seconds"], int) and isinstance(r["session"], str)): errs.append("types")
    if r["task"] == "gamma" and r["passed"] is not None: errs.append("gamma passed")
# checks judge the answer: alpha matches its own answer text, beta never matches
for r in recs:
    if r["task"] == "beta":
        if r["passed"] is not False: errs.append("beta passed mismatch")
    if r["task"] == "alpha" and r["passed"] is not True: errs.append("alpha passed")
# rotation: records ordered round-major, then task, then side order
exp = []
S = ["pre", "post", "noise"]
for rnd in (1, 2, 3):
    off = (rnd - 1) % 3
    for t in ("alpha", "beta", "gamma"):
        for s in S[off:] + S[:off]:
            exp.append((rnd, t, s))
got = [(r["run"], r["task"], r["side"]) for r in recs]
if got != exp: errs.append("rotation order")
for t in ("alpha", "beta", "gamma"):
    for s in S:
        if sorted(r["run"] for r in recs if r["task"] == t and r["side"] == s) != [1, 2, 3]:
            errs.append("run numbers " + t + s)
print("OK" if not errs else "ERR " + ",".join(sorted(set(errs))))
EOF
check "record fields, check->passed, rotation" "$(cat "$T/pyres")" "OK"
if grep -q SECRETPROMPT "$T/e1" "$T/o1"; then bad "prompt text absent from stderr/stdout"; else ok "prompt text absent from stderr/stdout"; fi

# 1b. exact argv
: >"$WRITER_OUT"
: >"$T/argv"
STUB_ARGV="$T/argv" run_bench --model test-model >/dev/null 2>&1
check "argv: 27 calls" "$(wc -l <"$T/argv" | tr -d ' ')" "27"
WANT_TAIL="--output-format json --tools Read,Grep,Glob --permission-mode dontAsk --permission-prompts none --safe-mode --no-session-persistence --strict-mcp-config --mcp-config {\"mcpServers\":{}} --disallowedTools mcp__* --model test-model"
check "argv: exact line (alpha)" "$(grep -m1 'SECRETPROMPT-alpha' "$T/argv")" "-p SECRETPROMPT-alpha find things $WANT_TAIL"
check "argv: all 27 lines identical after the prompt" "$(sed 's/^-p SECRETPROMPT-[a-z]* [a-z ]* --output-format/--output-format/' "$T/argv" | sort -u | wc -l | tr -d ' ')" "1"
check "argv: all lines start with -p" "$(grep -c '^-p SECRETPROMPT-' "$T/argv")" "27"
: >"$T/argv"
STUB_ARGV="$T/argv" PARE_BENCH_PERMISSION_MODE=plan run_bench >/dev/null 2>&1
check "argv: no --model by default" "$(grep -c -e '--model' "$T/argv")" "0"
check "argv: permission mode override" "$(grep -c -e '--permission-mode plan --permission-prompts none' "$T/argv")" "27"
check "argv: no legacy flags" "$(grep -c -e '--allowedTools' "$T/argv")" "0"
check "argv: mcp confinement flags" "$(grep -c -F -e '--strict-mcp-config --mcp-config {"mcpServers":{}} --disallowedTools mcp__*' "$T/argv")" "27"
: >"$WRITER_OUT"

# 2. stub fails mid-run: exit 4, worktrees removed, only good runs written
: >"$WRITER_OUT"
rm -f "$T/count"
STUB_COUNT="$T/count" STUB_FAIL_FROM=10 run_bench >"$T/o2" 2>"$T/e2"
check "mid-run failure exit 4" "$?" "4"
check "failed runs not written (9 good)" "$(wc -l <"$WRITER_OUT" | tr -d ' ')" "9"
check "worktrees removed after failure" "$(wt_count)" "1"
if grep -q SECRETPROMPT "$T/e2" "$T/o2"; then bad "prompt absent on failure"; else ok "prompt absent on failure"; fi

# 3. one side returning garbage: exit 4, other sides written
: >"$WRITER_OUT"
STUB_FAIL_DIR=post run_bench >"$T/o3" 2>"$T/e3"
check "non-JSON on post exit 4" "$?" "4"
check "only pre+noise written (18)" "$(wc -l <"$WRITER_OUT" | tr -d ' ')" "18"
check "no post records" "$(grep -c '"side": "post"' "$WRITER_OUT")" "0"
check "worktrees removed (garbage)" "$(wt_count)" "1"

# 4. writer failure -> exit 3 and cleanup
printf 'import sys\nsys.exit(5)\n' >"$T/writer-bad.py"
PARE_LEDGER_WRITER="$T/writer-bad.py" run_bench >/dev/null 2>"$T/e4"
check "writer failure exit 3" "$?" "3"
check "worktrees removed (writer fail)" "$(wt_count)" "1"

# 5. --runs 2 rejected
run_bench --runs 2 >/dev/null 2>"$T/e5"
check "--runs 2 rejected exit 2" "$?" "2"

# 6. tasks validation
bad_tasks() { # name json
  printf '%s' "$2" >"$T/bt.json"
  TASKS="$T/bt.json" run_bench >"$T/ob" 2>"$T/eb"
  check "tasks: $1 exit 2" "$?" "2"
  if grep -q SECRETPROMPT "$T/eb"; then bad "tasks: $1 no prompt echo"; else ok "tasks: $1 no prompt echo"; fi
}
bad_tasks "too few" '{"tasks":[{"id":"a","prompt":"SECRETPROMPT x","check":null}]}'
bad_tasks "bad id" '{"tasks":[{"id":"A_","prompt":"SECRETPROMPT x","check":null},{"id":"b","prompt":"p","check":null},{"id":"c","prompt":"p","check":null}]}'
bad_tasks "dup id" '{"tasks":[{"id":"a","prompt":"SECRETPROMPT x","check":null},{"id":"a","prompt":"p","check":null},{"id":"c","prompt":"p","check":null}]}'
bad_tasks "empty prompt" '{"tasks":[{"id":"a","prompt":" ","check":null},{"id":"b","prompt":"SECRETPROMPT","check":null},{"id":"c","prompt":"p","check":null}]}'
bad_tasks "bad check type" '{"tasks":[{"id":"a","prompt":"SECRETPROMPT","check":5},{"id":"b","prompt":"p","check":null},{"id":"c","prompt":"p","check":null}]}'
bad_tasks "not json SECRETPROMPT" 'SECRETPROMPT {{'
TASKS="$T/missing.json" run_bench >/dev/null 2>&1
check "tasks: missing file exit 2" "$?" "2"

# 7. dry run creates nothing
: >"$WRITER_OUT"
: >"$T/count"
STUB_COUNT="$T/count" run_bench --dry-run >"$T/o7" 2>"$T/e7"
check "dry-run exit 0" "$?" "0"
check "dry-run no records" "$(wc -l <"$WRITER_OUT" | tr -d ' ')" "0"
check "dry-run no agent calls" "$(cat "$T/count")" ""
check "dry-run no worktrees" "$(wt_count)" "1"
check "dry-run plans 27 runs" "$(head -1 "$T/o7" | grep -c 'planned runs: 27')" "1"
check "dry-run lists 27 steps" "$(grep -c '^round ' "$T/o7")" "27"
check "dry-run round 2 starts post" "$(grep '^round 2 alpha' "$T/o7" | head -1)" "round 2 alpha post"
if grep -q SECRETPROMPT "$T/o7" "$T/e7"; then bad "dry-run no prompt text"; else ok "dry-run no prompt text"; fi
check "no leftover temp worktree dirs in repo" "$(ls "$REPO" | tr '\n' ' ')" "a.txt b.txt "

# 8. permission override allow-list
: >"$T/count"
STUB_COUNT="$T/count" PARE_BENCH_PERMISSION_MODE=bypassPermissions run_bench >/dev/null 2>"$T/e8"
check "bypassPermissions rejected exit 2" "$?" "2"
check "bypassPermissions: no agent calls" "$(cat "$T/count")" ""
check "bypassPermissions: no worktrees" "$(wt_count)" "1"

# 9. bad --pass-ts (right format, impossible date) -> exit 2, zero agent calls
: >"$T/count"
STUB_COUNT="$T/count" run_bench --pass-ts 2026-02-30T00:00:00Z >/dev/null 2>"$T/e9"
check "bad pass-ts exit 2" "$?" "2"
check "bad pass-ts: no agent calls" "$(cat "$T/count")" ""

# 10. missing usage -> run not written
for mode in 1 2; do
  : >"$WRITER_OUT"
  STUB_NOUSAGE=$mode run_bench >/dev/null 2>"$T/e10"
  check "missing usage ($mode) exit 4" "$?" "4"
  check "missing usage ($mode) nothing written" "$(wc -l <"$WRITER_OUT" | tr -d ' ')" "0"
done

# 11. checks get the answer on stdin, run outside the worktree, do not know the side
cat >"$T/chk.sh" <<'EOF'
echo "side=${PARE_BENCH_SIDE-unset} dir=$(basename "$PWD") n=$(ls -A | wc -l | tr -d ' ') ceil=$([ "$(cd "$GIT_CEILING_DIRECTORIES" && pwd -P)" = "$(pwd -P)" ] && echo same) stdin=$(cat)" >>"$CHKLOG"
EOF
cat >"$T/tasks-chk.json" <<EOF
{"tasks":[
 {"id":"alpha","prompt":"SECRETPROMPT-alpha q","check":"bash $T/chk.sh"},
 {"id":"beta","prompt":"SECRETPROMPT-beta q","check":"bash $T/chk.sh"},
 {"id":"gamma","prompt":"SECRETPROMPT-gamma q","check":"bash $T/chk.sh"}
]}
EOF
: >"$WRITER_OUT"
: >"$T/chklog"
CHKLOG="$T/chklog" PARE_BENCH_SIDE=leak TASKS="$T/tasks-chk.json" run_bench >/dev/null 2>&1
check "check run exit 0" "$?" "0"
check "check ran 27 times" "$(wc -l <"$T/chklog" | tr -d ' ')" "27"
check "check: side unset" "$(grep -c '^side=unset ' "$T/chklog")" "27"
check "check: fresh empty chk- dir" "$(grep -c ' dir=chk-[A-Za-z0-9_]* n=0 ' "$T/chklog")" "27"
check "check: ceiling is its dir" "$(grep -c ' ceil=same ' "$T/chklog")" "27"
check "check: answer on stdin" "$(grep -c ' stdin=ANS:SECRETPROMPT-[a-z]* q$' "$T/chklog")" "27"
check "check: passed true in records" "$(grep -c '"passed": true' "$WRITER_OUT")" "27"

# 12. a run that dirties the tree does not affect the next run
: >"$WRITER_OUT"
: >"$T/ls"
STUB_LS="$T/ls" STUB_DIRTY=1 run_bench >/dev/null 2>&1
check "dirty: exit 0" "$?" "0"
check "dirty: every run saw a clean tree" "$(grep -c -v -e 'dirty.txt' "$T/ls")" "27"
check "dirty: tracked file restored" "$(grep -c -v -e '|one$' "$T/ls")" "0"
check "dirty: worktrees removed" "$(wt_count)" "1"

# 13. stale worktree from an earlier (fake) killed run is cleaned at start
STALE="$(mktemp -d "$TMPDIR/pare-bench-XXXXXX")"
git -C "$REPO" worktree add -q --detach "$STALE/pre" "$PRE"
check "stale: worktree registered" "$(wt_count)" "2"
: >"$WRITER_OUT"
run_bench >/dev/null 2>&1
check "stale: run exit 0" "$?" "0"
check "stale: worktree gone" "$(wt_count)" "1"
check "stale: dir gone" "$([ -e "$STALE" ] && echo yes || echo no)" "no"
KEEP="$T/keep-wt"
git -C "$REPO" worktree add -q --detach "$KEEP" "$PRE"
run_bench >/dev/null 2>&1
check "unrelated worktree kept" "$(wt_count)" "2"
git -C "$REPO" worktree remove --force "$KEEP"

# 14. SIGTERM mid-run: worktrees and the stub process tree are gone
: >"$T/pids"
(exec env STUB_SLEEP=1 STUB_PIDS="$T/pids" python3 -B -I "$BENCH" --repo "$REPO" --tasks "$T/tasks.json" --pre "$PRE" --post "$POST" --pass-ts "$TS" >/dev/null 2>&1) &
BPID=$!
for _ in $(seq 1 100); do
  [ "$(wc -l <"$T/pids" | tr -d ' ')" -ge 2 ] && break
  sleep 0.1
done
check "sigterm: stub started" "$([ "$(wc -l <"$T/pids" | tr -d ' ')" -ge 2 ] && echo yes || echo no)" "yes"
check "sigterm: worktrees exist mid-run" "$(wt_count)" "4"
# a second run while the first holds the lock is refused and leaves the first's worktrees
run_bench >/dev/null 2>"$T/e14"
check "lock: second run exit 2" "$?" "2"
check "lock: message" "$(grep -c 'another pare-bench run holds this repo' "$T/e14")" "1"
check "lock: first run's worktrees intact" "$(wt_count)" "4"
kill -TERM "$BPID"
wait "$BPID"
check "sigterm: exit 143" "$?" "143"
sleep 0.3
check "sigterm: worktrees gone" "$(wt_count)" "1"
alive=0
while read -r pid; do kill -0 "$pid" 2>/dev/null && alive=$((alive + 1)); done <"$T/pids"
check "sigterm: stub and child gone" "$alive" "0"

check "lock file left in .git" "$([ -f "$REPO/.git/pare-bench.lock" ] && echo yes || echo no)" "yes"

# 15. nothing left in TMPDIR
check "TMPDIR empty at end" "$(ls -A "$TMPDIR" | wc -l | tr -d ' ')" "0"

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
