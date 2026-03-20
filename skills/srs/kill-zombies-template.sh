#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# [PROJECT_NAME] — Kill Zombie Processes
# ══════════════════════════════════════════════════════════════════════
#
# Standalone cleanup script — kills stale dev processes on project ports,
# orphaned node processes, and leftover Playwright browsers.
#
# Why this exists:
#   Dev servers (Vite, tsx, Playwright) sometimes leave orphan processes
#   that hold ports open. This causes "address already in use" on restart
#   and flaky E2E tests. Run this before restart.sh or E2E test runs.
#
# Port layout (keep in sync with restart.sh, vite configs, .env):
#   API:        ${API_PORT}
#   [VITE_PORTS_COMMENT]
#   PostgreSQL: ${DB_PORT}
#   E2E:        ${E2E_PORT}
#
# Usage:
#   bash kill-zombies.sh                # Kill all zombies
#   bash kill-zombies.sh --dry-run      # Show what would be killed
#   bash kill-zombies.sh --include-dev  # Also kill the API server process
#
set -euo pipefail

# ── Port Configuration ───────────────────────────────────────────────
API_PORT=[API_PORT]
# [VITE_PORT_VARS]
DB_PORT=[DB_PORT]
E2E_PORT=[E2E_PORT]

# By default, skip the API port (safe for use while API is intentionally running)
KILL_PORTS=([VITE_PORT_LIST] $E2E_PORT)

DRY_RUN=false
INCLUDE_DEV=false

for arg in "$@"; do
  case "$arg" in
    --dry-run)     DRY_RUN=true ;;
    --include-dev) INCLUDE_DEV=true ;;
  esac
done

$INCLUDE_DEV && KILL_PORTS=($API_PORT "${KILL_PORTS[@]}")

# ── Kill by Port ─────────────────────────────────────────────────────
echo "🧹 Killing zombie processes on project ports..."

kill_port() {
  local port=$1
  if command -v fuser &>/dev/null; then
    if $DRY_RUN; then
      fuser "$port/tcp" 2>/dev/null && echo "  [dry-run] Would kill port $port" || true
    else
      fuser -k "$port/tcp" 2>/dev/null && echo "  Killed port $port" || echo "  Port $port: clean"
    fi
  elif command -v lsof &>/dev/null; then
    local PIDS=$(lsof -t -i:$port 2>/dev/null)
    for PID in $PIDS; do
      if $DRY_RUN; then
        echo "  [dry-run] Would kill PID $PID on port $port"
      else
        echo "  Killing PID $PID on port $port"
        kill -9 "$PID" 2>/dev/null || true
      fi
    done
  fi
}

for p in "${KILL_PORTS[@]}"; do
  kill_port "$p"
done

# ── Kill Orphaned Node Processes ─────────────────────────────────────
echo ""
echo "🔍 Checking for orphaned node processes..."
ORPHANS=$(pgrep -f "node.*(vite|tsx|dev-server|playwright|vitest).*[PROJECT_NAME]" 2>/dev/null || true)
if [ -n "$ORPHANS" ]; then
  for PID in $ORPHANS; do
    if $DRY_RUN; then
      echo "  [dry-run] Would kill orphan PID $PID ($(ps -p $PID -o args= 2>/dev/null || echo 'unknown'))"
    else
      echo "  Killing orphan PID $PID"
      kill -9 "$PID" 2>/dev/null || true
    fi
  done
else
  echo "  No orphans found."
fi

# ── Kill Stale Playwright Browsers ───────────────────────────────────
echo ""
echo "🎭 Checking for stale Playwright browsers..."
PW_PROCS=$(pgrep -f "ms-playwright|playwright.*chromium|playwright.*firefox" 2>/dev/null || true)
if [ -n "$PW_PROCS" ]; then
  for PID in $PW_PROCS; do
    if $DRY_RUN; then
      echo "  [dry-run] Would kill Playwright PID $PID"
    else
      echo "  Killing Playwright PID $PID"
      kill -9 "$PID" 2>/dev/null || true
    fi
  done
else
  echo "  No stale browsers found."
fi

# ── Summary ──────────────────────────────────────────────────────────
echo ""
if $DRY_RUN; then
  echo "Dry run complete — no processes were killed."
else
  echo "✅ Cleanup complete."
fi
