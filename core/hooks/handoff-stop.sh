#!/usr/bin/env bash
#
# Stop hook — the trigger half of opt-in auto-handoff.
#
# A session opts in with `/handoff on <name>`; when its work is done the model
# runs `/handoff`, which writes <root>/pane-<N>.md (the note) and a per-pane
# "ready" marker. When the turn then ends, this hook consumes the marker and
# schedules a fully detached job that types `/clear <name>` and, once the fresh
# context has had the note injected and is idle, `/rename <name>` and then a
# resume prompt into the session's own tmux pane. /rename is needed because
# Claude Code titles a cleared session from its first prompt and /clear's
# argument does not set the title. The SessionStart(clear) twin, handoff-start.sh,
# injects the note in between.
#
# Why keystrokes: there is no hook decision that clears context. Typing
# `/clear <name>` (the name keeps the session's messaging address) into the
# pane is the only path, so this script is security-sensitive and every typing
# step is fenced:
#   - it acts only on $TMUX_PANE, the pane this Claude process runs in;
#   - only with a VALID opt-in: recorded pane_pid == live pane_pid AND the
#     recorded claude_pid is alive AND is the Claude Code ancestor of this hook
#     (a reused pane id, or a new Claude started in the same shell, never
#     inherits an opt-in);
#   - before every keystroke batch the job re-checks: token present and still
#     carrying THIS job's id (cancel; a cancel + re-handoff leaves only the new
#     job alive), opt-in still valid, that Claude pid alive and still `claude`,
#     the pane's foreground command is Claude, the pane is not in copy mode,
#     and the input box is the LAST box on screen, empty and not busy;
#   - before `/clear` the transcript bytes appended since the Stop hook started
#     must be quiet. Allowlist, everything else is activity: only the types
#     last-prompt, custom-title, agent-name, mode, permission-mode, atis-latch,
#     cost-state, bridge-session, artifact-comment-monitor and system (any
#     subtype) are ignored, plus `assistant` lines
#     whose timestamp is <= the Stop hook's start + 2 s (the turn's own final
#     message). user, attachment, queue-operation, progress, api-request*,
#     file-history-snapshot, unknown types, a late assistant line, an
#     unparseable complete line, or a shrunk/missing file abort. The appended
#     range is read ONCE into a buffer and a trailing partial line is dropped
#     from that same buffer. The screen check is secondary;
#   - typing is verified, never blind: `send-keys -l` (literal) types only a
#     regex-validated name (in /clear and /rename) or the fixed resume prompt; 0.3 s later the input
#     box must hold exactly that text (whitespace-normalised across wrapped
#     lines) or Enter is NOT sent and the text is left as is (nothing is ever
#     erased); after Enter the box must be empty again within 2.5 s, or the
#     step counts as failed (`Enter swallowed`) and nothing further happens;
#   - lastclear is written only after `/clear` is confirmed submitted;
#   - the resume prompt is typed only if handoff-start.sh left an `injected`
#     marker (the note really reached the new context) AND the new transcript
#     shows no user activity since the clear (lines of the clear itself, i.e.
#     user / attachment / file-history-snapshot timestamped <= injection + 2 s,
#     are tolerated, except a user line with promptId/promptSource/turnOrigin,
#     which is a real prompt; any assistant line is activity). The guard runs
#     before `/rename <name>` is typed, then the pane must be idle again
#     (up to ~5 tries) before the resume prompt;
#   - loop guard: no schedule if this pane was auto-cleared less than
#     HANDOFF_MIN_INTERVAL seconds ago (the helper refuses to set the ready
#     marker in that window too; this is defence in depth).
# Wrong-abort costs the user one manual /clear; wrong-type corrupts their input.
#
# Why detached: Claude Code waits on the hook's stdout, and the /clear cannot
# be typed until the turn has actually ended and the prompt redrawn. The job
# re-execs this file (`--job`) under `setsid -f` with all three std streams on
# /dev/null; the hook itself prints nothing and exits 0 at once. It never emits
# `decision: block`.
#
# Fail open: any unexpected state → exit 0, no output, nothing typed.
#
# State (shared contract with the /handoff helper and handoff-start.sh):
#   root  ${HANDOFF_DIR:-$HOME/.claude/handoffs}, state dir <root>/state
#   <root>/pane-<N>.md   the note                                   (helper)
#   pane-<N>.optin       name= / pane_pid= / claude_pid=            (helper)
#   pane-<N>.ready       name= / epoch=                             (helper)
#   pane-<N>.clearing    epoch= / id= / name= / claude_pid=  (this hook; consumed by start hook)
#   pane-<N>.injected    epoch= / at= / transcript= / size=  (start hook; consumed by the job)
#   pane-<N>.lastclear   epoch=                     (job, once /clear is confirmed submitted)
#   handoff.log          one line per decision
# Env: HANDOFF_TMUX (default `tmux`, word-split; tests use `tmux -L <sock>`),
#      HANDOFF_DELAY (default 3 s before the first check),
#      HANDOFF_POLL_TRIES (default 4 idle checks 1 s apart before /clear),
#      HANDOFF_READY_TTL (default 900 s; older ready markers are dropped),
#      HANDOFF_MIN_INTERVAL (default 600 s between auto-clears of one pane).
#
# settings.json: Stop, no matcher.

