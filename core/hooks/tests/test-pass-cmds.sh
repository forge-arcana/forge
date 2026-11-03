#!/usr/bin/env bash
#
# Test for pass.sh subcommands: auto / manual (and the on / off aliases),
# status lines and exit codes, the one-shot status line, not-in-tmux, and the
# usage error. Fake HOME, temp PASS_DIR, stub tmux, fake `claude` (copy of
# bash). No real pane, session or ~/.claude is touched.
# Run:  bash core/hooks/tests/test-pass-cmds.sh
HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../skills/pass"
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
mkdir -p "$TMPD/home"
export HOME="$TMPD/home"
unset CLAUDE_CODE_SESSION_ID
cp "$(command -v bash)" "$TMPD/claude"
cat > "$TMPD/tmux" <<'STUB'
#!/bin/sh
case "$*" in
  *window_name*) echo bash ;;
  *session_name*) echo sess ;;
  *) echo 4242 ;;
esac
STUB
chmod +x "$TMPD/tmux"
export PASS_DIR="$TMPD/c" PASS_TMUX="$TMPD/tmux" TMUX_PANE="%5" PASS_MIN_INTERVAL=600
C="bash \"$HERE/pass.sh\""
FAILS=0
check() { if [ "$2" = 0 ]; then echo "PASS  $1"; else echo "FAIL  $1  (${3:-})"; FAILS=$((FAILS + 1)); fi; }
# run BODY inside one fake claude; OUT = stdout+stderr. The trailing exit keeps
# bash from exec-ing the last command (the fake claude must stay the parent).
in_claude() { OUT="$("$TMPD/claude" -c "$1"$'\n''exit $?' 2>&1)"; RC=$?; }
printf '# Pass\n## Done last session\n- did x\n' > "$TMPD/good.md"

for pair in "auto manual" "on off"; do
  set -- $pair
  rm -rf "$PASS_DIR"
  in_claude "$C $1 tester; echo \"rc=\$?\"; $C status; echo \"rc=\$?\""
  exp="pass: auto — session 'tester' (pane %5). /pass writes a note; the session then clears itself and resumes from it.
rc=0
auto name=tester pane=%5 ready=no
rc=0"
  [ "$OUT" = "$exp" ] && check "1 '$1 tester': exact line, exit 0; status 'auto name=tester pane=%5 ready=no' exit 0" 0 \
    || check "1 '$1 tester': exact line, exit 0; status 'auto ...' exit 0" 1 "out=$OUT"
  in_claude "$C $1 tester >/dev/null; $C write < \"$TMPD/good.md\" >/dev/null; $C status; echo \"rc=\$?\""
  [ "$OUT" = $'auto name=tester pane=%5 ready=yes\nrc=0' ] && check "2 '$1' + write: ready=yes" 0 || check "2 '$1' + write: ready=yes" 1 "out=$OUT"
  in_claude "$C $1 tester >/dev/null; $C $2; echo \"rc=\$?\"; $C status; echo \"rc=\$?\""
  exp="pass: manual — pane %5 no longer auto-clears.
rc=0
manual
rc=1"
  [ "$OUT" = "$exp" ] && check "3 '$2': exact line, exit 0; status 'manual' exit 1" 0 || check "3 '$2': exact line, exit 0; status 'manual' exit 1" 1 "out=$OUT"
  [ ! -e "$PASS_DIR/state/pane-5.optin" ] && check "4 '$2' removes the opt-in" 0 || check "4 '$2' removes the opt-in" 1
done

rm -rf "$PASS_DIR"
in_claude "$C auto; echo \"rc=\$?\""
[ "$OUT" = $'pass: auto — session \'sess\' (pane %5). /pass writes a note; the session then clears itself and resumes from it.\nrc=0' ] \
  && check "5 bare 'auto' derives a name (session name here)" 0 || check "5 bare 'auto' derives a name" 1 "out=$OUT"

rm -rf "$PASS_DIR"
in_claude "$C write afp < \"$TMPD/good.md\" >/dev/null; $C status; echo \"rc=\$?\""
[ "$OUT" = $'manual (one-shot pass pending name=afp ready=yes)\nrc=1' ] \
  && check "6 one-shot status line, exit 1" 0 || check "6 one-shot status line, exit 1" 1 "out=$OUT"

rm -rf "$PASS_DIR"
mkdir -p "$PASS_DIR/state"
printf 'name=old\npane_pid=1\nclaude_pid=1\n' > "$PASS_DIR/state/pane-5.optin"
in_claude "$C status; echo \"rc=\$?\""
[ "$OUT" = $'stale opt-in removed\nmanual\nrc=1' ] && check "7 stale opt-in: 'stale opt-in removed' then 'manual', exit 1" 0 \
  || check "7 stale opt-in: 'stale opt-in removed' then 'manual', exit 1" 1 "out=$OUT"

OUT="$(env -u TMUX_PANE bash "$HERE/pass.sh" status 2>&1)"; RC=$?
[ "$RC" = 1 ] && [ "$OUT" = "manual (not in tmux)" ] && check "8 no TMUX_PANE: 'manual (not in tmux)' exit 1" 0 || check "8 no TMUX_PANE" 1 "rc=$RC out=$OUT"
OUT="$(PASS_TMUX="$TMPD/no-such-tmux" bash "$HERE/pass.sh" status 2>&1)"; RC=$?
[ "$RC" = 1 ] && [ "$OUT" = "manual (not in tmux)" ] && check "9 no tmux binary: 'manual (not in tmux)' exit 1" 0 || check "9 no tmux binary" 1 "rc=$RC out=$OUT"

OUT="$(bash "$HERE/pass.sh" bogus 2>&1)"; RC=$?
[ "$RC" = 64 ] && [ "$OUT" = "usage: pass.sh auto [name...] | manual | status | write [name...] | cancel" ] \
  && check "10 unknown subcommand: usage, exit 64" 0 || check "10 unknown subcommand: usage, exit 64" 1 "rc=$RC out=$OUT"
OUT="$(bash "$HERE/pass.sh" 2>&1)"; RC=$?
[ "$RC" = 64 ] && check "11 no subcommand: exit 64" 0 || check "11 no subcommand: exit 64" 1 "rc=$RC"
in_claude "$C auto -bad"
[ "$RC" = 64 ] && check "12 'auto -bad': invalid name, exit 64" 0 || check "12 'auto -bad': exit 64" 1 "rc=$RC out=$OUT"

if [ "$FAILS" -ne 0 ]; then echo "$FAILS FAILED"; exit 1; fi
echo "all passed"
