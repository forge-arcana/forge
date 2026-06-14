#!/usr/bin/env bash
# burn-status.sh — Per-session token-burn report for /burn (Path A monitor)
#
# Reads the harness's own session transcripts — zero external deps, no OTEL
# backend, no API key. Every assistant turn records its token usage on disk;
# this just sums it per session and estimates cost.
#
# COUPLING NOTE: transcript path + JSON shape below are Claude Code's
# (~/.claude/projects/<encoded-path>/<uuid>.jsonl, one `message.usage` per
# turn). Other harnesses store usage differently — on those this degrades
# gracefully to "no transcripts found" rather than erroring. If/when forge
# validates another harness's format, abstract LOCATE + the jq below.
#
# USAGE:
#   burn-status.sh [project-path]            # all sessions for a project (default: cwd)
#   burn-status.sh [project-path] --today    # only sessions touched today
#   burn-status.sh [project-path] --session latest   # detail one session (uuid|latest)
#   burn-status.sh --all                     # every project under the membrane
#
# Requires: jq, awk. bash >=3.2.
set -euo pipefail

MEMBRANE="${FORGE_MEMBRANE:-$HOME/.claude}"
PROJECTS_DIR="$MEMBRANE/projects"

# --- Parse args ---
PROJECT="."
MODE="all-sessions"
SESSION=""
SCOPE="project"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)     SCOPE="all"; shift ;;
    --today)   MODE="today"; shift ;;
    --session) MODE="session"; SESSION="${2:-latest}"; shift 2 ;;
    -*)        echo "burn-status.sh: unknown option '$1'" >&2; exit 2 ;;
    *)         PROJECT="$1"; shift ;;
  esac
done

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required for burn-status.sh."; exit 1
fi

# --- Pricing (USD per 1M tokens): input / output / cache-write / cache-read ---
# ESTIMATE ONLY — edit to match current Claude pricing. Unknown models fall back
# to the Opus tier (the heaviest), so estimates are conservative-high, never low.
price_for() {
  case "$1" in
    *opus*)   echo "15 75 18.75 1.50" ;;
    *sonnet*) echo "3 15 3.75 0.30" ;;
    *haiku*)  echo "1 5 1.25 0.10" ;;
    *)        echo "15 75 18.75 1.50" ;;   # default → Opus tier
  esac
}

# --- Locate the transcript dir for a project path ---
# CC encodes the absolute path by replacing every '/' with '-'.
encode_path() { printf '%s' "$1" | sed 's#/#-#g'; }

humanize() { # bytes-ish integer → 1.6M / 23.9k / 412
  awk -v n="$1" 'BEGIN{
    if (n>=1e6) printf "%.1fM", n/1e6;
    else if (n>=1e3) printf "%.1fk", n/1e3;
    else printf "%d", n;
  }'
}

