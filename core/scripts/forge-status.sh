#!/usr/bin/env bash
# forge-status.sh — Mechanical membrane inspection
# Usage: forge-status.sh [--fetch|--pull]
# Outputs structured markdown for the /forge cycle preflight
#   --fetch: read-only inspection (used by /forge --dry)
#   --pull:  syncs forge before a writing cycle (used by /forge)
set -euo pipefail

# Membrane = the harness's per-tool config dir (~/.claude/ for Claude Code, ~/.bob/ for Bob, etc.)
MEMBRANE="${FORGE_MEMBRANE:-$HOME/.claude}"

MODE="${1:---fetch}"

# --- Resolve node binary (may not be on PATH in Git Bash on Windows) ---
NODE_BIN=""
for candidate in node "/c/Program Files/nodejs/node.exe" "/c/Program Files/nodejs/node"; do
  if command -v "$candidate" >/dev/null 2>&1 || [[ -x "$candidate" ]]; then
    NODE_BIN="$candidate"
    break
  fi
done
if [[ -z "$NODE_BIN" ]]; then
  echo "ERROR: node not found. Ensure Node.js is installed."
  exit 1
fi

# Convert MSYS/Git Bash paths (/c/Users/...) to Windows paths (C:/Users/...) for Node.js
winpath() {
  local p="$1"
  if [[ "$p" =~ ^/([a-zA-Z])/ ]]; then
    echo "${BASH_REMATCH[1]}:/${p:3}"
  else
    echo "$p"
  fi
}

# --- Step 1: Resolve forge path (FORGE_PATH env var > CLAUDE.md fallback) ---
FORGE_PATH="${FORGE_PATH:-}"
if [[ -z "$FORGE_PATH" && -f "$MEMBRANE/CLAUDE.md" ]]; then
  FORGE_PATH=$(sed -n 's/^forge-path:[[:space:]]*//p' "$MEMBRANE/CLAUDE.md" 2>/dev/null | sed 's/[[:space:]]*$//' || true)
fi
if [[ -z "$FORGE_PATH" ]]; then
  echo "ERROR: forge path not configured. Set FORGE_PATH env var, or add 'forge-path: /path/to/forge' to $MEMBRANE/CLAUDE.md."
  exit 1
fi

# --- Windows-safe paths for Node.js (MSYS /c/... → C:/...) ---
W_HOME=$(winpath "$HOME")
W_FORGE=$(winpath "$FORGE_PATH")

