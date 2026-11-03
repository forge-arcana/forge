#!/usr/bin/env bash
#
# Test for the legacy state-dir migration shared by pass.sh, pass-start.sh
# and pass-stop.sh: with PASS_DIR unset, a real ~/.claude/handoffs and no
# ~/.claude/passes, the first run renames it to passes and leaves a relative
# symlink handoffs -> passes. Every case runs under its own fake HOME inside a
# temp dir; the real ~/.claude is never touched.
# Run:  bash core/hooks/tests/test-pass-migrate.sh
TESTS="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
HOOKS="$TESTS/.."
SKILL="$TESTS/../../skills/pass"
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
command -v jq >/dev/null 2>&1 || { echo "jq not found"; exit 1; }
unset PASS_DIR CLAUDE_CODE_SESSION_ID
export HOME="$TMPD/none"   # replaced per case before any script runs
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
export PASS_TMUX="$TMPD/tmux" TMUX_PANE="%5"
MSG='migrated legacy state dir ~/.claude/handoffs -> ~/.claude/passes'
FAILS=0 K=0
check() { if [ "$2" = 0 ]; then echo "PASS  $1"; else echo "FAIL  $1  (${3:-})"; FAILS=$((FAILS + 1)); fi; }

# fresh fake HOME with a populated legacy dir; sets H, OLD, NEW
legacy_home() {
  K=$((K + 1))
  H="$TMPD/home$K"
  export HOME="$H"
  OLD="$H/.claude/handoffs" NEW="$H/.claude/passes"
  mkdir -p "$OLD/state" "$OLD/archive"
  printf 'name=x\npane_pid=1\nclaude_pid=1\n' > "$OLD/state/pane-9.optin"
  printf '# note\n' > "$OLD/pane-5.md"
  printf 'old\n' > "$OLD/archive/x"
}
migrated() { # migrated LABEL -> checks the post-migration layout
  [ -d "$NEW" ] && [ ! -L "$NEW" ] && [ -L "$OLD" ] && [ "$(readlink "$OLD")" = passes ] \
    && [ -f "$NEW/pane-5.md" ] && [ -f "$NEW/archive/x" ] && [ -f "$NEW/state/pane-9.optin" ] \
    && [ -f "$OLD/pane-5.md" ] \
    && [ "$(grep -c -F "$MSG" "$NEW/state/pass.log" 2>/dev/null)" = 1 ] \
    && check "$1" 0 || check "$1" 1 "$(ls -la "$H/.claude" "$NEW" "$NEW/state" 2>&1; cat "$NEW/state/pass.log" 2>&1)"
}

legacy_home
OUT="$(bash "$SKILL/pass.sh" status 2>&1)"
migrated "1 pass.sh status migrates: files moved, handoffs -> passes, one log line"
[ "$OUT" = manual ] && check "1b status output unaffected ('manual')" 0 || check "1b status output unaffected" 1 "out=$OUT"
bash "$SKILL/pass.sh" status >/dev/null 2>&1
migrated "2 second run is a no-op (still one log line, symlink intact)"

legacy_home
OUT="$(bash "$HOOKS/pass-start.sh" < /dev/null 2>&1)"; RC=$?
migrated "3 start hook (empty stdin) migrates"
[ "$RC" = 0 ] && [ -z "$OUT" ] && check "3b start hook silent, exit 0" 0 || check "3b start hook silent, exit 0" 1 "rc=$RC out=$OUT"

legacy_home
OUT="$(printf '{}' | bash "$HOOKS/pass-stop.sh" 2>&1)"; RC=$?
migrated "4 stop hook ({} stdin, no ready marker) migrates"
[ "$RC" = 0 ] && [ -z "$OUT" ] && check "4b stop hook silent, exit 0" 0 || check "4b stop hook silent, exit 0" 1 "rc=$RC out=$OUT"
printf '{}' | bash "$HOOKS/pass-stop.sh" >/dev/null 2>&1
migrated "4c stop hook second run is a no-op"

