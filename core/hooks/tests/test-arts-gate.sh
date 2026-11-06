#!/usr/bin/env bash
#
# Tests for the commit gate (core/hooks/arts-gate.sh) and its recorder
# (core/scripts/forge-art-record.sh). Copies both into a temp dir, builds
# throwaway repos with an isolated HOME and GIT_CONFIG_GLOBAL, and feeds the
# hook PreToolUse payloads built with jq. Nothing outside the temp dir is
# touched.
# Run:  bash core/hooks/tests/test-arts-gate.sh      (non-zero on failure)

HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.."
HOOK_SRC="$(readlink -f "$HERE/arts-gate.sh")"
REC_SRC="$(readlink -f "$HERE/../scripts/forge-art-record.sh")"
TMPD="$(mktemp -d)"
trap 'chmod -R u+w "$TMPD" 2>/dev/null; rm -rf "$TMPD"' EXIT
unset FORGE_ALLOW_UNGATED_COMMIT FORGE_ARTS_SKIP GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
export HOME="$TMPD/home"
mkdir -p "$HOME"
export GIT_CONFIG_GLOBAL="$TMPD/gitconfig" GIT_CONFIG_SYSTEM=/dev/null
printf '[user]\n\tname = Test User\n\temail = test@example.invalid\n[init]\n\tdefaultBranch = main\n' > "$GIT_CONFIG_GLOBAL"

mkdir -p "$TMPD/bin" "$TMPD/elsewhere"
cp "$HOOK_SRC" "$TMPD/bin/arts-gate.sh"
cp "$REC_SRC" "$TMPD/bin/forge-art-record.sh"
HOOK="$TMPD/bin/arts-gate.sh"
REC="$TMPD/bin/forge-art-record.sh"

FAILS=0
check() { if [ "$2" = 0 ]; then echo "PASS  $1"; else echo "FAIL  $1  (${3:-})"; FAILS=$((FAILS + 1)); fi; }
# payload <command> <cwd> [agent_id] — the command goes in on stdin, so a
# 188 KB command does not hit the argument-length limit.
payload() {
  printf '%s' "$1" | jq -Rsc --arg d "$2" --arg a "${3:-}" \
    '{session_id:"s",hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:.},cwd:$d} + (if $a == "" then {} else {agent_id:$a} end)'
}
hook() { OUT="$(printf '%s' "$1" | bash "$HOOK" 2>&1)"; RC=$?; }
denied() { [ "$RC" = 0 ] && printf '%s' "$OUT" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1 && echo 0 || echo 1; }
allowed() { [ "$RC" = 0 ] && [ -z "$OUT" ] && echo 0 || echo 1; }
expect_deny()  { hook "$(payload "$1" "$2" "${4:-}")"; check "$3" "$(denied)" "rc=$RC out=$OUT"; }
expect_allow() { hook "$(payload "$1" "$2" "${4:-}")"; check "$3" "$(allowed)" "rc=$RC out=$OUT"; }
new_repo() { mkdir -p "$1"; git -C "$1" init -q; echo base > "$1/README.md"; git -C "$1" add README.md; git -C "$1" commit -q -m base; }
stage() { local r="$1"; shift; local f; for f in "$@"; do mkdir -p "$(dirname "$r/$f")"; echo "x $RANDOM" >> "$r/$f"; git -C "$r" add "$f"; done; }
# perf <label> <payload> <expect: allow|deny>: verdict plus wall time < 300 ms
perf() {
  local t0 ms v i best=999999
  for i in 1 2 3; do                  # best of 3: a loaded box adds noise, not cost
    t0=$(date +%s%N); hook "$2"; ms=$(( ($(date +%s%N) - t0) / 1000000 ))
    [ "$ms" -lt "$best" ] && best=$ms
  done
  ms=$best
  if [ "$3" = deny ]; then v="$(denied)"; else v="$(allowed)"; fi
  check "perf: $1 → $3 in under 300 ms (${ms} ms)" "$([ "$v" = 0 ] && [ "$ms" -lt 300 ] && echo 0 || echo 1)" "rc=$RC out=${OUT:0:200}"
}

