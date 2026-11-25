#!/usr/bin/env bash
#
# Test for /pass self-relocation of a background-job session (pass.sh bg_handle +
# pass-relocate.sh). Claude is started by argument list (new-window / respawn-pane
# -- bash pass-relocate.sh --run-claude ...); nothing is typed into a shell. The
# only send-keys are the Stop hook's own /clear, /rename and resume prompt into the
# fake Claude TUI. Everything runs on a PRIVATE tmux server (tmux -L), with a
# stub `claude` that serves `agents --json` from a fixture, records `stop` calls
# and flips the fixture, and otherwise runs a fake Claude TUI (a bordered `❯`
# input box that logs the lines it receives and runs pass-start.sh on /clear).
# HOME and PASS_DIR are temp dirs; no real tmux server, session or Claude is
# touched. PASS_TMUX is a wrapper that logs new-window / respawn-pane / send-keys.
# Run:  bash core/hooks/tests/test-pass-relocate.sh      (non-zero on failure)
# Lives in core/hooks/tests/ so cast-deploy's core/hooks/*.sh glob skips it.

HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
SKILLD="$HERE/../../skills/pass"
ABSD="$(readlink -f "$SKILLD")"
HOOK="$HERE/../pass-stop.sh"
command -v tmux >/dev/null 2>&1 || { echo "tmux not found"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq not found"; exit 1; }
command -v flock >/dev/null 2>&1 || { echo "flock not found"; exit 1; }

TMPD="$(mktemp -d)"
SOCK="pass-reloc-$$-$RANDOM"
TM="tmux -u -L $SOCK"
BGPID=""
SID="36494a69-f80b-4c2e-9d1a-0123456789ab"
OTHER="aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee"

kill_jobs() {   # detached jobs of THIS run only (matched by their PASS_DIR)
  local p
  for p in $(pgrep -f -- '--job' 2>/dev/null); do
    if tr '\0' '\n' <"/proc/$p/environ" 2>/dev/null | grep -qx "PASS_DIR=$TMPD/h"; then kill "$p" 2>/dev/null; fi
  done
}
cleanup() {
  kill_jobs
  $TM kill-server >/dev/null 2>&1
  [ -n "$BGPID" ] && kill "$BGPID" 2>/dev/null
  rm -rf "$TMPD"
}
trap cleanup EXIT

mkdir -p "$TMPD/home" "$TMPD/bin" "$TMPD/realbin" "$TMPD/cwd"
export HOME="$TMPD/home"
unset TMUX TMUX_PANE CLAUDE_CODE_SESSION_ID PASS_NOTIFY
export PASS_DIR="$TMPD/h" PASS_TMUX="$TMPD/bin/tmuxw" PASS_CLAUDE="$TMPD/bin/claude" PASS_STOP_HOOK="$HOOK"
export PATH="$TMPD/bin:$PATH"
export PASS_DELAY=1 PASS_RELOCATE_WAIT=15 PASS_RELOCATE_POLL=0.2 PASS_RELOCATE_STOP_WAIT=3 \
       PASS_RELOCATE_START=8 PASS_MIN_INTERVAL=600 PASS_MIN_CONTEXT=0 PASS_RELOCATE_NO_SYSTEMD=1

mkdir -p "$TMPD/shellbin"
cat >"$TMPD/shellbin/bash" <<EOF2
#!/usr/bin/env bash
[ "\${1:-}" = -lic ] && printf '%s\n' "\$*" >> "$TMPD/shell.log"
exec /bin/bash --noprofile --norc "\$@"
EOF2
chmod +x "$TMPD/shellbin/bash"
export SHELL="$TMPD/shellbin/bash"
cp "$(command -v bash)" "$TMPD/realbin/claude"   # a process whose comm is `claude`

cat >"$TMPD/bin/claude" <<EOF
#!/usr/bin/env bash
T="$TMPD"
case "\${1:-}" in
  agents) cat "\$T/fx.json" ;;
  stop)
    echo "\$*" >> "\$T/stop.log"
    [ -e "\$T/stop-noop" ] && exit 0
    [ -e "\$T/stop-slow" ] && sleep 2
    pid="\$(jq -r --arg i "\$2" '.[] | select(.id == \$i) | .pid // empty' "\$T/fx.json")"
    jq --arg i "\$2" 'map(if .id == \$i then del(.pid, .status) | .state = "stopped" else . end)' "\$T/fx.json" >"\$T/fx.tmp" \\
      && mv "\$T/fx.tmp" "\$T/fx.json"
    [ -n "\$pid" ] && kill "\$pid" 2>/dev/null
    if [ -f "\$T/view-on-stop" ]; then
      case "\$(cat "\$T/view-on-stop")" in
        exit) kill "\$(cat "\$T/view.pid")" 2>/dev/null ;;
        list) : >"\$T/view-list" ;;
      esac
    fi
    exit 0 ;;
  *)
    [ -e "\$T/no-box" ] && { printf 'args: %s\n' "\$*" >> "\$T/tui.log"; exec "\$T/realbin/claude" -c 'read -r -t 600 x'; }
    exec "\$T/realbin/claude" "\$T/tui.sh" "\$@" ;;
esac
EOF
cat >"$TMPD/bin/systemctl" <<'EOF2'
#!/usr/bin/env bash
echo running
EOF2
cat >"$TMPD/bin/systemd-run" <<EOF2
#!/usr/bin/env bash
printf '%s\n' "\$@" > "$TMPD/sd.log"
[ -e "$TMPD/sd-fail" ] && exit 1
envs=()
while [ \$# -gt 0 ]; do
  case "\$1" in --setenv=*) envs+=("\${1#--setenv=}"); shift ;; --unit) shift 2 ;; --*) shift ;; *) break ;; esac
done
setsid -f env "\${envs[@]}" "\$@" </dev/null >/dev/null 2>&1
EOF2
# tmux wrapper: logs the subcommands that start Claude or send keys; can be told to fail one.
cat >"$TMPD/bin/tmuxw" <<EOF2
#!/usr/bin/env bash
case "\${1:-}" in new-window|respawn-pane|send-keys) printf '%s\n' "\$*" >> "$TMPD/tmux.log" ;; esac
[ -e "$TMPD/tm-fail-\${1:-}" ] && exit 1
exec tmux -u -L $SOCK "\$@"
EOF2
chmod +x "$TMPD/bin/claude" "$TMPD/bin/systemctl" "$TMPD/bin/systemd-run" "$TMPD/bin/tmuxw"
cat >"$TMPD/notify.sh" <<EOF2
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$TMPD/notify.log"
EOF2
chmod +x "$TMPD/notify.sh"
cat >"$TMPD/fakeshell" <<'EOF2'
#!/usr/bin/env bash
echo "SHELL-REACHED $*"
EOF2
chmod +x "$TMPD/fakeshell"

