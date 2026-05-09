#!/usr/bin/env bash
# user-agent-preflight.sh — Layer 2 entry point: SessionStart hook target
# Workaround for Claude Code OAuth refresh-token race (see WORKAROUNDS.md WA-001)
#
# Called by Claude Code on every SessionStart. Tiny, idempotent, fast (sub-1s on no-op path).
# WSL2-gated: no-ops on non-WSL2 platforms (defense-in-depth for dotfile-clone case).
#
# Behavior:
#   1. Check ~/.claude/.token-stale sentinel — if present, print loud warning to stderr.
#   2. WSL2 gate: exit 0 silently if not WSL2.
#   3. Acquire flock on the preflight lock — non-blocking. Race-losers exit 0.
#   4. Synchronous warmup (refreshes if token <30 min remaining).
#   5. Ensure user-scope scheduler is running; spawn if not (detached).
#   6. Release flock; exit 0.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WARMUP="$SCRIPT_DIR/agent-token-warmup.sh"
SCHEDULER="$SCRIPT_DIR/agent-token-scheduler.sh"
STALE_SENTINEL="$HOME/.claude/.token-stale"
PREFLIGHT_LOCK="/tmp/forge-agent-preflight.lock"
USER_PID_FILE="/tmp/forge-agent-token-scheduler.user-${USER}.pid"

# --- 1. Stale-token warning (always shown, regardless of platform) ---
if [[ -f "$STALE_SENTINEL" ]]; then
  echo "" >&2
  echo "═══════════════════════════════════════════════════════════════════════" >&2
  echo "  CLAUDE CODE OAUTH REFRESH FAILING REPEATEDLY" >&2
  echo "═══════════════════════════════════════════════════════════════════════" >&2
  cat "$STALE_SENTINEL" >&2
  echo "  (sentinel: $STALE_SENTINEL)" >&2
  echo "" >&2
fi

# --- 2. WSL2 gate ---
if [[ ! -f /proc/version ]] || ! grep -qi microsoft /proc/version 2>/dev/null; then
  exit 0
fi

# --- 3. Flock the spawn block to prevent burst-spawn race ---
exec 8>"$PREFLIGHT_LOCK"
if ! flock -n 8; then
  # Another preflight is mid-spawn; trust them
  exit 0
fi

# --- 4. Synchronous warmup ---
if [[ -x "$WARMUP" ]]; then
  bash "$WARMUP" "preflight:user"
fi

# --- 5. Ensure user-scope scheduler is running ---
if [[ -f "$USER_PID_FILE" ]]; then
  EXISTING_PID=$(cat "$USER_PID_FILE" 2>/dev/null || echo "")
  if [[ -n "$EXISTING_PID" ]] && kill -0 "$EXISTING_PID" 2>/dev/null; then
    exit 0  # scheduler already running
  fi
  rm -f "$USER_PID_FILE"  # stale
fi

# Spawn detached
if [[ -x "$SCHEDULER" ]]; then
  nohup bash "$SCHEDULER" --user </dev/null >/dev/null 2>&1 &
  disown
fi

exit 0
