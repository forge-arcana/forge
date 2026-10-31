#!/usr/bin/env bash
#
# Test for handoff-start.sh: the status-block instruction is injected, and a
# note without a "Done last session" section still injects. Runs the hook under
# a fake `claude` process (a copy of bash) in a temp HANDOFF_DIR; no tmux, no
# real session. Run:  bash core/hooks/tests/test-handoff-start.sh
HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.."
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
command -v jq >/dev/null 2>&1 || { echo "jq not found"; exit 1; }
cp "$(command -v bash)" "$TMPD/claude"
FAILS=0
SESS="$(printf "n%.0s" $(seq 1 64))"   # longest valid name (64 chars)
export SESS
check() { if [ "$2" = 0 ]; then echo "PASS  $1"; else echo "FAIL  $1  (${3:-})"; FAILS=$((FAILS + 1)); fi; }

# run_hook NOTEFILE -> prints the hook's stdout; HANDOFF_DIR is fresh per call
run_hook() {
  export HANDOFF_DIR="$(mktemp -d "$TMPD/h.XXXXXX")" TMUX_PANE="%7"
  printf "%s" "$HANDOFF_DIR" > "$TMPD/lastdir"   # run_hook runs in a $(...) subshell
  mkdir -p "$HANDOFF_DIR/state"
  cp "$1" "$HANDOFF_DIR/pane-7.md"
  [ -z "${SEED:-}" ] || "$SEED" "$HANDOFF_DIR"
  # inside the fake claude: write the token naming its own pid, then run the hook
  "$TMPD/claude" -c '
    printf "epoch=%s\nid=1.1\nname=%s\nclaude_pid=%s\n" "$(date +%s)" "$SESS" "$$" > "$HANDOFF_DIR/state/pane-7.clearing"
    printf "{\"source\":\"clear\",\"transcript_path\":\"/nonexistent/t.jsonl\"}" | bash "'"$HERE"'/handoff-start.sh"'
}

printf '# Handoff - sess - d\n## Done last session\n- shipped X\n## Next task\nDo Y\n' > "$TMPD/new.md"
printf '# Handoff - sess - d\n## Next task\nDo Y (old note, no done section)\n' > "$TMPD/old.md"

out="$(run_hook "$TMPD/new.md")"
ctx="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null)"
[[ "$ctx" == *'Open your first reply with a brief status block'* && "$ctx" == *'Last session (per handoff note)'* && "$ctx" == *'run CronList'* && "$ctx" == *'history, not approval to act'* && "$ctx" == *'Last session'* && "$ctx" == *'Done last session'* && "$ctx" == *'Next task'* && "$ctx" == *'Open items'* && "$ctx" == *'shipped X'* ]] \
  && check "1 new note: status-block instruction and note injected" 0 || check "1 new note: status-block instruction and note injected" 1 "$out"

out="$(run_hook "$TMPD/old.md")"
ctx="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null)"
[[ "$ctx" == *'old note, no done section'* && "$ctx" == *'status block'* ]] \
  && check "2 note without 'Done last session' still injects" 0 || check "2 note without 'Done last session' still injects" 1 "$out"
[ -f "$(cat "$TMPD/lastdir")/state/pane-7.injected" ] && check "3 injected marker written" 0 || check "3 injected marker written" 1

# Budget: the hook caps the note at min(9000, 9999 - pre - 2 - 12), so a
# 9000-char note is never truncated iff 9999 - pre - 14 >= 9000.
pre_len="$(printf '%s' "$ctx" | awk 'BEGIN{RS="\n\n"} NR==1{print length($0)}')"
[ $((9999 - ${pre_len:-9999} - 14)) -ge 9000 ] && check "4 preamble with a 64-char name ($pre_len chars) leaves the full 9000-char note budget" 0 || check "4 preamble leaves the full 9000-char note budget" 1 "pre=$pre_len"

# End to end: a 9000-char note comes through untruncated.
{ printf '# H\n## Done last session\n- x\n## Next task\n'; head -c 8958 /dev/zero | tr '\0' 'a'; } > "$TMPD/big.md"
big_n="$(wc -m < "$TMPD/big.md")"
out="$(run_hook "$TMPD/big.md")"
ctx="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null)"
[[ "$ctx" != *'[truncated]'* && "$big_n" -le 9000 ]] && check "5 near-cap note is not truncated ($big_n chars)" 0 || check "5 near-cap note is not truncated" 1 "n=$big_n"

# Archive pruning: age rule (any pane, by name timestamp) and per-pane cap.
seed_archives() {
  local a="$1/archive" d40 d10 i
  mkdir -p "$a"
  d40="$(date -d '-40 days' +%Y%m%d-%H%M%S)"; d10="$(date -d '-10 days' +%Y%m%d-%H%M%S)"
  : > "$a/old-pane-3-$d40.md"          # 40 days, other pane: deleted
  : > "$a/old-pane-3-$d40-123.md"      # same with -n suffix: deleted
  : > "$a/recent-pane-3-$d10.md"       # 10 days, other pane: kept
  : > "$a/notes.md"                    # non-matching: kept
  : > "$a/x-pane-3-garbage.md"         # non-matching: kept
  touch -d '-90 days' "$a/notes.md" "$a/x-pane-3-garbage.md" "$a/recent-pane-3-$d10.md"
  for i in $(seq 1 24); do : > "$a/cap-pane-7-$(date -d "-${i} hours" +%Y%m%d-%H%M%S).md"; done
}
SEED=seed_archives out="$(run_hook "$TMPD/new.md")"
AD="$(cat "$TMPD/lastdir")/archive"
ls "$AD"/old-pane-3-* >/dev/null 2>&1 && check "6 40-day-old archive of another pane deleted" 1 "$(ls "$AD")" || check "6 40-day-old archive of another pane deleted" 0
ls "$AD"/recent-pane-3-* >/dev/null 2>&1 && check "7 10-day-old archive of another pane kept" 0 || check "7 10-day-old archive of another pane kept" 1
[ -f "$AD/notes.md" ] && [ -f "$AD/x-pane-3-garbage.md" ] && check "8 non-matching files kept" 0 || check "8 non-matching files kept" 1 "$(ls "$AD")"
cnt="$(ls "$AD" | grep -c -- '-pane-7-')"
[ "$cnt" = 20 ] && check "9 per-pane cap keeps newest 20 ($cnt)" 0 || check "9 per-pane cap keeps newest 20" 1 "cnt=$cnt"
grep -q 'older than 30 days' "$(cat "$TMPD/lastdir")/state/handoff.log" && check "10 age deletion logged" 0 || check "10 age deletion logged" 1

if [ "$FAILS" -ne 0 ]; then echo "$FAILS FAILED"; exit 1; fi
echo "all passed"
