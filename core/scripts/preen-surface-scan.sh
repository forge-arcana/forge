#!/usr/bin/env bash
# preen-surface-scan.sh — Mechanical evidence for /preen Dimension 7 (typographic
# voice) and the greppable half of Dimension 8 (landing shape: brand marks,
# sticky nav, demoted providers).
#
# Usage: preen-surface-scan.sh <project-path> [touchstone.md]
#
# Emits structured markdown for LLM judgment:
#   1. Every font-family declaration / Tailwind font-* utility, with file:line and
#      the selector or element it lands on — grouped by family.
#   2. The "two-voice" list: any family other than the Touchstone's ui_face that
#      reaches a heading, figure, or dialog-title selector. Without a Touchstone
#      the same list is built for every family beyond the most-used one.
#   3. Tabular-numeral coverage (font-variant-numeric / tabular-nums / tnum).
#   4. Third-party brand marks: inline SVG paths near a provider name, with path
#      length — short paths are the hand-drawn-approximation tell.
#   5. Sticky/fixed nav count and muted/outline provider buttons.
#
# Exit code: 2 when the two-voice list is non-empty, 0 otherwise (1 on usage).
# Portable: bash >=3.2, awk, grep, find.
set -euo pipefail

PROJECT="${1:-}"
TOUCHSTONE="${2:-}"
if [[ -z "$PROJECT" || ! -d "$PROJECT" ]]; then
  echo "Usage: preen-surface-scan.sh <project-path> [touchstone.md]" >&2
  exit 1
fi
PROJECT=$(cd "$PROJECT" && pwd)

EXCLUDE_DIRS='node_modules|dist|build|\.next|\.nuxt|\.svelte-kit|coverage|vendor|\.git|out|\.turbo'
STYLE_EXT='css|scss|sass|less|styl|tsx|jsx|ts|js|vue|svelte|astro|html|mdx'

# --- file finder (relative paths, excluding build dirs) ---
list_files() {
  find "$PROJECT" -type f 2>/dev/null \
    | grep -E "\.($STYLE_EXT)$" \
    | grep -Ev "/($EXCLUDE_DIRS)/" | sed "s|^$PROJECT/||" | sort
}
FILES="$(list_files)"
if [[ -z "$FILES" ]]; then
  echo "No style/component files found under $PROJECT"
  exit 0
fi

# grep helper: pattern, prints file:line:text (relative), extended regex, case-insensitive
g() {
  local pat="$1"
  ( cd "$PROJECT" && printf '%s\n' "$FILES" | xargs grep -HniE -- "$pat" 2>/dev/null ) || true
}

