#!/usr/bin/env bash
# llm-delegate.sh: Delegate code generation to a local or remote Ollama LLM.
# Needs: chmod +x /srv/forge/core/scripts/llm-delegate.sh
#
# Usage: llm-delegate.sh [OPTIONS] [PROMPT]
#   If PROMPT is omitted, reads from stdin.
#
# Options:
#   --model MODEL      Ollama model name (default: qwen3-coder:30b)
#   --system PROMPT    System prompt override (default: built-in)
#   --url URL          Ollama endpoint (default: http://localhost:11434)
#   --num-ctx N        Context window (default: 4096)
#   --temperature T    Sampling temperature (default: 0.2)
#   --strip-fences     Strip outer markdown code fences from output
#   --quiet            Suppress stderr stats
#
# Environment variables:
#   OLLAMA_URL            Primary Ollama endpoint
#   FORGE_LLM_REMOTE_URL  Fallback remote Ollama endpoint
#   FORGE_LLM_MODEL       Default model override
#   FORGE_LLM_SYSTEM      Default system prompt override
#
# Exit codes: 0=success, 1=unavailable, 2=empty response

set -euo pipefail

DEFAULT_SYSTEM="You are a coding assistant. Output exactly ONE solution. Never provide alternatives, variations, or here-is-also versions. No usage examples unless asked. Be concise. Prefer standard library solutions."

MODEL=""
SYSTEM=""
URL=""
NUM_CTX=4096
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
    echo "llm-delegate.sh: no reachable Ollama endpoint found" >&2
    exit 1
fi

[ -z "$MODEL" ] && MODEL="${FORGE_LLM_MODEL:-qwen3-coder:30b}"
[ -z "$SYSTEM" ] && SYSTEM="${FORGE_LLM_SYSTEM:-$DEFAULT_SYSTEM}"

if [ ${#ARGS[@]} -gt 0 ]; then
    PROMPT="${ARGS[*]}"
elif [ -t 0 ]; then
    echo "llm-delegate.sh: no prompt given and stdin is a terminal" >&2
    exit 1
else
    PROMPT=$(cat)
fi

PAYLOAD=$(python3 -c "
import json, sys
model, system, prompt, num_ctx, temperature = sys.argv[1:6]
print(json.dumps({
    'model': model, 'system': system, 'prompt': prompt, 'stream': False,
    'options': {'temperature': float(temperature), 'num_ctx': int(num_ctx)},
}))
" "$MODEL" "$SYSTEM" "$PROMPT" "$NUM_CTX" "$TEMPERATURE")

RESPONSE=$(curl -s "${RESOLVED_URL}/api/generate" -d "$PAYLOAD")

echo "$RESPONSE" | python3 -c "
import json, sys, re

strip_fences = $([ "$STRIP_FENCES" -eq 1 ] && echo True || echo False)
quiet = $([ "$QUIET" -eq 1 ] && echo True || echo False)

d = json.load(sys.stdin)
text = d.get('response', '')
text = re.sub(r'<think>.*?</think>', '', text, flags=re.DOTALL).strip()

if strip_fences:
    text = re.sub(r'^\`\`\`[a-zA-Z0-9_+-]*\n', '', text)
    text = re.sub(r'\n\`\`\`\s*\$', '', text)
    text = text.strip()

tokens = d.get('eval_count', 0)
if tokens <= 0:
    print('llm-delegate.sh: empty response from model', file=sys.stderr)
    sys.exit(2)

print(text)
if not quiet:
    dur = d.get('total_duration', 0) / 1e9
    speed = tokens / max(d.get('eval_duration', 1) / 1e9, 0.001)
    print(f'[{tokens} tokens, {dur:.1f}s, {speed:.1f} tok/s, model: {d.get(\"model\", \"?\")}]', file=sys.stderr)
"
