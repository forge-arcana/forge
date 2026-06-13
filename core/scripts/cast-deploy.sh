#!/usr/bin/env bash
# cast-deploy.sh — Generic Forge v2 membrane deploy.
#
# Layout:
#   $AGENTS_DIR/skills/<name>/       canonical skill store (Open Agent Skills standard)
#   $AGENTS_DIR/scripts/             canonical runtime scripts (none at present)
#   $MEMBRANE/skills/                symlink → $AGENTS_DIR/skills/  (Claude Code discovers via this)
#   $MEMBRANE/scripts/               symlink → $AGENTS_DIR/scripts/ (hooks call by absolute path)
#
# Why two paths: $AGENTS_DIR is the cross-tool canonical store (Codex, Gemini,
# Bob, etc. read it natively). $MEMBRANE is the Claude-Code-specific config dir.
# A directory symlink from $MEMBRANE/skills/ to $AGENTS_DIR/skills/ gives Claude
# Code discoverability without duplicating content. Single source of truth.
#
# Usage:
#   cast-deploy.sh <skill-name> [<skill-name> ...]   deploy specific skills
#   cast-deploy.sh --all                              deploy all skills + scripts + symlinks
#   cast-deploy.sh --verify                           verify all skills match forge
#   cast-deploy.sh --scripts                          deploy runtime scripts only
#   cast-deploy.sh --verify-scripts                   verify runtime scripts match forge
#   cast-deploy.sh --bootstrap                        create dirs + symlinks (no skill deploy)
#
# Environment overrides:
#   FORGE_PATH       path to forge repo (canonical) — falls back to CLAUDE.md forge-path: line
#   FORGE_MEMBRANE   harness config dir (default $HOME/.claude)
#   FORGE_AGENTS_DIR canonical Open Agent Skills dir (default $HOME/.agents)

set -euo pipefail

# --- Resolve paths ---
MEMBRANE="${FORGE_MEMBRANE:-$HOME/.claude}"
AGENTS_DIR="${FORGE_AGENTS_DIR:-$HOME/.agents}"

FORGE_PATH="${FORGE_PATH:-}"
if [[ -z "$FORGE_PATH" && -f "$MEMBRANE/CLAUDE.md" ]]; then
  FORGE_PATH=$(sed -n 's/^forge-path:[[:space:]]*//p' "$MEMBRANE/CLAUDE.md" 2>/dev/null | sed 's/[[:space:]]*$//' || true)
fi
if [[ -z "$FORGE_PATH" ]]; then
  echo "ERROR: forge path not configured. Set FORGE_PATH env var, or add 'forge-path: /path/to/forge' to $MEMBRANE/CLAUDE.md." >&2
  exit 1
fi

FORGE_SKILLS="$FORGE_PATH/core/skills"
FORGE_SCRIPTS="$FORGE_PATH/claude-helpers/scripts"

AGENTS_SKILLS="$AGENTS_DIR/skills"
AGENTS_SCRIPTS="$AGENTS_DIR/scripts"
MEMBRANE_SKILLS_LINK="$MEMBRANE/skills"
MEMBRANE_SCRIPTS_LINK="$MEMBRANE/scripts"

# No runtime scripts are deployed to the membrane at present. The WA-001 OAuth-race
# token scripts that previously lived here were retired once the upstream bug was
# fixed (Claude Code v2.1.136). Any membrane that still has the old copies should
# delete them manually — see CLAUDE.md's WA-001 retirement note.
SCRIPTS_MANIFEST=()

if [[ ! -d "$FORGE_SKILLS" ]]; then
  echo "ERROR: Forge skills not found at $FORGE_SKILLS" >&2
  exit 1
fi

