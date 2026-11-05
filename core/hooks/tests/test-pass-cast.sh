#!/usr/bin/env bash
#
# Tests cast-deploy.sh --hooks / --verify-hooks / --retire-skills for the
# handoff-* → pass-* rename: retired entries stripped from every event (exact
# filename match), retired bodies unlinked with one RETIRED row each,
# hand-written entries and look-alike files untouched, settings.json mode kept,
# idempotent, verify fails while a retired hook is still wired but only warns on
# a leftover body; the retired handoff skill is removed from both stores only
# when unmodified (a modified dir is kept and reported). Fully sandboxed: HOME
# and the membrane live in a temp dir; the real membrane is never touched.
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
printf '#!/bin/sh\n' > "$H/my-handoff-stop.sh.bak-runner"
printf '#!/bin/sh\n' > "$H/bypass-stop.sh"

bash "$CAST" --hooks > "$TMPD/out1" 2>&1
check "--hooks exits 0" $? "$(tail -3 "$TMPD/out1")"
t "reports RETIRED removal from Stop" grep -q '| handoff-stop.sh | RETIRED | entry removed from Stop |' "$TMPD/out1"
t "reports RETIRED removal from SessionStart" grep -q '| handoff-start.sh | RETIRED | entry removed from SessionStart |' "$TMPD/out1"
t "reports handoff-stop.sh body removed" grep -q '| handoff-stop.sh | RETIRED | body removed from ' "$TMPD/out1"
t "reports handoff-start.sh body removed" grep -q '| handoff-start.sh | RETIRED | body removed from ' "$TMPD/out1"
[ "$(grep -c '| RETIRED | body removed' "$TMPD/out1")" = 2 ]; check "exactly one body-removed row per retired body" $?
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
[ ! -e "$H/handoff-stop.sh" ] && [ ! -L "$H/handoff-stop.sh" ]; check "old handoff-stop.sh body unlinked" $?
[ ! -e "$H/handoff-start.sh" ] && [ ! -L "$H/handoff-start.sh" ]; check "old handoff-start.sh body unlinked" $?
[ -f "$H/my-handoff-stop.sh.bak-runner" ]; check "look-alike hook file untouched" $?
[ -f "$H/bypass-stop.sh" ]; check "bypass-stop.sh file untouched" $?

bash "$CAST" --verify-hooks > "$TMPD/v1" 2>&1
check "--verify-hooks exits 0 after cast (bodies unlinked)" $? "$(grep -E 'MISSING|DIFFERS|UNWIRED|STALE|RETIRED-WIRED' "$TMPD/v1")"
t "verify reports pass-stop.sh WIRED despite bypass-stop.sh" grep -q '| pass-stop.sh | WIRED | Stop matcher' "$TMPD/v1"
grep -q 'RETIRED' "$TMPD/v1"; [ $? -ne 0 ]; check "verify reports no RETIRED row once the bodies are gone" $?

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

# Re-cast strips the entry again and reports it; nothing to unlink (already gone).
bash "$CAST" --hooks > "$TMPD/out3" 2>&1
t "re-cast strips the re-added entry" grep -q '| handoff-stop.sh | RETIRED | entry removed from SubagentStop |' "$TMPD/out3"
grep -q 'body removed' "$TMPD/out3"; [ $? -ne 0 ]; check "re-cast reports no body removal (already gone)" $?

# A leftover body that nothing runs is only a warning; the next --hooks unlinks it.
printf '#!/bin/sh\n' > "$H/handoff-start.sh"
bash "$CAST" --verify-hooks > "$TMPD/v3" 2>&1
check "--verify-hooks still exits 0 with an unwired retired body" $? "$(grep -E 'MISSING|DIFFERS|UNWIRED|STALE|RETIRED-WIRED' "$TMPD/v3")"
t "reports RETIRED-BODY warning pointing at the next cast" grep -q '| handoff-start.sh | RETIRED-BODY | warning: .*the next cast-deploy.sh --hooks removes it' "$TMPD/v3"
grep -q 'handoff-stop.sh | RETIRED-BODY' "$TMPD/v3"; [ $? -ne 0 ]; check "no RETIRED-BODY row for the absent body" $?
bash "$CAST" --hooks > "$TMPD/out4" 2>&1
t "next --hooks reports the leftover body removed" grep -q '| handoff-start.sh | RETIRED | body removed from ' "$TMPD/out4"
[ ! -e "$H/handoff-start.sh" ]; check "next --hooks unlinked the leftover body" $?
[ "$(grep -c 'body removed' "$TMPD/out4")" = 1 ]; check "only the body actually present is reported" $?

