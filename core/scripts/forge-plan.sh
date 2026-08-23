#!/usr/bin/env bash
# forge-plan.sh — Build the /forge PLAN-table SKELETON from forge-status.sh output
#
# Consumes forge-status.sh's markdown report (Skill Drift Report, Learning
# Status, Memory Status sections) and mechanically routes every non-IDENTICAL
# / non-in-sync item into the three PLAN-table sections (INCOMING, OUTGOING,
# CONFLICTS) per core/skills/forge/preflight.md's Universal Classification
# Table and core/skills/forge/SKILL.md Phase 1's direction-routing rules.
#
# Two ways to feed it forge-status.sh output — pick whichever fits the caller.
# Selection is by explicit flag, never by tty-sniffing stdin: this script is
# almost always driven by an agent harness (not a human at a terminal), where
# stdin is routinely closed/redirected even when no pipe was intended — a
# `[[ ! -t 0 ]]` guess would silently misfire there.
#   1. Pipe:     bash forge-status.sh --pull | bash forge-plan.sh --stdin
#   2. Run-self: bash forge-plan.sh --pull      (runs forge-status.sh itself)
# Piping avoids a second pull/fetch when the skill already ran forge-status.sh
# once in Phase 0 and wants to reuse that same output for Phase 1.
#
# What it does NOT do (left to the model, per SKILL.md Phase 1):
#   - Config rows (harness rules-file drift) — forge-status.sh has no config
#     classification section yet, so there is nothing mechanical to route.
#   - Any judgment field: recommendation/notes text and conflict-analysis
#     prose are placeholdered as `_model fills_` wherever the mechanical
#     source data (Change Details / Learning Details / Memory Status) doesn't
#     carry the answer. The model reviews every row before presenting.
#   - Protected-skill EXCLUSION from outgoing is enforced here mechanically
#     (forge/purge never land as a plain outgoing row — they're forced into
#     CONFLICTS with a "protected" note), but the [^] keep-membrane-disabled
#     UI behaviour itself is presentation, not this script's job.
#
# Portable: bash >=3.2 (no associative arrays), awk + sed + grep only. No
# external deps beyond what forge-status.sh itself already requires.
set -euo pipefail

PROTECTED_SKILLS="forge purge"
ROWSEP=$'\x1f'  # field separator for internal row records — unlikely to collide
            # with markdown/prose content, unlike '|' or tab.

is_protected() {
  local name="$1" p
  for p in $PROTECTED_SKILLS; do
    [[ "$name" == "$p" ]] && return 0
  done
  return 1
}

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

# --- Step 1: obtain forge-status.sh output ---
if [[ "${1:-}" == "--stdin" ]]; then
  STATUS_OUTPUT="$(cat)"
else
  MODE="${1:---fetch}"
  if [[ "$MODE" != "--pull" && "$MODE" != "--fetch" ]]; then
    echo "ERROR: forge-plan.sh accepts only --pull, --fetch, or --stdin (got: $MODE)" >&2
    echo "Usage: forge-plan.sh [--pull|--fetch]   OR   <producer> | forge-plan.sh --stdin" >&2
    exit 1
  fi

  MEMBRANE="${FORGE_MEMBRANE:-$HOME/.claude}"
  RESOLVED_FORGE_PATH="${FORGE_PATH:-}"
  if [[ -z "$RESOLVED_FORGE_PATH" && -f "$MEMBRANE/CLAUDE.md" ]]; then
    RESOLVED_FORGE_PATH=$(sed -n 's/^forge-path:[[:space:]]*//p' "$MEMBRANE/CLAUDE.md" 2>/dev/null | sed 's/[[:space:]]*$//' || true)
  fi
  if [[ -z "$RESOLVED_FORGE_PATH" ]]; then
    echo "ERROR: forge path not configured. Set FORGE_PATH env var, or add 'forge-path: /path/to/forge' to $MEMBRANE/CLAUDE.md." >&2
    exit 1
  fi

  STATUS_SCRIPT="$RESOLVED_FORGE_PATH/core/scripts/forge-status.sh"
  if [[ ! -f "$STATUS_SCRIPT" ]]; then
    echo "ERROR: forge-status.sh not found at $STATUS_SCRIPT" >&2
    exit 1
  fi

  set +e
  STATUS_OUTPUT="$(bash "$STATUS_SCRIPT" "$MODE" 2>&1)"
  STATUS_EXIT=$?
  set -e
  if [[ $STATUS_EXIT -ne 0 ]]; then
    echo "$STATUS_OUTPUT"
    echo ""
    echo "ERROR: forge-status.sh exited $STATUS_EXIT — no PLAN skeleton built. Resolve the above first." >&2
    exit "$STATUS_EXIT"
  fi
