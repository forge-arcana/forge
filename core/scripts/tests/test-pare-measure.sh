#!/usr/bin/env bash
#
# Tests for pare-measure.py. Stub repomix / osv-scanner / hyperfine on a temp
# PATH, a temp git repo, a temp HOME; never touches a real repo or tool.
# Run:  bash core/scripts/tests/test-pare-measure.sh      (non-zero on failure)

HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.."
PM="$HERE/pare-measure.py"
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
export PYTHONDONTWRITEBYTECODE=1
mkdir -p "$TMPD/home"; export HOME="$TMPD/home"
printf '[user]\n\tname = Test User\n\temail = test@example.invalid\n' > "$TMPD/gitconfig"
export GIT_CONFIG_GLOBAL="$TMPD/gitconfig" GIT_CONFIG_NOSYSTEM=1

FAILS=0
check() { if [ "$2" = 0 ]; then echo "PASS  $1"; else echo "FAIL  $1  (${3:-})"; FAILS=$((FAILS + 1)); fi; }
eq() { [ "$2" = "$3" ] && check "$1" 0 || check "$1" 1 "got=$2 want=$3"; }

# --- stubs -----------------------------------------------------------------
FULL="$TMPD/full"; NOHF="$TMPD/nohf"; NONE="$TMPD/none"
mkdir -p "$FULL" "$NOHF" "$NONE"
cat > "$FULL/repomix" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "--version" ]; then echo "1.2.3"; exit 0; fi
out=""
while [ $# -gt 0 ]; do [ "$1" = "--output" ] && out="$2"; shift; done
[ -n "$out" ] && echo "<packed/>" > "$out"
printf '\033[32mTotal Tokens:\033[0m 12,345 tokens\n'
EOF
cat > "$FULL/osv-scanner" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "--version" ]; then echo "osv-scanner version: 2.0.0"; exit 0; fi
echo '{"results":[{"packages":[{"vulnerabilities":[{"id":"GHSA-b"},{"id":"GHSA-a"}]},{"vulnerabilities":[{"id":"GHSA-a"}]}]}]}'
exit 1
EOF
cat > "$FULL/hyperfine" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "--version" ]; then echo "hyperfine 1.18.0"; exit 0; fi
js=""
while [ $# -gt 0 ]; do [ "$1" = "--export-json" ] && js="$2"; last="$1"; shift; done
case "$last" in *failcmd*) exit 1;; esac
echo '{"results":[{"median":0.2504,"mean":9}]}' > "$js"
EOF
chmod +x "$FULL"/*
cp "$FULL/repomix" "$FULL/osv-scanner" "$NOHF/"
SYS="/usr/bin:/bin"

# --- repo ------------------------------------------------------------------
REPO="$TMPD/repo"
mkdir -p "$REPO/pkg/sub" "$REPO/dist"
git init -q "$REPO"
cat > "$REPO/package.json" <<'EOF'
{"dependencies":{"a":"1","b":"1"},"devDependencies":{"c":"1"},"optionalDependencies":{"d":"1"},"peerDependencies":{"e":"1"}}
EOF
cat > "$REPO/pkg/pyproject.toml" <<'EOF'
[project]
dependencies = ["x>=1", "y"]
[project.optional-dependencies]
dev = ["z"]
[tool.poetry.dependencies]
python = "^3.11"
w = "1"
EOF
printf '# c\nfoo==1\n\nbar\n' > "$REPO/requirements-dev.txt"
printf 'x' > "$REPO/dist/a.js"; printf 'yy' > "$REPO/dist/b.js"
ln -s /etc/hostname "$REPO/dist/link"
echo "ok" > "$REPO/pkg/f.txt"
git -C "$REPO" add -A
git -C "$REPO" commit -qm init

run() { # PATHDIR args... -> stdout json in $OUT, exit in $RC
  local p="$1"; shift
  OUT="$(PATH="$p:$SYS" python3 -B -I "$PM" --repo "$REPO" "$@" 2>/dev/null)"; RC=$?
}
field() { python3 -B -I -c 'import json,sys;d=json.loads(sys.argv[1]);k=sys.argv[2];print(json.dumps(d["metrics"][k] if k in d["metrics"] else d[k]))' "$OUT" "$1"; }

# 1 all tools present
run "$FULL" --scope pkg --build "true" --test "true" --typecheck "true" --test-count "echo 'ran 7 tests'; echo 42" --bundle dist --runs 2
eq "exit 0 all tools" "$RC" 0
eq "source_tokens parsed" "$(field source_tokens)" 12345
eq "advisories unique" "$(field advisories)" 2
eq "advisory_ids sorted" "$(field advisory_ids)" '["GHSA-a", "GHSA-b"]'
eq "hyperfine median ms" "$(field build_ms)" 250
eq "test_ms" "$(field test_ms)" 250
eq "typecheck_ms" "$(field typecheck_ms)" 250
eq "test_count last integer" "$(field test_count)" 42
eq "bundle bytes (no symlink follow)" "$(python3 -B -I -c 'import json,sys;print(json.loads(sys.argv[1])["metrics"]["bundle_bytes"] - 3 >= 0)' "$OUT")" True
eq "missing empty" "$(field missing)" '[]'
eq "tools versions (version tokens)" "$(field tools)" '{"hyperfine": "1.18.0", "osv-scanner": "2.0.0", "repomix": "1.2.3"}'
# packages: root package.json 6? a,b,c,d,e = 5; requirements-dev 2; scope pyproject x,y,z,w = 4
eq "packages summed" "$(field packages)" 11

eq "output top-level keys" "$(python3 -B -I -c 'import json,sys;print(sorted(json.loads(sys.argv[1])))' "$OUT")" "['advisory_ids', 'metrics', 'missing', 'tools']"
eq "metrics has the 8 ledger keys" "$(python3 -B -I -c 'import json,sys;print(sorted(json.loads(sys.argv[1])["metrics"]))' "$OUT")" "['advisories', 'build_ms', 'bundle_bytes', 'packages', 'source_tokens', 'test_count', 'test_ms', 'typecheck_ms']"

# 1b end to end: metrics go straight into a valid ledger run record
printf '%s' "$OUT" > "$TMPD/measure.json"
eq "measure metrics fit a ledger run record" "$(python3 -B -I - "$HERE/pare-ledger.py" "$TMPD/measure.json" <<'PY'
import importlib.util, json, sys
spec = importlib.util.spec_from_file_location("pare_ledger", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
me = json.load(open(sys.argv[2]))
after = dict(me["metrics"], packages=me["metrics"]["packages"] - 1)
rec = {"v": 1, "ts": "2026-01-02T03:04:05Z", "started_at": "2026-01-02T03:00:00Z",
       "session": None, "repo": "/tmp/x/proj-a", "scope": "pkg", "trigger": "standalone",
       "commit_before": "abc1234", "commit_after": None, "tools": me["tools"].copy(),
       "coverage_pct": None, "report_only": False, "report_only_reason": None,
       "cuts": {"proven": {"candidates": 1, "tried": 1, "kept": 1, "reverted": 0},
                "judgement": {"candidates": 0, "proposed": 0, "approved": 0, "kept": 0, "reverted": 0}},
       "removed": {"lines": 1, "files": 0, "exports": 0, "packages": 1},
       "removed_items": {"files": [], "exports": [], "packages": ["a"]},
       "before": me["metrics"], "after": after, "advisory_ids_removed": me["advisory_ids"],
       "guards": {"tests_green_after": True, "test_count_drop": False, "config_changed": False},
       "pass_seconds": 245, "outcome": "completed"}
errs = m.validate_run(rec)
print("ok" if not errs else errs)
PY
)" ok

# 2 tools absent
run "$NONE" --scope pkg
eq "exit 0 no tools" "$RC" 0
eq "source_tokens null" "$(field source_tokens)" null
eq "advisories null" "$(field advisories)" null
eq "advisory_ids empty" "$(field advisory_ids)" '[]'
eq "build_ms null (no cmd)" "$(field build_ms)" null
eq "missing lists tools" "$(field missing)" '["advisories", "build_ms", "bundle_bytes", "osv-scanner", "repomix", "source_tokens", "test_count", "test_ms", "typecheck_ms"]'

# 3 hyperfine absent -> stdlib fallback
run "$NOHF" --scope pkg --build "true" --runs 3
eq "fallback build_ms is int" "$(python3 -B -I -c 'import json,sys;print(type(json.loads(sys.argv[1])["metrics"]["build_ms"]).__name__)' "$OUT")" int
run "$NOHF" --scope pkg --build "sleep 0.2" --runs 2
eq "fallback measures real time" "$(python3 -B -I -c 'import json,sys;print(json.loads(sys.argv[1])["metrics"]["build_ms"] >= 190)' "$OUT")" True

# 4 failing commands -> null + missing
run "$FULL" --scope pkg --build "failcmd" --test-count "exit 3"
eq "hyperfine failure null" "$(field build_ms)" null
eq "failed test_count null" "$(field test_count)" null
eq "failure listed in missing" "$(python3 -B -I -c 'import json,sys;m=json.loads(sys.argv[1])["missing"];print("build_ms" in m and "test_count" in m)' "$OUT")" True
run "$NOHF" --scope pkg --build "false"
eq "fallback failure null" "$(field build_ms)" null

# 5 manifests individually
M="$TMPD/m"; git init -q "$M"
REPO="$M"; mkdir -p "$M/s"; echo hi > "$M/s/a"
run "$NONE" --scope s
eq "no manifest -> packages null" "$(field packages)" null
echo '{"dependencies":{"a":"1"}}' > "$M/package.json"
run "$NONE" --scope s
eq "package.json only" "$(field packages)" 1
rm "$M/package.json"
printf '[tool.poetry.dependencies]\npython="3"\nq="1"\n[tool.poetry.group.dev.dependencies]\nr="1"\n' > "$M/pyproject.toml"
run "$NONE" --scope s
eq "pyproject poetry (python excluded)" "$(field packages)" 2
rm "$M/pyproject.toml"
printf 'a\n# x\nb\n' > "$M/requirements.txt"
run "$NONE" --scope s
eq "requirements only" "$(field packages)" 2

# 5b test_count must be a bare count on the last non-empty line
run "$NONE" --scope s --test-count "echo '42 tests collected in 0.05s'"
eq "test_count prose line -> null" "$(field test_count)" null
run "$NONE" --scope s --test-count "echo 42"
eq "test_count bare 42" "$(field test_count)" 42
run "$NONE" --scope s --test-count "printf '  17  \n\n'"
eq "test_count trailing blank lines" "$(field test_count)" 17
run "$NONE" --scope s --test-count "printf '5\nok done\n'"
eq "test_count last line not a number -> null" "$(field test_count)" null
run "$NONE" --scope s --test-count "echo 99999999999999999999"
eq "test_count above 2**53-1 -> null" "$(field test_count)" null

# 5c packages: requirements option lines skipped, duplicates counted once
printf -- '-r base.txt\n-e ./local\n-c cons.txt\n--index-url https://x.invalid/simple\nFoo_Bar==1\nbaz>=2 # c\n' > "$M/requirements.txt"
run "$NONE" --scope s
eq "requirements skips -r/-e/-c/--index-url" "$(field packages)" 2
printf 'foo-bar\nFoo.Bar[x]>=1\n' > "$M/requirements-dev.txt"
run "$NONE" --scope s
eq "PEP 503 duplicate names across requirements files" "$(field packages)" 2
printf '[project]\ndependencies = ["FOO_bar>=1", "qux"]\n' > "$M/pyproject.toml"
run "$NONE" --scope s
eq "python names unique across pyproject and requirements" "$(field packages)" 3
rm "$M/requirements.txt" "$M/requirements-dev.txt" "$M/pyproject.toml"
echo '{"dependencies":{"a":"1","b":"1"},"devDependencies":{"a":"1"},"peerDependencies":{"b":"1","c":"1"}}' > "$M/package.json"
run "$NONE" --scope s
eq "js package in several groups counted once" "$(field packages)" 3
rm "$M/package.json"

# 5d timeout kills the whole process group
PIDF="$TMPD/sleeper.pid"; rm -f "$PIDF"
run "$NOHF" --scope s --build "sleep 300 & echo \$! > '$PIDF'; wait" --timeout 1 --runs 1
eq "timed-out build is null" "$(field build_ms)" null
SP="$(cat "$PIDF" 2>/dev/null)"
sleep 0.5
if [ -n "$SP" ] && [ -r "/proc/$SP/stat" ] && ! grep -q ') Z ' "/proc/$SP/stat"; then ALIVE=yes; kill -9 "$SP" 2>/dev/null; else ALIVE=no; fi
eq "child sleeper killed on timeout" "$ALIVE/${SP:+pid}" "no/pid"
PIDF="$TMPD/sleeper2.pid"; rm -f "$PIDF"
run "$NONE" --scope s --test-count "sleep 300 & echo \$! > '$PIDF'; wait" --timeout 1
SP="$(cat "$PIDF" 2>/dev/null)"
sleep 0.5
if [ -n "$SP" ] && [ -r "/proc/$SP/stat" ] && ! grep -q ') Z ' "/proc/$SP/stat"; then ALIVE=yes; kill -9 "$SP" 2>/dev/null; else ALIVE=no; fi
eq "child sleeper killed on test-count timeout" "$ALIVE/${SP:+pid}" "no/pid"

# 6 bad arguments -> exit 2
run "$FULL" --scope ../..
eq "scope escaping repo exits 2" "$RC" 2
run "$FULL" --scope /etc
eq "absolute scope exits 2" "$RC" 2
run "$FULL" --scope nonexistent
eq "missing scope exits 2" "$RC" 2
REPO="$TMPD/notgit"; mkdir -p "$REPO"
run "$FULL" --scope .
eq "non-git repo exits 2" "$RC" 2
REPO="$TMPD/repo"
run "$FULL" --scope pkg --bundle ../x
eq "bundle escaping exits 2" "$RC" 2
mkdir -p "$TMPD/outside/sub"; echo data > "$TMPD/outside/sub/f"
ln -s "$TMPD/outside" "$REPO/pkg/lnk"
run "$FULL" --scope pkg --bundle pkg/lnk/sub
eq "bundle through symlinked parent leaving repo exits 2" "$RC" 2
run "$FULL" --scope pkg --bundle pkg/lnk
eq "bundle that is a symlink leaving repo exits 2" "$RC" 2
rm "$REPO/pkg/lnk"

# 7 nothing written inside the repo
run "$FULL" --scope pkg --build "true" --test "true" --test-count "echo 1" --bundle dist
eq "git status clean after full run" "$(git -C "$REPO" status --porcelain --ignored)" ""

echo
[ "$FAILS" = 0 ] && echo "ALL PASS" || echo "$FAILS FAILED"
exit $((FAILS > 0))
