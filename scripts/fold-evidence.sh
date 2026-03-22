#!/usr/bin/env bash
# fold-evidence.sh — Evidence collection for /fold
# Usage: fold-evidence.sh <forge-path>
# Reads all forge learnings, memories, and membrane state in one pass
set -euo pipefail

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

echo "### Reforge tracker"
echo '```'
cat "$FORGE_PATH/learnings/.reforge-tracker.json" 2>/dev/null || echo "(not found)"
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

# ============================================================
# Section 5: Mechanical Dedup & Pre-Triage
# ============================================================
echo "# Section 5: Dedup & Pre-Triage"
echo ""

# 5a: Cross-file duplicate titles within forge learnings
echo "### Cross-file duplicate titles (forge learnings)"
python3 -c "
import re, os
titles = {}  # title -> [files]
learnings_dir = os.path.join('$FORGE_PATH', 'learnings')
for fname in sorted(os.listdir(learnings_dir)):
    if not fname.endswith('.md'):
        continue
    fpath = os.path.join(learnings_dir, fname)
    try:
        with open(fpath) as f:
            for line in f:
                m = re.match(r'^## (.+?)(?:\s*\([\d-]+\))?\s*$', line)
                if m:
                    t = m.group(1).strip()
                    titles.setdefault(t, []).append(fname)
    except: pass
dupes = {t: fs for t, fs in titles.items() if len(fs) > 1}
if dupes:
    for t, fs in sorted(dupes.items()):
        print(f'DUPLICATE: \"{t}\" in {\" + \".join(fs)}')
else:
    print('No duplicates found.')
" 2>/dev/null || echo "(dedup check failed)"
echo ""

# 5b: Pre-triage candidates from general.md against forge learnings
echo "### Candidate pre-triage (general.md vs forge)"
MEMBRANE_LEARNINGS="$HOME/.claude/learnings/general.md"
if [[ -f "$MEMBRANE_LEARNINGS" ]]; then
  python3 -c "
import re, os, json

# Get all titles in forge learnings
forge_titles = {}  # title -> file
learnings_dir = os.path.join('$FORGE_PATH', 'learnings')
for fname in sorted(os.listdir(learnings_dir)):
    if not fname.endswith('.md'):
        continue
    fpath = os.path.join(learnings_dir, fname)
    try:
        with open(fpath) as f:
            for line in f:
                m = re.match(r'^## (.+?)(?:\s*\([\d-]+\))?\s*\$', line)
                if m:
                    forge_titles[m.group(1).strip()] = fname
    except: pass

# Get tracker processedEntries
processed = set()
tracker_path = os.path.join('$FORGE_PATH', 'learnings', '.reforge-tracker.json')
try:
    with open(tracker_path) as f:
        data = json.load(f)
        processed = set(data.get('processedEntries', []))
except: pass

# Get all titles in general.md
membrane_titles = []
try:
    with open('$MEMBRANE_LEARNINGS') as f:
        for line in f:
            m = re.match(r'^## (.+?)(?:\s*\([\d-]+\))?\s*\$', line)
            if m:
                membrane_titles.append(m.group(1).strip())
except: pass

for t in membrane_titles:
    in_forge = forge_titles.get(t)
    in_tracker = t in processed
    if in_forge and in_tracker:
        print(f'ABSORBED: \"{t}\" -> {in_forge} (in tracker)')
    elif in_forge:
        print(f'IN-FORGE: \"{t}\" -> {in_forge} (NOT in tracker — tracker stale?)')
    elif in_tracker:
        print(f'TRACKED-ONLY: \"{t}\" (in tracker but NOT in forge — orphan?)')
    else:
        print(f'NEW: \"{t}\" (not in forge, not in tracker)')
" 2>/dev/null || echo "(pre-triage check failed)"
else
  echo "(no membrane learnings file found)"
fi
echo ""

# 5c: Tracker consistency check
echo "### Tracker consistency"
python3 -c "
import re, os, json

forge_titles = set()
learnings_dir = os.path.join('$FORGE_PATH', 'learnings')
for fname in sorted(os.listdir(learnings_dir)):
    if not fname.endswith('.md'):
        continue
    try:
        with open(os.path.join(learnings_dir, fname)) as f:
            for line in f:
                m = re.match(r'^## (.+?)(?:\s*\([\d-]+\))?\s*\$', line)
                if m:
                    forge_titles.add(m.group(1).strip())
    except: pass

tracker_path = os.path.join('$FORGE_PATH', 'learnings', '.reforge-tracker.json')
try:
    with open(tracker_path) as f:
        data = json.load(f)
        processed = set(data.get('processedEntries', []))
except:
    processed = set()
    print('(tracker not found)')

orphans = processed - forge_titles
if orphans:
    for o in sorted(orphans):
        print(f'ORPHAN: \"{o}\" in tracker but not in any forge learning file')
else:
    print('Tracker consistent — all processed entries found in forge.')
" 2>/dev/null || echo "(consistency check failed)"
echo ""

echo "---"
echo "*Evidence collection complete. LLM triage phase follows.*"
