#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# [PROJECT_NAME] — Local Dev Restart Script
# ══════════════════════════════════════════════════════════════════════
#
# Port layout (keep in sync with kill-zombies.sh, vite configs, .env):
#   API:        ${API_PORT}
#   [VITE_PORTS_COMMENT]
#   PostgreSQL: ${DB_PORT}
#   E2E:        ${E2E_PORT}
#
# Usage:
#   bash restart.sh              # Full restart
#   bash restart.sh --dry-run    # Show what would be killed
#
set -euo pipefail
cd "$(dirname "$0")"

# ── Port Configuration ───────────────────────────────────────────────
API_PORT=[API_PORT]
# [VITE_PORT_VARS]
DB_PORT=[DB_PORT]
E2E_PORT=[E2E_PORT]
DEV_PORTS=($API_PORT [VITE_PORT_LIST] $E2E_PORT)

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

# ── Process Cleanup ──────────────────────────────────────────────────
echo "🧹 Stopping existing dev processes..."

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

for p in "${DEV_PORTS[@]}"; do
  kill_port "$p"
done

# Kill orphaned node processes matching this project
ORPHANS=$(pgrep -f "node.*(vite|tsx|dev-server|playwright|vitest).*[PROJECT_NAME]" 2>/dev/null || true)
if [ -n "$ORPHANS" ]; then
  for PID in $ORPHANS; do
    if $DRY_RUN; then
      echo "  [dry-run] Would kill orphan PID $PID"
    else
      echo "  Killing orphan node PID $PID"
      kill -9 "$PID" 2>/dev/null || true
    fi
  done
fi

# Kill stale Playwright browsers
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
fi

$DRY_RUN && { echo "Dry run complete."; exit 0; }
sleep 0.5

# ── Port Health Check (WSL2 WFP blackhole detection) ─────────────────
echo ""
echo "🔍 Checking port health..."
BLOCKED=()
for p in "${DEV_PORTS[@]}"; do
  if python3 -c "
import socket, sys
srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
try:
    srv.bind(('127.0.0.1', $p))
    srv.listen(1)
except OSError:
    sys.exit(0)  # port in use, not blackholed
cli = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
cli.settimeout(1)
try:
    cli.connect(('127.0.0.1', $p))
    cli.close()
except socket.timeout:
    srv.close()
    sys.exit(1)  # blackholed
except OSError:
    pass
srv.close()
" 2>/dev/null; then
    true
  else
    BLOCKED+=($p)
  fi
done

if [ ${#BLOCKED[@]} -gt 0 ]; then
  echo "  ❌ Port(s) ${BLOCKED[*]} blackholed by WSL2/WFP!"
  echo "  These ports bind but cannot accept connections (SYN packets dropped)."
  echo "  Fix: change the affected port(s) in vite configs / .env"
  echo "  Debug: from Windows PowerShell run:"
  echo "    netsh wfp show filters file=- | Select-String \"<port>\" -Context 5,5"
  exit 1
fi
echo "  ✅ All ports OK."

# ── Database Readiness ───────────────────────────────────────────────
# [DB_SECTION — customize or remove if using external DB like Neon]
echo ""
echo "🗄️  Checking PostgreSQL..."
if [ -f docker-compose.yml ] || [ -f compose.yml ]; then
  if ! docker compose ps --status running 2>/dev/null | grep -q db; then
    echo "  Starting PostgreSQL (docker compose up -d db)..."
    docker compose up -d db
    echo "  Waiting for PostgreSQL to be healthy..."
    TIMEOUT=30
    ELAPSED=0
    until docker compose exec db pg_isready -U [DB_USER] -q 2>/dev/null; do
      sleep 1
      ELAPSED=$((ELAPSED + 1))
      if [ $ELAPSED -ge $TIMEOUT ]; then
        echo "  ❌ PostgreSQL failed to start within ${TIMEOUT}s"
        exit 1
      fi
    done
    echo "  ✅ PostgreSQL ready."
  else
    echo "  ✅ PostgreSQL already running."
  fi
else
  echo "  ⏭️  No docker-compose.yml — skipping local DB check."
fi

# ── Codegen (if needed) ─────────────────────────────────────────────
# [CODEGEN_SECTION — customize based on project needs]
# echo ""
# echo "🔧 Running codegen..."
# pnpm --filter @[PROJECT_NAME]/ui run paraglide:compile
# echo "  ✅ Codegen complete."

# ── Start Dev Servers ────────────────────────────────────────────────
echo ""
echo "🚀 Starting dev stack..."
echo "  API:    http://localhost:${API_PORT}"
# [VITE_STARTUP_SUMMARY]
echo ""
echo "Press Ctrl+C to stop all."
echo ""

mkdir -p logs
pnpm dev 2>&1 | tee -a logs/dev.log
