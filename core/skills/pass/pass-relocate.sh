#!/usr/bin/env bash
#
# pass-relocate.sh — moves a Claude Code BACKGROUND-JOB session into a tmux pane
# so /pass can clear it. Three roles, one file:
#
#   1. Library. `PASS_RELOCATE_LIB=1 source pass-relocate.sh` (pass.sh does this)
#      defines the rl_* functions only: rl_detect (is this session a background
#      job?) and rl_target (which pane may receive it, decided from tmux and
#      `claude agents --json`). pass.sh decides synchronously with them so the
#      reason reaches the caller; the job re-runs rl_target before acting.
#      rl_target never accepts a shell: no window of the session's name means a
#      new window; one single-pane window holding a PROVEN leftover view of this
#      session (rl_view_proof) is respawned in place; anything else is refused.
#   2. Job. `pass-relocate.sh --job <session uuid> <job id>`, started detached
#      (systemd-run --user first, setsid -f as fallback) by `pass.sh write`. It
#      reads state/relocate-<uuid>.req (ignored and removed after 3600 s), then:
#        a. waits for the turn to end (agents entry idle, transcript quiet for
#           PASS_DELAY s; any new activity aborts; hard cap PASS_RELOCATE_WAIT),
#        b. reads model + permission mode from the transcript (strict regexes;
#           anything but a recorded safe mode becomes `manual`),
#        c. takes a non-blocking per-window flock, re-validates the target, applies
#           the loop guard to an existing pane, checks the view is idle with an
#           empty input box (recording the pane pid and the view's Claude pid), and
#           that the background Claude has no shell child,
#        d. `claude stop <short id>` and waits for the process to be gone (a stop
#           that does not land in time is a rl_fail: it may still land),
#        e. decides from the recorded pids what the stop did to the view: still
#           running (a list screen) or exited to the pane's shell -> `tmux
#           respawn-pane -k -c <cwd> -e PASS_DIR=.. -- bash pass-relocate.sh
#           --run-claude ...`; pane gone -> `tmux new-window -d ...` (if the name is
#           free); anything else -> rl_fail. Claude is started by argument list, no
#           key is ever sent to start it,
#        f. waits for an idle input box,
#        g. writes pane-N.optin, moves the note to pane-N.md, removes the request,
#        h. unless the pane was auto-cleared recently (loop guard), writes the
#           clearing token and execs the Stop hook's `--job`, which types
#           `/clear <name>`, `/rename <name>` and the resume prompt, verified.
#      Every step re-checks that the request file still exists and carries this
#      job id: `/pass cancel` removes it, a newer /pass replaces it. Every exit
#      after the stop succeeded goes through rl_fail: it logs and writes to
#      relocate/<uuid>.failed `resume with: cd <cwd> && claude --resume <uuid>`
#      and runs $PASS_NOTIFY (one executable path) if set.
#   3. `--run-claude <claude args>`: what the relocated pane runs. It runs Claude
#      (own process group, so the pane's foreground command is `claude`) through
#      the user's interactive login bash/zsh (`$SHELL -lic '"$0" "$@"; <fg loop>'`,
#      so profile and PATH apply; any other $SHELL: a plain interactive bash).
#      That shell owns job control: after Ctrl+Z its own `fg` brings Claude back
#      until it has exited. When Claude exits the wrapper shows the .failed line
#      for the resumed uuid if there is one, then execs the login shell.
#
# Fail open: any unexpected state logs one line (prefix pass-relocate) to
# state/pass.log, leaves the saved note in place and exits 0. The only keys ever
# sent are the Stop hook's own verified `--job` typing; text in a pane is never
# erased and no Ctrl+C is sent.
#
# State: <root>/relocate/<uuid>.md (note), <root>/state/relocate-<uuid>.req
# (name= sid= short= cwd= pane= explicit= epoch= job= bgpid= title=),
# <root>/state/relocate-window-<name>.lock.
# Env: PASS_CLAUDE (claude binary, word-split like PASS_TMUX), PASS_TMUX,
#      PASS_STOP_HOOK (hook path), PASS_DELAY (quiet window, 25 s),
#      PASS_RELOCATE_WAIT (180 s), PASS_RELOCATE_STOP_WAIT (30 s),
#      PASS_RELOCATE_START (90 s), PASS_RELOCATE_POLL (1 s),
#      PASS_RELOCATE_SETTLE (2 s), PASS_MIN_INTERVAL (loop guard, as the hook),
#      PASS_NOTIFY (optional executable that gets one line when the conversation
#      is left stopped).