# Fake Claude TUI: last box on screen = border / "❯ <text>" / border / footer.
# On "/clear <name>" it runs the real pass-start.sh the way Claude Code would
# (a direct child of this process, so the hook finds this Claude as its ancestor).
cat >"$TMPD/tui.sh" <<EOF
#!/usr/bin/env bash
export LC_ALL=C.UTF-8
stty -echo -icanon 2>/dev/null
B='────────────────────────────────'
buf=""
printf 'args: %s\n' "\$*" >> "$TMPD/tui.log"
if [ -e "$TMPD/self-stop" ]; then rm -f "$TMPD/self-stop"; kill -STOP \$\$; printf 'continued\n' >> "$TMPD/tui.log"; fi
draw() { printf '\033[2J\033[H'; printf 'fake claude\n\n%s\n❯ %s\n%s\n  ? for shortcuts\n' "\$B" "\$buf" "\$B"; }
draw
while IFS= read -rsn1 ch; do
  case "\$ch" in
    "")
      printf 'line: %s\n' "\$buf" >> "$TMPD/tui.log"
      case "\$buf" in
        "/clear "*)
          printf '{"source":"clear","transcript_path":"%s"}' "$TMPD/newtx.jsonl" | bash "$HERE/../pass-start.sh" > "$TMPD/inject.out" 2>/dev/null
          printf 'inject: %s\n' "\$(jq -r '.hookSpecificOutput.additionalContext // empty' "$TMPD/inject.out" 2>/dev/null | head -c 60)" >> "$TMPD/tui.log" ;;
      esac
      buf="" ;;
    *) buf+="\$ch" ;;
  esac
  draw
done
EOF

# A leftover view of the session: an idle Claude-looking box that records any key it gets.
cat >"$TMPD/view.sh" <<EOF
#!/usr/bin/env bash
export LC_ALL=C.UTF-8
stty -echo -icanon 2>/dev/null
B='────────────────────────────────'
txt=""; [ -f "$TMPD/view-text" ] && txt="\$(cat "$TMPD/view-text")"
echo \$\$ > "$TMPD/view.pid"
printf '\033[2J\033[Hagents view\n\n%s\n❯ %s\n%s\n  ? for shortcuts\n' "\$B" "\$txt" "\$B"
listed=0
while :; do
  IFS= read -rsn1 -t 0.2 ch; rc=\$?
  if [ \$rc -eq 0 ]; then printf 'key\n' >> "$TMPD/view-keys.log"; elif [ \$rc -lt 128 ]; then break; fi
  if [ -e "$TMPD/view-list" ] && [ \$listed = 0 ]; then
    listed=1; printf '\033[2J\033[HSessions\n\n  imads  (stopped)\n  1 of 1\n'
  fi
done
EOF

# Shell rc for plain shell windows (nothing may ever be typed into them).
cat >"$TMPD/rc" <<EOF
PS1='\$ '
EOF
SHELL_CMD="bash --noprofile --rcfile $TMPD/rc -i"

printf '# Pass\n## Done last session\n- did x\n## Next task\nx\n' >"$TMPD/good.md"

FAILS=0
check() { if [ "$2" = 0 ]; then echo "PASS  $1"; else echo "FAIL  $1  (${3:-})"; FAILS=$((FAILS + 1)); fi; }
kvf() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1; }
wait_for() { local s="$1" i; shift; for ((i = 0; i < s * 5; i++)); do "$@" && return 0; sleep 0.2; done; return 1; }
pane_of() { $TM list-panes -a -F '#{pane_id} #{window_name}' 2>/dev/null | awk -v n="$1" '$2 == n { print $1; exit }'; }
has_file() { [ -e "$1" ]; }
log_has() { grep -q -- "$1" "$PASS_DIR/state/pass.log" 2>/dev/null; }
tui_has() { grep -qxF -- "$1" "$TMPD/tui.log" 2>/dev/null; }
tui_has_re() { grep -qE -- "$1" "$TMPD/tui.log" 2>/dev/null; }
pass() { env CLAUDE_CODE_SESSION_ID="$SID" bash "$SKILLD/pass.sh" "$@"; }
pane_changed() { [ -n "$(pane_of imads)" ] && [ "$(pane_of imads)" != "$OLDP" ]; }
descend_claude() {  # PID: the Claude process anywhere under PID
  local c r
  for c in $(ps -o pid= --ppid "$1" 2>/dev/null); do
    if [ "$(ps -o comm= -p "$c" 2>/dev/null)" = claude ]; then echo "$c"; return 0; fi
    r="$(descend_claude "$c")"; [ -n "$r" ] && { echo "$r"; return 0; }
  done
}
win_exists() { [ -n "$(pane_of imads)" ]; }
no_keys_sent() { ! grep -q '^send-keys' "$TMPD/tmux.log" 2>/dev/null; }
no_start() { ! grep -q '^\(new-window\|respawn-pane\)' "$TMPD/tmux.log" 2>/dev/null; }

mkfx() {
  jq -n --argjson pid "$BGPID" --arg cwd "${FXCWD:-$TMPD/cwd}" --arg sid "$SID" \
    '[{pid: $pid, id: "36494a69", cwd: $cwd, kind: "background", sessionId: $sid, name: "imads", status: "idle"}]' >"$TMPD/fx.json"
}
mktx() {  # MODEL MODE [USAGE]
  mkdir -p "$HOME/.claude/projects/p"
  {
    jq -nc --arg s "$SID" '{type: "custom-title", customTitle: "imads", sessionId: $s}'
    [ -n "${2:-}" ] && jq -nc --arg m "$2" '{type: "permission-mode", permissionMode: $m}'
    [ -n "${1:-}" ] && jq -nc --arg m "$1" --argjson u "${3:-200000}" \
      '{type: "assistant", isSidechain: false, timestamp: "2026-01-01T00:00:00.000Z", message: {model: $m, usage: {input_tokens: $u}}}'
  } >"$HOME/.claude/projects/p/$SID.jsonl"
}
reset() {  # MODEL MODE [USAGE]
  kill_jobs
  $TM kill-server >/dev/null 2>&1
  [ -n "$BGPID" ] && kill "$BGPID" 2>/dev/null
  sleep 600 & BGPID=$!
  rm -rf "$PASS_DIR" "$TMPD"/{sd.log,sd-fail,stop.log,tui.log,view-keys.log,stop-noop,stop-slow,no-box,tmux.log,notify.log,view-text,view-on-stop,view-list,view.pid,self-stop,shell.log,inject.out,newtx.jsonl,pwned} "$TMPD"/tm-fail-*
  $TM new-session -d -s main -n base -x 100 -y 30 "$SHELL_CMD" || { echo "cannot start tmux"; exit 1; }
  $TM set-option -g default-command "$SHELL_CMD"
  $TM set-option -g default-shell "$SHELL"
  mkfx
  mktx "${1-claude-opus-5-5}" "${2-}" "${3:-200000}"
}
mkwin() { $TM new-window -d -n "${1:-imads}" -c "${2:-$TMPD/cwd}"; sleep 0.4; }   # a plain shell window
mkview() {  # EXTRA_ARGS...: a window "imads" whose pane IS a Claude-named process (a leftover view)
  $TM new-window -d -n imads -c "${VIEWCWD:-$TMPD/cwd}" -- "$TMPD/realbin/claude" "$TMPD/view.sh" "$@"
  sleep 0.6
}
mkview_sh() {  # a leftover view that is a CHILD of the pane's shell (job control on); TAIL = what that shell does after it
  $TM new-window -d -n imads -c "$TMPD/cwd" -- bash -c 'set -m; "$0" "$@"; '"${TAIL:-exec bash --noprofile --rcfile $TMPD/rc -i}" "$TMPD/realbin/claude" "$TMPD/view.sh" "$@"
  sleep 0.6
}
relo_wait() {   # the window exists and its pane has the pass opt-in; sets P, N
  wait_for 25 win_exists || return 1
  P="$(pane_of imads)"; N="${P#%}"
  wait_for 25 test -f "$PASS_DIR/state/pane-$N.optin"
}
expect_args() {  # NAME EXPECTED: the argv the new Claude process received
  local got; got="$(grep -m1 '^args: ' "$TMPD/tui.log" 2>/dev/null | cut -c7-)"
  [ "$got" = "$2" ]; check "$1" $? "args='$got'"
}
nothing_left() { [ ! -e "$PASS_DIR/relocate" ] && ! ls "$PASS_DIR"/state/relocate-*.req >/dev/null 2>&1 && ! has_file "$TMPD/stop.log"; }
abort_quiet() {  # NAME: nothing stopped, nothing started, no keys
  [ ! -e "$TMPD/stop.log" ] && [ ! -e "$TMPD/tui.log" ] && no_keys_sent && no_start; check "$1" $?
}
refuse() {  # NAME EXPECT_SUBSTRING
  local out rc
  out="$(pass write --explicit <"$TMPD/good.md" 2>&1)"; rc=$?
  [ "$rc" = 1 ] && [[ "$out" == *"$2"* ]] && nothing_left; check "$1" $? "rc=$rc out=$out"
}

