#!/usr/bin/env bash
#
# Test for cycle.sh name derivation: session title (customTitle in the
# transcript) -> tmux window name (program names skipped) -> tmux session name
# -> "cycle"; an explicit name wins; a no-arg write renames the opt-in after a
# title change made after opting in (title_at_optin), never to a title that
# predates it; legacy opt-ins without that key still rename. Fake HOME, temp CYCLE_DIR, stub tmux, fake `claude` (copy of
# bash). No real pane, session or ~/.claude is touched.
# Run:  bash core/hooks/tests/test-cycle-name.sh
HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../skills/cycle"
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
mkdir -p "$TMPD/home"
export HOME="$TMPD/home"
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
SID="0123abcd-4567-89ef-0123-456789abcdef"
export CYCLE_DIR="$TMPD/c" CYCLE_TMUX="$TMPD/tmux" TMUX_PANE="%5" CYCLE_MIN_INTERVAL=600
export CLAUDE_CODE_SESSION_ID="$SID"
TX="$HOME/.claude/projects/-x/$SID.jsonl"
O="$CYCLE_DIR/state/pane-5.optin"; R="$CYCLE_DIR/state/pane-5.ready"
FAILS=0
check() { if [ "$2" = 0 ]; then echo "PASS  $1"; else echo "FAIL  $1  (${3:-})"; FAILS=$((FAILS + 1)); fi; }
# the trailing exit keeps bash from exec-ing the last command (the fake claude must stay the parent)
in_claude() { OUT="$("$TMPD/claude" -c "$1"$'\n''exit $?' 2>&1)"; RC=$?; }
reset() { rm -rf "$CYCLE_DIR" "$HOME/.claude/projects"; export STUB_WINDOW=win STUB_SESSION=sess; }
title() { # title NAME... -> append custom-title records to the transcript
  mkdir -p "${TX%/*}"
  local t
  for t in "$@"; do
    jq -cn --arg t "$t" --arg s "$SID" '{type:"custom-title",customTitle:$t,sessionId:$s}' >> "$TX"
  done
}
auto_name() { # run `auto` with no name; NAME = stored opt-in name
  in_claude 'bash "'"$HERE"'/cycle.sh" auto'
  NAME="$(sed -n 's/^name=//p' "$O" 2>/dev/null)"
}
printf '# Cycle\n## Done last session\n- did x\n' > "$TMPD/good.md"

reset
mkdir -p "${TX%/*}"
printf '{"type":"user","message":"mentions \\"custom-title\\" in text"}\n' > "$TX"
title "first title" "afp work"
printf '{"type":"assistant","text":"says \\"custom-title\\" too"}\n' >> "$TX"
auto_name
[ "$RC" = 0 ] && [ "$NAME" = "afp work" ] && [[ "$OUT" == "cycle: auto — session 'afp work' (pane %5)."* ]] \
  && check "1 last customTitle wins (other lines mentioning it ignored)" 0 || check "1 last customTitle wins (other lines mentioning it ignored)" 1 "rc=$RC name=$NAME out=$OUT"

reset
title "afp — admin/ops"
auto_name
[ "$NAME" = "afp --- admin-ops" ] \
  && check "2 title with disallowed chars is sanitised" 0 || check "2 title with disallowed chars is sanitised" 1 "name=$NAME"

reset
title "—/!!"
export STUB_WINDOW="build win"
auto_name
[ "$NAME" = "build win" ] && check "3 title sanitising to nothing falls to the window name" 0 || check "3 title sanitising to nothing falls to the window name" 1 "name=$NAME"

reset
export STUB_WINDOW="build win"
auto_name
[ "$NAME" = "build win" ] && check "4 no transcript: tmux window name" 0 || check "4 no transcript: tmux window name" 1 "name=$NAME"

for w in claude bash node; do
  reset
  export STUB_WINDOW="$w" STUB_SESSION="my sess:1"
  auto_name
  [ "$NAME" = "my sess-1" ] && check "5 window '$w' skipped: session name" 0 || check "5 window '$w' skipped: session name" 1 "name=$NAME"
done

reset
export STUB_WINDOW="zsh" STUB_SESSION="!!!"
auto_name
[ "$NAME" = "cycle" ] && check "6 nothing usable: 'cycle'" 0 || check "6 nothing usable: 'cycle'" 1 "name=$NAME"

reset
mkdir -p "$HOME/.claude/projects/-x"
echo '{"type":"custom-title","customTitle":"evil"}' > "$HOME/.claude/etc.jsonl"
CLAUDE_CODE_SESSION_ID="../../etc" STUB_WINDOW=zsh STUB_SESSION="s1" auto_name
[ "$NAME" = "s1" ] && check "7 malformed session id: transcript not read" 0 || check "7 malformed session id: transcript not read" 1 "name=$NAME"

reset
title "titled"
in_claude 'bash "'"$HERE"'/cycle.sh" auto given'
grep -qx 'name=given' "$O" && check "8 explicit auto name wins over the title" 0 || check "8 explicit auto name wins over the title" 1 "$(cat "$O" 2>&1)"

