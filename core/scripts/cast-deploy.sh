#!/usr/bin/env bash
# cast-deploy.sh — Deploy forge skills (and runtime scripts) to membrane ($MEMBRANE/)
# Handles the cp -r pitfall correctly: always removes dest first, then copies fresh.
#
# Usage:
#   cast-deploy.sh <skill-name> [<skill-name> ...]   — deploy specific skills
#   cast-deploy.sh --all                               — deploy all skills + runtime scripts
#   cast-deploy.sh --verify                            — verify all skills match forge
#   cast-deploy.sh --scripts                           — deploy runtime scripts to $MEMBRANE/scripts/
#   cast-deploy.sh --verify-scripts                    — verify runtime scripts match forge
#
# Examples:
#   cast-deploy.sh cast fold mark          # deploy three skills
#   cast-deploy.sh --all                   # deploy everything (skills + scripts)
#   cast-deploy.sh --verify                # check for drift/nesting bugs
#   cast-deploy.sh --scripts               # deploy WA-001 runtime scripts to membrane
set -euo pipefail

# Membrane = the harness's per-tool config dir (~/.claude/ for Claude Code, ~/.bob/ for Bob, etc.)
MEMBRANE="${FORGE_MEMBRANE:-$HOME/.claude}"

FORGE_PATH=""
if [[ -f "$MEMBRANE/CLAUDE.md" ]]; then
  FORGE_PATH=$(sed -n 's/^forge-path:[[:space:]]*//p' "$MEMBRANE/CLAUDE.md" 2>/dev/null | sed 's/[[:space:]]*$//' || true)
fi
if [[ -z "$FORGE_PATH" ]]; then
  echo "ERROR: forge-path not found in $MEMBRANE/CLAUDE.md. Run /forge to configure."
  exit 1
fi

FORGE_SKILLS="$FORGE_PATH/skills"
FORGE_SCRIPTS="$FORGE_PATH/scripts"
MEMBRANE_SKILLS="$MEMBRANE/skills"
MEMBRANE_SCRIPTS="$MEMBRANE/scripts"

# Runtime scripts to deploy to $MEMBRANE/scripts/ (manifest — explicit, no globbing).
# These are scripts the user's environment needs (hooks call them by absolute path),
# not forge-internal helpers. See WORKAROUNDS.md WA-001.
SCRIPTS_MANIFEST=(
  agent-token-warmup.sh
  agent-token-scheduler.sh
  user-agent-preflight.sh
)

if [[ ! -d "$FORGE_SKILLS" ]]; then
  echo "ERROR: Forge skills not found at $FORGE_SKILLS"
  exit 1
fi

mkdir -p "$MEMBRANE_SKILLS" "$MEMBRANE_SCRIPTS"

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

# --- Scripts mode: deploy runtime scripts to $MEMBRANE/scripts/ ---
deploy_scripts() {
  echo "## Deploying ${#SCRIPTS_MANIFEST[@]} runtime script(s) to $MEMBRANE_SCRIPTS"
  echo ""
  for s in "${SCRIPTS_MANIFEST[@]}"; do
    src="$FORGE_SCRIPTS/$s"
    dest="$MEMBRANE_SCRIPTS/$s"
    if [[ ! -f "$src" ]]; then
      echo "| $s | SKIP | Not found in forge |"
      continue
    fi
    cp "$src" "$dest"
    chmod +x "$dest"
    echo "| $s | DEPLOYED | $(stat -c %s "$src") bytes |"
  done
  echo ""
  echo "**Scripts deploy complete**"
}

verify_scripts() {
  echo "## Scripts Verification"
  echo ""
  errors=0
  for s in "${SCRIPTS_MANIFEST[@]}"; do
    src="$FORGE_SCRIPTS/$s"
    dest="$MEMBRANE_SCRIPTS/$s"
    if [[ ! -f "$src" ]]; then
      echo "| $s | MISSING-SOURCE | Not in forge — manifest stale |"
      errors=$((errors + 1))
      continue
    fi
    if [[ ! -f "$dest" ]]; then
      echo "| $s | MISSING | Not deployed |"
      errors=$((errors + 1))
      continue
    fi
    if ! diff -q "$src" "$dest" >/dev/null 2>&1; then
      echo "| $s | DIFFERS | Drift between forge and membrane |"
      errors=$((errors + 1))
    else
      echo "| $s | OK | In sync |"
    fi
  done
  echo ""
  if [[ $errors -eq 0 ]]; then
    echo "**All scripts verified OK**"
  else
    echo "**$errors script(s) need attention**"
  fi
  exit $errors
}

if [[ "${1:-}" == "--scripts" ]]; then
  deploy_scripts
  exit 0
fi

if [[ "${1:-}" == "--verify-scripts" ]]; then
  verify_scripts
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
  echo "Usage: cast-deploy.sh <skill-name> [...] | --all | --verify | --scripts | --verify-scripts"
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

# --all also deploys runtime scripts
if [[ "${1:-}" == "--all" ]]; then
  echo ""
  deploy_scripts
fi