# --- hot path never needs jq -------------------------------------------------
NOJQ="$TMPD/nojq"; mkdir -p "$NOJQ"
ln -s "$(command -v bash)" "$NOJQ/bash"
PATH="$NOJQ" command -v jq >/dev/null 2>&1; check "nojq: jq is absent from the trimmed PATH" "$([ $? != 0 ] && echo 0 || echo 1)"
OUT="$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"ls -la"},"cwd":"/"}' | env -i PATH="$NOJQ" HOME="$HOME" "$NOJQ/bash" "$HOOK" 2>&1)"; RC=$?
check "nojq: non-commit command exits 0 with empty output" "$(allowed)" "rc=$RC out=$OUT"
OUT="$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git commit -m x"},"cwd":"/"}' | env -i PATH="$NOJQ" HOME="$HOME" "$NOJQ/bash" "$HOOK" 2>&1)"; RC=$?
check "nojq: commit command with no jq fails open" "$(allowed)" "rc=$RC out=$OUT"

# --- core gate -----------------------------------------------------------------
R="$TMPD/repo"; new_repo "$R"
stage "$R" src/a.ts src/b.py
expect_deny 'git commit -m "add two"' "$R" "deny: 2 staged code files, no record"
RSN="$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null)"
check "deny: reason present and names repo and count" "$([[ "$RSN" == *"repo has 2 changed source files"* ]] && echo 0 || echo 1)" "$OUT"
check "deny: reason present and does not mention the recorder" "$([ -n "$RSN" ] && [[ "$RSN" != *forge-art-record* ]] && echo 0 || echo 1)" "$RSN"
expect_deny 'git commit -m "add two"' "$R" "deny: subagent call (agent_id) gated like the parent" "agent-123"

bash "$REC" poke "$R"
grep -qx "head=$(git -C "$R" rev-parse HEAD)" "$R/.git/forge-arts/poke"; check "record: head= line written" $? "$(cat "$R/.git/forge-arts/poke" 2>&1)"
grep -qE '^time=[0-9]{4}-[0-9]{2}-[0-9]{2}T' "$R/.git/forge-arts/poke"; check "record: time= line written" $?
expect_allow 'git commit -m "add two"' "$R" "allow: fresh poke record at HEAD"

git -C "$R" commit -q -m "add two"
stage "$R" src/c.go src/d.rs
expect_deny 'git commit -m next' "$R" "deny: record from an older HEAD"

git -C "$R" reset -q
stage "$R" docs/a.md docs/b.html docs/c.json
expect_allow 'git commit -m docs' "$R" "allow: 3 staged md/html/json files"
git -C "$R" reset -q
stage "$R" src/one.ts docs/x.md docs/y.md
expect_allow 'git commit -m mixed' "$R" "allow: 1 code + 2 md"
git -C "$R" reset -q
stage "$R" src/e.ts src/f.ts

expect_deny "git -C $R commit -m x" "$TMPD/elsewhere" "deny: git -C <repo> commit from another cwd"
expect_deny "git -C repo commit -m x" "$TMPD" "deny: relative -C resolved against cwd"
expect_deny "git -c core.editor=true --no-pager commit -m x" "$R" "deny: -c and --no-pager before commit"
expect_deny "git commit -m \"\$(cat <<'EOF'
Don't \"chain\"; really | commit twice (no)
EOF
)\"" "$R" "deny: heredoc message is collapsed, not read as chaining"
expect_deny "git commit -F - <<'EOF'
msg; with | stuff
EOF" "$R" "deny: -F - heredoc on stdin"
expect_deny "git commit -m \"\$(cat <<'END-MSG'
dash delimiter
END-MSG
)\"" "$R" "deny: dash in heredoc delimiter"
expect_deny 'git commit -m "fix; tidy | commit two"' "$R" "deny: operators inside a quoted message"
expect_deny 'git commit -m x 2>&1' "$R" "deny: trailing 2>&1 redirect"
expect_deny 'git commit -qm x' "$R" "deny: combined -qm"
expect_deny "git commit -m 'it'\\''s \"fine\" & done' --no-verify" "$R" "deny: mixed quoting, escaped quote, & in message"
expect_allow "git commit -m 'unterminated" "$R" "allow: unterminated quote (fail open)"
SP="$TMPD/with space"; new_repo "$SP"; stage "$SP" a.ts b.ts
expect_deny "git -C \"$SP\" commit -m x" "$TMPD/elsewhere" "deny: quoted -C path with a space"
expect_deny "
  git commit -m x" "$R" "deny: leading whitespace and newlines trimmed"