reset
title "before"
in_claude 'bash "'"$HERE"'/cycle.sh" auto >/dev/null
  printf "%s\n" "{\"type\":\"custom-title\",\"customTitle\":\"after\",\"sessionId\":\"'"$SID"'\"}" >> "'"$TX"'"
  bash "'"$HERE"'/cycle.sh" write < "'"$TMPD"'/good.md" >/dev/null
  echo "rc=$?"
  bash "'"$HERE"'/cycle.sh" status'
[[ "$OUT" == *"rc=0"* ]] && grep -qx 'name=after' "$O" && grep -qx 'name=after' "$R" && ! grep -q oneshot "$O" \
  && grep -qx 'pane_pid=4242' "$O" && grep -q '^claude_pid=[0-9]' "$O" && [[ "$OUT" == *"auto name=after pane=%5 ready=yes"* ]] \
  && grep -q 'renamed before -> after' "$CYCLE_DIR/state/cycle.log" \
  && check "9 write refresh: opt-in + ready marker carry the new title, logged" 0 || check "9 write refresh: opt-in + ready marker carry the new title, logged" 1 "out=$OUT $(cat "$O" "$R" 2>&1)"

reset
in_claude 'bash "'"$HERE"'/cycle.sh" auto given >/dev/null
  bash "'"$HERE"'/cycle.sh" write < "'"$TMPD"'/good.md" >/dev/null'
grep -qx 'name=given' "$O" && grep -qx 'name=given' "$R" \
  && check "10 no title: refresh keeps the explicit auto name (tmux names never override)" 0 || check "10 no title: refresh keeps the explicit auto name (tmux names never override)" 1 "$(cat "$O" "$R" 2>&1)"

reset
title "one-shot title"
in_claude 'bash "'"$HERE"'/cycle.sh" write < "'"$TMPD"'/good.md" >/dev/null
  printf "%s\n" "{\"type\":\"custom-title\",\"customTitle\":\"renamed\",\"sessionId\":\"'"$SID"'\"}" >> "'"$TX"'"
  rm -f "'"$R"'"
  bash "'"$HERE"'/cycle.sh" write < "'"$TMPD"'/good.md" >/dev/null'
grep -qx 'name=renamed' "$O" && grep -qx 'oneshot=1' "$O" && grep -qx 'name=renamed' "$R" \
  && check "11 not opted in: one-shot uses the derived title; refresh keeps oneshot=1" 0 || check "11 not opted in: one-shot uses the derived title; refresh keeps oneshot=1" 1 "$(cat "$O" "$R" 2>&1)"

addt() { printf '%s\n' "printf \"%s\\n\" \"{\\\"type\\\":\\\"custom-title\\\",\\\"customTitle\\\":\\\"$1\\\",\\\"sessionId\\\":\\\"$SID\\\"}\" >> \"$TX\""; }
W='bash "'"$HERE"'/cycle.sh" write < "'"$TMPD"'/good.md" >/dev/null'

reset
title "bar"
in_claude 'bash "'"$HERE"'/cycle.sh" auto foo >/dev/null
  '"$W"'
  sed -n "s/^name=//p" "'"$O"'" > "'"$TMPD"'/n1"
  '"$(addt baz)"'
  '"$W"''
[ "$(cat "$TMPD/n1")" = foo ] && grep -qx 'title_at_optin=baz' "$O" && grep -qx 'name=baz' "$O" && grep -qx 'name=baz' "$R" \
  && grep -qx 'pane_pid=4242' "$O" && grep -q '^claude_pid=[0-9]' "$O" && ! grep -q oneshot "$O" \
  && [ "$(grep -c '^title_at_optin=' "$O")" = 1 ] && [ "$(grep -c '^name=' "$O")" = 1 ] \
  && check "12 title predating 'auto foo' never overrides foo; a later /rename to baz does" 0 \
  || check "12 title predating 'auto foo' never overrides foo; a later /rename to baz does" 1 "n1=$(cat "$TMPD/n1" 2>&1) $(cat "$O" "$R" 2>&1)"

reset
title "bar"
in_claude 'bash "'"$HERE"'/cycle.sh" auto foo >/dev/null
  sed -i "/^title_at_optin=/d" "'"$O"'"
  '"$W"''
grep -qx 'name=bar' "$O" && grep -qx 'name=bar' "$R" && grep -qx 'pane_pid=4242' "$O" && grep -q '^claude_pid=[0-9]' "$O" \
  && grep -qx 'title_at_optin=bar' "$O" \
  && check "13 legacy opt-in (no title_at_optin): refresh renames to the title as before" 0 \
  || check "13 legacy opt-in (no title_at_optin): refresh renames to the title as before" 1 "$(cat "$O" "$R" 2>&1)"

reset
title "bar"
in_claude 'bash "'"$HERE"'/cycle.sh" write foo < "'"$TMPD"'/good.md" >/dev/null
  rm -f "'"$R"'"
  '"$W"''
grep -qx 'name=foo' "$O" && grep -qx 'oneshot=1' "$O" && grep -qx 'title_at_optin=bar' "$O" && grep -qx 'name=foo' "$R" \
  && check "14 one-shot 'write foo' under title bar: no-arg write keeps foo" 0 \
  || check "14 one-shot 'write foo' under title bar: no-arg write keeps foo" 1 "$(cat "$O" "$R" 2>&1)"

if [ "$FAILS" -ne 0 ]; then echo "$FAILS FAILED"; exit 1; fi
echo "all passed"
