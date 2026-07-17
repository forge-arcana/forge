#!/usr/bin/env bash
# smith-checkpoint.sh — Deterministic ledger stamping for /smith (Step 2f + Session Resume)
#
# Freehand LLM edits of smith-ledger.json are the main ledger-corruption risk;
# this script owns the mechanical stamps. Richer fields (evaluations, decisions)
# remain LLM-authored via ordinary edits.
#
# Ledger contract: core/skills/smith/ledger-schema.md
#
# USAGE (one operation per call):
#   smith-checkpoint.sh <project-path> --heat <N>
#       Stamp heat N's checkpointSha (= git rev-parse HEAD) + completedAt,
#       and bump top-level lastUpdated.
#   smith-checkpoint.sh <project-path> --gate <name>
#       Stamp phaseGates.<name>.checkpointSha (= HEAD), bump lastUpdated,
#       and snapshot the ledger to memory/smith-ledger-checkpoint-<name>.json.
#   smith-checkpoint.sh <project-path> --hash-check <blueprint|pattern|workspec>
#       Recompute sha256 of the file the ledger records for <kind> and compare:
#       prints "UNCHANGED <kind> <hash>" (exit 0) or
#              "CHANGED <kind> recorded=<h> actual=<h>" (exit 1).
#
# Requires: jq, git, sha256sum. bash >=3.2.
set -euo pipefail

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required." >&2; exit 1; }

PROJECT="${1:?usage: smith-checkpoint.sh <project-path> --heat N | --gate name | --hash-check kind}"
OP="${2:?missing operation (--heat | --gate | --hash-check)}"
ARG="${3:?missing operation argument}"

LEDGER="$PROJECT/memory/smith-ledger.json"
[[ -f "$LEDGER" ]] || { echo "ERROR: no ledger at $LEDGER" >&2; exit 1; }
jq -e . "$LEDGER" >/dev/null 2>&1 || { echo "ERROR: $LEDGER is not valid JSON — restore from the latest memory/smith-ledger-checkpoint-*.json" >&2; exit 1; }

stamp() { # jq filter → atomic in-place ledger rewrite
  local TMP
  TMP=$(mktemp "${TMPDIR:-/tmp}/smith-ledger.XXXXXX")
  jq "$1" "${@:2}" "$LEDGER" > "$TMP"
  jq -e . "$TMP" >/dev/null
  mv "$TMP" "$LEDGER"
}

case "$OP" in
  --heat)
    SHA=$(git -C "$PROJECT" rev-parse HEAD)
    jq -e --argjson n "$ARG" '[.plan.units[].heats[] | select(.number == $n)] | length == 1' "$LEDGER" >/dev/null \
      || { echo "ERROR: heat $ARG not found (or not unique) in ledger." >&2; exit 1; }
    stamp '
      (.plan.units[].heats[] | select(.number == $n)) |= (
        .checkpointSha = $sha | .completedAt = (now | todateiso8601)
      )
      | .lastUpdated = (now | todateiso8601)
    ' --argjson n "$ARG" --arg sha "$SHA"
    echo "STAMPED heat $ARG checkpointSha=$SHA"
    ;;

  --gate)
    SHA=$(git -C "$PROJECT" rev-parse HEAD)
    jq -e --arg g "$ARG" '.phaseGates | has($g)' "$LEDGER" >/dev/null \
      || { echo "ERROR: phase gate '$ARG' not found in ledger." >&2; exit 1; }
    stamp '
      .phaseGates[$g].checkpointSha = $sha
      | .lastUpdated = (now | todateiso8601)
    ' --arg g "$ARG" --arg sha "$SHA"
    SNAP="$PROJECT/memory/smith-ledger-checkpoint-$ARG.json"
    cp "$LEDGER" "$SNAP"
    echo "STAMPED gate $ARG checkpointSha=$SHA"
    echo "SNAPSHOT $SNAP"
    ;;

  --hash-check)
    case "$ARG" in blueprint|pattern|workspec) ;; *)
      echo "ERROR: --hash-check kind must be blueprint|pattern|workspec" >&2; exit 2 ;;
    esac
    FILE=$(jq -r --arg k "$ARG" '.[$k].file // empty' "$LEDGER")
    RECORDED=$(jq -r --arg k "$ARG" '.[$k].hash // empty' "$LEDGER")
    [[ -n "$FILE" && -n "$RECORDED" ]] || { echo "ERROR: ledger has no $ARG file/hash recorded." >&2; exit 2; }
    # Ledger paths are project-relative; tolerate absolute.
    [[ "$FILE" = /* ]] || FILE="$PROJECT/$FILE"
    [[ -f "$FILE" ]] || { echo "CHANGED $ARG recorded=$RECORDED actual=FILE-MISSING ($FILE)"; exit 1; }
    ACTUAL=$(sha256sum "$FILE" | awk '{print $1}')
    if [[ "$ACTUAL" == "$RECORDED" ]]; then
      echo "UNCHANGED $ARG $ACTUAL"
    else
      echo "CHANGED $ARG recorded=$RECORDED actual=$ACTUAL"
      exit 1
    fi
    ;;

  *)
    echo "ERROR: unknown operation '$OP' (--heat | --gate | --hash-check)" >&2; exit 2
    ;;
esac
