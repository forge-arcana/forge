#!/usr/bin/env bash
#
# Test for `cycle.sh write`: a note without a "## Done last session" line is
# rejected with exit 4 (no note, no ready marker); one with it is accepted.
# Temp CYCLE_DIR, a stub tmux, and a fake `claude` process (copy of bash) so
# the helper finds a Claude ancestor. No real pane or session is touched.
# Run:  bash core/hooks/tests/test-cycle-write.sh
HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../skills/cycle"
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
mkdir -p "$TMPD/home"; export HOME="$TMPD/home"; unset CLAUDE_CODE_SESSION_ID   # never the real ~/.claude
cp "$(command -v bash)" "$TMPD/claude"
cat > "$TMPD/tmux" <<'STUB'
#!/bin/sh
case "$*" in
  *session_name*) echo 'my sess:1/x' ;;
  *window_name*) echo bash ;;
  *) echo 4242 ;;
esac
STUB
chmod +x "$TMPD/tmux"
export CYCLE_DIR="$TMPD/h" CYCLE_TMUX="$TMPD/tmux" TMUX_PANE="%5" CYCLE_MIN_INTERVAL=600
FAILS=0
check() { if [ "$2" = 0 ]; then echo "PASS  $1"; else echo "FAIL  $1  (${3:-})"; FAILS=$((FAILS + 1)); fi; }

# helper SUBCMD NOTEFILE  -> runs `on` then `write` inside one fake claude; sets RC, ERR
write_note() {
  local note="$1"
  ERR="$("$TMPD/claude" -c '
    bash "'"$HERE"'/cycle.sh" on tester >/dev/null
    bash "'"$HERE"'/cycle.sh" write < "'"$note"'" 2>&1 >/dev/null
    exit $?' 2>&1)"
  RC=$?
}

printf '# Cycle\n## Next task\nx\n' > "$TMPD/bad.md"
printf '# Cycle\n## Done last session\n- did x\n## Next task\nx\n' > "$TMPD/good.md"
printf '# Cycle\n## Done last session (draft)\n- did x\n' > "$TMPD/near.md"

write_note "$TMPD/bad.md"
[ "$RC" = 4 ] && [[ "$ERR" == *"cycle: nothing saved — add a line that is exactly '## Done last session' (right after the title is conventional) listing what was done/shipped + key decisions, then re-run write."* ]] \
  && check "1 missing section: exit 4 with the message" 0 || check "1 missing section: exit 4 with the message" 1 "rc=$RC err=$ERR"
[ ! -e "$CYCLE_DIR/pane-5.md" ] && [ ! -e "$CYCLE_DIR/state/pane-5.ready" ] \
  && check "2 rejected: no note, no ready marker" 0 || check "2 rejected: no note, no ready marker" 1 "$(ls "$CYCLE_DIR" "$CYCLE_DIR/state")"

write_note "$TMPD/near.md"
[ "$RC" = 4 ] && check "3 near-miss heading (not exact line) is rejected" 0 || check "3 near-miss heading (not exact line) is rejected" 1 "rc=$RC"

printf '# Cycle\r\n## Done last session\r\n- did x\r\n## Next task\r\nx\r\n' > "$TMPD/crlf.md"
write_note "$TMPD/crlf.md"
[ "$RC" = 0 ] && check "3b CRLF note with the section is accepted" 0 || check "3b CRLF note with the section is accepted" 1 "rc=$RC err=$ERR"
rm -f "$CYCLE_DIR/state/pane-5.ready" "$CYCLE_DIR/state/pane-5.lastclear" "$CYCLE_DIR/pane-5.md"

# not opted in AND missing section: exit 4, and no opt-in left behind
ERR="$("$TMPD/claude" -c '
  bash "'"$HERE"'/cycle.sh" write < "'"$TMPD"'/bad.md" 2>&1
  exit $?' 2>&1)"; RC=$?
[ "$RC" = 4 ] && [ ! -e "$CYCLE_DIR/state/pane-5.optin" ] \
  && check "3c not opted in + missing section: exit 4, no optin" 0 || check "3c not opted in + missing section: exit 4, no optin" 1 "rc=$RC err=$ERR"

printf '# Cycle\n## Done last session   \n- did x\n' > "$TMPD/trail.md"
write_note "$TMPD/trail.md"
[ "$RC" = 0 ] && check "3d heading with trailing spaces is accepted" 0 || check "3d heading with trailing spaces is accepted" 1 "rc=$RC err=$ERR"
printf '# Cycle\n- did x\n## Done last session\n- done at the end of the note\n' > "$TMPD/late.md"
write_note "$TMPD/late.md"
[ "$RC" = 0 ] && check "3e section anywhere in the note is accepted" 0 || check "3e section anywhere in the note is accepted" 1 "rc=$RC err=$ERR"

