#!/usr/bin/env bash
# pass.sh — auto-pass helper. Auto-pass is ON BY DEFAULT in tmux; a session
# opts out by name (state/optout/<name>, persistent, not tied to pane or pid).
# Explicit opt-ins (state keyed by tmux pane, bound to the Claude Code process
# that ran `auto` or `write`) still work as before.
# Subcommands: auto [name...] | manual | status | write [--explicit] [name...] (note on stdin) | cancel.
# `manual` creates the opt-out for the derived session name and drops the pane
# opt-in; `auto` removes the opt-out for the resulting name, then opts in.
# `status` = auto when no opt-out exists for the name (default), manual when one does.
# `write --explicit` (the user typed /pass) marks the ready marker explicit=1,
# which skips the Stop hook's minimum-context gate.
# Exit codes: 0 ok, 1 error / empty note, 2 note over the length cap, 3 retired
# (write no longer needs an opt-in), 4 note lacks a '## Done last session' line
# (write), 64 usage / invalid name.
# write order: empty (1) -> length cap (2) -> invalid name arg (64) -> section
# check (4) -> only then, if not opted in: a normal opt-in (same file as `auto`)
# when the name has no opt-out (default on), else a ONE-SHOT opt-in (same file
# plus a line oneshot=1; name = name arg, else derive_name). A
# rejected note never leaves an opt-in behind. Every opt-in also stores
# title_at_optin=<session title when it was created, or empty>. While opted
# in, a no-arg write renames the opt-in to the session title (customTitle) only
# when that title differs from both the stored name and title_at_optin, i.e.
# the user ran /rename after opting in; an explicit `auto <name>` is never
# overridden by a title that already existed. A legacy opt-in without the
# title_at_optin key renames whenever the title differs from the name.
# A one-shot opt-in is left in place after the clear (the hooks need it through
# the resume); it dies with the Claude process (claude_pid binding). `status`
# reports it as manual, so the model-initiated auto-pass rule never fires on it.
# A background-job session (no $TMUX_PANE) is handled by bg_handle below via
# pass-relocate.sh: status reports `auto ... relocate=<pane>` when a tmux window
# named after the session can take it, write queues the move (exit 1 with a
# reason when it cannot), cancel drops the queued move.
# State contract: see core/hooks/pass-stop.sh header.
set -euo pipefail
umask 077

# State root + one-time move of the legacy ~/.claude/handoffs dir. Keep in sync
# with core/hooks/pass-stop.sh and core/hooks/pass-start.sh (same function).
# PASS_DIR set → that dir, never migrate. Else ~/.claude/passes; when it does
# not exist yet and ~/.claude/handoffs is a real dir, rename it and leave a
# relative symlink behind. Race-tolerant and silent; sets MIGRATED=1 only in
# the process whose mv won. Nothing may create the new root before this runs.
resolve_root() {
  MIGRATED=0
  if [ -n "${PASS_DIR:-}" ]; then ROOT="$PASS_DIR"; return 0; fi
  ROOT="$HOME/.claude/passes"
  local old="$HOME/.claude/handoffs"
  if [ "${1:-}" != nomigrate ] && [ ! -e "$ROOT" ] && [ ! -L "$ROOT" ] \
     && [ -d "$old" ] && [ ! -L "$old" ]; then
    if mv -T "$old" "$ROOT" 2>/dev/null; then MIGRATED=1; fi
    if ! ln -sT passes "$old" 2>/dev/null && [ "$MIGRATED" = 1 ]; then
      { mkdir -p "$ROOT/state" && printf '%s resolve_root pane=%s name=- legacy symlink not created (~/.claude/handoffs exists?)\n' \
        "$(date +%FT%T%z)" "${TMUX_PANE:-?}" >>"$ROOT/state/pass.log"; } 2>/dev/null || true
    fi
  fi
  return 0
}
resolve_root
STATE="$ROOT/state"
if [ "$MIGRATED" = 1 ]; then
  { mkdir -p "$STATE" && printf '%s pass.sh pane=%s name=- migrated legacy state dir ~/.claude/handoffs -> ~/.claude/passes\n' \
    "$(date +%FT%T%z)" "${TMUX_PANE:-?}" >>"$STATE/pass.log"; } 2>/dev/null || true
fi
CAP=9000
NAME_RE='^[A-Za-z0-9][A-Za-z0-9._ -]{0,63}$'
read -r -a TMUXC <<< "${PASS_TMUX:-tmux}"
[ "${#TMUXC[@]}" -gt 0 ] || TMUXC=(tmux)

