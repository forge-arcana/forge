#!/usr/bin/env bash
# bootstrap.sh — opt-in Claude Code bridge for projects that consume forge.
#
# Forge emits the cross-tool standard (AGENTS.md + .agents/skills/) per the Open
# Agent Skills specification. Tools like Codex, Cursor, Gemini CLI, DeepSeek
# TUI, Bob, etc. read those artifacts natively — no bootstrap needed.
#
# Claude Code does not yet auto-load AGENTS.md (tracked at
# anthropics/claude-code#6235 and #34235). This script applies the two opt-in
# bridges Claude users typically want:
#
#   1. A 1-line CLAUDE.md containing `@AGENTS.md` — uses Claude's officially
#      documented @-import mechanism (recursive up to 5 hops). Cross-platform
#      (no symlink fragility on Windows). Anthropic-recommended for this exact
#      "forge already uses AGENTS.md" scenario.
#
#   2. (optional, opt-in via INSTALL_WA001=yes) WA-001 SessionStart hook that
#      proactively refreshes the OAuth token to mitigate the long-known
#      Claude-Code refresh-token race (see <forge>/claude-helpers/WORKAROUNDS.md WA-001).
#
# Usage:
#   bash claude-helpers/bootstrap.sh <project-path>
#   INSTALL_WA001=yes bash claude-helpers/bootstrap.sh <project-path>
#
# Idempotent. Safe to re-run.

set -uo pipefail

PROJECT="${1:?usage: bootstrap.sh <project-path>}"

if [[ ! -d "$PROJECT" ]]; then
  echo "ERROR: project path does not exist: $PROJECT" >&2
  exit 1
fi

PROJECT_ABS=$(cd "$PROJECT" && pwd)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- 1. CLAUDE.md → @AGENTS.md import ---
CLAUDE_MD="$PROJECT_ABS/CLAUDE.md"
EXPECTED_CONTENT="@AGENTS.md"

if [[ -f "$CLAUDE_MD" ]]; then
  ACTUAL_CONTENT=$(tr -d '\n' < "$CLAUDE_MD")
  if [[ "$ACTUAL_CONTENT" == "$EXPECTED_CONTENT" ]]; then
    echo "✓ CLAUDE.md already contains the @-import — no change."
  else
    echo "WARN: $CLAUDE_MD exists with content other than '$EXPECTED_CONTENT'." >&2
    echo "      Will not overwrite. To rebuild from scratch, delete it and re-run." >&2
  fi
else
  echo "$EXPECTED_CONTENT" > "$CLAUDE_MD"
  echo "✓ Created $CLAUDE_MD with @-import to AGENTS.md."
fi

# --- 2. (optional) WA-001 SessionStart hook ---
if [[ "${INSTALL_WA001:-no}" == "yes" ]]; then
  HOOK_INSTALLER="$SCRIPT_DIR/scripts/install-token-hook.sh"
  if [[ -x "$HOOK_INSTALLER" ]]; then
    echo "Installing WA-001 SessionStart hook..."
    bash "$HOOK_INSTALLER"
  else
    echo "WARN: WA-001 installer not found or not executable at $HOOK_INSTALLER" >&2
  fi
else
  echo "(WA-001 hook not installed — set INSTALL_WA001=yes to enable.)"
fi

echo ""
echo "Forge bootstrapped for Claude Code at: $PROJECT_ABS"
echo ""
echo "Other tools (Codex, Cursor, Gemini CLI, DeepSeek, Bob, Amp, Factory, etc.)"
echo "consume AGENTS.md and .agents/skills/ directly — no bootstrap needed."
