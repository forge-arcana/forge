#!/usr/bin/env bash
# fold-purity-check.sh — Block project-specific leaks from entering the forge
#
# Scans staged forge content (learnings/, memory/) for leak patterns that violate
# the "No Project Names in Forge" HARD RULE. Designed to be invoked by /forge
# fold phase (3e, 3g) and the commit gate (3i).
#
# Usage:
#   bash fold-purity-check.sh <file> [<file> ...]    # scan specific files
#   bash fold-purity-check.sh --staged               # scan all staged files in forge
#   bash fold-purity-check.sh --commit-msg <text>    # scan a commit message string
#
# Exit codes:
#   0  — clean, no leaks detected
#   1  — leaks detected (output lists them); caller MUST block the write/commit
#   2  — script error (bad usage, missing dependencies)

set -uo pipefail

if [[ $# -eq 0 ]]; then
  echo "ERROR: usage: fold-purity-check.sh <file> [<file> ...] | --staged | --commit-msg <text>" >&2
  exit 2
fi

# Resolve forge root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Allowlist of capitalized terms that may legitimately appear ---
# Generic tech terms, well-known frameworks, regulations, regions.
# Add to this list as legitimate universal references emerge.
ALLOWLIST_TERMS=(
  # Languages & runtimes
  "TypeScript" "JavaScript" "Python" "Go" "Rust" "Java" "Ruby" "PHP" "Node" "Bun" "Deno"
  # Generic protocols / standards
  "HTTP" "HTTPS" "REST" "GraphQL" "WebSocket" "OAuth" "OIDC" "JWT" "TLS" "SSL" "DNS" "TCP" "UDP" "IP" "URL" "URI" "API"
  "CSS" "HTML" "JSON" "YAML" "XML" "SVG" "PDF" "UTF" "ASCII" "RFC" "ISO"
  "SQL" "NoSQL" "ORM" "CRUD" "ACID" "BASE"
  "GET" "POST" "PUT" "PATCH" "DELETE"
  "DOM" "SPA" "SSR" "CSR" "PWA" "CDN" "DDoS" "XSS" "CSRF" "CORS" "CSP" "MFA" "OTP" "SSO" "SAML" "RBAC" "ABAC" "PII" "GDPR" "CCPA" "LGPD" "DPA" "HIPAA" "SOC" "PCI"
  "AI" "ML" "LLM" "RAG" "GPU" "CPU" "RAM" "SSD" "OS" "VM" "VPN" "CI" "CD" "QA"
  # Cloud platforms (referenced as examples for generic patterns)
  "AWS" "GCP" "Azure" "Cloudflare" "Vercel" "Netlify" "Heroku" "Railway" "Render" "Fly" "DigitalOcean"
  # Generic AWS/GCP/Azure services (referenced as examples, not project lock-in)
  "S3" "EC2" "RDS" "DynamoDB" "Lambda" "SQS" "SNS" "IAM" "KMS"
  "Cloud" "Run" "Tasks" "Functions" "Storage" "Pub" "Sub" "Bigtable" "Spanner" "Firestore" "Firebase"
  # Regulations (region-named but universally referenced)
  "RA"  # Republic Act number prefix used in regulation references like "RA 10173"
  "EU" "US" "UK" "EEA" "APAC"
  # Common framework families (when discussed as examples)
  "React" "Vue" "Svelte" "Angular" "Next" "Nuxt" "Remix" "SolidJS" "Astro"
  "Express" "Hono" "Fastify" "Koa" "NestJS" "Django" "Flask" "Rails" "Spring"
  "Postgres" "PostgreSQL" "MySQL" "SQLite" "MongoDB" "Redis" "Memcached" "Kafka" "RabbitMQ" "Elasticsearch"
  "Drizzle" "Prisma" "TypeORM" "Sequelize" "SQLAlchemy"
  "Vite" "Webpack" "Rollup" "esbuild" "Turborepo" "Nx"
  "Vitest" "Jest" "Playwright" "Cypress" "Mocha" "Pytest"
  "Tailwind" "Stripe" "PayPal" "Twilio" "SendGrid" "Resend" "Auth0" "Better"  # Better Auth
  "Docker" "Kubernetes" "Terraform" "Ansible" "GitHub" "GitLab" "Bitbucket"
  # Forge mythology + Claude tools
  "Smith" "Warden" "Forge" "Anthropic" "Claude" "WebSearch" "WebFetch" "AskUserQuestion" "TodoWrite"
  # Forge artifact names (canonical lineage and Wedge intermediates; "WedgeBrief" is a retired predecessor of SoulBrief, kept for historical references)
  "SoulBrief" "WedgeBrief" "DirectionCards" "PreviewTouchstone" "ChosenDirection" "PitchCritique"
  # Claude Code hook event names (referenced in technical content)
  "SessionStart" "SessionEnd" "PreToolUse" "PostToolUse" "PermissionRequest" "Stop" "Notification" "UserPromptSubmit"
  # Web APIs / browser standards (well-known compound names)
  "WebSocket" "WebSockets" "WebView" "WebRTC" "WebGL" "WebGPU" "WebAssembly" "WebAuthn" "WebCrypto"
  "AudioContext" "MediaStream" "MediaRecorder" "RTCPeerConnection" "IndexedDB" "LocalStorage" "SessionStorage"
  "NotAllowedError" "TypeError" "RangeError" "SyntaxError" "ReferenceError"
  "DevTools" "HttpOnly" "SameSite"
  # Android / iOS API names commonly referenced
  "MainActivity" "BridgeActivity" "WindowCompat" "StatusBar" "ViewController" "AppDelegate" "ActivityResult"
  # Common open-source projects / tools (referenced as examples, not project lock-in)
  "LibreOffice" "OpenOffice" "WordPress" "Drupal" "Joomla" "Shopify" "Magento"
  "TanStack" "TanStackQuery" "Zustand" "Jotai" "Recoil" "MobX"
  "PayMongo" "Xendit" "Razorpay" "Mollie" "Adyen" "Square" "Stripe" "Wise" "Revolut"
  "OpenAI" "GoogleAI" "AnthropicSDK" "HuggingFace" "LangChain" "LlamaIndex"
  "GitHub" "GitLab" "Bitbucket" "Bitwarden"
  "Gotenberg" "Puppeteer" "Patchright" "CodeCov" "SonarQube"
  # Generic CamelCase patterns that appear in code-heavy learning docs
  "ReadMe" "FullStack" "FrontEnd" "BackEnd" "DevOps" "MLOps" "DataOps" "FinOps" "GitOps"
  "GraphiQL" "Swagger" "OpenAPI" "AsyncAPI"
  # Naming convention names (used meta-textually in learnings about code style)
  "CamelCase" "PascalCase" "SnakeCase" "KebabCase" "ScreamingSnakeCase"
  # Placeholder words used in describing patterns (meta-references)
  "Firstname" "Lastname" "Foo" "Bar" "Baz" "Qux" "Quux"
  # Common day/time markers
  "Day" "Phase" "MVP" "POC" "RFC" "TBD" "TODO" "WIP"
)

# Build a single regex pattern of allowlist terms (word boundaries)
# We use grep -wF semantics by joining with | and matching word-bounded.
ALLOWLIST_PATTERN=""
for term in "${ALLOWLIST_TERMS[@]}"; do
  if [[ -z "$ALLOWLIST_PATTERN" ]]; then
    ALLOWLIST_PATTERN="$term"
  else
    ALLOWLIST_PATTERN="$ALLOWLIST_PATTERN|$term"
  fi
done

# --- Leak patterns ---
# Each pattern returns matching lines for inclusion in the violation report.

LEAKS_FOUND=0
REPORT=""

scan_file_or_text() {
  local label="$1"   # display label (filename or "<commit message>")
  local content="$2" # the actual content to scan

  local file_violations=""

  # Strip heading lines (start with #) and code-fenced blocks before name detection.
  # Headings have lots of Title Case False Positives; code blocks have legitimate identifiers.
  local body
  body=$(echo "$content" | awk '
    /^```/ { in_code = !in_code; next }
    in_code { next }
    /^[[:space:]]*#/ { next }
    { print }
  ')

  # 1. Currency-symbol prices: ₱ $ € £ ¥ followed by digits
  # The dollar/euro/pound sign + digits is a near-certain leak (no legitimate universal usage).
  local currency_hits
  currency_hits=$(echo "$content" | grep -nE '[₱$€£¥][0-9]+' || true)
  if [[ -n "$currency_hits" ]]; then
    file_violations+="  CURRENCY (specific local price):"$'\n'
    file_violations+="$(echo "$currency_hits" | sed 's/^/    /')"$'\n'
  fi

  # 2. Attribution lines: "Forge-worthy: ... contributor: <Name>" or "(<X> session, YYYY-MM-DD)"
  local attribution_hits
  attribution_hits=$(echo "$content" | grep -nE 'Forge-worthy:.*contributor:|contributor:[[:space:]]*[A-Z][a-z]+ [A-Z][a-z]+|\(.*[Ss]ession,[[:space:]]*[0-9]{4}-[0-9]{2}-[0-9]{2}\)' || true)
  if [[ -n "$attribution_hits" ]]; then
    file_violations+="  ATTRIBUTION (contributor/session metadata leaked into content):"$'\n'
    file_violations+="$(echo "$attribution_hits" | sed 's/^/    /')"$'\n'
  fi

  # 3. CamelCase identifiers in body — multi-capital compound words like "LegitCheck", "MyApp"
  # Single-capital words at sentence starts are common English; we only flag mid-word capitals.
  # Pattern: word with 2+ uppercase letters and at least one lowercase, not matching common acronym shape.
  local camelcase_hits
  camelcase_hits=$(echo "$body" \
    | grep -oE '\b[A-Z][a-z]+[A-Z][a-zA-Z]+\b' \
    | sort -u \
    | grep -vwE "$ALLOWLIST_PATTERN" \
    || true)
  if [[ -n "$camelcase_hits" ]]; then
    file_violations+="  CAMELCASE (compound proper nouns — likely project/product names):"$'\n'
    file_violations+="$(echo "$camelcase_hits" | sed 's/^/    /')"$'\n'
  fi

  # 4. Backticked identifiers — `references`, `submittedIp`, `fraud_score` etc.
  # These are almost always project-specific schema/field names. Allowlist a few generic ones.
  local backtick_hits
  backtick_hits=$(echo "$body" \
    | grep -oE '`[a-z][a-zA-Z_]*[A-Z][a-zA-Z_]*`|`[a-z][a-z_]+_[a-z_]+`' \
    | sort -u \
    | grep -vE '`(camelCase|snake_case|kebab-case|env_var|api_key|access_token|refresh_token|node_modules|user_id|created_at|updated_at|deleted_at|expiresAt|invalid_grant|client_id|client_secret|grant_type|expires_in|token_type|id_token|scope|state|redirect_uri|code_verifier|code_challenge|cf_clearance|cf-mitigated|head_limit|output_mode|files_with_matches|forge-path|file_path)`' \
    || true)
  if [[ -n "$backtick_hits" ]]; then
    file_violations+="  BACKTICKED-IDENTIFIER (project-specific schema/field names — universalize the principle, drop the names):"$'\n'
    file_violations+="$(echo "$backtick_hits" | sed 's/^/    /')"$'\n'
  fi

  # 5. Personal-name pattern: "Firstname Lastname" in body (excluding allowed two-word phrases)
  # Skip headings (already stripped). Filter:
  #   - Known two-word tech phrases
  #   - Determiner + noun-phrase patterns (Any/Every/All/Each/Some/No/Many/Few/Most + Word)
  #   - Lines that are structural markers (Apply when:, etc.)
  local personal_name_hits
  personal_name_hits=$(echo "$body" \
    | grep -vE '^\*\*(Apply when|Forge-worthy|Why|How to apply|Learning)\*\*' \
    | grep -nE '\b[A-Z][a-z]+ [A-Z][a-z]+\b' \
    | grep -vE '\b(Any|Every|All|Each|Some|No|Many|Few|Most|Both|This|That|These|Those|My|Our|Your|Their|The) [A-Z][a-z]+' \
    | grep -vE '^\s*(Add|Update|Remove|Fix|Ship|Refactor|Move|Rename|Drop|Bump|Tighten|Loosen|Promote|Cleanse|Polish|Generalize|Absorb|Document|Note|Wire|Unify|Split|Merge|Archive|Resurrect) [A-Z][a-z]+' \
    | grep -vE '\b(Add|Update|Remove|Fix|Ship|Refactor|Bump|Tighten|Polish|Generalize|Absorb|Document|Note|Wire|Unify|Promote) [A-Z][a-z]+ [0-9]' \
    | grep -vE 'Cloud Run|Cloud Tasks|Cloud Storage|Cloud Functions|Cloud SQL|Cloud Spanner|Cloud Pub|Cloud Build|Better Auth|Pub Sub|Service Bus|Lambda Function|Open Source|Active Directory|Big Query|Data Lake|Side Effect|Dead Letter|Last Known|Last Modified|Last Verified|First Class|First Party|Single Sign|Two Factor|Multi Factor|Plain Text|Rich Text|Cross Platform|Cross Origin|Same Origin|Source Of|Out Of|Ahead Of|Behind The|Day One|Phase One|Phase Two|Phase Three|Read Me|Markdown File|Test Driven|Domain Driven|Event Driven|Type Script|Java Script|Web Sockets|Server Sent|Edge Cases|Use Case|Side Project|Republic Act|Data Privacy|Personal Information|Personal Data|Sensitive Personal|Magic Link|Magic Links|Service Account|Service Accounts|Service Identity|Pre Generated|Per Event|Per Check|Per Request|Per Hour|Per Day|Per Year|Per Month|Per User|Per Tenant|Per Customer|Per Page|Auto Scaling|Cold Start|Hot Path|Happy Path|Edge Case|Best Practice|Anti Pattern|Black Box|Black List|White List|Open Source|Closed Source|Quality Gate|Quality Gates|Status Code|Status Codes|Token Refresh|Refresh Token|Republic Act|Firstname Lastname|Foo Bar|Master Builder|Master Aesthetic|Master Tender|Master of|The Smith|The Wedge|The Warden|The Master|The Masters|Smith Master|Wedge Master|Warden Master|Pre Flight|Post Flight' \
    || true)
  if [[ -n "$personal_name_hits" ]]; then
    file_violations+="  PERSONAL-NAME (Firstname Lastname pattern in body — verify not a person):"$'\n'
    file_violations+="$(echo "$personal_name_hits" | sed 's/^/    /')"$'\n'
  fi

  if [[ -n "$file_violations" ]]; then
    REPORT+=$'\n'"$label:"$'\n'"$file_violations"
    LEAKS_FOUND=1
  fi
}

# --- Mode dispatch ---
if [[ "$1" == "--commit-msg" ]]; then
  shift
  if [[ $# -eq 0 ]]; then
    echo "ERROR: --commit-msg requires the message text as next argument" >&2
    exit 2
  fi
  scan_file_or_text "<commit message>" "$*"

elif [[ "$1" == "--staged" ]]; then
  STAGED_FILES=$(git -C "$FORGE_DIR" diff --cached --name-only | grep -E '^(learnings/|memory/)' | grep -vE '/\.[^/]+$' || true)
  if [[ -z "$STAGED_FILES" ]]; then
    exit 0  # nothing relevant staged
  fi
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    [[ ! -f "$FORGE_DIR/$f" ]] && continue
    # Get only the staged hunks (additions) — we only care about new content
    added_lines=$(git -C "$FORGE_DIR" diff --cached "$f" | grep -E '^\+' | grep -vE '^\+\+\+' | sed 's/^+//')
    [[ -z "$added_lines" ]] && continue
    scan_file_or_text "$f (staged additions)" "$added_lines"
  done <<< "$STAGED_FILES"

else
  for f in "$@"; do
    if [[ ! -f "$f" ]]; then
      echo "WARN: file not found, skipping: $f" >&2
      continue
    fi
    content=$(cat "$f")
    scan_file_or_text "$f" "$content"
  done
fi

# --- Output ---
if [[ "$LEAKS_FOUND" -eq 1 ]]; then
  echo "═══════════════════════════════════════════════════════════════════════"
  echo "  FORGE PURITY CHECK — VIOLATIONS DETECTED"
  echo "═══════════════════════════════════════════════════════════════════════"
  echo ""
  echo "The HARD RULE 'No Project Names in Forge' has been violated."
  echo "See <forge>/CLAUDE.md and <forge>/learnings/global-patterns.md"
  echo "(Exhibit A: 'How a Project-Name Leak Happens') for context."
  echo ""
  echo "Violations:"
  echo "$REPORT"
  echo ""
  echo "Required actions:"
  echo "  1. Genericize the flagged content — strip project name, contributor name,"
  echo "     local currency, project-specific schema/table names, competitor names."
  echo "  2. If a flagged term is a legitimate universal reference (e.g., a well-known"
  echo "     tech), add it to ALLOWLIST_TERMS in scripts/fold-purity-check.sh."
  echo "  3. Re-run this script until it exits clean."
  echo ""
  exit 1
fi

exit 0
