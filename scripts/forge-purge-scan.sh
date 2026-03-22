#!/usr/bin/env bash
# forge-purge-scan.sh — Forge hygiene evidence collection for /purge
# Usage: forge-purge-scan.sh [forge-path]
# Scans forge itself for contamination, staleness, duplication
set -euo pipefail

# Resolve forge path
FORGE_PATH="${1:-}"
if [[ -z "$FORGE_PATH" ]]; then
  if [[ -f "$HOME/.claude/CLAUDE.md" ]]; then
    FORGE_PATH=$(sed -n 's/^forge-path:[[:space:]]*//p' "$HOME/.claude/CLAUDE.md" 2>/dev/null | tr -d '[:space:]' || true)
  fi
  if [[ -z "$FORGE_PATH" ]]; then
    echo "ERROR: forge-path not found in ~/.claude/CLAUDE.md. Run /cast to configure."
    exit 1
  fi
fi

if [[ ! -d "$FORGE_PATH" ]]; then
  echo "ERROR: Forge not found at $FORGE_PATH"
  exit 1
fi

echo "## Forge Purge Scan Report"
echo "**Forge path**: \`$FORGE_PATH\`"
echo ""

# ============================================================
# Dimension 1: Knowledge Purity
# ============================================================
echo "# Dimension 1: Knowledge Purity"
echo ""

# --- 1a: Project-specific leaks ---
echo "## 1a: Project Name Contamination"
echo ""
echo "Scanning learnings and memory for proper nouns, specific paths, and domains..."
echo ""

# Scan for capitalized words that look like project names (2+ consecutive caps words)
echo "### Capitalized proper nouns in learnings"
echo '```'
rg -n '[A-Z][a-z]+(?:App|Api|Server|Client|Admin|Portal|Dashboard|Service)' "$FORGE_PATH/learnings/" 2>/dev/null | head -20 || echo "(none found)"
echo '```'
echo ""

# Scan for specific file paths (src/routes/appname, packages/appname)
echo "### Specific file paths in learnings"
echo '```'
rg -n 'src/[a-z]+/[a-z]+/|packages/[a-z]+/' "$FORGE_PATH/learnings/" 2>/dev/null | grep -v 'packages/server\|packages/client\|packages/shared\|packages/database\|src/lib/\|src/routes/\|src/components/' | head -20 || echo "(none found)"
echo '```'
echo ""

# Scan for URLs and domains
echo "### URLs and domains in learnings"
echo '```'
rg -n 'https?://[a-z]|\.com/|\.io/|\.dev/' "$FORGE_PATH/learnings/" 2>/dev/null | grep -v 'github.com\|npmjs.com\|example.com\|localhost' | head -20 || echo "(none found)"
echo '```'
echo ""

# Same scans for memory
echo "### Contamination in memory files"
echo '```'
rg -n '[A-Z][a-z]+(?:App|Api|Server|Client|Admin|Portal|Dashboard|Service)' "$FORGE_PATH/memory/" 2>/dev/null | head -10 || echo "(none found)"
rg -n 'https?://[a-z]' "$FORGE_PATH/memory/" 2>/dev/null | grep -v 'github.com\|npmjs.com\|example.com\|localhost' | head -10 || echo "(none found)"
echo '```'
echo ""

# --- 1b: Staleness indicators ---
echo "## 1b: Staleness Indicators"
echo ""

echo "### Version references in learnings (may be outdated)"
echo '```'
rg -n 'v\d+\.\d+|version \d|@\d+\.\d+' "$FORGE_PATH/learnings/" 2>/dev/null | head -20 || echo "(none found)"
echo '```'
echo ""

echo "### Deprecated API references"
echo '```'
rg -n -i 'deprecated|legacy|old api|removed in|breaking change' "$FORGE_PATH/learnings/" 2>/dev/null | head -20 || echo "(none found)"
echo '```'
echo ""

# --- 1c: Duplication ---
echo "## 1c: Duplication Detection"
echo ""

