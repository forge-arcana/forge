#!/usr/bin/env bash
# cycle.sh — opt-in auto-cycle helper (state keyed by tmux pane, bound to
# the Claude Code process that ran `auto`).
# Subcommands: auto [name...] | manual | status | write [name...] (note on stdin)
# | cancel. `on` / `off` are silent aliases of auto / manual.
# Exit codes: 0 ok, 1 error / empty note, 2 note over the length cap, 3 retired
# (write no longer needs an opt-in), 4 note lacks a '## Done last session' line
# (write), 64 usage / invalid name.
# write order: empty (1) -> length cap (2) -> invalid name arg (64) -> section
# check (4) -> only then, if not opted in, a ONE-SHOT opt-in is created (same file
# as `auto` plus a line oneshot=1; name = name arg, else derive_name). A
# rejected note never leaves an opt-in behind. Every opt-in also stores
# title_at_optin=<session title when it was created, or empty>. While opted
# in, a no-arg write renames the opt-in to the session title (customTitle) only
# when that title differs from both the stored name and title_at_optin, i.e.
# the user ran /rename after opting in; an explicit `auto <name>` is never
# overridden by a title that already existed. A legacy opt-in without the
# title_at_optin key renames whenever the title differs from the name.
# A one-shot opt-in is left in place after the clear (the hooks need it through
# the resume); it dies with the Claude process (claude_pid binding). `status`
# reports it as manual, so the model-initiated auto-cycle rule never fires on it.
# State contract: see core/hooks/cycle-stop.sh header.
set -euo pipefail
umask 077

# State root + one-time move of the legacy ~/.claude/handoffs dir. Keep in sync
# with core/hooks/cycle-stop.sh and core/hooks/cycle-start.sh (same function).
# CYCLE_DIR set → that dir, never migrate. Else ~/.claude/cycles; when it does
# not exist yet and ~/.claude/handoffs is a real dir, rename it and leave a
# relative symlink behind. Race-tolerant and silent; sets MIGRATED=1 only in
# the process whose mv won. Nothing may create the new root before this runs.
resolve_root() {
  MIGRATED=0
  if [ -n "${CYCLE_DIR:-}" ]; then ROOT="$CYCLE_DIR"; return 0; fi
  ROOT="$HOME/.claude/cycles"
  local old="$HOME/.claude/handoffs"
  if [ "${1:-}" != nomigrate ] && [ ! -e "$ROOT" ] && [ ! -L "$ROOT" ] \
     && [ -d "$old" ] && [ ! -L "$old" ]; then
    if mv -T "$old" "$ROOT" 2>/dev/null; then MIGRATED=1; fi
    if ! ln -sT cycles "$old" 2>/dev/null && [ "$MIGRATED" = 1 ]; then
      { mkdir -p "$ROOT/state" && printf '%s resolve_root pane=%s name=- legacy symlink not created (~/.claude/handoffs exists?)\n' \
        "$(date +%FT%T%z)" "${TMUX_PANE:-?}" >>"$ROOT/state/cycle.log"; } 2>/dev/null || true
    fi
  fi
  return 0
}
resolve_root
STATE="$ROOT/state"
if [ "$MIGRATED" = 1 ]; then
  { mkdir -p "$STATE" && printf '%s cycle.sh pane=%s name=- migrated legacy state dir ~/.claude/handoffs -> ~/.claude/cycles\n' \
    "$(date +%FT%T%z)" "${TMUX_PANE:-?}" >>"$STATE/cycle.log"; } 2>/dev/null || true
fi
CAP=9000
NAME_RE='^[A-Za-z0-9][A-Za-z0-9._ -]{0,63}$'
read -r -a TMUXC <<< "${CYCLE_TMUX:-tmux}"
[ "${#TMUXC[@]}" -gt 0 ] || TMUXC=(tmux)

usage() {
  echo "usage: cycle.sh auto [name...] | manual | status | write [name...] | cancel" >&2
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
# just a program name, else the tmux session name, else "cycle". Each candidate
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
  printf 'default cycle'
  return 0
}