# --- bootstrap_layout: idempotently create $AGENTS_DIR + symlinks ---
bootstrap_layout() {
  mkdir -p "$AGENTS_SKILLS" "$AGENTS_SCRIPTS" "$MEMBRANE"

  # Migrate existing $MEMBRANE/skills/ if it's a real directory (one-time conversion).
  # This is the path most users will hit — pre-pivot membrane has $MEMBRANE/skills/
  # as a regular dir; we move its contents into $AGENTS_SKILLS, then symlink.
  if [[ -d "$MEMBRANE_SKILLS_LINK" && ! -L "$MEMBRANE_SKILLS_LINK" ]]; then
    echo "  ↻ Migrating existing $MEMBRANE_SKILLS_LINK → $AGENTS_SKILLS"
    # rsync would be ideal but may not be present; use cp -r per-item to handle existing files in $AGENTS_SKILLS
    for entry in "$MEMBRANE_SKILLS_LINK"/*; do
      [[ -e "$entry" ]] || continue
      base=$(basename "$entry")
      if [[ -e "$AGENTS_SKILLS/$base" ]]; then
        # Already in canonical store — drop the membrane copy
        rm -rf "$entry"
      else
        mv "$entry" "$AGENTS_SKILLS/"
      fi
    done
    rmdir "$MEMBRANE_SKILLS_LINK" 2>/dev/null || rm -rf "$MEMBRANE_SKILLS_LINK"
  fi

  # Same migration for scripts/
  if [[ -d "$MEMBRANE_SCRIPTS_LINK" && ! -L "$MEMBRANE_SCRIPTS_LINK" ]]; then
    echo "  ↻ Migrating existing $MEMBRANE_SCRIPTS_LINK → $AGENTS_SCRIPTS"
    for entry in "$MEMBRANE_SCRIPTS_LINK"/*; do
      [[ -e "$entry" ]] || continue
      base=$(basename "$entry")
      if [[ -e "$AGENTS_SCRIPTS/$base" ]]; then
        rm -rf "$entry"
      else
        mv "$entry" "$AGENTS_SCRIPTS/"
      fi
    done
    rmdir "$MEMBRANE_SCRIPTS_LINK" 2>/dev/null || rm -rf "$MEMBRANE_SCRIPTS_LINK"
  fi

  # Create the symlinks (idempotent — ln -sfn replaces existing symlinks)
  ln -sfn "$AGENTS_SKILLS" "$MEMBRANE_SKILLS_LINK"
  ln -sfn "$AGENTS_SCRIPTS" "$MEMBRANE_SCRIPTS_LINK"
}

# --- Verify mode: check all deployed skills for correctness ---
if [[ "${1:-}" == "--verify" ]]; then
  echo "## Deployment Verification"
  echo ""
  errors=0
  # Check the symlink shape first
  if [[ ! -L "$MEMBRANE_SKILLS_LINK" ]]; then
    echo "| symlink | MISSING | $MEMBRANE_SKILLS_LINK is not a symlink |"
    errors=$((errors + 1))
  elif [[ "$(readlink -f "$MEMBRANE_SKILLS_LINK")" != "$(readlink -f "$AGENTS_SKILLS" 2>/dev/null || echo "$AGENTS_SKILLS")" ]]; then
    echo "| symlink | WRONG-TARGET | $MEMBRANE_SKILLS_LINK → $(readlink "$MEMBRANE_SKILLS_LINK") (expected $AGENTS_SKILLS) |"
    errors=$((errors + 1))
  fi
  for skill_dir in "$FORGE_SKILLS"/*/; do
    skill=$(basename "$skill_dir")
    [[ ! -f "$skill_dir/SKILL.md" ]] && continue
    dest="$AGENTS_SKILLS/$skill"
    if [[ ! -d "$dest" ]]; then
      echo "| $skill | MISSING | Not deployed |"
      errors=$((errors + 1))
      continue
    fi
    if [[ -d "$dest/$skill" ]]; then
      echo "| $skill | NESTED BUG | Found $skill/$skill/ — redeploy needed |"
      errors=$((errors + 1))
      continue
    fi
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

# --- Scripts deploy/verify ---
deploy_scripts() {
  echo "## Deploying ${#SCRIPTS_MANIFEST[@]} runtime script(s) to $AGENTS_SCRIPTS"
  echo ""
  for s in "${SCRIPTS_MANIFEST[@]}"; do
    src="$FORGE_SCRIPTS/$s"
    dest="$AGENTS_SCRIPTS/$s"
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
    dest="$AGENTS_SCRIPTS/$s"
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

if [[ "${1:-}" == "--bootstrap" ]]; then
  bootstrap_layout
  echo "Bootstrap complete."
  echo "  Canonical store: $AGENTS_DIR"
  echo "  Membrane symlinks: $MEMBRANE_SKILLS_LINK → $AGENTS_SKILLS"
  echo "                     $MEMBRANE_SCRIPTS_LINK → $AGENTS_SCRIPTS"
  exit 0
fi

if [[ "${1:-}" == "--scripts" ]]; then
  bootstrap_layout
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
  echo "Usage: cast-deploy.sh <skill-name> [...] | --all | --verify | --scripts | --verify-scripts | --bootstrap" >&2
  exit 1
fi

# Always ensure layout is bootstrapped before deploying
bootstrap_layout

# --- Deploy each skill ---
echo "## Deploying ${#skills[@]} skill(s) to $AGENTS_SKILLS"
echo ""
for skill in "${skills[@]}"; do
  src="$FORGE_SKILLS/$skill"
  dest="$AGENTS_SKILLS/$skill"

  if [[ ! -d "$src" ]]; then
    echo "| $skill | SKIP | Not found in forge |"
    continue
  fi

  if [[ -d "$dest" ]]; then
    rm -rf "$dest"
  fi

  cp -r "$src" "$dest"

  if [[ -d "$dest/$skill" ]]; then
    echo "| $skill | ERROR | Nesting bug detected after copy! |" >&2
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