# A symlinked retired body is unlinked itself; its target is never followed.
printf 'keep\n' > "$TMPD/target.sh"
ln -s "$TMPD/target.sh" "$H/handoff-stop.sh"
bash "$CAST" --hooks > /dev/null 2>&1
[ ! -L "$H/handoff-stop.sh" ] && [ -f "$TMPD/target.sh" ]; check "symlinked body removed, target untouched" $?

# --- Retired skill: removed from both stores only when unmodified ---
SK="$FORGE_MEMBRANE/skills/handoff"
NS="$FORGE_AGENTS_DIR/skills/handoff"
RETIRED_ROW="$(grep -m1 '^  "handoff|' "$CAST")"
SKILL_SHA="$(printf '%s' "$RETIRED_ROW" | sed -n 's/.*SKILL.md:\([0-9a-f]\{64\}\).*/\1/p')"
t "retired-skill row carries a sha256 for SKILL.md" test -n "$SKILL_SHA"
bash "$CAST" --list-retired-skills > "$TMPD/lr" 2>&1
[ "$(cat "$TMPD/lr")" = handoff ]; check "--list-retired-skills prints handoff" $?
# mk_shim <dir> <model-line>: recreate the retired shim exactly as the previous cast deployed it
# (SKILL.md carried the injected `model:` line, which the guard ignores).
mk_shim() {
  mkdir -p "$1"
  { printf '%s\n' '---' 'name: handoff'
    [ -n "$2" ] && printf '%s\n' "$2"
    cat <<'SKILLEOF'
description: "Deprecated alias of /pass (renamed 2026-11-02); kept one release so running sessions keep working. Use /pass."
---
<!-- model: haiku | alias; no fan-out -->

# /handoff — deprecated alias of /pass

Run the same thing via `bash "$HOME/.claude/skills/handoff/handoff.sh" <args>`, exactly as `/pass` documents (same arguments, same note template, same rules). `on` is `auto`, `off` is `manual`. Prefer `/pass`; this alias is removed next release.
SKILLEOF
  } > "$1/SKILL.md"
  cat > "$1/handoff.sh" <<'SHEOF'
#!/usr/bin/env bash
# handoff.sh - compatibility shim for the /handoff -> /pass rename (2026-11-02).
#
# Sessions started before the rename still follow the old rule: "run
# handoff.sh status; if it reports on, run /handoff". This shim forwards every
# call to ../pass/pass.sh, maps on->auto and off->manual, and rewrites the
# status output back (auto->on, manual->off) so those sessions keep working.
# Removed next release.
set -u

src="$(readlink -f "${BASH_SOURCE[0]}")"
dir="$(dirname "$src")"
target="$dir/../pass/pass.sh"

if [ ! -f "$target" ]; then
  echo "handoff: /pass is not installed" >&2
  exit 1
fi

cmd="${1:-}"
[ "$#" -gt 0 ] && shift

case "$cmd" in
  on) cmd=auto ;;
  off) cmd=manual ;;
esac

if [ "$cmd" = status ]; then
  out="$(bash "$target" status "$@")"
  rc=$?
  if [ -n "$out" ]; then
    printf '%s\n' "$out" | sed -E 's/^auto( |$)/on\1/; s/^manual( |$)/off\1/'
  fi
  exit "$rc"
fi

exec bash "$target" "$cmd" "$@"
SHEOF
  chmod +x "$1/handoff.sh"
}

# 1. Pristine shim in both stores (Claude copy with the injected model: line) → removed, row per store.
mk_shim "$SK" 'model: claude-haiku-5-5'
mk_shim "$NS" ''
mkdir -p "$FORGE_MEMBRANE/skills/pass" "$FORGE_MEMBRANE/skills/keepme"
printf 'x\n' > "$FORGE_MEMBRANE/skills/keepme/SKILL.md"
bash "$CAST" --verify > "$TMPD/rv0" 2>&1
t "--verify warns about the retired skill still present" grep -q '| handoff | RETIRED-SKILL | warning: retired skill still in ' "$TMPD/rv0"
bash "$CAST" --retire-skills > "$TMPD/rs1" 2>&1
check "--retire-skills exits 0" $? "$(tail -3 "$TMPD/rs1")"
t "reports the Claude-store copy removed" grep -q "| handoff | RETIRED-SKILL | removed $SK |" "$TMPD/rs1"
t "reports the neutral-store copy removed" grep -q "| handoff | RETIRED-SKILL | removed $NS |" "$TMPD/rs1"
[ ! -e "$SK" ] && [ ! -e "$NS" ]; check "pristine retired skill removed from both stores" $?
[ -f "$FORGE_MEMBRANE/skills/keepme/SKILL.md" ]; check "unrelated membrane-only skill untouched" $?
bash "$CAST" --retire-skills > "$TMPD/rs2" 2>&1
grep -q 'RETIRED-SKILL' "$TMPD/rs2"; [ $? -ne 0 ]; check "second --retire-skills reports no removal" $?

