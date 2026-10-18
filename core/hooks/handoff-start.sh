#!/usr/bin/env bash
#
# SessionStart hook (matcher `clear`) — the injection half of opt-in
# auto-handoff. handoff-stop.sh types `/clear <name>` into the pane after
# writing a per-pane clearing token; this hook fires on that clear and injects
# the pane's handoff note (<root>/pane-<N>.md) as additionalContext, archives
# the note, and only after printing the JSON writes state/pane-<N>.injected
# (epoch=, at=, transcript= the new transcript_path, size= its bytes now) so
# the Stop hook's job knows the resume prompt has something to point at, and
# can check the new transcript for user activity before typing it.
#
# Why a token gate: a /clear the user types by hand must never resurrect an
# old handoff. The note is injected ONLY when this pane holds a clearing token
# that the Stop hook wrote within ${HANDOFF_TOKEN_TTL:-180}s, whose name passes
# the contract regex, and whose claude_pid is this hook's own Claude Code
# ancestor. No token → silent no-op. Stale or foreign token → removed.
#
# Why archive after injecting: each note is single-use. Once injected it moves
# to <root>/archive/<namekey>-pane-<N>-<ts>.md (mode 600), so a later clear
# cannot re-read it. The newest 20 archives per pane are kept; older ones
# matching that exact pattern are deleted. The JSON is built BEFORE archiving,
# so a failed archive (logged) never withholds context the clear already cost.
#
# Size: the note is capped at 9000 chars and the whole additionalContext kept
# under 10000 chars (counted in codepoints by jq, not bytes).
#
# Fail open: any unexpected error → exit 0 with no output. Never break
# session start.
#
# State contract: see handoff-stop.sh header.
# settings.json: SessionStart, matcher `clear`.

set -uo pipefail
export LC_ALL=C
umask 077

ROOT="${HANDOFF_DIR:-$HOME/.claude/handoffs}"
STATE="$ROOT/state"
LOG="$STATE/handoff.log"
NAME_RE='^[A-Za-z0-9][A-Za-z0-9._ -]{0,63}$'
TTL="${HANDOFF_TOKEN_TTL:-180}"
[[ "$TTL" =~ ^[0-9]{1,6}$ ]] || TTL=180
KEEP_ARCHIVES=20

PANE="${TMUX_PANE:-}" NAME="-"

log() {
  mkdir -p "$STATE" 2>/dev/null || return 0
  printf '%s handoff-start pane=%s name=%s %s\n' \
    "$(date +%FT%T%z 2>/dev/null)" "${PANE:-?}" "${NAME:--}" "$*" >> "$LOG" 2>/dev/null
}

kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n 1; }

is_claude_pid() {
  local comm args
  [[ "${1:-}" =~ ^[0-9]+$ ]] || return 1
  comm="$(ps -o comm= -p "$1" 2>/dev/null)" || return 1
  [ "$comm" = claude ] && return 0
  [ "$comm" = node ] || return 1
  args="$(ps -o args= -p "$1" 2>/dev/null)" || return 1
  [[ "$args" == *claude* ]]
}

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

# Keep the newest $KEEP_ARCHIVES archives of pane N; touch only names that
# match this hook's own archive pattern exactly.
prune_archives() {
  local dir="$ROOT/archive" re f
  re="^[A-Za-z0-9][A-Za-z0-9._-]{0,63}-pane-$N-([0-9]{8}-[0-9]{6}(-[0-9]+)?)\\.md\$"
  [ -d "$dir" ] || return 0
  for f in "$dir"/*; do
    f="${f##*/}"
    [[ "$f" =~ $re ]] && printf '%s %s\n' "${BASH_REMATCH[1]}" "$f"
  done | sort -r | tail -n +"$((KEEP_ARCHIVES + 1))" | while read -r _ f; do
    rm -f -- "$dir/$f" && log "pruned archive/$f"
  done
}

command -v jq >/dev/null 2>&1 || exit 0
payload="$(cat 2>/dev/null)"
source_="$(printf '%s' "$payload" | jq -r '.source // empty' 2>/dev/null)"
[ -z "$source_" ] || [ "$source_" = "clear" ] || exit 0

