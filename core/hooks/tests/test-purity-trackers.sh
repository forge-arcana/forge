#!/usr/bin/env bash
#
# Tests that fold-purity-check.sh scans the two git-tracked JSON trackers
# (learnings/.fold-tracker.json, memory/.memory-tracker.json) in --staged and
# --diff modes, treats their lines as JSON string values (no false positives
# from syntax or Title Case titles), flags leaks in titles/filenames, still
# skips every other dotfile, and counts a tracker as a scanned file. Throwaway
# git repo with a copy of the gate; isolated GIT_CONFIG_GLOBAL with a dummy
# identity; nothing outside the temp dir is touched.
# Run:  bash core/hooks/tests/test-purity-trackers.sh      (non-zero on failure)

HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.."
GATE_SRC="$(readlink -f "$HERE/../scripts/fold-purity-check.sh")"
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
export HOME="$TMPD/home"
mkdir -p "$HOME"
export GIT_CONFIG_GLOBAL="$TMPD/gitconfig" GIT_CONFIG_SYSTEM=/dev/null
printf '[user]\n\tname = Test User\n\temail = test@example.invalid\n[init]\n\tdefaultBranch = main\n' > "$GIT_CONFIG_GLOBAL"

R="$TMPD/repo"
mkdir -p "$R/core/scripts" "$R/learnings" "$R/memory"
cp "$GATE_SRC" "$R/core/scripts/fold-purity-check.sh"
GATE="$R/core/scripts/fold-purity-check.sh"
git -C "$R" init -q
FT="learnings/.fold-tracker.json"; MT="memory/.memory-tracker.json"
write_ft() { printf '{\n  "lastRun": "2026-11-05",\n  "processedEntries": [\n    "Existing Clean Title",\n%s\n  ]\n}\n' "$1" > "$R/$FT"; }
write_ft '    "Another Clean Title"'
printf '{\n  "skippedFiles": [\n    "notes.md"\n  ]\n}\n' > "$R/$MT"
git -C "$R" add -A
git -C "$R" commit -q -m base
BASE="$(git -C "$R" rev-parse HEAD)"

FAILS=0
check() { if [ "$2" = 0 ]; then echo "PASS  $1"; else echo "FAIL  $1  (${3:-})"; FAILS=$((FAILS + 1)); fi; }
gate() { OUT="$(bash "$GATE" "$@" 2>&1)"; RC=$?; }
has() { printf '%s' "$OUT" | grep -qE -- "$1"; }
reset() { git -C "$R" reset -q; git -C "$R" checkout -q -- . ; git -C "$R" clean -qfd; }

# (a) clean title staged: passes; (d) tracker counted as a scanned file
write_ft '    "Another Clean Title",
    "Mock Auth in Staging Must Use the Real Auth Library, Not Manual Session Creation",
    "Drizzle Migration Strategy: Versioned for Persistent, Push for Ephemeral",
    "`cf-mitigated: challenge` Header Is a Diagnostic Signal",
    "Band-Aid Fallback Detection: Ask \\"Where Should This Be Set?\\"",
    "/forge Runs From Anywhere",
    "Generated Documents Must Reside in docs/"'
git -C "$R" add "$FT"
gate --staged
check "a: clean titles pass (exit 0)" "$([ $RC = 0 ] && echo 0 || echo 1)" "rc=$RC $OUT"
has '^purity: scanned 1 file\(s\), [0-9]+ line\(s\) \[staged\]' ; check "d: tracker counted as scanned file" $? "$OUT"
reset

# (b) leaks in a staged tracker line are reported, with the tracker named
leaks=(
  'CamelCase|    "AcmeShop Checkout Pattern"'
  'Currency|    "Price Drop to $12 Per Month"'
  'Attribution|    "Retry Pattern (Alice session, 2026-11-05)"'
  'Locator path|    "Notes From /home/someone/project"'
  'Locator domain|    "Lessons From example.com Launch"'
  'Locator email|    "Ping someone@example.org"'
)
for entry in "${leaks[@]}"; do
  label="${entry%%|*}"; line="${entry#*|}"
  write_ft "    \"Another Clean Title\",
$line"
  git -C "$R" add "$FT"
  gate --staged
  check "b: $label leak fails" "$([ $RC = 1 ] && echo 0 || echo 1)" "rc=$RC"
  has "FORGE PURITY CHECK" ; check "b: $label violation reported" $? "$OUT"
  has "$FT" ; check "b: $label names the tracker" $? "$OUT"
  reset
done

# (b2) memory tracker filenames: leak in a filename value
printf '{\n  "skippedFiles": [\n    "notes.md",\n    "AcmeShop-notes.md"\n  ]\n}\n' > "$R/$MT"
git -C "$R" add "$MT"
gate --staged
check "b2: memory tracker leak fails" "$([ $RC = 1 ] && echo 0 || echo 1)" "rc=$RC"
reset
printf '{\n  "skippedFiles": [\n    "notes.md",\n    "plain-name.md"\n  ]\n}\n' > "$R/$MT"
git -C "$R" add "$MT"
gate --staged
check "b2: clean memory tracker filename passes" "$([ $RC = 0 ] && echo 0 || echo 1)" "rc=$RC $OUT"
has '^purity: scanned 1 file' ; check "d: memory tracker counted" $? "$OUT"
reset

# (c) other dotfiles are still skipped (even with a leak) and count as nothing
printf '{\n  "x": "AcmeShop leak $12"\n}\n' > "$R/learnings/.other.json"
printf 'AcmeShop leak $12\n' > "$R/memory/.hidden.md"
git -C "$R" add -f learnings/.other.json memory/.hidden.md
gate --staged
check "c: other dotfiles skipped (exit 0)" "$([ $RC = 0 ] && echo 0 || echo 1)" "rc=$RC $OUT"
has '^purity: scanned 0 file\(s\), 0 line\(s\) \[staged\]' ; check "c: scanned count excludes dotfiles" $? "$OUT"
reset

# --diff mode: tracker scanned, other dotfiles still skipped
write_ft '    "Another Clean Title",
    "AcmeShop Checkout Pattern"'
printf '{\n  "x": "AcmeShop"\n}\n' > "$R/learnings/.other.json"
git -C "$R" add -A; git -C "$R" commit -q -m leak
HEAD_="$(git -C "$R" rev-parse HEAD)"
gate --diff "$BASE" "$HEAD_"
check "diff: tracker leak fails" "$([ $RC = 1 ] && echo 0 || echo 1)" "rc=$RC"
has '^purity: scanned 1 file\(s\)' ; check "diff: only the tracker scanned" $? "$OUT"
has "other.json" ; check "diff: other dotfile not reported" "$([ $? = 0 ] && echo 1 || echo 0)" "$OUT"

# file-argument mode treats a tracker as JSON (no Title Case false positives)
write_ft '    "Mock Auth in Staging Must Use the Real Auth Library"'
gate "$R/$FT"
check "file mode: tracker with clean titles passes" "$([ $RC = 0 ] && echo 0 || echo 1)" "rc=$RC $OUT"

echo
if [ "$FAILS" = 0 ]; then echo "ALL PASS"; else echo "$FAILS FAILED"; exit 1; fi