# Captured first: the Stop start time bounds which assistant lines are the
# turn's own (see tx_quiet).
STOP_T="$(date +%s.%N 2>/dev/null)"
[[ "$STOP_T" =~ ^[0-9]+(\.[0-9]+)?$ ]] || STOP_T="$(date +%s)"

set -uo pipefail
export LC_ALL=C   # byte semantics: ASCII-only name regex, literal ❯/─ prefix tests
umask 077

ROOT="${HANDOFF_DIR:-$HOME/.claude/handoffs}"
STATE="$ROOT/state"
LOG="$STATE/handoff.log"
NAME_RE='^[A-Za-z0-9][A-Za-z0-9._ -]{0,63}$'
PROMPT_CHAR=$'\xe2\x9d\xaf'   # ❯ U+276F
BORDER_CHAR=$'\xe2\x94\x80'   # ─ U+2500
NBSP=$'\xc2\xa0'              # Claude Code renders the empty prompt as "❯" + U+00A0
RESUME_PROMPT='[auto-handoff] Context was cleared by the handoff hook, not typed by the user. Resume from the injected handoff: re-arm any session-only state it lists, then continue with its next task. Do not run /handoff in this turn.'
ELLIPSIS=$'\xe2\x80\xa6'      # … U+2026, in the working spinner "Computing… (40s"
SPIN_RE="${ELLIPSIS}[[:space:]]*\\([0-9]"
BG_RE='[0-9]+ (shells?|(background )?tasks?)'   # footer background-task segment
GRACE=2                       # seconds of timestamp slack in tx_quiet

num_or() { [[ "$1" =~ ^[0-9]{1,6}$ ]] && printf '%s' "$1" || printf '%s' "$2"; }
DELAY="$(num_or "${HANDOFF_DELAY:-3}" 3)"
POLL_TRIES="$(num_or "${HANDOFF_POLL_TRIES:-4}" 4)"
READY_TTL="$(num_or "${HANDOFF_READY_TTL:-900}" 900)"
MIN_INTERVAL="$(num_or "${HANDOFF_MIN_INTERVAL:-600}" 600)"
POST_CLEAR_TRIES=20           # ~20 s for the injected marker + idle screen

read -r -a TMUXC <<< "${HANDOFF_TMUX:-tmux}"
[ "${#TMUXC[@]}" -gt 0 ] || TMUXC=(tmux)

PANE="" N="" NAME="-" CPID="" TID="" PANE_WHY=""

log() {
  mkdir -p "$STATE" 2>/dev/null || return 0
  printf '%s handoff-stop pane=%s name=%s %s\n' \
    "$(date +%FT%T%z 2>/dev/null)" "${PANE:-?}" "${NAME:--}" "$*" >> "$LOG" 2>/dev/null
}

