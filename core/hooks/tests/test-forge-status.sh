#!/usr/bin/env bash
#
# Tests forge-status.sh deployed-only skill classification and its routing
# through forge-plan.sh --stdin. A membrane skill with no forge core/skills/<name>/
# is FORGE-REMOVED only when it existed in forge at the last-cast baseline (and
# is not in FORGE_SKILL_RETIRED); never-tracked and symlinked ones get no row
# (never-tracked are counted as local-only); no baseline gives no rows.
# Fully sandboxed: throwaway git repo as forge, temp HOME and membrane, isolated
# git config. The real forge and membrane are never touched.
# Run:  bash core/hooks/tests/test-forge-status.sh      (non-zero on failure)

HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.."
REAL_FORGE="$(readlink -f "$HERE/../..")"
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
export HOME="$TMPD/home"
export GIT_CONFIG_GLOBAL="$TMPD/gitconfig"
export GIT_CONFIG_SYSTEM=/dev/null
export FORGE_PATH="$TMPD/forge"
export FORGE_MEMBRANE="$TMPD/home/.claude"
export FORGE_AGENTS_DIR="$TMPD/home/.agents"
mkdir -p "$HOME" "$FORGE_MEMBRANE/skills"
git config --global user.name "Fixture"
git config --global user.email "fixture@example.invalid"
git config --global init.defaultBranch main

FAILS=0
check() { if [ "$2" = 0 ]; then echo "PASS  $1"; else echo "FAIL  $1  (${3:-})"; FAILS=$((FAILS + 1)); fi; }
has() { grep -qF -- "$2" <<<"$1"; }
hasrow() { grep -qE -- "$2" <<<"$1"; }

RETIRED=$(FORGE_PATH="$REAL_FORGE" bash "$REAL_FORGE/core/scripts/cast-deploy.sh" --list-retired-skills | head -1)
[ -n "$RETIRED" ] || { echo "FAIL  no retired skill name available"; exit 1; }

mkdir -p "$FORGE_PATH/core/scripts" "$FORGE_PATH/learnings"
cp "$REAL_FORGE/core/scripts/cast-deploy.sh" "$FORGE_PATH/core/scripts/"
mkdir_skill() { mkdir -p "$1/$2"; printf '# %s\n' "$2" > "$1/$2/SKILL.md"; }
for s in keep gone "$RETIRED"; do mkdir_skill "$FORGE_PATH/core/skills" "$s"; done
git -C "$FORGE_PATH" init -q
git -C "$FORGE_PATH" add -A
git -C "$FORGE_PATH" commit -q -m "baseline"
BASE=$(git -C "$FORGE_PATH" rev-parse HEAD)
git -C "$FORGE_PATH" rm -rq "core/skills/gone" "core/skills/$RETIRED"
git -C "$FORGE_PATH" commit -q -m "forge deletes two skills"
mkdir_skill "$FORGE_PATH/core/skills" fresh
git -C "$FORGE_PATH" add -A
git -C "$FORGE_PATH" commit -q -m "forge adds a skill"

# Membrane: keep (identical), gone + retired (deleted in forge), localonly (never
# in forge), linked (symlink to a dir elsewhere). fresh is absent -> ADDED.
S="$FORGE_MEMBRANE/skills"
cp -r "$FORGE_PATH/core/skills/keep" "$S/keep"
mkdir_skill "$S" gone
mkdir_skill "$S" "$RETIRED"
mkdir_skill "$S" localonly
mkdir_skill "$TMPD/elsewhere" linked
ln -s "$TMPD/elsewhere/linked" "$S/linked"
# A symlinked skill whose name WAS tracked at the baseline is still personal.
mkdir_skill "$TMPD/elsewhere" gonelink

run_status() { bash "$REAL_FORGE/core/scripts/forge-status.sh" --fetch 2>&1; }
run_plan() { printf '%s\n' "$1" | bash "$REAL_FORGE/core/scripts/forge-plan.sh" --stdin 2>&1; }

