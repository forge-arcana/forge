#!/usr/bin/env bash
# llm-delegate.sh: Delegate code generation to a local or remote Ollama LLM.
# Needs: chmod +x <forge>/core/scripts/llm-delegate.sh
#
# Usage: llm-delegate.sh [OPTIONS] [PROMPT]
#   If PROMPT is omitted, reads from stdin.
#
# Options:
#   --model MODEL      Ollama model name (default: qwen3-coder:30b)
#   --system PROMPT    System prompt override (default: built-in)
#   --url URL          Ollama endpoint (default: http://localhost:11434)
#   --num-ctx N        Context window (default: 4096)
#   --num-predict N    Max output tokens (default: num_ctx * 3/4)
#   --timeout SECS     Curl timeout in seconds (default: 600)
#   --temperature T    Sampling temperature (default: 0.2)
#   --strip-fences     Strip outer markdown code fences from output
#   --quiet            Suppress stderr stats
#
# Environment variables:
#   OLLAMA_URL               Primary Ollama endpoint
#   FORGE_LLM_REMOTE_URL     Fallback remote Ollama endpoint
#   FORGE_LLM_MODEL          Default model override
#   FORGE_LLM_SYSTEM         Default system prompt override
#   FORGE_LLM_NUM_PREDICT    Default num_predict override
#   FORGE_LLM_TIMEOUT        Default timeout override
#   FORGE_LLM_DISABLE        Set to 1 to skip delegation (exits 1 at once so callers fall back to Claude)
#   FORGE_LLM_LEDGER         Usage ledger path, or "off" to disable it
#                            (default: ${XDG_STATE_HOME:-$HOME/.local/state}/forge/llm-delegate/calls.jsonl)
#
# Exit codes: 0=success, 1=unavailable/timeout, 2=empty, think-only, or truncated at num_predict (partial text still on stdout)
#
# Usage ledger: every invocation, on every exit path, appends exactly one JSON line to the
# ledger file (dir mode 700, file mode 600): version, UTC start time, wall time, model,
# endpoint class (local/remote, never the URL), options, prompt/system char counts, Ollama's
# own token and timing counters, done_reason, exit code, outcome (ok, disabled, unreachable,
# no_prompt, timeout, request_failed, empty_body, bad_json, endpoint_error, empty_output,
# truncated), length and sha256 of the printed text, session id (CLAUDE_SESSION_ID,
# CLAUDE_CODE_SESSION_ID or FORGE_SESSION_ID when set), and cwd. Prompt and response text are
# never stored. Ledger failures are swallowed: stdout, stderr and exit codes are unchanged.
# The ledger stores the working directory (cwd), so it stays local at mode 600.

set -euo pipefail

# ---- usage ledger (one line per call, written by the EXIT trap) --------------------------
LEDGER="${FORGE_LLM_LEDGER:-${XDG_STATE_HOME:-$HOME/.local/state}/forge/llm-delegate/calls.jsonl}"
# Microseconds since the epoch into REPLY. EPOCHREALTIME needs bash 5; older shells fall
# back to GNU date, and an empty value is tolerated by the writer.
ledger_now_us() {
    REPLY="${EPOCHREALTIME:-}"
    if [ -n "$REPLY" ]; then
        REPLY="${REPLY/[.,]/}"
    else
        REPLY="$(date +%s%6N 2>/dev/null || true)"
    fi
}
ledger_now_us
LEDGER_START_US="$REPLY"
LEDGER_OUTCOME=""
LEDGER_METRICS=""
PROMPT_CHARS=""
SYSTEM_CHARS=""
RESOLVED_URL=""
MODEL=""
NUM_CTX=""
NUM_PREDICT=""
TEMPERATURE=""
if [ "$LEDGER" != "off" ]; then
    LEDGER_METRICS=$(mktemp 2>/dev/null) || LEDGER_METRICS=""
fi

# shellcheck disable=SC2016
LEDGER_PY='
import sys, os, json, time, hashlib, math, re, stat
from urllib.parse import urlparse
(path, met, start_us, end_us, rc, outcome, model, url, num_ctx, num_predict, temp, pchars, schars) = sys.argv[1:14]
def to_int(x):
    try:
        return int(x)
    except Exception:
        return None
