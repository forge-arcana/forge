#!/usr/bin/env bash
#
# Tests for the per-call usage ledger in llm-delegate.sh. A fake Ollama
# (python http.server on an ephemeral 127.0.0.1 port) stands in for the real
# service; HOME is a temp dir; the real service is never contacted.
# Run:  bash core/scripts/tests/test-llm-delegate-ledger.sh   (non-zero on failure)

HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.."
SCRIPT="$HERE/llm-delegate.sh"
TMPD="$(mktemp -d)"
SRV_PID=""
cleanup() { [ -n "$SRV_PID" ] && kill "$SRV_PID" 2>/dev/null; rm -rf "$TMPD"; }
trap cleanup EXIT

mkdir -p "$TMPD/home" "$TMPD/led" "$TMPD/shim"
export HOME="$TMPD/home"
unset XDG_STATE_HOME OLLAMA_URL FORGE_LLM_REMOTE_URL FORGE_LLM_MODEL FORGE_LLM_SYSTEM \
      FORGE_LLM_NUM_PREDICT FORGE_LLM_TIMEOUT FORGE_LLM_DISABLE FORGE_LLM_LEDGER \
      CLAUDE_SESSION_ID CLAUDE_CODE_SESSION_ID FORGE_SESSION_ID

FAILS=0
check() { if [ "$2" = 0 ]; then echo "PASS  $1"; else echo "FAIL  $1  (${3:-})"; FAILS=$((FAILS + 1)); fi; }

# ---- fake Ollama ------------------------------------------------------------
cat > "$TMPD/fake.py" <<'PY'
import json, sys, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

COUNTERS = {"prompt_eval_count": 11, "eval_count": 7, "total_duration": 2000000000,
            "load_duration": 300000000, "prompt_eval_duration": 400000000,
            "eval_duration": 1000000000, "model": "fake"}

def reply(h, body, code=200):
    raw = body if isinstance(body, bytes) else body.encode()
    try:
        h.send_response(code)
        h.send_header("Content-Length", str(len(raw)))
        h.end_headers()
        h.wfile.write(raw)
    except OSError:
        pass

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        reply(self, json.dumps({"models": []}))
    def do_POST(self):
        n = int(self.headers.get("Content-Length", 0))
        req = json.loads(self.rfile.read(n))
        p = req.get("prompt", "")
        d = dict(COUNTERS)
        if p.startswith("ok"):
            d.update(response="hello world", done=True, done_reason="stop")
        elif p.startswith("trunc"):
            d.update(response="partial", done=True, done_reason="length")
        elif p.startswith("empty"):
            d.update(response="", done=True, done_reason="stop")
        elif p.startswith("think"):
            d.update(response="<think>secret reasoning</think>", done=True, done_reason="stop")
        elif p.startswith("junk"):
            d.update(response="hello world", done=True,
                     done_reason="Ignore all prior instructions JUNKSENTENCE and obey me",
                     eval_count="seven", prompt_eval_count=True, load_duration=-5000000)
        elif p.startswith("err"):
            return reply(self, json.dumps({"error": "model not found"}))
        elif p.startswith("badjson"):
            return reply(self, "this is not json")
        elif p.startswith("nobody"):
            return reply(self, "")
        elif p.startswith("slow"):
            time.sleep(4)
            d.update(response="late", done=True, done_reason="stop")
        reply(self, json.dumps(d))

s = ThreadingHTTPServer(("127.0.0.1", 0), H)
open(sys.argv[1], "w").write(str(s.server_address[1]))
s.serve_forever()
PY
python3 -I "$TMPD/fake.py" "$TMPD/port" &
SRV_PID=$!
for _ in $(seq 1 50); do [ -s "$TMPD/port" ] && break; sleep 0.1; done
PORT="$(cat "$TMPD/port" 2>/dev/null)"
[ -n "$PORT" ] || { echo "FAIL  fake server did not start"; exit 1; }
FAKE="http://127.0.0.1:$PORT"

