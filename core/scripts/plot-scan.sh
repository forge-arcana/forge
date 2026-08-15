#!/usr/bin/env bash
# plot-scan.sh — Topology evidence collection for /plot (the Atlas)
# Usage: plot-scan.sh [project-path]
# Outputs structured markdown: deployable units, dependency surfaces, external
# integrations, data stores, and route/handler entry points — the raw
# evidence /plot's facet subagents turn into a node/edge topology.
#
# Portable: Linux, macOS, Windows (Git Bash / WSL).
# Requires: bash >=3.2, awk. Uses ripgrep (rg) if available, falls back to grep.
# Read-only. Never prints .env values, only key names.
set -euo pipefail

PROJECT="${1:-.}"

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

# --- Lean output: compress sample-match blocks before they fan out to
# subagents. Counts are computed separately and stay exact; only the
# displayed samples are de-noised. Source the Tier-1 compressor. ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lean.sh
source "$SCRIPT_DIR/lean.sh"
lean_samples() { lean_filter 160 "$PROJECT" on; }

# Common noise directories to exclude from every find/grep.
PRUNE_DIRS=(-name node_modules -o -name .git -o -name dist -o -name build -o -name venv -o -name .venv -o -name __pycache__ -o -name .next -o -name target)

echo "## Plot Scan Report"
echo "**Project**: \`$PROJECT\`"
echo "**Search tool**: $(if $USE_RG; then echo "ripgrep"; else echo "grep (fallback)"; fi)"
echo ""

# Helper: find directories matching one or more glob names (bounded depth,
# common noise dirs pruned), print relative paths, or a "none found" note.
find_dirs() {
  local label="$1"
  shift
  local -a name_args=()
  local first=true
  for pat in "$@"; do
    if $first; then
      name_args+=(-name "$pat")
      first=false
    else
      name_args+=(-o -name "$pat")
    fi
  done

  local results
  results=$(find "$PROJECT" \( "${PRUNE_DIRS[@]}" \) -prune -o -maxdepth 6 -type d \( "${name_args[@]}" \) -print 2>/dev/null \
    | sed "s|^$PROJECT/||" | sort)

  echo "### $label"
  if [[ -n "$results" ]]; then
    echo '```'
    echo "$results" | head -40
    echo '```'
  else
    echo "*none found*"
  fi
  echo ""
}

# Helper: find files matching one or more glob patterns (bounded depth,
# common noise dirs pruned), print relative paths, or a "none found" note.
find_globs() {
  local label="$1"
  shift
  local -a name_args=()
  local first=true
  for pat in "$@"; do
    if $first; then
      name_args+=(-name "$pat")
      first=false
    else
      name_args+=(-o -name "$pat")
    fi
  done

  local results
  results=$(find "$PROJECT" \( "${PRUNE_DIRS[@]}" \) -prune -o -maxdepth 6 -type f \( "${name_args[@]}" \) -print 2>/dev/null \
    | sed "s|^$PROJECT/||" | sort)

  echo "### $label"
  if [[ -n "$results" ]]; then
    echo '```'
    echo "$results" | head -40
    local n
    n=$(echo "$results" | wc -l | tr -d ' ')
    if [[ "$n" -gt 40 ]]; then
      echo "… ($n total, showing first 40)"
    fi
    echo '```'
  else
    echo "*none found*"
  fi
  echo ""
}

