#!/usr/bin/env bash
# forge-scan.sh — Mechanical evidence collection for /poke and /press
# Usage: forge-scan.sh <poke|press> <project-path>
# Outputs structured markdown with grep findings for LLM judgment
#
# Portable: Linux, macOS, Windows (Git Bash / WSL).
# Requires: bash >=3.2, awk. Uses ripgrep (rg) if available, falls back to grep.
set -euo pipefail

SCAN_TYPE="${1:-}"
PROJECT="${2:-.}"

if [[ -z "$SCAN_TYPE" ]]; then
  echo "Usage: forge-scan.sh <poke|press> <project-path>"
  exit 1
fi

if [[ ! -d "$PROJECT" ]]; then
  echo "ERROR: Project path '$PROJECT' not found."
  exit 1
fi

# Resolve to absolute path (macOS readlink doesn't support -f, use cd+pwd)
PROJECT=$(cd "$PROJECT" && pwd)

# --- Tool detection ---
USE_RG=false
if command -v rg &>/dev/null; then
  USE_RG=true
fi

# --- Lean output (Path B): compress sample-match blocks before they fan out to
# subagents (/poke, /press, /pound). Counts are computed separately and stay
# exact; only the displayed samples are de-noised. Source the Tier-1 compressor. ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lean.sh
source "$SCRIPT_DIR/lean.sh"
# Dedup identical matches, strip the repeated absolute project path, cap width.
lean_samples() { lean_filter 160 "$PROJECT" on; }

echo "## Forge Scan Report"
echo "**Type**: $SCAN_TYPE | **Project**: \`$PROJECT\`"
echo "**Search tool**: $(if $USE_RG; then echo "ripgrep"; else echo "grep (fallback)"; fi)"

# --- Language detection: the patterns below cover JS/TS and Python only. A zero
# match on any other stack means "not looked at", so the report says so up front. ---
# Noise directories pruned from every find in this script.
PRUNE_ARGS=(-name node_modules -o -name .git -o -name dist -o -name build -o -name venv -o -name .venv -o -name __pycache__ -o -name site-packages)

# Presence test: true when a file matching the given find predicates exists
# (noise dirs pruned, bounded depth so a monorepo member counts).
# Args: find name predicates, e.g. -name 'package.json' -o -name '*.ts'
has_file() {
  [[ -n "$(find "$PROJECT" -mindepth 1 -maxdepth 5 \( "${PRUNE_ARGS[@]}" \) -prune \
    -o -type f \( "$@" \) -print -quit 2>/dev/null)" ]]
}

HAS_TS=false
HAS_PY=false
LANGS=()
if has_file -name 'package.json' -o -name 'tsconfig*.json' -o -name '*.ts' -o -name '*.tsx' -o -name '*.mts' -o -name '*.cts' -o -name '*.js' -o -name '*.jsx' -o -name '*.mjs' -o -name '*.cjs'; then
  HAS_TS=true
  LANGS+=("TypeScript/JavaScript")
fi
if has_file -name 'pyproject.toml' -o -name 'requirements*.txt' -o -name 'setup.py' -o -name 'Pipfile' -o -name 'uv.lock' -o -name 'poetry.lock' -o -name '*.py'; then
  HAS_PY=true
  LANGS+=("Python")
fi
# Language-typed rows print only for a detected language. With neither detected,
# every row prints (zero matches) under the "Not covered" banner.
PRINT_TS=true
PRINT_PY=true
if [[ ${#LANGS[@]} -gt 0 ]]; then
  echo "**Languages detected**: $(IFS=,; echo "${LANGS[*]}" | sed 's/,/, /g')"
  if ! $HAS_PY; then
    PRINT_PY=false
    echo "> **Skipped**: Python sections (no Python detected)."
  elif ! $HAS_TS; then
    PRINT_TS=false
    echo "> **Skipped**: TypeScript/JavaScript sections (no JS/TS detected)."
  fi
else
  echo "**Languages detected**: none (no JS/TS or Python manifests or source files found)"
  echo "> **Not covered**: this scan's patterns cover JS/TS and Python only. A zero-match result on this stack is not evidence of a clean codebase."
fi
echo ""

# Django migrations are generated code: /poke leaves them out of Python rows, /press keeps them.
PY_PRUNE_ARGS=("${PRUNE_ARGS[@]}")
PY_SKIP_MIGRATIONS=false
if [[ "$SCAN_TYPE" == "poke" ]]; then
  PY_SKIP_MIGRATIONS=true
  PY_PRUNE_ARGS+=(-o -name migrations)
fi

# Noise directories excluded from every rg and grep search (the rg and grep branches share this list).
NOISE_DIRS=(node_modules dist build .git)

# Map a type name to a grep --include glob list.
# rg uses --type ts; grep needs --include='*.ts' --include='*.tsx' etc.
type_to_includes() {
  case "$1" in
    ts)   echo "*.ts *.tsx *.mts *.cts" ;;
    js)   echo "*.js *.jsx *.mjs *.cjs" ;;
    py)   echo "*.py" ;;
    yaml) echo "*.yml *.yaml" ;;
    json) echo "*.json" ;;
    md)   echo "*.md *.mdx" ;;
    *)    echo "*.$1" ;;
  esac
}

# Fill the global FILES array from stdin, one path per line.
collect_files() {
  local f
  FILES=()
  while IFS= read -r f; do
    FILES+=("$f")
  done
}

# Report precomputed file:line:text matches: heading, pattern, count, first 20 samples.
# Args: label description matches
report_matches() {
  local label="$1"
  local desc="$2"
  local matches="$3"
  local count
  count=$(printf '%s' "$matches" | awk 'NF {c++} END {print c+0}')

  echo "### $label"
  echo "**Pattern**: \`$desc\` | **Matches**: $count"
  if [[ "$count" -gt 0 ]]; then
    echo '```'
    printf '%s\n' "$matches" | lean_samples | head -20 || true
    echo '```'
    if [[ "$count" -gt 20 ]]; then
      echo "*($count total matches, showing first 20)*"
    fi
  fi
  echo ""
}

