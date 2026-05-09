#!/usr/bin/env bash
# install-token-hook.sh — Idempotent installer for the SessionStart token-preflight hook
# Workaround for Claude Code OAuth refresh-token race (see WORKAROUNDS.md WA-001)
#
# Invoked by /forge cycle's cast phase after the user approves the hook row in the PLAN table.
# Also supports --uninstall for workaround retirement.
#
# Behavior:
#   - flock on ~/.claude/.settings.lock (prevents concurrent /forge cycles racing)
#   - backup settings.json to ~/.claude/.backups/settings.json.<timestamp>
#   - check both settings.json AND settings.local.json for existing entry; never duplicate
#   - jq array-append (|=) preserves every existing hook entry verbatim
#   - atomic write (temp + mv)
#
# The hook command itself uses $HOME (Claude Code shell-expands hook commands), no `bash` prefix
# (script's shebang handles it; the hook runs through `sh -c` already, so we'd otherwise spawn
# two shells per session start).

set -uo pipefail

SETTINGS="$HOME/.claude/settings.json"
SETTINGS_LOCAL="$HOME/.claude/settings.local.json"
LOCK="$HOME/.claude/.settings.lock"
BACKUP_DIR="$HOME/.claude/.backups"
HOOK_COMMAND='$HOME/.claude/scripts/user-agent-preflight.sh'
HOOK_MARKER="user-agent-preflight.sh"  # substring used to detect existing install

MODE="install"
if [[ "${1:-}" == "--uninstall" ]]; then
  MODE="uninstall"
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required but not installed" >&2
  exit 1
fi

mkdir -p "$HOME/.claude" "$BACKUP_DIR"

# --- Acquire blocking flock (30s timeout) ---
exec 7>"$LOCK"
if ! flock -w 30 7; then
  echo "ERROR: could not acquire settings lock within 30s" >&2
  exit 1
fi

# --- Helper: does any settings file already have our hook? ---
# Claude Code hook schema: .hooks.<Event>[]{hooks:[{type, command}]}
# Match by substring on the inner command field.
hook_present_in() {
  local file="$1"
  [[ ! -f "$file" ]] && return 1
  jq -e --arg marker "$HOOK_MARKER" \
    '(.hooks.SessionStart // [])
     | map(.hooks // [])
     | flatten
     | map(.command // "")
     | any(. | contains($marker))' \
    "$file" >/dev/null 2>&1
}

if [[ "$MODE" == "install" ]]; then
  # --- Idempotency check across both files ---
  if hook_present_in "$SETTINGS"; then
    echo "Hook already installed in $SETTINGS — no changes."
    exit 0
  fi
  if hook_present_in "$SETTINGS_LOCAL"; then
    echo "Hook already installed in $SETTINGS_LOCAL — no changes."
    exit 0
  fi

  # --- Backup settings.json (if it exists) ---
  if [[ -f "$SETTINGS" ]]; then
    TS=$(date -u +"%Y%m%dT%H%M%SZ")
    cp "$SETTINGS" "$BACKUP_DIR/settings.json.$TS"
    echo "Backed up existing settings.json to $BACKUP_DIR/settings.json.$TS"
  fi

  # --- Read current settings (treat missing as {}) ---
  CURRENT="{}"
  if [[ -f "$SETTINGS" ]]; then
    CURRENT=$(cat "$SETTINGS")
  fi

  # --- Append hook entry via jq |= (preserves all existing entries) ---
  # Claude Code hook schema: .hooks.<Event>[]{hooks:[{type, command}]}
  TMP=$(mktemp)
  echo "$CURRENT" | jq --arg cmd "$HOOK_COMMAND" \
    '.hooks //= {}
     | .hooks.SessionStart //= []
     | .hooks.SessionStart |= . + [{"hooks": [{"type": "command", "command": $cmd}]}]' \
    > "$TMP"

  # --- Atomic write ---
  mv "$TMP" "$SETTINGS"
  echo "Installed SessionStart hook in $SETTINGS:"
  jq '.hooks.SessionStart' "$SETTINGS"
  exit 0
fi

# --- Uninstall mode ---
if [[ "$MODE" == "uninstall" ]]; then
  if [[ ! -f "$SETTINGS" ]]; then
    echo "No settings.json found — nothing to uninstall."
    exit 0
  fi
  if ! hook_present_in "$SETTINGS"; then
    echo "Hook not present in $SETTINGS — nothing to uninstall."
    if hook_present_in "$SETTINGS_LOCAL"; then
      echo "WARN: hook IS present in $SETTINGS_LOCAL — uninstall it manually if desired (this script only manages $SETTINGS)."
    fi
    exit 0
  fi

  TS=$(date -u +"%Y%m%dT%H%M%SZ")
  cp "$SETTINGS" "$BACKUP_DIR/settings.json.$TS"
  echo "Backed up existing settings.json to $BACKUP_DIR/settings.json.$TS"

  TMP=$(mktemp)
  # Remove matcher groups whose inner hooks contain our marker.
  # Claude Code hook schema: .hooks.<Event>[]{hooks:[{type, command}]}
  jq --arg marker "$HOOK_MARKER" \
    '.hooks.SessionStart |= map(
       select(
         (.hooks // [])
         | map(.command // "")
         | any(. | contains($marker))
         | not
       )
     )' \
    "$SETTINGS" > "$TMP"
  mv "$TMP" "$SETTINGS"
  echo "Uninstalled SessionStart hook from $SETTINGS."
  exit 0
fi
