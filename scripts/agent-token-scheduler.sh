#!/usr/bin/env bash
# agent-token-scheduler.sh — Scheduled OAuth token refresh (unified scheduler)
# Workaround for Claude Code refresh-token race (see WORKAROUNDS.md WA-001)
#
# Why bash instead of cron/at/systemd-run:
#   This re-implements one-shot scheduled execution because at/cron/systemd-run cannot
#   be assumed available in WSL2 (atd/crond/systemd are commonly disabled or absent).
#   Bash sleep+loop is the lowest-common-denominator scheduler.
#
# Two modes:
#   --user                — Layer 2: runs forever until WSL VM lifecycle ends it.
#                            Sleeps until expiresAt-30min (full sleep). PID file keyed by user.
#   --parent <pid>        — Layer 1: runs only while parent skill (caller) is alive.
#                            Sleeps in 5-min chunks; checks `kill -0 $parent` between chunks.
#                            Refresh timing still uses expiresAt math; chunks are only for
#                            responsive parent-watch (polling is fine for liveness checks,
#                            wrong only for refresh timing).
#
# Clock-skew defense: re-reads expiresAt on EVERY wake before deciding what to do.
# If WSL2 host suspends and wall-clock jumps hours, the next wake recomputes from current
# expiresAt — fires immediately if past expiry, otherwise reschedules.
#
# Smith short-circuit: in --parent mode, if a --user scheduler is already running,
# this scheduler exits immediately (Layer 2 covers it; redundancy is wasteful).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WARMUP="$SCRIPT_DIR/agent-token-warmup.sh"
CREDS="$HOME/.claude/.credentials.json"
LOG="$HOME/.claude/.smith-token.log"

# --- Mode dispatch ---
MODE=""
PARENT_PID=""
case "${1:-}" in
  --user)
    MODE="user"
    PID_FILE="/tmp/forge-agent-token-scheduler.user-${USER}.pid"
    LOG_PREFIX="scheduler:user"
    ;;
  --parent)
    MODE="parent"
    PARENT_PID="${2:-}"
    if [[ -z "$PARENT_PID" ]]; then
      echo "ERROR: --parent requires a PID argument" >&2
      exit 1
    fi
    PID_FILE="/tmp/forge-agent-token-scheduler.${PARENT_PID}.pid"
    LOG_PREFIX="scheduler:parent[$PARENT_PID]"
    ;;
  *)
    echo "Usage: agent-token-scheduler.sh --user | --parent <pid>" >&2
    exit 1
    ;;
esac

log() {
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "[$ts] [$LOG_PREFIX:$$] $*" >> "$LOG"
}

SLEEP_PID=""

cleanup() {
  log "shutting down (signal received or lifecycle ended)"
  if [[ -n "$SLEEP_PID" ]]; then
    kill "$SLEEP_PID" 2>/dev/null || true
  fi
  rm -f "$PID_FILE"
  exit 0
}

trap cleanup SIGTERM SIGINT EXIT

# --- Smith short-circuit (parent mode only) ---
if [[ "$MODE" == "parent" ]]; then
  USER_PID_FILE="/tmp/forge-agent-token-scheduler.user-${USER}.pid"
  if [[ -f "$USER_PID_FILE" ]]; then
    USER_SCHED_PID=$(cat "$USER_PID_FILE" 2>/dev/null || echo "")
    if [[ -n "$USER_SCHED_PID" ]] && kill -0 "$USER_SCHED_PID" 2>/dev/null; then
      log "user-scope scheduler (PID $USER_SCHED_PID) is alive — Layer 2 covers this; exiting"
      exit 0
    fi
  fi
fi

# --- Write own PID atomically (set -C noclobber) ---
if ! (set -C; echo "$$" > "$PID_FILE") 2>/dev/null; then
  # File exists; check if its PID is alive
  EXISTING=$(cat "$PID_FILE" 2>/dev/null || echo "")
  if [[ -n "$EXISTING" ]] && kill -0 "$EXISTING" 2>/dev/null; then
    log "another scheduler ($EXISTING) is already running — exiting"
    exit 0
  fi
  # Stale PID file
  rm -f "$PID_FILE"
  echo "$$" > "$PID_FILE"
fi

log "started — mode=$MODE interval-strategy=$([[ "$MODE" == "user" ]] && echo "full-sleep" || echo "5min-chunks")"

# Verify warmup script exists
if [[ ! -x "$WARMUP" ]]; then
  log "ERROR: warmup script not found or not executable at $WARMUP"
  exit 1
fi

# --- Helpers ---
read_expires_s() {
  if [[ ! -f "$CREDS" ]]; then
    echo ""
    return
  fi
  local ms
  ms=$(jq -r '.claudeAiOauth.expiresAt // empty' "$CREDS" 2>/dev/null || echo "")
  if [[ -z "$ms" ]]; then
    echo ""
    return
  fi
  echo $((ms / 1000))
}

# Sleep that's interruptible by signals (backgrounded sleep + wait)
interruptible_sleep() {
  local seconds="$1"
  sleep "$seconds" &
  SLEEP_PID=$!
  wait "$SLEEP_PID" 2>/dev/null || true
  SLEEP_PID=""
}

# --- Main loop ---
THRESHOLD_SECONDS=1800  # refresh 30 min before expiry
MIN_SLEEP=60            # never sleep less than this (avoid hot loop on weird state)

while true; do
  # Re-read expiresAt on every wake — defends against WSL2 clock skew
  EXPIRES_S=$(read_expires_s)
  if [[ -z "$EXPIRES_S" ]]; then
    log "WARN: could not read expiresAt — retrying in 5 min"
    interruptible_sleep 300
    continue
  fi

  NOW_S=$(date +%s)
  TIME_TO_REFRESH=$(( EXPIRES_S - THRESHOLD_SECONDS - NOW_S ))

  # Already past refresh window? Fire warmup immediately.
  if [[ $TIME_TO_REFRESH -le 0 ]]; then
    log "expires=$EXPIRES_S now=$NOW_S past refresh window — firing warmup now"
    bash "$WARMUP" "$LOG_PREFIX" || log "WARN: warmup invocation failed"
    # After warmup, loop will re-read expiresAt and reschedule
    interruptible_sleep "$MIN_SLEEP"

    # Parent-watch (parent mode only) after the sleep
    if [[ "$MODE" == "parent" ]] && ! kill -0 "$PARENT_PID" 2>/dev/null; then
      log "parent process $PARENT_PID is gone — exiting"
      exit 0
    fi
    continue
  fi

  # Schedule the next refresh.
  if [[ "$MODE" == "user" ]]; then
    # Full sleep until refresh time. Could be 30+ minutes.
    SLEEP_FOR=$TIME_TO_REFRESH
    if [[ $SLEEP_FOR -lt $MIN_SLEEP ]]; then
      SLEEP_FOR=$MIN_SLEEP
    fi
    log "next refresh in ${SLEEP_FOR}s ($((SLEEP_FOR / 60))min)"
    interruptible_sleep "$SLEEP_FOR"
  else
    # Parent mode: 5-min chunks with parent-watch between
    CHUNK=300
    if [[ $TIME_TO_REFRESH -lt $CHUNK ]]; then
      CHUNK=$TIME_TO_REFRESH
      if [[ $CHUNK -lt $MIN_SLEEP ]]; then
        CHUNK=$MIN_SLEEP
      fi
    fi
    interruptible_sleep "$CHUNK"
    if ! kill -0 "$PARENT_PID" 2>/dev/null; then
      log "parent process $PARENT_PID is gone — exiting"
      exit 0
    fi
  fi
done