RL_UUID_RE='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
RL_SHELLS=" bash zsh sh fish dash "
read -r -a CLAUDEC <<< "${PASS_CLAUDE:-claude}"
[ "${#CLAUDEC[@]}" -gt 0 ] || CLAUDEC=(claude)
RL_AGENTS=""
RL_KIND="" RL_PANE="" RL_WHY="" RL_DETAIL=""
BG_SHORT="" BG_CWD="" BG_NAME="" BG_PID=""

# Needs: TMUXC (array), is_claude_pid, jq. Both callers define the first two.

rl_agents() { timeout 5 "${CLAUDEC[@]}" agents --json 2>/dev/null | jq -ce 'select(type == "array")' 2>/dev/null; }

# 0 iff $1 is the id of a background-job session (sets BG_*, RL_AGENTS).
rl_detect() {
  local sid="$1" ent
  [[ "$sid" =~ $RL_UUID_RE ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  command -v "${CLAUDEC[0]}" >/dev/null 2>&1 || return 1
  "${TMUXC[@]}" list-sessions -F x >/dev/null 2>&1 || return 1
  RL_AGENTS="$(rl_agents)" || RL_AGENTS=""
  [ -n "$RL_AGENTS" ] || return 1
  ent="$(printf '%s' "$RL_AGENTS" | jq -c --arg s "$sid" \
    'map(select(.sessionId == $s and .kind == "background")) | first // empty' 2>/dev/null)" || return 1
  [ -n "$ent" ] || return 1
  BG_SHORT="$(printf '%s' "$ent" | jq -r '.id // empty')"
  [[ "$BG_SHORT" =~ ^[0-9a-f]{4,16}$ ]] || BG_SHORT="${sid:0:8}"
  BG_CWD="$(printf '%s' "$ent" | jq -r '.cwd // empty')"
  BG_NAME="$(printf '%s' "$ent" | jq -r '.name // empty')"
  BG_PID="$(printf '%s' "$ent" | jq -r '.pid // empty')"
  [[ "$BG_PID" =~ ^[0-9]+$ ]] || BG_PID=""
  return 0
}

# Claude process at or under pid $1 (depth <= 3); prints its pid.
rl_pane_claude_pid() {
  local layer="$1" next p c d
  for ((d = 0; d < 4; d++)); do
    next=""
    for p in $layer; do
      if is_claude_pid "$p"; then printf '%s' "$p"; return 0; fi
      for c in $(ps -o pid= --ppid "$p" 2>/dev/null); do next="$next $c"; done
    done
    [ -n "${next// /}" ] || return 1
    layer="$next"
  done
  return 1
}

# rl_view_proof PANE_PID SID CWD: is the Claude in this pane a leftover view of
# THIS session? All must hold: its pid is not another session's agents pid; its
# arguments hold no other session uuid, no -p/--print/agents, no `attach` or
# `--resume` aimed at another id; its working directory is the session's.
# 0 yes; 1 no (RL_DETAIL says which test failed, for the log only).
rl_view_proof() {
  local ppid="$1" sid="$2" cwd="$3" cp args tok prev="" real want
  local -a toks
  cp="$(rl_pane_claude_pid "$ppid")" || cp=""
  [ -n "$cp" ] || { RL_DETAIL="Claude process in the pane cannot be identified"; return 1; }
  RL_AGENTS="$(rl_agents)" || RL_AGENTS=""
  [ -n "$RL_AGENTS" ] || { RL_DETAIL="cannot read 'claude agents'"; return 1; }
  if printf '%s' "$RL_AGENTS" | jq -e --argjson p "$cp" --arg s "$sid" \
       'any(.[]; .pid == $p and .sessionId != $s)' >/dev/null 2>&1; then
    RL_DETAIL="pane Claude (pid $cp) owns another live session"; return 1
  fi
  args="$(ps -o args= -p "$cp" 2>/dev/null)"
  read -r -a toks <<< "$args"
  for tok in "${toks[@]}"; do
    case "$tok" in
      -p|--print|-c|--continue|agents) RL_DETAIL="pane Claude was started with '$tok'"; return 1 ;;
    esac
    if [[ "$tok" =~ [0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12} ]] && [ "${BASH_REMATCH[0]}" != "$sid" ]; then
      RL_DETAIL="pane Claude was started for another session (${BASH_REMATCH[0]})"; return 1
    fi
    case "$prev" in
      attach|--resume|-r)
        if [ "$tok" != "$sid" ] && [ "$tok" != "$BG_SHORT" ]; then
          RL_DETAIL="pane Claude was started with '$prev $tok'"; return 1
        fi ;;
    esac
    prev="$tok"
  done
  real="$(readlink "/proc/$cp/cwd" 2>/dev/null)"
  want="$(readlink -f "$cwd" 2>/dev/null)"
  if [ -z "$real" ] || { [ "$real" != "$cwd" ] && [ "$real" != "$want" ]; }; then
    RL_DETAIL="pane Claude's working directory is '${real:-unknown}', not the session's"; return 1
  fi
  return 0
}

