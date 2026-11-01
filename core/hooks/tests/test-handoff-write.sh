#!/usr/bin/env bash
#
# Test for `handoff.sh write`: a note without a "## Done last session" line is
# rejected with exit 4 (no note, no ready marker); one with it is accepted.
# Temp HANDOFF_DIR, a stub tmux, and a fake `claude` process (copy of bash) so
# the helper finds a Claude ancestor. No real pane or session is touched.
# Run:  bash core/hooks/tests/test-handoff-write.sh
HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../skills/handoff"
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
cp "$(command -v bash)" "$TMPD/claude"
cat > "$TMPD/tmux" <<'STUB'
#!/bin/sh
case "$*" in
  *session_name*) echo 'my sess:1/x' ;;
  *) echo 4242 ;;
esac
STUB
chmod +x "$TMPD/tmux"
export HANDOFF_DIR="$TMPD/h" HANDOFF_TMUX="$TMPD/tmux" TMUX_PANE="%5" HANDOFF_MIN_INTERVAL=600
FAILS=0
check() { if [ "$2" = 0 ]; then echo "PASS  $1"; else echo "FAIL  $1  (${3:-})"; FAILS=$((FAILS + 1)); fi; }

# helper SUBCMD NOTEFILE  -> runs `on` then `write` inside one fake claude; sets RC, ERR
write_note() {
  local note="$1"
  ERR="$("$TMPD/claude" -c '
    bash "'"$HERE"'/handoff.sh" on tester >/dev/null
    bash "'"$HERE"'/handoff.sh" write < "'"$note"'" 2>&1 >/dev/null
    exit $?' 2>&1)"
  RC=$?
}

printf '# Handoff\n## Next task\nx\n' > "$TMPD/bad.md"
printf '# Handoff\n## Done last session\n- did x\n## Next task\nx\n' > "$TMPD/good.md"
printf '# Handoff\n## Done last session (draft)\n- did x\n' > "$TMPD/near.md"

write_note "$TMPD/bad.md"
[ "$RC" = 4 ] && [[ "$ERR" == *"handoff: nothing saved — add a line that is exactly '## Done last session' (right after the title is conventional) listing what was done/shipped + key decisions, then re-run write."* ]] \
  && check "1 missing section: exit 4 with the message" 0 || check "1 missing section: exit 4 with the message" 1 "rc=$RC err=$ERR"
[ ! -e "$HANDOFF_DIR/pane-5.md" ] && [ ! -e "$HANDOFF_DIR/state/pane-5.ready" ] \
  && check "2 rejected: no note, no ready marker" 0 || check "2 rejected: no note, no ready marker" 1 "$(ls "$HANDOFF_DIR" "$HANDOFF_DIR/state")"

write_note "$TMPD/near.md"
[ "$RC" = 4 ] && check "3 near-miss heading (not exact line) is rejected" 0 || check "3 near-miss heading (not exact line) is rejected" 1 "rc=$RC"

printf '# Handoff\r\n## Done last session\r\n- did x\r\n## Next task\r\nx\r\n' > "$TMPD/crlf.md"
write_note "$TMPD/crlf.md"
[ "$RC" = 0 ] && check "3b CRLF note with the section is accepted" 0 || check "3b CRLF note with the section is accepted" 1 "rc=$RC err=$ERR"
rm -f "$HANDOFF_DIR/state/pane-5.ready" "$HANDOFF_DIR/state/pane-5.lastclear" "$HANDOFF_DIR/pane-5.md"

# not opted in AND missing section: exit 4, and no opt-in left behind
ERR="$("$TMPD/claude" -c '
  bash "'"$HERE"'/handoff.sh" write < "'"$TMPD"'/bad.md" 2>&1
  exit $?' 2>&1)"; RC=$?
[ "$RC" = 4 ] && [ ! -e "$HANDOFF_DIR/state/pane-5.optin" ] \
  && check "3c not opted in + missing section: exit 4, no optin" 0 || check "3c not opted in + missing section: exit 4, no optin" 1 "rc=$RC err=$ERR"

printf '# Handoff\n## Done last session   \n- did x\n' > "$TMPD/trail.md"
write_note "$TMPD/trail.md"
[ "$RC" = 0 ] && check "3d heading with trailing spaces is accepted" 0 || check "3d heading with trailing spaces is accepted" 1 "rc=$RC err=$ERR"
printf '# Handoff\n- did x\n## Done last session\n- done at the end of the note\n' > "$TMPD/late.md"
write_note "$TMPD/late.md"
[ "$RC" = 0 ] && check "3e section anywhere in the note is accepted" 0 || check "3e section anywhere in the note is accepted" 1 "rc=$RC err=$ERR"