# value of key=... from a state file (first match only)
kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n 1; }

valid_name() { [[ "$1" =~ $NAME_RE ]] && [[ "$1" != *" " ]]; }

# 0 iff pid is a live Claude Code process: comm `claude`, or `node` running claude.
is_claude_pid() {
  local comm args
  [[ "${1:-}" =~ ^[0-9]+$ ]] || return 1
  comm="$(ps -o comm= -p "$1" 2>/dev/null)" || return 1
  [ "$comm" = claude ] && return 0
  [ "$comm" = node ] || return 1
  args="$(ps -o args= -p "$1" 2>/dev/null)" || return 1
  [[ "$args" == *claude* ]]
}

# Walk up from this process to the nearest Claude Code ancestor; print its pid.
claude_ancestor() {
  local pid=$$ i ppid
  for ((i = 0; i < 10; i++)); do
    ppid="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')"
    [[ "$ppid" =~ ^[0-9]+$ ]] && [ "$ppid" -gt 1 ] || return 1
    if is_claude_pid "$ppid"; then printf '%s' "$ppid"; return 0; fi
    pid="$ppid"
  done
  return 1
}

live_pane_pid() { "${TMUXC[@]}" display-message -p -t "$PANE" '#{pane_pid}' 2>/dev/null; }

# Opt-in is valid iff pane_pid matches the live one AND its claude_pid is a live
# Claude AND equals $CPID (the Claude this hook / job is bound to).
# Prints the opt-in name on success.
optin_name() {
  local f="$STATE/pane-$N.optin" want live nm cp
  [ -f "$f" ] || return 1
  want="$(kv "$f" pane_pid)"
  nm="$(kv "$f" name)"
  cp="$(kv "$f" claude_pid)"
  live="$(live_pane_pid)"
  [ -n "$want" ] && [ -n "$live" ] && [ "$want" = "$live" ] || return 1
  [ -n "$cp" ] && [ "$cp" = "$CPID" ] && is_claude_pid "$cp" || return 1
  valid_name "$nm" || return 1
  printf '%s' "$nm"
}

# 0 iff the bound Claude is alive, is the pane's foreground command, and the
# pane is not in copy/view mode. Logs the reason on failure.
proc_ok() {
  local out cmd mode
  is_claude_pid "$CPID" || { log "job: claude pid $CPID gone or not claude"; return 1; }
  out="$("${TMUXC[@]}" display-message -p -t "$PANE" '#{pane_current_command} #{pane_in_mode}' 2>/dev/null)" \
    || { log "job: pane gone"; return 1; }
  cmd="${out% *}"; mode="${out##* }"
  case "$cmd" in
    claude) ;;
    node) ;;   # $CPID already passed the node-args check above
    *) log "job: pane foreground is '$cmd', not claude"; return 1 ;;
  esac
  [ "$mode" = 0 ] || { log "job: pane in copy/view mode"; return 1; }
  return 0
}

# strip every space, tab and NBSP (whitespace normalisation for wrapped text)
squash() { local s="${1//"$NBSP"/}"; s="${s//$'\t'/}"; printf '%s' "${s// /}"; }