# --- Load last-cast baseline SHA (written by /forge after a successful cast phase) ---
LAST_CAST_SHA=""
LAST_CAST_FILE="$MEMBRANE/.last-cast.json"
W_LAST_CAST_FILE="$W_HOME/.claude/.last-cast.json"
if [[ -f "$LAST_CAST_FILE" ]]; then
  LAST_CAST_SHA=$("$NODE_BIN" -e "
const d = require('fs').readFileSync('$W_LAST_CAST_FILE','utf8');
console.log(JSON.parse(d).lastCastCommit || '');
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
  echo "**Baseline**: none (all diffs will be CONFLICT — run /forge to establish baseline)"
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
    echo "**STATUS**: $BEHIND commits behind remote. Run \`/forge\` to pull and sync."
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
for skill_dir in "$FORGE_PATH"/core/skills/*/; do
  skill=$(basename "$skill_dir")
  [[ ! -f "$skill_dir/SKILL.md" ]] && continue

  deployed="$MEMBRANE/skills/$skill"

  if [[ ! -d "$deployed" ]]; then
    echo "| $skill | ADDED | cast needed |"
    ADDED=$((ADDED + 1))
    ADDED_SKILLS+=("$skill")
    continue
  fi

  diff_output=$(diff -rq --strip-trailing-cr "$FORGE_PATH/core/skills/$skill" "$deployed" 2>/dev/null || true)

  if [[ -z "$diff_output" ]]; then
    echo "| $skill | IDENTICAL | -- |"
    IDENTICAL=$((IDENTICAL + 1))
  else
    if [[ -z "$LAST_CAST_SHA" ]]; then
      # No baseline — cannot safely determine direction; emit CONFLICT
      echo "| $skill | CONFLICT (no-baseline) | run /forge first to establish baseline |"
      CONFLICT=$((CONFLICT + 1))
      CHANGED_SKILLS+=("$skill")
    else
      # Three-way comparison using baseline
      # Q1: Did forge change since last cast?
      forge_changed="no"
      git -C "$FORGE_PATH" diff --quiet "$LAST_CAST_SHA" HEAD -- "core/skills/$skill/" 2>/dev/null || forge_changed="yes"

      if [[ "$forge_changed" == "no" ]]; then
        # Forge didn't move — membrane was edited
        if [[ "$skill" == "forge" || "$skill" == "purge" ]]; then
          echo "| $skill | DEPLOYED-DIFFERS (protected) | cast only — fold phase must NOT absorb |"
        else
          echo "| $skill | DEPLOYED-DIFFERS | outgoing |"
        fi
        NEED_FOLD=$((NEED_FOLD + 1))
        CHANGED_SKILLS+=("$skill")
      else
        # Forge moved — check if deployed matches baseline (stale) or was also modified (conflict)
        # Check if skill existed at baseline
        baseline_skill_exists=$(git -C "$FORGE_PATH" ls-tree "$LAST_CAST_SHA" "core/skills/$skill/" 2>/dev/null | head -1)

        if [[ -z "$baseline_skill_exists" ]]; then
          # Skill didn't exist at baseline — forge added it, incoming
          echo "| $skill | FORGE-UPDATED | incoming |"
          NEED_CAST=$((NEED_CAST + 1))
          CHANGED_SKILLS+=("$skill")
        else
          # Compare FULL deployed skill dir against baseline (not just SKILL.md)
          tmp_baseline=$(mktemp -d)
          git -C "$FORGE_PATH" archive --format=tar "$LAST_CAST_SHA" "core/skills/$skill/" 2>/dev/null \
            | tar -x -C "$tmp_baseline" 2>/dev/null || true
          deployed_vs_baseline=$(diff -rq --strip-trailing-cr \
            "$tmp_baseline/skills/$skill" "$deployed" 2>/dev/null || true)
          rm -rf "$tmp_baseline"

          if [[ -z "$deployed_vs_baseline" ]]; then
            # Deployed matches baseline exactly — membrane is just stale
            echo "| $skill | FORGE-UPDATED | incoming |"
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
if [[ -d "$MEMBRANE/skills" ]]; then
  for deployed_dir in "$MEMBRANE/skills"/*/; do
    [[ ! -d "$deployed_dir" ]] && continue
    skill=$(basename "$deployed_dir")
    [[ ! -f "$FORGE_PATH/core/skills/$skill/SKILL.md" ]] && continue
    if [[ ! -d "$FORGE_PATH/core/skills/$skill" ]]; then
      echo "| $skill | REMOVED | outgoing (deployed only) |"
      REMOVED=$((REMOVED + 1))
    fi
  done
fi

echo ""
CONFLICT_MSG=""
if [[ "$CONFLICT" -gt 0 ]]; then
  CONFLICT_MSG=", $CONFLICT conflict"
fi
echo "**Summary**: $IDENTICAL identical, $((NEED_CAST + ADDED)) incoming, $NEED_FOLD outgoing${CONFLICT_MSG}, $REMOVED removed"
echo ""

# --- Step 3b: Change details for non-IDENTICAL skills ---
if [[ ${#CHANGED_SKILLS[@]} -gt 0 && -n "$LAST_CAST_SHA" ]]; then
  echo "### Change Details"
  echo ""
  for skill in "${CHANGED_SKILLS[@]}"; do
    deployed="$MEMBRANE/skills/$skill"

    # Show git log of what changed in this skill since baseline
    changes=$(git -C "$FORGE_PATH" log --format="  - %h %s (%an)" "$LAST_CAST_SHA"..HEAD -- "core/skills/$skill/" 2>/dev/null || true)
    if [[ -n "$changes" ]]; then
      echo "**$skill**:"
      echo "$changes"
    else
      # Deployed differs but no forge commits — membrane was edited
      # Wrap diff in || true so pipefail doesn't append "0" after grep's count
      diff_stat=$( (diff --strip-trailing-cr "$FORGE_PATH/core/skills/$skill/SKILL.md" "$deployed/SKILL.md" 2>/dev/null || true) | grep -c '^[<>]' || echo "0")
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

GENERAL="$MEMBRANE/learnings/general.md"
TRACKER="$FORGE_PATH/learnings/.fold-tracker.json"
W_GENERAL="$W_HOME/.claude/learnings/general.md"
W_TRACKER="$W_FORGE/learnings/.fold-tracker.json"

if [[ -f "$GENERAL" ]]; then
  # Title-based UNPROCESSED calculation: checks BOTH tracker AND forge files
  # A membrane entry is "processed" if its title is in the tracker OR in any forge learning file
  eval "$("$NODE_BIN" -e "
const fs = require('fs'), path = require('path');
const dir = path.join('$W_FORGE', 'learnings');
const forgeTitles = new Set();
for (const fname of fs.readdirSync(dir).filter(f => f.endsWith('.md')).sort()) {
  for (const l of fs.readFileSync(path.join(dir, fname),'utf8').split('\n')) {
    const m = l.match(/^## (.+?)(?:\s*\([\d-]+\))?\s*$/);
    if (m) forgeTitles.add(m[1].trim());
  }
}
let tracked = new Set();
try {
  const d = JSON.parse(fs.readFileSync(path.join(dir, '.fold-tracker.json'),'utf8'));
  tracked = new Set(d.processedEntries || []);
} catch(e) {}
const membraneTitles = [];
for (const l of fs.readFileSync('$W_GENERAL','utf8').split('\n')) {
  const m = l.match(/^## (.+?)(?:\s*\([\d-]+\))?\s*$/);
  if (m) membraneTitles.push(m[1].trim());
}
const unprocessed = membraneTitles.filter(t => !tracked.has(t) && !forgeTitles.has(t));
const processed = membraneTitles.length - unprocessed.length;
console.log('TOTAL_ENTRIES=' + membraneTitles.length);
console.log('PROCESSED=' + processed);
console.log('UNPROCESSED=' + unprocessed.length);
" 2>/dev/null || echo "TOTAL_ENTRIES=0; PROCESSED=0; UNPROCESSED=0")"

  echo "| Source | Total | Processed | Unprocessed |"
  echo "|--------|-------|-----------|-------------|"
  echo "| general.md | $TOTAL_ENTRIES | $PROCESSED | $UNPROCESSED |"
  echo ""

  if [[ $UNPROCESSED -gt 0 ]]; then
    echo "**Unprocessed entries** (outgoing — ready for /forge):"
    # Title-based: show membrane entries NOT in tracker AND NOT in any forge file
    "$NODE_BIN" -e "
const fs = require('fs'), path = require('path');
const dir = path.join('$W_FORGE', 'learnings');
const forgeTitles = new Set();
for (const fname of fs.readdirSync(dir).filter(f => f.endsWith('.md')).sort()) {
  for (const l of fs.readFileSync(path.join(dir, fname),'utf8').split('\n')) {
    const m = l.match(/^## (.+?)(?:\s*\([\d-]+\))?\s*$/);
    if (m) forgeTitles.add(m[1].trim());
  }
}
let tracked = new Set();
try {
  const d = JSON.parse(fs.readFileSync(path.join(dir, '.fold-tracker.json'),'utf8'));
  tracked = new Set(d.processedEntries || []);
} catch(e) {}
for (const line of fs.readFileSync('$W_GENERAL','utf8').split('\n')) {
  const m = line.match(/^## (.+?)(?:\s*\([\d-]+\))?\s*$/);
  if (m) { const t = m[1].trim(); if (!tracked.has(t) && !forgeTitles.has(t)) console.log('- ' + t); }
}
" 2>/dev/null || true
    echo ""
  fi
else
  echo "No global learnings file found."
  echo ""
fi

# Skill-specific learnings — title-based comparison across ALL forge files + tracker
echo "### Skill-Specific Learnings"
echo ""
echo "| File | User Copy | Forge Copy | Status |"
echo "|------|-----------|------------|--------|"

# Build global title index: all titles across all forge learning files + tracker processedEntries
ALL_FORGE_TITLES_FILE=$(mktemp)
"$NODE_BIN" -e "
const fs = require('fs'), path = require('path');
const dir = '$W_FORGE/learnings';
const titles = new Set();
// Collect titles from all forge .md files
for (const f of fs.readdirSync(dir).filter(f => f.endsWith('.md'))) {
  for (const l of fs.readFileSync(path.join(dir, f),'utf8').split('\n')) {
    const m = l.match(/^## (.+?)(?:\s*\([\d-]+\))?\s*$/);
    if (m) titles.add(m[1].trim());
  }
}
// Also add tracker processedEntries
try {
  const t = JSON.parse(fs.readFileSync(path.join(dir, '.fold-tracker.json'),'utf8'));
  for (const e of (t.processedEntries || [])) titles.add(e);
} catch(e) {}
for (const t of [...titles].sort()) console.log(t);
" 2>/dev/null > "$ALL_FORGE_TITLES_FILE" || true

LEARNING_DETAILS_LINES=()
for forge_file in "$FORGE_PATH"/learnings/*.md; do
  [[ ! -f "$forge_file" ]] && continue
  fname=$(basename "$forge_file")
  [[ "$fname" == "general.md" ]] && continue

  user_file="$MEMBRANE/learnings/$fname"
  w_user_file="$W_HOME/.claude/learnings/$fname"
  w_forge_file=$(winpath "$forge_file")
  forge_count=$(grep -c '^## ' "$forge_file" 2>/dev/null || true)
  forge_count=${forge_count:-0}

  if [[ -f "$user_file" ]]; then
    user_count=$(grep -c '^## ' "$user_file" 2>/dev/null || true)
    user_count=${user_count:-0}

    # Title-based comparison: find titles truly new (not in ANY forge file or tracker)
    comparison=$("$NODE_BIN" -e "
const fs = require('fs');
function getTitles(p) {
  const t = new Set();
  try { for (const l of fs.readFileSync(p,'utf8').split('\n')) {
    const m = l.match(/^## (.+?)(?:\s*\([\d-]+\))?\s*$/);
    if (m) t.add(m[1].trim());
  }} catch(e) {}
  return t;
}
const userT = getTitles('$w_user_file');
const forgeFileT = getTitles('$w_forge_file');
const allForgeT = new Set(fs.readFileSync('$(winpath "$ALL_FORGE_TITLES_FILE")','utf8').split('\n').map(l=>l.trim()).filter(Boolean));
// Truly new in user = in user file, not in ANY forge file or tracker
const newInUser = [...userT].filter(t => !allForgeT.has(t)).sort();
// New in this forge file = in forge file, not in user file
const newInForge = [...forgeFileT].filter(t => !userT.has(t)).sort();
console.log(JSON.stringify({newInUser, newInForge}));
" 2>/dev/null || echo '{"newInUser":[],"newInForge":[]}')

    new_in_user=$("$NODE_BIN" -e "console.log(JSON.parse('$comparison').newInUser.length)" 2>/dev/null || echo "0")
    new_in_forge=$("$NODE_BIN" -e "console.log(JSON.parse('$comparison').newInForge.length)" 2>/dev/null || echo "0")

    if [[ "$new_in_user" -eq 0 && "$new_in_forge" -eq 0 ]]; then
      content_diff=$(diff --strip-trailing-cr "$user_file" "$forge_file" 2>/dev/null || true)
      if [[ -z "$content_diff" ]]; then
        echo "| $fname | $user_count | $forge_count | In sync |"
      else
        echo "| $fname | $user_count | $forge_count | Content differs but all titles accounted for |"
      fi
    elif [[ "$new_in_user" -gt 0 && "$new_in_forge" -eq 0 ]]; then
      echo "| $fname | $user_count | $forge_count | $new_in_user new in user -- fold needed |"
    elif [[ "$new_in_user" -eq 0 && "$new_in_forge" -gt 0 ]]; then
      echo "| $fname | $user_count | $forge_count | $new_in_forge new in forge -- cast needed |"
    else
      echo "| $fname | $user_count | $forge_count | $new_in_user new in user, $new_in_forge new in forge |"
    fi

    # Collect detail lines for truly new entries
    if [[ "$new_in_user" -gt 0 ]]; then
      detail_lines=$("$NODE_BIN" -e "
const fs = require('fs');
function getEntries(p) {
  const e = {}; let cur = null;
  try { for (const l of fs.readFileSync(p,'utf8').split('\n')) {
    const m = l.match(/^## (.+?)(?:\s*\([\d-]+\))?\s*$/);
    if (m) { cur = m[1].trim(); e[cur] = ''; }
    else if (cur && l.startsWith('**Learning**:')) {
      let s = l.replace('**Learning**:','').trim();
      if (s.length > 100) s = s.slice(0,97) + '...';
      e[cur] = s;
    }
  }} catch(e) {}
  return e;
}
const userE = getEntries('$w_user_file');
const allForgeT = new Set(fs.readFileSync('$(winpath "$ALL_FORGE_TITLES_FILE")','utf8').split('\n').map(l=>l.trim()).filter(Boolean));
const newTitles = Object.keys(userE).filter(t => !allForgeT.has(t)).sort();
for (const t of newTitles) {
  console.log(t);
  if (userE[t]) console.log('  -> ' + userE[t]);
}
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
    fi

    if [[ "$new_in_forge" -gt 0 ]]; then
      detail_lines=$("$NODE_BIN" -e "
const fs = require('fs');
const {execSync} = require('child_process');
function getEntries(p) {
  const e = {}; let cur = null;
  try { for (const l of fs.readFileSync(p,'utf8').split('\n')) {
    const m = l.match(/^## (.+?)(?:\s*\([\d-]+\))?\s*$/);
    if (m) { cur = m[1].trim(); e[cur] = ''; }
    else if (cur && l.startsWith('**Learning**:')) {
      let s = l.replace('**Learning**:','').trim();
      if (s.length > 100) s = s.slice(0,97) + '...';
      e[cur] = s;
    }
  }} catch(e) {}
  return e;
}
function getBlame(p, forgePath) {
  const authors = {};
  try {
    const out = execSync('git -C \"'+forgePath+'\" blame --line-porcelain \"'+p+'\"', {timeout:10000}).toString();
    let author = '';
    for (const l of out.split('\n')) {
      if (l.startsWith('author ')) author = l.slice(7);
      else if (l.startsWith('\t')) {
        const m = l.slice(1).match(/^## (.+?)(?:\s*\([\d-]+\))?\s*$/);
        if (m) authors[m[1].trim()] = author;
      }
    }
  } catch(e) {}
  return authors;
}
function getTitles(p) {
  const t = new Set();
  try { for (const l of fs.readFileSync(p,'utf8').split('\n')) {
    const m = l.match(/^## (.+?)(?:\s*\([\d-]+\))?\s*$/);
    if (m) t.add(m[1].trim());
  }} catch(e) {}
  return t;
}
const forgeE = getEntries('$w_forge_file');
const userT = getTitles('$w_user_file');
const blame = getBlame('$w_forge_file', '$W_FORGE');
const newTitles = Object.keys(forgeE).filter(t => !userT.has(t)).sort();
for (const t of newTitles) {
  const a = blame[t] || '';
  console.log(t + (a ? ' (' + a + ')' : ''));
  if (forgeE[t]) console.log('  -> ' + forgeE[t]);
}
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
    detail_lines=$("$NODE_BIN" -e "
const fs = require('fs');
const {execSync} = require('child_process');
function getEntries(p) {
  const e = {}; let cur = null;
  try { for (const l of fs.readFileSync(p,'utf8').split('\n')) {
    const m = l.match(/^## (.+?)(?:\s*\([\d-]+\))?\s*$/);
    if (m) { cur = m[1].trim(); e[cur] = ''; }
    else if (cur && l.startsWith('**Learning**:')) {
      let s = l.replace('**Learning**:','').trim();
      if (s.length > 100) s = s.slice(0,97) + '...';
      e[cur] = s;
    }
  }} catch(e) {}
  return e;
}
function getBlame(p, forgePath) {
  const authors = {};
  try {
    const out = execSync('git -C \"'+forgePath+'\" blame --line-porcelain \"'+p+'\"', {timeout:10000}).toString();
    let author = '';
    for (const l of out.split('\n')) {
      if (l.startsWith('author ')) author = l.slice(7);
      else if (l.startsWith('\t')) {
        const m = l.slice(1).match(/^## (.+?)(?:\s*\([\d-]+\))?\s*$/);
        if (m) authors[m[1].trim()] = author;
      }
    }
  } catch(e) {}
  return authors;
}
const forgeE = getEntries('$w_forge_file');
const blame = getBlame('$w_forge_file', '$W_FORGE');
for (const t of Object.keys(forgeE).sort()) {
  const a = blame[t] || '';
  console.log(t + (a ? ' (' + a + ')' : ''));
  if (forgeE[t]) console.log('  -> ' + forgeE[t]);
}
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
rm -f "$ALL_FORGE_TITLES_FILE"
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
W_MEM_TRACKER="$W_FORGE/memory/.memory-tracker.json"
SKIPPED_FILES=""
if [[ -f "$MEM_TRACKER" ]]; then
  SKIPPED_FILES=$("$NODE_BIN" -e "
const d = JSON.parse(require('fs').readFileSync('$W_MEM_TRACKER','utf8'));
(d.skippedFiles || []).forEach(f => console.log(f));
" 2>/dev/null || true)
fi

# Check membrane memories
if [[ -d "$MEMBRANE/memory" ]]; then
  for mem_file in "$MEMBRANE/memory"/*.md; do
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
        # Determine direction using baseline
        if [[ -n "$LAST_CAST_SHA" ]]; then
          forge_mem_changed="no"
          git -C "$FORGE_PATH" diff --quiet "$LAST_CAST_SHA" HEAD -- "memory/$fname" 2>/dev/null || forge_mem_changed="yes"
          if [[ "$forge_mem_changed" == "yes" ]]; then
            echo "| $fname | yes | yes (differs) | Forge updated -- cast needed |"
            MEM_CAST=$((MEM_CAST + 1))
          else
            echo "| $fname | yes | yes (differs) | Membrane updated -- fold candidate |"
            MEM_FOLD=$((MEM_FOLD + 1))
          fi
        else
          echo "| $fname | yes | yes (differs) | Updated (no baseline) -- run /forge first |"
          MEM_FOLD=$((MEM_FOLD + 1))
        fi
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

  if [[ ! -f "$MEMBRANE/memory/$fname" ]]; then
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

echo "**Summary**: $MEM_SYNC in sync, $MEM_FOLD outgoing, $MEM_CAST incoming, $MEM_SKIPPED skipped"
echo ""

# --- Step 6: Classification Checks (dedup, pre-triage, tracker consistency) ---
echo "## Classification Checks"
echo ""

# 6a: Cross-file duplicate titles within forge learnings
echo "### Cross-file duplicate titles (forge learnings)"
"$NODE_BIN" -e "
const fs = require('fs'), path = require('path');
const dir = path.join('$W_FORGE', 'learnings');
const titles = {};
for (const fname of fs.readdirSync(dir).filter(f => f.endsWith('.md')).sort()) {
  for (const l of fs.readFileSync(path.join(dir, fname),'utf8').split('\n')) {
    const m = l.match(/^## (.+?)(?:\s*\([\d-]+\))?\s*$/);
    if (m) { const t = m[1].trim(); (titles[t] = titles[t] || []).push(fname); }
  }
}
const dupes = Object.entries(titles).filter(([,fs]) => fs.length > 1).sort();
if (dupes.length) dupes.forEach(([t,fs]) => console.log('DUPLICATE: \"'+t+'\" in '+fs.join(' + ')));
else console.log('No duplicates found.');
" 2>/dev/null || echo "(dedup check failed)"
echo ""

# 6b: Pre-triage candidates from general.md against forge learnings
echo "### Candidate pre-triage (general.md vs forge)"
MEMBRANE_LEARNINGS="$MEMBRANE/learnings/general.md"
W_MEMBRANE_LEARNINGS="$W_HOME/.claude/learnings/general.md"
if [[ -f "$MEMBRANE_LEARNINGS" ]]; then
  "$NODE_BIN" -e "
const fs = require('fs'), path = require('path');
const dir = path.join('$W_FORGE', 'learnings');
const forgeTitles = {};
for (const fname of fs.readdirSync(dir).filter(f => f.endsWith('.md')).sort()) {
  for (const l of fs.readFileSync(path.join(dir, fname),'utf8').split('\n')) {
    const m = l.match(/^## (.+?)(?:\s*\([\d-]+\))?\s*$/);
    if (m) forgeTitles[m[1].trim()] = fname;
  }
}
let processed = new Set();
try {
  const d = JSON.parse(fs.readFileSync(path.join(dir, '.fold-tracker.json'),'utf8'));
  processed = new Set(d.processedEntries || []);
} catch(e) {}
const membraneTitles = [];
for (const l of fs.readFileSync('$W_MEMBRANE_LEARNINGS','utf8').split('\n')) {
  const m = l.match(/^## (.+?)(?:\s*\([\d-]+\))?\s*$/);
  if (m) membraneTitles.push(m[1].trim());
}
for (const t of membraneTitles) {
  const inForge = forgeTitles[t];
  const inTracker = processed.has(t);
  if (inForge && inTracker) console.log('ABSORBED: \"'+t+'\" -> '+inForge+' (in tracker)');
  else if (inForge) console.log('IN-FORGE: \"'+t+'\" -> '+inForge+' (NOT in tracker -- tracker stale?)');
  else if (inTracker) console.log('TRACKED-ONLY: \"'+t+'\" (in tracker, not in forge -- residue, safe)');
  else console.log('NEW: \"'+t+'\" (not in forge, not in tracker)');
}
" 2>/dev/null || echo "(pre-triage check failed)"
else
  echo "(no membrane learnings file found)"
fi
echo ""

# 6c: Tracker consistency check
echo "### Tracker consistency"
"$NODE_BIN" -e "
const fs = require('fs'), path = require('path');
const dir = path.join('$W_FORGE', 'learnings');
const forgeTitles = new Set();
for (const fname of fs.readdirSync(dir).filter(f => f.endsWith('.md')).sort()) {
  for (const l of fs.readFileSync(path.join(dir, fname),'utf8').split('\n')) {
    const m = l.match(/^## (.+?)(?:\s*\([\d-]+\))?\s*$/);
    if (m) forgeTitles.add(m[1].trim());
  }
}
let processed = new Set();
try {
  const d = JSON.parse(fs.readFileSync(path.join(dir, '.fold-tracker.json'),'utf8'));
  processed = new Set(d.processedEntries || []);
} catch(e) { console.log('(tracker not found)'); }
// Tracker entries without forge matches are harmless residue (purged or renamed).
// Tracker is append-only — these are NOT orphans to remove.
const residue = [...processed].filter(t => !forgeTitles.has(t)).sort();
if (residue.length === 0) console.log('Tracker consistent -- all processed entries found in forge.');
else console.log('Tracker has ' + residue.length + ' residue entries (purged/renamed -- safe, no action needed).');
" 2>/dev/null || echo "(consistency check failed)"
echo ""

# --- Step 7: Combined status ---
echo "## Membrane Status -- Summary"
echo ""
echo "| Area | Status | Action |"
echo "|------|--------|--------|"

if [[ "$MODE" == "--fetch" ]]; then
  if [[ "${BEHIND:-0}" -gt 0 ]]; then
    echo "| Forge Remote | $BEHIND commits behind | Run /forge to pull |"
  else
    echo "| Forge Remote | Up to date | -- |"
  fi
else
  echo "| Forge Remote | Up to date (pulled) | -- |"
fi

if [[ $((NEED_CAST + ADDED + NEED_FOLD + CONFLICT + REMOVED)) -eq 0 ]]; then
  echo "| Skills | $IDENTICAL identical | -- |"
else
  SKILL_STATUS="$((NEED_CAST + ADDED)) incoming, $NEED_FOLD outgoing"
  if [[ "$CONFLICT" -gt 0 ]]; then
    SKILL_STATUS="$SKILL_STATUS, $CONFLICT conflict"
  fi
  echo "| Skills | $SKILL_STATUS | Run /forge |"
fi

UNPROCESSED=${UNPROCESSED:-0}
if [[ "$UNPROCESSED" -gt 0 ]]; then
  echo "| Learnings | $UNPROCESSED unprocessed | Run /forge |"
else
  echo "| Learnings | 0 unprocessed | -- |"
fi

if [[ "$MEM_FOLD" -gt 0 || "$MEM_CAST" -gt 0 ]]; then
  echo "| Memory | $MEM_FOLD outgoing, $MEM_CAST incoming | Run /forge |"
else
  echo "| Memory | All synced | -- |"
fi
echo ""

# Recommended next step
if [[ "$CONFLICT" -gt 0 ]]; then
  echo "**Recommended**: Resolve $CONFLICT skill conflict(s) before running \`/forge\`"
elif [[ "${BEHIND:-0}" -gt 0 ]]; then
  echo "**Recommended**: \`/forge\` (forge is behind remote)"
elif [[ $((NEED_CAST + ADDED)) -gt 0 ]]; then
  echo "**Recommended**: \`/forge\` (incoming skills ready)"
elif [[ $NEED_FOLD -gt 0 || ${UNPROCESSED:-0} -gt 0 || $MEM_FOLD -gt 0 ]]; then
  echo "**Recommended**: \`/forge\` (outgoing knowledge ready for absorption)"
else
  echo "**Recommended**: All in sync -- nothing to do"
fi