write_note "$TMPD/good.md"
[ "$RC" = 0 ] && [ -s "$HANDOFF_DIR/pane-5.md" ] && [ -f "$HANDOFF_DIR/state/pane-5.ready" ] \
  && check "4 note with the section: saved, ready marker set" 0 || check "4 note with the section: saved, ready marker set" 1 "rc=$RC err=$ERR"

# --- one-shot handoff (not opted in) ---
clean() { rm -rf "$HANDOFF_DIR"; }
O="$HANDOFF_DIR/state/pane-5.optin"; R="$HANDOFF_DIR/state/pane-5.ready"

# run BODY inside one fake claude; sets RC and OUT
in_claude() { OUT="$("$TMPD/claude" -c "$1" 2>&1)"; RC=$?; }

clean
in_claude 'bash "'"$HERE"'/handoff.sh" write afp < "'"$TMPD"'/good.md" >/dev/null 2>&1
  rc=$?
  bash "'"$HERE"'/handoff.sh" status
  echo "status_rc=$?"
  exit $rc'
[ "$RC" = 0 ] && [ -s "$HANDOFF_DIR/pane-5.md" ] && grep -qx 'name=afp' "$R" && grep -qx 'oneshot=1' "$O" && grep -qx 'name=afp' "$O" \
  && check "A one-shot write with name arg: saved, ready+optin name=afp, oneshot=1" 0 || check "A one-shot write with name arg: saved, ready+optin name=afp, oneshot=1" 1 "rc=$RC out=$OUT"
[[ "$OUT" == "off (one-shot handoff pending name=afp"* ]] && [[ "$OUT" == *"status_rc=1"* ]] \
  && check "B status after one-shot: exit 1, 'off (one-shot handoff pending name=afp'" 0 || check "B status after one-shot: exit 1, 'off (one-shot handoff pending name=afp'" 1 "out=$OUT"

clean
in_claude 'bash "'"$HERE"'/handoff.sh" write < "'"$TMPD"'/good.md" 2>&1'
[ "$RC" = 0 ] && grep -qx 'name=my sess-1-x' "$O" && grep -qx 'name=my sess-1-x' "$R" \
  && check "C no name arg: falls back to sanitised tmux session name" 0 || check "C no name arg: falls back to sanitised tmux session name" 1 "rc=$RC out=$OUT $(cat "$O" 2>&1)"

clean
in_claude 'bash "'"$HERE"'/handoff.sh" on tester >/dev/null
  bash "'"$HERE"'/handoff.sh" write other < "'"$TMPD"'/good.md" >/dev/null 2>&1'
[ "$RC" = 0 ] && grep -qx 'name=tester' "$O" && ! grep -q oneshot "$O" && grep -qx 'name=tester' "$R" \
  && check "D real opt-in keeps its name; name arg ignored, no oneshot" 0 || check "D real opt-in keeps its name; name arg ignored, no oneshot" 1 "rc=$RC out=$OUT $(cat "$O" 2>&1)"

clean
in_claude 'bash "'"$HERE"'/handoff.sh" write -bad < "'"$TMPD"'/good.md" 2>&1'
[ "$RC" = 64 ] && [ ! -e "$O" ] \
  && check "E invalid name arg: exit 64, no optin" 0 || check "E invalid name arg: exit 64, no optin" 1 "rc=$RC out=$OUT"

clean
in_claude 'bash "'"$HERE"'/handoff.sh" write one < "'"$TMPD"'/good.md" >/dev/null 2>&1
  rm -f "'"$HANDOFF_DIR"'/state/pane-5.lastclear" "'"$R"'"
  bash "'"$HERE"'/handoff.sh" write two < "'"$TMPD"'/good.md" >/dev/null 2>&1
  bash "'"$HERE"'/handoff.sh" on real >/dev/null
  bash "'"$HERE"'/handoff.sh" status; true'
[[ "$OUT" == "on name=real"* ]] && ! grep -q oneshot "$O" \
  && check "F one-shot renamed by a differing arg; 'on' overwrites it" 0 || check "F one-shot renamed by a differing arg; 'on' overwrites it" 1 "out=$OUT"

if [ "$FAILS" -ne 0 ]; then echo "$FAILS FAILED"; exit 1; fi
echo "all passed"
