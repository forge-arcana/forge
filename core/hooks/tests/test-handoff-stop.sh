#!/usr/bin/env bash
#
# Test for handoff-stop.sh's screen reading (read_box / pane_state), notably
# that Claude Code's dim suggested prompt in an empty input box counts as empty.
# Uses a PRIVATE tmux server (tmux -L); touches nothing else. Exit non-zero on
# any failure.   Run:  bash core/hooks/tests/test-handoff-stop.sh
# Lives in core/hooks/tests/ so cast-deploy's core/hooks/*.sh glob skips it.

HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.."
command -v tmux >/dev/null 2>&1 || { echo "tmux not found"; exit 1; }

SOCK="handoff-test-$$-$RANDOM"
TMPD="$(mktemp -d)"
export HANDOFF_TMUX="tmux -u -L $SOCK"
cleanup() { tmux -u -L "$SOCK" kill-server >/dev/null 2>&1; rm -rf "$TMPD"; }
trap cleanup EXIT

HANDOFF_SOURCE_ONLY=1 source "$HERE/handoff-stop.sh"
set +u   # sourcing turned nounset on; the fixtures below don't need it

# Fixture drawn in the pane: history, [spinner], border, prompt line, border, footer.
cat > "$TMPD/fx.sh" <<'EOF'
#!/usr/bin/env bash
export LC_ALL=C.UTF-8
B='────────────────────────────────'
printf '\033[2J\033[H'
printf 'history line one\nhistory line two\n\033[38;5;231m> an old user message\033[0m\n'
[ -n "$2" ] && printf '%s\n' "$2"
printf '%s\n' "$B"
printf '%b\n' "$1"
printf '%s\n' "$B"
printf '  ? for shortcuts\n'
sleep 600
EOF

FAILS=0 CASE=0
draw() {  # draw PROMPT_LINE_FORMAT [SPINNER_LINE]  -> sets PANE
  CASE=$((CASE + 1))
  tmux -u -L "$SOCK" new-session -d -s "c$CASE" -x 100 -y 30 \
    bash "$TMPD/fx.sh" "$1" "${2:-}" || { echo "cannot start tmux"; exit 1; }
  PANE="$(tmux -u -L "$SOCK" display-message -p -t "c$CASE" '#{pane_id}')"
  local t
  for ((t = 0; t < 40; t++)); do   # wait for the footer to appear
    tmux -u -L "$SOCK" capture-pane -p -t "$PANE" | grep -q 'for shortcuts' && break
    sleep 0.1
  done
  sleep 0.2
}

check() {  # check NAME CONDITION(0/1)
  if [ "$2" = 0 ]; then echo "PASS  $1"; else echo "FAIL  $1  (rc/why: ${3:-})"; FAILS=$((FAILS + 1)); fi
}

NB='\xc2\xa0'
P='\xe2\x9d\xaf'

# state NAME PROMPT_FORMAT WANT_RC [WHY_SUBSTRING] [SPINNER]
state() {
  local name="$1" fmt="$2" want="$3" why="${4:-}" spin="${5:-}" rc
  draw "$fmt" "$spin"
  pane_state; rc=$?
  if [ "$rc" != "$want" ]; then check "$name" 1 "rc=$rc want=$want why=$PANE_WHY"; return; fi
  if [ -n "$why" ] && [[ "$PANE_WHY" != *"$why"* ]]; then check "$name" 1 "why=$PANE_WHY"; return; fi
  check "$name" 0
}

state "1 empty box (prompt + NBSP) is idle"            "$P$NB"                                              0
state "1b empty box with colour SGR is idle"           "\e[39m$P$NB"                                        0
state "1c empty box, grey-coloured prompt is idle"     "\e[38;5;246m$P$NB\e[39m"                            0
state "2 dim suggestion is idle"                       "\e[39m$P$NB\e[2mok publish it when done\e[0m"       0
state "3 typed text is not idle"                       "$P$NB""hello"                                       1 "input not empty"
state "4 typed text then dim run is not idle"          "$P$NB""hel\e[2mlo world\e[0m"                       1 "input not empty"
state "5 dim closed by 22, then typed text, not idle"  "$P$NB\e[2msuggest\e[22mtyped"                       1 "input not empty"
state "6 spinner above the border is busy"             "$P$NB"                                              1 "busy" "✽ Computing… (40s"
state "7 bare ESC[m closes the dim run"                "$P$NB\e[2msuggest\e[mtyped"                         1 "input not empty"
state "8 38;5;2 colour index is not dim"               "$P$NB\e[38;5;2mgreen typed\e[0m"                    1 "input not empty"
state "9 colour-only grey text is NOT dropped"         "$P$NB\e[38;5;246mgrey typed\e[0m"                   1 "input not empty"

