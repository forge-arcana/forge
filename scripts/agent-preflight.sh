#!/usr/bin/env bash
# agent-preflight.sh — Token warmup + idempotent keeper spawn for any subagent-spawning skill
# Workaround for Claude Code OAuth refresh-token race (see WORKAROUNDS.md WA-001)
#
# Usage:  bash agent-preflight.sh <parent_pid>
#
# Idempotent: if a keeper is already running for parent_pid, no-op. Safe to call repeatedly
# from nested skills (e.g., smith → /temper → /poke each call preflight; only one keeper spawns).

set -uo pipefail

PARENT_PID="${1:-}"
if [[ -z "$PARENT_PID" ]]; then
  echo "ERROR: parent PID required as first argument" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WARMUP="$SCRIPT_DIR/agent-token-warmup.sh"
KEEPER="$SCRIPT_DIR/agent-token-keeper.sh"
PID_FILE="/tmp/forge-agent-token-keeper.${PARENT_PID}.pid"

# 1. Synchronous warmup (no-op when token healthy)
bash "$WARMUP" "preflight"

# 2. Check for existing keeper for this parent — idempotent re-entry
if [[ -f "$PID_FILE" ]]; then
  EXISTING_PID=$(cat "$PID_FILE" 2>/dev/null || echo "")
  if [[ -n "$EXISTING_PID" ]] && kill -0 "$EXISTING_PID" 2>/dev/null; then
    exit 0  # keeper already running, done
  fi
  rm -f "$PID_FILE"  # stale
fi

# 3. Spawn keeper detached
nohup bash "$KEEPER" "$PARENT_PID" >/dev/null 2>&1 &
disown
exit 0
