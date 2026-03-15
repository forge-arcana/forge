#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
# Forge — Bootstrap Installer
# ══════════════════════════════════════════════════════════════════════
#
# Deploys forge skills, learnings, and memory to ~/.claude/
# Safe to re-run — uses manifest to detect and report changes.
#
# Usage:
#   bash install.sh              # Install/update everything
#   bash install.sh --dry-run    # Show what would change without applying
#   bash install.sh --status     # Show current deployment status
#
set -euo pipefail

FORGE_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
SKILLS_SRC="$FORGE_DIR/skills"
SKILLS_DST="$CLAUDE_DIR/skills"
LEARNINGS_SRC="$FORGE_DIR/learnings"
LEARNINGS_DST="$CLAUDE_DIR/learnings"
MEMORY_SRC="$FORGE_DIR/memory"
MEMORY_DST="$CLAUDE_DIR/memory"
MANIFEST="$SKILLS_DST/.forge-manifest.json"

DRY_RUN=false
STATUS_ONLY=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true
[[ "${1:-}" == "--status" ]] && STATUS_ONLY=true

# ── Helpers ────────────────────────────────────────────────────────

hash_file() {
  sha256sum "$1" 2>/dev/null | cut -d' ' -f1
}

hash_dir() {
  # Hash all files in a directory, sorted for determinism
  local dir="$1"
  if [ -d "$dir" ]; then
    find "$dir" -type f | sort | xargs sha256sum 2>/dev/null | sha256sum | cut -d' ' -f1
  else
    echo "empty"
  fi
}

get_manifest_hash() {
  local key="$1"
  if [ -f "$MANIFEST" ]; then
    python3 -c "
import json, sys
try:
    m = json.load(open('$MANIFEST'))
    print(m.get('$key', {}).get('hash', 'missing'))
except:
    print('missing')
" 2>/dev/null
  else
    echo "missing"
  fi
}

# ── Status Check ──────────────────────────────────────────────────

if $STATUS_ONLY; then
  echo "Forge Deployment Status"
  echo "═══════════════════════"
  echo ""
  echo "Forge repo:     $FORGE_DIR"
  echo "Deploy target:  $CLAUDE_DIR"
  echo "Manifest:       $([ -f "$MANIFEST" ] && echo "exists" || echo "MISSING")"
  echo ""

  if [ -f "$MANIFEST" ]; then
    echo "Deployed at:    $(python3 -c "import json; print(json.load(open('$MANIFEST')).get('deployed_at', 'unknown'))" 2>/dev/null)"
    echo "Forge commit:   $(python3 -c "import json; print(json.load(open('$MANIFEST')).get('forge_commit', 'unknown'))" 2>/dev/null)"
  fi

  echo ""
  echo "Skills:"
  for skill_dir in "$SKILLS_SRC"/*/; do
    skill=$(basename "$skill_dir")
    current=$(hash_dir "$skill_dir")
    deployed=$(get_manifest_hash "skill:$skill")
    if [ "$deployed" = "missing" ]; then
      printf "  %-12s  NOT DEPLOYED\n" "$skill"
    elif [ "$current" = "$deployed" ]; then
      printf "  %-12s  up to date\n" "$skill"
    else
      printf "  %-12s  CHANGED (update available)\n" "$skill"
    fi
  done

  # Check for removed skills (in manifest but not in source)
  if [ -f "$MANIFEST" ]; then
    python3 -c "
import json, os
m = json.load(open('$MANIFEST'))
for key in m:
    if key.startswith('skill:'):
        name = key[6:]
        if not os.path.isdir('$SKILLS_SRC/' + name):
            print(f'  {name:<12}  REMOVED from forge (orphan)')
" 2>/dev/null
  fi

  exit 0
fi

# ── Pre-flight ────────────────────────────────────────────────────

echo "Forge Bootstrap Installer"
echo "═════════════════════════"
echo ""
echo "Forge repo:     $FORGE_DIR"
echo "Deploy target:  $CLAUDE_DIR"
$DRY_RUN && echo "Mode:           DRY RUN (no changes)"
echo ""

# Verify forge/skills/ exists
if [ ! -d "$SKILLS_SRC" ]; then
  echo "ERROR: $SKILLS_SRC not found. Is this the forge repo?"
  exit 1
fi

# ── Create directories ───────────────────────────────────────────

for dir in "$SKILLS_DST" "$LEARNINGS_DST" "$MEMORY_DST"; do
  if [ ! -d "$dir" ]; then
    if $DRY_RUN; then
      echo "[dry-run] Would create: $dir"
    else
      mkdir -p "$dir"
      echo "Created: $dir"
    fi
  fi
done

# ── Deploy Skills ────────────────────────────────────────────────

echo ""
echo "Skills"
echo "──────"

ADDED=0
UPDATED=0
UNCHANGED=0
REMOVED=0

for skill_dir in "$SKILLS_SRC"/*/; do
  skill=$(basename "$skill_dir")
  current_hash=$(hash_dir "$skill_dir")
  deployed_hash=$(get_manifest_hash "skill:$skill")

  if [ "$deployed_hash" = "missing" ]; then
    # New skill
    if $DRY_RUN; then
      echo "  [+] $skill — would deploy (NEW)"
    else
      cp -r "$skill_dir" "$SKILLS_DST/$skill"
      echo "  [+] $skill — deployed (NEW)"
    fi
    ADDED=$((ADDED + 1))
  elif [ "$current_hash" != "$deployed_hash" ]; then
    # Changed skill
    if $DRY_RUN; then
      echo "  [~] $skill — would update (CHANGED)"
    else
      rm -rf "$SKILLS_DST/$skill"
      cp -r "$skill_dir" "$SKILLS_DST/$skill"
      echo "  [~] $skill — updated (CHANGED)"
    fi
    UPDATED=$((UPDATED + 1))
  else
    echo "  [=] $skill — up to date"
    UNCHANGED=$((UNCHANGED + 1))
  fi
