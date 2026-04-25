#!/usr/bin/env bash
# smith-token-keeper.sh — Background token-refresh loop for /smith
# Workaround for Claude Code refresh-token race (see WORKAROUNDS.md WA-001)
#
# Usage: smith-token-keeper.sh <parent_pid>
#
# Behavior:
#   - Loops every 5 min calling smith-token-warmup.sh
#   - Exits cleanly when parent process dies
#   - Traps SIGTERM/SIGINT for clean shutdown
#   - Records own PID at /tmp/forge-smith-token-keeper.<parent_pid>.pid

set -uo pipefail

PARENT_PID="${1:-}"
if [[ -z "$PARENT_PID" ]]; then
  echo "ERROR: parent PID required as first argument"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WARMUP="$SCRIPT_DIR/smith-token-warmup.sh"
PID_FILE="/tmp/forge-smith-token-keeper.${PARENT_PID}.pid"
LOG="$HOME/.claude/.smith-token.log"
INTERVAL=300  # 5 minutes

log() {
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "[$ts] [keeper:$$] $*" >> "$LOG"
}

SLEEP_PID=""

cleanup() {
  log "shutting down (signal received or parent gone)"
  if [[ -n "$SLEEP_PID" ]]; then
    kill "$SLEEP_PID" 2>/dev/null || true
  fi
  rm -f "$PID_FILE"
  exit 0
}

trap cleanup SIGTERM SIGINT EXIT

# Write own PID
echo "$$" > "$PID_FILE"
log "started — parent_pid=$PARENT_PID interval=${INTERVAL}s"

# Verify warmup script exists
if [[ ! -x "$WARMUP" ]]; then
  log "ERROR: warmup script not found or not executable at $WARMUP"
  exit 1
fi

# Main loop — use backgrounded sleep + wait so signals interrupt promptly
while true; do
  # Check parent is still alive
  if ! kill -0 "$PARENT_PID" 2>/dev/null; then
    log "parent process $PARENT_PID is gone — exiting"
    exit 0
  fi

  # Run warmup (idempotent — no-op when token healthy)
  bash "$WARMUP" "keeper" || log "WARN: warmup invocation failed"

  # Backgrounded sleep so SIGTERM/SIGINT can interrupt via trap (foreground sleep blocks signal handling)
  sleep "$INTERVAL" &
  SLEEP_PID=$!
  wait "$SLEEP_PID" 2>/dev/null || true
  SLEEP_PID=""
done