# Locate the input box, which must be the LAST box on screen:
#   top border (─...) / "❯" line / continuation lines (wrapped input) /
#   bottom border (─...) / footer lines only (no further ─ line).
# Sets BOX_RAW (the ❯ line, trailing space/tab/NBSP stripped), BOX_N (number
# of content lines), BOX_TEXT (content after ❯ joined across lines, all
# whitespace removed), BOX_BUSY (1 iff the spinner shows in the 4 lines above the
# top border ("…" + "(<digit>", or "esc to interrupt"), or the footer says "esc
# to interrupt" WITHOUT a "N shell(s)" / "N task(s)" segment: with a background
# shell running the footer keeps that text while idle), BOX_SIGNAL (which fired).
# Returns 0 found, 1 no well-formed last box, 2 pane gone.
read_box() {
  local cap i p=-1 q=-1 n s
  local -a lines
  BOX_RAW="" BOX_N=0 BOX_TEXT="" BOX_BUSY=0 BOX_SIGNAL=""
  cap="$("${TMUXC[@]}" capture-pane -p -t "$PANE" 2>/dev/null)" || return 2
  mapfile -t lines <<< "$cap"
  n="${#lines[@]}"
  for ((i = n - 1; i >= 0; i--)); do
    [[ "${lines[$i]}" == "$PROMPT_CHAR"* ]] && { p=$i; break; }
  done
  [ "$p" -ge 1 ] || return 1
  [[ "${lines[$((p - 1))]}" == "$BORDER_CHAR"* ]] || return 1
  for ((i = p + 1; i < n; i++)); do
    [[ "${lines[$i]}" == "$BORDER_CHAR"* ]] && { q=$i; break; }
  done
  [ "$q" -gt "$p" ] || return 1
  local f_esc=0 f_bg=0 spin=0
  for ((i = q + 1; i < n; i++)); do
    [[ "${lines[$i]}" == "$BORDER_CHAR"* ]] && return 1
    [[ "${lines[$i]}" == *"esc to interrupt"* ]] && f_esc=1
    [[ "${lines[$i]}" =~ $BG_RE ]] && f_bg=1
  done
  # Footer: "esc to interrupt" stays on screen while only a background shell/task
  # runs, so with a shell/task segment present the spinner alone decides.
  if [ "$f_esc" -eq 1 ] && [ "$f_bg" -eq 0 ]; then
    BOX_BUSY=1; BOX_SIGNAL="footer"
  fi
  # Spinner: up to 4 lines above the top border ("✽ Computing… (40s · ...").
  for ((i = p - 5; i < p - 1; i++)); do
    [ "$i" -ge 0 ] || continue
    if [[ "${lines[$i]}" == *"esc to interrupt"* ]] || [[ "${lines[$i]}" =~ $SPIN_RE ]]; then
      spin=1
    fi
  done
  if [ "$spin" -eq 1 ]; then
    if [ "$BOX_BUSY" -eq 1 ]; then BOX_SIGNAL="footer+spinner"; else BOX_SIGNAL="spinner"; fi
    BOX_BUSY=1
  fi
  s="${lines[$p]}"
  while :; do
    case "$s" in
      *" ")     s="${s% }" ;;
      *$'\t')   s="${s%$'\t'}" ;;
      *"$NBSP") s="${s%"$NBSP"}" ;;
      *) break ;;
    esac
  done
  BOX_RAW="$s"
  BOX_N=$((q - p))
  s="${lines[$p]#"$PROMPT_CHAR"}"
  for ((i = p + 1; i < q; i++)); do s+="${lines[$i]}"; done
  BOX_TEXT="$(squash "$s")"
  return 0
}

# Idle check: last box, single empty line, not busy.
# 0 = idle with an empty input box. 1 = not (busy, text, ambiguous). 2 = pane gone.
pane_state() {
  local rc
  PANE_WHY=""
  read_box; rc=$?
  case "$rc" in
    0) ;;
    2) PANE_WHY="pane gone"; return 2 ;;
    *) PANE_WHY="input box not the last box on screen"; return 1 ;;
  esac
  [ "$BOX_BUSY" -eq 0 ] || { PANE_WHY="busy (${BOX_SIGNAL:-unknown} signal)"; return 1; }
  if ! { [ "$BOX_N" -eq 1 ] && [ -z "$BOX_TEXT" ]; }; then
    local ex="${BOX_TEXT//[^[:print:]]/}"
    ex="${ex//\'/\"}"
    PANE_WHY="input not empty (lines=$BOX_N text='${ex:0:40}')"
    return 1
  fi
  return 0
}