cmd="${1:-}"
[ -n "$cmd" ] || usage
shift || true
case "$cmd" in
  on) cmd=auto ;;
  off) cmd=manual ;;
  auto|manual|status|write|cancel) ;;
  *) usage ;;
esac

if { [ "$cmd" = auto ] || [ "$cmd" = write ]; } && [ $# -gt 0 ] && ! valid_name "$*"; then
  echo "cycle: invalid name; 1-64 chars of A-Za-z0-9._ - (space allowed), starting with a letter or digit, no trailing space" >&2
  exit 64
fi

if ! command -v "${TMUXC[0]}" >/dev/null 2>&1; then
  if [ "$cmd" = status ]; then echo "manual (not in tmux)"; exit 1; fi
  echo "cycle: tmux is required" >&2; exit 1
fi
if [ -z "${TMUX_PANE:-}" ]; then
  if [ "$cmd" = status ]; then echo "manual (not in tmux)"; exit 1; fi
  echo "cycle: not in a tmux pane (\$TMUX_PANE unset); auto-cycle needs tmux" >&2
  exit 1
fi

PANE="$TMUX_PANE"
[[ "$PANE" =~ ^%[0-9]+$ ]] || { echo "cycle: unparseable \$TMUX_PANE '$PANE'" >&2; exit 1; }
N="${PANE#%}"
OPTIN="$STATE/pane-$N.optin"
READY="$STATE/pane-$N.ready"
CLEARING="$STATE/pane-$N.clearing"

log() { # log <subcommand> <name> <result>
  mkdir -p "$STATE" 2>/dev/null || return 0
  printf '%s cycle.sh %s pane=%s name=%s %s\n' \
    "$(date +%FT%T%z)" "$1" "$PANE" "$2" "$3" >>"$STATE/cycle.log" 2>/dev/null || true
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
  auto)
    name="$*"
    if [ -z "$name" ]; then name="$(derive_name)"; name="${name#* }"; fi
    if [ -z "$CPID" ]; then
      echo "cycle: no Claude Code process found above this shell; run /cycle from inside Claude Code" >&2
      exit 1
    fi
    live="$(cur_pid)"
    [ -n "$live" ] || { echo "cycle: cannot read pane pid for $PANE" >&2; exit 1; }
    mkdir -p "$STATE"
    chmod 700 "$ROOT" "$STATE"
    tmp="$(mktemp "$STATE/.optin.XXXXXX")"
    printf 'name=%s\npane_pid=%s\nclaude_pid=%s\ntitle_at_optin=%s\n' \
      "$name" "$live" "$CPID" "$(current_title)" >"$tmp"
    mv -f "$tmp" "$OPTIN"
    rm -f "$READY" "$CLEARING"
    log auto "$name" "ok(claude_pid=$CPID)"
    echo "cycle: auto — session '$name' (pane $PANE). /cycle writes a note; the session then clears itself and resumes from it."
    ;;
  manual)
    name="-"
    if [ -f "$OPTIN" ]; then name="$(sed -n 's/^name=//p' "$OPTIN" | head -n1)"; fi
    rm -f "$OPTIN" "$READY" "$CLEARING"
    log manual "$name" ok
    echo "cycle: manual — pane $PANE no longer auto-clears."
    ;;
  status)
    rc=0
    load_optin || rc=$?
    if [ "$rc" -eq 0 ]; then
      ready=no
      [ -f "$READY" ] && ready=yes
      if [ "$OPT_ONESHOT" = 1 ]; then
        echo "manual (one-shot cycle pending name=$OPT_NAME ready=$ready)"
        exit 1
      fi
      echo "auto name=$OPT_NAME pane=$PANE ready=$ready"
      exit 0
    fi
    [ "$rc" -eq 2 ] && echo "stale opt-in removed"
    echo "manual"
    exit 1
    ;;
  write)
    note="$(cat; printf x)"
    note="${note%x}"
    if [ -z "${note//[[:space:]]/}" ]; then
      echo "cycle: empty note rejected" >&2; exit 1
    fi
    n="$(printf '%s' "$note" | wc -m | tr -d ' ')"
    if [ "$n" -gt "$CAP" ]; then
      echo "cycle: note is $n chars; cap is $CAP. Shorten and retry." >&2
      log write "-" "rejected-too-long($n)"
      exit 2
    fi
    argname="$*"
    rc=0
    load_optin || rc=$?
    [ "$rc" -eq 2 ] && echo "cycle: stale opt-in removed" >&2
    if ! printf '%s\n' "$note" | tr -d '\r' | grep -qx '## Done last session[[:space:]]*'; then
      echo "cycle: nothing saved — add a line that is exactly '## Done last session' (right after the title is conventional) listing what was done/shipped + key decisions, then re-run write." >&2
      log write "${OPT_NAME:--}" "rejected-no-done-section"
      exit 4
    fi
    if [ "$rc" -ne 0 ] || { [ "$OPT_ONESHOT" = 1 ] && [ -n "$argname" ] && [ "$argname" != "$OPT_NAME" ]; }; then
      # No opt-in (or a one-shot being renamed): create/rewrite a one-shot one.
      name="$argname"
      if [ -z "$name" ]; then name="$(derive_name)"; name="${name#* }"; fi
      if [ -z "$CPID" ]; then
        echo "cycle: no Claude Code process found above this shell; run /cycle from inside Claude Code" >&2
        exit 1
      fi
      live="$(cur_pid)"
      [ -n "$live" ] || { echo "cycle: cannot read pane pid for $PANE" >&2; exit 1; }
      mkdir -p "$STATE"
      chmod 700 "$ROOT" "$STATE"
      tmp="$(mktemp "$STATE/.optin.XXXXXX")"
      printf 'name=%s\npane_pid=%s\nclaude_pid=%s\noneshot=1\ntitle_at_optin=%s\n' \
        "$name" "$live" "$CPID" "$(current_title)" >"$tmp"
      mv -f "$tmp" "$OPTIN"
      OPT_NAME="$name"
      log write "$name" "oneshot-optin(claude_pid=$CPID)"
    elif [ -n "$argname" ] && [ "$argname" != "$OPT_NAME" ]; then
      echo "cycle: session is opted in as '$OPT_NAME'; ignoring name '$argname'" >&2
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
    dest="$ROOT/pane-$N.md"
    tmp="$(mktemp "$ROOT/.pane-$N.XXXXXX")"
    printf '%s' "$note" >"$tmp"
    mv -f "$tmp" "$dest"
    # Loop guard (same window as the Stop hook's): inside it, save the note but
    # set no ready marker, and say so — the model must not expect a clear.
    min="${CYCLE_MIN_INTERVAL:-600}"
    [[ "$min" =~ ^[0-9]{1,6}$ ]] || min=600
    last="$(sed -n 's/^epoch=//p' "$STATE/pane-$N.lastclear" 2>/dev/null | head -n1 || true)"
    now="$(date +%s)"
    if [[ "$last" =~ ^[0-9]+$ ]] && [ $((now - last)) -lt "$min" ] && [ $((now - last)) -ge 0 ]; then
      rm -f "$READY"
      log write "$OPT_NAME" "saved($n),cooldown($((now - last))s)"
      echo "cycle: saved $dest; auto-clear is on cooldown for $((min - (now - last)))s (last auto-clear $((now - last))s ago) — nothing will clear this turn."
      exit 0
    fi
    rtmp="$(mktemp "$STATE/.ready.XXXXXX")"
    printf 'name=%s\nepoch=%s\n' "$OPT_NAME" "$(date +%s)" >"$rtmp"
    mv -f "$rtmp" "$READY"
    log write "$OPT_NAME" "saved($n)"
    echo "cycle: saved $dest ($n chars). Auto-clear is queued for the end of this turn; /cycle cancel stops it until the clear is typed."
    ;;
  cancel)
    name="-"
    if [ -f "$OPTIN" ]; then name="$(sed -n 's/^name=//p' "$OPTIN" | head -n1)"; fi
    rm -f "$READY" "$CLEARING"
    log cancel "$name" ok
    echo "cycle: cancelled — no auto-clear queued for pane $PANE."
    ;;
esac
