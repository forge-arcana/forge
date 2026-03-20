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

echo "## Forge Scan Report"
echo "**Type**: $SCAN_TYPE | **Project**: \`$PROJECT\`"
echo "**Search tool**: $(if $USE_RG; then echo "ripgrep"; else echo "grep (fallback)"; fi)"
echo ""

# Map a type name to a grep --include glob list.
# rg uses --type ts; grep needs --include='*.ts' --include='*.tsx' etc.
type_to_includes() {
  case "$1" in
    ts)   echo "*.ts *.tsx *.mts *.cts" ;;
    js)   echo "*.js *.jsx *.mjs *.cjs" ;;
    yaml) echo "*.yml *.yaml" ;;
    json) echo "*.json" ;;
    md)   echo "*.md *.mdx" ;;
    *)    echo "*.$1" ;;
  esac
}

# Helper: run search and report count + sample matches
# Args: label pattern [type_name] [extra: -i]
scan_pattern() {
  local label="$1"
  local pattern="$2"
  local type_name="${3:-ts}"
  local case_flag="${4:-}"

  local count=0

  if $USE_RG; then
    # Build rg args
    local rg_args=("--type" "$type_name")
    if [[ "$case_flag" == "-i" ]]; then
      rg_args+=("-i")
    fi

    # Count: rg -c prints file:count per file; awk sums them.
    # Pipeline may exit non-zero (pipefail) when rg finds 0 matches.
    count=$(rg "${rg_args[@]}" -c "$pattern" "$PROJECT" 2>/dev/null \
      | awk -F: '{s+=$NF} END {print s+0}') || count=0

    echo "### $label"
    echo "**Pattern**: \`$pattern\` | **Matches**: $count"

    if [[ "$count" -gt 0 ]]; then
      echo '```'
      rg "${rg_args[@]}" -n "$pattern" "$PROJECT" 2>/dev/null | head -20 || true
      echo '```'
      if [[ "$count" -gt 20 ]]; then
        echo "*($count total matches, showing first 20)*"
      fi
    fi
  else
    # grep fallback — build --include flags from type name
    local grep_args=("-rn" "-E")
    if [[ "$case_flag" == "-i" ]]; then
      grep_args+=("-i")
    fi
    local includes
    includes=$(type_to_includes "$type_name")
    for inc in $includes; do
      grep_args+=("--include=$inc")
    done

    # Exclude common noise directories
    grep_args+=("--exclude-dir=node_modules" "--exclude-dir=.git" "--exclude-dir=dist" "--exclude-dir=build")

    # Count matching lines
    count=$(grep "${grep_args[@]}" -c "$pattern" "$PROJECT" 2>/dev/null \
      | awk -F: '{s+=$NF} END {print s+0}') || count=0

    echo "### $label"
    echo "**Pattern**: \`$pattern\` | **Matches**: $count"

    if [[ "$count" -gt 0 ]]; then
      echo '```'
      grep "${grep_args[@]}" "$pattern" "$PROJECT" 2>/dev/null | head -20 || true
      echo '```'
      if [[ "$count" -gt 20 ]]; then
        echo "*($count total matches, showing first 20)*"
      fi
    fi
  fi
  echo ""
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

# ============================================================
# POKE SCAN — Tech debt evidence collection
# ============================================================
if [[ "$SCAN_TYPE" == "poke" ]]; then

  echo "# /poke Evidence Collection"
  echo ""

  # --- Dimension 1: Strategy Pattern Opportunities ---
  echo "## Dimension 1: Strategy Patterns"
  echo ""

  scan_pattern "Environment branching (NODE_ENV)" \
    "NODE_ENV|isDev|isProduction|isStaging" \
    "ts"

  scan_pattern "Switch/case chains (>3 cases)" \
    "case '" \
    "ts"

  scan_pattern "Feature flag if-statements" \
    "featureFlag|feature_flag|FEATURE_" \
    "ts" "-i"

  # --- Dimension 2: Band-Aids ---
  echo "## Dimension 2: Band-Aids"
  echo ""

  scan_pattern "Fallback chains (3+ links)" \
    '\|\|.*\|\|' \
    "ts"

  scan_pattern "Nullish coalescing chains" \
    '\?\?.*\?\?' \
    "ts"

  scan_pattern "Sentinel defaults ('unknown', 'default')" \
    "(\|\| ['\"]unknown['\"]|\?\? ['\"]default['\"]|\?\? ['\"]Unknown['\"]|\|\| ['\"]N/A['\"])" \
    "ts"

  scan_pattern "Unsafe casts (as any)" \
    'as any|as unknown' \
    "ts"

  scan_pattern "Non-null assertions (!.)" \
    '\w+!\.' \
    "ts"

  scan_pattern "Magic string comparisons" \
    "=== ['\"][a-z]+" \
    "ts"

  scan_pattern "Hardcoded URLs" \
    "https?://[a-z]" \
    "ts" "-i"

  scan_pattern "Hardcoded port numbers" \
    ':\d{4}[^0-9]' \
    "ts"

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

  # --- Dimension 3: Framework Misuse ---
  echo "## Dimension 3: Framework Misuse"
  echo ""

  scan_pattern "Manual query building (raw SQL)" \
    'sql`|\.execute\(|\.raw\(' \
    "ts"

  scan_pattern "Hand-rolled validation (manual checks)" \
    'typeof .* !== |typeof .* === ' \
    "ts"

  scan_pattern "Custom error classes" \
    'extends Error' \
    "ts"

  scan_pattern "Manual JSON parsing" \
    'JSON\.parse' \
    "ts"

  # --- Dimension 4: Logging Hygiene ---
  echo "## Dimension 4: Logging Hygiene"
  echo ""

  scan_pattern "Console.log usage (should use structured logger)" \
    'console\.(log|warn|error|info|debug)' \
    "ts"

  scan_pattern "Logger calls (structured logging)" \
    'logger\.(info|warn|error|debug|trace|fatal)' \
    "ts"

  scan_pattern "Pino redact configuration" \
    'redact' \
    "ts"

  scan_pattern "Health check endpoints" \
    'health|healthz|readyz|livez' \
    "ts" "-i"

  scan_pattern "Sensitive data in logs (password, token, secret)" \
    'password|token|secret|apiKey|api_key' \
    "ts" "-i"

  scan_pattern "Dev log endpoint" \
    '/api/dev/log|dev.log|browser_console' \
    "ts" "-i"

  # --- File structure checks ---
  echo "## Project Structure"
  echo ""
  echo "| Check | Path | Exists? |"
  echo "|-------|------|---------|"

  check_exists "Logging config" "src/lib/logger"
  check_exists "Dev log file" "logs/dev.log"
  check_exists "Logs directory" "logs"
  check_exists "Error tracking (Sentry)" ".sentryclirc"
  check_exists "Kill zombies script" "kill-zombies.sh"
  check_exists "Restart script" "restart.sh"
  echo ""

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

  scan_pattern "CSP headers" \
    "Content-Security-Policy|CSP|helmet" \
    "ts" "-i"

  scan_pattern "Rate limiting" \
    'rateLimit|rate.limit|throttle' \
    "ts" "-i"

  scan_pattern "Input validation (Zod schemas)" \
    'z\.(string|number|object|array|enum)\(' \
    "ts"

  scan_pattern "Hardcoded secrets" \
    "(password|secret|apiKey|api_key|token)\s*[:=]\s*['\"][^'\"]{8,}" \
    "ts" "-i"

  scan_pattern "SQL injection risk (string concatenation in queries)" \
    'sql`\$\{' \
    "ts"

  scan_pattern "CSRF protection" \
    'csrf|CSRF|xsrf' \
    "ts" "-i"

  # --- Dimension 2: Scalability ---
  echo "## Dimension 2: Scalability"
  echo ""

  scan_pattern "Database indexes" \
    'index\(|\.createIndex|CREATE INDEX|uniqueIndex' \
    "ts" "-i"

  scan_pattern "Connection pooling" \
    'pool|connectionPool|maxConnections|max_connections' \
    "ts" "-i"

  scan_pattern "Caching" \
    'cache|Cache|redis|Redis|memcached' \
    "ts" "-i"

  scan_pattern "N+1 query patterns (loop with await)" \
    'for.*await.*find|forEach.*await.*query|map.*await.*get' \
    "ts"

  # --- Dimension 3: Operations ---
  echo "## Dimension 3: Operations"
  echo ""

  scan_pattern "Structured logging (Pino)" \
    'pino|createLogger|getLogger' \
    "ts" "-i"

  scan_pattern "Error tracking integration" \
    'Sentry|sentry|bugsnag|rollbar|datadog' \
    "ts" "-i"

  scan_pattern "Health check endpoints" \
    'health|healthz|readyz|livez' \
    "ts" "-i"

  scan_pattern "Graceful shutdown" \
    'SIGTERM|SIGINT|graceful|shutdown' \
    "ts" "-i"

  # --- Dimension 4: Compliance ---
  echo "## Dimension 4: Compliance"
  echo ""

  scan_pattern "GDPR / privacy references" \
    'gdpr|GDPR|privacy|data.retention|deletion.request|right.to.forget' \
    "ts" "-i"

  scan_pattern "Audit trail logging" \
    'audit|auditLog|audit_log' \
    "ts" "-i"

  scan_pattern "Cookie consent" \
    'cookie.consent|cookieConsent|cookie.banner' \
    "ts" "-i"

  # --- Dimension 5: Observability ---
  echo "## Dimension 5: Observability"
  echo ""

  scan_pattern "Request tracing (trace IDs)" \
    'traceId|trace.id|requestId|request.id|correlationId|x-request-id' \
    "ts" "-i"

  scan_pattern "Metrics collection" \
    'metrics|prometheus|statsd|opentelemetry|OTEL' \
    "ts" "-i"

  scan_pattern "Alerting configuration" \
    'alert|pagerduty|opsgenie|webhook.*notify' \
    "ts" "-i"

  # --- Dimension 6: Deployment ---
  echo "## Dimension 6: Deployment"
  echo ""

  scan_pattern "CI/CD configuration" \
    'workflow|pipeline|deploy' \
    "yaml"

  scan_pattern "Database migrations" \
    'migrate|migration|drizzle-kit' \
    "ts" "-i"

  scan_pattern "Feature flags" \
    'featureFlag|feature.flag|unleash|launchDarkly|flagsmith' \
    "ts" "-i"

  scan_pattern "SSL/TLS references" \
    'ssl|tls|https|certificate' \
    "ts" "-i"

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
