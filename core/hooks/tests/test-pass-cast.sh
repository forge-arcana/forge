#!/usr/bin/env bash
#
# Tests cast-deploy.sh --hooks / --verify-hooks for the handoff-* → pass-*
# rename: retired entries stripped from every event (exact filename match),
# hand-written entries untouched, old bodies left in place (unwired) this
# release, settings.json mode kept, idempotent, and verify fails while a
# retired hook is still wired but only warns on a leftover body. Fully sandboxed: HOME and the
# membrane live in a temp dir; the real membrane is never touched.
# Run:  bash core/hooks/tests/test-pass-cast.sh      (non-zero on failure)

HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.."
FORGE="$(readlink -f "$HERE/../..")"
CAST="$FORGE/core/scripts/cast-deploy.sh"
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
export HOME="$TMPD/home"
export FORGE_MEMBRANE="$TMPD/home/.claude"
export FORGE_AGENTS_DIR="$TMPD/home/.agents"
export FORGE_AGENTS_RULES_FILE="$TMPD/home/.agents/AGENTS.md"
export FORGE_PATH="$FORGE"
mkdir -p "$FORGE_MEMBRANE/hooks" "$FORGE_AGENTS_DIR"
S="$FORGE_MEMBRANE/settings.json"
H="$FORGE_MEMBRANE/hooks"

FAILS=0
check() { if [ "$2" = 0 ]; then echo "PASS  $1"; else echo "FAIL  $1  (${3:-})"; FAILS=$((FAILS + 1)); fi; }
skip() { echo "SKIP  $1  (${2:-})"; }
t() { local name="$1"; shift; if "$@" >/dev/null 2>&1; then check "$name" 0; else check "$name" 1 "$*"; fi; }

NOTIFY='{"matcher":"","hooks":[{"type":"command","command":"/opt/x/notify-blocked.sh notification","async":true}]}'
LOOKALIKE='{"matcher":"","hooks":[{"type":"command","command":"/opt/x/my-handoff-stop.sh.bak-runner"}]}'
BYPASS='{"matcher":"Bash","hooks":[{"type":"command","command":"/opt/x/bypass-stop.sh"}]}'
OLD_STOP="{\"matcher\":\"\",\"hooks\":[{\"type\":\"command\",\"command\":\"$H/handoff-stop.sh\"}]}"
OLD_START="{\"matcher\":\"clear\",\"hooks\":[{\"type\":\"command\",\"command\":\"$H/handoff-start.sh\"}]}"
jq -n --argjson n "$NOTIFY" --argjson l "$LOOKALIKE" --argjson b "$BYPASS" --argjson os "$OLD_STOP" --argjson ost "$OLD_START" '{
  permissions: {allow: ["Bash(ls:*)"], deny: []},
  env: {FOO: "bar"},
  hooks: {Stop: [$b, $os, $l], SessionStart: [$ost], Notification: [$n]}
}' > "$S"
chmod 600 "$S"
PERM_BEFORE="$(jq -S .permissions "$S")"
ENV_BEFORE="$(jq -S .env "$S")"
NOTIFY_BEFORE="$(jq -S .hooks.Notification "$S")"
printf '#!/bin/sh\n' > "$H/handoff-stop.sh"
printf '#!/bin/sh\n' > "$H/handoff-start.sh"

bash "$CAST" --hooks > "$TMPD/out1" 2>&1
check "--hooks exits 0" $? "$(tail -3 "$TMPD/out1")"
t "reports RETIRED removal from Stop" grep -q '| handoff-stop.sh | RETIRED | entry removed from Stop |' "$TMPD/out1"
t "reports RETIRED removal from SessionStart" grep -q '| handoff-start.sh | RETIRED | entry removed from SessionStart |' "$TMPD/out1"
grep -q 'body removed' "$TMPD/out1"; [ $? -ne 0 ]; check "does not report old bodies removed" $?
[ "$(stat -c %a "$S")" = 600 ]; check "settings.json seeded 0600 stays 0600" $? "$(stat -c %a "$S")"

t "no handoff-stop.sh entry anywhere" jq -e '[.hooks[][].hooks[].command | select(endswith("/handoff-stop.sh"))] | length == 0' "$S"
t "no handoff-start.sh entry anywhere" jq -e '[.hooks[][].hooks[].command | select(endswith("/handoff-start.sh"))] | length == 0' "$S"