# --- with baseline ---
printf '{"lastCastCommit":"%s"}\n' "$BASE" > "$FORGE_MEMBRANE/.last-cast.json"
OUT=$(run_status)
has "$OUT" "| gone | FORGE-REMOVED | incoming (delete deployed copy) |"; check "(a) deleted-after-baseline -> FORGE-REMOVED row" $? "$OUT"
! has "$OUT" "| localonly |"; check "(b) never-tracked skill has no row" $?
has "$OUT" "Local-only skills (not tracked by forge): 1"; check "(b) local-only count is 1 (symlink and retired not counted)" $? "$(grep -i 'local-only' <<<"$OUT")"
! has "$OUT" "| linked |"; check "(c) symlinked skill has no row" $?
ln -s "$TMPD/elsewhere/gonelink" "$S/gonelink"
OUT2=$(run_status)
! has "$OUT2" "| gonelink |"; check "(c) symlinked skill that was once tracked has no row" $?
rm "$S/gonelink"
! has "$OUT" "| $RETIRED |"; check "(d) retired-list name has no row" $?
has "$OUT" "| keep | IDENTICAL |"; check "(f) IDENTICAL still reported" $?
has "$OUT" "| fresh | ADDED | cast needed |"; check "(f) ADDED still reported" $?
has "$OUT" "**Summary**: 1 identical, 2 incoming (1 FORGE-REMOVED), 0 outgoing"; check "summary counts FORGE-REMOVED as incoming" $? "$(grep Summary <<<"$OUT")"
has "$OUT" "| Skills | 2 incoming, 0 outgoing | Run /forge |"; check "anything-to-do total counts FORGE-REMOVED" $? "$(grep '| Skills' <<<"$OUT")"
! hasrow "$OUT" '\| REMOVED \|'; check "old REMOVED status is gone" $?

# --- plan routing ---
PLAN=$(run_plan "$OUT")
INC=$(sed -n '/INCOMING/,/OUTGOING/p' <<<"$PLAN")
has "$INC" "gone"; check "plan: FORGE-REMOVED row lands under INCOMING" $? "$PLAN"
has "$INC" "Removed from forge; apply deletes the deployed copy"; check "plan: FORGE-REMOVED essence line" $?
! has "$PLAN" "localonly"; check "plan: local-only skill never appears" $?
! has "$PLAN" "linked"; check "plan: symlinked skill never appears" $?
! has "$PLAN" "$RETIRED"; check "plan: retired skill never appears" $?
# retired filter still applies to a FORGE-REMOVED row fed in directly
FAKE=$(printf '%s\n' "$OUT" | sed "s/^| gone | FORGE-REMOVED/| $RETIRED | FORGE-REMOVED/")
PLAN2=$(run_plan "$FAKE")
! has "$PLAN2" "$RETIRED"; check "plan: retired filter applies to FORGE-REMOVED" $?