# --- commit is the FIRST simple command: judged, the rest ignored -------------
expect_deny 'git commit -m x 2>&1 | tail -5' "$R" "deny: commit piped to tail"
expect_deny 'git commit -m x && git push' "$R" "deny: commit && push"
expect_deny "git commit -m \"\$(cat <<'EOF'
msg
EOF
)\" && git push" "$R" "deny: heredoc commit && push"
expect_deny 'git commit -m x || true' "$R" "deny: commit || true"
expect_deny 'git commit -m x # note' "$R" "deny: trailing comment"
expect_deny 'git commit -m x;' "$R" "deny: trailing ;"
expect_deny 'git commit -m x; git push' "$R" "deny: commit; push"
expect_deny 'git commit -m "x" \
  --no-verify' "$R" "deny: backslash-newline continuation"
expect_deny 'git commit -m x#y' "$R" "deny: # inside a word is not a comment"
expect_allow 'git add . && git commit -m x' "$R" "allow: commit after another command (fail open)"
expect_allow 'git status; git commit -m x' "$R" "allow: commit as second command (fail open)"

# --- wrappers and env prefixes -----------------------------------------------
expect_deny 'command git commit -m x' "$R" "deny: command wrapper"
expect_deny 'time git commit -m x' "$R" "deny: time wrapper"
expect_deny 'nice -n 5 git commit -m x' "$R" "deny: nice -n wrapper"
expect_deny 'timeout 30 git commit -m x' "$R" "deny: timeout wrapper"
expect_deny 'env FOO=1 git commit -m x' "$R" "deny: env with VAR=val only"
expect_allow 'env -i git commit -m x' "$R" "allow: env with options (fail open)"
expect_allow 'GIT_DIR=.git git commit -m x' "$R" "allow: GIT_DIR prefix (fail open)"
expect_allow 'GIT_INDEX_FILE=/tmp/idx git commit -m x' "$R" "allow: GIT_INDEX_FILE prefix (fail open)"
expect_allow 'GIT_WORK_TREE=. git commit -m x' "$R" "allow: GIT_WORK_TREE prefix (fail open)"
expect_allow 'GIT_CONFIG_GLOBAL=/tmp/x git commit -m x' "$R" "allow: GIT_CONFIG_GLOBAL prefix (fail open)"
expect_deny 'GIT_EDITOR=true git commit -m x' "$R" "deny: GIT_EDITOR prefix is skipped, commit still judged"
LONGF="$(printf 'q%.0s' $(seq 1 100))"
expect_allow "git commit -$LONGF -m x" "$R" "allow: 100-char short-flag word (fail open)"
OUT="$(payload 'git -C ~ commit -m x' "$R" | env -u HOME bash "$HOOK" 2>&1)"; RC=$?
check "allow: HOME unset with git -C ~ exits 0 without crash" "$(allowed)" "rc=$RC out=$OUT"
HR="$HOME/proj"; new_repo "$HR"; stage "$HR" a.ts b.ts
expect_deny 'git -C $HOME/proj commit -m x' "$TMPD/elsewhere" "deny: -C \$HOME/... expanded"
expect_deny 'git -C "${HOME}/proj" commit -m x' "$TMPD/elsewhere" "deny: -C \${HOME}/... expanded"
expect_deny 'git -C "$PWD" commit -m x' "$R" "deny: -C \$PWD expanded to cwd"
expect_allow 'git -C "$OTHER/x" commit -m x' "$R" "allow: -C with another variable (fail open)"

# --- status-style commits never create a commit --------------------------------
for f in --short --sh --porcelain --po --long --null -z -h --help; do
  expect_allow "git commit $f" "$R" "allow: git commit $f"