usage() {
  echo "usage: pass.sh auto [name...] | manual | status | write [--explicit] [name...] | cancel" >&2
  exit 64
}

# ASCII-only regex under the C locale; the rest of the helper keeps the user's
# locale so `wc -m` counts characters, not bytes.
valid_name() ( export LC_ALL=C; [[ "$1" =~ $NAME_RE ]] && [[ "$1" != *" " ]] )

# Map any string onto the name charset; the caller still checks valid_name.
sanitize_name() {
  printf '%s' "$1" | LC_ALL=C tr -c 'A-Za-z0-9._ -' '-' | LC_ALL=C sed 's/^[^A-Za-z0-9]*//' \
    | cut -c1-64 | sed 's/ *$//' || true
}

# Session name when none is given. Prints "<tier> <name>" (tier: title|window|
# session|default): the session title (last custom-title record in this
# session's transcript, last 8 MB only), else the tmux window name unless it is
# just a program name, else the tmux session name, else "pass". Each candidate
# is sanitised and must pass valid_name, else the next one is tried.
# Sanitised session title when it is valid, else nothing (always exits 0).
current_title() {
  local sid t c
  sid="${CLAUDE_CODE_SESSION_ID:-}"
  if [[ "$sid" =~ ^[0-9a-f-]{8,64}$ ]] && command -v jq >/dev/null 2>&1; then
    for t in "$HOME"/.claude/projects/*/"$sid".jsonl; do
      [ -f "$t" ] || continue
      c="$(tail -c 8000000 "$t" 2>/dev/null | grep -a '"custom-title"' \
        | jq -rR 'fromjson? | select(.type? == "custom-title") | .customTitle // empty | strings' 2>/dev/null \
        | tail -n1 || true)"
      c="$(sanitize_name "$c")"
      if valid_name "$c"; then printf '%s' "$c"; fi
      break
    done
  fi
  return 0
}

# Transcript of this session (by session id), or nothing.
find_transcript() {
  local sid t
  sid="${CLAUDE_CODE_SESSION_ID:-}"
  [[ "$sid" =~ ^[0-9a-f-]{8,64}$ ]] || return 0
  for t in "$HOME"/.claude/projects/*/"$sid".jsonl; do
    [ -f "$t" ] && printf '%s' "$t"
    break
  done
  return 0
}

# Context size of the last non-sidechain assistant entry with usage > 0
# (input + cache read + cache creation tokens); nothing when unreadable.
# TWIN: the same pipeline is in core/hooks/pass-stop.sh (last_context);
# test-pass-default.sh checks both agree. Keep them identical.
last_context() {
  command -v jq >/dev/null 2>&1 || return 0
  tail -c 4000000 "$1" 2>/dev/null | grep -a '"usage"' \
    | jq -rR 'fromjson? | select(.type? == "assistant") | select(.isSidechain != true) | .message.usage? | objects
        | ((.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0))
        | select(. > 0)' 2>/dev/null | tail -n1 || true
  return 0
}

derive_name() {
  local c
  c="$(current_title)"
  if [ -n "$c" ]; then printf 'title %s' "$c"; return 0; fi
  c="$("${TMUXC[@]}" display-message -p -t "$PANE" '#{window_name}' 2>/dev/null || true)"
  case "$c" in
    claude|bash|zsh|sh|fish|dash|ksh|tcsh|node) c="" ;;
  esac
  c="$(sanitize_name "$c")"
  if valid_name "$c"; then printf 'window %s' "$c"; return 0; fi
  c="$("${TMUXC[@]}" display-message -p -t "$PANE" '#{session_name}' 2>/dev/null || true)"
  c="$(sanitize_name "$c")"
  if valid_name "$c"; then printf 'session %s' "$c"; return 0; fi
  printf 'default pass'
  return 0
}

cmd="${1:-}"
[ -n "$cmd" ] || usage
shift || true
case "$cmd" in
  auto|manual|status|write|cancel) ;;
  *) usage ;;
esac

EXPLICIT=0
if [ "$cmd" = write ]; then
  _args=()
  for _a in "$@"; do
    if [ "$_a" = "--explicit" ]; then EXPLICIT=1; else _args+=("$_a"); fi
  done
  set -- "${_args[@]}"
fi