NOTRMSG='pass: not in a tmux pane ($TMUX_PANE unset); auto-pass needs tmux'
BGMAN='manual (background job; an explicit /pass moves it into tmux)'
NOVIEW="exists but does not hold this session's view; close or rename that tab, then run /pass again"

# ------------------------------------------------ not a background session --
reset
out="$(env -u CLAUDE_CODE_SESSION_ID bash "$SKILLD/pass.sh" status 2>&1)"; rc=$?
[ "$rc" = 1 ] && [ "$out" = "manual (not in tmux)" ]; check "1a no session id: status unchanged" $? "rc=$rc out=$out"
out="$(env -u CLAUDE_CODE_SESSION_ID bash "$SKILLD/pass.sh" write --explicit <"$TMPD/good.md" 2>&1)"; rc=$?
[ "$rc" = 1 ] && [ "$out" = "$NOTRMSG" ]; check "1b no session id: write unchanged" $? "rc=$rc out=$out"
jq 'map(.kind = "interactive")' "$TMPD/fx.json" >"$TMPD/fx2" && mv "$TMPD/fx2" "$TMPD/fx.json"
out="$(pass status 2>&1)"; rc=$?
[ "$rc" = 1 ] && [ "$out" = "manual (not in tmux)" ]; check "1c interactive entry: status unchanged" $? "rc=$rc out=$out"
out="$(pass write --explicit <"$TMPD/good.md" 2>&1)"; rc=$?
[ "$rc" = 1 ] && [ "$out" = "$NOTRMSG" ]; check "1d interactive entry: write unchanged" $? "rc=$rc out=$out"
echo '[]' >"$TMPD/fx.json"
out="$(pass write --explicit <"$TMPD/good.md" 2>&1)"; rc=$?
[ "$rc" = 1 ] && [ "$out" = "$NOTRMSG" ]; check "1e no agents entry: write unchanged" $? "rc=$rc out=$out"
out="$(pass cancel 2>&1)"; rc=$?
[ "$rc" = 1 ] && [ "$out" = "$NOTRMSG" ]; check "1f no request file: cancel unchanged" $? "rc=$rc out=$out"
[ ! -e "$PASS_DIR/relocate" ] && ! has_file "$TMPD/stop.log"; check "1g nothing saved, nothing stopped" $?
mkdir -p "$PASS_DIR/state"; printf 'name=imads\nsid=%s\njob=1.1\nepoch=%s\n' "$SID" "$(( $(date +%s) - 7200 ))" >"$PASS_DIR/state/relocate-$SID.req"
out="$(pass cancel 2>&1)"; rc=$?
[ "$rc" = 1 ] && [ "$out" = "$NOTRMSG" ] && [ ! -e "$PASS_DIR/state/relocate-$SID.req" ]
check "1h stale request: cancel keeps today's behaviour (the stale file is removed)" $? "rc=$rc out=$out"

# ------------------------------------------------------ validation order ----
reset
mkwin imads
out="$(pass write --explicit </dev/null 2>&1)"; rc=$?
[ "$rc" = 1 ] && [[ "$out" == "pass: empty note rejected" ]] && nothing_left; check "2a empty note: exit 1, nothing saved or launched" $? "rc=$rc out=$out"
head -c 9100 /dev/zero | tr '\0' 'a' >"$TMPD/long.md"
out="$(pass write --explicit <"$TMPD/long.md" 2>&1)"; rc=$?
[ "$rc" = 2 ] && [[ "$out" == *"cap is 9000"* ]] && nothing_left; check "2b too long: exit 2, nothing saved or launched" $? "rc=$rc out=$out"
out="$(pass write --explicit 'bad!name' <"$TMPD/good.md" 2>&1)"; rc=$?
[ "$rc" = 64 ] && nothing_left; check "2c invalid name: exit 64, nothing saved or launched" $? "rc=$rc out=$out"
printf '# Pass\n## Next task\nx\n' >"$TMPD/bad.md"
out="$(pass write --explicit <"$TMPD/bad.md" 2>&1)"; rc=$?
[ "$rc" = 4 ] && [[ "$out" == "pass: nothing saved — add a line that is exactly '## Done last session'"* ]] && nothing_left; check "2d no Done section: exit 4, nothing saved or launched" $? "rc=$rc out=$out"

# ------------------------------------------------------------- status -------
reset
before="$(find "$PASS_DIR" 2>/dev/null | sort)"
out="$(pass status 2>&1)"; rc=$?
[ "$rc" = 1 ] && [ "$out" = "$BGMAN" ]; check "3a no matching window: manual, exit 1" $? "rc=$rc out=$out"
mkview
P="$(pane_of imads)"
out="$(pass status 2>&1)"; rc=$?
[ "$rc" = 0 ] && [ "$out" = "auto name=imads relocate=$P" ]; check "3b leftover view of this session: auto relocate=<pane>" $? "rc=$rc out=$out P=$P"
after="$(find "$PASS_DIR" 2>/dev/null | sort)"
[ "$before" = "$after" ]; check "3c status writes no files" $? "$after"
$TM new-session -d -t main -s grp >/dev/null 2>&1
out="$(pass status 2>&1)"; rc=$?
[ "$rc" = 0 ] && [ "$out" = "auto name=imads relocate=$P" ]; check "3d grouped sessions show one window once" $? "rc=$rc out=$out"
mkdir -p "$PASS_DIR/state/optout"; printf 'name=imads\n' >"$PASS_DIR/state/optout/imads"
out="$(pass status 2>&1)"; rc=$?
[ "$rc" = 1 ] && [ "$out" = "$BGMAN" ]; check "3e opted out: manual" $? "rc=$rc out=$out"
rm -f "$PASS_DIR/state/optout/imads"
reset; mkwin imads
out="$(pass status 2>&1)"; rc=$?
[ "$rc" = 1 ] && [ "$out" = "$BGMAN" ]; check "3f same-named SHELL window: status manual (never auto)" $? "rc=$rc out=$out"
mkdir -p "$TMPD/my cwd"; FXCWD="$TMPD/my cwd" reset; mkview
out="$(pass status 2>&1)"; rc=$?
[ "$rc" = 1 ] && [ "$out" = "$BGMAN" ]; check "3g status applies write's cwd check: bad cwd is manual" $? "rc=$rc out=$out"
rm -rf "$TMPD/my cwd"

