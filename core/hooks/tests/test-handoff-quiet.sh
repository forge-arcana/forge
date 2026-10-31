#!/usr/bin/env bash
#
# Tests for handoff-stop.sh's tx_quiet (transcript quiet check). No tmux, no
# real sessions: fake transcripts in a temp dir.
# Run:  bash core/hooks/tests/test-handoff-quiet.sh      (non-zero on failure)

HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.."
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
export HANDOFF_DIR="$TMPD/h"
mkdir -p "$HANDOFF_DIR/state"

HANDOFF_SOURCE_ONLY=1 source "$HERE/handoff-stop.sh"
set +u

FAILS=0
check() { if [ "$2" = 0 ]; then echo "PASS  $1"; else echo "FAIL  $1  (${3:-})"; FAILS=$((FAILS + 1)); fi; }

T0="2026-10-31T10:00:00.000Z"
AT="$(date -u -d "$T0" +%s)"
CUT="$((AT + 2)).000"
GRACED='["user","attachment","file-history-snapshot"]'

# quiet NAME WANT(0 quiet / 1 activity) LINES...   (each LINES arg is one JSON line)
quiet() {
  local name="$1" want="$2" f="$TMPD/tx.jsonl" rc l; shift 2
  : > "$f"
  for l in "$@"; do printf '%s\n' "$l" >> "$f"; done
  tx_quiet "$f" 0 "$CUT" "$GRACED" 1; rc=$?
  [ "$rc" = "$want" ] && check "$name" 0 || check "$name" 1 "rc=$rc want=$want"
}

# The observed failing sequence: untimestamped metadata incl. tools-used, then
# the clear's own lines (no promptId).
OBSERVED=(
  '{"type":"mode","mode":"normal"}'
  '{"type":"atis-latch","latch":true}'
  '{"type":"tools-used","tools":["Bash"]}'
  '{"type":"bridge-session","id":"x"}'
  "{\"type\":\"file-history-snapshot\",\"messageId\":\"m\",\"snapshot\":{\"timestamp\":\"$T0\"}}"
  "{\"type\":\"attachment\",\"timestamp\":\"$T0\",\"attachment\":{}}"
  "{\"type\":\"user\",\"timestamp\":\"$T0\",\"message\":{\"content\":\"<command-name>/clear</command-name>\"}}"
  "{\"type\":\"user\",\"timestamp\":\"$T0\",\"message\":{\"content\":\"<local-command-stdout></local-command-stdout>\"}}"
  "{\"type\":\"system\",\"subtype\":\"local_command\",\"timestamp\":\"$T0\"}"
)
quiet "1 observed post-clear sequence (with tools-used) is quiet" 0 "${OBSERVED[@]}"
quiet "2 typed user line with promptId is activity" 1 "${OBSERVED[@]}" \
  "{\"type\":\"user\",\"timestamp\":\"$T0\",\"promptId\":\"p1\",\"message\":{\"content\":\"hi\"}}"
quiet "2b user line with turnOrigin is activity" 1 \
  "{\"type\":\"user\",\"timestamp\":\"$T0\",\"turnOrigin\":\"human\"}"
quiet "3 untimestamped user line is activity" 1 '{"type":"user","message":{"content":"hi"}}'
quiet "3b untimestamped assistant line is activity" 1 '{"type":"assistant","message":{}}'
quiet "4 unknown untimestamped metadata type is ignored" 0 '{"type":"future-meta","x":1}'
quiet "4b unknown TIMESTAMPED type is activity" 1 "{\"type\":\"future-meta\",\"timestamp\":\"$T0\"}"
quiet "5 unparseable complete line is activity" 1 'not json at all'
quiet "6 assistant line is activity" 1 "{\"type\":\"assistant\",\"timestamp\":\"$T0\"}"
quiet "7 late user line (past cutoff) is activity" 1 "{\"type\":\"user\",\"timestamp\":\"2026-10-31T10:00:09.000Z\"}"
quiet "8 tools-used alone is quiet" 0 '{"type":"tools-used"}'
quiet "9 typeless {} is activity" 1 '{}'
quiet "10 non-string type is activity" 1 '{"type":5}'
quiet "11 untimestamped api-request-blob is activity" 1 '{"type":"api-request-blob","x":1}'
quiet "11b untimestamped api-request is activity" 1 '{"type":"api-request"}'
quiet "12 timestamped mode is quiet via the explicit list" 0 "{\"type\":\"mode\",\"timestamp\":\"2030-01-01T00:00:00.000Z\"}"