if { [ "$cmd" = auto ] || [ "$cmd" = write ]; } && [ $# -gt 0 ]; then
  for _a in "$@"; do
    if [[ "$_a" == -* ]]; then
      echo "pass: invalid argument '$_a'; the only flag is --explicit (write), and names cannot start with '-'" >&2
      exit 64
    fi
  done
  if ! valid_name "$*"; then
    echo "pass: invalid name; 1-64 chars of A-Za-z0-9._ - (space allowed), starting with a letter or digit, no trailing space" >&2
    exit 64
  fi
fi

if ! command -v "${TMUXC[0]}" >/dev/null 2>&1; then
  if [ "$cmd" = status ]; then echo "manual (not in tmux)"; exit 1; fi
  echo "pass: tmux is required" >&2; exit 1
fi
is_claude_pid() {
  local comm args
  [[ "${1:-}" =~ ^[0-9]+$ ]] || return 1
  comm="$(ps -o comm= -p "$1" 2>/dev/null)" || return 1
  [ "$comm" = claude ] && return 0
  [ "$comm" = node ] || return 1
  args="$(ps -o args= -p "$1" 2>/dev/null)" || return 1
  [[ "$args" == *claude* ]]
}

# ---- Background-job sessions (no $TMUX_PANE) --------------------------------
# A conversation running as a Claude Code background job has no tmux pane. For
# status / write / cancel in such a session (a valid $CLAUDE_CODE_SESSION_ID that
# `claude agents --json` lists with kind=background), pass-relocate.sh does the
# pass: it stops the job (anything the job still runs in the background ends
# with it), reopens the conversation in a tmux window named after the session
# (a new window, or the leftover view of this session respawned in place;
# nothing is ever typed into a shell), binds pass state there and hands over to
# the Stop hook's clear job. Anything else returns from bg_handle and gets
# today's messages.
bg_log() { # bg_log <subcommand> <name> <result>
  mkdir -p "$STATE" 2>/dev/null || return 0
  printf '%s pass.sh %s pane=- name=%s %s\n' "$(date +%FT%T%z)" "$1" "$2" "$3" >>"$STATE/pass.log" 2>/dev/null || true
}

bg_save_note() { # bg_save_note <sid> <note>; prints the reason and returns 1 on failure
  local t
  mkdir -p "$ROOT/relocate" "$STATE" 2>/dev/null || { echo "pass: cannot create $ROOT/relocate" >&2; return 1; }
  chmod 700 "$ROOT" "$STATE" "$ROOT/relocate" 2>/dev/null || true
  t="$(mktemp "$ROOT/relocate/.note.XXXXXX" 2>/dev/null)" || { echo "pass: cannot write in $ROOT/relocate" >&2; return 1; }
  if ! printf '%s' "$2" >"$t" 2>/dev/null || ! mv -f "$t" "$ROOT/relocate/$1.md" 2>/dev/null; then
    rm -f "$t"; echo "pass: cannot save the note in $ROOT/relocate" >&2; return 1
  fi
}

# A request file older than an hour is dead: ignore and remove it.
bg_req_stale() { # bg_req_stale <file>: 0 iff stale or without a valid epoch
  local e
  e="$(sed -n 's/^epoch=//p' "$1" 2>/dev/null | head -n 1)"
  [[ "$e" =~ ^[0-9]+$ ]] || return 0
  [ $(($(date +%s) - e)) -gt 3600 ]
}

# The checks write makes before relocating, shared with status so the two never
# disagree: sets BG_REFUSE (reason) and returns 1 when the move cannot happen.
bg_checks() { # bg_checks <name> <sid>
  BG_REFUSE=""
  if ! [[ "$BG_CWD" =~ ^/[A-Za-z0-9._/-]+$ ]] || [ ! -d "$BG_CWD" ]; then
    BG_REFUSE="this session runs as a background job and its working directory ('$BG_CWD') is not a plain existing path (letters, digits, . _ - /); it cannot be reopened in tmux automatically."
    BG_REFUSE_LOG="cwd"
    return 1
  fi
  if ! command -v setsid >/dev/null 2>&1; then
    BG_REFUSE="setsid not found; cannot move a background job into tmux."; BG_REFUSE_LOG="setsid"; return 1
  fi
  if ! rl_target "$1" "$2" "$BG_CWD"; then
    BG_REFUSE="this session runs as a background job and cannot be moved into tmux: $RL_WHY"
    BG_REFUSE_LOG="$RL_WHY${RL_DETAIL:+; $RL_DETAIL}"
    return 1
  fi
  return 0
}

bg_handle() {
  local sid req lib name c note n ctx mmin tx job t where launcher sysst ev v val
  local -a sdargs
  case "$cmd" in status|write|cancel) ;; *) return 0 ;; esac
  sid="${CLAUDE_CODE_SESSION_ID:-}"
  [[ "$sid" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]] || return 0
  req="$STATE/relocate-$sid.req"
  if [ -f "$req" ] && bg_req_stale "$req"; then
    rm -f "$req"; bg_log "$cmd" "-" "stale-relocate-request-removed"
  fi
  if [ "$cmd" = cancel ]; then
    [ -f "$req" ] || return 0
    rm -f "$req"
    bg_log cancel "-" "relocate-cancelled"
    echo "pass: cancelled — this background job will not be moved into tmux (the saved note is kept in $ROOT/relocate/$sid.md)."
    exit 0
  fi
  lib="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/pass-relocate.sh"
  [ -f "$lib" ] || return 0
  PASS_RELOCATE_LIB=1
  # shellcheck disable=SC1090
  . "$lib" || { unset PASS_RELOCATE_LIB; return 0; }
  unset PASS_RELOCATE_LIB
  rl_detect "$sid" || return 0

  name=""
  if [ "$cmd" = write ]; then name="$*"; fi
  [ -n "$name" ] || name="$(current_title)"
  if [ -z "$name" ]; then
    c="$(sanitize_name "$BG_NAME")"
    if valid_name "$c"; then name="$c"; fi
  fi

  if [ "$cmd" = status ]; then
    if [ -n "$name" ] && [ ! -f "$STATE/optout/$name" ] && bg_checks "$name" "$sid" && [ "$RL_KIND" = pane ]; then
      echo "auto name=$name relocate=$RL_PANE"
      exit 0
    fi
    echo "manual (background job; an explicit /pass moves it into tmux)"
    exit 1
  fi

  # write: same validation order and exit codes as the tmux path, before any relocation step
  note="$(cat; printf x)"
  note="${note%x}"
  if [ -z "${note//[[:space:]]/}" ]; then
    echo "pass: empty note rejected" >&2; exit 1
  fi
  n="$(printf '%s' "$note" | wc -m | tr -d ' ')"
  if [ "$n" -gt "$CAP" ]; then
    echo "pass: note is $n chars; cap is $CAP. Shorten and retry." >&2
    bg_log write "-" "rejected-too-long($n)"
    exit 2
  fi
  if ! printf '%s\n' "$note" | tr -d '\r' | grep -qx '## Done last session[[:space:]]*'; then
    echo "pass: nothing saved — add a line that is exactly '## Done last session' (right after the title is conventional) listing what was done/shipped + key decisions, then re-run write." >&2
    bg_log write "-" "rejected-no-done-section"
    exit 4
  fi
  if [ -z "$name" ]; then
    echo "pass: this session runs as a background job but has no usable name; /rename it, then run /pass again." >&2
    bg_log write "-" "bg-refused(no-name)"
    exit 1
  fi
  if [ "$EXPLICIT" != 1 ] && [ -f "$STATE/optout/$name" ]; then
    bg_save_note "$sid" "$note" || exit 1
    bg_log write "$name" "saved($n),optout-no-clear,bg"
    echo "pass: '$name' is opted out (/pass manual); note saved, not clearing"
    exit 0
  fi
  if [ "$EXPLICIT" != 1 ]; then
    mmin="${PASS_MIN_CONTEXT:-90000}"
    [[ "$mmin" =~ ^[0-9]{1,6}$ ]] || mmin=90000
    tx="$(find_transcript)"
    if [ -n "$tx" ]; then
      ctx="$(last_context "$tx")"
      if [[ "$ctx" =~ ^[0-9]+$ ]] && [ "$ctx" -lt "$mmin" ]; then
        bg_save_note "$sid" "$note" || exit 1
        bg_log write "$name" "saved($n),min-context($ctx<$mmin),bg"
        echo "pass: context $ctx < $mmin; note saved, not clearing"
        exit 0
      fi
    fi
  fi
  if ! bg_checks "$name" "$sid"; then
    echo "pass: $BG_REFUSE" >&2
    bg_log write "$name" "bg-refused($BG_REFUSE_LOG)"
    exit 1
  fi
  if [ "$RL_KIND" = new ]; then
    if [ "$EXPLICIT" != 1 ]; then
      bg_save_note "$sid" "$note" || exit 1
      bg_log write "$name" "saved($n),bg-no-window"
      echo "pass: this session runs as a background job and no tmux window named '$name' exists; note saved ($n chars), not moving it. An explicit /pass moves it into tmux."
      exit 0
    fi
  fi
  bg_save_note "$sid" "$note" || exit 1
  job="$(date +%s%N 2>/dev/null).$$"
  [[ "$job" =~ ^[0-9]+\.[0-9]+$ ]] || job="$(date +%s)$RANDOM.$$"
  if [ "$RL_KIND" = pane ]; then where="$RL_PANE"; else where="new window"; fi
  t="$(mktemp "$STATE/.relocate.XXXXXX")"
  {
    printf 'name=%s\nsid=%s\nshort=%s\ncwd=%s\n' "$name" "$sid" "$BG_SHORT" "$BG_CWD"
    printf 'pane=%s\n' "$([ "$RL_KIND" = pane ] && echo "$RL_PANE" || echo new)"
    printf 'explicit=%s\nepoch=%s\njob=%s\nbgpid=%s\ntitle=%s\n' "$EXPLICIT" "$(date +%s)" "$job" "$BG_PID" "$(current_title)"
  } >"$t"
  mv -f "$t" "$req"
  launcher=""
  if [ "${PASS_RELOCATE_NO_SYSTEMD:-0}" != 1 ] && command -v systemd-run >/dev/null 2>&1 && command -v systemctl >/dev/null 2>&1; then
    # Outlive `claude stop`: a transient user unit is not a descendant of the session.
    sysst="$(systemctl --user is-system-running 2>&1 || true)"
    case "$sysst" in
      running|degraded|starting|initializing|stopping|maintenance)
        sdargs=(--user --collect --quiet --unit "pass-relocate-$BG_SHORT-$(date +%s)")
        sdargs+=("--setenv=HOME=$HOME" "--setenv=PATH=$PATH")
        [ -n "${XDG_RUNTIME_DIR:-}" ] && sdargs+=("--setenv=XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR")
        [ -n "${TMUX_TMPDIR:-}" ] && sdargs+=("--setenv=TMUX_TMPDIR=$TMUX_TMPDIR")
        for v in $(compgen -e); do
          case "$v" in PASS_*) val="${!v}"; [[ "$val" == *$'\n'* ]] || sdargs+=("--setenv=$v=$val") ;; esac
        done
        if systemd-run "${sdargs[@]}" bash "$(dirname "$lib")/pass-relocate.sh" --job "$sid" "$job" </dev/null >/dev/null 2>&1; then
          launcher=systemd-run
        fi ;;
    esac
  fi
  if [ -z "$launcher" ] && setsid -f bash "$(dirname "$lib")/pass-relocate.sh" --job "$sid" "$job" </dev/null >/dev/null 2>&1; then
    launcher=setsid
  fi
  if [ -z "$launcher" ]; then
    rm -f "$req"
    echo "pass: could not start the relocation job; note saved in $ROOT/relocate/$sid.md." >&2
    bg_log write "$name" "saved($n),bg-launch-failed"
    exit 1
  fi
  bg_log write "$name" "saved($n),bg-relocate-queued($where),launcher=$launcher"
  echo "pass: this session runs as a background job; note saved ($n chars). When this turn ends the job is stopped (anything it still runs in the background ends with it) and the conversation is reopened in tmux window '$name' ($where), then cleared and resumed from the note. /pass cancel stops it, but only before this turn ends."
  exit 0
}