done

# Check for removed skills
if [ -f "$MANIFEST" ]; then
  python3 -c "
import json, os
m = json.load(open('$MANIFEST'))
for key in m:
    if key.startswith('skill:'):
        name = key[6:]
        if not os.path.isdir('$SKILLS_SRC/' + name):
            print(name)
" 2>/dev/null | while read -r skill; do
    if $DRY_RUN; then
      echo "  [-] $skill — would remove (REMOVED from forge)"
    else
      rm -rf "$SKILLS_DST/$skill"
      echo "  [-] $skill — removed (REMOVED from forge)"
    fi
    REMOVED=$((REMOVED + 1))
  done
fi

# ── Deploy Learnings (forge → user's global) ─────────────────────

echo ""
echo "Learnings"
echo "─────────"

if [ -d "$LEARNINGS_SRC" ]; then
  for learning_file in "$LEARNINGS_SRC"/*.md; do
    [ -f "$learning_file" ] || continue
    filename=$(basename "$learning_file")
    dst_file="$LEARNINGS_DST/$filename"

    if [ ! -f "$dst_file" ]; then
      if $DRY_RUN; then
        echo "  [+] $filename — would deploy (NEW)"
      else
        cp "$learning_file" "$dst_file"
        echo "  [+] $filename — deployed (NEW)"
      fi
    else
      src_hash=$(hash_file "$learning_file")
      dst_hash=$(hash_file "$dst_file")
      if [ "$src_hash" != "$dst_hash" ]; then
        echo "  [!] $filename — forge has updates (user copy differs)"
        echo "      Run /reforge to reconcile differences"
      else
        echo "  [=] $filename — up to date"
      fi
    fi
  done
else
  echo "  No learnings to deploy yet."
fi

# ── Deploy Memory (forge → user's global) ─────────────────────────

echo ""
echo "Memory"
echo "──────"

if [ -d "$MEMORY_SRC" ]; then
  found_memory=false
  for memory_file in "$MEMORY_SRC"/*.md; do
    [ -f "$memory_file" ] || continue
    found_memory=true
    filename=$(basename "$memory_file")
    dst_file="$MEMORY_DST/$filename"

    if [ ! -f "$dst_file" ]; then
      if $DRY_RUN; then
        echo "  [+] $filename — would deploy (NEW)"
      else
        cp "$memory_file" "$dst_file"
        echo "  [+] $filename — deployed (NEW)"
      fi
    else
      src_hash=$(hash_file "$memory_file")
      dst_hash=$(hash_file "$dst_file")
      if [ "$src_hash" != "$dst_hash" ]; then
        echo "  [!] $filename — forge has updates (user copy differs)"
        echo "      Run /reforge to reconcile differences"
      else
        echo "  [=] $filename — up to date"
      fi
    fi
  done
  if ! $found_memory; then
    echo "  No team memory files yet."
  fi
else
  echo "  No memory to deploy yet."
fi

# ── Set forge-path in ~/.claude/CLAUDE.md ────────────────────────

echo ""
echo "Config"
echo "──────"

CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
if [ -f "$CLAUDE_MD" ]; then
  if grep -q "forge-path:" "$CLAUDE_MD" 2>/dev/null; then
    current_path=$(grep "forge-path:" "$CLAUDE_MD" | head -1 | sed 's/.*forge-path:[[:space:]]*//')
    if [ "$current_path" = "$FORGE_DIR" ]; then
      echo "  forge-path: already set correctly"
    else
      if $DRY_RUN; then
        echo "  [~] Would update forge-path: $current_path → $FORGE_DIR"
      else
        sed -i "s|forge-path:.*|forge-path: $FORGE_DIR|" "$CLAUDE_MD"
        echo "  [~] Updated forge-path: $FORGE_DIR"
      fi
    fi
  else
    if $DRY_RUN; then
      echo "  [+] Would add forge-path: $FORGE_DIR to CLAUDE.md"
    else
      echo "" >> "$CLAUDE_MD"
      echo "- forge-path: $FORGE_DIR" >> "$CLAUDE_MD"
      echo "  [+] Added forge-path: $FORGE_DIR"
    fi
  fi
