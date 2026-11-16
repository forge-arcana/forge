#!/usr/bin/env bash
#
# Test for default-on auto-pass: status default, persistent opt-out by session
# name (survives pid changes), `auto` removing it, write (non-one-shot by
# default, one-shot when opted out, --explicit), and the Stop hook's
# min-context gate, opt-out check and default cancel window. Temp HOME/PASS_DIR,
# stub tmux, fake `claude` (copy of bash); nothing real is touched.
# Run:  bash core/hooks/tests/test-pass-default.sh
SKILL="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../skills/pass"
HOOK="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../pass-stop.sh"
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
mkdir -p "$TMPD/home"; export HOME="$TMPD/home"; unset CLAUDE_CODE_SESSION_ID
cp "$(command -v bash)" "$TMPD/claude"
cat > "$TMPD/tmux" <<'STUB'
#!/bin/sh
case "$*" in
  *window_name*) printf '%s\n' "${STUB_WINDOW-win}" ;;
  *session_name*) printf '%s\n' "${STUB_SESSION-sess}" ;;
  *) echo "${STUB_PANE_PID:-4242}" ;;
esac
STUB
chmod +x "$TMPD/tmux"
export PASS_DIR="$TMPD/c" PASS_TMUX="$TMPD/tmux" TMUX_PANE="%5" PASS_MIN_INTERVAL=600
export PASS_DELAY=0 PASS_POLL_TRIES=1
S="$PASS_DIR/state"; O="$S/pane-5.optin"; R="$S/pane-5.ready"; LOG="$S/pass.log"
FAILS=0
check() { if [ "$2" = 0 ]; then echo "PASS  $1"; else echo "FAIL  $1  (${3:-})"; FAILS=$((FAILS + 1)); fi; }
in_claude() { OUT="$("$TMPD/claude" -c "$1"$'\n''exit $?' 2>&1)"; RC=$?; }
reset() { rm -rf "$PASS_DIR"; export STUB_WINDOW=win STUB_SESSION=sess STUB_PANE_PID=4242; }
P="bash \"$SKILL/pass.sh\""
printf '# Pass\n## Done last session\n- did x\n' > "$TMPD/good.md"

# --- status / opt-out -------------------------------------------------------
reset
in_claude "$P status; echo rc=\$?"
[ "$OUT" = $'auto name=win pane=%5 ready=no\nrc=0' ] && check "1 default status is auto (window name)" 0 || check "1 default status is auto" 1 "$OUT"

reset
in_claude "$P manual; $P status; echo rc=\$?"
[ "$OUT" = $'pass: manual — pane %5 no longer auto-clears; opted out \'win\'.\nmanual\nrc=1' ] && [ -f "$S/optout/win" ] \
  && [ "$(stat -c %a "$S/optout")" = 700 ] && check "2 manual creates optout/<name> (dir 700), status manual" 0 || check "2 manual optout" 1 "$OUT"

STUB_PANE_PID=9999 in_claude "$P status; echo rc=\$?"
[ "$OUT" = $'manual\nrc=1' ] && check "3 opt-out survives a new pane pid and a new claude pid" 0 || check "3 opt-out persistence" 1 "$OUT"

in_claude "$P auto; $P status; echo rc=\$?"
[ ! -e "$S/optout/win" ] && [[ "$OUT" == *"auto name=win pane=%5 ready=no"*"rc=0" ]] && check "4 auto removes the opt-out and opts in" 0 || check "4 auto removes opt-out" 1 "$OUT"

reset
STUB_WINDOW="../evil" STUB_SESSION="" in_claude "$P manual; $P status; echo rc=\$?"
[ -f "$S/optout/evil" ] && [ ! -e "$S/evil" ] && [ ! -e "$PASS_DIR/evil" ] && [ ! -e "$S/../evil" ] && check "5 hostile name never escapes optout dir" 0 || check "5 hostile name" 1 "$(find "$PASS_DIR")"

# --- write ------------------------------------------------------------------
reset
in_claude "$P write < \"$TMPD/good.md\" >/dev/null; $P status"
[ -f "$O" ] && ! grep -q oneshot "$O" && grep -qx 'name=win' "$O" && [[ "$OUT" == "auto name=win"* ]] && ! grep -q explicit "$R" \
  && check "6 default write: normal (non-one-shot) opt-in, status auto" 0 || check "6 default write" 1 "$OUT $(cat "$O" 2>&1)"

reset
in_claude "$P manual >/dev/null; $P write --explicit < \"$TMPD/good.md\" >/dev/null; $P status; echo rc=\$?"
grep -qx 'oneshot=1' "$O" && [[ "$OUT" == "manual (one-shot pass pending name=win"*"rc=1" ]] \
  && check "7 opted out: write makes a one-shot, status still manual" 0 || check "7 opted out write" 1 "$OUT"

reset
in_claude "$P write --explicit < \"$TMPD/good.md\" >/dev/null"
grep -qx 'explicit=1' "$R" && grep -qx 'name=win' "$R" && check "8 write --explicit marks the ready marker" 0 || check "8 explicit marker" 1 "$(cat "$R" 2>&1)"
reset
in_claude "$P write --explicit named < \"$TMPD/good.md\" >/dev/null"
grep -qx 'name=named' "$O" && check "8b --explicit accepts a name" 0 || check "8b --explicit name" 1 "$(cat "$O" 2>&1)"

