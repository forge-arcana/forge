#!/usr/bin/env bash
# forge-workarounds-check.sh — Periodic upstream bug status check
# Reads WORKAROUNDS.md, queries GitHub for each upstream issue,
# and emits a status banner for /forge to display above the PLAN table.
#
# API calls are time-gated to once per 7 days per workaround.
# Output format: one status line per workaround. Always emits at least one line per WA.

set -uo pipefail

# Resolve forge path: FORGE_PATH env var > CLAUDE.md fallback > script-relative fallback
FORGE_PATH="${FORGE_PATH:-}"
MEMBRANE="${FORGE_MEMBRANE:-$HOME/.claude}"
if [[ -z "$FORGE_PATH" && -f "$MEMBRANE/CLAUDE.md" ]]; then
  FORGE_PATH=$(sed -n 's/^forge-path:[[:space:]]*//p' "$MEMBRANE/CLAUDE.md" 2>/dev/null | sed 's/[[:space:]]*$//' || true)
fi
if [[ -z "$FORGE_PATH" ]]; then
  # Last-resort: derive from script location (assumes core/scripts/ layout)
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  FORGE_PATH="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

WORKAROUNDS_FILE="$FORGE_PATH/claude-helpers/WORKAROUNDS.md"
TRACKER_FILE="$FORGE_PATH/learnings/.workarounds-tracker.json"
CACHE_TTL_DAYS=7

if [[ ! -f "$WORKAROUNDS_FILE" ]]; then
  # No workarounds tracked — silent.
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "WORKAROUNDS: (jq not installed — skipping check)" >&2
  exit 0
fi

# --- Initialize tracker if missing ---
if [[ ! -f "$TRACKER_FILE" ]]; then
  echo "{}" > "$TRACKER_FILE"
fi

# --- Parse WORKAROUNDS.md for active workaround IDs and their issue URLs ---
# Format expected: "## WA-NNN: Title" sections, with issue URLs of the form
# https://github.com/anthropics/claude-code/issues/NNNNN

CURRENT_WA=""
declare -A WA_TITLES
declare -A WA_ISSUES  # WA_ID -> space-separated issue numbers
WA_ORDER=()