if [ -f "$FORGE/core/hooks/pass-stop.sh" ]; then
  t "pass-stop.sh wired under Stop, matcher \"\"" jq -e --arg c "$H/pass-stop.sh" '[.hooks.Stop[] | select(.hooks[].command == $c) | .matcher] == [""]' "$S"
else skip "pass-stop.sh wiring" "forge source core/hooks/pass-stop.sh absent"; fi
if [ -f "$FORGE/core/hooks/pass-start.sh" ]; then
  t "pass-start.sh wired under SessionStart, matcher clear" jq -e --arg c "$H/pass-start.sh" '[.hooks.SessionStart[] | select(.hooks[].command == $c) | .matcher] == ["clear"]' "$S"
else skip "pass-start.sh wiring" "forge source core/hooks/pass-start.sh absent"; fi

[ "$(jq -S .hooks.Notification "$S")" = "$NOTIFY_BEFORE" ]; check "Notification entry byte-identical" $?
t "look-alike Stop entry kept" jq -e '[.hooks.Stop[].hooks[].command] | index("/opt/x/my-handoff-stop.sh.bak-runner") != null' "$S"
t "bypass-stop.sh Stop entry survives --hooks (exact-basename match)" jq -e '[.hooks.Stop[] | select(.hooks[].command == "/opt/x/bypass-stop.sh") | .matcher] == ["Bash"]' "$S"
[ "$(jq -S .permissions "$S")" = "$PERM_BEFORE" ]; check "permissions unchanged" $?
[ "$(jq -S .env "$S")" = "$ENV_BEFORE" ]; check "env unchanged" $?
[ -f "$H/handoff-stop.sh" ]; check "old handoff-stop.sh body left in place" $?
[ -f "$H/handoff-start.sh" ]; check "old handoff-start.sh body left in place" $?

bash "$CAST" --verify-hooks > "$TMPD/v1" 2>&1
check "--verify-hooks exits 0 after cast (bodies left in place)" $? "$(grep -E 'MISSING|DIFFERS|UNWIRED|STALE|RETIRED-WIRED' "$TMPD/v1")"
t "verify reports pass-stop.sh WIRED despite bypass-stop.sh" grep -q '| pass-stop.sh | WIRED | Stop matcher' "$TMPD/v1"
t "verify warns RETIRED-BODY for handoff-stop.sh" grep -q '| handoff-stop.sh | RETIRED-BODY | warning: .*(unused; left in place this release; removed next release)' "$TMPD/v1"
t "verify warns RETIRED-BODY for handoff-start.sh" grep -q '| handoff-start.sh | RETIRED-BODY |' "$TMPD/v1"

cp "$S" "$TMPD/s1"
bash "$CAST" --hooks > "$TMPD/out2" 2>&1
cmp -s "$S" "$TMPD/s1"; check "second --hooks leaves settings.json identical" $?
grep -q 'RETIRED' "$TMPD/out2"; [ $? -ne 0 ]; check "second --hooks reports no RETIRED work" $?
[ "$(stat -c %a "$S")" = 600 ]; check "settings.json still 0600 after second --hooks" $?

# Re-add an old entry (under a different event) → verify must fail.
jq --argjson os "$OLD_STOP" '.hooks.SubagentStop = [$os]' "$S" > "$TMPD/s2"
mv "$TMPD/s2" "$S"
bash "$CAST" --verify-hooks > "$TMPD/v2" 2>&1
[ $? -ne 0 ]; check "--verify-hooks fails with a retired entry re-added" $?
t "reports RETIRED-WIRED under SubagentStop" grep -q '| handoff-stop.sh | RETIRED-WIRED | still wired in settings.json under SubagentStop' "$TMPD/v2"

# Re-cast strips it again; the leftover body alone is only a warning.
bash "$CAST" --hooks > /dev/null 2>&1
[ -f "$H/handoff-start.sh" ]; check "re-cast leaves retired body in place" $?
bash "$CAST" --verify-hooks > "$TMPD/v3" 2>&1
check "--verify-hooks still exits 0 with an unwired retired body" $? "$(grep -E 'MISSING|DIFFERS|UNWIRED|STALE|RETIRED-WIRED' "$TMPD/v3")"
t "reports RETIRED-BODY warning" grep -q '| handoff-start.sh | RETIRED-BODY |' "$TMPD/v3"

echo
if [ "$FAILS" -eq 0 ]; then echo "all passed"; else echo "$FAILS failed"; exit 1; fi