def to_float(x):
    try:
        return float(x)
    except Exception:
        return None
def nn(x):
    # endpoint values are untrusted: only non-negative ints survive
    if isinstance(x, bool):
        return None
    if isinstance(x, float):
        if not math.isfinite(x) or x != int(x):
            return None
        x = int(x)
    if isinstance(x, int) and x >= 0:
        return x
    return None
DONE_REASONS = ("stop", "length", "load", "unload")
def reason(x):
    if x is None or x == "":
        return None
    return x if isinstance(x, str) and x in DONE_REASONS else "other"
def sha(x):
    return x if isinstance(x, str) and re.fullmatch("[0-9a-f]{64}", x) else None
m = {}
try:
    with open(met) as fh:
        m = json.load(fh)
except Exception:
    m = {}
if not isinstance(m, dict):
    m = {}
rc_i = to_int(rc)
if not outcome:
    outcome = m.get("outcome") or ("ok" if rc_i == 0 else "")
s, e = to_int(start_us), to_int(end_us)
now = time.time()
start = s / 1e6 if s is not None else now
wall = (e - s) // 1000 if (s is not None and e is not None) else None
endpoint = None
if url:
    host = (urlparse(url).hostname or "").lower()
    endpoint = "local" if host in ("localhost", "127.0.0.1", "::1") else "remote"
session = None
for k in ("CLAUDE_SESSION_ID", "CLAUDE_CODE_SESSION_ID", "FORGE_SESSION_ID"):
    if os.environ.get(k):
        session = os.environ[k]
        break
def g(k):
    return m.get(k)
line = {
    "v": 1,
    "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(start)),
    "wall_ms": wall,
    "model": model[:100] if model else None,
    "endpoint": endpoint,
    "num_ctx": to_int(num_ctx),
    "num_predict": to_int(num_predict),
    "temperature": to_float(temp),
    "prompt_chars": to_int(pchars),
    "system_chars": to_int(schars),
    "prompt_tokens": nn(g("prompt_tokens")),
    "eval_tokens": nn(g("eval_tokens")),
    "total_ms": nn(g("total_ms")),
    "load_ms": nn(g("load_ms")),
    "prompt_eval_ms": nn(g("prompt_eval_ms")),
    "eval_ms": nn(g("eval_ms")),
    "done_reason": reason(g("done_reason")),
    "exit": rc_i,
    "outcome": outcome or None,
    "response_chars": nn(g("response_chars")),
    "response_sha256": sha(g("response_sha256")),
    "session": session,
    "cwd": os.getcwd(),
}
data = (json.dumps(line, separators=(",", ":")) + "\n").encode("utf-8")
d = os.path.dirname(path)
if d:
    os.makedirs(d, mode=0o700, exist_ok=True)
fd = os.open(path, os.O_WRONLY | os.O_APPEND | os.O_CREAT | os.O_NONBLOCK | os.O_NOFOLLOW, 0o600)
try:
    if stat.S_ISREG(os.fstat(fd).st_mode):
        os.write(fd, data)
finally:
    os.close(fd)
'

ledger_write() {
    local rc=$?
    trap - EXIT
    set +eu
    {
        if [ "$LEDGER" != "off" ]; then
            ledger_now_us
            local bound=()
            command -v timeout >/dev/null 2>&1 && bound=(timeout 5)
            "${bound[@]}" python3 -I -c "$LEDGER_PY" "$LEDGER" "$LEDGER_METRICS" "$LEDGER_START_US" "$REPLY" \
                "$rc" "$LEDGER_OUTCOME" "$MODEL" "$RESOLVED_URL" "$NUM_CTX" "$NUM_PREDICT" "$TEMPERATURE" \
                "$PROMPT_CHARS" "$SYSTEM_CHARS"
        fi
        [ -n "$LEDGER_METRICS" ] && rm -f "$LEDGER_METRICS"
    } >/dev/null 2>&1
    return 0
}
trap ledger_write EXIT