if [ -z "${TMUX_PANE:-}" ]; then
  bg_handle "$@"
  if [ "$cmd" = status ]; then echo "manual (not in tmux)"; exit 1; fi
  echo "pass: not in a tmux pane (\$TMUX_PANE unset); auto-pass needs tmux" >&2
  exit 1
fi

PANE="$TMUX_PANE"
[[ "$PANE" =~ ^%[0-9]+$ ]] || { echo "pass: unparseable \$TMUX_PANE '$PANE'" >&2; exit 1; }
N="${PANE#%}"
OPTIN="$STATE/pane-$N.optin"
READY="$STATE/pane-$N.ready"
OPTOUT_DIR="$STATE/optout"
CLEARING="$STATE/pane-$N.clearing"

log() { # log <subcommand> <name> <result>
  mkdir -p "$STATE" 2>/dev/null || return 0
  printf '%s pass.sh %s pane=%s name=%s %s\n' \
    "$(date +%FT%T%z)" "$1" "$PANE" "$2" "$3" >>"$STATE/pass.log" 2>/dev/null || true
}

cur_pid() { "${TMUXC[@]}" display-message -p -t "$PANE" '#{pane_pid}' 2>/dev/null || true; }

# Nearest Claude Code ancestor of this helper (it runs under Claude's Bash tool).
claude_ancestor() {
  local pid=$$ i ppid
  for ((i = 0; i < 10; i++)); do
    ppid="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')" || return 1
    [[ "$ppid" =~ ^[0-9]+$ ]] && [ "$ppid" -gt 1 ] || return 1
    if is_claude_pid "$ppid"; then printf '%s' "$ppid"; return 0; fi
    pid="$ppid"
  done
  return 1
}