# --- Stop hook --------------------------------------------------------------
TX="$TMPD/tx.jsonl"
tx() { # tx INPUT CACHE_READ CACHE_CREATE  (writes a transcript with one assistant line)
  printf '{"type":"user","timestamp":"2026-01-01T00:00:00.000Z"}\n{"type":"assistant","timestamp":"2026-01-01T00:00:01.000Z","message":{"usage":{"input_tokens":%s,"cache_read_input_tokens":%s,"cache_creation_input_tokens":%s,"output_tokens":5}}}\n' "$1" "$2" "$3" > "$TX"
}
hook() { # hook [write args...]: write a note then run the Stop hook, in one fake claude
  in_claude "$P write $* < \"$TMPD/good.md\" >/dev/null; printf '{\"transcript_path\":\"$TX\"}' | bash \"$HOOK\"; echo rc=\$?"
  sleep 0.5
}

reset; tx 10 20000 30000
hook
grep -q 'skip(min-context 50010 < 90000)' "$LOG" && [ ! -e "$R" ] && [ -s "$PASS_DIR/pane-5.md" ] && ! grep -q 'scheduled clear job' "$LOG" && [ "$OUT" = rc=0 ] \
  && check "9 low context: skipped, logged, note kept, ready marker gone, exit 0 silent" 0 || check "9 min-context skip" 1 "$(cat "$LOG")"

reset; tx 10 20000 30000
hook --explicit
grep -q 'scheduled clear job' "$LOG" && ! grep -q 'min-context' "$LOG" && check "10 --explicit bypasses the gate" 0 || check "10 explicit bypass" 1 "$(cat "$LOG")"

reset; tx 10 80000 30000
hook
grep -q 'scheduled clear job' "$LOG" && check "11 context above the minimum schedules" 0 || check "11 above min" 1 "$(cat "$LOG")"

reset; tx 10 20000 30000
PASS_MIN_CONTEXT=40000 hook
grep -q 'scheduled clear job' "$LOG" && check "11b PASS_MIN_CONTEXT is honoured" 0 || check "11b env min" 1 "$(cat "$LOG")"

reset; printf '{"type":"user","timestamp":"2026-01-01T00:00:00.000Z"}\n' > "$TX"
hook
grep -q 'usage unreadable' "$LOG" && grep -q 'scheduled clear job' "$LOG" && check "12 unreadable usage fails open and is logged" 0 || check "12 fail open" 1 "$(cat "$LOG")"

reset; tx 10 80000 30000
in_claude "$P write < \"$TMPD/good.md\" >/dev/null; mkdir -p \"$S/optout\"; printf 'name=win\n' > \"$S/optout/win\"; printf '{\"transcript_path\":\"$TX\"}' | bash \"$HOOK\"; echo rc=\$?"
sleep 0.3
grep -q 'opted out (optout/win)' "$LOG" && ! grep -q 'scheduled clear job' "$LOG" && check "13 hook honours an opt-out on a non-one-shot opt-in" 0 || check "13 hook opt-out" 1 "$(cat "$LOG")"

reset; tx 10 80000 30000
unset PASS_DELAY
in_claude "printf '{\"transcript_path\":\"$TX\"}' > \"$TMPD/pl\"; $P write < \"$TMPD/good.md\" >/dev/null; bash \"$HOOK\" < \"$TMPD/pl\""
sleep 1
grep -q 'cancel window 25s' "$LOG" && check "14 default cancel window is 25 s" 0 || check "14 default delay" 1 "$(cat "$LOG")"
rm -f "$S/pane-5.clearing"   # cancels the job, which aborts at its next 1 s check
sleep 2.5


export PASS_DELAY=0
# --- review fixes -----------------------------------------------------------
# F1: opted-out plain write saves the note but sets no marker and no opt-in
reset
in_claude "$P manual >/dev/null; $P write < \"$TMPD/good.md\"; echo rc=\$?"
[ "$OUT" = $'pass: \'win\' is opted out (/pass manual); note saved, not clearing\nrc=0' ] && [ ! -e "$R" ] && [ ! -e "$O" ] && [ -s "$PASS_DIR/pane-5.md" ] \
  && check "15 opted-out plain write: note saved, no marker, no opt-in, one-line message" 0 || check "15 opted-out plain write" 1 "$OUT"

# F1: opted-out explicit write clears once; the following plain write does not
reset; tx 10 80000 30000
in_claude "$P manual >/dev/null; $P write --explicit < \"$TMPD/good.md\" >/dev/null; printf '{\"transcript_path\":\"$TX\"}' | bash \"$HOOK\"; echo rc=\$?; $P write < \"$TMPD/good.md\" >/dev/null; [ -e \"$R\" ] && echo READY || echo NOREADY"
sleep 0.5
[ "$(grep -c 'scheduled clear job' "$LOG")" = 1 ] && [[ "$OUT" == *NOREADY ]] \
  && check "16 opted-out: explicit write clears once, a following plain write does not" 0 || check "16 explicit once" 1 "$OUT $(cat "$LOG")"