if [ "${FORGE_LLM_DISABLE:-}" = "1" ]; then
    LEDGER_OUTCOME="disabled"
    echo "llm-delegate.sh: FORGE_LLM_DISABLE=1, local delegation disabled; fall back to the pinned Claude tier" >&2
    exit 1
fi

DEFAULT_SYSTEM="You are a coding assistant. Output exactly ONE solution. Never provide alternatives, variations, or here-is-also versions. No usage examples unless asked. Be concise. Prefer standard library solutions."

MODEL=""
SYSTEM=""
URL=""
NUM_CTX=4096
NUM_PREDICT=""
TIMEOUT="${FORGE_LLM_TIMEOUT:-600}"
TEMPERATURE=0.2
STRIP_FENCES=0
QUIET=0
ARGS=()

while [ $# -gt 0 ]; do
    case "$1" in
        --model) MODEL="$2"; shift 2 ;;
        --system) SYSTEM="$2"; shift 2 ;;
        --url) URL="$2"; shift 2 ;;
        --num-ctx) NUM_CTX="$2"; shift 2 ;;
        --num-predict) NUM_PREDICT="$2"; shift 2 ;;
        --timeout) TIMEOUT="$2"; shift 2 ;;
        --temperature) TEMPERATURE="$2"; shift 2 ;;
        --strip-fences) STRIP_FENCES=1; shift ;;
        --quiet) QUIET=1; shift ;;
        *) ARGS+=("$1"); shift ;;
    esac
done

CANDIDATE_URLS=()
[ -n "${OLLAMA_URL:-}" ] && CANDIDATE_URLS+=("$OLLAMA_URL")
[ -n "$URL" ] && CANDIDATE_URLS+=("$URL")
CANDIDATE_URLS+=("http://localhost:11434")
[ -n "${FORGE_LLM_REMOTE_URL:-}" ] && CANDIDATE_URLS+=("$FORGE_LLM_REMOTE_URL")

RESOLVED_URL=""
for candidate in "${CANDIDATE_URLS[@]}"; do
    if curl -sf "${candidate}/api/tags" >/dev/null 2>&1; then
        RESOLVED_URL="$candidate"
        break
    fi
done
if [ -z "$RESOLVED_URL" ]; then
    LEDGER_OUTCOME="unreachable"
    echo "llm-delegate.sh: no reachable Ollama endpoint found" >&2
    exit 1
fi

