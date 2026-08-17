#!/usr/bin/env bash
# burn-status.sh — Per-session token-burn report for /burn (Path A monitor)
#
# Reads the harness's own session transcripts — zero external deps, no OTEL
# backend, no API key. Every assistant turn records its token usage on disk;
# this just sums it per session and estimates cost.
#
# Sessions are aggregated PER MODEL, not one-model-per-session: a session that
# spawned sonnet/haiku subagents under an opus orchestrator shows each model's
# share. That per-model split is the verification signal for tier wiring — a
# fan-out session whose report shows only one model means the per-spawn tier
# hints did not bind at runtime.
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
#   burn-status.sh [project-path] --compare <a> <b>  # before/after delta between two
#                                            # sessions (uuid prefix | latest)
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
    --compare) MODE="compare"; CMP_A="${2:?--compare needs two session ids}"; CMP_B="${3:?--compare needs two session ids}"; shift 3 ;;
    -*)        echo "burn-status.sh: unknown option '$1'" >&2; exit 2 ;;
    *)         PROJECT="$1"; shift ;;
  esac
done

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required for burn-status.sh."; exit 1
fi

# --- Pricing (USD per 1M tokens): input / output / cache-write / cache-read ---
# ESTIMATE ONLY — verified against Claude API list pricing 2026-08-15
# (cache write = 1.25x input, cache read = 0.1x input). Edit when pricing moves.
# Unknown models fall back to the Fable tier (the heaviest), so estimates are
# conservative-high, never low.
price_for() {
  case "$1" in
    *fable*|*mythos*) echo "10 50 12.50 1.00" ;;
    *opus*)           echo "5 25 6.25 0.50" ;;
    *sonnet*)         echo "3 15 3.75 0.30" ;;
    *haiku*)          echo "1 5 1.25 0.10" ;;
    *)                echo "10 50 12.50 1.00" ;;   # default → Fable tier
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

# Subagent transcripts for a session, one path per line (empty if none).
#
# Subagent turns are NOT written to the session's own .jsonl — the harness gives
# each spawned agent its own transcript under a per-session tasks/ directory. A
# main-transcript-only reading therefore shows zero cheap-tier turns even when
# every fan-out leg bound its model correctly, which is exactly backwards for a
# tier audit. Override the search roots with FORGE_TASKS_ROOTS on harnesses that
# place them elsewhere; finding none is normal and silently yields nothing.
subagent_transcripts() { # session .jsonl → task transcript paths
  local f="$1" uuid enc root
  uuid=$(basename "$f" .jsonl)
  enc=$(basename "$(dirname "$f")")
  shopt -s nullglob
  for root in ${FORGE_TASKS_ROOTS:-/tmp/claude-*}; do
    [[ -d "$root/$enc/$uuid/tasks" ]] || continue
    for t in "$root/$enc/$uuid/tasks/"*.output; do echo "$t"; done
  done
  shopt -u nullglob
}