while IFS= read -r line; do
  if [[ "$line" =~ ^##[[:space:]]+(WA-[0-9]+):[[:space:]]*(.*)$ ]]; then
    CURRENT_WA="${BASH_REMATCH[1]}"
    WA_TITLES["$CURRENT_WA"]="${BASH_REMATCH[2]}"
    WA_ISSUES["$CURRENT_WA"]=""
    WA_ORDER+=("$CURRENT_WA")
  elif [[ -n "$CURRENT_WA" ]]; then
    # Match issue URLs in this workaround block
    while [[ "$line" =~ github\.com/anthropics/claude-code/issues/([0-9]+) ]]; do
      issue="${BASH_REMATCH[1]}"
      existing="${WA_ISSUES[$CURRENT_WA]}"
      if [[ " $existing " != *" $issue "* ]]; then
        WA_ISSUES["$CURRENT_WA"]="$existing $issue"
      fi
      # Strip the matched portion to find more matches on same line
      line="${line/${BASH_REMATCH[0]}/}"
    done
  fi
done < "$WORKAROUNDS_FILE"

if [[ ${#WA_ORDER[@]} -eq 0 ]]; then
  exit 0
fi

# --- Helper: how many days since timestamp ---
days_since() {
  local then_iso="$1"
  if [[ -z "$then_iso" ]]; then
    echo "999"
    return
  fi
  local then_s now_s
  then_s=$(date -u -d "$then_iso" +%s 2>/dev/null || echo "0")
  now_s=$(date -u +%s)
  if [[ "$then_s" -eq 0 ]]; then
    echo "999"
    return
  fi
  echo $(( (now_s - then_s) / 86400 ))
}

# --- Helper: friendly relative time ---
relative_time() {
  local days="$1"
  if [[ "$days" -eq 0 ]]; then
    echo "today"
  elif [[ "$days" -eq 1 ]]; then
    echo "1d ago"
  else
    echo "${days}d ago"
  fi
}

# --- Process each workaround ---
NOW_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TODAY=$(date -u +"%Y-%m-%d")

for wa_id in "${WA_ORDER[@]}"; do
  issues="${WA_ISSUES[$wa_id]## }"
  issues="${issues%% }"
  if [[ -z "$issues" ]]; then
    echo "WORKAROUNDS: $wa_id active, no upstream issues tracked"
    continue
  fi
  issue_count=$(echo "$issues" | wc -w)

  last_checked=$(jq -r --arg id "$wa_id" '.[$id].last_checked // empty' "$TRACKER_FILE" 2>/dev/null)
  last_status=$(jq -r --arg id "$wa_id" '.[$id].last_status // empty' "$TRACKER_FILE" 2>/dev/null)
  age_days=$(days_since "$last_checked")

  needs_check="no"
  if [[ "$age_days" -ge "$CACHE_TTL_DAYS" ]]; then
    needs_check="yes"
  elif [[ -z "$last_checked" ]]; then
    needs_check="yes"
  fi

  if [[ "$needs_check" == "yes" ]]; then
    # Run actual gh API check
    if ! command -v gh >/dev/null 2>&1; then
      echo "WORKAROUNDS: $wa_id active (gh check failed — gh not installed)"
      continue
    fi

    closed_issues=""
    open_count=0
    closed_count=0
    api_failed="no"
    declare -A ISSUE_STATES=()
    declare -A ISSUE_TITLES=()

    for issue in $issues; do
      result=$(gh issue view "$issue" --repo anthropics/claude-code --json state,title 2>/dev/null || echo "")
      if [[ -z "$result" ]]; then
        api_failed="yes"
        ISSUE_STATES["$issue"]="UNKNOWN"
        continue
      fi
      state=$(echo "$result" | jq -r '.state // "UNKNOWN"')
      title=$(echo "$result" | jq -r '.title // ""')
      ISSUE_STATES["$issue"]="$state"
      ISSUE_TITLES["$issue"]="$title"
      if [[ "$state" == "CLOSED" ]]; then
        closed_count=$((closed_count + 1))
        closed_issues="$closed_issues $issue"
      else
        open_count=$((open_count + 1))
      fi
    done

    if [[ "$api_failed" == "yes" && "$closed_count" -eq 0 && "$open_count" -eq 0 ]]; then
      echo "WORKAROUNDS: $wa_id active (gh check failed — offline or rate limited)"
      continue
    fi

    # Build the issues object for the tracker
    issues_json="{"
    first="yes"
    for issue in $issues; do
      state="${ISSUE_STATES[$issue]:-UNKNOWN}"
      if [[ "$first" == "yes" ]]; then
        issues_json="$issues_json\"$issue\":\"$state\""
        first="no"
      else
        issues_json="$issues_json,\"$issue\":\"$state\""
      fi
    done
    issues_json="$issues_json}"

    if [[ "$closed_count" -gt 0 ]]; then
      new_status="has_closed"
      # Build the alert line
      first_closed="${closed_issues## }"
      first_closed="${first_closed%% *}"
      title="${ISSUE_TITLES[$first_closed]}"
      echo "WORKAROUNDS: $wa_id READY FOR REMOVAL — issue #$first_closed CLOSED: \"$title\" — see WORKAROUNDS.md"
    else
      new_status="all_open"
      echo "WORKAROUNDS: $wa_id active, all $issue_count upstream issues OPEN, last checked just now"
      # Update Last verified active in WORKAROUNDS.md
      sed -i.bak "/^## $wa_id:/,/^## /{ s/^\(\*\*Last verified active\*\*:\).*/\1 $TODAY/; }" "$WORKAROUNDS_FILE" 2>/dev/null || true
      rm -f "$WORKAROUNDS_FILE.bak"
    fi

    # Update tracker
    tmp=$(mktemp)
    jq --arg id "$wa_id" \
       --arg ts "$NOW_ISO" \
       --arg status "$new_status" \
       --argjson issues "$issues_json" \
       '.[$id] = {last_checked: $ts, last_status: $status, issues: $issues}' \
       "$TRACKER_FILE" > "$tmp" && mv "$tmp" "$TRACKER_FILE"

    unset ISSUE_STATES ISSUE_TITLES
  else
    # Use cached status
    rel=$(relative_time "$age_days")
    if [[ "$last_status" == "has_closed" ]]; then
      echo "WORKAROUNDS: $wa_id READY FOR REMOVAL (cached, last checked $rel) — see WORKAROUNDS.md"
    else
      echo "WORKAROUNDS: $wa_id active, all $issue_count upstream issues OPEN, last checked $rel"
    fi
  fi
done

exit 0
