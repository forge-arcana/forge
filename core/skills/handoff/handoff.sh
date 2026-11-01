#!/usr/bin/env bash
# handoff.sh — opt-in auto-handoff helper (state keyed by tmux pane, bound to
# the Claude Code process that ran `on`).
# Subcommands: on <name...> | off | status | write [name...] (note on stdin) | cancel
# Exit codes: 0 ok, 1 error / empty note, 2 note over the length cap, 3 retired
# (write no longer needs an opt-in), 4 note lacks a '## Done last session' line
# (write), 64 usage / invalid name.
# write order: empty (1) -> length cap (2) -> invalid name arg (64) -> section
# check (4) -> only then, if not opted in, a ONE-SHOT opt-in is created (same file
# as `on` plus a line oneshot=1; name = name arg, else tmux session name
# sanitised, else "handoff"). A rejected note never leaves an opt-in behind.
# A one-shot opt-in is left in place after the clear (the hooks need it through
# the resume); it dies with the Claude process (claude_pid binding). `status`
# reports it as off, so the model-initiated auto-handoff rule never fires on it.
# State contract: see core/hooks/handoff-stop.sh header.
set -euo pipefail
umask 077

ROOT="${HANDOFF_DIR:-$HOME/.claude/handoffs}"
STATE="$ROOT/state"
CAP=9000
NAME_RE='^[A-Za-z0-9][A-Za-z0-9._ -]{0,63}$'
read -r -a TMUXC <<< "${HANDOFF_TMUX:-tmux}"
[ "${#TMUXC[@]}" -gt 0 ] || TMUXC=(tmux)

usage() {
  echo "usage: handoff.sh on <name...> | off | status | write [name...] | cancel" >&2
  exit 64
}

# ASCII-only regex under the C locale; the rest of the helper keeps the user's
# locale so `wc -m` counts characters, not bytes.
valid_name() ( export LC_ALL=C; [[ "$1" =~ $NAME_RE ]] && [[ "$1" != *" " ]] )

cmd="${1:-}"
[ -n "$cmd" ] || usage
shift || true
case "$cmd" in on|off|status|write|cancel) ;; *) usage ;; esac