# Aggregate a session into one TSV row PER MODEL: model\ti\to\tcr\tcc\tn
# Covers the main transcript AND its subagent transcripts — jq -s slurps them
# into one array, so grouping and dedupe span every model that ran for the
# session, not just the one the session itself rode.
# Dedupes streaming-duplicate records by (message.id|requestId|timestamp).
aggregate_by_model() {
  local -a all=("$1")
  local sf
  while IFS= read -r sf; do [[ -n "$sf" ]] && all+=("$sf"); done < <(subagent_transcripts "$1")
  jq -rs '
    [ .[] | select(.message.usage and .message.role=="assistant") ]
    | unique_by((.message.id // "") + "|" + (.requestId // "") + "|" + (.timestamp // ""))
    | group_by(.message.model // "unknown")[]
    | {
        model: (.[0].message.model // "unknown"),
        i:  (map(.message.usage.input_tokens // 0)               | add // 0),
        o:  (map(.message.usage.output_tokens // 0)              | add // 0),
        cr: (map(.message.usage.cache_read_input_tokens // 0)    | add // 0),
        cc: (map(.message.usage.cache_creation_input_tokens // 0)| add // 0),
        n:  length
      }
    | "\(.model)\t\(.i)\t\(.o)\t\(.cr)\t\(.cc)\t\(.n)"
  ' "${all[@]}" 2>/dev/null || true
}

cost_of() { # model i o cr cc → USD (awk float)
  read -r pin pout pcw pcr <<<"$(price_for "$1")"
  awk -v i="$2" -v o="$3" -v cr="$4" -v cc="$5" \
      -v pin="$pin" -v pout="$pout" -v pcw="$pcw" -v pcr="$pcr" \
      'BEGIN{ printf "%.2f", (i*pin + o*pout + cc*pcw + cr*pcr)/1e6 }'
}

# Session-level rollup across models. Sets S_I S_O S_CR S_CC S_N S_COST S_MIX;
# cost is the sum of per-model costs, mix reads like "opus-5:12t sonnet-5:34t".
session_stats() {
  S_I=0; S_O=0; S_CR=0; S_CC=0; S_N=0; S_COST=0; S_MIX=""
  local m i o cr cc n c
  while IFS=$'\t' read -r m i o cr cc n; do
    [[ -n "$m" && "${n:-0}" -gt 0 ]] || continue
    S_I=$((S_I+i)); S_O=$((S_O+o)); S_CR=$((S_CR+cr)); S_CC=$((S_CC+cc)); S_N=$((S_N+n))
    c=$(cost_of "$m" "$i" "$o" "$cr" "$cc")
    S_COST=$(awk -v a="$S_COST" -v b="$c" 'BEGIN{printf "%.2f", a+b}')
    S_MIX="${S_MIX:+$S_MIX }${m#claude-}:${n}t"
  done < <(aggregate_by_model "$1")
}

# --- Resolve which transcript dirs to walk ---
declare -a DIRS=()
if [[ "$SCOPE" == "all" ]]; then
  for d in "$PROJECTS_DIR"/*/; do [[ -d "$d" ]] && DIRS+=("$d"); done
else
  ABS=$(cd "$PROJECT" 2>/dev/null && pwd || echo "$PROJECT")
  DIRS+=("$PROJECTS_DIR/$(encode_path "$ABS")/")
fi

# --- --compare: before/after delta between two sessions of one project ---
resolve_session() { # dir selector → single .jsonl path (errors if ambiguous/absent)
  local dir="$1" sel="$2"
  if [[ "$sel" == "latest" ]]; then
    ls -t "$dir"*.jsonl 2>/dev/null | head -1
    return
  fi
  local matches=("$dir$sel"*.jsonl)
  if [[ ${#matches[@]} -ne 1 || ! -f "${matches[0]}" ]]; then
    echo "ERROR: session '$sel' matches ${#matches[@]} transcript(s) in $dir — need exactly 1." >&2
    return 1
  fi
  echo "${matches[0]}"
}

if [[ "$MODE" == "compare" ]]; then
  DIR="${DIRS[0]}"
  [[ -d "$DIR" ]] || { echo "No transcript dir found for this project ($DIR)."; exit 1; }
  shopt -s nullglob
  FA=$(resolve_session "$DIR" "$CMP_A") || exit 1
  FB=$(resolve_session "$DIR" "$CMP_B") || exit 1
  shopt -u nullglob
  [[ -n "$FA" && -n "$FB" ]] || { echo "ERROR: could not resolve both sessions." >&2; exit 1; }
  session_stats "$FA"; ai=$S_I; ao=$S_O; acr=$S_CR; acc=$S_CC; an=$S_N; ACOST=$S_COST; AMIX=$S_MIX
  session_stats "$FB"; bi=$S_I; bo=$S_O; bcr=$S_CR; bcc=$S_CC; bn=$S_N; BCOST=$S_COST; BMIX=$S_MIX
  echo "## Token Burn — Before/After"
  echo "**A (before)**: \`$(basename "$FA" .jsonl | cut -c1-8)\` ($an turns — $AMIX) | **B (after)**: \`$(basename "$FB" .jsonl | cut -c1-8)\` ($bn turns — $BMIX)"
  echo ""
  echo "| Metric | A | B | Δ | Δ% |"
  echo "|--------|---|---|----|----|"
  row() { # label a b
    awk -v L="$1" -v a="$2" -v b="$3" 'BEGIN{
      d = b - a
      pct = (a == 0) ? "n/a" : sprintf("%+.1f%%", d / a * 100)
      hum = ""; n = (d < 0 ? -d : d)
      if (n >= 1e6) hum = sprintf("%.1fM", n/1e6); else if (n >= 1e3) hum = sprintf("%.1fk", n/1e3); else hum = sprintf("%d", n)
      printf "| %s | %s | %s | %s%s | %s |\n", L, a, b, (d < 0 ? "-" : "+"), hum, pct
    }'
  }
  row "Output tokens" "$ao" "$bo"
  row "Input tokens" "$ai" "$bi"
  row "Cache write" "$acc" "$bcc"
  row "Cache read" "$acr" "$bcr"
  awk -v a="$ACOST" -v b="$BCOST" 'BEGIN{
    d = b - a
    pct = (a == 0) ? "n/a" : sprintf("%+.1f%%", d / a * 100)
    printf "| Est cost | $%.2f | $%.2f | %+.2f | %s |\n", a, b, d, pct
  }'
  echo ""
  echo "_Output tokens are the honest spend signal; cache-read deltas flatter the numbers._"
  exit 0
fi

echo "## Token Burn Report"
echo "**Membrane**: \`$MEMBRANE\` | **Scope**: $SCOPE | **Mode**: $MODE"
echo "**Pricing**: estimate only (see price_for in burn-status.sh)"
echo ""

GT_I=0; GT_O=0; GT_CR=0; GT_CC=0; GT_COST=0; FOUND=0
GT_OC=0; GT_WC=0; GT_RC=0   # per-column est-cost accumulators (output / cache-write / cache-read)

# Per-model grand totals — parallel indexed arrays for bash 3.2 compat.
MODEL_NAMES=(); MODEL_I=(); MODEL_O=(); MODEL_CR=(); MODEL_CC=(); MODEL_N=(); MODEL_COST=()
model_idx() { # sets MIDX for model "$1", registering it if new (no subshell — mutates arrays)
  local m="$1" k
  for k in "${!MODEL_NAMES[@]}"; do
    if [[ "${MODEL_NAMES[$k]}" == "$m" ]]; then MIDX=$k; return; fi
  done
  MODEL_NAMES+=("$m"); MODEL_I+=(0); MODEL_O+=(0); MODEL_CR+=(0); MODEL_CC+=(0); MODEL_N+=(0); MODEL_COST+=(0)
  MIDX=$((${#MODEL_NAMES[@]}-1))
}

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
  echo "| Session | Date | Turns | Input | Output | Cache R | Cache W | Est \$ | Model mix |"
  echo "|---------|------|-------|-------|--------|---------|---------|--------|-----------|"

  for f in "${FILES[@]}"; do
    [[ -f "$f" ]] || continue
    s_i=0; s_o=0; s_cr=0; s_cc=0; s_n=0; s_cost=0; s_mix=""
    while IFS=$'\t' read -r m i o cr cc n; do
      [[ -n "$m" && "${n:-0}" -gt 0 ]] || continue
      s_i=$((s_i+i)); s_o=$((s_o+o)); s_cr=$((s_cr+cr)); s_cc=$((s_cc+cc)); s_n=$((s_n+n))
      c=$(cost_of "$m" "$i" "$o" "$cr" "$cc")
      s_cost=$(awk -v a="$s_cost" -v b="$c" 'BEGIN{printf "%.2f", a+b}')
      s_mix="${s_mix:+$s_mix }${m#claude-}:${n}t"
      model_idx "$m"
      MODEL_I[$MIDX]=$((MODEL_I[$MIDX]+i)); MODEL_O[$MIDX]=$((MODEL_O[$MIDX]+o))
      MODEL_CR[$MIDX]=$((MODEL_CR[$MIDX]+cr)); MODEL_CC[$MIDX]=$((MODEL_CC[$MIDX]+cc))
      MODEL_N[$MIDX]=$((MODEL_N[$MIDX]+n))
      MODEL_COST[$MIDX]=$(awk -v a="${MODEL_COST[$MIDX]}" -v b="$c" 'BEGIN{printf "%.2f", a+b}')
      read -r pin pout pcw pcr <<<"$(price_for "$m")"
      GT_OC=$(awk -v a="$GT_OC" -v o="$o" -v p="$pout" 'BEGIN{printf "%.4f", a + o*p/1e6}')
      GT_WC=$(awk -v a="$GT_WC" -v cx="$cc" -v p="$pcw" 'BEGIN{printf "%.4f", a + cx*p/1e6}')
      GT_RC=$(awk -v a="$GT_RC" -v cx="$cr" -v p="$pcr" 'BEGIN{printf "%.4f", a + cx*p/1e6}')
    done < <(aggregate_by_model "$f")
    [[ "$s_n" -eq 0 ]] && continue
    FOUND=$((FOUND+1))
    sid=$(basename "$f" .jsonl); sid="${sid:0:8}"
    dt=$(date -r "$f" +%m-%d 2>/dev/null || echo "??")
    echo "| \`$sid\` | $dt | $s_n | $(humanize "$s_i") | $(humanize "$s_o") | $(humanize "$s_cr") | $(humanize "$s_cc") | \$$s_cost | $s_mix |"
    GT_I=$((GT_I+s_i)); GT_O=$((GT_O+s_o)); GT_CR=$((GT_CR+s_cr)); GT_CC=$((GT_CC+s_cc))
    GT_COST=$(awk -v a="$GT_COST" -v b="$s_cost" 'BEGIN{printf "%.2f", a+b}')
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
echo "### By Model"
echo ""
echo "| Model | Turns | Input | Output | Cache R | Cache W | Est \$ | % of cost |"
echo "|-------|-------|-------|--------|---------|---------|--------|-----------|"
for k in "${!MODEL_NAMES[@]}"; do
  pct=$(awk -v c="${MODEL_COST[$k]}" -v t="$GT_COST" 'BEGIN{ printf "%.0f%%", (t > 0) ? c / t * 100 : 0 }')
  echo "| ${MODEL_NAMES[$k]#claude-} | ${MODEL_N[$k]} | $(humanize "${MODEL_I[$k]}") | $(humanize "${MODEL_O[$k]}") | $(humanize "${MODEL_CR[$k]}") | $(humanize "${MODEL_CC[$k]}") | \$${MODEL_COST[$k]} | $pct |"
done
echo ""
echo "_Tier-binding check: these rows span the main session AND its subagent transcripts, so a fan-out session should show sonnet/haiku rows. If it shows only the session model, either no leg passed a per-spawn model parameter, or the subagent transcripts were not found (set FORGE_TASKS_ROOTS). Note what a session-model-only breakdown does NOT mean: a skill's \`model:\` frontmatter never pulls a session below what it is already running, so inline skill work always reads as the session tier — that is expected, not a binding failure. See protocol.md Model Tiers rule 7._"
echo ""
# Dominant-column burn profile (cost-weighted) + the canned lever line — deterministic,
# so /burn's step-2 read is emitted here instead of asking the model to compare numbers.
awk -v oc="$GT_OC" -v wc="$GT_WC" -v rc="$GT_RC" -v tot="$GT_COST" 'BEGIN{
  lbl = "Output-dominated"; dom = oc
  lever = "leaner prompts / fewer fan-out subagents"
  if (wc > dom) { lbl = "Cache-Write-dominated"; dom = wc
    lever = "steadier context — avoid churn that invalidates the prompt cache" }
  if (rc > dom) { lbl = "Cache-Read-dominated"; dom = rc
    lever = "cheap; usually fine — big raw numbers here are mostly low-cost" }
  share = (tot > 0) ? sprintf(" (%.0f%% of est cost)", dom / tot * 100) : ""
  printf "**Profile**: %s%s — lever: %s.\n", lbl, share, lever
}'
echo ""
echo "_Output tokens are the real spend lever; cache-read is cheap. Burn dominated by Cache W → context is being rebuilt; by Output → generation-heavy work._"