# 2. Guarded cases: each variant must be kept and reported, never deleted.
guard_case() { # guard_case <label> <mutator-fn>
  mk_shim "$SK" 'model: claude-haiku-5-5'
  rm -rf "$NS"
  "$2"
  bash "$CAST" --retire-skills > "$TMPD/rg" 2>&1
  check "$1: exits 0" $? "$(tail -3 "$TMPD/rg")"
  t "$1: reported KEPT" grep -q "| handoff | RETIRED-SKILL-KEPT | $SK not removed" "$TMPD/rg"
  grep -q '| RETIRED-SKILL |' "$TMPD/rg"; [ $? -ne 0 ]; check "$1: no removal row" $?
  [ -d "$SK" ]; check "$1: dir still present" $?
}
mut_edit_md() { printf 'my own note\n' >> "$SK/SKILL.md"; }
mut_edit_sh() { printf '# local tweak\n' >> "$SK/handoff.sh"; }
mut_extra() { printf 'mine\n' > "$SK/notes.txt"; }
mut_missing() { rm -f "$SK/handoff.sh"; }
guard_case "edited SKILL.md" mut_edit_md
t "edited SKILL.md: message names the file" grep -q 'SKILL.md was modified' "$TMPD/rg"
guard_case "edited handoff.sh" mut_edit_sh
guard_case "extra file in dir" mut_extra
[ -f "$SK/notes.txt" ]; check "extra user file survives" $?
guard_case "missing handoff.sh" mut_missing

# 3. A symlink named handoff is never followed or removed.
rm -rf "$SK"
mkdir -p "$TMPD/elsewhere"
printf 'precious\n' > "$TMPD/elsewhere/data"
ln -s "$TMPD/elsewhere" "$SK"
bash "$CAST" --retire-skills > "$TMPD/rl" 2>&1
t "symlinked retired skill: reported KEPT" grep -q "| handoff | RETIRED-SKILL-KEPT | $SK not removed (not a plain directory)" "$TMPD/rl"
[ -L "$SK" ] && [ -f "$TMPD/elsewhere/data" ]; check "symlink and its target untouched" $?
rm -f "$SK"

# 4. One modified store does not block the other: neutral pristine, Claude copy edited.
mk_shim "$SK" 'model: claude-haiku-5-5'
printf 'edited\n' >> "$SK/SKILL.md"
mk_shim "$NS" ''
bash "$CAST" --retire-skills > "$TMPD/rm" 2>&1
[ -d "$SK" ] && [ ! -e "$NS" ]; check "modified Claude copy kept, pristine neutral copy removed" $?
rm -rf "$SK" "$NS"

# 5. A full cast (--all) retires the shim and the whole deployment still verifies clean.
mk_shim "$SK" 'model: claude-haiku-5-5'
mk_shim "$NS" ''
bash "$CAST" --all > "$TMPD/all" 2>&1
check "--all exits 0" $? "$(tail -3 "$TMPD/all")"
[ ! -e "$SK" ] && [ ! -e "$NS" ]; check "--all removed the retired skill from both stores" $?
t "--all reports the retired skill removed" grep -q '| handoff | RETIRED-SKILL | removed ' "$TMPD/all"
bash "$CAST" --verify > "$TMPD/va" 2>&1
check "--verify exits 0 after --all" $? "$(grep -vE '\| OK \||^$|^##' "$TMPD/va")"
bash "$CAST" --verify-hooks > "$TMPD/vh" 2>&1
check "--verify-hooks exits 0 after --all" $? "$(grep -E 'MISSING|DIFFERS|UNWIRED|STALE|RETIRED' "$TMPD/vh")"

echo
if [ "$FAILS" -eq 0 ]; then echo "all passed"; else echo "$FAILS failed"; exit 1; fi