write_note "$TMPD/good.md"
[ "$RC" = 0 ] && [ -s "$CYCLE_DIR/pane-5.md" ] && [ -f "$CYCLE_DIR/state/pane-5.ready" ] \
  && check "4 note with the section: saved, ready marker set" 0 || check "4 note with the section: saved, ready marker set" 1 "rc=$RC err=$ERR"

# --- one-shot cycle (not opted in) ---
clean() { rm -rf "$CYCLE_DIR"; }
O="$CYCLE_DIR/state/pane-5.optin"; R="$CYCLE_DIR/state/pane-5.ready"

# run BODY inside one fake claude; sets RC and OUT
# the trailing exit keeps bash from exec-ing the last command (the fake claude must stay the parent)
in_claude() { OUT="$("$TMPD/claude" -c "$1"$'\n''exit $?' 2>&1)"; RC=$?; }

clean
in_claude 'bash "'"$HERE"'/cycle.sh" write afp < "'"$TMPD"'/good.md" >/dev/null 2>&1
  rc=$?
  bash "'"$HERE"'/cycle.sh" status
  echo "status_rc=$?"
  exit $rc'
[ "$RC" = 0 ] && [ -s "$CYCLE_DIR/pane-5.md" ] && grep -qx 'name=afp' "$R" && grep -qx 'oneshot=1' "$O" && grep -qx 'name=afp' "$O" \
  && check "A one-shot write with name arg: saved, ready+optin name=afp, oneshot=1" 0 || check "A one-shot write with name arg: saved, ready+optin name=afp, oneshot=1" 1 "rc=$RC out=$OUT"
[[ "$OUT" == "manual (one-shot cycle pending name=afp"* ]] && [[ "$OUT" == *"status_rc=1"* ]] \
  && check "B status after one-shot: exit 1, 'manual (one-shot cycle pending name=afp'" 0 || check "B status after one-shot: exit 1, 'manual (one-shot cycle pending name=afp'" 1 "out=$OUT"

clean
in_claude 'bash "'"$HERE"'/cycle.sh" write < "'"$TMPD"'/good.md" 2>&1'
[ "$RC" = 0 ] && grep -qx 'name=my sess-1-x' "$O" && grep -qx 'name=my sess-1-x' "$R" \
  && check "C no name arg: falls back to sanitised tmux session name" 0 || check "C no name arg: falls back to sanitised tmux session name" 1 "rc=$RC out=$OUT $(cat "$O" 2>&1)"

clean
in_claude 'bash "'"$HERE"'/cycle.sh" on tester >/dev/null
  bash "'"$HERE"'/cycle.sh" write other < "'"$TMPD"'/good.md" >/dev/null 2>&1'
[ "$RC" = 0 ] && grep -qx 'name=tester' "$O" && ! grep -q oneshot "$O" && grep -qx 'name=tester' "$R" \
  && check "D real opt-in keeps its name; name arg ignored, no oneshot" 0 || check "D real opt-in keeps its name; name arg ignored, no oneshot" 1 "rc=$RC out=$OUT $(cat "$O" 2>&1)"

clean
in_claude 'bash "'"$HERE"'/cycle.sh" write -bad < "'"$TMPD"'/good.md" 2>&1'
[ "$RC" = 64 ] && [ ! -e "$O" ] \
  && check "E invalid name arg: exit 64, no optin" 0 || check "E invalid name arg: exit 64, no optin" 1 "rc=$RC out=$OUT"

clean
in_claude 'bash "'"$HERE"'/cycle.sh" write one < "'"$TMPD"'/good.md" >/dev/null 2>&1
  rm -f "'"$CYCLE_DIR"'/state/pane-5.lastclear" "'"$R"'"
  bash "'"$HERE"'/cycle.sh" write two < "'"$TMPD"'/good.md" >/dev/null 2>&1
  bash "'"$HERE"'/cycle.sh" on real >/dev/null
  bash "'"$HERE"'/cycle.sh" status; true'
[[ "$OUT" == "auto name=real"* ]] && ! grep -q oneshot "$O" \
  && check "F one-shot renamed by a differing arg; 'on' overwrites it" 0 || check "F one-shot renamed by a differing arg; 'on' overwrites it" 1 "out=$OUT"

if [ "$FAILS" -ne 0 ]; then echo "$FAILS FAILED"; exit 1; fi
echo "all passed"
