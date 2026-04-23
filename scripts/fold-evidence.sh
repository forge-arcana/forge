#!/usr/bin/env bash
# fold-evidence.sh — Evidence collection for the /forge cycle's fold phase
# Usage: fold-evidence.sh <forge-path>
# Reads all forge learnings, memories, and membrane state in one pass
set -euo pipefail

FORGE_PATH="${1:-}"
if [[ -z "$FORGE_PATH" ]]; then
  if [[ -f "$HOME/.claude/CLAUDE.md" ]]; then
    FORGE_PATH=$(sed -n 's/^forge-path:[[:space:]]*//p' "$HOME/.claude/CLAUDE.md" 2>/dev/null | sed 's/[[:space:]]*$//' || true)
  fi
  if [[ -z "$FORGE_PATH" ]]; then
    echo "ERROR: forge-path not found in ~/.claude/CLAUDE.md. Run /forge to configure."
    exit 1
  fi
fi

if [[ ! -d "$FORGE_PATH" ]]; then
  echo "ERROR: Forge not found at $FORGE_PATH"
  exit 1
fi

echo "## Fold Evidence Report"
echo "**Forge path**: \`$FORGE_PATH\`"
echo ""

# ============================================================
# Section 1: Forge Learnings Inventory
# ============================================================
echo "# Section 1: Forge Learnings"
echo ""

echo "### Learning files"
echo ""
echo "| File | Entries | Lines |"
echo "|------|---------|-------|"
for f in "$FORGE_PATH"/learnings/*.md; do
  [[ ! -f "$f" ]] && continue
  fname=$(basename "$f")
  entries=$(grep -c '^## ' "$f" 2>/dev/null || echo "0")
  lines=$(wc -l < "$f")
  echo "| $fname | $entries | $lines |"
done
echo ""

# Dump all learning content for LLM triage
echo "### Learning contents"
echo ""
for f in "$FORGE_PATH"/learnings/*.md; do
  [[ ! -f "$f" ]] && continue
  fname=$(basename "$f")
  echo "#### $fname"
  echo '```'
  cat "$f"
  echo '```'
  echo ""
done

# ============================================================
# Section 2: Forge Memory Inventory
# ============================================================
echo "# Section 2: Forge Memory"
echo ""

echo "### Memory files"
echo ""
echo "| File | Type | Description |"
echo "|------|------|-------------|"
for f in "$FORGE_PATH"/memory/*.md; do
  [[ ! -f "$f" ]] && continue
  fname=$(basename "$f")
  [[ "$fname" == "MEMORY.md" ]] && continue
  mtype=$(sed -n 's/^type:[[:space:]]*//p' "$f" 2>/dev/null || echo "unknown")
  desc=$(sed -n 's/^description:[[:space:]]*//p' "$f" 2>/dev/null || echo "(no description)")
  echo "| $fname | $mtype | $desc |"
done
echo ""

# Dump memory content
echo "### Memory contents"
echo ""
for f in "$FORGE_PATH"/memory/*.md; do
  [[ ! -f "$f" ]] && continue
  fname=$(basename "$f")
  [[ "$fname" == "MEMORY.md" ]] && continue
  echo "#### $fname"
  echo '```'
  cat "$f"
  echo '```'
  echo ""
done

# ============================================================
# Section 3: Membrane State (user's ~/.claude/)
# ============================================================
echo "# Section 3: Membrane Learnings"
echo ""

MEMBRANE_LEARNINGS="$HOME/.claude/learnings"
if [[ -d "$MEMBRANE_LEARNINGS" ]]; then
  echo "### Membrane learning files"
  echo ""
  echo "| File | Entries | Lines |"
  echo "|------|---------|-------|"
  for f in "$MEMBRANE_LEARNINGS"/*.md; do
    [[ ! -f "$f" ]] && continue
    fname=$(basename "$f")
    entries=$(grep -c '^## ' "$f" 2>/dev/null || echo "0")
    lines=$(wc -l < "$f")
    echo "| $fname | $entries | $lines |"
  done
  echo ""

  echo "### Membrane learning contents"
  echo ""
  for f in "$MEMBRANE_LEARNINGS"/*.md; do
    [[ ! -f "$f" ]] && continue
    fname=$(basename "$f")
    echo "#### $fname"
    echo '```'
    cat "$f"
    echo '```'
    echo ""
  done
else
  echo "(no membrane learnings directory)"
  echo ""
fi

echo "# Section 4: Membrane Memory"
echo ""

MEMBRANE_MEMORY="$HOME/.claude/memory"
if [[ -d "$MEMBRANE_MEMORY" ]]; then
  echo "### Membrane memory files"
  echo ""
  echo "| File | Type | Description |"
  echo "|------|------|-------------|"
  for f in "$MEMBRANE_MEMORY"/*.md; do
    [[ ! -f "$f" ]] && continue
    fname=$(basename "$f")
    [[ "$fname" == "MEMORY.md" ]] && continue
    mtype=$(sed -n 's/^type:[[:space:]]*//p' "$f" 2>/dev/null || echo "unknown")
    desc=$(sed -n 's/^description:[[:space:]]*//p' "$f" 2>/dev/null || echo "(no description)")
    echo "| $fname | $mtype | $desc |"
  done
  echo ""

  echo "### Membrane memory contents"
  echo ""
  for f in "$MEMBRANE_MEMORY"/*.md; do
    [[ ! -f "$f" ]] && continue
    fname=$(basename "$f")
    [[ "$fname" == "MEMORY.md" ]] && continue
    echo "#### $fname"
    echo '```'
    cat "$f"
    echo '```'
    echo ""
  done
else
  echo "(no membrane memory directory)"
  echo ""
fi

# ============================================================
# Section 5: Tracker State
# ============================================================
echo "# Section 5: Trackers"
echo ""

echo "### Fold tracker"
echo '```'
cat "$FORGE_PATH/learnings/.fold-tracker.json" 2>/dev/null || echo "(not found)"
echo '```'
echo ""

echo "### Memory tracker"
echo '```'
cat "$FORGE_PATH/memory/.memory-tracker.json" 2>/dev/null || echo "(not found)"
echo '```'
echo ""

echo "### Last cast baseline"
echo '```'
cat "$HOME/.claude/.last-cast.json" 2>/dev/null || echo "(not found)"
echo '```'
echo ""

echo "---"
echo "*Evidence collection complete. Classification checks (dedup, pre-triage, tracker consistency) are now in forge-status.sh output. LLM triage phase follows.*"
