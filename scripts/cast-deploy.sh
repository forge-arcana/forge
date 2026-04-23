#!/usr/bin/env bash
# cast-deploy.sh — Deploy forge skills to membrane (~/.claude/skills/)
# Handles the cp -r pitfall correctly: always removes dest first, then copies fresh.
#
# Usage:
#   cast-deploy.sh <skill-name> [<skill-name> ...]   — deploy specific skills
#   cast-deploy.sh --all                               — deploy all skills
#   cast-deploy.sh --verify                            — verify all skills match forge
#
# Examples:
#   cast-deploy.sh cast fold mark          # deploy three skills
#   cast-deploy.sh --all                   # deploy everything
#   cast-deploy.sh --verify                # check for drift/nesting bugs
set -euo pipefail

FORGE_PATH=""
if [[ -f "$HOME/.claude/CLAUDE.md" ]]; then
  FORGE_PATH=$(sed -n 's/^forge-path:[[:space:]]*//p' "$HOME/.claude/CLAUDE.md" 2>/dev/null | sed 's/[[:space:]]*$//' || true)
fi
if [[ -z "$FORGE_PATH" ]]; then
  echo "ERROR: forge-path not found in ~/.claude/CLAUDE.md. Run /forge to configure."
  exit 1
fi

FORGE_SKILLS="$FORGE_PATH/skills"
MEMBRANE_SKILLS="$HOME/.claude/skills"

if [[ ! -d "$FORGE_SKILLS" ]]; then
  echo "ERROR: Forge skills not found at $FORGE_SKILLS"
  exit 1
fi

mkdir -p "$MEMBRANE_SKILLS"

# --- Verify mode: check all deployed skills for correctness ---
if [[ "${1:-}" == "--verify" ]]; then
  echo "## Deployment Verification"
  echo ""
  errors=0
  for skill_dir in "$FORGE_SKILLS"/*/; do
    skill=$(basename "$skill_dir")
    # Skip directories without a SKILL.md (not a deployable skill)
    [[ ! -f "$skill_dir/SKILL.md" ]] && continue
    dest="$MEMBRANE_SKILLS/$skill"
    if [[ ! -d "$dest" ]]; then
      echo "| $skill | MISSING | Not deployed |"
      errors=$((errors + 1))
      continue
    fi
    # Check for nested directory bug (skill/skill/ exists)
    if [[ -d "$dest/$skill" ]]; then
      echo "| $skill | NESTED BUG | Found $skill/$skill/ — redeploy needed |"
      errors=$((errors + 1))
      continue
    fi
    # Check content matches
    diff_output=$(diff -rq "$skill_dir" "$dest" 2>&1 || true)
    if [[ -n "$diff_output" ]]; then
      echo "| $skill | DIFFERS | $diff_output |"
      errors=$((errors + 1))
    else
      echo "| $skill | OK | In sync |"
    fi
  done
  echo ""
  if [[ $errors -eq 0 ]]; then
    echo "**All skills verified OK**"
  else
    echo "**$errors skill(s) need attention**"
  fi
  exit $errors
fi

# --- Build skill list ---
skills=()
if [[ "${1:-}" == "--all" ]]; then
  for skill_dir in "$FORGE_SKILLS"/*/; do
    skill=$(basename "$skill_dir")
    [[ ! -f "$skill_dir/SKILL.md" ]] && continue
    skills+=("$skill")
  done
else
  skills=("$@")
fi

if [[ ${#skills[@]} -eq 0 ]]; then
  echo "Usage: cast-deploy.sh <skill-name> [...] | --all | --verify"
  exit 1
fi

# --- Deploy each skill ---
echo "## Deploying ${#skills[@]} skill(s)"
echo ""
for skill in "${skills[@]}"; do
  src="$FORGE_SKILLS/$skill"
  dest="$MEMBRANE_SKILLS/$skill"

  if [[ ! -d "$src" ]]; then
    echo "| $skill | SKIP | Not found in forge |"
    continue
  fi

  # CRITICAL: Remove destination first to prevent cp -r nesting bug
  if [[ -d "$dest" ]]; then
    rm -rf "$dest"
  fi

  # Copy fresh from forge
  cp -r "$src" "$dest"

  # Verify no nesting occurred
  if [[ -d "$dest/$skill" ]]; then
    echo "| $skill | ERROR | Nesting bug detected after copy! |"
    exit 1
  fi

  echo "| $skill | DEPLOYED | $(find "$src" -type f | wc -l) file(s) |"
done
echo ""
echo "**Deploy complete**"
