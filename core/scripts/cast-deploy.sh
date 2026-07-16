#!/usr/bin/env bash
# cast-deploy.sh — Generic Forge v2 membrane deploy.
#
# Layout:
#   $AGENTS_DIR/skills/<name>/       neutral cross-tool skill store (Open Agent Skills standard, comment-only)
#   $AGENTS_DIR/scripts/             canonical runtime scripts (none at present)
#   $MEMBRANE/skills/                REAL dir — Claude copies WITH injected `model:` frontmatter
#   $MEMBRANE/scripts/               symlink → $AGENTS_DIR/scripts/ (hooks call by absolute path)
#
# Why skills are NOT symlinked: $AGENTS_DIR/skills is read natively by other tools
# (Codex, Gemini) and must stay vendor-neutral. The Claude copy needs a real `model:`
# frontmatter field (translated from each skill's neutral `<!-- model: -->` hint) so
# Claude Code applies the per-skill model tier (haiku/sonnet/opus). Those two requirements conflict in
# one file, so $MEMBRANE/skills is a real directory holding Claude-flavoured copies.
# Scripts carry no frontmatter, so they stay symlinked — single source of truth where
# divergence isn't needed. The Claude copy is a deterministic function of the neutral
# one (neutral + injected line), regenerated on every cast, so there's no real drift.
#
# Usage:
#   cast-deploy.sh <skill-name> [<skill-name> ...]   deploy specific skills
#   cast-deploy.sh --all                              deploy all skills + scripts + symlinks
#   cast-deploy.sh --verify                           verify all skills match forge
#   cast-deploy.sh --scripts                          deploy runtime scripts only
#   cast-deploy.sh --verify-scripts                   verify runtime scripts match forge
#   cast-deploy.sh --rules                            deploy forge core/rules → membrane global rules file
#   cast-deploy.sh --verify-rules                     verify membrane rules block matches forge core/rules
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
FORGE_RULES="$FORGE_PATH/core/rules"
MEMBRANE_RULES_FILE="$MEMBRANE/CLAUDE.md"   # global rules file; AGENTS.md split will retarget this later

AGENTS_SKILLS="$AGENTS_DIR/skills"
AGENTS_SCRIPTS="$AGENTS_DIR/scripts"
MEMBRANE_SKILLS="$MEMBRANE/skills"
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

  # Skills are deployed to TWO targets that must differ:
  #   $AGENTS_SKILLS   — neutral cross-tool canonical store (comment-only, no frontmatter)
  #   $MEMBRANE_SKILLS — Claude discovery dir, real copies WITH injected `model:` frontmatter
  # Under Phase C, $MEMBRANE/skills was a directory symlink → $AGENTS_SKILLS, so the two
  # were the same files. Per-tool model frontmatter means they can no longer be: convert
  # $MEMBRANE/skills back to a real directory. (Scripts have no frontmatter, so they stay
  # symlinked — single source of truth preserved where divergence isn't needed.)
  if [[ -L "$MEMBRANE_SKILLS" ]]; then
    echo "  ↻ Unlinking $MEMBRANE_SKILLS (was symlink → $AGENTS_SKILLS); becomes a real Claude-flavoured dir"
    rm -f "$MEMBRANE_SKILLS"
  fi
  mkdir -p "$MEMBRANE_SKILLS"

  # Migrate scripts/ if it's a real directory (one-time conversion), then symlink.
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

  # Scripts stay symlinked (no per-tool divergence); skills do NOT (Claude copy differs).
  ln -sfn "$AGENTS_SCRIPTS" "$MEMBRANE_SCRIPTS_LINK"
}