# Extract all ## headings across all learning files and find duplicates
echo "### Duplicate entry titles across learning files"
echo '```'
grep -rn '^## ' "$FORGE_PATH/learnings/"*.md 2>/dev/null | \
  sed 's/^.*:## //' | \
  sed 's/ ([0-9-]*)$//' | \
  sort | uniq -c | sort -rn | \
  awk '$1 > 1 {print}' || echo "(no duplicates)"
echo '```'
echo ""

# Count entries per file
echo "### Entry counts per learning file"
echo ""
echo "| File | Entries |"
echo "|------|---------|"
for f in "$FORGE_PATH"/learnings/*.md; do
  [[ ! -f "$f" ]] && continue
  fname=$(basename "$f")
  count=$(grep -c '^## ' "$f" 2>/dev/null || true)
  echo "| $fname | $count |"
done
echo ""

# --- 1d: Density ---
echo "## 1d: Verbose Entries (>10 lines)"
echo ""
echo "| File | Entry | Lines |"
echo "|------|-------|-------|"

for f in "$FORGE_PATH"/learnings/*.md; do
  [[ ! -f "$f" ]] && continue
  fname=$(basename "$f")
  python3 -c "
import re
with open('$f') as fh:
    content = fh.read()
entries = re.split(r'^## ', content, flags=re.MULTILINE)[1:]
for entry in entries:
    lines = entry.strip().split('\n')
    title = lines[0].strip()
    if len(lines) > 10:
        print(f'| $fname | {title[:50]} | {len(lines)} |')
" 2>/dev/null || true
done
echo ""

# ============================================================
# Dimension 2: Memory Hygiene
# ============================================================
echo "# Dimension 2: Memory Hygiene"
echo ""

echo "### Memory file inventory"
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

# ============================================================
# Dimension 3: Art Fitness
# ============================================================
echo "# Dimension 3: Art Fitness"
echo ""

echo "### Art SKILL.md sizes"
echo ""
echo "| Art | Lines | Chars | Has Protocol Ref? |"
echo "|-----|-------|-------|-------------------|"
for art in prime probe poke preen press pound pry purge; do
  skill_file="$FORGE_PATH/skills/$art/SKILL.md"
  if [[ -f "$skill_file" ]]; then
    lines=$(wc -l < "$skill_file")
    chars=$(wc -c < "$skill_file")
    has_protocol=$(grep -c 'protocol.md\|Forge Protocol' "$skill_file" 2>/dev/null || echo "0")
    proto_status="YES"
    [[ "$has_protocol" -eq 0 ]] && proto_status="**MISSING**"
    echo "| $art | $lines | $chars | $proto_status |"
  else
    echo "| $art | -- | -- | SKILL.md MISSING |"
  fi
done
echo ""

echo "### Section-level bloat analysis (all skills)"
echo ""
echo "| Skill | Section | Lines | % of File |"
echo "|-------|---------|-------|-----------|"
for f in "$FORGE_PATH"/skills/*/SKILL.md; do
  [[ ! -f "$f" ]] && continue
  skill_name=$(basename "$(dirname "$f")")
  [[ "$skill_name" == "forge" ]] && continue
  total=$(wc -l < "$f")
  python3 -c "
import re
with open('$f') as fh:
    content = fh.read()
sections = re.split(r'^## ', content, flags=re.MULTILINE)
for section in sections[1:]:
    lines_list = section.strip().split('\n')
    title = lines_list[0].strip()[:40]
    count = len(lines_list)
    pct = round(100 * count / $total) if $total > 0 else 0
    if pct >= 15:
        print(f'| $skill_name | {title} | {count} | {pct}% |')
" 2>/dev/null || true
done
echo ""