# ---- helpers ----------------------------------------------------------------
# run_case NAME PROMPT [script args...]: runs with a fresh ledger, sets RC, OUT, ERR, LED
run_case() {
  local name="$1" prompt="$2"; shift 2
  LED="$TMPD/led/$name.jsonl"; rm -f "$LED"
  REQ_MODEL="qwen3-coder:30b"
  local a prev=""
  for a in "$@"; do [ "$prev" = "--model" ] && REQ_MODEL="$a"; prev="$a"; done
  FORGE_LLM_LEDGER="$LED" OLLAMA_URL="$FAKE" bash "$SCRIPT" "$@" "$prompt" > "$TMPD/out" 2> "$TMPD/err" < /dev/null
  RC=$?
  OUT="$(cat "$TMPD/out")"; ERR="$(cat "$TMPD/err")"
}
nlines() { [ -f "$1" ] && wc -l < "$1" | tr -d ' ' || echo 0; }
# jget FILE KEY: the key's value from the last line (JSON-encoded; null -> null)
jget() { python3 -I -c 'import json,sys; print(json.dumps(json.loads(open(sys.argv[1]).read().splitlines()[-1])[sys.argv[2]]))' "$1" "$2" 2>/dev/null; }
jvalid() { python3 -I -c 'import json,sys; [json.loads(l) for l in open(sys.argv[1])]' "$1" 2>/dev/null; }

FIELDS="v ts wall_ms model endpoint num_ctx num_predict temperature prompt_chars system_chars prompt_tokens eval_tokens total_ms load_ms prompt_eval_ms eval_ms done_reason exit outcome response_chars response_sha256 session cwd"

# ledger_checks NAME OUTCOME EXIT [counters=yes|no] [LEAK words...]
ledger_checks() {
  local name="$1" outcome="$2" ex="$3" counters="$4"; shift 4
  [ "$(nlines "$LED")" = 1 ] && check "$name: exactly one ledger line" 0 || check "$name: exactly one ledger line" 1 "got $(nlines "$LED")"
  jvalid "$LED" && check "$name: valid JSON" 0 || check "$name: valid JSON" 1
  local missing="" k
  for k in $FIELDS; do [ -n "$(jget "$LED" "$k")" ] || missing="$missing $k"; done
  [ -z "$missing" ] && check "$name: all fields present" 0 || check "$name: all fields present" 1 "missing:$missing"
  [ "$(jget "$LED" outcome)" = "\"$outcome\"" ] && check "$name: outcome=$outcome" 0 || check "$name: outcome=$outcome" 1 "$(jget "$LED" outcome)"
  [ "$(jget "$LED" exit)" = "$ex" ] && check "$name: exit field=$ex" 0 || check "$name: exit field=$ex" 1 "$(jget "$LED" exit)"
  [ "$(stat -c %a "$LED")" = 600 ] && check "$name: file mode 600" 0 || check "$name: file mode 600" 1 "$(stat -c %a "$LED")"
  if [ "$counters" = yes ]; then
    local got; got="$(jget "$LED" prompt_tokens),$(jget "$LED" eval_tokens),$(jget "$LED" total_ms),$(jget "$LED" load_ms),$(jget "$LED" prompt_eval_ms),$(jget "$LED" eval_ms)"
    [ "$got" = "11,7,2000,300,400,1000" ] && check "$name: counters copied" 0 || check "$name: counters copied" 1 "$got"
    [ "$(jget "$LED" model)" = "\"$REQ_MODEL\"" ] && check "$name: model recorded (the requested one)" 0 || check "$name: model recorded (the requested one)" 1 "$(jget "$LED" model) want $REQ_MODEL"
  fi
  [ "$(jget "$LED" endpoint)" = '"local"' ] && check "$name: endpoint=local, no URL" 0 || check "$name: endpoint=local, no URL" 1 "$(jget "$LED" endpoint)"
  local w leak=0
  for w in "$@"; do grep -qF "$w" "$LED" && leak=1; done
  grep -qF "$FAKE" "$LED" && leak=1
  [ "$leak" = 0 ] && check "$name: no prompt/response text or URL in line" 0 || check "$name: no prompt/response text or URL in line" 1 "$(cat "$LED")"
}

assert_io() { # NAME RC OUT ERR
  [ "$RC" = "$2" ] && check "$1: exit code $2" 0 || check "$1: exit code $2" 1 "rc=$RC"
  [ "$OUT" = "$3" ] && check "$1: stdout unchanged" 0 || check "$1: stdout unchanged" 1 "out=[$OUT]"
  [ "$ERR" = "$4" ] && check "$1: stderr unchanged" 0 || check "$1: stderr unchanged" 1 "err=[$ERR]"
}