else
  echo "  ~/.claude/CLAUDE.md not found — skill resolution will use fallback path"
fi

# ── Write Manifest ───────────────────────────────────────────────

if ! $DRY_RUN; then
  FORGE_COMMIT=$(git -C "$FORGE_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")
  DEPLOYED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Build manifest JSON
  python3 -c "
import json, subprocess, os

manifest = {
    'version': 1,
    'deployed_at': '$DEPLOYED_AT',
    'forge_commit': '$FORGE_COMMIT',
    'forge_path': '$FORGE_DIR'
}

# Hash each skill directory
skills_src = '$SKILLS_SRC'
for skill in sorted(os.listdir(skills_src)):
    skill_path = os.path.join(skills_src, skill)
    if os.path.isdir(skill_path):
        # Get combined hash of all files in skill dir
        result = subprocess.run(
            f'find \"{skill_path}\" -type f | sort | xargs sha256sum 2>/dev/null | sha256sum',
            shell=True, capture_output=True, text=True
        )
        h = result.stdout.strip().split()[0] if result.stdout.strip() else 'unknown'
        files = sorted([
            f for f in os.listdir(skill_path)
            if os.path.isfile(os.path.join(skill_path, f))
        ])
        manifest[f'skill:{skill}'] = {'hash': h, 'files': files}

json.dump(manifest, open('$MANIFEST', 'w'), indent=2)
print('  Manifest written: $MANIFEST')
" 2>/dev/null
fi

# ── Summary ──────────────────────────────────────────────────────

echo ""
echo "Summary"
echo "───────"
echo "  Skills:    $ADDED added, $UPDATED updated, $UNCHANGED unchanged, $REMOVED removed"
echo ""

if $DRY_RUN; then
  echo "Dry run complete. Run without --dry-run to apply."
else
  echo "Forge deployed successfully."
  echo ""
  echo "Next steps:"
  echo "  1. cd into any project"
  echo "  2. Run /forge to apply conventions"
  echo "  3. Start building!"
fi