[ -z "$MODEL" ] && MODEL="${FORGE_LLM_MODEL:-qwen3-coder:30b}"
[ -z "$SYSTEM" ] && SYSTEM="${FORGE_LLM_SYSTEM:-$DEFAULT_SYSTEM}"
[ -z "$NUM_PREDICT" ] && NUM_PREDICT="${FORGE_LLM_NUM_PREDICT:-$((NUM_CTX * 3 / 4))}"
SYSTEM_CHARS=${#SYSTEM}

if [ ${#ARGS[@]} -gt 0 ]; then
    PROMPT="${ARGS[*]}"
elif [ -t 0 ]; then
    LEDGER_OUTCOME="no_prompt"
    echo "llm-delegate.sh: no prompt given and stdin is a terminal" >&2
    exit 1
else
    PROMPT=$(cat)
fi
PROMPT_CHARS=${#PROMPT}

PAYLOAD=$(python3 -c "
import json, sys
model, system, prompt, num_ctx, num_predict, temperature = sys.argv[1:7]
print(json.dumps({
    'model': model, 'system': system, 'prompt': prompt, 'stream': False,
    'options': {'temperature': float(temperature), 'num_ctx': int(num_ctx), 'num_predict': int(num_predict)},
}))
" "$MODEL" "$SYSTEM" "$PROMPT" "$NUM_CTX" "$NUM_PREDICT" "$TEMPERATURE")

set +e
RESPONSE=$(curl -s --max-time "$TIMEOUT" "${RESOLVED_URL}/api/generate" -d "$PAYLOAD")
CURL_EXIT=$?
set -e
if [ $CURL_EXIT -ne 0 ]; then
    if [ $CURL_EXIT -eq 28 ]; then LEDGER_OUTCOME="timeout"; else LEDGER_OUTCOME="request_failed"; fi
    echo "llm-delegate.sh: request failed or timed out after ${TIMEOUT}s (curl exit $CURL_EXIT)" >&2
    exit 1
fi
if [ -z "$RESPONSE" ]; then
    LEDGER_OUTCOME="empty_body"
    echo "llm-delegate.sh: empty response from endpoint" >&2
    exit 1
fi

echo "$RESPONSE" | python3 -c "
import json, sys, re, hashlib

strip_fences = $([ "$STRIP_FENCES" -eq 1 ] && echo True || echo False)
quiet = $([ "$QUIET" -eq 1 ] && echo True || echo False)

# Ledger hand-off: metrics go to a private temp file named in argv[1]; stdout/stderr are untouched.
met_path = sys.argv[1] if len(sys.argv) > 1 else ''

def rec(**kw):
    if not met_path:
        return
    try:
        with open(met_path, 'w') as fh:
            json.dump(kw, fh)
    except Exception:
        pass

def to_ms(ns):
    return int(round(ns / 1e6)) if isinstance(ns, (int, float)) and not isinstance(ns, bool) else None

try:
    d = json.load(sys.stdin)
except json.JSONDecodeError:
    rec(outcome='bad_json')
    print('llm-delegate.sh: invalid JSON response from endpoint', file=sys.stderr)
    sys.exit(1)

if not isinstance(d, dict):
    rec(outcome='bad_json')

base = {}
if isinstance(d, dict):
    base = {
        'prompt_tokens': d.get('prompt_eval_count'),
        'eval_tokens': d.get('eval_count'),
        'total_ms': to_ms(d.get('total_duration')),
        'load_ms': to_ms(d.get('load_duration')),
        'prompt_eval_ms': to_ms(d.get('prompt_eval_duration')),
        'eval_ms': to_ms(d.get('eval_duration')),
        'done_reason': d.get('done_reason'),
    }

if d.get('error'):
    rec(outcome='endpoint_error', **base)
    print(f'llm-delegate.sh: endpoint error: {d[\"error\"]}', file=sys.stderr)
    sys.exit(1)

text = d.get('response', '')
text = re.sub(r'<think>.*?</think>', '', text, flags=re.DOTALL).strip()
text = re.sub(r'<think>.*\Z', '', text, flags=re.DOTALL).strip()

if strip_fences:
    text = re.sub(r'^\`\`\`[a-zA-Z0-9_+-]*\n', '', text)
    text = re.sub(r'\n\`\`\`\s*\$', '', text)
    text = text.strip()

done_reason = d.get('done_reason', '')
tokens = d.get('eval_count', 0)

if not text:
    rec(outcome='empty_output', **base)
    if done_reason == 'length':
        print('llm-delegate.sh: hit num_predict limit with no output', file=sys.stderr)
    else:
        print('llm-delegate.sh: empty response from model', file=sys.stderr)
    sys.exit(2)

rec(outcome=('truncated' if done_reason == 'length' else 'ok'), response_chars=len(text),
    response_sha256=hashlib.sha256(text.encode('utf-8', 'replace')).hexdigest(), **base)
print(text)

if done_reason == 'length':
    if not quiet:
        dur = d.get('total_duration', 0) / 1e9
        speed = tokens / max(d.get('eval_duration', 1) / 1e9, 0.001)
        print(f'[{tokens} tokens, {dur:.1f}s, {speed:.1f} tok/s, model: {d.get(\"model\", \"?\")}]', file=sys.stderr)
    print('llm-delegate.sh: truncated at num_predict (partial output on stdout)', file=sys.stderr)
    sys.exit(2)

if not quiet:
    dur = d.get('total_duration', 0) / 1e9
    speed = tokens / max(d.get('eval_duration', 1) / 1e9, 0.001)
    print(f'[{tokens} tokens, {dur:.1f}s, {speed:.1f} tok/s, model: {d.get(\"model\", \"?\")}]', file=sys.stderr)
" "$LEDGER_METRICS"