# --- inject_model_frontmatter: translate the neutral `<!-- model: <tier> -->`
#     comment in a deployed skill into a real `model:` frontmatter field that
#     Claude Code honours. haiku/sonnet/opus are injected; `inherit` and
#     unhinted skills ride the session model untouched; any other tier value
#     WARNs to stderr and injects nothing (rides the session model). The neutral
#     comment stays in the body, so the source in core/ and the forge-build
#     distributable remain 100% vendor-neutral. Per the Open Agent Skills spec,
#     other tools (Codex/Gemini) ignore the unknown `model:` key — the value is
#     never interpreted, so this is invisible to non-Claude harnesses. ---
inject_model_frontmatter() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  local tier
  tier=$(grep -m1 -oE '<!--[[:space:]]*model:[[:space:]]*[a-zA-Z]+' "$file" 2>/dev/null | grep -oE '[a-zA-Z]+$' || true)
  case "$tier" in
    ""|haiku|sonnet|opus|inherit) ;;
    *) echo "WARN: unknown model tier '$tier' in $file — no frontmatter injected; skill rides the session model" >&2 ;;
  esac
  awk -v tier="$tier" '
    BEGIN { n = 0 }
    /^---[[:space:]]*$/ {
      n++
      if (n == 2 && (tier == "haiku" || tier == "sonnet" || tier == "opus")) print "model: " tier
      print
      next
    }
    (n == 1 && /^model:[[:space:]]/) { next }   # drop any stale injected line inside frontmatter
    { print }
  ' "$file" > "$file.tmp"
  mv "$file.tmp" "$file"
}

# --- skill_diff: compare a forge source skill dir against its deployed copy,
#     ignoring the Claude-only `model:` frontmatter line injected above. Echoes
#     the diff (empty == equivalent). Keeps --verify from flagging every skill. ---
skill_diff() {
  local src="$1" dst="$2"
  diff -rq --strip-trailing-cr --exclude=SKILL.md "$src" "$dst" 2>/dev/null || true
  if [[ -f "$src/SKILL.md" && -f "$dst/SKILL.md" ]]; then
    diff --strip-trailing-cr \
      <(grep -v '^model:[[:space:]]' "$src/SKILL.md" 2>/dev/null) \
      <(grep -v '^model:[[:space:]]' "$dst/SKILL.md" 2>/dev/null) 2>/dev/null || true
  fi
}

# --- Rules deploy: write forge's core/rules/ into the membrane's global rules
#     file as a single marker-delimited managed block. Idempotent — regenerated
#     every cast, so editing a rule in forge core/rules/ + re-casting updates the
#     block in place with no duplication. Personal content outside the markers is
#     never touched (same contract as the forge-path: line /forge manages). This
#     is how a HARD RULE authored in forge reaches every teammate's membrane. ---
RULES_START='<!-- FORGE-RULES:START — managed by /forge; this block is regenerated from forge core/rules/ on every cast. Edit the forge source, not here. -->'
RULES_END='<!-- FORGE-RULES:END -->'