# --- three-way classification (separate fixture) ---
export FORGE_PATH="$TMPD/forge2"
export FORGE_MEMBRANE="$TMPD/home2/.claude"
S2="$FORGE_MEMBRANE/skills"
mkdir -p "$FORGE_PATH/core/scripts" "$FORGE_PATH/learnings" "$S2"
cp "$REAL_FORGE/core/scripts/cast-deploy.sh" "$FORGE_PATH/core/scripts/"
for s in upd conf memedit same forge purge; do mkdir_skill "$FORGE_PATH/core/skills" "$s"; done
git -C "$FORGE_PATH" init -q
git -C "$FORGE_PATH" add -A
git -C "$FORGE_PATH" commit -q -m "baseline"
BASE2=$(git -C "$FORGE_PATH" rev-parse HEAD)
for s in upd conf forge purge; do printf 'forge edit\n' >> "$FORGE_PATH/core/skills/$s/SKILL.md"; done
git -C "$FORGE_PATH" commit -qam "forge edits four skills"
for s in upd conf memedit same forge purge; do cp -r "$FORGE_PATH/core/skills/$s" "$S2/$s"; done
git -C "$FORGE_PATH" show "$BASE2:core/skills/upd/SKILL.md" > "$S2/upd/SKILL.md"
git -C "$FORGE_PATH" show "$BASE2:core/skills/conf/SKILL.md" > "$S2/conf/SKILL.md"
printf 'membrane edit\n' >> "$S2/conf/SKILL.md"
git -C "$FORGE_PATH" show "$BASE2:core/skills/forge/SKILL.md" > "$S2/forge/SKILL.md"
printf 'membrane edit\n' >> "$S2/forge/SKILL.md"
git -C "$FORGE_PATH" show "$BASE2:core/skills/purge/SKILL.md" > "$S2/purge/SKILL.md"
printf 'membrane edit\n' >> "$S2/purge/SKILL.md"
printf 'membrane edit\n' >> "$S2/memedit/SKILL.md"
printf '{"lastCastCommit":"%s"}\n' "$BASE2" > "$FORGE_MEMBRANE/.last-cast.json"
O4=$(run_status)
has "$O4" "| upd | FORGE-UPDATED | incoming |"; check "(g) forge changed, membrane unchanged -> FORGE-UPDATED" $? "$O4"
has "$O4" "| conf | CONFLICT | both changed since last cast |"; check "(h) both sides changed -> CONFLICT" $?
has "$O4" "| memedit | DEPLOYED-DIFFERS | outgoing |"; check "(i) membrane edited, forge unchanged -> DEPLOYED-DIFFERS" $?
has "$O4" "| forge | CONFLICT | both changed since last cast |"; check "(j) protected forge, both changed -> CONFLICT" $?
has "$O4" "| purge | CONFLICT | both changed since last cast |"; check "(j) protected purge, both changed -> CONFLICT" $?
has "$O4" "| same | IDENTICAL |"; check "unchanged skill IDENTICAL" $?
P4=$(run_plan "$O4")
CONFSEC=$(sed -n '/CONFLICTS/,$p' <<<"$P4")
has "$CONFSEC" "conf"; check "plan: CONFLICT row lands under CONFLICTS" $? "$P4"
has "$CONFSEC" "forge"; check "plan: protected forge CONFLICT lands under CONFLICTS" $?
has "$CONFSEC" "purge"; check "plan: protected purge CONFLICT lands under CONFLICTS" $?
# archive failure must fail safe: unreachable baseline path -> CONFLICT, never FORGE-UPDATED
GIT_ARCHIVE_BROKEN=$(mktemp -d)
printf '#!/bin/sh\n[ "$3" = archive ] && exit 1\nexec %s "$@"\n' "$(command -v git)" > "$GIT_ARCHIVE_BROKEN/git"
chmod +x "$GIT_ARCHIVE_BROKEN/git"
O5=$(PATH="$GIT_ARCHIVE_BROKEN:$PATH" run_status)
has "$O5" "| upd | CONFLICT | both changed since last cast |"; check "archive failure fails safe -> CONFLICT" $? "$(grep '| upd' <<<"$O5")"

export FORGE_PATH="$TMPD/forge"
export FORGE_MEMBRANE="$TMPD/home/.claude"
# --- no baseline ---
rm "$FORGE_MEMBRANE/.last-cast.json"
OUT3=$(run_status)
! has "$OUT3" "FORGE-REMOVED"; check "(e) no baseline: no FORGE-REMOVED rows" $?
has "$OUT3" "Local-only skills (not tracked by forge): 3"; check "(e) no baseline: local-only count only (gone, retired, localonly)" $? "$(grep -i 'local-only' <<<"$OUT3")"
has "$OUT3" "| keep | IDENTICAL |"; check "(e) no baseline: IDENTICAL still works" $?

echo
if [ "$FAILS" = 0 ]; then echo "ALL PASS"; else echo "$FAILS FAILED"; exit 1; fi
