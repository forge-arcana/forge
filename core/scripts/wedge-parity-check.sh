#!/usr/bin/env bash
# wedge-parity-check.sh — Touchstone MD/HTML token parity check for /wedge.
#
# The Touchstone MD's YAML frontmatter (per the DESIGN.md-style scaffold in
# touchstone-md-scaffold.md) is the normative token contract. This script
# extracts every leaf token VALUE declared in that YAML block (colors, font
# names, radii, spacing, etc. — token references like "{colors.primary}"
# are skipped, since they resolve to another token's value rather than
# being a raw value themselves) and checks whether each value literally
# appears in the paired Touchstone HTML. Drift (a declared value that never
# shows up in the rendered HTML) is a defect per Heat 7's HTML <-> MD parity
# HARD RULE.
#
# Usage:
#   wedge-parity-check.sh <touchstone.md> <touchstone.html>
#
# Output: a markdown table (token path | value | present-in-HTML) followed
# by a PASS/FAIL summary line. Exits nonzero on FAIL or on missing input.
#
# Portable: bash >=3.2 (no associative arrays), awk + grep only. No external
# deps. Hex-color comparison is case-insensitive; 3-digit hex shorthand is
# expanded to 6-digit (and vice versa) before the HTML lookup.
#
# Presence is a literal (fixed-string, case-insensitive) substring search —
# this is a mechanical evidence pass, not a CSS-computed-style diff. A value
# that happens to be a substring of an unrelated larger token (e.g. "16px"
# inside "116px") can false-positive; treat FAIL rows as ground truth, PASS
# rows as evidence to spot-check, same as forge-scan.sh's other greps.
set -euo pipefail

usage() {
  echo "Usage: wedge-parity-check.sh <touchstone.md> <touchstone.html>" >&2
  exit 1
}

MD="${1:-}"
HTML="${2:-}"
[[ -z "$MD" || -z "$HTML" ]] && usage

if [[ ! -f "$MD" ]]; then
  echo "ERROR: Touchstone MD not found: $MD" >&2
  exit 1
fi
if [[ ! -f "$HTML" ]]; then
  echo "ERROR: Touchstone HTML not found: $HTML" >&2
  exit 1
fi

# --- Extract "path<TAB>value" pairs from the MD's leading YAML frontmatter. ---
# Walks the block tracking indentation as a shallow (<=4 level) key stack —
# the DESIGN.md scaffold never nests deeper than colors.primary or
# typography.headline-display.fontFamily / components.button-primary.backgroundColor.
# Metadata scalars (version/name/description) and token-reference values
# ("{path.to.token}") are skipped — the former aren't design tokens, the
# latter resolve to another row's value rather than declaring their own.
TOKENS_TSV="$(awk '
  function trim(s) {
    gsub(/^[ \t]+|[ \t]+$/, "", s)
    return s
  }
  BEGIN { dashcount = 0; in_fm = 0 }
  {
    line = $0
    if (line ~ /^---[ \t]*$/) {
      dashcount++
      if (dashcount == 1) { in_fm = 1; next }
      if (dashcount == 2) { in_fm = 0; exit }
    }
    if (!in_fm) next
    if (trim(line) == "") next
    if (line ~ /^[ \t]*#/) next

    match(line, /[^ ]/)
    indent = RSTART - 1
    content = substr(line, indent + 1)
    colon_pos = index(content, ":")
    if (colon_pos == 0) next
    key = trim(substr(content, 1, colon_pos - 1))
    val = trim(substr(content, colon_pos + 1))
    sub(/[ \t]+#.*$/, "", val)

    level = int(indent / 2)
    if (level == 0) { L0 = key; L1 = ""; L2 = ""; L3 = "" }
    else if (level == 1) { L1 = key; L2 = ""; L3 = "" }
    else if (level == 2) { L2 = key; L3 = "" }
    else if (level == 3) { L3 = key }
    else next

    if (val == "") next
    if (L0 == "version" || L0 == "name" || L0 == "description") next

    gsub(/^"|"$/, "", val)
    gsub(/^\x27|\x27$/, "", val)
    if (val == "") next
    if (val ~ /^\{/) next

    path = L0
    if (level >= 1 && L1 != "") path = path "." L1
    if (level >= 2 && L2 != "") path = path "." L2
    if (level >= 3 && L3 != "") path = path "." L3

    print path "\t" val
  }
' "$MD")"

if [[ -z "$TOKENS_TSV" ]]; then
  echo "ERROR: no YAML frontmatter tokens found in $MD (expected a --- ... --- block at the top)." >&2
  exit 1
fi

# --- Hex shorthand expand/collapse helper (trivial cases only). ---
hex_expand() {
  # #abc -> #aabbcc ; passthrough otherwise
  local v="$1"
  if [[ "$v" =~ ^#([0-9A-Fa-f])([0-9A-Fa-f])([0-9A-Fa-f])$ ]]; then
    printf '#%s%s%s%s%s%s' \
      "${BASH_REMATCH[1]}" "${BASH_REMATCH[1]}" \
      "${BASH_REMATCH[2]}" "${BASH_REMATCH[2]}" \
      "${BASH_REMATCH[3]}" "${BASH_REMATCH[3]}"
  else
    printf '%s' "$v"
  fi
}

hex_collapse() {
  # #aabbcc -> #abc only if each channel pair is doubled; passthrough otherwise
  local v="$1"
  if [[ "$v" =~ ^#([0-9A-Fa-f])\1([0-9A-Fa-f])\2([0-9A-Fa-f])\3$ ]]; then
    printf '#%s%s%s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
  else
    printf '%s' "$v"
  fi
}

echo "## Touchstone MD <-> HTML Parity"
echo "**MD**: \`$MD\` | **HTML**: \`$HTML\`"
echo ""
echo "| Token | Value | Present in HTML |"
echo "|-------|-------|------------------|"

FAIL_COUNT=0
TOTAL=0

while IFS=$'\t' read -r path value; do
  [[ -z "$path" ]] && continue
  TOTAL=$((TOTAL + 1))

  found="NO"
  if grep -qiF -- "$value" "$HTML" 2>/dev/null; then
    found="YES"
  elif [[ "$value" == \#* ]]; then
    alt="$(hex_expand "$value")"
    if [[ "$alt" != "$value" ]] && grep -qiF -- "$alt" "$HTML" 2>/dev/null; then
      found="YES"
    else
      alt="$(hex_collapse "$value")"
      if [[ "$alt" != "$value" ]] && grep -qiF -- "$alt" "$HTML" 2>/dev/null; then
        found="YES"
      fi
    fi
  fi

  if [[ "$found" == "NO" ]]; then
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi

  echo "| \`$path\` | \`$value\` | $found |"
done <<< "$TOKENS_TSV"

echo ""
if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo "**FAIL** — $FAIL_COUNT of $TOTAL token value(s) missing from the HTML. Drift is a defect (Heat 7 HARD RULE)."
  exit 1
else
  echo "**PASS** — all $TOTAL token value(s) present in the HTML."
fi