# Aggregate one .jsonl into a TSV row: model\ti\to\tcr\tcc\tn
# Dedupes streaming-duplicate records by (message.id|requestId|timestamp).
aggregate_session() {
  jq -rs '
    [ .[] | select(.message.usage and .message.role=="assistant") ]
    | unique_by((.message.id // "") + "|" + (.requestId // "") + "|" + (.timestamp // ""))
    | {
        model: ((map(.message.model) | map(select(.)) | last) // "unknown"),
        i:  (map(.message.usage.input_tokens // 0)               | add // 0),
        o:  (map(.message.usage.output_tokens // 0)              | add // 0),
        cr: (map(.message.usage.cache_read_input_tokens // 0)    | add // 0),
        cc: (map(.message.usage.cache_creation_input_tokens // 0)| add // 0),
        n:  length
      }
    | "\(.model)\t\(.i)\t\(.o)\t\(.cr)\t\(.cc)\t\(.n)"
  ' "$1" 2>/dev/null || echo "unknown	0	0	0	0	0"
}

cost_of() { # model i o cr cc → USD (awk float)
  read -r pin pout pcw pcr <<<"$(price_for "$1")"
  awk -v i="$2" -v o="$3" -v cr="$4" -v cc="$5" \
      -v pin="$pin" -v pout="$pout" -v pcw="$pcw" -v pcr="$pcr" \
      'BEGIN{ printf "%.2f", (i*pin + o*pout + cc*pcw + cr*pcr)/1e6 }'
}

# --- Resolve which transcript dirs to walk ---
declare -a DIRS=()
if [[ "$SCOPE" == "all" ]]; then
  for d in "$PROJECTS_DIR"/*/; do [[ -d "$d" ]] && DIRS+=("$d"); done
else
  ABS=$(cd "$PROJECT" 2>/dev/null && pwd || echo "$PROJECT")
  DIRS+=("$PROJECTS_DIR/$(encode_path "$ABS")/")
fi

echo "## Token Burn Report"
echo "**Membrane**: \`$MEMBRANE\` | **Scope**: $SCOPE | **Mode**: $MODE"
echo "**Pricing**: estimate only (see price_for in burn-status.sh)"
echo ""

GT_I=0; GT_O=0; GT_CR=0; GT_CC=0; GT_COST=0; FOUND=0

for DIR in "${DIRS[@]}"; do
  [[ -d "$DIR" ]] || continue
  shopt -s nullglob
  FILES=("$DIR"*.jsonl)
  shopt -u nullglob
  [[ ${#FILES[@]} -eq 0 ]] && continue

  # --today filter
  if [[ "$MODE" == "today" ]]; then
    TODAY=$(date +%Y-%m-%d)
    declare -a KEPT=()
    for f in "${FILES[@]}"; do
      [[ "$(date -r "$f" +%Y-%m-%d 2>/dev/null)" == "$TODAY" ]] && KEPT+=("$f")
    done
    FILES=("${KEPT[@]}")
  fi
  # --session filter
  if [[ "$MODE" == "session" ]]; then
    if [[ "$SESSION" == "latest" ]]; then
      LATEST=$(ls -t "$DIR"*.jsonl 2>/dev/null | head -1)
      FILES=("$LATEST")
    else
      FILES=("$DIR$SESSION.jsonl")
    fi
  fi

  [[ "$SCOPE" == "all" ]] && echo "### $(basename "$DIR")"
  echo ""
  echo "| Session | Date | Turns | Input | Output | Cache R | Cache W | Est \$ | Model |"
  echo "|---------|------|-------|-------|--------|---------|---------|--------|-------|"

  for f in "${FILES[@]}"; do
    [[ -f "$f" ]] || continue
    IFS=$'\t' read -r model i o cr cc n <<<"$(aggregate_session "$f")"
    [[ "${n:-0}" -eq 0 ]] && continue
    FOUND=$((FOUND+1))
    cost=$(cost_of "$model" "$i" "$o" "$cr" "$cc")
    sid=$(basename "$f" .jsonl); sid="${sid:0:8}"
    dt=$(date -r "$f" +%m-%d 2>/dev/null || echo "??")
    echo "| \`$sid\` | $dt | $n | $(humanize "$i") | $(humanize "$o") | $(humanize "$cr") | $(humanize "$cc") | \$$cost | ${model#claude-} |"
    GT_I=$((GT_I+i)); GT_O=$((GT_O+o)); GT_CR=$((GT_CR+cr)); GT_CC=$((GT_CC+cc))
    GT_COST=$(awk -v a="$GT_COST" -v b="$cost" 'BEGIN{printf "%.2f", a+b}')
  done
  echo ""
done

if [[ "$FOUND" -eq 0 ]]; then
  echo "_No session transcripts found. (On non-Claude-Code harnesses this is expected — see the coupling note in burn-status.sh.)_"
  exit 0
fi

echo "### Totals"
echo ""
echo "| Sessions | Input | Output | Cache R | Cache W | Est \$ |"
echo "|----------|-------|--------|---------|---------|--------|"
echo "| $FOUND | $(humanize "$GT_I") | $(humanize "$GT_O") | $(humanize "$GT_CR") | $(humanize "$GT_CC") | \$$GT_COST |"
echo ""
echo "_Output tokens are the real spend lever; cache-read is cheap. Burn dominated by Cache W → context is being rebuilt; by Output → generation-heavy work._"