done

# --- escape hatches and fail-open -------------------------------------------------
expect_allow "FORGE_ARTS_SKIP='docs reshuffle' git commit -m x" "$R" "allow: quoted FORGE_ARTS_SKIP reason"
expect_allow "FORGE_ARTS_SKIP=hotfix git commit -m x" "$R" "allow: bare FORGE_ARTS_SKIP reason"
expect_deny  "FORGE_ARTS_SKIP= git commit -m x" "$R" "deny: empty FORGE_ARTS_SKIP is not a skip"
expect_deny  "FORGE_ARTS_SKIP='' git commit -m x" "$R" "deny: empty quoted FORGE_ARTS_SKIP is not a skip"
OUT="$(payload 'git commit -m x' "$R" | FORGE_ALLOW_UNGATED_COMMIT=1 bash "$HOOK" 2>&1)"; RC=$?
check "allow: FORGE_ALLOW_UNGATED_COMMIT=1 in the hook env" "$(allowed)" "rc=$RC out=$OUT"

hook 'not json at all, commit'; check "allow: malformed payload" "$(allowed)" "rc=$RC out=$OUT"
hook '{"tool_name":"Bash","tool_input":{"command":"git commit -m x"}}'; check "allow: payload without cwd" "$(allowed)" "rc=$RC out=$OUT"
expect_allow 'git commit -m x' "$TMPD/elsewhere" "allow: non-repo cwd"
expect_allow 'git commit -m "$(cat msg.txt)"' "$R" "allow: other command substitution (fail open)"
expect_allow 'git log --grep commit' "$R" "allow: non-commit git subcommand"
expect_allow 'git commit -m x -- src/e.ts src/f.ts' "$R" "allow: explicit pathspecs (fail open)"
expect_allow 'git commit -m x src/e.ts' "$R" "allow: bare pathspec (fail open)"
expect_allow 'git commit --dry-run -m x' "$R" "allow: dry run"
expect_allow 'git --git-dir=.git commit -m x' "$R" "allow: --git-dir (fail open)"
expect_allow 'echo commit' "$R" "allow: non-git command mentioning commit"
hook "$(jq -nc --arg d "$R" '{tool_name:"Read",tool_input:{file_path:"commit.md"},cwd:$d}')"; check "allow: non-Bash tool" "$(allowed)" "rc=$RC out=$OUT"

git -C "$R" rev-parse HEAD > "$R/.git/MERGE_HEAD"
expect_allow 'git commit -m merge' "$R" "allow: merge in progress"
rm -f "$R/.git/MERGE_HEAD"

# --- performance: adversarial payloads ---------------------------------------
rep() { local s="$1" n="$2" out=""; out="$(printf "%${n}s" "")"; printf '%s' "${out// /$s}"; }
perf "15 KB single-line message (over the 8 KB scanner cap)" "$(payload "git commit -m \"$(rep a 15000) é\"" "$R")" allow
perf "many <<ident markers (60 KB)" "$(payload "git commit -m x $(rep '<<EOF1 ' 8000)" "$R")" allow
perf "many <<ident markers with newlines (60 KB)" "$(payload "git commit -m x <<A
$(rep $'<<B\n' 12000)" "$R")" allow
perf "many <<ident markers under the scanner cap" "$(payload "git commit -m x $(rep '<<E ' 2000)" "$R")" allow
perf "15k trailing spaces" "$(payload "git commit -m x$(rep ' ' 15000)" "$R")" allow
perf "8k trailing spaces under the cap" "$(payload "git commit -m x$(rep ' ' 8000)" "$R")" deny
perf "10k \$ in a message" "$(payload "git commit -m \"$(rep '$' 10000)\"" "$R")" allow
perf "8k \$ under the cap" "$(payload "git commit -m \"$(rep '$' 8000)\"" "$R")" deny
perf "5k '' pairs" "$(payload "git commit -m x $(rep "''" 5000)" "$R")" allow
perf "4k '' pairs under the cap (step budget, fails open)" "$(payload "git commit -m x$(rep "''" 4000)" "$R")" allow
check "perf: 188 KB python payload really is over 64 KB" "$([ "$(payload "python3 -c \"$(rep $'x = a << b  # commit\n' 9000)\"" "$R" | wc -c)" -gt 65536 ] && echo 0 || echo 1)"
PY="python3 -c \"$(rep $'x = a << b  # commit\n' 9000)\""
perf "188 KB python -c payload" "$(payload "$PY" "$R")" allow
perf "45 KB python -c payload (under the 64 KB cap)" "$(payload "${PY:0:42000}" "$R")" allow
perf "non-commit hot path" "$(payload 'ls -la' "$R")" allow