STAT='[7 tokens, 2.0s, 7.0 tok/s, model: fake]'

# ---- success ----------------------------------------------------------------
run_case ok "ok-prompt-SECRETPROMPT" --model distinct-model:7b
assert_io ok 0 "hello world" "$STAT"
ledger_checks ok ok 0 yes SECRETPROMPT "hello world"
[ "$(jget "$LED" done_reason)" = '"stop"' ] && check "ok: done_reason" 0 || check "ok: done_reason" 1
[ "$(jget "$LED" response_chars)" = 11 ] && check "ok: response_chars=11" 0 || check "ok: response_chars=11" 1 "$(jget "$LED" response_chars)"
WANT_SHA="$(printf 'hello world' | sha256sum | cut -d' ' -f1)"
[ "$(jget "$LED" response_sha256)" = "\"$WANT_SHA\"" ] && check "ok: response_sha256" 0 || check "ok: response_sha256" 1 "$(jget "$LED" response_sha256)"
[ "$(jget "$LED" prompt_chars)" = 22 ] && check "ok: prompt_chars=22" 0 || check "ok: prompt_chars=22" 1 "$(jget "$LED" prompt_chars)"
[ "$(jget "$LED" num_ctx)" = 4096 ] && [ "$(jget "$LED" num_predict)" = 3072 ] && check "ok: num_ctx/num_predict" 0 || check "ok: num_ctx/num_predict" 1
[ "$(jget "$LED" cwd)" = "\"$PWD\"" ] && check "ok: cwd" 0 || check "ok: cwd" 1 "$(jget "$LED" cwd)"
[ "$(jget "$LED" session)" = null ] && check "ok: session null without env" 0 || check "ok: session null without env" 1

# session precedence and no other env leaking
LED="$TMPD/led/sess.jsonl"; rm -f "$LED"
CLAUDE_CODE_SESSION_ID=sess-b FORGE_SESSION_ID=sess-c FORGE_LLM_LEDGER="$LED" OLLAMA_URL="$FAKE" bash "$SCRIPT" "ok" >/dev/null 2>&1 </dev/null
[ "$(jget "$LED" session)" = '"sess-b"' ] && check "session: CLAUDE_CODE_SESSION_ID beats FORGE_SESSION_ID" 0 || check "session precedence" 1 "$(jget "$LED" session)"

# ---- endpoint error ---------------------------------------------------------
run_case enderr "err-prompt"
assert_io enderr 1 "" "llm-delegate.sh: endpoint error: model not found"
ledger_checks enderr endpoint_error 1 no "err-prompt" "model not found"

# ---- truncated (with partial output) ---------------------------------------
run_case trunc "trunc-prompt"
assert_io trunc 2 "partial" "$STAT
llm-delegate.sh: truncated at num_predict (partial output on stdout)"
ledger_checks trunc truncated 2 yes "trunc-prompt"
[ "$(jget "$LED" done_reason)" = '"length"' ] && check "trunc: done_reason=length" 0 || check "trunc: done_reason=length" 1
[ "$(jget "$LED" response_chars)" = 7 ] && check "trunc: response_chars=7" 0 || check "trunc: response_chars=7" 1

# ---- empty model output / think-only ----------------------------------------
run_case empty "empty-prompt"
assert_io empty 2 "" "llm-delegate.sh: empty response from model"
ledger_checks empty empty_output 2 yes "empty-prompt"
[ "$(jget "$LED" response_chars)" = null ] && [ "$(jget "$LED" response_sha256)" = null ] && check "empty: response fields null" 0 || check "empty: response fields null" 1

run_case think "think-prompt"
assert_io think 2 "" "llm-delegate.sh: empty response from model"
ledger_checks think empty_output 2 yes "think-prompt" "secret reasoning"

# ---- invalid JSON / empty body ---------------------------------------------
run_case badjson "badjson-prompt"
assert_io badjson 1 "" "llm-delegate.sh: invalid JSON response from endpoint"
ledger_checks badjson bad_json 1 no "badjson-prompt" "this is not json"

run_case nobody "nobody-prompt"
assert_io nobody 1 "" "llm-delegate.sh: empty response from endpoint"
ledger_checks nobody empty_body 1 no "nobody-prompt"