echo "### Redundancy check: content duplicated from reference docs"
echo '```'
for f in "$FORGE_PATH"/skills/*/SKILL.md; do
  [[ ! -f "$f" ]] && continue
  skill_name=$(basename "$(dirname "$f")")
  [[ "$skill_name" == "forge" ]] && continue
  # Check for inline grep patterns (should be in scan script instead)
  grep_count=$(grep -c "^rg \|^grep " "$f" 2>/dev/null | head -1 || true)
  grep_count="${grep_count:-0}"
  if [[ "$grep_count" =~ ^[0-9]+$ ]] && [[ "$grep_count" -gt 0 ]]; then
    echo "$skill_name: $grep_count inline grep patterns (should be in forge-scan.sh)"
  fi
  logging_lines=$(grep -c "MUST be logged\|MUST NOT be logged\|What MUST\|What MUST NOT" "$f" 2>/dev/null | head -1 || true)
  logging_lines="${logging_lines:-0}"
  if [[ "$logging_lines" =~ ^[0-9]+$ ]] && [[ "$logging_lines" -gt 2 ]]; then
    echo "$skill_name: $logging_lines logging rule lines (should reference forge-conventions.md)"
  fi
done
echo '```'
echo ""

echo "### Consistency: frontmatter fields"
echo ""
echo "| Art | name | description | user-invocable |"
echo "|-----|------|-------------|----------------|"
for art in prime probe poke preen press pound pry purge; do
  skill_file="$FORGE_PATH/skills/$art/SKILL.md"
  if [[ -f "$skill_file" ]]; then
    has_name=$(grep -c '^name:' "$skill_file" 2>/dev/null || echo "0")
    has_desc=$(grep -c '^description:' "$skill_file" 2>/dev/null || echo "0")
    has_ui=$(grep -c '^user-invocable:' "$skill_file" 2>/dev/null || echo "0")
    echo "| $art | $([[ $has_name -gt 0 ]] && echo YES || echo MISSING) | $([[ $has_desc -gt 0 ]] && echo YES || echo MISSING) | $([[ $has_ui -gt 0 ]] && echo YES || echo MISSING) |"
  fi
done
echo ""

# ============================================================
# Dimension 4: Reference Integrity
# ============================================================
echo "# Dimension 4: Reference Integrity"
echo ""

echo "### Reference doc sizes"
echo ""
echo "| File | Lines | Last Modified |"
echo "|------|-------|---------------|"
for ref in stack-guide.md claude-code-rules.md forge-conventions.md protocol.md preflight.md; do
  ref_file="$FORGE_PATH/skills/forge/$ref"
  if [[ -f "$ref_file" ]]; then
    lines=$(wc -l < "$ref_file")
    modified=$(git -C "$FORGE_PATH" log -1 --format='%cr' -- "skills/forge/$ref" 2>/dev/null || echo "unknown")
    echo "| $ref | $lines | $modified |"
  else
    echo "| $ref | -- | **MISSING** |"
  fi
done
echo ""

echo "### CLAUDE.md Current Context freshness"
echo '```'
grep -A5 '## Current Context' "$FORGE_PATH/CLAUDE.md" 2>/dev/null | head -8 || echo "(no Current Context section)"
echo '```'
echo ""

# Skill count verification
echo "### Skill count verification"
TOTAL_SKILLS=$(find "$FORGE_PATH/skills" -maxdepth 1 -mindepth 1 -type d ! -name forge | wc -l)
ARTS=$(echo "prime probe poke preen press pound pry purge" | wc -w)
TASK_SKILLS=$((TOTAL_SKILLS - ARTS))
echo "**Total skills**: $TOTAL_SKILLS ($ARTS arts + $TASK_SKILLS task skills)"
echo ""

# Check if CLAUDE.md counts match
CLAIMED_SKILLS=$(grep -o '[0-9]* global skills' "$FORGE_PATH/CLAUDE.md" 2>/dev/null || echo "not stated")
echo "**CLAUDE.md claims**: $CLAIMED_SKILLS"
echo "**Actual**: $TOTAL_SKILLS"
echo ""

echo "---"
echo "*Evidence collection complete. LLM judgment phase follows.*"
