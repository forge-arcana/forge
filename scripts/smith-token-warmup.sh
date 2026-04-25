#!/usr/bin/env bash
# smith-token-warmup.sh — Proactive OAuth token refresh for /smith
# Workaround for Claude Code refresh-token race (see WORKAROUNDS.md WA-001)
#
# Behavior:
#   1. Read ~/.claude/.credentials.json
#   2. If token expires in >30 min → no-op (token healthy)
#   3. Else → backup + trigger refresh via `claude -p` no-op call
#   4. Always exit 0 (never fail smith on refresh issues)
#
# Logs to ~/.claude/.smith-token.log

set -uo pipefail

CREDS="$HOME/.claude/.credentials.json"
BACKUP="$HOME/.claude/.credentials.json.lkg"
LOG="$HOME/.claude/.smith-token.log"
THRESHOLD_SECONDS=1800  # 30 minutes
LOG_PREFIX="${1:-warmup}"  # caller can pass a custom prefix (e.g. "keeper")

log() {
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "[$ts] [$LOG_PREFIX] $*" >> "$LOG"
}

# --- Step 1: Read credentials ---
if [[ ! -f "$CREDS" ]]; then
  log "credentials file missing at $CREDS — skipping"
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  log "jq not installed — cannot parse credentials, skipping"
  exit 0
fi

EXPIRES_AT_MS=$(jq -r '.claudeAiOauth.expiresAt // empty' "$CREDS" 2>/dev/null || echo "")
if [[ -z "$EXPIRES_AT_MS" ]]; then
  log "could not read expiresAt from credentials — skipping"
  exit 0
fi

# --- Step 2: Check expiry ---
NOW_S=$(date +%s)
EXPIRES_AT_S=$((EXPIRES_AT_MS / 1000))
SECONDS_REMAINING=$((EXPIRES_AT_S - NOW_S))

if [[ $SECONDS_REMAINING -gt $THRESHOLD_SECONDS ]]; then
  MINUTES_REMAINING=$((SECONDS_REMAINING / 60))
  log "token healthy — ${MINUTES_REMAINING}min remaining"
  exit 0
fi

# --- Step 3: Refresh needed ---
if [[ $SECONDS_REMAINING -lt 0 ]]; then
  log "token already expired — attempting refresh"
else
  MINUTES_REMAINING=$((SECONDS_REMAINING / 60))
  log "token expires in ${MINUTES_REMAINING}min — refreshing"
fi

# Backup current credentials before refresh attempts
if cp "$CREDS" "$BACKUP" 2>/dev/null; then
  log "backed up credentials to $BACKUP"
else
  log "WARN: backup failed — proceeding anyway"
fi

# Trigger refresh by invoking a tiny claude API call
# This forces Claude Code's auth client to refresh if token is expired/expiring
if ! command -v claude >/dev/null 2>&1; then
  log "claude not in PATH — cannot trigger refresh"
  exit 0
fi

REFRESH_OUTPUT=$(echo "ok" | timeout 30 claude -p --max-turns 1 2>&1) || true
log "refresh trigger output: ${REFRESH_OUTPUT:0:200}"

# --- Step 4: Verify refresh worked ---
NEW_EXPIRES_AT_MS=$(jq -r '.claudeAiOauth.expiresAt // empty' "$CREDS" 2>/dev/null || echo "")
if [[ -z "$NEW_EXPIRES_AT_MS" ]]; then
  log "WARN: post-refresh credentials read failed"
  exit 0
fi

if [[ "$NEW_EXPIRES_AT_MS" != "$EXPIRES_AT_MS" ]]; then
  NEW_EXPIRES_AT_S=$((NEW_EXPIRES_AT_MS / 1000))
  NEW_REMAINING=$(( (NEW_EXPIRES_AT_S - NOW_S) / 60 ))
  log "refresh succeeded — new expiry in ${NEW_REMAINING}min"
else
  log "WARN: expiresAt unchanged — refresh may have failed"
fi

exit 0