# Helper: run a pattern search across the whole tree and print sample lines
# (no file-type restriction — topology evidence is polyglot).
scan_pattern() {
  local label="$1"
  local pattern="$2"
  local case_flag="${3:-}"

  local count=0
  local matches=""

  if $USE_RG; then
    local rg_args=()
    [[ "$case_flag" == "-i" ]] && rg_args+=("-i")
    matches=$(rg "${rg_args[@]}" -n "$pattern" "$PROJECT" \
      -g '!node_modules' -g '!.git' -g '!dist' -g '!build' -g '!venv' -g '!.venv' -g '!__pycache__' -g '!.next' -g '!target' \
      2>/dev/null || true)
  else
    local grep_args=("-rn" "-E")
    [[ "$case_flag" == "-i" ]] && grep_args+=("-i")
    grep_args+=("--exclude-dir=node_modules" "--exclude-dir=.git" "--exclude-dir=dist" "--exclude-dir=build" "--exclude-dir=venv" "--exclude-dir=.venv" "--exclude-dir=__pycache__" "--exclude-dir=.next" "--exclude-dir=target")
    matches=$(grep "${grep_args[@]}" "$pattern" "$PROJECT" 2>/dev/null || true)
  fi

  count=$(printf '%s' "$matches" | grep -c '.' 2>/dev/null || echo 0)
  [[ -z "$matches" ]] && count=0

  echo "### $label"
  echo "**Pattern**: \`$pattern\` | **Matches**: $count"
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

# ============================================================
# SECTION 1 — Deployable units & deploy targets
# ============================================================
echo "# Deployable Units & Deploy Targets"
echo ""

find_globs "Container / compose" \
  "Dockerfile" "Dockerfile.*" "docker-compose*.yml" "docker-compose*.yaml"

find_globs "Platform-specific deploy configs" \
  "fly.toml" "vercel.json" "wrangler.toml" "wrangler.jsonc" "railway.json" "railway.toml" \
  "render.yaml" "netlify.toml" "app.yaml" "cloudbuild.yaml" "Procfile" \
  "serverless.yml" "serverless.yaml"

find_globs "Kamal / Hetzner-style deploy" \
  "deploy.yml"

find_globs "Kubernetes manifests" \
  "*.k8s.yaml" "*.k8s.yml" "kustomization.yaml"

find_globs "Infra-as-code" \
  "*.tf" "Pulumi.yaml" "Pulumi.yaml.*"

echo "### GitHub Actions workflows (deploy-related)"
if [[ -d "$PROJECT/.github/workflows" ]]; then
  deploy_workflows=$(grep -lRiE 'deploy|release|publish' "$PROJECT/.github/workflows" 2>/dev/null | sed "s|^$PROJECT/||" || true)
  if [[ -n "$deploy_workflows" ]]; then
    echo '```'
    echo "$deploy_workflows"
    echo '```'
  else
    echo "*workflows present but none look deploy-related by name/content*"
  fi
else
  echo "*absent — no \`.github/workflows\` directory*"
fi
echo ""

scan_pattern "K8s manifest hints (kind: Deployment/Service/CronJob)" 'kind:\s*(Deployment|Service|CronJob|StatefulSet|Job)' "-i"

# ============================================================
# SECTION 2 — Dependency surfaces
# ============================================================
echo "# Dependency Surfaces"
echo ""

find_globs "JS/TS package manifests" \
  "package.json" "pnpm-workspace.yaml"

find_globs "Python project manifests" \
  "pyproject.toml" "requirements*.txt" "Pipfile" "setup.py"

find_globs "Go / Rust / Ruby / PHP manifests" \
  "go.mod" "Cargo.toml" "Gemfile" "composer.json"

echo "### Workspace / monorepo package layout"
if [[ -f "$PROJECT/package.json" ]] && command -v jq &>/dev/null; then
  workspaces=$(jq -r '.workspaces // empty' "$PROJECT/package.json" 2>/dev/null || true)
  if [[ -n "$workspaces" && "$workspaces" != "null" ]]; then
    echo "**\`package.json\` workspaces**:"
    echo '```'
    echo "$workspaces"
    echo '```'
  fi
fi
if [[ -f "$PROJECT/pyproject.toml" ]]; then
  ws=$(grep -A5 -E '\[tool\.(uv\.workspace|poetry\.group|hatch\.envs)|\[tool\.rye\.workspace\]' "$PROJECT/pyproject.toml" 2>/dev/null || true)
  if [[ -n "$ws" ]]; then
    echo "**\`pyproject.toml\` workspace/tool sections**:"
    echo '```'
    echo "$ws" | lean_samples
    echo '```'
  fi
fi
if [[ ! -f "$PROJECT/package.json" && ! -f "$PROJECT/pyproject.toml" ]]; then
  echo "*no package.json or pyproject.toml at project root*"
fi
echo ""

# ============================================================
# SECTION 3 — External integrations
# ============================================================
echo "# External Integrations"
echo ""

echo "### Env keys (names only — values never printed)"
env_files=$(find "$PROJECT" \( "${PRUNE_DIRS[@]}" \) -prune -o -maxdepth 4 -type f \( -name ".env.example" -o -name ".env.sample" -o -name ".env.template" \) -print 2>/dev/null)
if [[ -n "$env_files" ]]; then
  for f in $env_files; do
    rel="${f#$PROJECT/}"
    echo "**\`$rel\`**:"
    echo '```'
    grep -oE '^[A-Za-z_][A-Za-z0-9_]*' "$f" 2>/dev/null | sort -u | head -60
    echo '```'
  done
else
  echo "*absent — no \`.env.example\` / \`.env.sample\` / \`.env.template\` found*"
fi
echo ""

echo "### Vendor SDK dependencies (payment, auth, email, storage, queue, observability)"
vendor_pattern='stripe|paddle|lemonsqueezy|braintree|paypal|auth0|clerk|firebase-auth|next-auth|okta|supabase|sendgrid|postmark|resend|mailgun|nodemailer|twilio|aws-sdk|@aws-sdk|google-cloud/storage|@google-cloud|cloudflare|r2|s3|gcs|bullmq|bull|sqs|rabbitmq|amqplib|kafkajs|sentry|@sentry|datadog|dd-trace|newrelic|opentelemetry|posthog|segment|mixpanel|amplitude|openai|anthropic|@anthropic-ai|langchain|pinecone|weaviate|twilio'
found_vendor=""
for depfile in package.json pyproject.toml requirements.txt requirements-prod.txt Gemfile Cargo.toml go.mod composer.json; do
  fpath="$PROJECT/$depfile"
  if [[ -f "$fpath" ]]; then
    hits=$(grep -oiE "$vendor_pattern" "$fpath" 2>/dev/null | tr '[:upper:]' '[:lower:]' | sort -u || true)
    if [[ -n "$hits" ]]; then
      found_vendor="yes"
      echo "**\`$depfile\`**:"
      echo '```'
      echo "$hits"
      echo '```'
    fi
  fi
done
if [[ -z "$found_vendor" ]]; then
  echo "*no recognized vendor SDK names in dependency manifests at project root*"
fi
echo ""

# ============================================================
# SECTION 4 — Data stores
# ============================================================
echo "# Data Stores"
echo ""

find_globs "ORM / schema files" \
  "schema.prisma" "*.drizzle.ts" "alembic.ini" "models.py"

find_dirs "Migration / drizzle directories (by convention name)" \
  "migrations" "migrate" "drizzle" "alembic"

echo "### DB / cache connection env-key names"
if [[ -n "${env_files:-}" ]]; then
  for f in $env_files; do
    hits=$(grep -oE '^[A-Za-z_]*(DATABASE|DB|POSTGRES|MYSQL|MONGO|REDIS|SQLITE)[A-Za-z_]*' "$f" 2>/dev/null | sort -u || true)
    if [[ -n "$hits" ]]; then
      echo '```'
      echo "$hits"
      echo '```'
    fi
  done
else
  echo "*no env-example files to inspect*"
fi
echo ""

scan_pattern "ORM / driver client imports (JS/TS)" \
  "from ['\"](drizzle-orm|@prisma/client|prisma|mongoose|pg|mysql2|ioredis|redis|knex|typeorm)['\"]"

scan_pattern "ORM / driver imports (Python)" \
  "^\s*(from|import)\s+(sqlalchemy|django\.db|psycopg2|pymongo|redis|asyncpg)"

# ============================================================
# SECTION 5 — Entry points / routes
# ============================================================
echo "# Entry Points & Routes"
echo ""

echo "## JS/TS route patterns"

find_globs "File-based routing directories" \
  "route.ts" "route.tsx" "route.js" "+server.ts" "+page.server.ts"

scan_pattern "Express/Hono/Fastify handler registration" \
  "\b(app|router|server|api)\.(get|post|put|patch|delete)\(\s*['\"/]"

scan_pattern "Next.js API route handlers" \
  "export\s+(async\s+)?function\s+(GET|POST|PUT|PATCH|DELETE)\b"

echo "## Python route patterns"

scan_pattern "FastAPI route decorators" \
  "@(app|router)\.(get|post|put|patch|delete|websocket)\("

scan_pattern "Flask route decorators" \
  "@app\.route\("

find_globs "Django URL config" \
  "urls.py"

scan_pattern "Django path()/re_path() registrations" \
  "^\s*(path|re_path)\("

scan_pattern "Async handler defs (Python)" \
  "^\s*async def (get|post|put|patch|delete)_?\w*\("

echo "## Go http handlers"

scan_pattern "net/http or common router registration" \
  "\.(HandleFunc|Handle|GET|POST|PUT|PATCH|DELETE)\(\s*[\"\`]"

echo "---"
echo "*Evidence collection complete. LLM facet-derivation phase follows.*"
