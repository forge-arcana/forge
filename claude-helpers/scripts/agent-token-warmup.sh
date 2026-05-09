#!/usr/bin/env bash
# agent-token-warmup.sh — Proactive OAuth token refresh for any subagent-spawning skill
# Workaround for Claude Code refresh-token race (see WORKAROUNDS.md WA-001)
#
# Behavior:
#   1. Read ~/.claude/.credentials.json
#   2. If token expires in >30 min → no-op (token healthy)
#   3. Else → flock + double-check + backup + trigger refresh via `claude -p` no-op call
#   4. Update consecutive-failure counter; write sentinel `~/.claude/.token-stale` after threshold
#   5. Always exit 0 (never fail caller on refresh issues)
#
# Concurrency: a non-blocking `flock` on /tmp/forge-agent-token-warmup.lock serializes the
# refresh action across simultaneous warmup invocations. Race-losers exit clean — whoever
# holds the lock will refresh, and the next caller will see a healthy token.
#
# Logs to ~/.claude/.smith-token.log

set -uo pipefail

CREDS="$HOME/.claude/.credentials.json"
BACKUP="$HOME/.claude/.credentials.json.lkg"
LOG="$HOME/.claude/.smith-token.log"
LOCK="/tmp/forge-agent-token-warmup.lock"
STALE_SENTINEL="$HOME/.claude/.token-stale"
FAIL_COUNTER="$HOME/.claude/.token-fail-count"
FAIL_THRESHOLD=3
THRESHOLD_SECONDS=1800  # 30 minutes
LOG_PREFIX="${1:-warmup}"  # caller can pass a custom prefix (e.g. "scheduler:user")

log() {
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "[$ts] [$LOG_PREFIX] $*" >> "$LOG"
}

# --- Read credentials ---
if [[ ! -f "$CREDS" ]]; then
  log "credentials file missing at $CREDS — skipping"
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  log "jq not installed — cannot parse credentials, skipping"
  exit 0
fi

read_expires_ms() {
  jq -r '.claudeAiOauth.expiresAt // empty' "$CREDS" 2>/dev/null || echo ""
}

EXPIRES_AT_MS=$(read_expires_ms)
if [[ -z "$EXPIRES_AT_MS" ]]; then
  log "could not read expiresAt from credentials — skipping"
  exit 0
fi

# --- Quick check: is refresh even needed? ---
NOW_S=$(date +%s)
EXPIRES_AT_S=$((EXPIRES_AT_MS / 1000))
SECONDS_REMAINING=$((EXPIRES_AT_S - NOW_S))

if [[ $SECONDS_REMAINING -gt $THRESHOLD_SECONDS ]]; then
  MINUTES_REMAINING=$((SECONDS_REMAINING / 60))
  log "token healthy — ${MINUTES_REMAINING}min remaining"
  exit 0
fi

# --- Refresh needed: acquire flock and double-check ---
exec 9>"$LOCK"
if ! flock -n 9; then
  log "another warmup holds the lock — skipping (token will be healthy after their refresh)"
  exit 0
fi

# Re-read credentials inside the critical section: another warmup may have just refreshed
EXPIRES_AT_MS=$(read_expires_ms)
if [[ -z "$EXPIRES_AT_MS" ]]; then
  log "post-lock: could not read expiresAt — releasing lock and skipping"
  exit 0
fi
EXPIRES_AT_S=$((EXPIRES_AT_MS / 1000))
NOW_S=$(date +%s)
SECONDS_REMAINING=$((EXPIRES_AT_S - NOW_S))
if [[ $SECONDS_REMAINING -gt $THRESHOLD_SECONDS ]]; then
  MINUTES_REMAINING=$((SECONDS_REMAINING / 60))
  log "post-lock: token now healthy (${MINUTES_REMAINING}min remaining) — another warmup just refreshed"
  exit 0
fi

# --- Refresh action ---
if [[ $SECONDS_REMAINING -lt 0 ]]; then
  log "token already expired — attempting refresh"
else
  MINUTES_REMAINING=$((SECONDS_REMAINING / 60))
  log "token expires in ${MINUTES_REMAINING}min — refreshing"
fi

if cp "$CREDS" "$BACKUP" 2>/dev/null; then
  log "backed up credentials to $BACKUP"
else
  log "WARN: backup failed — proceeding anyway"
fi

if ! command -v claude >/dev/null 2>&1; then
  log "claude not in PATH — cannot trigger refresh"
  exit 0
fi

REFRESH_OUTPUT=$(echo "ok" | timeout 30 claude -p --max-turns 1 2>&1) || true
log "refresh trigger output: ${REFRESH_OUTPUT:0:200}"

# --- Verify + update failure counter ---
NEW_EXPIRES_AT_MS=$(read_expires_ms)
REFRESH_OK="no"
if [[ -n "$NEW_EXPIRES_AT_MS" && "$NEW_EXPIRES_AT_MS" != "$EXPIRES_AT_MS" ]]; then
  NEW_EXPIRES_AT_S=$((NEW_EXPIRES_AT_MS / 1000))
  NEW_REMAINING=$(( (NEW_EXPIRES_AT_S - NOW_S) / 60 ))
  log "refresh succeeded — new expiry in ${NEW_REMAINING}min"
  REFRESH_OK="yes"
else
  log "WARN: expiresAt unchanged — refresh may have failed"
fi

if [[ "$REFRESH_OK" == "yes" ]]; then
  # Reset failure counter and clear sentinel on success
  rm -f "$FAIL_COUNTER" "$STALE_SENTINEL"
else
  # Increment failure counter; write sentinel if threshold crossed
  CURRENT_FAILS=0
  if [[ -f "$FAIL_COUNTER" ]]; then
    CURRENT_FAILS=$(cat "$FAIL_COUNTER" 2>/dev/null || echo "0")
  fi
  CURRENT_FAILS=$((CURRENT_FAILS + 1))
  echo "$CURRENT_FAILS" > "$FAIL_COUNTER"
  if [[ $CURRENT_FAILS -ge $FAIL_THRESHOLD ]]; then
    echo "OAuth refresh has failed $CURRENT_FAILS consecutive times. Run \`claude\` from a terminal to re-authenticate." > "$STALE_SENTINEL"
    log "WARN: failure count $CURRENT_FAILS reached threshold $FAIL_THRESHOLD — wrote sentinel $STALE_SENTINEL"
  fi
fi

exit 0