# ------------------------------------------------- refusals (nothing stopped)
reset; mkwin imads; mkwin imads
refuse "4a two windows of the same name: refused" "2 tmux windows are named 'imads'"
reset; mkwin imads; $TM split-window -d -t imads
refuse "4b two-pane window: refused" "has 2 panes"

# a shell window of that name: refused, no key ever sent, pane content untouched
reset; mkwin imads
SP="$(pane_of imads)"
snap_before="$($TM capture-pane -p -t "$SP")"
refuse "4c same-named shell window: refused with the 'close or rename that tab' reason" "tmux window 'imads' $NOVIEW"
sleep 1
[ "$($TM capture-pane -p -t "$SP")" = "$snap_before" ] && no_keys_sent && no_start; check "4d shell window: no keys sent, pane content unchanged" $?
! grep -q 'queued' "$PASS_DIR/state/pass.log" 2>/dev/null; check "4e shell window: no job queued" $?

# view-proof failures
reset
mkview
VP="$(pane_of imads)"; VPP="$($TM display-message -p -t "$VP" '#{pane_pid}')"
jq --argjson p "$VPP" --arg s "$OTHER" '. + [{pid: $p, cwd: "/x", kind: "interactive", sessionId: $s, name: "other", status: "idle"}]' "$TMPD/fx.json" >"$TMPD/fx2" && mv "$TMPD/fx2" "$TMPD/fx.json"
refuse "4f pane Claude owns another live session: refused" "$NOVIEW"
log_has "owns another live session"; check "4g the specific reason is in pass.log" $?
sleep 0.5
[ ! -e "$TMPD/view-keys.log" ] && no_keys_sent; check "4h no keys sent to that pane" $?
reset; mkview --resume "$OTHER"
refuse "4i pane Claude started for another uuid: refused" "$NOVIEW"
reset; mkview -p
refuse "4j pane Claude started with -p: refused" "$NOVIEW"
reset; mkview --print
refuse "4k pane Claude started with --print: refused" "$NOVIEW"
reset; mkview agents
refuse "4l pane Claude started with 'agents': refused" "$NOVIEW"
reset; mkview attach "$OTHER"
refuse "4m pane Claude started with 'attach <other id>': refused" "$NOVIEW"
reset; mkview attach deadbeef
refuse "4n pane Claude 'attach <other short id>': refused" "$NOVIEW"
reset; mkview -c
refuse "4n2 pane Claude started with -c (continue the latest): refused" "$NOVIEW"
reset; mkview --continue
refuse "4n3 pane Claude started with --continue: refused" "$NOVIEW"
reset; VIEWCWD="$TMPD" mkview
refuse "4o pane Claude's working directory differs from the session's: refused" "$NOVIEW"
log_has "working directory is"; check "4p cwd reason logged" $?
reset; mkview attach 36494a69
P="$(pane_of imads)"; out="$(pass status 2>&1)"
[ "$out" = "auto name=imads relocate=$P" ]; check "4q 'attach <this session's short id>' is still our view" $? "$out"
reset; $TM new-window -d -n imads -c "$TMPD/cwd" -- sleep 30; sleep 0.4
refuse "4r foreground is neither a shell nor Claude: refused" "$NOVIEW"

# ------------------------------------------------ non-explicit, no window ----
reset
out="$(pass write <"$TMPD/good.md" 2>&1)"; rc=$?
[ "$rc" = 0 ] && [[ "$out" == *"no tmux window named 'imads' exists; note saved"* ]] && [ -s "$PASS_DIR/relocate/$SID.md" ] \
  && ! ls "$PASS_DIR"/state/relocate-*.req >/dev/null 2>&1 && ! has_file "$TMPD/stop.log"
check "5a non-explicit, no window: note saved, no job, exit 0" $? "rc=$rc out=$out"
mkdir -p "$PASS_DIR/state/optout"; printf 'name=imads\n' >"$PASS_DIR/state/optout/imads"; mkwin imads
rm -f "$PASS_DIR/relocate/$SID.md"
out="$(pass write <"$TMPD/good.md" 2>&1)"; rc=$?
[ "$rc" = 0 ] && [[ "$out" == *"opted out"*"note saved, not clearing"* ]] && [ -s "$PASS_DIR/relocate/$SID.md" ] && ! has_file "$TMPD/stop.log" \
  && ! ls "$PASS_DIR"/state/relocate-*.req >/dev/null 2>&1
check "5b non-explicit, opted out: note saved, no job" $? "rc=$rc out=$out"
reset "claude-opus-5-5" "" 1000
mkview
out="$(PASS_MIN_CONTEXT=90000 pass write <"$TMPD/good.md" 2>&1)"; rc=$?
[ "$rc" = 0 ] && [[ "$out" == *"context 1000 < 90000; note saved, not clearing"* ]] && [ -s "$PASS_DIR/relocate/$SID.md" ] && ! has_file "$TMPD/stop.log" \
  && ! ls "$PASS_DIR"/state/relocate-*.req >/dev/null 2>&1
check "5c non-explicit, under minimum context: note saved, no job" $? "rc=$rc out=$out"
reset
mkdir -p "$PASS_DIR"; printf 'x' >"$PASS_DIR/relocate"      # a FILE where the note dir must go
out="$(pass write <"$TMPD/good.md" 2>&1)"; rc=$?
[ "$rc" = 1 ] && [[ "$out" == *"pass: cannot create"* ]]; check "5d note that cannot be saved: reason printed, exit 1" $? "rc=$rc out=$out"