if { [ "$cmd" = on ] || { [ "$cmd" = write ] && [ $# -gt 0 ]; }; } && ! valid_name "$*"; then
  echo "handoff: invalid name; 1-64 chars of A-Za-z0-9._ - (space allowed), starting with a letter or digit, no trailing space" >&2
  exit 64
fi

if ! command -v "${TMUXC[0]}" >/dev/null 2>&1; then
  if [ "$cmd" = status ]; then echo "off (not in tmux)"; exit 1; fi
  echo "handoff: tmux is required" >&2; exit 1
fi
if [ -z "${TMUX_PANE:-}" ]; then
  if [ "$cmd" = status ]; then echo "off (not in tmux)"; exit 1; fi
  echo "handoff: not in a tmux pane (\$TMUX_PANE unset); auto-handoff needs tmux" >&2
  exit 1
fi

PANE="$TMUX_PANE"
[[ "$PANE" =~ ^%[0-9]+$ ]] || { echo "handoff: unparseable \$TMUX_PANE '$PANE'" >&2; exit 1; }
N="${PANE#%}"
OPTIN="$STATE/pane-$N.optin"
READY="$STATE/pane-$N.ready"
CLEARING="$STATE/pane-$N.clearing"

log() { # log <subcommand> <name> <result>
  mkdir -p "$STATE" 2>/dev/null || return 0
  printf '%s handoff.sh %s pane=%s name=%s %s\n' \
    "$(date +%FT%T%z)" "$1" "$PANE" "$2" "$3" >>"$STATE/handoff.log" 2>/dev/null || true
}

cur_pid() { "${TMUXC[@]}" display-message -p -t "$PANE" '#{pane_pid}' 2>/dev/null || true; }

is_claude_pid() {
  local comm args
  [[ "${1:-}" =~ ^[0-9]+$ ]] || return 1
  comm="$(ps -o comm= -p "$1" 2>/dev/null)" || return 1
  [ "$comm" = claude ] && return 0
  [ "$comm" = node ] || return 1
  args="$(ps -o args= -p "$1" 2>/dev/null)" || return 1
  [[ "$args" == *claude* ]]
}

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
  on)
    name="$*"
    if [ -z "$CPID" ]; then
      echo "handoff: no Claude Code process found above this shell; run /handoff from inside Claude Code" >&2
      exit 1
    fi
    live="$(cur_pid)"
    [ -n "$live" ] || { echo "handoff: cannot read pane pid for $PANE" >&2; exit 1; }
    mkdir -p "$STATE"
    chmod 700 "$ROOT" "$STATE"
    tmp="$(mktemp "$STATE/.optin.XXXXXX")"
    printf 'name=%s\npane_pid=%s\nclaude_pid=%s\n' "$name" "$live" "$CPID" >"$tmp"
    mv -f "$tmp" "$OPTIN"
    rm -f "$READY" "$CLEARING"
    log on "$name" "ok(claude_pid=$CPID)"
    echo "handoff: on — session '$name' (pane $PANE). /handoff writes a note; the session then clears itself and resumes from it."
    ;;
  off)
    name="-"
    if [ -f "$OPTIN" ]; then name="$(sed -n 's/^name=//p' "$OPTIN" | head -n1)"; fi
    rm -f "$OPTIN" "$READY" "$CLEARING"
    log off "$name" ok
    echo "handoff: off — pane $PANE no longer auto-clears."
    ;;
  status)
    rc=0
    load_optin || rc=$?
    if [ "$rc" -eq 0 ]; then
      ready=no
      [ -f "$READY" ] && ready=yes
      if [ "$OPT_ONESHOT" = 1 ]; then
        echo "off (one-shot handoff pending name=$OPT_NAME ready=$ready)"
        exit 1
      fi
      echo "on name=$OPT_NAME pane=$PANE ready=$ready"
      exit 0
    fi
    [ "$rc" -eq 2 ] && echo "stale opt-in removed"
    echo "off"
    exit 1
    ;;
  write)
    note="$(cat; printf x)"
    note="${note%x}"
    if [ -z "${note//[[:space:]]/}" ]; then
      echo "handoff: empty note rejected" >&2; exit 1
    fi
    n="$(printf '%s' "$note" | wc -m | tr -d ' ')"
    if [ "$n" -gt "$CAP" ]; then
      echo "handoff: note is $n chars; cap is $CAP. Shorten and retry." >&2
      log write "-" "rejected-too-long($n)"
      exit 2
    fi
    argname="$*"
    rc=0
    load_optin || rc=$?
    [ "$rc" -eq 2 ] && echo "handoff: stale opt-in removed" >&2
    if ! printf '%s\n' "$note" | tr -d '\r' | grep -qx '## Done last session[[:space:]]*'; then
      echo "handoff: nothing saved — add a line that is exactly '## Done last session' (right after the title is conventional) listing what was done/shipped + key decisions, then re-run write." >&2
      log write "${OPT_NAME:--}" "rejected-no-done-section"
      exit 4
    fi
    if [ "$rc" -ne 0 ] || { [ "$OPT_ONESHOT" = 1 ] && [ -n "$argname" ] && [ "$argname" != "$OPT_NAME" ]; }; then
      # No opt-in (or a one-shot being renamed): create/rewrite a one-shot one.
      name="$argname"
      if [ -z "$name" ]; then
        name="$("${TMUXC[@]}" display-message -p -t "$PANE" '#{session_name}' 2>/dev/null || true)"
        name="$(printf '%s' "$name" | LC_ALL=C tr -c 'A-Za-z0-9._ -' '-' | LC_ALL=C sed 's/^[^A-Za-z0-9]*//' | cut -c1-64 | sed 's/ *$//')"
        valid_name "$name" || name=handoff
      fi
      if [ -z "$CPID" ]; then
        echo "handoff: no Claude Code process found above this shell; run /handoff from inside Claude Code" >&2
        exit 1
      fi
      live="$(cur_pid)"
      [ -n "$live" ] || { echo "handoff: cannot read pane pid for $PANE" >&2; exit 1; }
      mkdir -p "$STATE"
      chmod 700 "$ROOT" "$STATE"
      tmp="$(mktemp "$STATE/.optin.XXXXXX")"
      printf 'name=%s\npane_pid=%s\nclaude_pid=%s\noneshot=1\n' "$name" "$live" "$CPID" >"$tmp"
      mv -f "$tmp" "$OPTIN"
      OPT_NAME="$name"
      log write "$name" "oneshot-optin(claude_pid=$CPID)"
    elif [ -n "$argname" ] && [ "$argname" != "$OPT_NAME" ]; then
      echo "handoff: session is opted in as '$OPT_NAME'; ignoring name '$argname'" >&2
    fi
    dest="$ROOT/pane-$N.md"
    tmp="$(mktemp "$ROOT/.pane-$N.XXXXXX")"
    printf '%s' "$note" >"$tmp"
    mv -f "$tmp" "$dest"
    # Loop guard (same window as the Stop hook's): inside it, save the note but
    # set no ready marker, and say so — the model must not expect a clear.
    min="${HANDOFF_MIN_INTERVAL:-600}"
    [[ "$min" =~ ^[0-9]{1,6}$ ]] || min=600
    last="$(sed -n 's/^epoch=//p' "$STATE/pane-$N.lastclear" 2>/dev/null | head -n1 || true)"
    now="$(date +%s)"
    if [[ "$last" =~ ^[0-9]+$ ]] && [ $((now - last)) -lt "$min" ] && [ $((now - last)) -ge 0 ]; then
      rm -f "$READY"
      log write "$OPT_NAME" "saved($n),cooldown($((now - last))s)"
      echo "handoff: saved $dest; auto-clear is on cooldown for $((min - (now - last)))s (last auto-clear $((now - last))s ago) — nothing will clear this turn."
      exit 0
    fi
    rtmp="$(mktemp "$STATE/.ready.XXXXXX")"
    printf 'name=%s\nepoch=%s\n' "$OPT_NAME" "$(date +%s)" >"$rtmp"
    mv -f "$rtmp" "$READY"
    log write "$OPT_NAME" "saved($n)"
    echo "handoff: saved $dest ($n chars). Auto-clear is queued for the end of this turn; /handoff cancel stops it until the clear is typed."
    ;;
  cancel)
    name="-"
    if [ -f "$OPTIN" ]; then name="$(sed -n 's/^name=//p' "$OPTIN" | head -n1)"; fi
    rm -f "$READY" "$CLEARING"
    log cancel "$name" ok
    echo "handoff: cancelled — no auto-clear queued for pane $PANE."
    ;;
esac