CPID="$(claude_ancestor || true)"

# Opt-out by session name. Names are validated before use, so they cannot
# contain '/' or start with '.', and never escape the dir.
optout_exists() { valid_name "$1" && [ -f "$OPTOUT_DIR/$1" ]; }
optout_set() {
  valid_name "$1" || return 1
  mkdir -p "$OPTOUT_DIR"
  chmod 700 "$ROOT" "$STATE" "$OPTOUT_DIR"
  printf 'name=%s\nepoch=%s\n' "$1" "$(date +%s)" >"$OPTOUT_DIR/$1"
}
optout_clear() { valid_name "$1" && rm -f "$OPTOUT_DIR/$1"; return 0; }

# Sets OPT_NAME, OPT_ONESHOT; returns 0 valid, 1 none, 2 stale (and removes it).
# Valid iff pane_pid is the live one AND claude_pid is this helper's Claude.
load_optin() {
  OPT_NAME=""; OPT_ONESHOT=""
  [ -f "$OPTIN" ] || return 1
  local name pid cp live
  name="$(sed -n 's/^name=//p' "$OPTIN" | head -n1)"
  pid="$(sed -n 's/^pane_pid=//p' "$OPTIN" | head -n1)"
  cp="$(sed -n 's/^claude_pid=//p' "$OPTIN" | head -n1)"
  live="$(cur_pid)"
  if [ -n "$name" ] && [ -n "$live" ] && [ "$pid" = "$live" ] \
     && [ -n "$CPID" ] && [ "$cp" = "$CPID" ]; then
    OPT_NAME="$name"
    OPT_ONESHOT="$(sed -n 's/^oneshot=//p' "$OPTIN" | head -n1)"
    return 0
  fi
  rm -f "$OPTIN" "$READY" "$CLEARING"
  return 2
}