# ---- timeout (curl exit 28) -------------------------------------------------
run_case slow "slow-prompt" --timeout 1
assert_io slow 1 "" "llm-delegate.sh: request failed or timed out after 1s (curl exit 28)"
ledger_checks slow timeout 1 no "slow-prompt"

# ---- other curl failure: the server drops the connection --------------------
# A shim curl that passes /api/tags to the real curl and fails generate with exit 7.
REAL_CURL="$(command -v curl)"
cat > "$TMPD/shim/curl" <<SH
#!/usr/bin/env bash
case "\$*" in
  *:11434*) exit 7 ;;
  *api/generate*) exit 7 ;;
esac
exec "$REAL_CURL" "\$@"
SH
chmod +x "$TMPD/shim/curl"
LED="$TMPD/led/reqfail.jsonl"; rm -f "$LED"
PATH="$TMPD/shim:$PATH" FORGE_LLM_LEDGER="$LED" OLLAMA_URL="$FAKE" bash "$SCRIPT" "ok-x" > "$TMPD/out" 2> "$TMPD/err" < /dev/null
RC=$?; OUT="$(cat "$TMPD/out")"; ERR="$(cat "$TMPD/err")"
assert_io reqfail 1 "" "llm-delegate.sh: request failed or timed out after 600s (curl exit 7)"
ledger_checks reqfail request_failed 1 no "ok-x"

# ---- unreachable endpoint (hermetic: shim blocks the fixed localhost:11434 fallback) ----
LED="$TMPD/led/unreach.jsonl"; rm -f "$LED"
PATH="$TMPD/shim:$PATH" FORGE_LLM_LEDGER="$LED" OLLAMA_URL="http://127.0.0.1:1" bash "$SCRIPT" "ok-x" > "$TMPD/out" 2> "$TMPD/err" < /dev/null
RC=$?; OUT="$(cat "$TMPD/out")"; ERR="$(cat "$TMPD/err")"
assert_io unreach 1 "" "llm-delegate.sh: no reachable Ollama endpoint found"
[ "$(nlines "$LED")" = 1 ] && check "unreach: exactly one ledger line" 0 || check "unreach: exactly one ledger line" 1
[ "$(jget "$LED" outcome)" = '"unreachable"' ] && check "unreach: outcome=unreachable" 0 || check "unreach: outcome=unreachable" 1 "$(jget "$LED" outcome)"
[ "$(jget "$LED" endpoint)" = null ] && check "unreach: endpoint null" 0 || check "unreach: endpoint null" 1

# ---- no prompt (stdin is a terminal) ----------------------------------------
if command -v script >/dev/null 2>&1; then
  LED="$TMPD/led/noprompt.jsonl"; rm -f "$LED"
  FORGE_LLM_LEDGER="$LED" OLLAMA_URL="$FAKE" script -qec "bash '$SCRIPT'" /dev/null > "$TMPD/out" 2>&1 < /dev/null
  [ "$(nlines "$LED")" = 1 ] && [ "$(jget "$LED" outcome)" = '"no_prompt"' ] && check "no_prompt: logged" 0 || check "no_prompt: logged" 1 "$(cat "$LED" 2>/dev/null)"
else
  echo "SKIP  no_prompt: 'script' (pty) not installed"
fi

# ---- FORGE_LLM_DISABLE=1 ----------------------------------------------------
LED="$TMPD/led/disable.jsonl"; rm -f "$LED"
FORGE_LLM_DISABLE=1 FORGE_LLM_LEDGER="$LED" OLLAMA_URL="$FAKE" bash "$SCRIPT" "ok" > "$TMPD/out" 2> "$TMPD/err" < /dev/null
RC=$?; OUT="$(cat "$TMPD/out")"; ERR="$(cat "$TMPD/err")"
assert_io disable 1 "" "llm-delegate.sh: FORGE_LLM_DISABLE=1, local delegation disabled; fall back to the pinned Claude tier"
[ "$(nlines "$LED")" = 1 ] && [ "$(jget "$LED" outcome)" = '"disabled"' ] && check "disable: logged disabled" 0 || check "disable: logged disabled" 1 "$(cat "$LED" 2>/dev/null)"