fi

# --- Step 2: pull FORGE_PATH / baseline sha out of the status report itself ---
# (single source of truth — works whether we ran forge-status.sh ourselves or
# received its output from elsewhere)
FORGE_PATH_FROM_REPORT=$(printf '%s\n' "$STATUS_OUTPUT" | sed -n 's/^\*\*Forge path\*\*: `\(.*\)`$/\1/p' | head -1)
BASELINE_SHA=$(printf '%s\n' "$STATUS_OUTPUT" | sed -n 's/^\*\*Baseline\*\*: `\([0-9a-f]*\)`.*/\1/p' | head -1)

FORGE_SHA="unknown"
if [[ -n "$FORGE_PATH_FROM_REPORT" ]] && git -C "$FORGE_PATH_FROM_REPORT" rev-parse --short HEAD >/dev/null 2>&1; then
  FORGE_SHA=$(git -C "$FORGE_PATH_FROM_REPORT" rev-parse --short HEAD)
fi
BASELINE_LABEL="${BASELINE_SHA:-none}"

# --- Step 3: slice the report into per-pillar sections ---
SKILL_SECTION=$(sed -n '/^## Skill Drift Report$/,/^## Learning Status$/p' <<<"$STATUS_OUTPUT")
LEARNING_SECTION=$(sed -n '/^## Learning Status$/,/^## Memory Status$/p' <<<"$STATUS_OUTPUT")
MEMORY_SECTION=$(sed -n '/^## Memory Status$/,/^## Classification Checks$/p' <<<"$STATUS_OUTPUT")
CHANGE_DETAILS=$(sed -n '/^### Change Details$/,$p' <<<"$SKILL_SECTION")
LEARNING_DETAILS=$(sed -n '/^### Learning Details$/,$p' <<<"$LEARNING_SECTION")

# skill_essence <name>: first Change Details bullet for a skill, stripped of
# its leading commit hash and trailing "(Author)" — this is the mechanical
# equivalent of "the specific rule/step/behaviour that changed" the SKILL.md
# row-content rule asks for. Empty if nothing mechanical is available.
skill_essence() {
  local name="$1"
  printf '%s\n' "$CHANGE_DETAILS" | awk -v name="$name" '
    BEGIN { inblock = 0 }
    /^\*\*/ {
      inblock = (index($0, "**" name "**") == 1) ? 1 : 0
      next
    }
    inblock && /^  - / {
      line = $0
      sub(/^  - /, "", line)
      # Strip a leading git short-hash token (>=7 hex chars) only — a bare
      # `[a-f0-9]+` also matches plain decimal prose like the "7" in
      # "7 lines changed in deployed copy", corrupting that fallback essence.
      if (match(line, /^[0-9a-f]+ /)) {
        tok_len = RLENGTH - 1
        if (tok_len >= 7) {
          line = substr(line, RLENGTH + 1)
        }
      }
      sub(/ \([^)]*\)[[:space:]]*$/, "", line)
      print line
      exit
    }
  '
}

# --- Step 4: skill rows ---
INC=()
OUT=()
CONF=()

