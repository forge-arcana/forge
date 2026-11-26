#!/usr/bin/env bash
#
# Tests for pare-ledger.py. Temp HOME and state dir; never touches a real ledger.
# Run:  bash core/scripts/tests/test-pare-ledger.sh      (non-zero on failure)

HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.."
PL="$HERE/pare-ledger.py"
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
export PYTHONDONTWRITEBYTECODE=1
mkdir -p "$TMPD/home"; export HOME="$TMPD/home"
unset XDG_STATE_HOME FORGE_PARE_LEDGER

FAILS=0
check() { if [ "$2" = 0 ]; then echo "PASS  $1"; else echo "FAIL  $1  (${3:-})"; FAILS=$((FAILS + 1)); fi; }
eq() { [ "$2" = "$3" ] && check "$1" 0 || check "$1" 1 "got=$2 want=$3"; }

pl() { python3 -B -I "$PL" "$@"; }

# gen KIND [PYEXPR]: print a valid object as JSON after applying PYEXPR (mutates dict d)
gen() {
  python3 -B -I - "$1" "${2:-pass}" <<'PY'
import json, sys
kind, expr = sys.argv[1], sys.argv[2]
M = {"source_tokens": 1000, "packages": 5, "advisories": 0, "bundle_bytes": None,
     "build_ms": 10, "test_ms": 20, "typecheck_ms": None, "test_count": 7}
if kind == "run":
    d = {"v": 1, "ts": "2026-01-02T03:04:05Z", "started_at": "2026-01-02T03:00:00Z",
         "session": "sess-a", "repo": "/tmp/x/proj-a", "scope": "src", "trigger": "smith",
         "commit_before": "abc1234", "commit_after": None, "tools": {"tool-a": "1.2.3"},
         "coverage_pct": 81.5, "report_only": False, "report_only_reason": None,
         "cuts": {"proven": {"candidates": 5, "tried": 4, "kept": 3, "reverted": 1},
                  "judgement": {"candidates": 3, "proposed": 2, "approved": 2, "kept": 1, "reverted": 1}},
         "removed": {"lines": 10, "files": 1, "exports": 1, "packages": 0},
         "removed_items": {"files": ["src/a.ts"], "exports": [{"module": "src/b.ts", "name": "fn"}], "packages": []},
         "before": dict(M), "after": dict(M, packages=4), "advisory_ids_removed": ["ADV-1"],
         "guards": {"tests_green_after": True, "test_count_drop": False, "config_changed": False},
         "pass_seconds": 245, "outcome": "completed"}
else:
    d = {"v": 1, "ts": "2026-01-02T03:04:05Z", "repo": "/tmp/x/proj-a", "pass_ts": "2026-01-02T03:04:05Z",
         "side": "pre", "commit": "abc1234def", "task": "task-1", "run": 1, "input_tokens": 1,
         "output_tokens": 2, "cache_creation_tokens": 3, "cache_read_tokens": 4, "passed": None,
         "seconds": 9, "session": None}
exec(expr)
print(json.dumps(d))
PY
}

mode() { stat -c %a "$1"; }
lines() { wc -l < "$1" | tr -d ' '; }

# --- valid appends ---------------------------------------------------------
export XDG_STATE_HOME="$TMPD/state"
RUNS="$XDG_STATE_HOME/forge/pare/runs.jsonl"
BENCH="$XDG_STATE_HOME/forge/pare/bench.jsonl"
gen run | pl run; eq "valid run exits 0" "$?" 0
gen bench | pl bench; eq "valid bench exits 0" "$?" 0
eq "runs one line" "$(lines "$RUNS")" 1
eq "bench one line" "$(lines "$BENCH")" 1
eq "runs file mode 600" "$(mode "$RUNS")" 600
eq "bench file mode 600" "$(mode "$BENCH")" 600
eq "dir mode 700" "$(mode "$XDG_STATE_HOME/forge/pare")" 700
python3 -B -I -c 'import json,sys; [json.loads(l) for l in open(sys.argv[1])]' "$RUNS"; eq "runs line is JSON" "$?" 0
case "$(head -c 200 "$RUNS")" in *'" '*|*', "'*) check "run line is compact" 1 ;; *) check "run line is compact" 0 ;; esac
gen run "d['commit_after']='deadbeef'; d['scope']='.'; d['coverage_pct']=None; d['report_only']=True; d['report_only_reason']='no_tool'; d['outcome']='report_only'; d['cuts']['proven']['kept']=0; d['cuts']['judgement']['kept']=0" | pl run
eq "valid variant (report_only, scope dot)" "$?" 0
gen run "d['report_only']=True; d['report_only_reason']='dirty_tree'; d['outcome']='report_only'; d['cuts']['proven']['kept']=0; d['cuts']['judgement']['kept']=0" | pl run
eq "valid variant (dirty_tree reason)" "$?" 0
gen run "d['commit_before']='a'*64; d['pass_seconds']=250; d['removed']['lines']=2**53-1" | pl run
eq "valid variant (64-hex sha, pass_seconds +5, max int)" "$?" 0