# --- commit -a with nothing staged ------------------------------------------
git -C "$R" commit -q -m "e f"
echo more >> "$R/src/e.ts"; echo more >> "$R/src/f.ts"
expect_deny 'git commit -am x' "$R" "deny: -am with 2 modified tracked code files"
expect_deny 'git commit --all -m x' "$R" "deny: --all"
expect_allow 'git commit -m x' "$R" "allow: same tree without -a (nothing staged)"
expect_allow 'git commit --amend --no-edit' "$R" "allow: --amend is not -a (nothing staged)"
git -C "$R" checkout -q -- .

# --- renames ---------------------------------------------------------------------
N="$TMPD/ren"; new_repo "$N"
mkdir -p "$N/src"
for f in a b; do seq 1 40 | sed "s/^/line $f /" > "$N/src/$f.ts"; done
git -C "$N" add src; git -C "$N" commit -q -m two
git -C "$N" mv src/a.ts src/a2.ts; git -C "$N" mv src/b.ts src/b2.ts
expect_allow 'git commit -m rename' "$N" "allow: two pure renames (R100) do not count"
echo "edit" >> "$N/src/a2.ts"; echo "edit" >> "$N/src/b2.ts"; git -C "$N" add src
expect_deny 'git commit -m rename' "$N" "deny: two renames with edits count"

# --- worktrees: records are per worktree ------------------------------------------
W="$TMPD/wtbase"; new_repo "$W"
git -C "$W" worktree add -q "$TMPD/wt1" -b one 2>/dev/null
git -C "$W" worktree add -q "$TMPD/wt2" -b two 2>/dev/null
echo b > "$TMPD/wt2/b.md"; git -C "$TMPD/wt2" add b.md; git -C "$TMPD/wt2" commit -q -m wt2-head
stage "$TMPD/wt1" w/a.ts w/b.ts
stage "$TMPD/wt2" w/a.ts w/b.ts
bash "$REC" pound "$TMPD/wt2"
WT2REC="$(git -C "$TMPD/wt2" rev-parse --path-format=absolute --git-path forge-arts)/pound"
check "record: linked worktree writes under .git/worktrees/<name>" "$([[ "$WT2REC" == */.git/worktrees/wt2/forge-arts/pound ]] && [ -f "$WT2REC" ] && echo 0 || echo 1)" "$WT2REC"
check "record: linked worktree does not write the main dir" "$([ ! -e "$W/.git/forge-arts/pound" ] && echo 0 || echo 1)"
expect_allow 'git commit -m wt' "$TMPD/wt2" "allow: wt2 with its own fresh record"
expect_deny 'git commit -m wt' "$TMPD/wt1" "deny: wt2's record does not unlock wt1"
WT2BEFORE="$(cat "$WT2REC")"
bash "$REC" pound "$TMPD/wt1"
check "record: wt1's record does not overwrite wt2's" "$([ "$(cat "$WT2REC")" = "$WT2BEFORE" ] && echo 0 || echo 1)"
expect_allow 'git commit -m wt' "$TMPD/wt1" "allow: wt1 with its own fresh record"

