#!/usr/bin/env bash
# agent-preflight.sh — Layer 1 entry point: token warmup + idempotent scheduler spawn
# Workaround for Claude Code OAuth refresh-token race (see WORKAROUNDS.md WA-001)
#
# Usage:  bash agent-preflight.sh <parent_pid>
#
# Idempotent: if a scheduler is already running for parent_pid, no-op. Safe to call
# repeatedly from nested skills (e.g., smith → /temper → /poke each call preflight;
# only one scheduler spawns).

set -uo pipefail

PARENT_PID="${1:-}"
if [[ -z "$PARENT_PID" ]]; then
  echo "ERROR: parent PID required as first argument" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WARMUP="$SCRIPT_DIR/agent-token-warmup.sh"
SCHEDULER="$SCRIPT_DIR/agent-token-scheduler.sh"
PID_FILE="/tmp/forge-agent-token-scheduler.${PARENT_PID}.pid"

# 1. Synchronous warmup (no-op when token healthy)
bash "$WARMUP" "preflight"

# 2. Check for existing scheduler for this parent — idempotent re-entry
if [[ -f "$PID_FILE" ]]; then
  EXISTING_PID=$(cat "$PID_FILE" 2>/dev/null || echo "")
  if [[ -n "$EXISTING_PID" ]] && kill -0 "$EXISTING_PID" 2>/dev/null; then
    exit 0  # scheduler already running, done
  fi
  rm -f "$PID_FILE"  # stale
fi

# 3. Spawn scheduler in --parent mode (it will short-circuit if a --user scheduler is alive)
nohup bash "$SCHEDULER" --parent "$PARENT_PID" </dev/null >/dev/null 2>&1 &
disown
exit 0