# --- Touchstone faces (optional) ---
UI_FACE=""; LOGO_FACE=""; CODE_FACE=""; HEAD_FACE=""
if [[ -n "$TOUCHSTONE" && -f "$TOUCHSTONE" ]]; then
  face() { awk -v k="$1" '
    /^---[ \t]*$/ { d++; if (d==2) exit; next }
    d==1 && $1==k":" { sub(/^[^:]*:[ \t]*/, ""); gsub(/^["\x27]|["\x27]$/, ""); print; exit }
  ' "$TOUCHSTONE"; }
  UI_FACE="$(face ui_face)"; LOGO_FACE="$(face logotype_face)"
  CODE_FACE="$(face code_face)"; HEAD_FACE="$(face heading_face)"
fi

echo "## /preen Surface Scan"
echo "**Project**: \`$PROJECT\`"
if [[ -n "$UI_FACE" ]]; then
  echo "**Touchstone faces**: ui=\`$UI_FACE\` · wordmark=\`${LOGO_FACE:--}\` · code=\`${CODE_FACE:--}\` · heading=\`${HEAD_FACE:--}\`"
else
  echo "**Touchstone faces**: none supplied — two-voice list is built against the most-used family"
fi
echo ""

# ---------------------------------------------------------------------------
# 1. Font-family inventory. For CSS-ish files we carry the nearest preceding
#    selector (a line containing "{"); for markup we carry the line itself.
# ---------------------------------------------------------------------------
echo "### 1. Font-family inventory"
echo ""
# Custom-property map: "--font-xxx: 'Family', ..." -> name<US>family, so a later
# "font-family: var(--font-xxx)" reference can be resolved to the real family
# instead of being discarded as an opaque var() reference.
CUSTOM_MAP="$(cd "$PROJECT" && printf '%s\n' "$FILES" | while IFS= read -r f; do
  awk '
    {
      s = $0
      while (match(s, /--font-[a-zA-Z0-9-]+[ \t]*:[ \t]*[^;}]+/)) {
        m = substr(s, RSTART, RLENGTH)
        name = m; sub(/[ \t]*:.*/, "", name); name = tolower(name)
        val = m; sub(/^[^:]*:[ \t]*/, "", val); sub(/,.*$/, "", val)
        gsub(/["\x27]/, "", val); gsub(/^[ \t]+|[ \t]+$/, "", val)
        if (name != "" && val != "") printf "%s\037%s\n", name, val
        s = substr(s, RSTART + RLENGTH)
      }
    }' "$f"
done | sort -u)"

INVENTORY="$(cd "$PROJECT" && printf '%s\n' "$FILES" | while IFS= read -r f; do
  awk -v F="$f" -v cpmap="$CUSTOM_MAP" '
    function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    BEGIN {
      cpn = split(cpmap, cplines, "\n")
      for (ci = 1; ci <= cpn; ci++) {
        split(cplines[ci], kv, "\037")
        if (kv[1] != "") vars[kv[1]] = kv[2]
      }
    }
    /\{/ { sel = $0; sub(/\{.*/, "", sel); sel = trim(sel); if (sel != "") lastsel = sel }
    {
      line = $0
      lc = tolower(line)
      if (match(lc, /--font-[a-z0-9-]+[ \t]*:[ \t]*[^;}]+/)) {
        rest = line
        while (match(rest, /--font-[a-z0-9-]+[ \t]*:[ \t]*[^;}]+/)) {
          m = substr(rest, RSTART, RLENGTH)
          name = m; sub(/[ \t]*:.*/, "", name); name = tolower(trim(name))
          val = m; sub(/^[^:]*:[ \t]*/, "", val); sub(/,.*$/, "", val)
          gsub(/["\x27]/, "", val); val = trim(val)
          if (name != "" && val != "") {
            vars[name] = val
            printf "%s\t%s:%d\t%s\n", val, F, NR, "(declares " name ")"
          }
          rest = substr(rest, RSTART + RLENGTH)
        }
        next
      }
      fam = ""
      if (match(lc, /font-family[ \t]*:[ \t]*[^;}]+/)) {
        fam = substr(line, RSTART, RLENGTH); sub(/^[^:]*:[ \t]*/, "", fam)
        fam = trim(fam); sub(/,.*$/, "", fam); gsub(/["\x27]/, "", fam)
        if (fam ~ /^var\(/) {
          vn = fam; sub(/^var\(/, "", vn); sub(/\).*/, "", vn); vn = tolower(trim(vn))
          if (vn in vars) fam = vars[vn]
        }
      } else if (match(lc, /fontfamily[ \t]*:[ \t]*["\x27][^"\x27]+/)) {
        fam = substr(line, RSTART, RLENGTH); sub(/^[^:]*:[ \t]*["\x27]/, "", fam)
        sub(/,.*$/, "", fam); fam = trim(fam)
      } else if (match(lc, /(^|[ \t"\x27`])font-(serif|mono|display|heading|headline|title|brand|logo|sans)([ \t"\x27`:]|$)/)) {
        fam = substr(lc, RSTART, RLENGTH); gsub(/[^a-z-]/, "", fam); sub(/^font-/, "utility:font-", fam)
      }
      if (fam == "" || fam ~ /^(inherit|initial|unset)/) next
      ctx = (F ~ /\.(css|scss|sass|less|styl)$/) ? lastsel : trim(line)
      if (length(ctx) > 110) ctx = substr(ctx, 1, 107) "..."
      printf "%s\t%s:%d\t%s\n", fam, F, NR, ctx
    }' "$f"
done)"

if [[ -z "$INVENTORY" ]]; then
  echo "_No font-family declarations found._"
  echo ""
else
  echo "| Family | Sites | Sample locations |"
  echo "|--------|-------|------------------|"
  printf '%s\n' "$INVENTORY" | awk -F'\t' '
    { n[$1]++; if (n[$1] <= 3) s[$1] = s[$1] (s[$1] == "" ? "" : "<br>") "`" $2 "` " $3 }
    END { for (k in n) printf "%d\t| `%s` | %d | %s |\n", n[k], k, n[k], s[k] }' \
    | sort -rn | cut -f2-
  echo ""
fi

# ---------------------------------------------------------------------------
# 2. Two-voice list: a non-UI family reaching headings / figures / dialog titles.
# ---------------------------------------------------------------------------
echo "### 2. Two-voice test — second family reaching headings, figures, or dialog titles"
echo ""
HEAD_RE='(^|[^a-z])(h[1-6]|heading|headline|title|display|hero|price|amount|figure|stat|total|balance|count|number|numeral|metric|dialog|modal|sheet|toast)([^a-z]|$)'
WORDMARK_RE='(wordmark|logotype|brand-name|brandname|logo-text|logotext)'

MOST_USED=""
if [[ -n "$INVENTORY" ]]; then
  # Prefer whatever family is set on a `body`/`html` selector — that is the
  # base UI voice regardless of how many headings/figures a display face
  # touches. Fall back to raw frequency (excluding utility rows and
  # declaration rows) when no body/html rule is found.
  MOST_USED="$(printf '%s\n' "$INVENTORY" | awk -F'\t' '
    $1 !~ /^utility:/ {
      ctx = tolower($3)
      if (ctx ~ /(^|,[ ]*)(body|html)([ ]*,|$)/) { print $1; exit }
    }')"
  if [[ -z "$MOST_USED" ]]; then
    MOST_USED="$(printf '%s\n' "$INVENTORY" | awk -F'\t' '
      $1 !~ /^utility:/ && $3 !~ /^\(declares/ { n[$1]++ }
      END { m=0; b=""; for (k in n) if (n[k] > m) { m = n[k]; b = k } print b }')"
  fi
fi
BASE_FACE="${UI_FACE:-$MOST_USED}"

TWO_VOICE="$(printf '%s\n' "$INVENTORY" | awk -F'\t' -v base="$(printf '%s' "$BASE_FACE" | tr 'A-Z' 'a-z')" \
  -v code="$(printf '%s' "$CODE_FACE" | tr 'A-Z' 'a-z')" -v hre="$HEAD_RE" -v wre="$WORDMARK_RE" '
  {
    fam = tolower($1); ctx = tolower($3)
    if (fam == "") next
    if (ctx ~ /^\(declares/) next
    if (base != "" && fam == base) next
    if (fam == "utility:font-sans") next
    if (code != "" && fam == code) next
    if (ctx ~ wre) next
    if (ctx ~ hre || fam ~ /(serif|display|heading|headline|title)$/) print "| `" $1 "` | `" $2 "` | " $3 " |"
  }')"

if [[ -z "$TWO_VOICE" ]]; then
  echo "_PASS — no second family reaches a heading, figure, or dialog title (wordmark sites excluded)._"
else
  echo "| Family | Location | Selector / element |"
  echo "|--------|----------|--------------------|"
  printf '%s\n' "$TWO_VOICE"
  echo ""
  echo "**FAIL** — each row is a site where a second voice reaches the interface. Passes only if every row is the wordmark beside the brand mark, or the Touchstone declares a \`heading_face\` with audience + reason (and no row is a figure)."
fi
echo ""

# ---------------------------------------------------------------------------
# 3. Tabular numerals
# ---------------------------------------------------------------------------
echo "### 3. Figures are tabular"
echo ""
TAB="$(g 'tabular-nums|font-variant-numeric|font-feature-settings[^;]*tnum')"
FIG="$(g "(class|className)=[\"'][^\"']*(price|amount|total|balance|figure|stat|count|number|metric)")"
TAB_N=$(printf '%s\n' "$TAB" | grep -c . || true)
FIG_N=$(printf '%s\n' "$FIG" | grep -c . || true)
echo "- tabular-numeral declarations: **$TAB_N**"
echo "- money/count elements by class name: **$FIG_N**"
if [[ "$TAB_N" -eq 0 && "$FIG_N" -gt 0 ]]; then
  echo "- **FLAG** — figures exist but nothing declares tabular numerals; columns of money or counts will jitter."
fi
if [[ -n "$TAB" ]]; then
  echo ""
  echo '```'
  printf '%s\n' "$TAB" | head -12
  echo '```'
fi
echo ""

# ---------------------------------------------------------------------------
# 4. Brand marks — provider-named inline SVG path lengths
# ---------------------------------------------------------------------------
echo "### 4. Third-party brand marks (hand-drawn tell = short path data)"
echo ""
PROVIDERS='google|apple|github|microsoft|facebook|meta|discord|twitter|x\.com|slack|linkedin|amazon|stripe|paypal|spotify'
BRAND="$(cd "$PROJECT" && printf '%s\n' "$FILES" | xargs awk -v pre="$PROVIDERS" '
  FNR == 1 { prov_line = 0; prov = "" }
  {
    lc = tolower($0)
    if (lc ~ pre) { prov_line = FNR; prov = lc; match(prov, pre); prov = substr(prov, RSTART, RLENGTH) }
    if (lc ~ /<path[^>]*d=/ && prov_line && FNR - prov_line <= 6) {
      d = $0; sub(/.*d=["\x27]/, "", d); sub(/["\x27].*/, "", d)
      printf "| %s | `%s:%d` | %d | %s |\n", prov, FILENAME, FNR, length(d), (length(d) < 120 ? "**verify — short path**" : "ok")
    }
  }' 2>/dev/null)" || true
if [[ -z "$BRAND" ]]; then
  echo "_No provider-named inline SVG paths found. If provider buttons exist as <img>/<Icon>, verify the source is the published geometry by hand._"
else
  echo "| Provider | Location | Path length | Verdict |"
  echo "|----------|----------|-------------|---------|"
  printf '%s\n' "$BRAND"
fi
echo ""

# ---------------------------------------------------------------------------
# 5. Landing: sticky nav and demoted providers
# ---------------------------------------------------------------------------
echo "### 5. Landing signals"
echo ""
STICKY="$(g 'position[ \t]*:[ \t]*(sticky|fixed)|(^|[ \t"'"'"'])(sticky|fixed)([ \t"'"'"']|$)' | grep -iE 'nav|header' || true)"
STICKY_N=$(printf '%s\n' "$STICKY" | grep -c . || true)
echo "- sticky/fixed nav or header rules: **$STICKY_N** (expect exactly one)"
DEMOTED="$(g "variant=[\"'](outline|ghost|secondary)|btn-(outline|ghost)|text-muted|opacity-[0-6]0" | grep -iE "$PROVIDERS|provider|sign.?in|continue with" || true)"
DEMOTED_N=$(printf '%s\n' "$DEMOTED" | grep -c . || true)
echo "- sign-in providers styled as muted/outline/ghost: **$DEMOTED_N** (equal weight is the default; each needs a stated reason)"
if [[ -n "$DEMOTED" ]]; then
  echo ""
  echo '```'
  printf '%s\n' "$DEMOTED" | head -12
  echo '```'
fi
echo ""
echo "_Above-the-fold product shot, section-shape variety, and the 375px stack check are visual — take the screenshots (Dimension 8)._"

if [[ -n "$TWO_VOICE" ]]; then exit 2; fi
exit 0