# ---- FORGE_LLM_LEDGER=off ---------------------------------------------------
rm -rf "$HOME/.local"
FORGE_LLM_LEDGER=off OLLAMA_URL="$FAKE" bash "$SCRIPT" "ok" > "$TMPD/out" 2> "$TMPD/err" < /dev/null
RC=$?
{ [ "$RC" = 0 ] && [ ! -e "$HOME/.local" ] && [ "$(cat "$TMPD/out")" = "hello world" ]; } && check "off: nothing written, behaviour same" 0 || check "off: nothing written, behaviour same" 1
FORGE_LLM_LEDGER=off FORGE_LLM_DISABLE=1 bash "$SCRIPT" "ok" >/dev/null 2>&1 </dev/null
[ ! -e "$HOME/.local" ] && check "off: disabled path writes nothing" 0 || check "off: disabled path writes nothing" 1

# ---- default path under XDG state, dir mode 700 -----------------------------
OLLAMA_URL="$FAKE" bash "$SCRIPT" "ok" >/dev/null 2>&1 </dev/null
DEF="$HOME/.local/state/forge/llm-delegate/calls.jsonl"
{ [ "$(nlines "$DEF")" = 1 ] && [ "$(stat -c %a "$(dirname "$DEF")")" = 700 ] && [ "$(stat -c %a "$DEF")" = 600 ]; } && check "default path, dir 700, file 600" 0 || check "default path, dir 700, file 600" 1
XDG_STATE_HOME="$TMPD/xdg" OLLAMA_URL="$FAKE" bash "$SCRIPT" "ok" >/dev/null 2>&1 </dev/null
[ "$(nlines "$TMPD/xdg/forge/llm-delegate/calls.jsonl")" = 1 ] && check "XDG_STATE_HOME honoured" 0 || check "XDG_STATE_HOME honoured" 1

# ---- unwritable ledger path changes nothing ---------------------------------
mkdir -p "$TMPD/ro"; chmod 500 "$TMPD/ro"
if [ "$(id -u)" = 0 ]; then
  echo "SKIP  unwritable ledger (running as root, permissions not enforced)"
else
  FORGE_LLM_LEDGER="$TMPD/ro/sub/calls.jsonl" OLLAMA_URL="$FAKE" bash "$SCRIPT" "ok" > "$TMPD/out" 2> "$TMPD/err" < /dev/null
  RC=$?
  { [ "$RC" = 0 ] && [ "$(cat "$TMPD/out")" = "hello world" ] && [ "$(cat "$TMPD/err")" = "$STAT" ]; } && check "unwritable ledger: exit/stdout/stderr unchanged (success)" 0 || check "unwritable ledger: success unchanged" 1 "rc=$RC err=$(cat "$TMPD/err")"
  FORGE_LLM_LEDGER="$TMPD/ro/sub/calls.jsonl" OLLAMA_URL="$FAKE" bash "$SCRIPT" "err" > "$TMPD/out" 2> "$TMPD/err" < /dev/null
  RC=$?
  { [ "$RC" = 1 ] && [ "$(cat "$TMPD/err")" = "llm-delegate.sh: endpoint error: model not found" ]; } && check "unwritable ledger: failure path unchanged" 0 || check "unwritable ledger: failure path unchanged" 1 "rc=$RC err=$(cat "$TMPD/err")"
fi
chmod 700 "$TMPD/ro"

# ---- concurrent callers do not interleave -----------------------------------
LED="$TMPD/led/conc.jsonl"; rm -f "$LED"
PIDS=()
for _ in 1 2 3 4 5 6 7 8; do
  FORGE_LLM_LEDGER="$LED" OLLAMA_URL="$FAKE" bash "$SCRIPT" "ok" >/dev/null 2>&1 </dev/null &
  PIDS+=("$!")
done
wait "${PIDS[@]}"
{ [ "$(nlines "$LED")" = 8 ] && jvalid "$LED"; } && check "concurrent: 8 intact lines" 0 || check "concurrent: 8 intact lines" 1 "$(nlines "$LED")"

# ---- H1: no EPOCHREALTIME (bash < 5) must not abort under set -u ---------------
# Simulated: a copy of the helper whose EPOCHREALTIME is renamed to a variable that is never set.
sed 's/EPOCHREALTIME/NO_SUCH_VAR_X/g' "$SCRIPT" > "$TMPD/h1.sh"
LED="$TMPD/led/h1.jsonl"; rm -f "$LED"
FORGE_LLM_LEDGER="$LED" OLLAMA_URL="$FAKE" bash "$TMPD/h1.sh" "ok" > "$TMPD/out" 2> "$TMPD/err" < /dev/null
RC=$?; OUT="$(cat "$TMPD/out")"; ERR="$(cat "$TMPD/err")"
assert_io h1 0 "hello world" "$STAT"
{ [ "$(nlines "$LED")" = 1 ] && [ "$(jget "$LED" wall_ms)" != null ] && [ -n "$(jget "$LED" wall_ms)" ]; } && check "h1: ledger line with wall_ms via date fallback" 0 || check "h1: ledger line with wall_ms via date fallback" 1 "$(cat "$LED" 2>/dev/null)"