# ----------------------------------------------------------- happy paths ----
# New window, end to end: argv of the tmux call, argv of Claude, bound state, and
# the Stop hook's job carrying on through pass-start's injection to the resume prompt.
reset "claude-opus-5-5" "acceptEdits"
out="$(pass write --explicit <"$TMPD/good.md" 2>&1)"; rc=$?
[ "$rc" = 0 ] && [[ "$out" == "pass: this session runs as a background job; note saved ("*" chars). When this turn ends the job is stopped (anything it still runs in the background ends with it) and the conversation is reopened in tmux window 'imads' (new window), then cleared and resumed from the note. /pass cancel stops it, but only before this turn ends." ]]
check "6a write: queued message (names the background-work consequence) and exit 0" $? "rc=$rc out=$out"
[ "$(stat -c %a "$PASS_DIR/relocate/$SID.md" 2>/dev/null)" = 600 ]; check "6a2 note saved 0600" $?
relo_wait; check "6b job created the window and bound the new Claude (optin written)" $?
[ "$(cat "$TMPD/stop.log")" = "stop 36494a69" ]; check "6c claude stop called once with the short id" $? "$(cat "$TMPD/stop.log" 2>&1)"
line="$(grep '^new-window' "$TMPD/tmux.log" | sed -E 's/-t \$[0-9]+ /-t SESS /')"
[ "$line" = "new-window -d -P -F #{pane_id} -t SESS -n imads -c $TMPD/cwd -e PASS_DIR=$PASS_DIR -e PASS_CLAUDE=$PASS_CLAUDE -- bash $ABSD/pass-relocate.sh --run-claude --model claude-opus-5-5 --permission-mode acceptEdits --resume $SID" ]
check "6d exact new-window argv (detached, cwd, -- bash <abs>/pass-relocate.sh --run-claude ...)" $? "$line"
expect_args "6e Claude received exactly: --model, --permission-mode, --resume" "--model claude-opus-5-5 --permission-mode acceptEdits --resume $SID"
PP="$($TM display-message -p -t "$P" '#{pane_pid}')"; CC="$(descend_claude "$PP")"
O="$PASS_DIR/state/pane-$N.optin"
[ "$(kvf "$O" name)" = imads ] && [ "$(kvf "$O" pane_pid)" = "$PP" ] && [ "$(kvf "$O" claude_pid)" = "$CC" ] && ! grep -q oneshot "$O"
check "6f opt-in bound to the new pane pid and Claude pid" $? "$(cat "$O" 2>&1) pp=$PP cc=$CC"
[ ! -e "$PASS_DIR/relocate/$SID.md" ] && ! ls "$PASS_DIR"/state/relocate-*.req >/dev/null 2>&1 && [ ! -e "$PASS_DIR/relocate/$SID.failed" ]
check "6g note moved out of relocate/, request removed, no .failed" $?
[ "$($TM display-message -p -t main: '#{window_name}')" = base ]; check "6h window created detached (focus not stolen)" $?
[ "$($TM display-message -p -t "$P" '#{pane_current_path}')" = "$TMPD/cwd" ]; check "6i window opened in the job's cwd" $?
[ "$($TM display-message -p -t "$P" '#{pane_current_command}')" = claude ]; check "6j the pane's foreground command is claude (own process group)" $?
wait_for 40 tui_has "line: /clear imads"; check "6k the Stop hook's job typed /clear imads" $? "$(cat "$TMPD/tui.log")"
wait_for 20 tui_has_re '^inject: Auto-pass for session "imads"'; check "6l pass-start injected the note after the clear" $? "$(cat "$TMPD/tui.log")"
wait_for 20 tui_has "line: /rename imads"; check "6m the job typed /rename imads" $?
wait_for 20 tui_has_re '^line: \[auto-pass\] Context was cleared by the pass hook'; check "6n the job typed the resume prompt" $? "$(cat "$TMPD/tui.log")"
ls "$PASS_DIR"/archive/imads-pane-"$N"-*.md >/dev/null 2>&1; check "6o the injected note was archived" $?
! grep -q 'C-c' "$TMPD/tmux.log" && ! grep '^send-keys' "$TMPD/tmux.log" | grep -qE -- '--resume|claude'; check "6p no Ctrl+C, and no key ever started Claude" $?

# existing leftover view: respawned in place (same pane id), view process gone
reset "claude-opus-5-5" "plan"
mkview
P="$(pane_of imads)"; N="${P#%}"; VPP="$($TM display-message -p -t "$P" '#{pane_pid}')"
out="$(pass write --explicit <"$TMPD/good.md" 2>&1)"; rc=$?
[ "$rc" = 0 ] && [[ "$out" == *"reopened in tmux window 'imads' ($P)"* ]]; check "7a view of this session accepted, queued with its pane id" $? "rc=$rc out=$out"
wait_for 25 test -f "$PASS_DIR/state/pane-$N.optin"; check "7b respawned pane bound" $?
[ "$(pane_of imads)" = "$P" ]; check "7c same pane id after respawn" $?
line="$(grep '^respawn-pane' "$TMPD/tmux.log")"
[ "$line" = "respawn-pane -k -t $P -c $TMPD/cwd -e PASS_DIR=$PASS_DIR -e PASS_CLAUDE=$PASS_CLAUDE -- bash $ABSD/pass-relocate.sh --run-claude --model claude-opus-5-5 --permission-mode plan --resume $SID" ]
check "7d exact respawn-pane argv" $? "$line"
expect_args "7e Claude received the argument list" "--model claude-opus-5-5 --permission-mode plan --resume $SID"
! kill -0 "$VPP" 2>/dev/null; check "7f the old view process was killed by the respawn" $?
[ ! -e "$TMPD/view-keys.log" ]; check "7g the view never received a key" $?
! grep -q 'C-c' "$TMPD/tmux.log" && ! grep '^send-keys' "$TMPD/tmux.log" | grep -qE -- '--resume|claude'; check "7h no Ctrl+C, no typed command" $?
wait_for 40 tui_has "line: /clear imads"; check "7i hook job cleared it" $?

# model and mode rules
reset "claude-opus-5-5[1m]" "auto"
pass write --explicit <"$TMPD/good.md" >/dev/null 2>&1; relo_wait
expect_args "8a model with brackets passes through unquoted (argv, no shell)" "--model claude-opus-5-5[1m] --permission-mode auto --resume $SID"
reset "claude-opus-5-5" "default"
pass write --explicit <"$TMPD/good.md" >/dev/null 2>&1; relo_wait
expect_args "8b recorded mode 'default' becomes manual" "--model claude-opus-5-5 --permission-mode manual --resume $SID"
reset "claude-opus-5-5" ""
pass write --explicit <"$TMPD/good.md" >/dev/null 2>&1; relo_wait
expect_args "8c no recorded mode: --permission-mode manual" "--model claude-opus-5-5 --permission-mode manual --resume $SID"
reset "" ""
pass write --explicit <"$TMPD/good.md" >/dev/null 2>&1; relo_wait
expect_args "8d no model, no mode: only manual + resume" "--permission-mode manual --resume $SID"
reset "claude-opus-5-5" "bypassPermissions"
pass write --explicit <"$TMPD/good.md" >/dev/null 2>&1; relo_wait
expect_args "8e bypassPermissions becomes manual" "--model claude-opus-5-5 --permission-mode manual --resume $SID"
log_has "bypassPermissions is never carried"; check "8f the substitution is logged" $?
reset "claude-opus-5-5" "zzz"
pass write --explicit <"$TMPD/good.md" >/dev/null 2>&1; relo_wait
expect_args "8g unknown mode becomes manual" "--model claude-opus-5-5 --permission-mode manual --resume $SID"
reset "claude-x;touch $TMPD/pwned" "plan"
pass write --explicit <"$TMPD/good.md" >/dev/null 2>&1; relo_wait
expect_args "8h model with shell metacharacters is dropped" "--permission-mode plan --resume $SID"
[ ! -e "$TMPD/pwned" ]; check "8i nothing was executed from the model string" $?
reset "-evil" "plan"
pass write --explicit <"$TMPD/good.md" >/dev/null 2>&1; relo_wait
expect_args "8j model with a leading dash is dropped" "--permission-mode plan --resume $SID"
log_has "rejected by the strict regex"; check "8k the drop is logged" $?