while IFS='|' read -r _ skill status _; do
  skill=$(trim "$skill")
  status=$(trim "$status")
  [[ -z "$skill" || "$skill" == "Skill" || "$skill" =~ ^-+$ ]] && continue
  [[ -z "$status" || "$status" == "IDENTICAL" ]] && continue

  essence=$(skill_essence "$skill")
  section=""
  token="$status"

  case "$status" in
    "FORGE-UPDATED"|"ADDED")
      section="INC"
      [[ -z "$essence" ]] && essence="_model fills_ (new/updated skill — no forge commit range to summarize)"
      ;;
    "DEPLOYED-DIFFERS (protected)")
      section="CONF"
      token="DEPLOYED-DIFFERS"
      essence="forge: unchanged since baseline | membrane: _model fills_ — protected skill, reconcile manually, [^] keep-membrane disabled"
      ;;
    "DEPLOYED-DIFFERS")
      section="OUT"
      [[ -z "$essence" ]] && essence="_model fills_ (deployed copy modified locally — describe the edit)"
      ;;
    "REMOVED")
      section="OUT"
      essence="_model fills_ (deployed-only skill, not present in forge — confirm removal or intentional local addition)"
      ;;
    "CONFLICT"|"CONFLICT (no-baseline)")
      section="CONF"
      if [[ -n "$essence" ]]; then
        essence="forge: $essence | membrane: _model fills_"
      else
        essence="_model fills_ — no baseline; compare forge vs deployed manually"
      fi
      ;;
    *)
      # Unrecognized classification — never silently drop it. Route to
      # CONFLICTS per preflight.md's "ambiguous = CONFLICT" safety doctrine.
      section="CONF"
      essence="_model fills_ — unrecognized classification \"$status\", verify manually"
      ;;
  esac

  # Mechanical protected-skill safety net, independent of forge-status.sh's
  # own "(protected)" labelling — never let forge/purge land as a plain
  # outgoing row.
  if [[ "$section" == "OUT" ]] && is_protected "$skill"; then
    section="CONF"
    token="$status"
    essence="_model fills_ — protected skill, reconcile manually, [^] keep-membrane disabled"
  fi

  row="skill${ROWSEP}${skill}${ROWSEP}${token}${ROWSEP}${essence}"
  case "$section" in
    INC) INC+=("$row") ;;
    OUT) OUT+=("$row") ;;
    CONF) CONF+=("$row") ;;
  esac
done < <(printf '%s\n' "$SKILL_SECTION" | grep '^| ')

# --- Step 5: learning rows ---
# 5a: general.md unprocessed entries (title only — no body/contributor
# available mechanically at this granularity; forge-status.sh's "Learning
# Details" section only carries bodies for skill-specific files).
GENERAL_BLOCK=$(sed -n '/^\*\*Unprocessed entries\*\*/,/^$/p' <<<"$LEARNING_SECTION")
while IFS= read -r line; do
  [[ "$line" != "- "* ]] && continue
  title="${line#- }"
  [[ -z "$title" ]] && continue
  row="learning${ROWSEP}${title}${ROWSEP}${ROWSEP}_model fills_ — read <membrane>/learnings/general.md for the Learning/Apply-when body"
  OUT+=("$row")
done <<< "$GENERAL_BLOCK"

# 5b: skill-specific learning files — per-entry detail from Learning Details.
# direction: "new in forge" / "new file"  -> incoming (ADDED)
#            "new in user"                -> outgoing (REMOVED)
# CAST_DETAIL_FILES tracks (space-joined, bash-3.2-safe — no assoc arrays) every
# file that got at least one INC row here, so 5c below can tell a genuine
# cast-needed-with-detail file apart from a consolidated file whose Learning
# Details came back empty (pure retire/merge with no surviving new title text).
CAST_DETAIL_FILES=""
while IFS="$ROWSEP" read -r file dir title author teaser; do
  [[ -z "$file" ]] && continue
  essence="$teaser"
  [[ -z "$essence" ]] && essence="_model fills_ — read the full entry in <forge>/learnings/$file or <membrane>/learnings/$file"
  label="$title"
  [[ -n "$author" ]] && label="${title} (${author})"
  row="learning${ROWSEP}${label}${ROWSEP}${ROWSEP}${essence}"
  case "$dir" in
    "new in forge"|"new file") INC+=("$row"); CAST_DETAIL_FILES="${CAST_DETAIL_FILES} ${file}" ;;
    "new in user") OUT+=("$row") ;;
    *) CONF+=("learning${ROWSEP}${label}${ROWSEP}unrecognized-direction${ROWSEP}_model fills_ — unrecognized direction \"$dir\" for $file") ;;
  esac
done < <(printf '%s\n' "$LEARNING_DETAILS" | awk '
  function flush() {
    if (pending_title != "") {
      print file0 "\037" dir0 "\037" pending_title "\037" pending_author "\037" pending_teaser
    }
  }
  BEGIN { file0 = ""; dir0 = ""; pending_title = "" }
  /^\*\*/ {
    flush()
    pending_title = ""
    s = $0
    sub(/:$/, "", s)
    sub(/^\*\*/, "", s)
    idx = index(s, "** (")
    if (idx > 0) {
      file0 = substr(s, 1, idx - 1)
      dir0 = substr(s, idx + 4)
      sub(/\)$/, "", dir0)
    }
    next
  }
  /^  - / {
    flush()
    t = $0
    sub(/^  - /, "", t)
    author0 = ""
    if (match(t, / \([^)]*\)$/)) {
      astart = RSTART
      alen = RLENGTH
      author0 = substr(t, astart + 2, alen - 3)
      t = substr(t, 1, astart - 1)
    }
    pending_title = t
    pending_author = author0
    pending_teaser = ""
    next
  }
  /^    → / {
    te = $0
    sub(/^    → /, "", te)
    pending_teaser = te
    next
  }
  END { flush() }