# ---- H2: a FIFO or symlinked ledger path cannot hang or change anything ---------
now_ms() { echo $(( $(date +%s%N) / 1000000 )); }
GUARD=""; command -v timeout >/dev/null 2>&1 && GUARD="timeout 30"
mkfifo "$TMPD/led/fifo"
T0=$(now_ms)
FORGE_LLM_LEDGER="$TMPD/led/fifo" OLLAMA_URL="$FAKE" $GUARD bash "$SCRIPT" "ok" > "$TMPD/out" 2> "$TMPD/err" < /dev/null
RC=$?; T1=$(now_ms); OUT="$(cat "$TMPD/out")"; ERR="$(cat "$TMPD/err")"
assert_io fifo 0 "hello world" "$STAT"
[ $((T1 - T0)) -lt 4000 ] && check "fifo ledger: returns promptly" 0 || check "fifo ledger: returns promptly" 1 "$((T1 - T0)) ms"
: > "$TMPD/led/target.jsonl"
ln -s "$TMPD/led/target.jsonl" "$TMPD/led/link.jsonl"
T0=$(now_ms)
FORGE_LLM_LEDGER="$TMPD/led/link.jsonl" OLLAMA_URL="$FAKE" $GUARD bash "$SCRIPT" "ok" > "$TMPD/out" 2> "$TMPD/err" < /dev/null
RC=$?; T1=$(now_ms); OUT="$(cat "$TMPD/out")"; ERR="$(cat "$TMPD/err")"
assert_io symlink 0 "hello world" "$STAT"
[ $((T1 - T0)) -lt 4000 ] && check "symlink ledger: returns promptly" 0 || check "symlink ledger: returns promptly" 1 "$((T1 - T0)) ms"
[ ! -s "$TMPD/led/target.jsonl" ] && check "symlink ledger: target not written" 0 || check "symlink ledger: target not written" 1 "$(cat "$TMPD/led/target.jsonl")"

# ---- H3: untrusted endpoint values are coerced; no free text reaches the ledger ---
LONGMODEL="$(printf 'm%.0s' $(seq 1 150))"
run_case junk "junk-prompt" --quiet --model "$LONGMODEL"
assert_io junk 0 "hello world" ""
[ "$(nlines "$LED")" = 1 ] && check "junk: one ledger line" 0 || check "junk: one ledger line" 1
[ "$(jget "$LED" eval_tokens)" = null ] && check "junk: string eval_count -> null" 0 || check "junk: string eval_count -> null" 1 "$(jget "$LED" eval_tokens)"
[ "$(jget "$LED" prompt_tokens)" = null ] && check "junk: bool prompt_eval_count -> null" 0 || check "junk: bool prompt_eval_count -> null" 1 "$(jget "$LED" prompt_tokens)"
[ "$(jget "$LED" load_ms)" = null ] && check "junk: negative duration -> null" 0 || check "junk: negative duration -> null" 1 "$(jget "$LED" load_ms)"
[ "$(jget "$LED" done_reason)" = '"other"' ] && check "junk: sentence done_reason -> other" 0 || check "junk: sentence done_reason -> other" 1 "$(jget "$LED" done_reason)"
grep -qE 'JUNKSENTENCE|Ignore all|seven' "$LED" && check "junk: none of the endpoint text in the line" 1 "$(cat "$LED")" || check "junk: none of the endpoint text in the line" 0
[ "$(jget "$LED" model)" = "\"$(printf 'm%.0s' $(seq 1 100))\"" ] && check "junk: model capped at 100 chars" 0 || check "junk: model capped at 100 chars" 1 "$(jget "$LED" model | wc -c)"

echo
if [ "$FAILS" = 0 ]; then echo "ALL PASS"; else echo "$FAILS FAILED"; exit 1; fi