# the same rules hold in the pre-clear call (graced = assistant only)
f="$TMPD/pre.jsonl"; printf '%s\n' '{"type":"tools-used"}' '{}' > "$f"
tx_quiet "$f" 0 "$CUT" '["assistant"]' 0; rc=$?
[ "$rc" = 1 ] && check "13 pre-clear: {} is activity" 0 || check "13 pre-clear: {} is activity" 1 "rc=$rc"
printf '%s\n' '{"type":"tools-used"}' '{"type":"api-request-blob"}' > "$f"
tx_quiet "$f" 0 "$CUT" '["assistant"]' 0; rc=$?
[ "$rc" = 1 ] && check "13b pre-clear: api-request-blob is activity" 0 || check "13b pre-clear: api-request-blob is activity" 1 "rc=$rc"
printf '%s\n' '{"type":"tools-used"}' '{"type":"future-meta"}' > "$f"
tx_quiet "$f" 0 "$CUT" '["assistant"]' 0; rc=$?
[ "$rc" = 0 ] && check "13c pre-clear: untimestamped metadata is quiet" 0 || check "13c pre-clear: untimestamped metadata is quiet" 1 "rc=$rc"


# both NAME WANT LINES... : the same lines through the resume call and the pre-clear call
both() {
  local name="$1" want="$2" f="$TMPD/both.jsonl" rc l; shift 2
  : > "$f"; for l in "$@"; do printf '%s\n' "$l" >> "$f"; done
  tx_quiet "$f" 0 "$CUT" "$GRACED" 1; rc=$?
  [ "$rc" = "$want" ] && check "$name (resume)" 0 || check "$name (resume)" 1 "rc=$rc want=$want"
  tx_quiet "$f" 0 "$CUT" '["assistant"]' 0; rc=$?
  [ "$rc" = "$want" ] && check "$name (pre-clear)" 0 || check "$name (pre-clear)" 1 "rc=$rc want=$want"
}
both "14 untimestamped queue-operation is activity" 1 '{"type":"queue-operation","operation":"enqueue"}'
both "15 untimestamped attachment is activity" 1 '{"type":"attachment","attachment":{}}'
both "16 untimestamped progress is activity" 1 '{"type":"progress"}'
both "17 untimestamped file-history-snapshot is activity" 1 '{"type":"file-history-snapshot","messageId":"m"}'
both "17b untimestamped summary / tool_result are activity" 1 '{"type":"summary"}'
both "17c untimestamped tool_result is activity" 1 '{"type":"tool_result"}'
both "18 unknown type with timestamp:false is activity" 1 '{"type":"future-meta","timestamp":false}'
both "19 unknown type with timestamp:null is activity" 1 '{"type":"future-meta","timestamp":null}'
both "19b unknown type with timestamp:\"\" is activity" 1 '{"type":"future-meta","timestamp":""}'
both "19c unknown type with null snapshot.timestamp is activity" 1 '{"type":"future-meta","snapshot":{"timestamp":null}}'
both "20 type \"User\" is activity" 1 '{"type":"User"}'
both "20b type \"\" is activity" 1 '{"type":""}'
both "20c type \"user \" is activity" 1 '{"type":"user "}'
both "20d type \"USER\" is activity" 1 '{"type":"USER"}'
both "21 timestamped frame-link is quiet" 0 "{\"type\":\"frame-link\",\"timestamp\":\"2030-01-01T00:00:00.000Z\"}"
both "21b untimestamped frame-link / ai-title / artifact-autoreact-ledger are quiet" 0 '{"type":"frame-link"}' '{"type":"ai-title"}' '{"type":"artifact-autoreact-ledger"}'
both "22 untimestamped unknown lower-case metadata is quiet" 0 '{"type":"future-meta"}'

# attachment with timestamp:false must be activity (graced type, unusable timestamp)
quiet "23 attachment with timestamp:false is activity" 1 '{"type":"attachment","timestamp":false}'

# TX_WHY carries type and line number (and no-ts)
f="$TMPD/why.jsonl"; printf '%s\n' '{"type":"mode"}' '{"type":"frame-link"}' '{"type":"queue-operation"}' > "$f"
tx_quiet "$f" 0 "$CUT" "$GRACED" 1
[ "$TX_WHY" = "queue-operation line 3 no-ts" ] && check "24 TX_WHY = '$TX_WHY'" 0 || check "24 TX_WHY carries type, line, no-ts" 1 "why='$TX_WHY'"
printf '%s\n' '{"type":"mode"}' "{\"type\":\"assistant\",\"timestamp\":\"2030-01-01T00:00:00.000Z\"}" > "$f"
tx_quiet "$f" 0 "$CUT" "$GRACED" 1
[ "$TX_WHY" = "assistant line 2" ] && check "24b TX_WHY for a timestamped line: '$TX_WHY'" 0 || check "24b TX_WHY for a timestamped line" 1 "why='$TX_WHY'"
printf '%s\n' 'garbage' > "$f"
tx_quiet "$f" 0 "$CUT" "$GRACED" 1
[ "$TX_WHY" = "unparseable line 1" ] && check "24c TX_WHY for an unparseable line" 0 || check "24c TX_WHY for an unparseable line" 1 "why='$TX_WHY'"
tx_quiet "$TMPD/tx.jsonl" 0 "$CUT" "$GRACED" 1

if [ "$FAILS" -ne 0 ]; then echo "$FAILS FAILED"; exit 1; fi
echo "all passed"