# rl_target NAME SID CWD: where may this session go? Sets RL_KIND (pane|new|refuse),
# RL_PANE (pane id for pane), RL_WHY (one-line reason for refuse), RL_DETAIL (log only).
#   no window of that name           -> new   (a window is created)
#   one window, one pane, a Claude proven to be a leftover view of this session
#                                    -> pane  (respawned in place)
#   anything else                    -> refuse (nothing is ever typed into a shell)
rl_target() {
  local name="$1" sid="$2" cwd="$3" lines wid pane ppid pcmd wname
  local -A wpanes=()
  local -A info=()
  local -a wids=()
  RL_KIND="refuse" RL_PANE="" RL_WHY="" RL_DETAIL=""
  lines="$("${TMUXC[@]}" list-panes -a -F '#{window_id}|#{pane_id}|#{pane_pid}|#{pane_current_command}|#{window_name}' 2>/dev/null)" \
    || { RL_WHY="tmux is not answering"; return 1; }
  while IFS='|' read -r wid pane ppid pcmd wname; do
    [ "$wname" = "$name" ] || continue
    [[ "$wid" =~ ^@[0-9]+$ ]] && [[ "$pane" =~ ^%[0-9]+$ ]] || continue
    if [ -z "${wpanes[$wid]:-}" ]; then wids+=("$wid"); fi
    case " ${wpanes[$wid]:-} " in *" $pane "*) ;; *) wpanes[$wid]="${wpanes[$wid]:-} $pane"; info[$pane]="$ppid|$pcmd" ;; esac
  done <<< "$lines"
  if [ "${#wids[@]}" -eq 0 ]; then RL_KIND="new"; return 0; fi
  if [ "${#wids[@]}" -gt 1 ]; then
    RL_WHY="${#wids[@]} tmux windows are named '$name'; close or rename all but one"; return 1
  fi
  wid="${wids[0]}"
  set -- ${wpanes[$wid]}
  if [ "$#" -ne 1 ]; then RL_WHY="tmux window '$name' has $# panes; it needs exactly one"; return 1; fi
  pane="$1"; ppid="${info[$pane]%%|*}"; pcmd="${info[$pane]#*|}"
  RL_WHY="tmux window '$name' exists but does not hold this session's view; close or rename that tab, then run /pass again"
  case "$pcmd" in
    claude|node) ;;
    *) RL_DETAIL="pane $pane runs '$pcmd'"; return 1 ;;
  esac
  rl_view_proof "$ppid" "$sid" "$cwd" || return 1
  RL_KIND="pane"; RL_PANE="$pane"; RL_WHY=""; return 0
}

# ---------------------------------------------------------------- library end --
[ "${PASS_RELOCATE_LIB:-0}" = 1 ] && return 0 2>/dev/null

# ------------------------------------------------------------------ job path --
set -uo pipefail
umask 077
ROOT="${PASS_DIR:-$HOME/.claude/passes}"
STATE="$ROOT/state"
NAME="-" PANE=""
rlog() {
  mkdir -p "$STATE" 2>/dev/null || return 0
  printf '%s pass-relocate pane=%s name=%s %s\n' "$(date +%FT%T%z 2>/dev/null)" "${PANE:-?}" "${NAME:--}" "$*" \
    >>"$STATE/pass.log" 2>/dev/null
  return 0
}
SELF="$(readlink -f "${BASH_SOURCE[0]}")"