# --- override and off ------------------------------------------------------
export FORGE_PARE_LEDGER="$TMPD/other/r.jsonl"
gen run | pl run; eq "override run exits 0" "$?" 0
eq "override file written" "$(lines "$TMPD/other/r.jsonl")" 1
gen bench | pl bench; eq "override bench exits 0" "$?" 0
eq "bench sits beside override" "$(lines "$TMPD/other/bench.jsonl")" 1
export FORGE_PARE_LEDGER=off
OUT="$(gen run | pl run 2>&1)"; eq "off run exits 0" "$?" 0
case "$OUT" in *off*) check "off says so on stderr" 0 ;; *) check "off says so on stderr" 1 "$OUT" ;; esac
gen run "d['v']=2" | pl run 2>/dev/null; eq "off still validates" "$?" 2
eq "off wrote nothing new" "$(lines "$RUNS")" 4
unset FORGE_PARE_LEDGER

# --- rejections ------------------------------------------------------------
SENT="SENTINEL-zq9"
rej() { # name kind expr
  local out rc
  out="$(gen "$2" "$3" | pl "$2" 2>&1 >/dev/null)"; rc=$?
  eq "reject: $1 (exit 2)" "$rc" 2
  case "$out" in *"$SENT"*) check "reject: $1 leaks no value" 1 "$out" ;; *) check "reject: $1 leaks no value" 0 ;; esac
  [ -n "$out" ]; eq "reject: $1 has message" "$?" 0
}
rej "unknown key" run "d['extra_$SENT']=1"
rej "unknown nested key" run "d['cuts']['proven']['x_$SENT']=1"
rej "missing key" run "del d['outcome']"
rej "missing nested key" run "del d['before']['test_ms']"
rej "bool as int" run "d['pass_seconds']=True"
rej "bool as nested int" run "d['removed']['lines']=True"
rej "negative" run "d['removed']['files']=-1"
rej "float as int" run "d['pass_seconds']=1.5"
rej "bad enum" run "d['trigger']='$SENT'"
rej "bad outcome" run "d['outcome']='done'"
rej "bad ts" run "d['ts']='$SENT'"
rej "ts without Z" run "d['ts']='2026-01-02T03:04:05'"
rej "ts impossible date" run "d['ts']='2026-02-30T03:04:05Z'"
rej "started_at after ts" run "d['started_at']='2026-01-02T03:04:06Z'"
rej "reason set while not report_only" run "d['report_only_reason']='no_tool'"
rej "report_only without reason" run "d['report_only']=True; d['outcome']='report_only'"
rej "bad reason" run "d['report_only']=True; d['outcome']='report_only'; d['report_only_reason']='$SENT'"
rej "proven kept+reverted > tried" run "d['cuts']['proven']['kept']=4"
rej "judgement kept+reverted > approved" run "d['cuts']['judgement']['kept']=2"
rej "judgement approved > proposed" run "d['cuts']['judgement'].update(proposed=1, approved=2, kept=0, reverted=0)"
rej "scope with .." run "d['scope']='a/../$SENT'"
rej "scope absolute" run "d['scope']='/$SENT'"
rej "relative repo" run "d['repo']='$SENT'"
rej "bad sha" run "d['commit_before']='zz$SENT'"
rej "short sha" run "d['commit_before']='abc12'"
rej "bad commit_after" run "d['commit_after']='$SENT'"
rej "coverage over 100" run "d['coverage_pct']=100.5"
rej "coverage bool" run "d['coverage_pct']=True"
rej "tools non-string value" run "d['tools']={'t':1}"
rej "removed_items file with .." run "d['removed_items']['files']=['../$SENT']"
rej "removed_items export bad" run "d['removed_items']['exports']=[{'module':'a','name':5}]"
rej "metric string" run "d['before']['build_ms']='$SENT'"
rej "guards non-bool" run "d['guards']['config_changed']=0"
rej "v wrong" run "d['v']=True"
rej "v float" run "d['v']=1.0"
rej "bench v float" bench "d['v']=1.0"
rej "sha 65 hex" run "d['commit_before']='a'*65"
rej "int above 2**53-1" run "d['removed']['lines']=2**53"
rej "metric above 2**53-1" run "d['before']['test_ms']=2**53"
rej "bench int above cap" bench "d['seconds']=2**53"
rej "session too long" run "d['session']='s'*129"
rej "bench session too long" bench "d['session']='s'*129"
rej "tool name too long" run "d['tools']={'t'*65: '1'}"
rej "tool version bad chars" run "d['tools']={'t': 'a b'}"
rej "tool version too long" run "d['tools']={'t': '1'*65}"
rej "export name too long" run "d['removed_items']['exports'][0]['name']='n'*201"
rej "package name too long" run "d['removed_items']['packages']=['p'*215]; d['removed']['packages']=1"
rej "path too long" run "d['scope']='p'*4097"
rej "repo too long" run "d['repo']='/'+'p'*4096"
rej "leading colon scope" run "d['scope']=':(top)x'"
rej "leading colon removed file" run "d['removed_items']['files']=[':(glob)x']"
rej "leading colon export module" run "d['removed_items']['exports'][0]['module']=':x'"
rej "report_only true but outcome completed" run "d['report_only']=True; d['report_only_reason']='no_tool'; d['cuts']['proven']['kept']=0; d['cuts']['judgement']['kept']=0"
rej "outcome report_only but report_only false" run "d['outcome']='report_only'"
rej "report_only with proven kept" run "d['report_only']=True; d['report_only_reason']='no_tool'; d['outcome']='report_only'; d['cuts']['judgement']['kept']=0"
rej "report_only with judgement kept" run "d['report_only']=True; d['report_only_reason']='no_tool'; d['outcome']='report_only'; d['cuts']['proven']['kept']=0"
rej "removed.files mismatch" run "d['removed']['files']=2"
rej "removed.exports mismatch" run "d['removed']['exports']=0"
rej "removed.packages mismatch" run "d['removed']['packages']=1"
rej "pass_seconds 6 over" run "d['pass_seconds']=251"
rej "pass_seconds 6 under" run "d['pass_seconds']=239"
rej "bench bad task" bench "d['task']='Bad_$SENT'"
rej "bench task too long" bench "d['task']='a'*41"
rej "bench run zero" bench "d['run']=0"
rej "bench bad side" bench "d['side']='$SENT'"
rej "bench bad sha" bench "d['commit']='$SENT'"
rej "bench bad pass_ts" bench "d['pass_ts']='$SENT'"
rej "bench passed int" bench "d['passed']=1"
rej "bench unknown key" bench "d['$SENT']=1"
rej "bench missing key" bench "del d['seconds']"
rej "bench negative" bench "d['input_tokens']=-3"
OUT="$(printf '{"x": %s' "$SENT" | pl run 2>&1)"; eq "malformed JSON exits 2" "$?" 2
case "$OUT" in *"$SENT"*) check "malformed JSON leaks no value" 1 ;; *) check "malformed JSON leaks no value" 0 ;; esac
printf '[1]' | pl run 2>/dev/null; eq "non-object exits 2" "$?" 2
printf '{"v":1,"coverage_pct":NaN}' | pl run 2>/dev/null; eq "NaN input exits 2" "$?" 2
eq "rejections wrote nothing" "$(lines "$RUNS")" 4
eq "bench rejections wrote nothing" "$(lines "$BENCH")" 1