')

# 5c: skill-specific learning files — per-file status-table safety net.
# forge-status.sh's Skill-Specific Learnings table (in LEARNING_SECTION, above
# Learning Details) is the source of truth for whether a file needs a cast at
# all. A file whose status contains "cast needed" MUST produce at least one
# INCOMING row. Most of the time 5b already supplied one (or several) via
# Learning Details' "(new in forge)" entries. The one case 5b cannot cover is
# a consolidation/retirement with no surviving new title text — e.g. entries
# renamed/merged such that the tracker recognizes the old titles as retired
# but forge-status.sh's title-diff found nothing textually "new" to attach a
# body to. Without this net, that file's cast-needed status is silently
# dropped from the PLAN table entirely (the historical bug this fixes).
#
# "Content differs but all titles accounted for" and "In sync" are deliberately
# NOT handled here — the former keeps its existing footer-note-only treatment
# (Step 8 below), the latter needs no row at all.
CAST_DETAIL_HAS() {
  local f="$1"
  case " $CAST_DETAIL_FILES " in
    *" $f "*) return 0 ;;
    *) return 1 ;;
  esac
}

while IFS='|' read -r _ file user_copy forge_copy status _; do
  file=$(trim "$file")
  status=$(trim "$status")
  [[ -z "$file" || "$file" == "File" || "$file" =~ ^-+$ ]] && continue

  case "$status" in
    *"PARSE-ERROR"*)
      CONF+=("learning${ROWSEP}${file}${ROWSEP}CONFLICT (parse-error)${ROWSEP}_model fills_ — forge-status.sh could not parse titles for $file; diff <forge>/learnings/$file vs <membrane>/learnings/$file manually")
      ;;
    *"cast needed"*)
      if ! CAST_DETAIL_HAS "$file"; then
        # Extract a merged/retired count for the essence line — prefer the
        # explicit "N merged/retired in forge" figure; fall back to "N new
        # in forge" when there's no retirement figure to report.
        n=$(printf '%s' "$status" | grep -oE '[0-9]+ merged/retired in forge' | grep -oE '^[0-9]+' | head -1)
        [[ -z "$n" ]] && n=$(printf '%s' "$status" | grep -oE '[0-9]+ new in forge' | grep -oE '^[0-9]+' | head -1)
        [[ -z "$n" ]] && n="?"
        INC+=("learning${ROWSEP}${file}${ROWSEP}FORGE-UPDATED${ROWSEP}_model fills_ — ${n} entries merged/retired; diff <forge>/learnings/$file vs <membrane>/learnings/$file")
      fi
      ;;
  esac
done < <(printf '%s\n' "$LEARNING_SECTION" | grep '^| ' | awk -F'|' 'NF==6')

# --- Step 6: memory rows ---
FORGEONLY_BLOCK=$(sed -n '/^\*\*Forge-only memories\*\*/,/^$/p' <<<"$MEMORY_SECTION")