# --- check mode judges the staged set -------------------------------------------
C="$TMPD/check"; new_repo "$C"
mkdir -p "$C/newdir"; echo a > "$C/newdir/a.ts"; echo b > "$C/newdir/b.ts"
OUT="$(bash "$HOOK" --check "$C" 2>&1)"; RC=$?
check "check: untracked only → ok with a note, never blocked" "$([ $RC = 0 ] && [ "$(printf '%s\n' "$OUT" | head -1)" = "arts-gate: ok" ] && [[ "$OUT" == *"arts-gate: note — 2 untracked source file(s)"* ]] && echo 0 || echo 1)" "rc=$RC out=$OUT"
git -C "$C" add newdir; git -C "$C" commit -q -m two
echo m >> "$C/newdir/a.ts"; echo m >> "$C/newdir/b.ts"
OUT="$(bash "$HOOK" --check "$C" 2>&1)"; RC=$?
check "check: unstaged modifications only → ok" "$([ $RC = 0 ] && [ "$OUT" = "arts-gate: ok" ] && echo 0 || echo 1)" "rc=$RC out=$OUT"
git -C "$C" add newdir
OUT="$(bash "$HOOK" --check "$C" 2>&1)"; RC=$?
check "check: 2 staged code files, no record → blocked, exit 1" "$([ $RC = 1 ] && [[ "$OUT" == "arts-gate: blocked — "* ]] && echo 0 || echo 1)" "rc=$RC out=$OUT"
hook "$(payload 'git commit -m x' "$C")"; check "check: hook agrees (deny) on the same state" "$(denied)" "rc=$RC out=$OUT"
bash "$REC" preen "$C"
OUT="$(bash "$HOOK" --check "$C" 2>&1)"; RC=$?
check "check: ok after a fresh record" "$([ $RC = 0 ] && [ "$OUT" = "arts-gate: ok" ] && echo 0 || echo 1)" "rc=$RC out=$OUT"
OUT="$(bash "$HOOK" --check "$TMPD/elsewhere" 2>&1)"; RC=$?
check "check: non-repo path is ok" "$([ $RC = 0 ] && [ "$OUT" = "arts-gate: ok" ] && echo 0 || echo 1)" "rc=$RC out=$OUT"

# --- initial commit (no HEAD) -----------------------------------------------
I="$TMPD/init"; mkdir -p "$I"; git -C "$I" init -q
stage "$I" a.py b.py
expect_deny 'git commit -m first' "$I" "deny: initial commit, no record"
bash "$REC" poke "$I"
grep -qx "head=none" "$I/.git/forge-arts/poke"; check "record: head=none before the first commit" $?
expect_allow 'git commit -m first' "$I" "allow: initial commit with head=none record"

# --- recorder edge cases ------------------------------------------------------
bash "$REC" bogus "$I" 2>/dev/null; check "record: unknown art exits 2" "$([ $? = 2 ] && echo 0 || echo 1)"
OUT="$(bash "$REC" poke "$TMPD/elsewhere" 2>&1)"; RC=$?
check "record: silent exit 0 outside a repo" "$([ $RC = 0 ] && [ -z "$OUT" ] && echo 0 || echo 1)" "rc=$RC out=$OUT"
ls -A "$I/.git/forge-arts" | grep -q '^\.tmp' ; check "record: no temp files left behind" "$([ $? != 0 ] && echo 0 || echo 1)"
F="$TMPD/fileblock"; new_repo "$F"; echo x > "$F/.git/forge-arts"
ERR="$(bash "$REC" poke "$F" 2>&1 >/dev/null)"; RC=$?
check "record: forge-arts is a file → one-line warning, exit 0" "$([ $RC = 0 ] && [[ "$ERR" == forge-art-record:* ]] && [ "$(printf '%s\n' "$ERR" | wc -l)" = 1 ] && echo 0 || echo 1)" "rc=$RC err=$ERR"
U="$TMPD/unwritable"; new_repo "$U"; mkdir -p "$U/.git/forge-arts"; chmod 555 "$U/.git/forge-arts"
ERR="$(bash "$REC" poke "$U" 2>&1 >/dev/null)"; RC=$?
check "record: unwritable dir → one-line warning, exit 0" "$([ $RC = 0 ] && [[ "$ERR" == forge-art-record:* ]] && echo 0 || echo 1)" "rc=$RC err=$ERR"
chmod 755 "$U/.git/forge-arts"

echo
if [ "$FAILS" = 0 ]; then echo "ALL PASS"; else echo "$FAILS FAILED"; exit 1; fi