# Helper: run search and report count + sample matches
# Rows typed for a language that was not detected print nothing (see PRINT_TS / PRINT_PY).
# Args: label pattern [type_name] [extra: -i] [exclude_regex]
# exclude_regex drops matching lines whose text (after file:line:) matches it (ERE).
scan_pattern() {
  local label="$1"
  local pattern="$2"
  local type_name="${3:-ts}"
  local case_flag="${4:-}"
  local exclude="${5:-}"
  local matches="" d

  if [[ "$type_name" == "py" ]] && ! $PRINT_PY; then return 0; fi
  if [[ "$type_name" == "ts" ]] && ! $PRINT_TS; then return 0; fi

  if $USE_RG; then
    # "ts" covers plain JS too. --type may repeat (union).
    local rg_args=("--type" "$type_name")
    if [[ "$type_name" == "ts" ]]; then
      rg_args+=("--type" "js")
    fi
    if [[ "$case_flag" == "-i" ]]; then
      rg_args+=("-i")
    fi
    # rg honours .gitignore only inside a git repo, so exclude the noise dirs explicitly.
    for d in "${NOISE_DIRS[@]}"; do
      rg_args+=("-g" "!$d")
    done
    rg_args+=("-g" "!*.min.js")
    # Virtualenvs and bytecode caches are not project code (rg skips them only via .gitignore).
    if [[ "$type_name" == "py" ]]; then
      rg_args+=("-g" "!venv" "-g" "!.venv" "-g" "!__pycache__" "-g" "!site-packages")
      if $PY_SKIP_MIGRATIONS; then
        rg_args+=("-g" "!migrations")
      fi
    fi
    # Zero matches makes rg exit non-zero (pipefail); that is a result, not an error.
    matches=$(rg "${rg_args[@]}" -n "$pattern" "$PROJECT" 2>/dev/null || true)
  else
    # grep fallback — build --include flags from type name
    local grep_args=("-rn" "-E")
    if [[ "$case_flag" == "-i" ]]; then
      grep_args+=("-i")
    fi
    local includes inc
    includes=$(type_to_includes "$type_name")
    if [[ "$type_name" == "ts" ]]; then
      includes="$includes $(type_to_includes js)"
    fi
    for inc in $includes; do
      grep_args+=("--include=$inc")
    done

    # Exclude common noise directories
    for d in "${NOISE_DIRS[@]}"; do
      grep_args+=("--exclude-dir=$d")
    done
    grep_args+=("--exclude=*.min.js")
    if [[ "$type_name" == "py" ]]; then
      grep_args+=("--exclude-dir=venv" "--exclude-dir=.venv" "--exclude-dir=__pycache__" "--exclude-dir=site-packages")
      if $PY_SKIP_MIGRATIONS; then
        grep_args+=("--exclude-dir=migrations")
      fi
    fi
    matches=$(grep "${grep_args[@]}" "$pattern" "$PROJECT" 2>/dev/null || true)
  fi

  if [[ -n "$exclude" ]]; then
    matches=$(printf '%s\n' "$matches" | grep -E -v ":[0-9]+:${exclude}" || true)
  fi
  report_matches "$label" "$pattern" "$matches"
}

# Helper: check file/directory existence
check_exists() {
  local label="$1"
  local path="$2"

  if [[ -e "$PROJECT/$path" ]]; then
    echo "| $label | \`$path\` | YES |"
  else
    echo "| $label | \`$path\` | **MISSING** |"
  fi
}