# Row is "| file | in-membrane | in-forge | status |" — 4 real columns, so
# read needs 6 slots (leading/trailing empty boundary fields included) to
# land `status` on the correct (5th) field instead of `in-membrane`.
while IFS='|' read -r _ file _ _ status _; do
  file=$(trim "$file")
  status=$(trim "$status")
  [[ -z "$file" || "$file" == "File" || "$file" =~ ^-+$ ]] && continue
  case "$status" in
    "In sync"|"Skipped (PERSONAL)") continue ;;
  esac

  essence=""
  section=""
  token=""
  case "$status" in
    *"no baseline"*)
      # Checked before "cast needed"/"fold candidate" since forge-status.sh's
      # no-baseline diff status doesn't contain either substring — ambiguous
      # direction, route to CONFLICTS per preflight.md's safety doctrine.
      section="CONF"; token="CONFLICT (no-baseline)"
      essence="_model fills_ — no baseline; diff <forge>/memory/$file vs <membrane>/memory/$file manually"
      ;;
    *"cast needed"*)
      section="INC"; token="FORGE-UPDATED"
      essence="_model fills_ — diff <forge>/memory/$file vs <membrane>/memory/$file"
      ;;
    *"fold candidate"*)
      section="OUT"; token="DEPLOYED-DIFFERS"
      essence="_model fills_ — diff <forge>/memory/$file vs <membrane>/memory/$file"
      ;;
    *)
      section="CONF"; token="UNRECOGNIZED"
      essence="_model fills_ — unrecognized memory status \"$status\", verify manually"
      ;;
  esac

  row="memory${ROWSEP}${file}${ROWSEP}${token}${ROWSEP}${essence}"
  case "$section" in
    INC) INC+=("$row") ;;
    OUT) OUT+=("$row") ;;
    CONF) CONF+=("$row") ;;
  esac
done < <(printf '%s\n' "$MEMORY_SECTION" | grep '^| ' | awk -F'|' 'NF==6')

# Forge-only memories (cast candidates) — description is mechanically
# available, so this is the one memory case with a real essence line.
while IFS='|' read -r _ file desc _; do
  file=$(trim "$file")
  desc=$(trim "$desc")
  [[ -z "$file" || "$file" == "File" || "$file" =~ ^-+$ ]] && continue
  row="memory${ROWSEP}${file}${ROWSEP}ADDED${ROWSEP}${desc}"
  INC+=("$row")
done < <(printf '%s\n' "$FORGEONLY_BLOCK" | grep '^| ' | awk -F'|' 'NF==4')

# --- Step 7: render ---
TOTAL=$(( ${#INC[@]} + ${#OUT[@]} + ${#CONF[@]} ))

echo "forge @ ${FORGE_SHA} ⇄ membrane @ ${BASELINE_LABEL:0:7}    ${TOTAL} items"
echo ""

if [[ $TOTAL -eq 0 ]]; then
  echo "✓ Membrane synced."
  exit 0
fi

render_section() {
  local heading="$1" start_n="$2"
  shift 2
  local rows=("$@")
  local n=$start_n
  for row in "${rows[@]}"; do
    IFS="$ROWSEP" read -r type name token essence <<< "$row"
    printf '  [ ] %-2d %-10s %-22s %s\n' "$n" "$type" "$name" "$token"
    printf '         → %s\n' "$essence"
    n=$((n + 1))
  done
}

n=1
if [[ ${#INC[@]} -gt 0 ]]; then
  echo "↓ INCOMING (forge → you) — ${#INC[@]} items"
  render_section "INCOMING" "$n" "${INC[@]}"
  n=$((n + ${#INC[@]}))
  echo ""
fi

if [[ ${#OUT[@]} -gt 0 ]]; then
  echo "↑ OUTGOING (you → forge) — ${#OUT[@]} items"
  render_section "OUTGOING" "$n" "${OUT[@]}"
  n=$((n + ${#OUT[@]}))
  echo ""
fi

if [[ ${#CONF[@]} -gt 0 ]]; then
  echo "⚠ CONFLICTS (both changed) — ${#CONF[@]} items"
  render_section "CONFLICTS" "$n" "${CONF[@]}"
  n=$((n + ${#CONF[@]}))
  echo ""
fi

echo "  [a]ll  [N] toggle  [v N] view  [ENTER] apply  [q]uit"

# --- Step 8: footnotes for mechanically-skipped-but-not-silent cases ---
AMBIGUOUS_TITLES=$(printf '%s\n' "$LEARNING_SECTION" | grep '^| ' | awk -F'|' '
  NF==6 {
    file=$2; status=$5
    gsub(/^[ \t]+|[ \t]+$/,"",file); gsub(/^[ \t]+|[ \t]+$/,"",status)
    if (file=="File" || file ~ /^-+$/) next
    if (status ~ /Content differs but all titles accounted for/) print file
  }')
if [[ -n "$AMBIGUOUS_TITLES" ]]; then
  echo ""
  echo "Note: titles match but raw content differs (no per-entry route available) in:"
  while IFS= read -r f; do
    [[ -n "$f" ]] && echo "  - $f — inspect manually if needed"
  done <<< "$AMBIGUOUS_TITLES"
fi
