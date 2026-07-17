#!/usr/bin/env bash
# pound-persona.sh — Persona-slice extraction for /pound's 21-persona fan-out
#
# qa-framework.md is written as one ~20KB copy-paste prompt. Sending all of it
# to all 21 persona subagents multiplies that cost 21×; each spawn needs only
# the shared preamble (reviewer framing + severity scale) plus its own numbered
# persona block. Splitting text by heading is deterministic — script tier.
#
# USAGE:
#   pound-persona.sh <qa-framework.md> --list        # "N<TAB>Persona name" per persona
#   pound-persona.sh <qa-framework.md> --preamble    # shared preamble only
#   pound-persona.sh <qa-framework.md> <N>           # preamble + persona block N
#
# Block boundaries: a persona starts at '^N. **Name**' inside PART 2 and ends
# before the next persona, the next '###' group heading, or the next '##' part.
#
# Requires: awk. bash >=3.2.
set -euo pipefail

FRAMEWORK="${1:?usage: pound-persona.sh <qa-framework.md> <N|--list|--preamble>}"
SEL="${2:?usage: pound-persona.sh <qa-framework.md> <N|--list|--preamble>}"
[[ -f "$FRAMEWORK" ]] || { echo "ERROR: no such file: $FRAMEWORK" >&2; exit 1; }

preamble() {
  # From the first line after the '## The Prompt' code fence up to the line
  # before '## PART 1' (drop the trailing '---' separator if present).
  awk '
    /^## The Prompt/ { inprompt = 1; next }
    inprompt && /^```/ && !fence { fence = 1; next }
    fence && /^## PART 1/ { exit }
    fence { buf[++n] = $0 }
    END {
      while (n > 0 && (buf[n] ~ /^[[:space:]]*$/ || buf[n] ~ /^---[[:space:]]*$/)) n--
      for (i = 1; i <= n; i++) print buf[i]
    }
  ' "$FRAMEWORK"
}

case "$SEL" in
  --list)
    awk '
      /^## PART 2/ { inpart = 1; next }
      /^## / && inpart { exit }
      inpart && match($0, /^[0-9]+\. \*\*[^*]+\*\*/) {
        num = $0; sub(/\..*$/, "", num)
        name = $0; sub(/^[0-9]+\. \*\*/, "", name); sub(/\*\*.*$/, "", name)
        printf "%s\t%s\n", num, name
      }
    ' "$FRAMEWORK"
    ;;

  --preamble)
    preamble
    ;;

  *)
    [[ "$SEL" =~ ^[0-9]+$ ]] || { echo "ERROR: selector must be a persona number, --list, or --preamble" >&2; exit 2; }
    BLOCK=$(awk -v n="$SEL" '
      /^## PART 2/ { inpart = 1; next }
      /^## / && inpart { exit }
      !inpart { next }
      $0 ~ ("^" n "\\. \\*\\*") { grab = 1; print; next }
      grab && (/^[0-9]+\. \*\*/ || /^###/ || /^##/) { exit }
      grab { print }
    ' "$FRAMEWORK")
    [[ -n "$BLOCK" ]] || { echo "ERROR: persona $SEL not found in PART 2." >&2; exit 1; }
    preamble
    echo ""
    echo "---"
    echo ""
    echo "## YOUR PERSONA"
    echo ""
    echo "$BLOCK"
    ;;
esac