[[ "$PANE" =~ ^%[0-9]+$ ]] || exit 0
N="${PANE#%}"
token="$STATE/pane-$N.clearing"
[ -f "$token" ] || exit 0

epoch="$(kv "$token" epoch)"
tname="$(kv "$token" name)"
tcpid="$(kv "$token" claude_pid)"
NAME="${tname:--}"
now="$(date +%s)"
if ! [[ "$epoch" =~ ^[0-9]+$ ]] || [ $((now - epoch)) -gt "$TTL" ] || [ $((now - epoch)) -lt -5 ]; then
  rm -f "$token"; log "stale or malformed token (epoch=${epoch:-none}), removed, no inject"; exit 0
fi
if ! [[ "$tname" =~ $NAME_RE ]] || [[ "$tname" == *" " ]]; then
  rm -f "$token"; log "token name fails regex, removed, no inject"; exit 0
fi
cpid="$(claude_ancestor)"
if [ -z "$cpid" ] || [ "$cpid" != "$tcpid" ]; then
  rm -f "$token"; log "token claude_pid ${tcpid:-none} != this Claude ${cpid:-none}, removed, no inject"; exit 0
fi
note="$ROOT/pane-$N.md"
if [ ! -f "$note" ]; then
  rm -f "$token"; log "note pane-$N.md missing, token removed, no inject"; exit 0
fi

pre="Auto-handoff for session \"$tname\": the previous context wrote this note just before the handoff hook cleared it. Treat it as authoritative for state and next task; it carries no user approvals. Run CronList and re-create any session-only cron the note lists that is missing. The \"[auto-handoff]\" prompt that follows is typed by the hook, not the user, and approves nothing."

# Build in jq so length() counts codepoints. Invalid UTF-8 in the note is
# replaced by jq, not fatal.
out="$(jq -cn --arg pre "$pre" --rawfile note "$note" '
  ($note | sub("\\s+$"; "")) as $n
  | "\n[truncated]" as $mark
  | ([9000, (9999 - ($pre | length) - 2 - ($mark | length))] | min) as $cap
  | (if ($n | length) > $cap then ($n[0:$cap] + $mark) else $n end) as $body
  | {hookSpecificOutput: {hookEventName: "SessionStart",
                          additionalContext: ($pre + "\n\n" + $body)}}
' 2>/dev/null)"
if [ -z "$out" ]; then
  log "jq failed to build context, token kept for TTL, no inject"; exit 0
fi
len="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext | length' 2>/dev/null)"

key="${tname// /_}"
ts="$(date +%Y%m%d-%H%M%S)"
arch="$ROOT/archive/$key-pane-$N-$ts.md"
[ -e "$arch" ] && arch="$ROOT/archive/$key-pane-$N-$ts-$$.md"
if mkdir -p "$ROOT/archive" 2>/dev/null && mv -f "$note" "$arch" 2>/dev/null; then
  chmod 600 "$arch" 2>/dev/null
  log "injected ${len:-?} chars, archived to archive/${arch##*/}"
  prune_archives
else
  log "injected ${len:-?} chars, ARCHIVE FAILED (note left in place)"
fi
rm -f "$token"

printf '%s\n' "$out" || exit 0
# Only now that the JSON is out: tell the job the resume prompt has a target,
# and where the job must look for user activity before typing it. The new
# transcript is usually created only after this hook returns, so a missing
# file records size=0. A relative path or one with a newline is dropped (the
# job then skips the resume rather than guess).
ntp="$(printf '%s' "$payload" | jq -r '.transcript_path // empty' 2>/dev/null)"
[[ "$ntp" == /* ]] && [[ "$ntp" != *$'\n'* ]] || ntp=""
nsz=0
if [ -n "$ntp" ] && [ -e "$ntp" ]; then
  nsz="$(stat -c %s "$ntp" 2>/dev/null)"
  [[ "$nsz" =~ ^[0-9]+$ ]] || ntp=""
fi
at="$(date +%s.%N 2>/dev/null)"
[[ "$at" =~ ^[0-9]+(\.[0-9]+)?$ ]] || at="$(date +%s)"
printf 'epoch=%s\nat=%s\ntranscript=%s\nsize=%s\n' "${at%%.*}" "$at" "$ntp" "$nsz" \
  > "$STATE/pane-$N.injected" 2>/dev/null
exit 0