build_rules_block() {
  # Emits the full managed block (markers included) to stdout.
  echo "$RULES_START"
  echo ""
  echo "# Forge-Managed HARD RULES"
  echo ""
  echo "_Deployed from the forge's \`core/rules/\` on each \`/forge\` cast. To change these, edit the forge source and re-run \`/forge\` — edits between the markers are overwritten._"
  echo ""
  for f in "$FORGE_RULES"/*.md; do
    [[ -f "$f" ]] || continue
    cat "$f"
    echo ""
  done
  echo "$RULES_END"
}

deploy_rules() {
  echo "## Deploying forge core/rules → $MEMBRANE_RULES_FILE"
  echo ""
  if [[ ! -d "$FORGE_RULES" ]]; then
    echo "| rules | SKIP | $FORGE_RULES not found |"
    return 0
  fi

  local block tmp
  block=$(mktemp)
  build_rules_block > "$block"

  if [[ ! -f "$MEMBRANE_RULES_FILE" ]]; then
    cat "$block" > "$MEMBRANE_RULES_FILE"
    echo "| rules | CREATED | wrote managed block to new $MEMBRANE_RULES_FILE |"
  elif grep -qF 'FORGE-RULES:START' "$MEMBRANE_RULES_FILE"; then
    tmp=$(mktemp)
    awk -v blockfile="$block" '
      index($0, "FORGE-RULES:START") {
        while ((getline line < blockfile) > 0) print line
        close(blockfile)
        skip = 1
        next
      }
      index($0, "FORGE-RULES:END") { skip = 0; next }
      skip != 1 { print }
    ' "$MEMBRANE_RULES_FILE" > "$tmp"
    mv "$tmp" "$MEMBRANE_RULES_FILE"
    echo "| rules | UPDATED | refreshed managed block in place |"
  else
    printf '\n' >> "$MEMBRANE_RULES_FILE"
    cat "$block" >> "$MEMBRANE_RULES_FILE"
    echo "| rules | DEPLOYED | appended managed block (personal content preserved) |"
  fi
  rm -f "$block"
  echo ""
  echo "**Rules deploy complete**"
}

verify_rules() {
  echo "## Rules Verification"
  echo ""
  if [[ ! -f "$MEMBRANE_RULES_FILE" ]] || ! grep -qF 'FORGE-RULES:START' "$MEMBRANE_RULES_FILE"; then
    echo "| rules | MISSING | no managed block in $MEMBRANE_RULES_FILE — run cast-deploy.sh --rules |"
    return 1
  fi
  local block current
  block=$(mktemp); current=$(mktemp)
  build_rules_block > "$block"
  awk 'index($0,"FORGE-RULES:START"){f=1} f{print} index($0,"FORGE-RULES:END"){f=0}' "$MEMBRANE_RULES_FILE" > "$current"
  if diff -q --strip-trailing-cr "$block" "$current" >/dev/null 2>&1; then
    echo "| rules | OK | membrane block matches forge core/rules/ |"
    rm -f "$block" "$current"
    return 0
  else
    echo "| rules | DRIFT | membrane block differs from forge core/rules/ — run cast-deploy.sh --rules |"
    rm -f "$block" "$current"
    return 1
  fi
}

# --- Verify mode: check all deployed skills for correctness ---
if [[ "${1:-}" == "--verify" ]]; then
  echo "## Deployment Verification"
  echo ""
  errors=0
  # Skills are no longer symlinked — $MEMBRANE_SKILLS must be a REAL directory now.
  if [[ -L "$MEMBRANE_SKILLS" ]]; then
    echo "| layout | STALE-SYMLINK | $MEMBRANE_SKILLS is still a symlink — redeploy to convert to a real dir |"
    errors=$((errors + 1))
  elif [[ ! -d "$MEMBRANE_SKILLS" ]]; then
    echo "| layout | MISSING | $MEMBRANE_SKILLS does not exist |"
    errors=$((errors + 1))
  fi
  for skill_dir in "$FORGE_SKILLS"/*/; do
    skill=$(basename "$skill_dir")
    [[ ! -f "$skill_dir/SKILL.md" ]] && continue
    neutral="$AGENTS_SKILLS/$skill"   # cross-tool copy — must stay comment-only
    claude="$MEMBRANE_SKILLS/$skill"  # Claude copy — carries injected frontmatter
    if [[ ! -d "$claude" || ! -d "$neutral" ]]; then
      echo "| $skill | MISSING | Not deployed to both stores |"
      errors=$((errors + 1))
      continue
    fi
    if [[ -d "$claude/$skill" || -d "$neutral/$skill" ]]; then
      echo "| $skill | NESTED BUG | Found $skill/$skill/ — redeploy needed |"
      errors=$((errors + 1))
      continue
    fi
    # The Claude copy must match forge modulo the injected model: line.
    diff_output=$(skill_diff "$skill_dir" "$claude")
    # If the neutral hint names an injectable tier, the Claude copy must carry the matching frontmatter.
    hint_tier=$(grep -m1 -oE '<!--[[:space:]]*model:[[:space:]]*[a-zA-Z]+' "$neutral/SKILL.md" 2>/dev/null | grep -oE '[a-zA-Z]+$' || true)
    # The neutral copy must be byte-identical to forge — NO frontmatter leak into the cross-tool store.
    if grep -q '^model:[[:space:]]' "$neutral/SKILL.md" 2>/dev/null; then
      echo "| $skill | LEAK | model: frontmatter found in neutral cross-tool store |"
      errors=$((errors + 1))
    elif [[ -n "$diff_output" ]]; then
      echo "| $skill | DIFFERS | $diff_output |"
      errors=$((errors + 1))
    elif [[ "$hint_tier" == "haiku" || "$hint_tier" == "sonnet" || "$hint_tier" == "opus" ]] && ! grep -q "^model:[[:space:]]*${hint_tier}[[:space:]]*$" "$claude/SKILL.md" 2>/dev/null; then
      echo "| $skill | NO-INJECT | hint says $hint_tier but Claude copy lacks model: $hint_tier frontmatter — redeploy |"
      errors=$((errors + 1))
    else
      echo "| $skill | OK | In sync |"
    fi
  done
  echo ""
  verify_rules || errors=$((errors + 1))
  echo ""
  if [[ $errors -eq 0 ]]; then
    echo "**All skills + rules verified OK**"
  else
    echo "**$errors item(s) need attention**"
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

if [[ "${1:-}" == "--rules" ]]; then
  deploy_rules
  exit 0
fi

if [[ "${1:-}" == "--verify-rules" ]]; then
  verify_rules
  exit $?
fi

if [[ "${1:-}" == "--bootstrap" ]]; then
  bootstrap_layout
  echo "Bootstrap complete."
  echo "  Neutral cross-tool skill store: $AGENTS_SKILLS (real dir)"
  echo "  Claude skill dir:               $MEMBRANE_SKILLS (real dir, frontmatter-injected)"
  echo "  Scripts symlink:                $MEMBRANE_SCRIPTS_LINK → $AGENTS_SCRIPTS"
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
  echo "Usage: cast-deploy.sh <skill-name> [...] | --all | --verify | --scripts | --verify-scripts | --rules | --verify-rules | --bootstrap" >&2
  exit 1
fi

# Always ensure layout is bootstrapped before deploying
bootstrap_layout

# --- Deploy each skill to BOTH stores ---
#   $AGENTS_SKILLS   neutral cross-tool copy (comment-only, untouched)
#   $MEMBRANE_SKILLS Claude copy (same content + injected `model:` frontmatter)
echo "## Deploying ${#skills[@]} skill(s): neutral → $AGENTS_SKILLS, Claude → $MEMBRANE_SKILLS"
echo ""
for skill in "${skills[@]}"; do
  src="$FORGE_SKILLS/$skill"
  neutral="$AGENTS_SKILLS/$skill"
  claude="$MEMBRANE_SKILLS/$skill"

  if [[ ! -d "$src" ]]; then
    echo "| $skill | SKIP | Not found in forge |"
    continue
  fi

  # Neutral cross-tool copy — NEVER injected, byte-identical to forge source.
  rm -rf "$neutral"
  cp -r "$src" "$neutral"

  # Claude discovery copy — same content, then translate the model hint into real frontmatter.
  rm -rf "$claude"
  cp -r "$src" "$claude"

  if [[ -d "$neutral/$skill" || -d "$claude/$skill" ]]; then
    echo "| $skill | ERROR | Nesting bug detected after copy! |" >&2
    exit 1
  fi

  inject_model_frontmatter "$claude/SKILL.md"

  echo "| $skill | DEPLOYED | $(find "$src" -type f | wc -l) file(s) → both stores |"
done
echo ""
echo "**Deploy complete**"

# --all also deploys runtime scripts and the forge rules block
if [[ "${1:-}" == "--all" ]]; then
  echo ""
  deploy_scripts
  echo ""
  deploy_rules
fi