legacy_home
OUT="$(printf '{}' | env -u TMUX_PANE bash "$HOOKS/pass-stop.sh" 2>&1)"
migrated "5 stop hook outside tmux still migrates"

legacy_home
mkdir -p "$NEW"
bash "$SKILL/pass.sh" status >/dev/null 2>&1
printf '{}' | bash "$HOOKS/pass-stop.sh" >/dev/null 2>&1
bash "$HOOKS/pass-start.sh" < /dev/null >/dev/null 2>&1
[ -d "$OLD" ] && [ ! -L "$OLD" ] && [ -f "$OLD/pane-5.md" ] && [ -f "$OLD/state/pane-9.optin" ] && [ ! -e "$NEW/pane-5.md" ] \
  && ! grep -qF "$MSG" "$NEW/state/pass.log" 2>/dev/null \
  && check "6 passes already exists: real handoffs left untouched" 0 || check "6 passes already exists: real handoffs left untouched" 1 "$(ls -la "$H/.claude" 2>&1)"

legacy_home
export PASS_DIR="$TMPD/explicit$K"
bash "$SKILL/pass.sh" status >/dev/null 2>&1
printf '{}' | bash "$HOOKS/pass-stop.sh" >/dev/null 2>&1
bash "$HOOKS/pass-start.sh" < /dev/null >/dev/null 2>&1
[ -d "$OLD" ] && [ ! -L "$OLD" ] && [ ! -e "$NEW" ] && [ ! -L "$NEW" ] && [ -f "$OLD/pane-5.md" ] \
  && check "7 PASS_DIR set: no migration even with a legacy dir" 0 || check "7 PASS_DIR set: no migration" 1 "$(ls -la "$H/.claude" 2>&1)"
unset PASS_DIR

legacy_home
rm -rf "$OLD"
mkdir -p "$H/.claude"
ln -s elsewhere "$OLD"
bash "$SKILL/pass.sh" status >/dev/null 2>&1
[ -L "$OLD" ] && [ "$(readlink "$OLD")" = elsewhere ] && [ ! -e "$NEW" ] \
  && check "8 legacy path is a symlink: left alone, nothing created" 0 || check "8 legacy symlink left alone" 1 "$(ls -la "$H/.claude" 2>&1)"

# Opted-in session: the opt-in is written under the legacy dir by the same fake
# claude that then runs status (claude_pid = that process, pane_pid = stub's).
legacy_home
OUT="$("$TMPD/claude" -c '
  printf "name=keeper\npane_pid=4242\nclaude_pid=%s\n" "$$" > "'"$OLD"'/state/pane-5.optin"
  bash "'"$SKILL"'/pass.sh" status
  exit $?' 2>&1)"; RC=$?
[ "$RC" = 0 ] && [ "$OUT" = "auto name=keeper pane=%5 ready=no" ] && [ -f "$NEW/state/pane-5.optin" ] && [ -L "$OLD" ] \
  && check "9 opted-in session still reports auto after migration" 0 || check "9 opted-in session still reports auto after migration" 1 "rc=$RC out=$OUT"

# Race: several processes start at once; exactly one moves the dir.
legacy_home
for i in 1 2 3 4 5 6; do bash "$SKILL/pass.sh" status >/dev/null 2>&1 & done
for i in 1 2 3 4 5 6; do printf '{}' | bash "$HOOKS/pass-stop.sh" >/dev/null 2>&1 & done
wait
migrated "10 concurrent first runs: one migration, consistent layout"
[ ! -e "$NEW/passes" ] && [ ! -e "$NEW/handoffs" ] && check "10b no nested dir or stray link inside passes" 0 || check "10b no nested dir or stray link" 1 "$(ls -la "$NEW")"

if [ "$FAILS" -ne 0 ]; then echo "$FAILS FAILED"; exit 1; fi
echo "all passed"