# type_verified's BOX_RAW extraction
draw "$P $(printf '%s' '/clear afp')"
read_box; rc=$?
if [ "$rc" = 0 ] && [ "$BOX_RAW" = "❯ /clear afp" ]; then check "BOX_RAW for '❯ /clear afp'" 0
else check "BOX_RAW for '❯ /clear afp'" 1 "rc=$rc raw='$BOX_RAW'"; fi

draw "\e[39m$P$NB/clear afp"
read_box; rc=$?
if [ "$rc" = 0 ] && [ "$BOX_RAW" = "❯${NBSP}/clear afp" ]; then check "BOX_RAW with NBSP and SGR" 0
else check "BOX_RAW with NBSP and SGR" 1 "rc=$rc raw='$BOX_RAW'"; fi

draw "$P$NB"
read_box; rc=$?
if [ "$rc" = 0 ] && [ "$BOX_RAW" = "❯" ]; then check "BOX_RAW empty box strips trailing NBSP" 0
else check "BOX_RAW empty box strips trailing NBSP" 1 "rc=$rc raw='$BOX_RAW'"; fi

# (a) dim non-suggestion content (paste placeholder) before the typed text
draw "$P \e[2m[Pasted text #1]\e[0m /clear afp"
read_box; rc=$?
if [ "$rc" = 0 ] && [ "$BOX_PLAIN_RAW" != "❯ /clear afp" ] && ! box_holds "/clear afp"; then
  check "(a) dim placeholder + text: box_holds false" 0
else check "(a) dim placeholder + text: box_holds false" 1 "rc=$rc plain='$BOX_PLAIN_RAW'"; fi

# (a2) type_verified returns 2 and sends no Enter (send-keys stubbed)
cat > "$TMPD/tmux-stub" <<EOF
#!/usr/bin/env bash
for a in "\$@"; do [ "\$a" = send-keys ] && { echo "\$*" >> "$TMPD/keys.log"; exit 0; }; done
exec tmux -u -L "$SOCK" "\$@"
EOF
chmod +x "$TMPD/tmux-stub"
: > "$TMPD/keys.log"
SAVED_TMUXC=("${TMUXC[@]}")
TMUXC=("$TMPD/tmux-stub")
type_verified "/clear afp"; rc=$?
TMUXC=("${SAVED_TMUXC[@]}")
if [ "$rc" = 2 ] && ! grep -q Enter "$TMPD/keys.log"; then check "(a2) type_verified returns 2, no Enter" 0
else check "(a2) type_verified returns 2, no Enter" 1 "rc=$rc"; fi

# (b) plain typed text, no dim
draw "$P /clear afp"
read_box
if box_holds "/clear afp"; then check "(b) '❯ /clear afp' box_holds true" 0
else check "(b) '❯ /clear afp' box_holds true" 1 "plain='$BOX_PLAIN_RAW'"; fi

# (c) after Enter, a box with only a dim suggestion counts as empty
draw "$P$NB\e[2mnext suggestion\e[0m"
read_box; rc=$?
if [ "$rc" = 0 ] && [ "$BOX_N" -eq 1 ] && [ -z "$BOX_TEXT" ]; then check "(c) dim suggestion after Enter counts as empty" 0
else check "(c) dim suggestion after Enter counts as empty" 1 "rc=$rc text='$BOX_TEXT'"; fi

if [ "$FAILS" -ne 0 ]; then echo "$FAILS FAILED"; exit 1; fi
echo "all passed"
