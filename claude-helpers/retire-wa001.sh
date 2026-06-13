#!/usr/bin/env bash
# retire-wa001.sh — TRANSIENT one-shot. Cleans a Claude Code membrane of the
# retired WA-001 OAuth-token-race workaround (scripts + SessionStart hook).
#
# WA-001 was retired on 2026-06-13 after the upstream race was fixed in Claude
# Code v2.1.136. The forge-side scrub removed the source, but a teammate's
# already-deployed membrane keeps the vestigial artifacts because /forge never
# syncs hooks and the side-effect uninstall path was never implemented. This
# script closes that gap.
#
# Wired into the /forge cast phase so it runs automatically each cycle. It is
# IDEMPOTENT and SILENT when there is nothing to clean — safe to run repeatedly.
#
# REMOVAL: once the team has cycled at least once, delete this file and its
# invocation in core/skills/forge/SKILL.md + .claude/skills/forge/SKILL.md
# (Phase 2 cast). Tracked in CLAUDE.md Outstanding.

set -uo pipefail

MEMBRANE="$HOME/.claude"
AGENTS_SCRIPTS="$HOME/.agents/scripts"
SETTINGS="$MEMBRANE/settings.json"
SETTINGS_LOCAL="$MEMBRANE/settings.local.json"

# The marker substring identifying any WA-001 artifact.
MARKER_SCRIPTS=(agent-token-warmup.sh agent-token-scheduler.sh user-agent-preflight.sh agent-preflight.sh)
HOOK_MARKER="user-agent-preflight"

did_something=0

# --- 1. Remove deployed token scripts (membrane + canonical store) ---
for s in "${MARKER_SCRIPTS[@]}"; do
  for path in "$MEMBRANE/scripts/$s" "$AGENTS_SCRIPTS/$s"; do
    if [[ -e "$path" || -L "$path" ]]; then
      rm -f "$path"
      echo "retire-wa001: removed $path"
      did_something=1
    fi
  done
done

# --- 2. Strip the WA-001 SessionStart hook from settings files ---
strip_hook() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  # Does any SessionStart entry reference the WA-001 hook?
  local present
  present=$(jq --arg m "$HOOK_MARKER" \
    '[(.hooks.SessionStart // [])[] | (.hooks // [] | map(.command // "") | any(contains($m)))] | any' \
    "$file" 2>/dev/null)
  [[ "$present" == "true" ]] || return 0

  local tmp
  tmp="$(mktemp)"
  if jq --arg m "$HOOK_MARKER" \
    '(.hooks.SessionStart) |= (map(select((.hooks // [] | map(.command // "") | any(contains($m))) | not)))' \
    "$file" > "$tmp" 2>/dev/null; then
    cat "$tmp" > "$file"
    echo "retire-wa001: stripped SessionStart hook from $file"
    did_something=1
  fi
  rm -f "$tmp"
}

strip_hook "$SETTINGS"
strip_hook "$SETTINGS_LOCAL"

# --- 3. Kill any in-memory scheduler still looping a deleted script ---
# Match only REAL schedulers (they always run with a --user / --parent mode flag)
# and never this process tree, so an orchestrating shell whose command line merely
# mentions the pattern is left alone.
if command -v pgrep >/dev/null 2>&1; then
  while IFS= read -r pid; do
    [[ -z "$pid" ]] && continue
    [[ "$pid" == "$$" || "$pid" == "$PPID" ]] && continue
    if kill "$pid" 2>/dev/null; then
      echo "retire-wa001: stopped running token scheduler (pid $pid)"
      did_something=1
    fi
  done < <(pgrep -f 'agent-token-scheduler\.sh (--user|--parent)' 2>/dev/null || true)
fi

[[ "$did_something" -eq 1 ]] && echo "retire-wa001: membrane cleaned of WA-001 artifacts."
exit 0