case "$cmd" in
  auto)
    name="$*"
    if [ -z "$name" ]; then name="$(derive_name)"; name="${name#* }"; fi
    if [ -z "$CPID" ]; then
      echo "pass: no Claude Code process found above this shell; run /pass from inside Claude Code" >&2
      exit 1
    fi
    live="$(cur_pid)"
    [ -n "$live" ] || { echo "pass: cannot read pane pid for $PANE" >&2; exit 1; }
    mkdir -p "$STATE"
    chmod 700 "$ROOT" "$STATE"
    optout_clear "$name"
    tmp="$(mktemp "$STATE/.optin.XXXXXX")"
    printf 'name=%s\npane_pid=%s\nclaude_pid=%s\ntitle_at_optin=%s\n' \
      "$name" "$live" "$CPID" "$(current_title)" >"$tmp"
    mv -f "$tmp" "$OPTIN"
    rm -f "$READY" "$CLEARING"
    log auto "$name" "ok(claude_pid=$CPID)"
    echo "pass: auto — session '$name' (pane $PANE). /pass writes a note; the session then clears itself and resumes from it."
    ;;
  manual)
    name="-"
    if [ -f "$OPTIN" ]; then name="$(sed -n 's/^name=//p' "$OPTIN" | head -n1)"; fi
    dname="$(derive_name)"; dname="${dname#* }"
    rm -f "$OPTIN" "$READY" "$CLEARING"
    if optout_set "$dname"; then
      log manual "$dname" "ok(optout)"
    else
      log manual "$name" ok
    fi
    echo "pass: manual — pane $PANE no longer auto-clears; opted out '${dname:-$name}'."
    ;;
  status)
    rc=0
    load_optin || rc=$?
    if [ "$rc" -eq 0 ]; then
      ready=no
      [ -f "$READY" ] && ready=yes
      if [ "$OPT_ONESHOT" = 1 ]; then
        echo "manual (one-shot pass pending name=$OPT_NAME ready=$ready)"
        exit 1
      fi
      if optout_exists "$OPT_NAME"; then
        echo "manual (opted out name=$OPT_NAME)"
        exit 1
      fi
      echo "auto name=$OPT_NAME pane=$PANE ready=$ready"
      exit 0
    fi
    [ "$rc" -eq 2 ] && echo "stale opt-in removed"
    # Default on: no valid opt-in, but not opted out either.
    dd="$(derive_name)"; dtier="${dd%% *}"; dname="${dd#* }"
    if [ "$dtier" != default ] && ! optout_exists "$dname"; then
      ready=no
      [ -f "$READY" ] && ready=yes
      echo "auto name=$dname pane=$PANE ready=$ready"
      exit 0
    fi
    echo "manual"
    exit 1
    ;;
  write)
    note="$(cat; printf x)"
    note="${note%x}"
    if [ -z "${note//[[:space:]]/}" ]; then
      echo "pass: empty note rejected" >&2; exit 1
    fi
    n="$(printf '%s' "$note" | wc -m | tr -d ' ')"
    if [ "$n" -gt "$CAP" ]; then
      echo "pass: note is $n chars; cap is $CAP. Shorten and retry." >&2
      log write "-" "rejected-too-long($n)"
      exit 2
    fi
    argname="$*"
    SKIP_OPTOUT=""
    rc=0
    load_optin || rc=$?
    [ "$rc" -eq 2 ] && echo "pass: stale opt-in removed" >&2
    if ! printf '%s\n' "$note" | tr -d '\r' | grep -qx '## Done last session[[:space:]]*'; then
      echo "pass: nothing saved — add a line that is exactly '## Done last session' (right after the title is conventional) listing what was done/shipped + key decisions, then re-run write." >&2
      log write "${OPT_NAME:--}" "rejected-no-done-section"
      exit 4
    fi
    if [ "$rc" -ne 0 ] || { [ "$OPT_ONESHOT" = 1 ] && [ -n "$argname" ] && [ "$argname" != "$OPT_NAME" ]; }; then
      # No opt-in (or a one-shot being renamed): create/rewrite a one-shot one.
      name="$argname"
      if [ -z "$name" ]; then name="$(derive_name)"; name="${name#* }"; fi
      if [ -z "$CPID" ]; then
        echo "pass: no Claude Code process found above this shell; run /pass from inside Claude Code" >&2
        exit 1
      fi
      live="$(cur_pid)"
      [ -n "$live" ] || { echo "pass: cannot read pane pid for $PANE" >&2; exit 1; }
      mkdir -p "$STATE"
      chmod 700 "$ROOT" "$STATE"
      if [ "$EXPLICIT" != 1 ] && optout_exists "$name"; then
        # Opted out and not an explicit user /pass: no opt-in, no ready marker.
        SKIP_OPTOUT="$name"
      else
      tmp="$(mktemp "$STATE/.optin.XXXXXX")"
      if optout_exists "$name"; then
        # Opted out: an explicit pass still clears once; status stays manual.
        printf 'name=%s\npane_pid=%s\nclaude_pid=%s\noneshot=1\ntitle_at_optin=%s\n' \
          "$name" "$live" "$CPID" "$(current_title)" >"$tmp"
        oneshot_made=1
      else
        # Default on: behave like `auto`.
        printf 'name=%s\npane_pid=%s\nclaude_pid=%s\ntitle_at_optin=%s\n' \
          "$name" "$live" "$CPID" "$(current_title)" >"$tmp"
        oneshot_made=0
      fi
      mv -f "$tmp" "$OPTIN"
      OPT_NAME="$name"
      if [ "$oneshot_made" = 1 ]; then
        log write "$name" "oneshot-optin(claude_pid=$CPID)"
      else
        log write "$name" "default-optin(claude_pid=$CPID)"
      fi
      fi
    elif [ -n "$argname" ] && [ "$argname" != "$OPT_NAME" ]; then
      echo "pass: session is opted in as '$OPT_NAME'; ignoring name '$argname'" >&2
    elif [ -z "$argname" ]; then
      # Refresh: only a session title set AFTER opting in (/rename) renames
      # an opt-in; a title that already existed at opt-in, and the tmux
      # fallbacks, never override the name given to `auto`. Legacy opt-ins
      # (no title_at_optin key) rename whenever the title differs.
      new="$(current_title)"
      if grep -q '^title_at_optin=' "$OPTIN" 2>/dev/null; then
        tao="$(sed -n 's/^title_at_optin=//p' "$OPTIN" | head -n1)"
      else
        tao=""
      fi
      if [ -n "$new" ] && [ "$new" != "$OPT_NAME" ] && [ "$new" != "$tao" ]; then
        # Rewrite name + title_at_optin; every other line (pane_pid,
        # claude_pid, oneshot, ...) is carried over verbatim.
        tmp="$(mktemp "$STATE/.optin.XXXXXX")"
        {
          printf 'name=%s\n' "$new"
          grep -v -e '^name=' -e '^title_at_optin=' "$OPTIN" || true
          printf 'title_at_optin=%s\n' "$new"
        } >"$tmp"
        mv -f "$tmp" "$OPTIN"
        log write "$new" "renamed $OPT_NAME -> $new"
        OPT_NAME="$new"
      fi
    fi
    if [ -z "$SKIP_OPTOUT" ] && [ "$EXPLICIT" != 1 ] && [ -n "${OPT_NAME:-}" ] && optout_exists "$OPT_NAME"; then
      SKIP_OPTOUT="$OPT_NAME"
    fi
    dest="$ROOT/pane-$N.md"
    tmp="$(mktemp "$ROOT/.pane-$N.XXXXXX")"
    printf '%s' "$note" >"$tmp"
    mv -f "$tmp" "$dest"
    if [ -n "$SKIP_OPTOUT" ]; then
      log write "$SKIP_OPTOUT" "saved($n),optout-no-clear"
      echo "pass: '$SKIP_OPTOUT' is opted out (/pass manual); note saved, not clearing"
      exit 0
    fi
    # Minimum-context gate (twin of the Stop hook's; see last_context).
    if [ "$EXPLICIT" != 1 ]; then
      mmin="${PASS_MIN_CONTEXT:-90000}"
      [[ "$mmin" =~ ^[0-9]{1,6}$ ]] || mmin=90000
      tx="$(find_transcript)"
      if [ -n "$tx" ]; then
        ctx="$(last_context "$tx")"
        if [[ "$ctx" =~ ^[0-9]+$ ]] && [ "$ctx" -lt "$mmin" ]; then
          log write "$OPT_NAME" "saved($n),min-context($ctx<$mmin)"
          echo "pass: context $ctx < $mmin; note saved, not clearing"
          exit 0
        fi
      fi
    fi
    # Loop guard (same window as the Stop hook's): inside it, save the note but
    # set no ready marker, and say so — the model must not expect a clear.
    min="${PASS_MIN_INTERVAL:-600}"
    [[ "$min" =~ ^[0-9]{1,6}$ ]] || min=600
    last="$(sed -n 's/^epoch=//p' "$STATE/pane-$N.lastclear" 2>/dev/null | head -n1 || true)"
    now="$(date +%s)"
    if [[ "$last" =~ ^[0-9]+$ ]] && [ $((now - last)) -lt "$min" ] && [ $((now - last)) -ge 0 ]; then
      rm -f "$READY"
      log write "$OPT_NAME" "saved($n),cooldown($((now - last))s)"
      echo "pass: saved $dest; auto-clear is on cooldown for $((min - (now - last)))s (last auto-clear $((now - last))s ago) — nothing will clear this turn."
      exit 0
    fi
    rtmp="$(mktemp "$STATE/.ready.XXXXXX")"
    printf 'name=%s\nepoch=%s\n' "$OPT_NAME" "$(date +%s)" >"$rtmp"
    [ "$EXPLICIT" = 1 ] && printf 'explicit=1\n' >>"$rtmp"
    mv -f "$rtmp" "$READY"
    log write "$OPT_NAME" "saved($n)"
    echo "pass: saved $dest ($n chars). Auto-clear is queued for the end of this turn; /pass cancel stops it until the clear is typed."
    ;;
  cancel)
    name="-"
    if [ -f "$OPTIN" ]; then name="$(sed -n 's/^name=//p' "$OPTIN" | head -n1)"; fi
    rm -f "$READY" "$CLEARING"
    log cancel "$name" ok
    echo "pass: cancelled — no auto-clear queued for pane $PANE."
    ;;
esac
