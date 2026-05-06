#!/usr/bin/env bash
# sync-workaround-side-effects.sh — Parse WORKAROUNDS.md side-effect blocks for /forge cycle
#
# Reads WORKAROUNDS.md, extracts every "Side effects" block, and reports the diff between
# what's declared and what's currently deployed. Pure read — does NOT mutate anything.
#
# Output is line-oriented for /forge to consume:
#   ACTION TYPE WA-ID SOURCE TARGET PLATFORM
# Where ACTION ∈ {INSTALL, UPDATE, REMOVE} and TYPE ∈ {script, hook}.
#
# Used by /forge cycle's cast phase to surface rows in the PLAN table.
#
# Side-effect block format expected in WORKAROUNDS.md:
#   **Side effects** (managed by /forge cycle — apply on cast, remove on retirement):
#   - script: scripts/<name>.sh → ~/.claude/scripts/
#   - hook: SessionStart → "$HOME/.claude/scripts/<name>.sh"  (platform: WSL2)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKAROUNDS="$FORGE_DIR/WORKAROUNDS.md"
SETTINGS="$HOME/.claude/settings.json"
SETTINGS_LOCAL="$HOME/.claude/settings.local.json"

if [[ ! -f "$WORKAROUNDS" ]]; then
  exit 0  # No workarounds tracked, nothing to do
fi

# Detect WSL2
is_wsl2() {
  [[ -f /proc/version ]] && grep -qi microsoft /proc/version 2>/dev/null
}

# --- Parse WORKAROUNDS.md for side-effect blocks ---
# State machine: track current WA-ID, then collect lines after "**Side effects**" until next "##" or EOF.

CURRENT_WA=""
IN_SIDE_EFFECTS=0
declare -a SCRIPT_ENTRIES=()  # "WA-ID|forge_path|target_dir"
declare -a HOOK_ENTRIES=()    # "WA-ID|event|command|platform"

while IFS= read -r line; do
  # New WA section
  if [[ "$line" =~ ^##[[:space:]]+(WA-[0-9]+):[[:space:]]*(.*)$ ]]; then
    CURRENT_WA="${BASH_REMATCH[1]}"
    IN_SIDE_EFFECTS=0
    continue
  fi

  # Start of side-effects block
  if [[ "$line" =~ ^\*\*Side[[:space:]]effects\*\* ]]; then
    IN_SIDE_EFFECTS=1
    continue
  fi

  # Blank line ends the side-effects block (lenient)
  if [[ $IN_SIDE_EFFECTS -eq 1 && -z "${line//[[:space:]]/}" ]]; then
    IN_SIDE_EFFECTS=0
    continue
  fi

  # Inside side-effects block: parse entry lines
  if [[ $IN_SIDE_EFFECTS -eq 1 && -n "$CURRENT_WA" ]]; then
    # script: scripts/<name>.sh → ~/.claude/scripts/
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*script:[[:space:]]*([^[:space:]]+)[[:space:]]*(→|->)[[:space:]]*([^[:space:]]+) ]]; then
      forge_path="${BASH_REMATCH[1]}"
      target_dir="${BASH_REMATCH[3]}"
      SCRIPT_ENTRIES+=("$CURRENT_WA|$forge_path|$target_dir")
      continue
    fi
    # hook: SessionStart → "$HOME/.claude/scripts/<name>.sh"  (platform: WSL2)
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*hook:[[:space:]]*([A-Za-z]+)[[:space:]]*(→|->)[[:space:]]*\"([^\"]+)\"(.*)$ ]]; then
      event="${BASH_REMATCH[1]}"
      command="${BASH_REMATCH[3]}"
      rest="${BASH_REMATCH[4]}"
      platform=""
      if [[ "$rest" =~ \(platform:[[:space:]]*([A-Za-z0-9]+)\) ]]; then
        platform="${BASH_REMATCH[1]}"
      fi
      HOOK_ENTRIES+=("$CURRENT_WA|$event|$command|$platform")
      continue
    fi
  fi
done < "$WORKAROUNDS"

# --- Report script side-effect status ---
for entry in "${SCRIPT_ENTRIES[@]}"; do
  IFS='|' read -r wa forge_path target_dir <<< "$entry"
  src="$FORGE_DIR/$forge_path"
  filename=$(basename "$forge_path")
  # Expand ~/ in target_dir
  expanded_dir="${target_dir/#\~/$HOME}"
  dest="$expanded_dir$filename"
  # Trim trailing slash in expanded_dir for clean dest
  dest="${expanded_dir%/}/$filename"

  if [[ ! -f "$src" ]]; then
    echo "ERROR script $wa $forge_path $dest (forge source missing)"
    continue
  fi

  if [[ ! -f "$dest" ]]; then
    echo "INSTALL script $wa $src $dest -"
  elif ! diff -q "$src" "$dest" >/dev/null 2>&1; then
    echo "UPDATE script $wa $src $dest -"
  else
    echo "OK script $wa $src $dest -"
  fi
done

# --- Report hook side-effect status ---
hook_in_settings() {
  local file="$1"
  local marker="$2"
  [[ ! -f "$file" ]] && return 1
  command -v jq >/dev/null 2>&1 || return 1
  # Claude Code hook schema: .hooks.<Event>[]{hooks:[{type, command}]}
  jq -e --arg event "SessionStart" --arg marker "$marker" \
    '(.hooks[$event] // [])
     | map(.hooks // [])
     | flatten
     | map(.command // "")
     | any(. | contains($marker))' \
    "$file" >/dev/null 2>&1
}

for entry in "${HOOK_ENTRIES[@]}"; do
  IFS='|' read -r wa event cmd platform <<< "$entry"

  # Platform gate: suppress non-applicable platforms
  if [[ "$platform" == "WSL2" ]] && ! is_wsl2; then
    echo "SKIP hook $wa - $cmd $platform (not on WSL2)"
    continue
  fi

  # Detect by substring: take the script basename from the command as marker
  marker=$(basename "$cmd" 2>/dev/null || echo "$cmd")

  if hook_in_settings "$SETTINGS" "$marker" || hook_in_settings "$SETTINGS_LOCAL" "$marker"; then
    echo "OK hook $wa - $cmd $platform"
  else
    echo "INSTALL hook $wa - $cmd $platform"
  fi
done

exit 0
