#!/usr/bin/env bash
# forge-status.sh — Mechanical membrane inspection
# Usage: forge-status.sh [--fetch|--pull]
# Outputs structured markdown for /mark, /cast, /fold preflight
set -euo pipefail

MODE="${1:---fetch}"

# --- Step 1: Resolve forge path ---
FORGE_PATH=""
if [[ -f "$HOME/.claude/CLAUDE.md" ]]; then
  FORGE_PATH=$(grep -oP 'forge-path:\s*\K\S+' "$HOME/.claude/CLAUDE.md" 2>/dev/null || true)
fi
FORGE_PATH="${FORGE_PATH:-/root/dev/forge}"

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
  git -C "$FORGE_PATH" cat-file -t "$LAST_CAST_SHA" >/dev/null 2>&1 || LAST_CAST_SHA=""
fi

echo "## Forge Preflight Report"
echo "**Forge path**: \`$FORGE_PATH\`"
echo "**Mode**: $MODE"
if [[ -n "$LAST_CAST_SHA" ]]; then
  echo "**Baseline**: \`${LAST_CAST_SHA:0:7}\` (last cast commit)"
else
  echo "**Baseline**: none (two-way fallback)"
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

# Scan forge skills
for skill_dir in "$FORGE_PATH"/skills/*/; do
  skill=$(basename "$skill_dir")
  [[ "$skill" == "forge" ]] && continue

  deployed="$HOME/.claude/skills/$skill"

  if [[ ! -d "$deployed" ]]; then
    echo "| $skill | ADDED | cast needed |"
    ADDED=$((ADDED + 1))
    continue
  fi

  diff_output=$(diff -rq --strip-trailing-cr "$FORGE_PATH/skills/$skill" "$deployed" 2>/dev/null || true)

  if [[ -z "$diff_output" ]]; then
    echo "| $skill | IDENTICAL | -- |"
    IDENTICAL=$((IDENTICAL + 1))
  else
    if [[ -z "$LAST_CAST_SHA" ]]; then
      # No baseline — fall back to two-way heuristic
      git_diff=$(git -C "$FORGE_PATH" diff HEAD origin/main -- "skills/$skill" 2>/dev/null || true)
      if [[ -n "$git_diff" ]]; then
        echo "| $skill | FORGE-UPDATED | cast needed |"
        NEED_CAST=$((NEED_CAST + 1))
      else
        echo "| $skill | DEPLOYED-DIFFERS | fold needed |"
        NEED_FOLD=$((NEED_FOLD + 1))
      fi
    else
      # Three-way comparison using baseline
      # Q1: Did forge change since last cast?
      forge_changed="no"
      git -C "$FORGE_PATH" diff --quiet "$LAST_CAST_SHA" HEAD -- "skills/$skill/" 2>/dev/null || forge_changed="yes"

      if [[ "$forge_changed" == "no" ]]; then
        # Forge didn't move — membrane was edited
        echo "| $skill | DEPLOYED-DIFFERS | fold needed |"
        NEED_FOLD=$((NEED_FOLD + 1))
      else
        # Forge moved — check if deployed matches baseline (stale) or was also modified (conflict)
        # Get baseline SKILL.md content
        baseline_content=$(git -C "$FORGE_PATH" show "$LAST_CAST_SHA:skills/$skill/SKILL.md" 2>/dev/null || echo "")

        if [[ -z "$baseline_content" ]]; then
          # Skill didn't exist at baseline — forge added it, needs cast
          echo "| $skill | FORGE-UPDATED | cast needed |"
          NEED_CAST=$((NEED_CAST + 1))
        else
          # Compare deployed SKILL.md against baseline
          deployed_vs_baseline=$(diff --strip-trailing-cr <(echo "$baseline_content") "$deployed/SKILL.md" 2>/dev/null || true)

          if [[ -z "$deployed_vs_baseline" ]]; then
            # Deployed matches baseline — membrane is just stale
            echo "| $skill | FORGE-UPDATED | cast needed |"
            NEED_CAST=$((NEED_CAST + 1))
          else
            # Both sides changed since last cast
            echo "| $skill | CONFLICT | both changed since last cast |"
            CONFLICT=$((CONFLICT + 1))
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

# --- Step 4: Learning status ---
echo "## Learning Status"
echo ""

GENERAL="$HOME/.claude/learnings/general.md"
TRACKER="$FORGE_PATH/learnings/.reforge-tracker.json"

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
  [[ $UNPROCESSED -lt 0 ]] && UNPROCESSED=0

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
      echo "| $fname | $user_count | $forge_count | In sync |"
    elif [[ "$user_count" -gt "$forge_count" ]]; then
      diff=$((user_count - forge_count))
      echo "| $fname | $user_count | $forge_count | $diff new in user -- fold needed |"
    else
      diff=$((forge_count - user_count))
      echo "| $fname | $user_count | $forge_count | $diff new in forge -- cast needed |"
    fi
  else
    echo "| $fname | missing | $forge_count | cast needed |"
  fi
done
echo ""

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
FORGE_ONLY=""
for forge_mem in "$FORGE_PATH"/memory/*.md; do
  [[ ! -f "$forge_mem" ]] && continue
  fname=$(basename "$forge_mem")
  [[ "$fname" == "MEMORY.md" ]] && continue

  if [[ ! -f "$HOME/.claude/memory/$fname" ]]; then
    FORGE_ONLY="$FORGE_ONLY $fname"
    MEM_CAST=$((MEM_CAST + 1))
  fi
done

echo ""
if [[ -n "$FORGE_ONLY" ]]; then
  echo "**Forge-only memories** (cast candidate):"
  for fname in $FORGE_ONLY; do
    desc=$(grep -oP 'description:\s*\K.*' "$FORGE_PATH/memory/$fname" 2>/dev/null || echo "(no description)")
    echo "| $fname | $desc |"
  done
  echo ""
fi

echo "**Summary**: $MEM_SYNC in sync, $MEM_FOLD need fold, $MEM_CAST need cast, $MEM_SKIPPED skipped"
echo ""

# --- Step 6: Combined status ---
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
