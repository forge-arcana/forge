#!/usr/bin/env bash
# forge-status.sh — Mechanical membrane inspection
# Usage: forge-status.sh [--fetch|--pull]
# Outputs structured markdown for /mark, /cast, /fold preflight
set -euo pipefail

MODE="${1:---fetch}"

# --- Step 1: Resolve forge path ---
FORGE_PATH=""
if [[ -f "$HOME/.claude/CLAUDE.md" ]]; then
  FORGE_PATH=$(sed -n 's/^forge-path:[[:space:]]*//p' "$HOME/.claude/CLAUDE.md" 2>/dev/null | sed 's/[[:space:]]*$//' || true)
fi
if [[ -z "$FORGE_PATH" ]]; then
  echo "ERROR: forge-path not found in ~/.claude/CLAUDE.md. Run /cast to configure."
  exit 1
fi

# --- Load last-cast baseline SHA (written by /cast after successful deploy) ---
LAST_CAST_SHA=""
LAST_CAST_FILE="$HOME/.claude/.last-cast.json"
if [[ -f "$LAST_CAST_FILE" ]]; then
  LAST_CAST_SHA=$(python3 -c "
import json
with open('$LAST_CAST_FILE') as f:
    print(json.load(f).get('lastCastCommit', ''))
" 2>/dev/null || true)
fi

if [[ ! -d "$FORGE_PATH" ]]; then
  echo "ERROR: Forge not found at $FORGE_PATH. Clone the forge repo first."
  exit 1
fi

# Validate baseline SHA is reachable in git history
if [[ -n "$LAST_CAST_SHA" ]]; then
  git -C "$FORGE_PATH" merge-base --is-ancestor "$LAST_CAST_SHA" HEAD >/dev/null 2>&1 || LAST_CAST_SHA=""
fi

echo "## Forge Preflight Report"
echo "**Forge path**: \`$FORGE_PATH\`"
echo "**Mode**: $MODE"
if [[ -n "$LAST_CAST_SHA" ]]; then
  echo "**Baseline**: \`${LAST_CAST_SHA:0:7}\` (last cast commit)"
else
  echo "**Baseline**: none (all diffs will be CONFLICT — run /cast to establish baseline)"
fi
echo ""

# --- Step 2: Remote sync ---
echo "## Remote Status"
if [[ "$MODE" == "--pull" ]]; then
  PULL_OUTPUT=$(git -C "$FORGE_PATH" pull --ff-only 2>&1) || {
    echo "**STATUS**: DIVERGED"
    echo "Forge repo has diverged. Run \`git -C $FORGE_PATH status\` to investigate."
    echo ""
    echo '```'
    echo "$PULL_OUTPUT"
    echo '```'
    exit 1
  }
  echo "**STATUS**: Up to date (pulled)"
else
  git -C "$FORGE_PATH" fetch 2>/dev/null
  BEHIND=$(git -C "$FORGE_PATH" rev-list HEAD..origin/main --count 2>/dev/null || echo "0")
  if [[ "$BEHIND" -gt 0 ]]; then
    echo "**STATUS**: $BEHIND commits behind remote. Run \`/cast\` to pull and sync."
  else
    echo "**STATUS**: Up to date"
  fi
fi
echo ""

# --- Step 3: Skill drift scan ---
echo "## Skill Drift Report"
echo ""
echo "| Skill | Status | Action |"
echo "|-------|--------|--------|"

IDENTICAL=0
NEED_CAST=0
NEED_FOLD=0
CONFLICT=0
ADDED=0
REMOVED=0
CHANGED_SKILLS=()
ADDED_SKILLS=()

# Scan forge skills
for skill_dir in "$FORGE_PATH"/skills/*/; do
  skill=$(basename "$skill_dir")
  [[ "$skill" == "forge" ]] && continue

  deployed="$HOME/.claude/skills/$skill"

  if [[ ! -d "$deployed" ]]; then
    echo "| $skill | ADDED | cast needed |"
    ADDED=$((ADDED + 1))
    ADDED_SKILLS+=("$skill")
    continue
  fi

  diff_output=$(diff -rq --strip-trailing-cr "$FORGE_PATH/skills/$skill" "$deployed" 2>/dev/null || true)

  if [[ -z "$diff_output" ]]; then
    echo "| $skill | IDENTICAL | -- |"
    IDENTICAL=$((IDENTICAL + 1))
  else
    if [[ -z "$LAST_CAST_SHA" ]]; then
      # No baseline — cannot safely determine direction; emit CONFLICT
      echo "| $skill | CONFLICT (no-baseline) | run /cast first to establish baseline |"
      CONFLICT=$((CONFLICT + 1))
      CHANGED_SKILLS+=("$skill")
    else
      # Three-way comparison using baseline
      # Q1: Did forge change since last cast?
      forge_changed="no"
      git -C "$FORGE_PATH" diff --quiet "$LAST_CAST_SHA" HEAD -- "skills/$skill/" 2>/dev/null || forge_changed="yes"

      if [[ "$forge_changed" == "no" ]]; then
        # Forge didn't move — membrane was edited
        if [[ "$skill" == "fold" || "$skill" == "cast" || "$skill" == "purge" ]]; then
          echo "| $skill | DEPLOYED-DIFFERS (protected) | cast needed — /fold must NOT absorb |"
        else
          echo "| $skill | DEPLOYED-DIFFERS | fold needed |"
        fi
        NEED_FOLD=$((NEED_FOLD + 1))
        CHANGED_SKILLS+=("$skill")
      else
        # Forge moved — check if deployed matches baseline (stale) or was also modified (conflict)
        # Check if skill existed at baseline
        baseline_skill_exists=$(git -C "$FORGE_PATH" ls-tree "$LAST_CAST_SHA" "skills/$skill/" 2>/dev/null | head -1)

        if [[ -z "$baseline_skill_exists" ]]; then
          # Skill didn't exist at baseline — forge added it, needs cast
          echo "| $skill | FORGE-UPDATED | cast needed |"
          NEED_CAST=$((NEED_CAST + 1))
          CHANGED_SKILLS+=("$skill")
        else
          # Compare FULL deployed skill dir against baseline (not just SKILL.md)
          tmp_baseline=$(mktemp -d)
          git -C "$FORGE_PATH" archive --format=tar "$LAST_CAST_SHA" "skills/$skill/" 2>/dev/null \
            | tar -x -C "$tmp_baseline" 2>/dev/null || true
          deployed_vs_baseline=$(diff -rq --strip-trailing-cr \
            "$tmp_baseline/skills/$skill" "$deployed" 2>/dev/null || true)
          rm -rf "$tmp_baseline"

          if [[ -z "$deployed_vs_baseline" ]]; then
            # Deployed matches baseline exactly — membrane is just stale
            echo "| $skill | FORGE-UPDATED | cast needed |"
            NEED_CAST=$((NEED_CAST + 1))
            CHANGED_SKILLS+=("$skill")
          else
            # Both sides changed since last cast
            echo "| $skill | CONFLICT | both changed since last cast |"
            CONFLICT=$((CONFLICT + 1))
            CHANGED_SKILLS+=("$skill")
          fi
        fi
      fi
    fi
  fi
done

# Check for deployed-only skills (not in forge)
if [[ -d "$HOME/.claude/skills" ]]; then
  for deployed_dir in "$HOME/.claude/skills"/*/; do
    [[ ! -d "$deployed_dir" ]] && continue
    skill=$(basename "$deployed_dir")
    [[ "$skill" == "forge" ]] && continue
    if [[ ! -d "$FORGE_PATH/skills/$skill" ]]; then
      echo "| $skill | REMOVED | deployed only, not in forge |"
      REMOVED=$((REMOVED + 1))
    fi
  done
fi

echo ""
CONFLICT_MSG=""
if [[ "$CONFLICT" -gt 0 ]]; then
  CONFLICT_MSG=", $CONFLICT conflict"
fi
echo "**Summary**: $IDENTICAL identical, $((NEED_CAST + ADDED)) need cast, $NEED_FOLD need fold${CONFLICT_MSG}, $REMOVED removed"
echo ""

# --- Step 3b: Change details for non-IDENTICAL skills ---
if [[ ${#CHANGED_SKILLS[@]} -gt 0 && -n "$LAST_CAST_SHA" ]]; then
  echo "### Change Details"
  echo ""
  for skill in "${CHANGED_SKILLS[@]}"; do
    deployed="$HOME/.claude/skills/$skill"

    # Show git log of what changed in this skill since baseline
    changes=$(git -C "$FORGE_PATH" log --oneline "$LAST_CAST_SHA"..HEAD -- "skills/$skill/" 2>/dev/null || true)
    if [[ -n "$changes" ]]; then
      echo "**$skill**:"
      echo "$changes" | while IFS= read -r line; do
        echo "  - $line"
      done
    else
      # Deployed differs but no forge commits — membrane was edited
      diff_stat=$(diff --strip-trailing-cr "$FORGE_PATH/skills/$skill/SKILL.md" "$deployed/SKILL.md" 2>/dev/null | grep -c '^[<>]' || echo "0")
      if [[ "$diff_stat" -gt 0 ]]; then
        echo "**$skill** (deployed copy modified):"
        echo "  - $diff_stat lines changed in deployed copy"
      fi
    fi
  done
  echo ""
fi

# --- Step 4: Learning status ---
echo "## Learning Status"
echo ""

GENERAL="$HOME/.claude/learnings/general.md"
TRACKER="$FORGE_PATH/learnings/.fold-tracker.json"

if [[ -f "$GENERAL" ]]; then
  # Extract all ## titles (strip date suffix)
  TOTAL_ENTRIES=$(grep -c '^## ' "$GENERAL" 2>/dev/null || echo "0")

  if [[ -f "$TRACKER" ]]; then
    PROCESSED=$(python3 -c "
import json
with open('$TRACKER') as f:
    data = json.load(f)
print(len(data.get('processedEntries', [])))
" 2>/dev/null || echo "0")
  else
    PROCESSED=0
  fi

  UNPROCESSED=$((TOTAL_ENTRIES - PROCESSED))
  if [[ $UNPROCESSED -lt 0 ]]; then
    echo "**WARNING**: Tracker has $((PROCESSED - TOTAL_ENTRIES)) processed entries not found in general.md — tracker is ahead of file. Run /fold to reconcile."
    UNPROCESSED=0
  fi

  echo "| Source | Total | Processed | Unprocessed |"
  echo "|--------|-------|-----------|-------------|"
  echo "| general.md | $TOTAL_ENTRIES | $PROCESSED | $UNPROCESSED |"
  echo ""

  if [[ $UNPROCESSED -gt 0 && -f "$TRACKER" ]]; then
    echo "**Unprocessed entries** (ready for /fold):"
    # Get titles from general.md, filter out ones in tracker
    python3 -c "
import json, re
with open('$TRACKER') as f:
    processed = set(json.load(f).get('processedEntries', []))
with open('$GENERAL') as f:
    for line in f:
        m = re.match(r'^## (.+?)(?:\s*\([\d-]+\))?\s*$', line)
        if m:
            title = m.group(1).strip()
            if title not in processed:
                print(f'- {title}')
" 2>/dev/null || true
    echo ""
  fi
else
  echo "No global learnings file found."
  echo ""
fi

# Skill-specific learnings
echo "### Skill-Specific Learnings"
echo ""
echo "| File | User Copy | Forge Copy | Status |"
echo "|------|-----------|------------|--------|"

LEARNING_DETAILS_LINES=()
for forge_file in "$FORGE_PATH"/learnings/*.md; do
  [[ ! -f "$forge_file" ]] && continue
  fname=$(basename "$forge_file")
  [[ "$fname" == "general.md" ]] && continue

  user_file="$HOME/.claude/learnings/$fname"
  forge_count=$(grep -c '^## ' "$forge_file" 2>/dev/null || true)
  forge_count=${forge_count:-0}

  if [[ -f "$user_file" ]]; then
    user_count=$(grep -c '^## ' "$user_file" 2>/dev/null || true)
    user_count=${user_count:-0}
    if [[ "$user_count" -eq "$forge_count" ]]; then
      content_diff=$(diff --strip-trailing-cr "$user_file" "$forge_file" 2>/dev/null || true)
      if [[ -z "$content_diff" ]]; then
        echo "| $fname | $user_count | $forge_count | In sync |"
      else
        echo "| $fname | $user_count | $forge_count | Same count but content differs -- fold needed |"
      fi
    elif [[ "$user_count" -gt "$forge_count" ]]; then
      diff=$((user_count - forge_count))
      echo "| $fname | $user_count | $forge_count | $diff new in user -- fold needed |"
      # Collect detail: titles + summaries for entries in user but not in forge
      detail_lines=$(python3 -c "
import re, subprocess
def get_entries(path):
    entries = {}
    current_title = None
    try:
        with open(path) as f:
            for line in f:
                m = re.match(r'^## (.+?)(?:\s*\([\d-]+\))?\s*$', line)
                if m:
                    current_title = m.group(1).strip()
                    entries[current_title] = ''
                elif current_title and line.startswith('**Learning**:'):
                    s = line.replace('**Learning**:', '').strip()
                    if len(s) > 100: s = s[:97] + '...'
                    entries[current_title] = s
    except: pass
    return entries
user_e = get_entries('$user_file')
forge_e = get_entries('$forge_file')
blame = {}
# For user-only entries, blame the user file
try:
    out = subprocess.run(['git', '-C', '$FORGE_PATH', 'blame', '--line-porcelain', '$user_file'],
        capture_output=True, text=True, timeout=10).stdout
    author = ''
    for line in out.split('\n'):
        if line.startswith('author '): author = line[7:]
        elif line.startswith('\t'):
            m = re.match(r'^## (.+?)(?:\s*\([\d-]+\))?\s*$', line[1:])
            if m: blame[m.group(1).strip()] = author
except: pass
new_titles = sorted(set(user_e.keys()) - set(forge_e.keys()))
for t in new_titles:
    a = blame.get(t, '')
    suffix = f' ({a})' if a else ''
    print(f'{t}{suffix}')
    if user_e.get(t): print(f'  -> {user_e[t]}')
" 2>/dev/null || true)
      if [[ -n "$detail_lines" ]]; then
        LEARNING_DETAILS_LINES+=("**${fname}** (new in user):")
        while IFS= read -r line; do
          if [[ "$line" == "  -> "* ]]; then
            LEARNING_DETAILS_LINES+=("    ${line/#  -> /→ }")
          else
            LEARNING_DETAILS_LINES+=("  - ${line}")
          fi
        done <<< "$detail_lines"
      fi
    else
      diff=$((forge_count - user_count))
      echo "| $fname | $user_count | $forge_count | $diff new in forge -- cast needed |"
      # Collect detail: titles + summaries for entries in forge but not in user
      detail_lines=$(python3 -c "
import re, subprocess
def get_entries(path):
    entries = {}
    current_title = None
    try:
        with open(path) as f:
            for line in f:
                m = re.match(r'^## (.+?)(?:\s*\([\d-]+\))?\s*$', line)
                if m:
                    current_title = m.group(1).strip()
                    entries[current_title] = ''
                elif current_title and line.startswith('**Learning**:'):
                    s = line.replace('**Learning**:', '').strip()
                    if len(s) > 100: s = s[:97] + '...'
                    entries[current_title] = s
    except: pass
    return entries
def get_blame_authors(path, forge_path):
    authors = {}
    try:
        out = subprocess.run(['git', '-C', forge_path, 'blame', '--line-porcelain', path],
            capture_output=True, text=True, timeout=10).stdout
        author = ''
        for line in out.split('\n'):
            if line.startswith('author '): author = line[7:]
            elif line.startswith('\t'):
                m = re.match(r'^## (.+?)(?:\s*\([\d-]+\))?\s*$', line[1:])
                if m: authors[m.group(1).strip()] = author
    except: pass
    return authors
forge_e = get_entries('$forge_file')
user_e = get_entries('$user_file')
blame = get_blame_authors('$forge_file', '$FORGE_PATH')
new_titles = sorted(set(forge_e.keys()) - set(user_e.keys()))
for t in new_titles:
    a = blame.get(t, '')
    suffix = f' ({a})' if a else ''
    print(f'{t}{suffix}')
    if forge_e.get(t): print(f'  -> {forge_e[t]}')
" 2>/dev/null || true)
      if [[ -n "$detail_lines" ]]; then
        LEARNING_DETAILS_LINES+=("**${fname}** (new in forge):")
        while IFS= read -r line; do
          if [[ "$line" == "  -> "* ]]; then
            LEARNING_DETAILS_LINES+=("    ${line/#  -> /→ }")
          else
            LEARNING_DETAILS_LINES+=("  - ${line}")
          fi
        done <<< "$detail_lines"
      fi
    fi
  else
    echo "| $fname | missing | $forge_count | cast needed |"
    # Collect detail: all titles + summaries (file missing in membrane)
    detail_lines=$(python3 -c "
import re, subprocess
def get_entries(path):
    entries = {}
    current_title = None
    try:
        with open(path) as f:
            for line in f:
                m = re.match(r'^## (.+?)(?:\s*\([\d-]+\))?\s*$', line)
                if m:
                    current_title = m.group(1).strip()
                    entries[current_title] = ''
                elif current_title and line.startswith('**Learning**:'):
                    s = line.replace('**Learning**:', '').strip()
                    if len(s) > 100: s = s[:97] + '...'
                    entries[current_title] = s
    except: pass
    return entries
def get_blame_authors(path, forge_path):
    authors = {}
    try:
        out = subprocess.run(['git', '-C', forge_path, 'blame', '--line-porcelain', path],
            capture_output=True, text=True, timeout=10).stdout
        author = ''
        for line in out.split('\n'):
            if line.startswith('author '): author = line[7:]
            elif line.startswith('\t'):
                m = re.match(r'^## (.+?)(?:\s*\([\d-]+\))?\s*$', line[1:])
                if m: authors[m.group(1).strip()] = author
    except: pass
    return authors
forge_e = get_entries('$forge_file')
blame = get_blame_authors('$forge_file', '$FORGE_PATH')
for t in sorted(forge_e.keys()):
    a = blame.get(t, '')
    suffix = f' ({a})' if a else ''
    print(f'{t}{suffix}')
    if forge_e.get(t): print(f'  -> {forge_e[t]}')
" 2>/dev/null || true)
    if [[ -n "$detail_lines" ]]; then
      LEARNING_DETAILS_LINES+=("**${fname}** (new file):")
      while IFS= read -r line; do
        if [[ "$line" == "  -> "* ]]; then
          LEARNING_DETAILS_LINES+=("    ${line/#  -> /→ }")
        else
          LEARNING_DETAILS_LINES+=("  - ${line}")
        fi
      done <<< "$detail_lines"
    fi
  fi
done
echo ""

if [[ ${#LEARNING_DETAILS_LINES[@]} -gt 0 ]]; then
  echo "### Learning Details"
  echo ""
  for line in "${LEARNING_DETAILS_LINES[@]}"; do
    echo "$line"
  done
  echo ""
fi

# --- Step 5: Memory status ---
echo "## Memory Status"
echo ""
echo "| File | In Membrane | In Forge | Status |"
echo "|------|-------------|----------|--------|"

MEM_SYNC=0
MEM_FOLD=0
MEM_CAST=0
MEM_SKIPPED=0

# Load memory tracker skippedFiles
MEM_TRACKER="$FORGE_PATH/memory/.memory-tracker.json"
SKIPPED_FILES=""
if [[ -f "$MEM_TRACKER" ]]; then
  SKIPPED_FILES=$(python3 -c "
import json
with open('$MEM_TRACKER') as f:
    data = json.load(f)
for f in data.get('skippedFiles', []):
    print(f)
" 2>/dev/null || true)
fi

# Check membrane memories
if [[ -d "$HOME/.claude/memory" ]]; then
  for mem_file in "$HOME/.claude/memory"/*.md; do
    [[ ! -f "$mem_file" ]] && continue
    fname=$(basename "$mem_file")
    [[ "$fname" == "MEMORY.md" ]] && continue

    forge_mem="$FORGE_PATH/memory/$fname"

    if [[ -f "$forge_mem" ]]; then
      diff_out=$(diff --strip-trailing-cr "$mem_file" "$forge_mem" 2>/dev/null || true)
      if [[ -z "$diff_out" ]]; then
        echo "| $fname | yes | yes | In sync |"
        MEM_SYNC=$((MEM_SYNC + 1))
      else
        echo "| $fname | yes | yes (differs) | Updated -- fold candidate |"
        MEM_FOLD=$((MEM_FOLD + 1))
      fi
    else
      # Check if skipped
      if echo "$SKIPPED_FILES" | grep -qx "$fname" 2>/dev/null; then
        echo "| $fname | yes | no | Skipped (PERSONAL) |"
        MEM_SKIPPED=$((MEM_SKIPPED + 1))
      else
        echo "| $fname | yes | no | New -- fold candidate |"
        MEM_FOLD=$((MEM_FOLD + 1))
      fi
    fi
  done
fi

# Check forge-only memories
FORGE_ONLY_FILES=()
for forge_mem in "$FORGE_PATH"/memory/*.md; do
  [[ ! -f "$forge_mem" ]] && continue
  fname=$(basename "$forge_mem")
  [[ "$fname" == "MEMORY.md" ]] && continue

  if [[ ! -f "$HOME/.claude/memory/$fname" ]]; then
    FORGE_ONLY_FILES+=("$fname")
    MEM_CAST=$((MEM_CAST + 1))
  fi
done

echo ""
if [[ ${#FORGE_ONLY_FILES[@]} -gt 0 ]]; then
  echo "**Forge-only memories** (cast candidate):"
  for fname in "${FORGE_ONLY_FILES[@]}"; do
    desc=$(sed -n 's/^description:[[:space:]]*//p' "$FORGE_PATH/memory/$fname" 2>/dev/null || echo "(no description)")
    echo "| $fname | $desc |"
  done
  echo ""
fi

echo "**Summary**: $MEM_SYNC in sync, $MEM_FOLD need fold, $MEM_CAST need cast, $MEM_SKIPPED skipped"
echo ""

# --- Step 6: Classification Checks (dedup, pre-triage, tracker consistency) ---
echo "## Classification Checks"
echo ""

# 6a: Cross-file duplicate titles within forge learnings
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

# 6b: Pre-triage candidates from general.md against forge learnings
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
tracker_path = os.path.join('$FORGE_PATH', 'learnings', '.fold-tracker.json')
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
        print(f'IN-FORGE: \"{t}\" -> {in_forge} (NOT in tracker -- tracker stale?)')
    elif in_tracker:
        print(f'TRACKED-ONLY: \"{t}\" (in tracker but NOT in forge -- orphan?)')
    else:
        print(f'NEW: \"{t}\" (not in forge, not in tracker)')
" 2>/dev/null || echo "(pre-triage check failed)"
else
  echo "(no membrane learnings file found)"
fi
echo ""

# 6c: Tracker consistency check
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

tracker_path = os.path.join('$FORGE_PATH', 'learnings', '.fold-tracker.json')
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
    print('Tracker consistent -- all processed entries found in forge.')
" 2>/dev/null || echo "(consistency check failed)"
echo ""

# --- Step 7: Combined status ---
echo "## Membrane Status -- Summary"
echo ""
echo "| Area | Status | Action |"
echo "|------|--------|--------|"

if [[ "$MODE" == "--fetch" ]]; then
  if [[ "${BEHIND:-0}" -gt 0 ]]; then
    echo "| Forge Remote | $BEHIND commits behind | Run /cast to pull |"
  else
    echo "| Forge Remote | Up to date | -- |"
  fi
else
  echo "| Forge Remote | Up to date (pulled) | -- |"
fi

if [[ $((NEED_CAST + ADDED + NEED_FOLD + CONFLICT + REMOVED)) -eq 0 ]]; then
  echo "| Skills | $IDENTICAL identical | -- |"
else
  SKILL_STATUS="$((NEED_CAST + ADDED)) need cast, $NEED_FOLD need fold"
  if [[ "$CONFLICT" -gt 0 ]]; then
    SKILL_STATUS="$SKILL_STATUS, $CONFLICT conflict"
  fi
  echo "| Skills | $SKILL_STATUS | Run /cast or /fold |"
fi

UNPROCESSED=${UNPROCESSED:-0}
if [[ "$UNPROCESSED" -gt 0 ]]; then
  echo "| Learnings | $UNPROCESSED unprocessed | Run /fold |"
else
  echo "| Learnings | 0 unprocessed | -- |"
fi

if [[ "$MEM_FOLD" -gt 0 || "$MEM_CAST" -gt 0 ]]; then
  echo "| Memory | $MEM_FOLD need fold, $MEM_CAST need cast | Run /fold |"
else
  echo "| Memory | All synced | -- |"
fi
echo ""

# Recommended next step
if [[ "$CONFLICT" -gt 0 ]]; then
  echo "**Recommended**: Resolve $CONFLICT skill conflict(s) before running \`/cast\` or \`/fold\`"
elif [[ "${BEHIND:-0}" -gt 0 ]]; then
  echo "**Recommended**: \`/cast\` (forge is behind remote)"
elif [[ $((NEED_CAST + ADDED)) -gt 0 ]]; then
  echo "**Recommended**: \`/cast\` (skills need deployment)"
elif [[ $NEED_FOLD -gt 0 || ${UNPROCESSED:-0} -gt 0 || $MEM_FOLD -gt 0 ]]; then
  echo "**Recommended**: \`/fold\` (knowledge ready for absorption)"
else
  echo "**Recommended**: All in sync -- nothing to do"
fi