# Helper: like check_exists, but finds the first match anywhere under the project
# (PY_PRUNE_ARGS pruned, same as py_files0). Args: label, find type (f|d), names...
check_exists_any() {
  local label="$1" ftype="$2"
  shift 2
  local names=() n first
  for n in "$@"; do
    [[ ${#names[@]} -gt 0 ]] && names+=(-o)
    names+=(-name "$n")
  done
  first=$(find "$PROJECT" -mindepth 1 \( "${PY_PRUNE_ARGS[@]}" \) -prune \
    -o -type "$ftype" \( "${names[@]}" \) -print 2>/dev/null | LC_ALL=C awk '{print length($0) "\t" $0}' | LC_ALL=C sort -n | head -n 1 | cut -f2-)
  if [[ -n "$first" ]]; then
    echo "| $label | \`${first#"$PROJECT"/}\` | YES |"
  else
    echo "| $label | \`${names[1]}\` | **MISSING** |"
  fi
}

# Helper: search wrangler config files by name. scan_pattern filters by file
# type and cannot target wrangler.toml / wrangler.json / wrangler.jsonc.
# Comment lines are not counted. A match shows a key is present, not that it is
# on: samples carry two lines of context so the reader can see `enabled`.
# Args: label pattern
scan_wrangler() {
  local label="$1"
  local pattern="$2"
  local count=0
  # A grep -n line (file:N:text) or context line (file-N-text) whose text is a comment.
  local comment_re='^.*[:-][0-9]+[:-][[:space:]]*(#|//)'

  # -mindepth 1 keeps the prune from swallowing a scan root named build/ or dist/.
  collect_files < <(find "$PROJECT" -mindepth 1 \( -name node_modules -o -name .git -o -name dist -o -name build \) -prune \
    -o -type f \( -name 'wrangler.toml' -o -name 'wrangler.json' -o -name 'wrangler.jsonc' \) -print 2>/dev/null \
    | LC_ALL=C sort)
  local files=("${FILES[@]+"${FILES[@]}"}")

  echo "### $label"
  if [[ ${#files[@]} -eq 0 ]]; then
    echo "**Pattern**: \`$pattern\` | **Matches**: 0 (no wrangler config found)"
    echo ""
    return 0
  fi

  count=$(grep -E -n "$pattern" /dev/null "${files[@]}" 2>/dev/null \
    | grep -E -v -c "$comment_re") || count=0

  echo "**Pattern**: \`$pattern\` | **Matches**: $count (comment lines excluded; read \`enabled\` from the sample)"

  if [[ "$count" -gt 0 ]]; then
    echo '```'
    grep -E -n -A 2 "$pattern" /dev/null "${files[@]}" 2>/dev/null \
      | grep -E -v "$comment_re" | lean_samples | head -30 || true
    echo '```'
    if [[ "$count" -gt 10 ]]; then
      echo "*($count total matches, showing the first 30 lines including context)*"
    fi
  fi
  echo ""
}

# --- Python helpers ---
# scan_pattern is single-line grep. Python needs a few checks that depend on the
# next line or the enclosing block (a swallowed except, sync I/O inside async def),
# so those use awk over the .py files and report through the same format.

# Python env/secret reads: raw environ access, settings modules, dotenv loaders.
PY_ENV_RE='os\.environ|os\.getenv|environ\.get\(|getenv\(|BaseSettings|django\.conf|load_dotenv|dotenv_values|decouple|environs'

# NUL-delimited project .py files (noise dirs pruned), sorted. Feed to `xargs -0`
# so a large repo cannot exceed the argument limit.
py_files0() {
  find "$PROJECT" -mindepth 1 \( "${PY_PRUNE_ARGS[@]}" \) -prune \
    -o -type f -name '*.py' -print0 2>/dev/null | LC_ALL=C sort -z
}

# Top 15 files by line count from a NUL-delimited path list on stdin, as
# "%4d lines  <path relative to the project>". One wc per batch, not one per file.
top_files_by_lines() {
  xargs -0 -r wc -l 2>/dev/null \
    | grep -E -v '^ *[0-9]+ total$' \
    | LC_ALL=C sort -rn \
    | head -15 \
    | PRJ="$PROJECT" awk '{
        n = $1; sub(/^ *[0-9]+ /, "")
        if (index($0, ENVIRON["PRJ"] "/") == 1) $0 = substr($0, length(ENVIRON["PRJ"]) + 2)
        printf "%4d lines  %s\n", n, $0
      }' || true
}

# Lines matching BODY inside a block opened by a line matching START; the block
# ends at the first non-blank line indented no deeper than its opener, except a
# line that starts with a closing bracket at the opener's indent (the end of a
# multi-line signature or call). A nested plain `def` is skipped: its body is not
# in the opener's scope.
# Awk ERE (no \b, \s). Patterns pass through ENVIRON so backslashes survive.
# Args: label description start_regex body_regex
scan_py_block() {
  local label="$1" desc="$2" start="$3" body="$4" matches=""
  if ! $PRINT_PY; then return 0; fi
  matches=$(py_files0 | START="$start" BODY="$body" xargs -0 awk '
    FNR == 1 { inb = 0; skip = 0 }
    /^[ \t]*$/ { next }
    {
      match($0, /^[ \t]*/); ind = RLENGTH
      closer = ($0 ~ /^[ \t]*[])}]/)
      if (skip) {
        if (ind > sind || (closer && ind == sind)) next
        skip = 0
      }
      if (inb && ind <= bind && !(closer && ind == bind)) inb = 0
      if ($0 ~ ENVIRON["START"]) { inb = 1; bind = ind; next }
      if (inb && ind > bind && $0 ~ /^[ \t]*def[ \t]/) { skip = 1; sind = ind; next }
      if (inb && $0 !~ /^[ \t]*#/ && $0 ~ ENVIRON["BODY"]) print FILENAME ":" FNR ":" $0
    }' 2>/dev/null || true)
  report_matches "$label" "$desc" "$matches"
}

# Except clauses (bare, Exception/BaseException, or a tuple of classes) whose body only
# passes, continues or is "...": the error is swallowed. Looks at the next code line,
# or the same line.
# Args: label
scan_py_swallowed() {
  local label="$1" matches=""
  local desc='except / except Exception / except BaseException / except (A, B) followed by pass, ..., continue'
  if ! $PRINT_PY; then return 0; fi
  matches=$(py_files0 | xargs -0 awk '
    BEGIN {
      exc = "^[ \t]*except([ \t]*(Exception|BaseException|\\([^)]*\\))([ \t]+as[ \t]+[A-Za-z_][A-Za-z0-9_]*)?)?[ \t]*:"
      endre = exc "[ \t]*(#.*)?$"
      samere = exc "[ \t]*(pass|\\.\\.\\.|continue)[ \t]*(#.*)?$"
    }
    FNR == 1 { pend = 0 }
    /^[ \t]*$/ || /^[ \t]*#/ { next }
    {
      if (pend) {
        if ($0 ~ /^[ \t]*(pass|\.\.\.|continue)[ \t]*(#.*)?$/) print pfile ":" pline ":" ptext
        pend = 0
      }
      if ($0 ~ endre) {
        pend = 1; pfile = FILENAME; pline = FNR; ptext = $0
      } else if ($0 ~ samere) {
        print FILENAME ":" FNR ":" $0
      }
    }' 2>/dev/null || true)
  report_matches "Swallowed exceptions (except ... pass/continue) (Python)" "$desc" "$matches"
}

# Route registrations: FastAPI/Starlette/Flask decorators, Django path()/re_path(),
# DRF @api_view and view classes. Patterns follow plot-scan.sh, widened to
# router/blueprint variable names.
scan_py_routes() {
  scan_pattern "Route registrations - FastAPI/Starlette/DRF decorators (Python)" \
    '@\w*(app|router|api|bp|blueprint)\w*\.(get|post|put|patch|delete|options|head|websocket|api_route)\(|@api_view\(' \
    "py"

  scan_pattern "Route registrations - Flask route decorators (Python)" \
    '@\w*(app|bp|blueprint|api)\w*\.route\(' \
    "py"

  scan_pattern "Route registrations - Django path()/re_path()/url() (Python)" \
    "^\s*(path|re_path|url)\(\s*r?['\"]" \
    "py"

  scan_pattern "Django/DRF view classes (Python)" \
    'class \w+\([^)]*(View|ViewSet)\b' \
    "py"
}

# Python manifests, lockfiles and workspace layout (uv, poetry, hatch, pdm, rye).
python_manifests() {
  local nested
  if ! $PRINT_PY; then return 0; fi
  echo "### Python manifests and lockfiles"
  echo "| Check | Path | Exists? |"
  echo "|-------|------|---------|"
  check_exists "Python project manifest" "pyproject.toml"
  check_exists "Python requirements file" "requirements.txt"
  check_exists "uv lockfile" "uv.lock"
  check_exists "Poetry lockfile" "poetry.lock"
  check_exists "Pipenv lockfile" "Pipfile.lock"
  echo ""

  nested=$(find "$PROJECT" -mindepth 1 -maxdepth 5 \( "${PRUNE_ARGS[@]}" \) -prune \
    -o -type f \( -name 'pyproject.toml' -o -name 'requirements*.txt' -o -name 'setup.py' \) -print 2>/dev/null \
    | sed "s|^$PROJECT/||" | LC_ALL=C sort) || nested=""
  echo "### Python manifests found (up to 5 levels deep)"
  if [[ -n "$nested" ]]; then
    echo '```'
    printf '%s\n' "$nested" | head -40
    echo '```'
  else
    echo "**Matches**: 0 (no Python manifest found)"
  fi
  echo ""

  scan_py_workspace
}

# Workspace sections in pyproject.toml files (root and members).
scan_py_workspace() {
  local matches=""
  if ! $PRINT_PY; then return 0; fi
  load_pyprojects
  if [[ ${#PYPROJECTS[@]} -gt 0 ]]; then
    matches=$(grep -E -n -H '^\[(tool\.(uv\.workspace|uv\.sources|poetry|hatch|pdm|rye)|dependency-groups)' "${PYPROJECTS[@]}" 2>/dev/null || true)
  fi
  report_matches "Python workspace / tool sections (pyproject.toml)" \
    '[tool.uv.workspace], [tool.poetry], [tool.hatch], [tool.pdm], [tool.rye], [dependency-groups]' "$matches"
}

# pyproject.toml files (root and members, up to 5 levels), found once.
PYPROJECTS=()
PYPROJECTS_LOADED=false
load_pyprojects() {
  if $PYPROJECTS_LOADED; then return 0; fi
  collect_files < <(find "$PROJECT" -mindepth 1 -maxdepth 5 \( "${PRUNE_ARGS[@]}" \) -prune \
    -o -type f -name 'pyproject.toml' -print 2>/dev/null | LC_ALL=C sort)
  PYPROJECTS=("${FILES[@]+"${FILES[@]}"}")
  PYPROJECTS_LOADED=true
}

# The [project] / [tool.poetry] version line (or `dynamic`) per pyproject.toml.
scan_pyproject_version() {
  local matches=""
  if ! $PRINT_PY; then return 0; fi
  load_pyprojects
  if [[ ${#PYPROJECTS[@]} -gt 0 ]]; then
    matches=$(awk '
      FNR == 1 { sec = "" }
      /^\[/ { sec = $0 }
      (sec == "[project]" || sec == "[tool.poetry]") && /^[ \t]*(version|dynamic)[ \t]*=/ { print FILENAME ":" FNR ":" $0 }
    ' "${PYPROJECTS[@]}" 2>/dev/null || true)
  fi
  report_matches "Python package version source (pyproject.toml)" \
    'version / dynamic under [project] or [tool.poetry]' "$matches"
}

# ============================================================
# POKE SCAN — Code quality + tech debt evidence collection
# ============================================================
if [[ "$SCAN_TYPE" == "poke" ]]; then

  echo "# /poke Evidence Collection"
  echo ""

  # --- Dimension 1: SOLID & Strategy Patterns ---
  echo "## Dimension 1: SOLID & Strategy Patterns"
  echo ""

  scan_pattern "Switch/case chains (OCP candidates)" \
    "case '" \
    "ts"

  scan_pattern "match/case chains (OCP candidates) (Python)" \
    '^\s*case\s+.+:\s*$' \
    "py"

  scan_pattern "Environment branching (NODE_ENV)" \
    "NODE_ENV|isDev|isProduction|isStaging" \
    "ts"

  scan_pattern "Environment branching (APP_ENV, DEBUG, is_prod) (Python)" \
    'APP_ENV|ENVIRONMENT|is_dev|is_prod(uction)?|is_staging|settings\.DEBUG|DJANGO_SETTINGS_MODULE|^\s*DEBUG\s*=' \
    "py"

  scan_pattern "Environment and secret reads (os.environ, settings modules) (Python)" \
    "$PY_ENV_RE" \
    "py"

  scan_pattern "Feature flag if-statements" \
    "featureFlag|feature_flag|FEATURE_" \
    "ts" "-i"

  scan_pattern "Feature flag if-statements (Python)" \
    'feature_flag|FEATURE_|waffle|flag_enabled' \
    "py" "-i"

  scan_pattern "Concrete class imports (DIP — should inject)" \
    'import.*Service|import.*Repository|import.*Client' \
    "ts"

  scan_pattern "Concrete class imports (DIP — should inject) (Python)" \
    '^\s*(from|import)\s.*(Service|Repository|Client)\b' \
    "py"

  scan_pattern "NotImplemented / method stubs (LSP/ISP smell)" \
    'NotImplemented|throw new Error.*not implemented|TODO.*implement' \
    "ts" "-i"

  scan_pattern "NotImplementedError / method stubs (LSP/ISP smell) (Python)" \
    'NotImplemented|TODO.*implement' \
    "py" "-i"

  # --- Dimension 2: Band-Aids ---
  echo "## Dimension 2: Band-Aids"
  echo ""

  scan_pattern "Fallback chains (3+ links)" \
    '\|\|.*\|\|' \
    "ts"

  # Docstring and comment lines ("""either a or b or c""", # a or b or c) are prose, not code.
  scan_pattern "Fallback chains (3+ links) (Python)" \
    '\bor\b.*\bor\b' \
    "py" "" '[[:space:]]*("""|'"'''"'|#)'

  scan_pattern "Bare except (catches SystemExit and KeyboardInterrupt) (Python)" \
    '^\s*except\s*:' \
    "py"

  scan_py_swallowed "Swallowed exceptions (except ... pass/continue) (Python)"

  scan_pattern "Nullish coalescing chains" \
    '\?\?.*\?\?' \
    "ts"

  scan_pattern "Sentinel defaults ('unknown', 'default')" \
    "(\|\| ['\"]unknown['\"]|\?\? ['\"]default['\"]|\?\? ['\"]Unknown['\"]|\|\| ['\"]N/A['\"])" \
    "ts"

  scan_pattern "Sentinel defaults ('unknown', 'default') (Python)" \
    "(\bor |getenv\([^)]*, *|\.get\([^)]*, *)['\"](unknown|default|Unknown|N/A)['\"]" \
    "py"

  scan_pattern "Unsafe casts (as any)" \
    'as any|as unknown' \
    "ts"

  scan_pattern "Type-check escapes (cast, type: ignore, Any) (Python)" \
    '\bcast\(|# type: ignore|: Any\b|-> Any\b' \
    "py"

  scan_pattern "Non-null assertions (!.)" \
    '\w+!\.' \
    "ts"

  scan_pattern "Magic string comparisons" \
    "=== ['\"][a-z]+" \
    "ts"

  scan_pattern "Magic string comparisons (Python)" \
    "[=!]= ['\"][a-z]+" \
    "py"

  scan_pattern "Hardcoded URLs" \
    "https?://[a-z]" \
    "ts" "-i"

  scan_pattern "Hardcoded URLs (Python)" \
    "https?://[a-z]" \
    "py" "-i"

  scan_pattern "Hardcoded port numbers" \
    ':\d{4}[^0-9]' \
    "ts"

  scan_pattern "Hardcoded port numbers (Python)" \
    ':[0-9]{4}([^0-9]|$)' \
    "py"

  # --- Dimension 2b: Client-Supplied Actor Identity ---
  echo "### 2b: Actor Identity in Request Body"
  echo ""

  scan_pattern "Identity fields in validation schemas" \
    'Id.*z\.string|sender.*z\.string' \
    "ts"

  scan_pattern "Handlers reading identity from body" \
    '(Id|sender).*=.*req\.(valid|body|json)' \
    "ts"

  scan_pattern "Soft auth checks" \
    'if \((auth|session).*&&' \
    "ts"

  scan_pattern "Identity fields in request models (Pydantic, serializers) (Python)" \
    '^\s*\w*(_id|Id|sender)\w*\s*:\s*(str|int|UUID|Optional)' \
    "py"

  scan_pattern "Handlers reading identity from body (Python)" \
    '(_id|Id|sender)\w*\s*=.*(request\.(json|data|form|POST|GET|args)|body\[|body\.get|payload\[|payload\.get)' \
    "py"

  scan_pattern "Soft auth checks (Python)" \
    'if\s+\(?(auth|session)\w*.*\band\b' \
    "py"

  if $PRINT_PY; then
    echo "### 2c: Route Surface (Python)"
    echo ""
  fi

  scan_py_routes

  # --- Dimension 3: Framework Misuse ---
  echo "## Dimension 3: Framework Misuse"
  echo ""

  scan_pattern "Manual query building (raw SQL)" \
    'sql`|\.execute\(|\.raw\(' \
    "ts"

  scan_pattern "Manual query building (raw SQL) (Python)" \
    '\.execute(many)?\(|\btext\(\s*f?["'"'"']|\.raw\(|\.extra\(|RawSQL' \
    "py"

  scan_pattern "Hand-rolled validation (manual checks)" \
    'typeof .* !== |typeof .* === ' \
    "ts"

  scan_pattern "Hand-rolled validation (isinstance / type checks) (Python)" \
    'if not isinstance\(|type\(.*\) *(==|!=|is)' \
    "py"

  scan_pattern "Custom error classes" \
    'extends Error' \
    "ts"

  scan_pattern "Custom error classes (Python)" \
    'class \w+\((\w+\.)*(Exception|\w*Error)\)' \
    "py"

  scan_pattern "Manual JSON parsing" \
    'JSON\.parse' \
    "ts"

  scan_pattern "Manual JSON parsing (Python)" \
    'json\.loads?\(' \
    "py"

  scan_py_block "Sync I/O inside async def (blocks the event loop) (Python)" \
    'time.sleep, requests.*, urlopen, subprocess.*, open(), sqlite3/psycopg2 connect inside async def' \
    '^[ \t]*async[ \t]+def[ \t]' \
    'time\.sleep\(|requests\.(get|post|put|patch|delete|head|request)\(|urllib\.request\.|urlopen\(|subprocess\.(run|call|check_output|check_call)\(|(^|[^.A-Za-z0-9_])open\(|sqlite3\.connect\(|psycopg2\.connect\('

  # --- Dimension 4: Logging Hygiene ---
  echo "## Dimension 4: Logging Hygiene"
  echo ""

  scan_pattern "Console.log usage (should use structured logger)" \
    'console\.(log|warn|error|info|debug)' \
    "ts"

  scan_pattern "print() / debugger usage (should use logging) (Python)" \
    '\bprint\(|\bpprint\(|breakpoint\(\)|pdb\.set_trace\(' \
    "py"

  scan_pattern "Logger calls (structured logging)" \
    'logger\.(info|warn|error|debug|trace|fatal)' \
    "ts"

  scan_pattern "Logger calls (logging, structlog, loguru) (Python)" \
    '\b(logger|log|logging|_logger|_log)\.(info|warning|warn|error|debug|critical|exception|fatal)\(' \
    "py"

  scan_pattern "Pino redact configuration" \
    'redact' \
    "ts"

  scan_pattern "Log redaction / filters (Python)" \
    'redact|scrub|sensitive|logging\.Filter' \
    "py" "-i"

  scan_pattern "Health check endpoints" \
    'health|healthz|readyz|livez' \
    "ts" "-i"

  scan_pattern "Health check endpoints (Python)" \
    'health|healthz|readyz|livez' \
    "py" "-i"

  scan_pattern "Sensitive data in logs (password, token, secret)" \
    'password|token|secret|apiKey|api_key' \
    "ts" "-i"

  scan_pattern "Sensitive data in logs (password, token, secret) (Python)" \
    'password|token|secret|apiKey|api_key' \
    "py" "-i"

  scan_pattern "Dev log endpoint" \
    '/api/dev/log|dev.log|browser_console' \
    "ts" "-i"

  scan_pattern "Dev log endpoint (Python)" \
    '/api/dev/log|dev.log|browser_console' \
    "py" "-i"

  # --- Dimension 5: Clean Functions ---
  echo "## Dimension 5: Clean Functions"
  echo ""

  scan_pattern "Generic variable names (data, info, result, tmp)" \
    '\b(const|let|var)\s+(data|info|result|tmp|temp|ret|val|obj|item)\b' \
    "ts"

  scan_pattern "Functions with many parameters (>4)" \
    '\(((\w+:\s*\w+,\s*){4,})' \
    "ts"

  scan_pattern "Deep nesting (4+ levels of indentation)" \
    '^\s{16,}\S' \
    "ts"

  scan_pattern "Single-letter variables (outside loops)" \
    '\b(const|let)\s+[a-z]\s*=' \
    "ts"

  scan_pattern "Functions with many parameters (>4) (Python)" \
    'def \w+\(([^,)]+,){4,}' \
    "py"

  scan_pattern "Deep nesting (6+ levels of indentation) (Python)" \
    '^\s{24,}\S' \
    "py"

  # --- Dimension 6: Dependency Direction & Law of Demeter ---
  echo "## Dimension 6: Dependency Direction & Law of Demeter"
  echo ""

  scan_pattern "Shared importing from features (wrong direction)" \
    "from ['\"]\.\./(features|pages|routes|views)/" \
    "ts"

  scan_pattern "Shared importing from features (wrong direction) (Python)" \
    '^\s*(from|import)\s+[A-Za-z0-9_.]*\b(features|pages|routes|views)\b' \
    "py"

  scan_pattern "Circular dependency markers" \
    'circular|CIRCULAR' \
    "ts" "-i"

  scan_pattern "Domain importing framework code" \
    "from ['\"]hono|from ['\"]react|from ['\"]express|from ['\"]next" \
    "ts"

  scan_pattern "Domain importing framework code (Python)" \
    '^\s*(from|import)\s+(fastapi|flask|django|starlette|aiohttp|sanic|tornado)\b' \
    "py"

  scan_pattern "Deep property chains (train wrecks)" \
    '\w+\.\w+\.\w+\.\w+' \
    "ts"

  # Dotted module paths on import lines are not train wrecks.
  scan_pattern "Deep property chains (train wrecks) (Python)" \
    '\w+\.\w+\.\w+\.\w+' \
    "py" "" '[[:space:]]*(from|import)[[:space:]]'

  scan_pattern "Optional chaining depth (a?.b?.c?.d)" \
    '\?\.\w+\?\.\w+\?\.' \
    "ts"

  # --- Dimension 7: Composition over Inheritance ---
  echo "## Dimension 7: Composition over Inheritance"
  echo ""

  scan_pattern "Class inheritance (extends)" \
    'class \w+ extends' \
    "ts"

  scan_pattern "Class inheritance (base classes) (Python)" \
    '^\s*class \w+\([A-Za-z_][A-Za-z0-9_., ]*\)\s*:' \
    "py"

  scan_pattern "Mixin patterns" \
    'mixin|Mixin|applyMixin' \
    "ts" "-i"

  # --- File Size Analysis ---
  echo "## File Size Analysis"
  echo ""
  if $PRINT_TS; then
    echo "### Largest TypeScript files (potential SRP violations)"
    echo '```'
    find "$PROJECT" -mindepth 1 \( -name node_modules -o -name dist -o -name build -o -name .git \) -prune \
      -o -type f \( -name '*.ts' -o -name '*.tsx' \) ! -name '*.d.ts' -print0 2>/dev/null \
      | top_files_by_lines || true
    echo '```'
    echo ""
  fi

  if $PRINT_PY; then
    echo "### Largest Python files (potential SRP violations)"
    echo '```'
    py_files0 | top_files_by_lines || true
    echo '```'
    echo ""
  fi

  # --- File structure checks ---
  echo "## Project Structure"
  echo ""
  echo "| Check | Path | Exists? |"
  echo "|-------|------|---------|"

  check_exists "Logging config" "src/lib/logger"
  check_exists "Dev log file" "logs/dev.log"
  check_exists "Logs directory" "logs"
  check_exists "Error tracking (Sentry CLI config; not needed on Workers)" ".sentryclirc"
  check_exists "Kill zombies script" "kill-zombies.sh"
  check_exists "Restart script" "restart.sh"
  echo ""

  python_manifests

fi

# ============================================================
# PRESS SCAN — Go-live readiness evidence collection
# ============================================================
if [[ "$SCAN_TYPE" == "press" ]]; then

  echo "# /press Evidence Collection"
  echo ""

  # --- Dimension 1: Security ---
  echo "## Dimension 1: Security"
  echo ""

  scan_pattern "CORS configuration" \
    'cors|CORS|Access-Control' \
    "ts" "-i"

  scan_pattern "CORS configuration (Python)" \
    'cors|Access-Control' \
    "py" "-i"

  scan_pattern "CSP headers" \
    "Content-Security-Policy|CSP|helmet" \
    "ts" "-i"

  scan_pattern "CSP headers (Python)" \
    'Content-Security-Policy|CSP|talisman|SecurityMiddleware|secure_headers' \
    "py" "-i"

  scan_pattern "Rate limiting" \
    'rateLimit|rate.limit|throttle' \
    "ts" "-i"

  scan_pattern "Rate limiting (Python)" \
    'rate.?limit|throttle|slowapi|Limiter\(' \
    "py" "-i"

  scan_pattern "Input validation (Zod schemas)" \
    'z\.(string|number|object|array|enum)\(' \
    "ts"

  scan_pattern "Input validation (Pydantic, marshmallow, forms, serializers) (Python)" \
    'pydantic|BaseModel|marshmallow|wtforms|serializers\.\w*Serializer|forms\.\w*Form|\bField\(' \
    "py"

  scan_pattern "Hardcoded secrets" \
    "(password|secret|apiKey|api_key|token)\s*[:=]\s*['\"][^'\"]{8,}" \
    "ts" "-i"

  scan_pattern "Hardcoded secrets (Python)" \
    "(password|secret|apiKey|api_key|token)\w*\s*[:=]\s*['\"][^'\"]{8,}" \
    "py" "-i"

  scan_pattern "Environment and secret reads (os.environ, settings modules) (Python)" \
    "$PY_ENV_RE" \
    "py"

  scan_pattern "SQL injection risk (string concatenation in queries)" \
    'sql`\$\{' \
    "ts"

  scan_pattern "SQL injection risk (formatted SQL strings) (Python)" \
    "f['\"].*(SELECT .* FROM|INSERT INTO|UPDATE [a-z_.]+ SET|DELETE FROM)|(SELECT .* FROM|INSERT INTO|UPDATE [a-z_.]+ SET|DELETE FROM).*['\"] *(%|\.format\(|\+ )" \
    "py" "-i"

  scan_pattern "CSRF protection" \
    'csrf|CSRF|xsrf' \
    "ts" "-i"

  scan_pattern "CSRF protection (Python)" \
    'csrf|xsrf' \
    "py" "-i"

  if $PRINT_PY; then
    echo "### Route surface (Python)"
    echo ""
  fi

  scan_py_routes

  # --- Dimension 2: Scalability ---
  echo "## Dimension 2: Scalability"
  echo ""

  scan_pattern "Database indexes" \
    'index\(|\.createIndex|CREATE INDEX|uniqueIndex' \
    "ts" "-i"

  scan_pattern "Database indexes (Python)" \
    'Index\(|db_index|index=True|CREATE (UNIQUE )?INDEX|create_index|unique_together|indexes\s*=' \
    "py" "-i"

  scan_pattern "Connection pooling" \
    'pool|connectionPool|maxConnections|max_connections' \
    "ts" "-i"

  scan_pattern "Connection pooling (Python)" \
    'pool|max_connections|max_overflow|pool_pre_ping|CONN_MAX_AGE' \
    "py" "-i"

  scan_pattern "Caching" \
    'cache|Cache|redis|Redis|memcached' \
    "ts" "-i"

  scan_pattern "Caching (Python)" \
    'cache|redis|memcached|lru_cache' \
    "py" "-i"

  scan_pattern "N+1 query patterns (loop with await)" \
    'for.*await.*find|forEach.*await.*query|map.*await.*get' \
    "ts"

  scan_py_block "N+1 query patterns (queries inside a for loop) (Python)" \
    'ORM/DB/awaited fetch calls inside a for loop body' \
    '^[ \t]*(async[ \t]+)?for[ \t].*[ \t]in[ \t].*:[ \t]*(#.*)?$' \
    '\.objects\.(get|filter)\(|session\.(query|execute|get)\(|cursor\.(execute|executemany)\(|await .*\.(get|find|filter|first|fetch[a-z_]*|execute|query)\(|\.(fetchone|fetchall)\('

  # --- Dimension 3: Operations ---
  echo "## Dimension 3: Operations"
  echo ""

  scan_pattern "Structured logging (Pino)" \
    'pino|createLogger|getLogger' \
    "ts" "-i"

  scan_pattern "Structured logging (structlog, loguru, logging config) (Python)" \
    'structlog|loguru|getLogger|dictConfig|basicConfig|jsonlogger' \
    "py" "-i"

  scan_pattern "Error tracking integration (SDK)" \
    'Sentry|sentry|bugsnag|rollbar|datadog' \
    "ts" "-i"

  scan_pattern "Error tracking integration (SDK) (Python)" \
    'Sentry|sentry|bugsnag|rollbar|datadog' \
    "py" "-i"

  # "issues" catches the JSON form, where the key sits on its own line under "observability".
  scan_wrangler "Workers-native error tracking (wrangler config)" \
    'upload_source_maps|observability|head_sampling_rate|"issues"'

  scan_pattern "Browser error beacon" \
    'unhandledrejection|window\.onerror|addEventListener\(.error' \
    "ts" "-i"

  scan_pattern "Health check endpoints" \
    'health|healthz|readyz|livez' \
    "ts" "-i"

  scan_pattern "Health check endpoints (Python)" \
    'health|healthz|readyz|livez' \
    "py" "-i"

  scan_pattern "Version surfacing and build-identity stamping" \
    '/version|buildSha|GIT_SHA|COMMIT_SHA|BUILD_ID|GITHUB_SHA|__APP_VERSION__|version_metadata|org\.opencontainers\.image\.(version|revision)|rev-parse' \
    "ts"

  scan_pattern "Version surfacing and build-identity stamping (Python)" \
    '/version|build_?sha|GIT_SHA|COMMIT_SHA|BUILD_ID|GITHUB_SHA|__version__|importlib\.metadata|version_metadata|org\.opencontainers\.image\.(version|revision)|rev-parse' \
    "py"

  scan_pattern "Hardcoded placeholder versions" \
    "version['\"]?\s*[:=]\s*['\"](0\.0\.0|dev|unknown)['\"]|['\"]0\.0\.0['\"]" \
    "ts"

  scan_pattern "Hardcoded placeholder versions (Python)" \
    "version['\"]?\s*[:=]\s*['\"](0\.0\.0|dev|unknown)['\"]|['\"]0\.0\.0['\"]" \
    "py"

  scan_pyproject_version

  scan_pattern "Error tracker release tag" \
    'release\s*:' \
    "ts"

  scan_pattern "Error tracker release tag (Python)" \
    'release\s*=' \
    "py"

  echo "### Version and changelog files"
  echo "| Check | Path | Exists? |"
  echo "|-------|------|---------|"
  check_exists "Root VERSION file (optional when a manifest is the source)" "VERSION"
  check_exists "Changelog" "CHANGELOG.md"
  echo ""

  scan_pattern "Graceful shutdown" \
    'SIGTERM|SIGINT|graceful|shutdown' \
    "ts" "-i"

  scan_pattern "Graceful shutdown (Python)" \
    'SIGTERM|SIGINT|graceful|shutdown|signal\.signal|lifespan|atexit' \
    "py" "-i"

  # --- Dimension 4: Compliance ---
  echo "## Dimension 4: Compliance"
  echo ""

  scan_pattern "GDPR / privacy references" \
    'gdpr|GDPR|privacy|data.retention|deletion.request|right.to.forget' \
    "ts" "-i"

  scan_pattern "GDPR / privacy references (Python)" \
    'gdpr|privacy|data.retention|deletion.request|right.to.forget' \
    "py" "-i"

  scan_pattern "Audit trail logging" \
    'audit|auditLog|audit_log' \
    "ts" "-i"

  scan_pattern "Audit trail logging (Python)" \
    'audit' \
    "py" "-i"

  scan_pattern "Cookie consent" \
    'cookie.consent|cookieConsent|cookie.banner' \
    "ts" "-i"

  # --- Dimension 5: Observability ---
  echo "## Dimension 5: Observability"
  echo ""

  scan_pattern "Request tracing (trace IDs)" \
    'traceId|trace.id|requestId|request.id|correlationId|x-request-id' \
    "ts" "-i"

  scan_pattern "Request tracing (trace IDs) (Python)" \
    'trace.?id|request.?id|correlation.?id|x-request-id|contextvars' \
    "py" "-i"

  scan_pattern "Metrics collection" \
    'metrics|prometheus|statsd|opentelemetry|OTEL' \
    "ts" "-i"

  scan_pattern "Metrics collection (Python)" \
    'metrics|prometheus|statsd|opentelemetry|OTEL' \
    "py" "-i"

  scan_pattern "Alerting configuration" \
    'alert|pagerduty|opsgenie|webhook.*notify' \
    "ts" "-i"

  scan_pattern "Alerting configuration (Python)" \
    'alert|pagerduty|opsgenie|webhook.*notify' \
    "py" "-i"

  # --- Dimension 6: Deployment ---
  echo "## Dimension 6: Deployment"
  echo ""

  scan_pattern "CI/CD configuration" \
    'workflow|pipeline|deploy' \
    "yaml"

  if $PRINT_PY; then
    scan_pattern "CI steps for Python (pytest, ruff, mypy, uv, poetry)" \
      'pytest|ruff|mypy|pyright|flake8|tox|nox|uv (sync|run)|poetry install|pip install' \
      "yaml"

    python_manifests

    echo "### Python tests"
    echo "| Check | Path | Exists? |"
    echo "|-------|------|---------|"
    check_exists_any "Tests directory (Python)" d tests test
    check_exists_any "pytest fixtures (Python)" f conftest.py
    check_exists "pytest config (Python)" "pytest.ini"
    check_exists "tox config (Python)" "tox.ini"
    echo ""
  fi

  scan_pattern "Test functions and fixtures - pytest/unittest (Python)" \
    '^\s*(async )?def test_|@pytest\.|class Test\w+|unittest\.TestCase' \
    "py"

  scan_pattern "Database migrations" \
    'migrate|migration|drizzle-kit' \
    "ts" "-i"

  scan_pattern "Database migrations (Python)" \
    'alembic|migrate|migration|makemigrations' \
    "py" "-i"

  scan_pattern "Feature flags" \
    'featureFlag|feature.flag|unleash|launchDarkly|flagsmith' \
    "ts" "-i"

  scan_pattern "Feature flags (Python)" \
    'feature.?flag|unleash|launchDarkly|flagsmith|waffle' \
    "py" "-i"

  scan_pattern "SSL/TLS references" \
    'ssl|tls|https|certificate' \
    "ts" "-i"

  scan_pattern "SSL/TLS references (Python)" \
    'ssl|tls|https|certificate' \
    "py" "-i"

  # --- Dimension 7: Documentation ---
  echo "## Dimension 7: Documentation"
  echo ""

  echo "| Check | Path | Exists? |"
  echo "|-------|------|---------|"

  check_exists "README" "README.md"
  check_exists "API docs (OpenAPI)" "openapi"
  check_exists "API docs (Swagger)" "swagger"
  check_exists "Architecture decisions" "docs/adr"
  check_exists "Runbooks" "docs/runbooks"
  check_exists "Contributing guide" "CONTRIBUTING.md"
  check_exists "CI/CD config" ".github/workflows"
  check_exists "Docker config" "Dockerfile"
  check_exists "Docker Compose" "docker-compose.yml"
  check_exists "Env example" ".env.example"
  echo ""

fi

echo "---"
echo "*Evidence collection complete. LLM judgment phase follows.*"