# --run-claude <claude args>: the process a relocated pane runs. Claude starts by
# argument list (never typed into a shell); when it exits, a recorded failure
# line for the resumed conversation is shown and the pane falls back to the
# user's login shell. set -m puts Claude in its own foreground process group so
# the pane's foreground command is `claude`, as in a hand-started tab.
if [ "${1:-}" = --run-claude ]; then
  shift
  set -m
  # Claude gets the user's normal shell setup (profile, PATH, env): it runs as the
  # foreground job of an interactive login bash/zsh. argv stays intact: the Claude
  # command words and the args are positional parameters, never re-split. That
  # interactive shell also owns job control, so after Ctrl+Z it takes the terminal
  # back and its own `fg` (looped until Claude has really exited) hands it over
  # again; a non-interactive wrapper cannot do that (the terminal is not returned).
  # Any other $SHELL: the same through a plain interactive bash (no profile).
  rjob='"$0" "$@"; rn=0; while [ -n "$(jobs -s 2>/dev/null)" ] && [ "$rn" -lt 600 ]; do fg >/dev/null 2>&1 || sleep 1; rn=$((rn + 1)); done'
  case "${SHELL##*/}" in
    bash|zsh) [ -x "${SHELL:-}" ] && rsh="$SHELL" ;;
  esac
  if [ -n "${rsh:-}" ]; then
    "$rsh" -lic "$rjob" "${CLAUDEC[@]}" "$@"
  elif command -v bash >/dev/null 2>&1; then
    bash -ic "$rjob" "${CLAUDEC[@]}" "$@"
  else
    "${CLAUDEC[@]}" "$@"
  fi
  ruid="" rprev=""
  for ra in "$@"; do [ "$rprev" = --resume ] && ruid="$ra"; rprev="$ra"; done
  if [[ "$ruid" =~ $RL_UUID_RE ]] && [ -f "$ROOT/relocate/$ruid.failed" ]; then
    head -n 1 "$ROOT/relocate/$ruid.failed" 2>/dev/null
  fi
  [ -x "${SHELL:-}" ] || SHELL=/bin/bash
  exec "$SHELL" -l
fi

[ "${1:-}" = --job ] || { echo "usage: pass-relocate.sh --job <session uuid> <job id> | --run-claude <claude args>" >&2; exit 0; }
SID="${2:-}" JOB="${3:-}"
[[ "$SID" =~ $RL_UUID_RE ]] || { rlog "job: bad session id, abort"; exit 0; }
[[ "$JOB" =~ ^[0-9]+\.[0-9]+$ ]] || { rlog "job: bad job id, abort"; exit 0; }
REQ="$STATE/relocate-$SID.req"
NOTE="$ROOT/relocate/$SID.md"

# Locate and source the Stop hook for its fenced screen helpers.
HOOK=""
SELF_DIR="$(dirname "$SELF")"
if [ -n "${PASS_STOP_HOOK:-}" ]; then
  [ -f "$PASS_STOP_HOOK" ] && HOOK="$PASS_STOP_HOOK"
else
  for h in "$HOME/.claude/hooks/pass-stop.sh" "$SELF_DIR/../../hooks/pass-stop.sh"; do
    [ -f "$h" ] && { HOOK="$h"; break; }
  done
fi
[ -n "$HOOK" ] || { rlog "job: pass-stop.sh not found, abort (note kept in $NOTE)"; exit 0; }
# shellcheck disable=SC1090
PASS_SOURCE_ONLY=1 source "$HOOK" || { rlog "job: cannot source $HOOK, abort"; exit 0; }
for f in read_box pane_state tx_quiet is_claude_pid kv valid_name num_or live_pane_pid; do
  declare -F "$f" >/dev/null || { rlog "job: hook lacks $f, abort"; exit 0; }
done
STATE="$ROOT/state"

POLL="${PASS_RELOCATE_POLL:-1}"; [[ "$POLL" =~ ^[0-9]+(\.[0-9]+)?$ ]] || POLL=1
WAIT_MAX="$(num_or "${PASS_RELOCATE_WAIT:-180}" 180)"
STOP_WAIT="$(num_or "${PASS_RELOCATE_STOP_WAIT:-30}" 30)"
START_WAIT="$(num_or "${PASS_RELOCATE_START:-90}" 90)"
REQ_MAX_AGE=3600

req_ok() { [ -f "$REQ" ] && [ "$(kv "$REQ" job)" = "$JOB" ]; }
cancelled() { rlog "job: request cancelled or superseded, abort"; exit 0; }
chk() { req_ok || cancelled; }
# Before the stop: nothing has happened to the conversation.
rl_abort() { rlog "job: $*, abort (nothing stopped)"; req_ok && rm -f "$REQ"; exit 0; }
# After the stop succeeded: the one exit that says how to get the conversation back.
rl_fail() {
  local line="resume with: cd $CWD && claude --resume $SID"
  rlog "job: $*, abort (conversation is stopped; $line)"
  printf '%s\n' "$line" >"$ROOT/relocate/$SID.failed" 2>/dev/null
  req_ok && rm -f "$REQ"
  if [ -n "${PASS_NOTIFY:-}" ] && [ -f "$PASS_NOTIFY" ] && [ -x "$PASS_NOTIFY" ]; then
    "$PASS_NOTIFY" "pass: session '$NAME' was stopped for tmux but could not be reopened ($*). $line" >/dev/null 2>&1
  fi
  exit 0
}
chk_stopped() { req_ok || rl_fail "request cancelled or superseded after the stop"; }
is_shell() { case "$RL_SHELLS" in *" $1 "*) return 0 ;; esac; return 1; }