# --- importable ------------------------------------------------------------
python3 -B -I - "$PL" "$(gen run)" "$(gen run "d['pass_seconds']=-1")" <<'PY'
import importlib.util, json, sys
spec = importlib.util.spec_from_file_location("pare_ledger", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
ok = m.validate_run(json.loads(sys.argv[2])) == []
bad = m.validate_run(json.loads(sys.argv[3]))
sys.exit(0 if ok and bad and all(isinstance(e, str) for e in bad) and callable(m.validate_bench) else 1)
PY
eq "importable validate_run/validate_bench" "$?" 0

python3 -B -I - "$PL" <<'PY'
import importlib.util, os, sys, datetime
spec = importlib.util.spec_from_file_location("pare_ledger", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
ok = True
for n in ("SHA_RE", "SLUG_RE", "TS_RE", "SIDES", "METRIC_KEYS", "MAX_INT", "parse_ts",
          "runs_path", "bench_path", "state_dir", "validate_run", "validate_bench"):
    ok = ok and hasattr(m, n)
ok = ok and m.MAX_INT == 2**53 - 1 and len(m.METRIC_KEYS) == 8 and m.SIDES == ("pre", "post", "noise")
ok = ok and m.SHA_RE.match("a" * 64) and not m.SHA_RE.match("a" * 65) and not m.SHA_RE.match("a" * 6)
ok = ok and m.SLUG_RE.match("a-1") and not m.SLUG_RE.match("-a")
ok = ok and isinstance(m.parse_ts("2026-01-02T03:04:05Z"), datetime.datetime)
ok = ok and m.parse_ts("2026-02-30T03:04:05Z") is None and m.parse_ts("2026-01-02 03:04:05") is None
os.environ["FORGE_PARE_LEDGER"] = "/x/y/runs.jsonl"
ok = ok and m.runs_path() == "/x/y/runs.jsonl" and m.bench_path() == "/x/y/bench.jsonl" and m.state_dir() == "/x/y"
os.environ["FORGE_PARE_LEDGER"] = "off"
ok = ok and m.runs_path() is None and m.bench_path() is None
os.environ["FORGE_PARE_LEDGER"] = ""
ok = ok and m.runs_path() is not None and os.path.isabs(m.runs_path())
os.environ["FORGE_PARE_LEDGER"] = "rel/x"
try:
    m.runs_path(); ok = False
except ValueError:
    pass
sys.exit(0 if ok else 1)
PY
eq "importable public names and behaviour" "$?" 0

# --- append safety ---------------------------------------------------------
mkdir -p "$TMPD/safe"; chmod 700 "$TMPD/safe"
echo precious > "$TMPD/target.txt"
ln -s "$TMPD/target.txt" "$TMPD/safe/runs.jsonl"
export FORGE_PARE_LEDGER="$TMPD/safe/runs.jsonl"
gen run | pl run 2>/dev/null; eq "symlinked ledger refused (exit 1)" "$?" 1
eq "symlink target untouched" "$(cat "$TMPD/target.txt")" precious
rm "$TMPD/safe/runs.jsonl"
mkdir -p "$TMPD/loose"; chmod 777 "$TMPD/loose"
touch "$TMPD/loose/runs.jsonl"; chmod 666 "$TMPD/loose/runs.jsonl"
export FORGE_PARE_LEDGER="$TMPD/loose/runs.jsonl"
gen run | pl run; eq "loose-mode ledger append exits 0" "$?" 0
eq "loose file tightened to 600" "$(mode "$TMPD/loose/runs.jsonl")" 600
eq "loose dir tightened to 700" "$(mode "$TMPD/loose")" 700
eq "loose ledger got the line" "$(lines "$TMPD/loose/runs.jsonl")" 1
unset FORGE_PARE_LEDGER

# --- concurrency -----------------------------------------------------------
export FORGE_PARE_LEDGER="$TMPD/conc/runs.jsonl"
for i in $(seq 1 20); do
  gen run "d['session']='w$i'; d['advisory_ids_removed']=['A'*190]*60" | pl run &
done
wait
eq "20 concurrent writers: 20 lines" "$(lines "$FORGE_PARE_LEDGER")" 20
python3 -B -I -c '
import json,sys
s=set()
for l in open(sys.argv[1]):
    s.add(json.loads(l)["session"])
sys.exit(0 if len(s)==20 else 1)' "$FORGE_PARE_LEDGER"
eq "all 20 lines intact and distinct" "$?" 0
unset FORGE_PARE_LEDGER

# --- hook-status -----------------------------------------------------------
export XDG_STATE_HOME="$TMPD/state2"
OUT="$(pl hook-status)"; rc=$?
eq "hook-status default prints off" "$OUT" off
eq "hook-status default exit 1" "$rc" 1
eq "hook-status created nothing" "$([ -e "$XDG_STATE_HOME" ] && echo yes || echo no)" no
mkdir -p "$XDG_STATE_HOME/forge/pare"; touch "$XDG_STATE_HOME/forge/pare/smith-hook-on"
OUT="$(pl hook-status)"; rc=$?
eq "hook-status after touch prints on" "$OUT" on
eq "hook-status after touch exit 0" "$rc" 0
pl bogus 2>/dev/null; eq "unknown subcommand exits 2" "$?" 2

echo
if [ "$FAILS" = 0 ]; then echo "ALL PASS"; else echo "$FAILS FAILED"; exit 1; fi