# tx_quiet PATH BASE CUTOFF GRACED_JSON MISSING_OK
# 0 iff nothing but Claude Code's own writes was appended to PATH after byte
# BASE. Ignored: types last-prompt, custom-title, agent-name, mode,
# permission-mode, atis-latch, cost-state, bridge-session,
# artifact-comment-monitor (session metadata, no timestamp, written at the top
# of a new transcript when Remote Control / artifacts are active), system (any
# subtype); and lines
# whose type is in GRACED_JSON (a JSON array) with a timestamp (.timestamp, or
# .snapshot.timestamp) <= CUTOFF (epoch seconds, fractional ok). A user line
# carrying promptId / promptSource / turnOrigin is a real prompt and is
# activity whatever its timestamp (the clear's own user lines carry none).
# Everything else, including an unparseable complete line, is activity. The range is read
# ONCE; a trailing partial line in that buffer is dropped. A shrunk file is
# activity; a missing file is activity unless MISSING_OK=1 and BASE=0.
tx_quiet() {
  local path="$1" base="$2" cut="$3" graced="$4" missing_ok="${5:-0}" size buf bad rc
  if [ ! -e "$path" ]; then
    [ "$missing_ok" = 1 ] && [ "$base" -eq 0 ] && return 0
    return 1
  fi
  size="$(stat -c %s "$path" 2>/dev/null)" || return 1
  [[ "$size" =~ ^[0-9]+$ ]] || return 1
  [ "$size" -lt "$base" ] && return 1
  [ "$size" -eq "$base" ] && return 0
  buf="$(mktemp "$STATE/.tx.XXXXXX" 2>/dev/null)" || return 1
  if ! tail -c +"$((base + 1))" "$path" > "$buf" 2>/dev/null; then rm -f "$buf"; return 1; fi
  if [ -s "$buf" ] && [ "$(tail -c 1 "$buf" | wc -l)" -eq 0 ]; then
    sed -i '$d' "$buf" 2>/dev/null || { rm -f "$buf"; return 1; }
  fi
  bad="$(jq -rR --arg cut "$cut" --argjson g "$graced" '
    def tsnum:
      if type == "string" then
        (capture("^(?<s>[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2})(\\.(?<f>[0-9]+))?Z$") // null)
        | if . == null then null
          else ((.s + "Z") | fromdateiso8601) + (("0." + (.f // "0")) | tonumber) end
      else null end;
    ($cut | tonumber) as $c
    | (try fromjson catch null) as $o
    | if ($o | type) != "object" then "x"
      elif ($o.type | IN("last-prompt", "custom-title", "agent-name", "mode",
                         "permission-mode", "atis-latch", "cost-state", "system",
                         "bridge-session", "artifact-comment-monitor")) then empty
      elif $o.type == "user" and ($o | has("promptId") or has("promptSource") or has("turnOrigin")) then "x"
      elif ($o.type | IN($g[])) then
        (($o.timestamp // ($o.snapshot | objects | .timestamp) // null) | tsnum) as $t
        | if $t != null and $t <= $c then empty else "x" end
      else "x" end
  ' "$buf" 2>/dev/null)"; rc=$?
  rm -f "$buf"
  [ "$rc" -eq 0 ] && [ -z "$bad" ]
}

# Remove the clearing token only if it is still this job's (a newer job's
# token must survive a stale job's abort).
drop_token() { [ -f "$TOKEN" ] && [ "$(kv "$TOKEN" id)" = "$TID" ] && rm -f "$TOKEN"; return 0; }

abort() { log "job: $*, abort"; drop_token; exit 0; }

# Every precondition shared by both typing steps.
# The token check is the cancel path: /handoff cancel or off deletes it, and a
# re-handoff replaces it with a new id.
precheck() {
  local on
  [ -f "$TOKEN" ] && [ "$(kv "$TOKEN" name)" = "$NAME" ] && [ "$(kv "$TOKEN" id)" = "$TID" ] \
    || { log "job: token gone or changed (cancelled or superseded), abort"; exit 0; }
  proc_ok || abort "process check failed"
  on="$(optin_name)" || abort "opt-in no longer valid"
  [ "$on" = "$NAME" ] || abort "opt-in name changed to '$on'"
}

# type_verified TEXT
#   send-keys -l TEXT; after 0.3 s the last box must hold exactly TEXT
#   (single line: "❯" + space/NBSP + TEXT; wrapped: content joined, all
#   whitespace removed, equal to TEXT likewise), else no Enter and the text is
#   left in place. Then Enter, and the box must be empty again within 2.5 s.
# 0 submitted, 1 send-keys failed, 2 box does not hold the text (no Enter
# sent), 3 pane gone after Enter, 4 Enter swallowed or not submitted.
type_verified() {
  local text="$1" t rc ok=1
  "${TMUXC[@]}" send-keys -t "$PANE" -l "$text" 2>/dev/null || return 1
  sleep 0.3
  read_box; rc=$?
  if [ "$rc" -eq 0 ]; then
    if [ "$BOX_N" -eq 1 ]; then
      [ "$BOX_RAW" = "$PROMPT_CHAR $text" ] || [ "$BOX_RAW" = "$PROMPT_CHAR$NBSP$text" ] && ok=0
    else
      [ "$BOX_TEXT" = "$(squash "$text")" ] && ok=0
    fi
  fi
  [ "$ok" -eq 0 ] || return 2
  "${TMUXC[@]}" send-keys -t "$PANE" Enter 2>/dev/null || return 4
  for ((t = 0; t < 10; t++)); do
    sleep 0.25
    read_box; rc=$?
    [ "$rc" -eq 2 ] && return 3
    # busy is fine here (the resume prompt starts a turn); only the box matters
    [ "$rc" -eq 0 ] && [ "$BOX_N" -eq 1 ] && [ -z "$BOX_TEXT" ] && return 0
  done
  return 4
}

type_fail_msg() {
  case "$1" in
    1) printf 'send-keys failed' ;;
    2) printf 'aborted: input box does not hold exactly the typed text (Enter not sent, text left)' ;;
    3) printf 'pane gone after Enter' ;;
    *) printf 'Enter swallowed or not submitted' ;;
  esac
}

# ---------------------------------------------------------------- job path --
run_job() {
  trap '' HUP
  PANE="${1:-}"; NAME="${2:-}"; CPID="${3:-}"; TPATH="${4:-}"; TBASE="${5:-}"; TSTOP="${6:-}"; TID="${7:-}"
  [[ "$PANE" =~ ^%[0-9]+$ ]] || exit 0
  N="${PANE#%}"
  TOKEN="$STATE/pane-$N.clearing"
  local injected="$STATE/pane-$N.injected" t rc ie ia it is clear_epoch on
  valid_name "$NAME" || { NAME="-"; log "job: invalid name, abort"; exit 0; }
  [[ "$TID" =~ ^[0-9]+\.[0-9]+$ ]] || { log "job: bad job id, abort"; exit 0; }
  [[ "$CPID" =~ ^[0-9]+$ ]] && [[ "$TBASE" =~ ^[0-9]+$ ]] && [[ "$TSTOP" =~ ^[0-9]+(\.[0-9]+)?$ ]] \
    && [ -n "$TPATH" ] || abort "bad job arguments"
  log "job: started, sleeping ${DELAY}s"
  sleep "$DELAY"

  # Idle check before /clear: a few tries over ~POLL_TRIES s, no long wait.
  rc=1
  for ((t = 0; t < POLL_TRIES; t++)); do
    precheck
    pane_state; rc=$?
    [ "$rc" -eq 0 ] && break
    [ "$rc" -eq 2 ] && abort "pane gone"
    sleep 1
  done
  [ "$rc" -eq 0 ] || abort "aborted: pane not idle after ${POLL_TRIES} checks: ${PANE_WHY:-unknown}"

  # Final re-check immediately before typing; transcript last.
  precheck
  pane_state || abort "aborted: pane not idle at final re-check: ${PANE_WHY:-unknown}"
  tx_quiet "$TPATH" "$TBASE" "$(awk -v a="$TSTOP" -v g="$GRACE" 'BEGIN { printf "%.3f", a + g }')" '["assistant"]' 0 \
    || abort "aborted: new activity in transcript"
  rm -f "$injected"
  clear_epoch="$(date +%s)"
  type_verified "/clear $NAME"; rc=$?
  [ "$rc" -eq 0 ] || abort "$(type_fail_msg "$rc") (/clear)"
  printf 'epoch=%s\n' "$clear_epoch" > "$STATE/pane-$N.lastclear" 2>/dev/null
  log "job: typed /clear + Enter, submitted"

  # Post-clear: wait for the start hook's injected marker AND an idle screen.
  # (The token is consumed by then, so precheck's token test does not apply.)
  for ((t = 0; t < POST_CLEAR_TRIES; t++)); do
    sleep 1
    [ -f "$injected" ] || continue
    pane_state; rc=$?
    [ "$rc" -eq 2 ] && { log "job: pane gone after clear, stop"; exit 0; }
    [ "$rc" -eq 0 ] && break
  done
  if [ ! -f "$injected" ]; then
    drop_token
    log "job: no injected marker, resume prompt not typed"; exit 0
  fi
  [ "$rc" -eq 0 ] || { rm -f "$injected"; log "job: not idle after clear (${PANE_WHY:-unknown}), resume prompt not typed"; exit 0; }
  ie="$(kv "$injected" epoch)"; ia="$(kv "$injected" at)"
  it="$(kv "$injected" transcript)"; is="$(kv "$injected" size)"
  rm -f "$injected"
  if ! [[ "$ie" =~ ^[0-9]+$ ]] || [ "$ie" -lt "$((clear_epoch - 1))" ]; then
    log "job: injected marker stale, resume prompt not typed"; exit 0
  fi
  on="$(optin_name)" || { log "job: opt-in no longer valid after clear, resume prompt not typed"; exit 0; }
  [ "$on" = "$NAME" ] || { log "job: opt-in name changed after clear, resume prompt not typed"; exit 0; }
  proc_ok || { log "job: process check failed after clear, resume prompt not typed"; exit 0; }
  pane_state || { log "job: pane not idle at resume re-check (${PANE_WHY:-unknown}), resume prompt not typed"; exit 0; }
  # Resume guard: the user may already have started a turn in the new context.
  if [ -z "$it" ] || ! [[ "$is" =~ ^[0-9]+$ ]] || ! [[ "$ia" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    log "job: resume skipped: injected marker has no transcript/size/at"; exit 0
  fi
  tx_quiet "$it" "$is" "$(awk -v a="$ia" -v g="$GRACE" 'BEGIN { printf "%.3f", a + g }')" \
    '["user","attachment","file-history-snapshot"]' 1 \
    || { log "job: resume skipped: user already active"; exit 0; }
  # Restore the session name: Claude Code titles a cleared session from its first
  # prompt ("Auto-handoff context resume"); /clear's argument does not set it.
  # The guard above ran first, so /rename's own transcript lines are never
  # mistaken for user activity.
  type_verified "/rename $NAME"; rc=$?
  [ "$rc" -eq 0 ] || { log "job: $(type_fail_msg "$rc") (/rename), resume prompt not typed"; exit 0; }
  log "job: typed /rename + Enter, submitted"
  rc=1
  for ((t = 0; t < 5; t++)); do
    sleep 0.7
    pane_state; rc=$?
    [ "$rc" -eq 0 ] && break
    [ "$rc" -eq 2 ] && { log "job: pane gone after /rename, stop"; exit 0; }
  done
  [ "$rc" -eq 0 ] || { log "job: not idle after /rename (${PANE_WHY:-unknown}), resume prompt not typed"; exit 0; }
  proc_ok || { log "job: process check failed after /rename, resume prompt not typed"; exit 0; }
  type_verified "$RESUME_PROMPT"; rc=$?
  [ "$rc" -eq 0 ] || { log "job: $(type_fail_msg "$rc") (resume prompt), stop"; exit 0; }
  log "job: typed resume prompt + Enter, submitted, done"
  exit 0
}

if [ "${1:-}" = "--job" ]; then
  shift
  run_job "$@"
fi

# --------------------------------------------------------------- hook path --
payload="$(cat 2>/dev/null)"

active="$(printf '%s' "$payload" | jq -r '.stop_hook_active // false' 2>/dev/null)"
[ "$active" = "true" ] && exit 0

# Cheap early exits, silent.
[ -n "${TMUX_PANE:-}" ] || exit 0
[[ "$TMUX_PANE" =~ ^%[0-9]+$ ]] || exit 0
PANE="$TMUX_PANE"
N="${PANE#%}"
ready="$STATE/pane-$N.ready"
[ -f "$ready" ] || exit 0
command -v "${TMUXC[0]}" >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

# Claim the marker atomically: only one Stop firing can win the mv.
claimed="$ready.claim.$$"
mv -f "$ready" "$claimed" 2>/dev/null || exit 0
rname="$(kv "$claimed" name)"
repoch="$(kv "$claimed" epoch)"
rm -f "$claimed"
NAME="${rname:--}"
now="$(date +%s)"

if ! [[ "$repoch" =~ ^[0-9]+$ ]] || [ $((now - repoch)) -gt "$READY_TTL" ] || [ $((now - repoch)) -lt -5 ]; then
  log "ready marker stale or malformed (epoch=${repoch:-none}, ttl ${READY_TTL}s), dropped"; exit 0
fi
CPID="$(claude_ancestor)" || { log "no Claude Code ancestor process, ready marker dropped"; exit 0; }
if ! on="$(optin_name)"; then log "no valid opt-in (missing, pane/claude pid mismatch or bad name), ready marker dropped"; exit 0; fi
if [ "$rname" != "$on" ]; then log "ready name != opt-in name '$on', ready marker dropped"; exit 0; fi
NAME="$on"
if [ ! -s "$ROOT/pane-$N.md" ]; then log "note pane-$N.md missing or empty, ready marker dropped"; exit 0; fi

last="$(kv "$STATE/pane-$N.lastclear" epoch)"
if [[ "$last" =~ ^[0-9]+$ ]] && [ $((now - last)) -lt "$MIN_INTERVAL" ]; then
  log "loop guard: last auto-clear $((now - last))s ago (< ${MIN_INTERVAL}s), not scheduling"; exit 0
fi

tpath="$(printf '%s' "$payload" | jq -r '.transcript_path // empty' 2>/dev/null)"
[ -n "$tpath" ] && [ -f "$tpath" ] || { log "no readable transcript_path in payload, not scheduling"; exit 0; }
tsize="$(stat -c %s "$tpath" 2>/dev/null)"
[[ "$tsize" =~ ^[0-9]+$ ]] || { log "cannot stat transcript, not scheduling"; exit 0; }
command -v setsid >/dev/null 2>&1 || { log "setsid not found, not scheduling"; exit 0; }
command -v awk >/dev/null 2>&1 || { log "awk not found, not scheduling"; exit 0; }

token="$STATE/pane-$N.clearing"
tmp="$token.tmp.$$"
TID="$(date +%s%N 2>/dev/null).$$"
[[ "$TID" =~ ^[0-9]+\.[0-9]+$ ]] || TID="$now$RANDOM$RANDOM.$$"
rm -f "$STATE/pane-$N.injected"
if ! printf 'epoch=%s\nid=%s\nname=%s\nclaude_pid=%s\n' "$now" "$TID" "$NAME" "$CPID" > "$tmp" 2>/dev/null || ! mv -f "$tmp" "$token" 2>/dev/null; then
  rm -f "$tmp"; log "could not write clearing token, not scheduling"; exit 0
fi

self="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null)"
[ -n "$self" ] || { rm -f "$token"; log "cannot resolve own path, not scheduling"; exit 0; }
if ! setsid -f bash "$self" --job "$PANE" "$NAME" "$CPID" "$tpath" "$tsize" "$STOP_T" "$TID" </dev/null >/dev/null 2>&1; then
  rm -f "$token"; log "setsid failed, token removed, not scheduling"; exit 0
fi
log "scheduled clear job (delay ${DELAY}s, claude pid $CPID)"
exit 0