req_ok || { rlog "job: no request file for this job, abort"; exit 0; }
NAME="$(kv "$REQ" name)"; CWD="$(kv "$REQ" cwd)"; TARGET="$(kv "$REQ" pane)"
SHORT="$(kv "$REQ" short)"; EXPLICIT="$(kv "$REQ" explicit)"; TITLE="$(kv "$REQ" title)"
REQ_EPOCH="$(kv "$REQ" epoch)"; REQ_BGPID="$(kv "$REQ" bgpid)"
valid_name "$NAME" || { NAME="-"; rl_abort "bad name in request"; }
if ! [[ "$REQ_EPOCH" =~ ^[0-9]+$ ]] || [ $(($(date +%s) - REQ_EPOCH)) -gt "$REQ_MAX_AGE" ]; then
  rlog "job: request is older than ${REQ_MAX_AGE}s or has no epoch, ignored and removed"; rm -f "$REQ"; exit 0
fi
[[ "$SHORT" =~ ^[0-9a-f]{4,16}$ ]] || rl_abort "bad short id in request"
[[ "$TARGET" =~ ^(%[0-9]+|new)$ ]] || rl_abort "bad target in request"
[[ "$CWD" =~ ^/[A-Za-z0-9._/-]+$ ]] && [ -d "$CWD" ] || rl_abort "working directory in request is not a plain existing path"
BG_SHORT="$SHORT"
[ -s "$NOTE" ] || rl_abort "saved note missing"
TX=""
for t in "$HOME"/.claude/projects/*/"$SID".jsonl; do [ -f "$t" ] && TX="$t"; break; done
[ -n "$TX" ] || rl_abort "transcript not found"
command -v jq >/dev/null 2>&1 && command -v awk >/dev/null 2>&1 || rl_abort "jq or awk missing"
command -v flock >/dev/null 2>&1 || rl_abort "flock missing"
rlog "job: started (target $TARGET, quiet window ${DELAY}s)"

# ---- a. wait for the turn to end, then for a quiet transcript
BGPID=""
read_bg() { # sets ST (idle|busy|none) and BGPID from a fresh agents read
  RL_AGENTS="$(rl_agents)" || RL_AGENTS=""
  ST="$(printf '%s' "$RL_AGENTS" | jq -r --arg s "$SID" \
    'map(select(.sessionId == $s)) | first // empty | if . == null then "none" elif (.pid == null) or (.status == "idle") then "idle" else "busy" end' 2>/dev/null)"
  BGPID="$(printf '%s' "$RL_AGENTS" | jq -r --arg s "$SID" 'map(select(.sessionId == $s)) | first // empty | .pid // empty' 2>/dev/null)"
  [[ "$BGPID" =~ ^[0-9]+$ ]] || BGPID=""
}
start="$(date +%s)"; base=""; tstop=""; idle_since=0
while :; do
  chk
  now="$(date +%s)"
  [ $((now - start)) -le "$WAIT_MAX" ] || rl_abort "timed out after ${WAIT_MAX}s waiting for the turn to end"
  read_bg
  case "$ST" in
    idle)
      if [ -z "$base" ]; then
        base="$(stat -c %s "$TX" 2>/dev/null)"; tstop="$(date +%s.%N)"; idle_since="$now"
        [[ "$base" =~ ^[0-9]+$ ]] || rl_abort "cannot stat transcript"
      else
        tx_quiet "$TX" "$base" "$(awk -v a="$tstop" -v g="$GRACE" 'BEGIN { printf "%.3f", a + g }')" '["assistant"]' 0 \
          || rl_abort "new activity in transcript during the quiet window${TX_WHY:+: $TX_WHY}"
        [ $((now - idle_since)) -ge "$DELAY" ] && break
      fi ;;
    busy) [ -z "$base" ] || rl_abort "session became busy again during the quiet window" ;;
    *) rl_abort "session not listed by claude agents" ;;
  esac
  sleep "$POLL"
done

# ---- b. model and permission mode from the transcript tail
# Model: strict regex, no leading dash; Claude is started by argument list, so no
# quoting is involved. Mode: always passed; anything unrecorded, `default` or
# bypassPermissions becomes `manual` (the safest mode, never a looser one).
MODEL="$(tail -c 4000000 "$TX" 2>/dev/null | grep -a '"assistant"' \
  | jq -rR 'fromjson? | select(.type? == "assistant") | select(.isSidechain != true) | .message.model? | strings | select(. != "<synthetic>")' 2>/dev/null | tail -n1)"
MODE="$(tail -c 4000000 "$TX" 2>/dev/null | grep -a '"permission-mode"' \
  | jq -rR 'fromjson? | select(.type? == "permission-mode") | .permissionMode? | strings' 2>/dev/null | tail -n1)"
MODEL_RE='^[A-Za-z0-9][][A-Za-z0-9._-]{0,79}$'
CARGS=()
if [ -n "$MODEL" ]; then
  if [[ "$MODEL" =~ $MODEL_RE ]]; then CARGS+=(--model "$MODEL")
  else rlog "job: model string rejected by the strict regex, flag omitted"; fi
fi
case "$MODE" in
  acceptEdits|auto|manual|dontAsk|plan) MODE_ARG="$MODE" ;;
  default) MODE_ARG=manual ;;
  bypassPermissions) MODE_ARG=manual; rlog "job: permission mode bypassPermissions is never carried over, using manual" ;;
  "") MODE_ARG=manual; rlog "job: no permission mode recorded, using manual" ;;
  *) MODE_ARG=manual; rlog "job: unknown permission mode, using manual" ;;
esac
CARGS+=(--permission-mode "$MODE_ARG" --resume "$SID")

# ---- c. one relocation per window at a time: the lock is taken BEFORE the target
# is re-validated and held until pass state is bound
exec {LOCKFD}>"$STATE/relocate-window-$NAME.lock" || rl_abort "cannot open the window lock"
flock -n "$LOCKFD" || rl_abort "another relocation holds the lock for window '$NAME'"

# ---- c2. re-validate the target (the view proof again, at job time)
chk
rl_target "$NAME" "$SID" "$CWD"
if [ "$TARGET" = new ]; then
  [ "$RL_KIND" = new ] || rl_abort "target changed since the request (${RL_WHY:-a window now exists}${RL_DETAIL:+; $RL_DETAIL})"
else
  [ "$RL_KIND" = pane ] && [ "$RL_PANE" = "$TARGET" ] || rl_abort "target pane no longer usable (${RL_WHY:-changed}${RL_DETAIL:+; $RL_DETAIL})"
  # loop guard, before anything is stopped
  lastc="$(kv "$STATE/pane-${TARGET#%}.lastclear" epoch)"
  now="$(date +%s)"
  if [[ "$lastc" =~ ^[0-9]+$ ]] && [ $((now - lastc)) -lt "$MIN_INTERVAL" ] && [ $((now - lastc)) -ge 0 ]; then
    rl_abort "loop guard: last auto-clear of $TARGET was $((now - lastc))s ago (< ${MIN_INTERVAL}s); note kept in relocate/$SID.md"
  fi
fi

# ---- c3. just before the stop: the view is idle with an empty box, and the
# background job has no shell of its own still running. For an existing pane the
# pane pid and the view's Claude pid are recorded here; after the stop the view may
# still be alive (showing a list), may have exited to the pane's shell, or the pane
# may be gone, and the record is how step e tells these apart.
VPANEPID="" VCPID=""
if [ "$TARGET" != new ]; then
  PANE="$TARGET"
  pane_state || rl_abort "pane $PANE is not idle with an empty input box (${PANE_WHY:-unknown})"
  VPANEPID="$(live_pane_pid)"
  VCPID="$(rl_pane_claude_pid "$VPANEPID")" || VCPID=""
  [[ "$VPANEPID" =~ ^[0-9]+$ ]] && [[ "$VCPID" =~ ^[0-9]+$ ]] || rl_abort "cannot record the view's processes in $PANE"
fi
read_bg
[ -z "$REQ_BGPID" ] || [ "$BGPID" = "$REQ_BGPID" ] || rl_abort "the background job's process changed since the request"
if [ -n "$BGPID" ]; then
  for c in $(ps -o pid= --ppid "$BGPID" 2>/dev/null); do
    [[ "$(ps -o stat= -p "$c" 2>/dev/null)" == Z* ]] && continue
    if is_shell "$(ps -o comm= -p "$c" 2>/dev/null)"; then
      rl_abort "background shell still running under the job"
    fi
  done
fi

# ---- d. stop the background job and wait until its process is gone
chk
rlog "job: stopping background job $SHORT"
"${CLAUDEC[@]}" stop "$SHORT" >/dev/null 2>&1
bgalive() {
  local pid
  RL_AGENTS="$(rl_agents)" || RL_AGENTS=""
  [ -n "$RL_AGENTS" ] || return 0   # unreadable: assume alive
  pid="$(printf '%s' "$RL_AGENTS" | jq -r --arg s "$SID" 'map(select(.sessionId == $s)) | first // empty | .pid // empty' 2>/dev/null)"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  [ -d "/proc/$pid" ] && [[ "$(ps -o stat= -p "$pid" 2>/dev/null)" != Z* ]]
}
stopped=0
for ((i = 0; i * 5 < STOP_WAIT * 10; i++)); do
  bgalive || { stopped=1; break; }
  sleep 0.5
done
# The stop was sent and may still land: from here on a failure is a recovery case.
[ "$stopped" = 1 ] || rl_fail "background job did not stop within ${STOP_WAIT}s (the stop may still take effect)"
rlog "job: background job stopped"

# ---- e. reopen: Claude is started by argument list, never typed into a shell
chk_stopped
RUN=(bash "$SELF" --run-claude "${CARGS[@]}")
# The reopened wrapper reads the same state root and Claude command as this job.
ENVA=()
for ev in PASS_DIR PASS_CLAUDE; do
  [ -n "${!ev:-}" ] && [[ "${!ev}" != *$'\n'* ]] && ENVA+=(-e "$ev=${!ev}")
done

open_new() {
  local sess
  rl_target "$NAME" "$SID" "$CWD"
  [ "$RL_KIND" = new ] || rl_fail "a window named '$NAME' appeared during the stop"
  sess="$("${TMUXC[@]}" list-clients -F '#{client_activity} #{session_id}' 2>/dev/null | sort -rn | head -n1 | cut -d' ' -f2)"
  [[ "$sess" =~ ^\$[0-9]+$ ]] || sess="$("${TMUXC[@]}" list-sessions -F '#{session_activity} #{session_id}' 2>/dev/null | sort -rn | head -n1 | cut -d' ' -f2)"
  [[ "$sess" =~ ^\$[0-9]+$ ]] || rl_fail "no tmux session to create the window in"
  PANE="$("${TMUXC[@]}" new-window -d -P -F '#{pane_id}' -t "$sess" -n "$NAME" -c "$CWD" "${ENVA[@]}" -- "${RUN[@]}" 2>/dev/null)"
  [[ "$PANE" =~ ^%[0-9]+$ ]] || { PANE=""; rl_fail "could not create tmux window '$NAME'"; }
  rlog "job: created window '$NAME' ($PANE) in session $sess"
}
open_respawn() {
  "${TMUXC[@]}" respawn-pane -k -t "$PANE" -c "$CWD" "${ENVA[@]}" -- "${RUN[@]}" >/dev/null 2>&1 || rl_fail "could not respawn pane $PANE"
  rlog "job: respawned pane $PANE ($1)"
}
pid_alive() { [ -d "/proc/$1" ] && [[ "$(ps -o stat= -p "$1" 2>/dev/null)" != Z* ]]; }

if [ "$TARGET" = new ]; then
  open_new
else
  # What did the stop do to the view? Decided from the pids recorded before it:
  #   a. same pane, same pane pid, the same Claude pid alive (it shows a list now)
  #   b. same pane and pane pid, the view gone, a shell in the foreground, no children
  #   c. the pane is gone (it was the view's own command)
  #   d. anything else
  PANE="$TARGET"
  REOPEN_WAIT="$(num_or "${PASS_RELOCATE_REOPEN_WAIT:-3}" 3)"
  decided=""
  for ((i = 0; i * 5 < REOPEN_WAIT * 10; i++)); do
    lp="$("${TMUXC[@]}" list-panes -a -F '#{pane_id}|#{pane_pid}|#{pane_current_command}' 2>/dev/null)" \
      || rl_fail "tmux is not answering after the stop"
    row="$(printf '%s\n' "$lp" | awk -F'|' -v p="$TARGET" '$1 == p { print; exit }')"
    if [ -z "$row" ]; then decided=c; break; fi
    IFS='|' read -r _ rpp rcmd <<< "$row"
    if [ "$rpp" = "$VPANEPID" ]; then
      cp="$(rl_pane_claude_pid "$rpp")" || cp=""
      if [ "$cp" = "$VCPID" ] && pid_alive "$VCPID"; then decided=a; break; fi
      if ! pid_alive "$VCPID" && is_shell "$rcmd" && [ -z "$(ps -o pid= --ppid "$rpp" 2>/dev/null | tr -d ' \n')" ]; then decided=b; break; fi
    fi
    sleep 0.2
  done
  case "$decided" in
    a) open_respawn "the view was still running" ;;
    b) open_respawn "the view had exited to the pane's shell" ;;
    c) rlog "job: pane $TARGET is gone after the stop"; open_new ;;
    *) rl_fail "pane $TARGET is in an unexpected state after the stop (${rcmd:+running ${rcmd:-}}); not respawning" ;;
  esac
fi
N="${PANE#%}"

# ---- f. wait for an idle input box
chk_stopped
ok=0
for ((i = 0; i < START_WAIT * 5; i++)); do
  case "$("${TMUXC[@]}" display-message -p -t "$PANE" '#{pane_current_command}' 2>/dev/null)" in
    claude|node)
      # Claude is running again: an earlier failure line no longer applies
      rm -f "$ROOT/relocate/$SID.failed"
      if pane_state; then ok=1; break; fi ;;
  esac
  sleep 0.2
done
if [ "$ok" != 1 ]; then
  rlog "job: Claude started in $PANE but is not at an idle prompt; note kept in relocate/$SID.md, run /pass there"
  req_ok && rm -f "$REQ"
  exit 0
fi

# ---- g. bind pass state to the new Claude process
PANEPID="$(live_pane_pid)"
CPID="$(rl_pane_claude_pid "$PANEPID")" || CPID=""
[[ "$PANEPID" =~ ^[0-9]+$ ]] && [ -n "$CPID" ] && is_claude_pid "$CPID" || rl_fail "cannot identify the new Claude process"
chk_stopped
tmp="$(mktemp "$STATE/.optin.XXXXXX")" || rl_fail "cannot write opt-in"
{
  printf 'name=%s\npane_pid=%s\nclaude_pid=%s\n' "$NAME" "$PANEPID" "$CPID"
  [ "$EXPLICIT" = 1 ] && [ -f "$STATE/optout/$NAME" ] && printf 'oneshot=1\n'
  printf 'title_at_optin=%s\n' "$TITLE"
} >"$tmp"
mv -f "$tmp" "$STATE/pane-$N.optin"
rm -f "$STATE/pane-$N.ready"
mv -f "$NOTE" "$ROOT/pane-$N.md" || rl_fail "cannot move the note"
rm -f "$REQ" "$ROOT/relocate/$SID.failed"
exec {LOCKFD}>&-
rlog "job: relocated, bound to claude pid $CPID in $PANE, note moved to pane-$N.md"

# ---- h. loop guard (a new pane id can repeat after a tmux restart), then hand
# over to the Stop hook's verified clear job
last="$(kv "$STATE/pane-$N.lastclear" epoch)"
now="$(date +%s)"
if [[ "$last" =~ ^[0-9]+$ ]] && [ $((now - last)) -lt "$MIN_INTERVAL" ] && [ $((now - last)) -ge 0 ]; then
  rlog "job: loop guard: last auto-clear $((now - last))s ago (< ${MIN_INTERVAL}s); relocated, note saved, not clearing"
  exit 0
fi
# Let the resumed session finish its own start-up writes before the baseline.
sleep "${PASS_RELOCATE_SETTLE:-2}"
now="$(date +%s)"
TID="$(date +%s%N 2>/dev/null).$$"
[[ "$TID" =~ ^[0-9]+\.[0-9]+$ ]] || { rlog "job: cannot make a job id, not clearing"; exit 0; }
TOKEN="$STATE/pane-$N.clearing"
rm -f "$STATE/pane-$N.injected"
printf 'epoch=%s\nid=%s\nname=%s\nclaude_pid=%s\n' "$now" "$TID" "$NAME" "$CPID" >"$TOKEN.tmp.$$" \
  && mv -f "$TOKEN.tmp.$$" "$TOKEN" || { rm -f "$TOKEN.tmp.$$"; rlog "job: cannot write clearing token, not clearing"; exit 0; }
TBASE="$(stat -c %s "$TX" 2>/dev/null)"
[[ "$TBASE" =~ ^[0-9]+$ ]] || { rm -f "$TOKEN"; rlog "job: cannot stat transcript, not clearing"; exit 0; }
rlog "job: handing over to the clear job"
PASS_DELAY=3 exec bash "$HOOK" --job "$PANE" "$NAME" "$CPID" "$TX" "$TBASE" "$(date +%s.%N)" "$TID" </dev/null >/dev/null 2>&1
