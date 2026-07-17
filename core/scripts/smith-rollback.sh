#!/usr/bin/env bash
# smith-rollback.sh — Deterministic half of /smith's Rollback (steps 1-3)
#
# Resolves the target checkpoint SHA from the ledger, reverts everything since
# it WITHOUT committing, and restores the ledger snapshot when one exists.
# Step 4 (re-plan forward) is judgment work and stays with the smith.
#
# USAGE:
#   smith-rollback.sh <project-path> <target>
#     <target> — a phase-gate name recorded in phaseGates (e.g. "foundation"),
#                or a heat number (uses that heat's checkpointSha).
#
# Behavior:
#   - Refuses to run on a dirty working tree (rollback must start from a
#     committed state — commit or stash first).
#   - `git revert --no-commit <sha>..HEAD` — the working tree holds the
#     reverted state, uncommitted, for the smith to inspect and re-plan.
#   - Gate targets: restores memory/smith-ledger.json from
#     memory/smith-ledger-checkpoint-<gate>.json (the pre-restore ledger is
#     saved to memory/smith-ledger.pre-rollback.json). Heat targets have no
#     snapshot — the ledger is left for the smith to update.
#
# Requires: jq, git. bash >=3.2.
set -euo pipefail

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required." >&2; exit 1; }

PROJECT="${1:?usage: smith-rollback.sh <project-path> <gate-name|heat-number>}"
TARGET="${2:?usage: smith-rollback.sh <project-path> <gate-name|heat-number>}"

LEDGER="$PROJECT/memory/smith-ledger.json"
[[ -f "$LEDGER" ]] || { echo "ERROR: no ledger at $LEDGER" >&2; exit 1; }
jq -e . "$LEDGER" >/dev/null 2>&1 || { echo "ERROR: $LEDGER is not valid JSON." >&2; exit 1; }

# --- Resolve target SHA ---
KIND="gate"
SHA=$(jq -r --arg g "$TARGET" '.phaseGates[$g].checkpointSha // empty' "$LEDGER")
if [[ -z "$SHA" && "$TARGET" =~ ^[0-9]+$ ]]; then
  KIND="heat"
  SHA=$(jq -r --argjson n "$TARGET" \
    '[.plan.units[].heats[] | select(.number == $n) | .checkpointSha] | first // empty' "$LEDGER")
fi
[[ -n "$SHA" ]] || { echo "ERROR: no checkpointSha recorded for '$TARGET' (gate name or heat number)." >&2; exit 1; }
git -C "$PROJECT" cat-file -e "$SHA^{commit}" 2>/dev/null \
  || { echo "ERROR: recorded SHA $SHA is not a commit in this repo." >&2; exit 1; }

# --- Safety: clean tree required ---
# Untracked files (often memory/ itself) are untouched by revert — ignore them.
if [[ -n "$(git -C "$PROJECT" status --porcelain --untracked-files=no)" ]]; then
  echo "ERROR: working tree has uncommitted tracked changes — commit or stash before rollback." >&2
  exit 1
fi

# --- Revert range ---
COUNT=$(git -C "$PROJECT" rev-list --count "$SHA..HEAD")
if [[ "$COUNT" -eq 0 ]]; then
  echo "NOTHING-TO-REVERT $KIND $TARGET already at $SHA"
else
  git -C "$PROJECT" revert --no-commit "$SHA..HEAD"
  echo "REVERTED $COUNT commit(s) since $KIND '$TARGET' ($SHA) — uncommitted, inspect then re-plan"
fi

# --- Ledger snapshot restore (gate targets only) ---
if [[ "$KIND" == "gate" ]]; then
  SNAP="$PROJECT/memory/smith-ledger-checkpoint-$TARGET.json"
  if [[ -f "$SNAP" ]]; then
    cp "$LEDGER" "$PROJECT/memory/smith-ledger.pre-rollback.json"
    cp "$SNAP" "$LEDGER"
    echo "LEDGER-RESTORED from $SNAP (previous ledger: memory/smith-ledger.pre-rollback.json)"
  else
    echo "WARN: no snapshot at $SNAP — ledger left as-is; update it during re-plan." >&2
  fi
else
  echo "NOTE: heat targets have no ledger snapshot — update the ledger during re-plan."
fi