# F1: hook skips an opt-out on a one-shot without explicit
reset; tx 10 80000 30000
in_claude "$P manual >/dev/null; $P write --explicit < \"$TMPD/good.md\" >/dev/null; printf 'name=win\nepoch=%s\n' \$(date +%s) > \"$R\"; printf '{\"transcript_path\":\"$TX\"}' | bash \"$HOOK\"; echo rc=\$?"
sleep 0.3
grep -q 'opted out (optout/win)' "$LOG" && ! grep -q 'scheduled clear job' "$LOG" && grep -qx 'oneshot=1' "$O" \
  && check "17 hook skips an opt-out on a one-shot without explicit" 0 || check "17 hook one-shot opt-out" 1 "$(cat "$LOG")"

# F3: --explicit anywhere; names starting with '-' rejected
reset
in_claude "$P write afp --explicit < \"$TMPD/good.md\" >/dev/null; echo rc=\$?"
[ "$OUT" = rc=0 ] && grep -qx 'name=afp' "$O" && grep -qx 'explicit=1' "$R" && check "18 'write afp --explicit' parses" 0 || check "18 write afp --explicit" 1 "$OUT $(cat "$R" 2>&1)"
reset
in_claude "$P write --explicit afp < \"$TMPD/good.md\" >/dev/null; echo rc=\$?"
[ "$OUT" = rc=0 ] && grep -qx 'name=afp' "$O" && grep -qx 'explicit=1' "$R" && check "18b 'write --explicit afp' parses" 0 || check "18b write --explicit afp" 1 "$OUT"
reset
in_claude "$P write -x < \"$TMPD/good.md\"; echo rc=\$?; $P write afp -y < \"$TMPD/good.md\"; echo rc=\$?"
[[ "$OUT" == *rc=64*rc=64 ]] && [ ! -e "$O" ] && check "18c names starting with '-' rejected (64)" 0 || check "18c dash names" 1 "$OUT"

# F4 / F5: low-context write; sidechain entries ignored
SID=11111111-2222-3333-4444-555555555555
mkdir -p "$HOME/.claude/projects/p"
STX="$HOME/.claude/projects/p/$SID.jsonl"
ast() { printf '{"type":"assistant","isSidechain":%s,"message":{"usage":{"input_tokens":%s,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}\n' "$1" "$2"; }
reset; { ast false 50000; } > "$STX"
CLAUDE_CODE_SESSION_ID=$SID in_claude "$P write < \"$TMPD/good.md\"; echo rc=\$?"
[ "$OUT" = $'pass: context 50000 < 90000; note saved, not clearing\nrc=0' ] && [ ! -e "$R" ] && [ -s "$PASS_DIR/pane-5.md" ] \
  && check "19 low-context write: not-clearing line, note saved, no marker" 0 || check "19 low-context write" 1 "$OUT"
reset; { ast false 50000; ast true 200000; } > "$STX"
CLAUDE_CODE_SESSION_ID=$SID in_claude "$P write < \"$TMPD/good.md\"; echo rc=\$?"
[[ "$OUT" == *"context 50000 < 90000"* ]] && [ ! -e "$R" ] && check "20 sidechain entry ignored by write" 0 || check "20 sidechain write" 1 "$OUT"
reset; { ast false 200000; } > "$STX"
CLAUDE_CODE_SESSION_ID=$SID in_claude "$P write < \"$TMPD/good.md\"; echo rc=\$?"
[[ "$OUT" == *"Auto-clear is queued"* ]] && [ -e "$R" ] && check "21 high-context write queues" 0 || check "21 high-context write" 1 "$OUT"
reset; { ast false 200000; } > "$STX"
CLAUDE_CODE_SESSION_ID=$SID in_claude "$P write --explicit < \"$TMPD/good.md\" >/dev/null"
{ ast false 50000; } > "$STX"
CLAUDE_CODE_SESSION_ID=$SID in_claude "$P write --explicit < \"$TMPD/good.md\"; echo rc=\$?"
[[ "$OUT" == *"Auto-clear is queued"* ]] && check "21b explicit write skips the gate" 0 || check "21b explicit gate" 1 "$OUT"
reset; { ast false 50000; ast true 200000; } > "$TX"
hook
grep -q 'skip(min-context 50000 < 90000)' "$LOG" && check "22 sidechain entry ignored by the hook" 0 || check "22 sidechain hook" 1 "$(cat "$LOG")"

# twin functions agree
a="$(sed -n '/^last_context() {/,/^}/p' "$SKILL/pass.sh")"; b="$(sed -n '/^last_context() {/,/^}/p' "$HOOK")"
[ -n "$a" ] && [ "$a" = "$b" ] && check "23 last_context identical in pass.sh and pass-stop.sh" 0 || check "23 twin last_context" 1

if [ "$FAILS" -ne 0 ]; then echo "$FAILS FAILED"; exit 1; fi
echo "all passed"