# --run-claude wrapper: shows the recorded failure line, then the login shell
reset
out="$(SHELL="$TMPD/fakeshell" bash "$SKILLD/pass-relocate.sh" --run-claude --resume "$SID" </dev/null 2>/dev/null | tail -n1)"
[ "$out" = "SHELL-REACHED -l" ]; check "9a wrapper: Claude exits, login shell follows" $? "$out"
mkdir -p "$PASS_DIR/relocate"; printf 'resume with: cd /x && claude --resume %s\n' "$SID" >"$PASS_DIR/relocate/$SID.failed"
out="$(SHELL="$TMPD/fakeshell" bash "$SKILLD/pass-relocate.sh" --run-claude --model m --resume "$SID" </dev/null 2>/dev/null | tail -n2)"
[ "$out" = "resume with: cd /x && claude --resume $SID
SHELL-REACHED -l" ]; check "9b wrapper: prints the .failed line, then the login shell" $? "$out"
[ ! -e "$TMPD/shell.log" ] && [ "$(grep -c '^args: ' "$TMPD/tui.log")" = 2 ] && tui_has "args: --model m --resume $SID"
check "9b2 a \$SHELL that is not bash/zsh: Claude runs directly, argv intact" $?

# the wrapper in a real pane, through the user's interactive login shell ($SHELL -lic 'exec "$0" "$@"')
reset
$TM new-window -d -n wrap -c "$TMPD/cwd" -- bash "$SKILLD/pass-relocate.sh" --run-claude --model "claude-opus-5-5[1m]" --resume "$SID"
wait_for 10 tui_has "args: --model claude-opus-5-5[1m] --resume $SID"; check "9c wrapper via \$SHELL -lic: Claude got its argv intact (nothing re-split)" $? "$(cat "$TMPD/tui.log" 2>&1)"
SL="$(cat "$TMPD/shell.log" 2>/dev/null)"
[[ "$SL" == '-lic '*'"$0" "$@"'*" $PASS_CLAUDE --model claude-opus-5-5[1m] --resume $SID" ]]
check "9d the shell was started interactive + login, Claude's words as positional parameters (no exec: it owns job control)" $? "$SL"
WP="$(pane_of wrap)"
[ "$($TM display-message -p -t "$WP" '#{pane_current_command}')" = claude ]; check "9e pane foreground command is still claude" $?
WPP="$($TM display-message -p -t "$WP" '#{pane_pid}')"
( PASS_SOURCE_ONLY=1 source "$HOOK"; is_claude_pid "$(descend_claude "$WPP")" ); check "9f the Claude process sits under the pane's pid (pass-start's lookup works)" $?
# Ctrl+Z: Claude stops itself once; the wrapper brings it back with fg
reset; : >"$TMPD/self-stop"
$TM new-window -d -n wrap -c "$TMPD/cwd" -- bash "$SKILLD/pass-relocate.sh" --run-claude --resume "$SID"
wait_for 10 tui_has "continued"; check "9g Claude stopped under the wrapper is brought back to the foreground" $? "$(cat "$TMPD/tui.log" 2>&1)"
WP="$(pane_of wrap)"
[ "$($TM display-message -p -t "$WP" '#{pane_current_command}')" = claude ]; check "9h and it is running again as the pane's foreground" $?

# ------------------------------------------------- abort and cancel paths ----
reset
PASS_DELAY=3 pass write --explicit <"$TMPD/good.md" >/dev/null 2>&1
sleep 0.8
out="$(pass cancel 2>&1)"; rc=$?
[ "$rc" = 0 ] && [[ "$out" == "pass: cancelled"* ]] && ! ls "$PASS_DIR"/state/relocate-*.req >/dev/null 2>&1; check "11a cancel removes the request, exit 0" $? "rc=$rc out=$out"
wait_for 8 log_has "request cancelled"; check "11b job saw the cancellation" $?
abort_quiet "11c cancelled: nothing stopped, nothing started"
[ -s "$PASS_DIR/relocate/$SID.md" ]; check "11d note stays saved" $?

reset
PASS_DELAY=3 pass write --explicit <"$TMPD/good.md" >/dev/null 2>&1
sleep 1
printf '%s\n' '{"type":"user","timestamp":"2099-01-01T00:00:00.000Z","promptId":"p1","message":{"role":"user","content":"hello"}}' >>"$HOME/.claude/projects/p/$SID.jsonl"
wait_for 8 log_has "new activity in transcript"; check "12a user activity during the quiet window aborts" $?
abort_quiet "12b activity: nothing stopped, nothing started"
[ ! -e "$PASS_DIR/state/relocate-$SID.req" ]; check "12c request cleaned up" $?

# target changes between write and job: a shell window appears (new -> now exists)
reset
PASS_DELAY=3 pass write --explicit <"$TMPD/good.md" >/dev/null 2>&1
sleep 0.8; mkwin imads
wait_for 10 log_has "target changed since the request"; check "13a a window that appears after write aborts the job" $?
abort_quiet "13b nothing stopped, nothing started, no keys"
# the view stops being this session's view (its Claude now owns another session)
reset; mkview
PASS_DELAY=3 pass write --explicit <"$TMPD/good.md" >/dev/null 2>&1
sleep 0.8
VP="$(pane_of imads)"; VPP="$($TM display-message -p -t "$VP" '#{pane_pid}')"
jq --argjson p "$VPP" --arg s "$OTHER" '. + [{pid: $p, cwd: "/x", kind: "interactive", sessionId: $s, name: "other", status: "idle"}]' "$TMPD/fx.json" >"$TMPD/fx2" && mv "$TMPD/fx2" "$TMPD/fx.json"
wait_for 10 log_has "target pane no longer usable"; check "13c view proof re-run at job time" $?
abort_quiet "13d changed view: nothing stopped, no keys sent"
[ ! -e "$TMPD/view-keys.log" ]; check "13e the view never received a key" $?

# a view with text in its input box: the job aborts before the stop
reset; printf 'half-typed draft' >"$TMPD/view-text"; mkview
pass write --explicit <"$TMPD/good.md" >/dev/null 2>&1
wait_for 10 log_has "not idle with an empty input box"; check "13f view with text in its box aborts" $?
abort_quiet "13g text in the box: stop never called, nothing started, no keys"
[ ! -e "$TMPD/view-keys.log" ] && [ -s "$PASS_DIR/relocate/$SID.md" ]; check "13h the view is untouched and the note is kept" $?

# a background shell still running under the job: abort before the stop
reset
kill "$BGPID" 2>/dev/null
bash -c 'sh -c "sleep 600; :" & wait' & BGPID=$!
sleep 0.5; mkfx
pass write --explicit <"$TMPD/good.md" >/dev/null 2>&1
wait_for 12 log_has "background shell still running under the job"; check "13i a shell child of the background Claude aborts the job" $?
abort_quiet "13j shell child: stop never called, nothing started"
pkill -P "$BGPID" 2>/dev/null

reset
: >"$TMPD/stop-noop"
pass write --explicit <"$TMPD/good.md" >/dev/null 2>&1
wait_for 12 log_has "did not stop within"; check "14a stop that never takes effect: logged" $?
[ "$(cat "$TMPD/stop.log")" = "stop 36494a69" ] && no_start \
  && [ "$(cat "$PASS_DIR/relocate/$SID.failed" 2>/dev/null)" = "resume with: cd $TMPD/cwd && claude --resume $SID" ]
check "14b stop sent but not seen: nothing started, recovery line written (it may still land)" $? "$(cat "$PASS_DIR/relocate/$SID.failed" 2>&1)"
log_has "the stop may still take effect"; check "14c it is the post-stop failure exit, not a quiet abort" $?
[ -s "$PASS_DIR/relocate/$SID.md" ] && [ ! -e "$PASS_DIR/state/relocate-$SID.req" ]; check "14d note kept, request removed" $?

# what the stop does to an existing view (recorded pane pid + Claude pid decide)
# a. the view stays alive and shows a list (no input box): respawned in place
reset "claude-opus-5-5" "plan"; echo list >"$TMPD/view-on-stop"
mkview_sh
P="$(pane_of imads)"; N="${P#%}"; VPP="$($TM display-message -p -t "$P" '#{pane_pid}')"; VCP="$(ps -o pid= --ppid "$VPP" | tr -d ' ')"
pass write --explicit <"$TMPD/good.md" >/dev/null 2>&1
wait_for 25 test -f "$PASS_DIR/state/pane-$N.optin"; check "14e view alive on a list screen after the stop: respawned and bound" $?
[ -e "$TMPD/view-list" ] && grep -q '^respawn-pane' "$TMPD/tmux.log" && ! grep -q '^new-window' "$TMPD/tmux.log" && [ "$(pane_of imads)" = "$P" ]
check "14f it was the respawn-pane path on the same pane id (no idle box needed)" $?
! kill -0 "$VCP" 2>/dev/null && [ ! -e "$TMPD/view-keys.log" ] && no_keys_sent && [ ! -e "$PASS_DIR/relocate/$SID.failed" ]
check "14g old view gone, no key sent to it, no .failed" $?
log_has "respawned pane $P (the view was still running)"; check "14h reason logged" $?
# b. the view exits to the pane's shell: respawned
reset "claude-opus-5-5" "plan"; echo exit >"$TMPD/view-on-stop"
mkview_sh
P="$(pane_of imads)"; N="${P#%}"
pass write --explicit <"$TMPD/good.md" >/dev/null 2>&1
wait_for 25 test -f "$PASS_DIR/state/pane-$N.optin"; check "14i view exited to the pane's shell: respawned and bound" $?
grep -q '^respawn-pane' "$TMPD/tmux.log" && ! grep -q '^new-window' "$TMPD/tmux.log" && [ "$(pane_of imads)" = "$P" ] && no_keys_sent
check "14j respawn-pane on the same pane id, no new window, no keys" $?
log_has "respawned pane $P (the view had exited to the pane's shell)"; check "14k reason logged" $?
# c. the view was the pane's own command and exits: the pane is gone, a new window is made
reset "claude-opus-5-5" "plan"; echo exit >"$TMPD/view-on-stop"
mkview
P="$(pane_of imads)"; OLDP="$P"
pass write --explicit <"$TMPD/good.md" >/dev/null 2>&1
wait_for 25 pane_changed; relo_wait; check "14l pane gone after the stop: a new window was created and bound" $?
NP="$(pane_of imads)"
[ "$NP" != "$OLDP" ] && grep -q '^new-window' "$TMPD/tmux.log" && ! grep -q '^respawn-pane' "$TMPD/tmux.log"
check "14m new-window path (different pane id), no respawn" $? "old=$OLDP new=$NP"
log_has "pane $OLDP is gone after the stop"; check "14n reason logged" $?
# d. anything else after the stop: failure exit, nothing respawned
reset "claude-opus-5-5" "plan"; echo exit >"$TMPD/view-on-stop"
TAIL='sleep 600' mkview_sh
P="$(pane_of imads)"
PASS_RELOCATE_REOPEN_WAIT=1 pass write --explicit <"$TMPD/good.md" >/dev/null 2>&1
wait_for 20 log_has "unexpected state after the stop"; check "14p view gone but the shell runs something else: failure exit" $?
no_start && [ "$(cat "$PASS_DIR/relocate/$SID.failed" 2>/dev/null)" = "resume with: cd $TMPD/cwd && claude --resume $SID" ] && [ -s "$PASS_DIR/relocate/$SID.md" ]
check "14q nothing respawned or created, recovery line written, note kept" $?
# the failure line left by an earlier failure is removed once Claude is running again
reset; : >"$TMPD/no-box"
mkdir -p "$PASS_DIR/relocate"; printf 'resume with: old\n' >"$PASS_DIR/relocate/$SID.failed"
PASS_RELOCATE_START=3 pass write --explicit <"$TMPD/good.md" >/dev/null 2>&1
wait_for 20 log_has "is not at an idle prompt"; check "14r (setup) Claude running but never idle" $?
[ ! -e "$PASS_DIR/relocate/$SID.failed" ]; check "14s an old .failed is removed once the reopened Claude is seen running" $?

# two jobs for one window: the second finds the lock held
reset
mkdir -p "$PASS_DIR/state"
flock "$PASS_DIR/state/relocate-window-imads.lock" sleep 30 & FL=$!
sleep 0.3
pass write --explicit <"$TMPD/good.md" >/dev/null 2>&1
wait_for 12 log_has "holds the lock for window 'imads'"; check "15a second job aborts while the window lock is held" $?
abort_quiet "15b lock held: stop never called, nothing started"
pkill -P "$FL" 2>/dev/null; kill "$FL" 2>/dev/null

# a request older than an hour is ignored and removed by the job
reset
mkdir -p "$PASS_DIR/state" "$PASS_DIR/relocate"; cp "$TMPD/good.md" "$PASS_DIR/relocate/$SID.md"
printf 'name=imads\nsid=%s\nshort=36494a69\ncwd=%s\npane=new\nexplicit=1\nepoch=%s\njob=1.2\nbgpid=%s\ntitle=\n' "$SID" "$TMPD/cwd" "$(( $(date +%s) - 4000 ))" "$BGPID" >"$PASS_DIR/state/relocate-$SID.req"
bash "$SKILLD/pass-relocate.sh" --job "$SID" 1.2
log_has "older than 3600s"; check "16a stale request: ignored by the job" $?
[ ! -e "$PASS_DIR/state/relocate-$SID.req" ]; check "16b stale request removed" $?
abort_quiet "16c stale request: nothing stopped, nothing started"
printf 'name=imads\nsid=%s\njob=1.1\nepoch=%s\n' "$SID" "$(( $(date +%s) - 7200 ))" >"$PASS_DIR/state/relocate-$SID.req"
out="$(pass status 2>&1)"
[ ! -e "$PASS_DIR/state/relocate-$SID.req" ]; check "16d stale request removed by pass.sh in a background session" $?

# failures after a successful stop: recovery line, .failed, notifier
reset; : >"$TMPD/tm-fail-new-window"
PASS_NOTIFY="$TMPD/notify.sh" pass write --explicit <"$TMPD/good.md" >/dev/null 2>&1
wait_for 12 log_has "could not create tmux window"; check "17a new-window failure after the stop is logged" $?
WANT="resume with: cd $TMPD/cwd && claude --resume $SID"
[ "$(cat "$PASS_DIR/relocate/$SID.failed" 2>/dev/null)" = "$WANT" ]; check "17b .failed holds the cd + resume line" $? "$(cat "$PASS_DIR/relocate/$SID.failed" 2>&1)"
log_has "$WANT"; check "17c the same line is in pass.log" $?
wait_for 5 test -s "$TMPD/notify.log" && grep -qF -- "$WANT" "$TMPD/notify.log"; check "17d \$PASS_NOTIFY called with the recovery line" $? "$(cat "$TMPD/notify.log" 2>&1)"
[ -s "$PASS_DIR/relocate/$SID.md" ] && [ ! -e "$PASS_DIR/state/relocate-$SID.req" ]; check "17e note kept, request removed" $?
reset; mkview; : >"$TMPD/tm-fail-respawn-pane"
pass write --explicit <"$TMPD/good.md" >/dev/null 2>&1
wait_for 12 log_has "could not respawn pane"; check "17f respawn failure after the stop is logged" $?
[ "$(cat "$PASS_DIR/relocate/$SID.failed" 2>/dev/null)" = "$WANT" ]; check "17g respawn failure writes .failed" $?
[ ! -e "$TMPD/notify.log" ]; check "17h no notifier set: none called" $?
reset; : >"$TMPD/stop-slow"
pass write --explicit <"$TMPD/good.md" >/dev/null 2>&1
wait_for 10 test -s "$TMPD/stop.log"
pass cancel >/dev/null 2>&1
wait_for 12 log_has "cancelled or superseded after the stop"; check "17i cancel detected after the stop goes through the failure exit" $?
[ "$(cat "$PASS_DIR/relocate/$SID.failed" 2>/dev/null)" = "$WANT" ]; check "17j .failed written for a cancel after the stop" $?
no_start; check "17k nothing started after the cancel" $?

# Claude started but never reaches an idle prompt: not a failure, note kept
reset; : >"$TMPD/no-box"
PASS_RELOCATE_START=3 pass write --explicit <"$TMPD/good.md" >/dev/null 2>&1
wait_for 20 log_has "is not at an idle prompt"; check "18a Claude that never shows a box: logged as not idle (no failure)" $?
[ ! -e "$PASS_DIR/relocate/$SID.failed" ] && [ -s "$PASS_DIR/relocate/$SID.md" ] && grep -q "note kept in relocate/$SID.md, run /pass there" "$PASS_DIR/state/pass.log"
check "18b no .failed, note kept, instruction logged" $?

# ---------------------------------------------------------- loop guard ------
reset
mkview; P="$(pane_of imads)"; N="${P#%}"
mkdir -p "$PASS_DIR/state"; printf 'epoch=%s\n' "$(date +%s)" >"$PASS_DIR/state/pane-$N.lastclear"
pass write --explicit <"$TMPD/good.md" >/dev/null 2>&1
wait_for 10 log_has "loop guard"; check "19a existing pane inside the loop-guard window: job aborts" $?
abort_quiet "19b loop guard: stop never called, nothing started"
[ -s "$PASS_DIR/relocate/$SID.md" ]; check "19c note kept" $?
# a brand-new pane whose id carries a recent lastclear (ids can repeat after a tmux restart)
reset
NEXT=$(( $($TM list-panes -a -F '#{pane_id}' | tr -d '%' | sort -n | tail -n1) + 1 ))
mkdir -p "$PASS_DIR/state"; printf 'epoch=%s\n' "$(date +%s)" >"$PASS_DIR/state/pane-$NEXT.lastclear"
pass write --explicit <"$TMPD/good.md" >/dev/null 2>&1
relo_wait; check "19d new window relocated even with a recent lastclear on its id" $?
wait_for 8 log_has "relocated, note saved, not clearing"; check "19e post-bind loop guard logged" $?
sleep 5
! tui_has "line: /clear imads" && [ ! -e "$PASS_DIR/state/pane-$N.clearing" ]; check "19f no /clear typed, no token left" $?
[ -s "$PASS_DIR/pane-$N.md" ]; check "19g note stays saved for the pane" $?

# --------------------------------------------- cwd rules, systemd launch -----
for bad in "$TMPD/my cwd" "$TMPD/it's"; do
  mkdir -p "$bad"; FXCWD="$bad" reset; mkwin imads
  refuse "20a cwd '${bad#$TMPD/}': refused, nothing saved" "not a plain existing path"
done
rm -rf "$TMPD/my cwd" "$TMPD/it's"
FXCWD="$TMPD/nonexistent" reset; mkwin imads
refuse "20b cwd that does not exist: refused" "not a plain existing path"

reset
export PASS_TEST_NL=$'a\nb'
out="$(PASS_RELOCATE_NO_SYSTEMD=0 pass write --explicit <"$TMPD/good.md" 2>&1)"; rc=$?
unset PASS_TEST_NL
[ "$rc" = 0 ]; check "21a systemd launch: queued" $? "rc=$rc out=$out"
relo_wait; check "21b job started through systemd-run ran to completion" $?
log_has "launcher=systemd-run"; check "21c launcher logged" $?
grep -qx -- '--user' "$TMPD/sd.log" && grep -qx -- '--collect' "$TMPD/sd.log" && grep -qx -- '--quiet' "$TMPD/sd.log"; check "21d user/collect/quiet flags" $?
grep -qE '^pass-relocate-36494a69-[0-9]+$' "$TMPD/sd.log"; check "21e unit name pass-relocate-<short id>-<epoch>" $?
grep -qx -- "--setenv=HOME=$HOME" "$TMPD/sd.log" && grep -q -- '^--setenv=PATH=' "$TMPD/sd.log" \
  && grep -qx -- "--setenv=PASS_DIR=$PASS_DIR" "$TMPD/sd.log" && grep -qx -- '--setenv=PASS_RELOCATE_POLL=0.2' "$TMPD/sd.log" \
  && ! grep -q -- 'TMUX_TMPDIR' "$TMPD/sd.log"; check "21f --setenv list: HOME, PATH, PASS_*, no TMUX_TMPDIR when unset" $?
! grep -q 'PASS_TEST_NL' "$TMPD/sd.log" && ! grep -qx 'b' "$TMPD/sd.log"; check "21g a PASS_* value with a newline is skipped" $?
grep -qx -- "$ABSD/pass-relocate.sh" "$TMPD/sd.log" && grep -qx -- "$SID" "$TMPD/sd.log" && grep -qx -- '--job' "$TMPD/sd.log" && [ "$(grep -n '^bash$' "$TMPD/sd.log" | cut -d: -f1)" -gt "$(grep -n '^--unit$' "$TMPD/sd.log" | cut -d: -f1)" ]
check "21h command is bash pass-relocate.sh --job <uuid> <job id>" $? "$(tr '\n' ' ' <"$TMPD/sd.log")"

reset
: >"$TMPD/sd-fail"
PASS_RELOCATE_NO_SYSTEMD=0 pass write --explicit <"$TMPD/good.md" >/dev/null 2>&1
relo_wait; check "22a failing systemd-run: falls back and still relocates" $?
log_has "launcher=setsid"; check "22b fallback launcher logged" $?

echo
if [ "$FAILS" -ne 0 ]; then echo "$FAILS FAILED"; exit 1; fi
echo "all passed"
