# Stack Guide

A reference architecture for new projects. Derived from production decisions across multiple projects, refined through full rewrites.

**Core bias:** We favor technologies that AI coding assistants have deep familiarity with — maximizing AI-assisted development velocity. We will not sacrifice solution quality for this, but when two options are comparable, we pick the one most major models know best.

**Infrastructure bias (agentic era):** For hosting, data, and deploy we no longer optimize for *ease of human console management* — that criterion has faded now that agents drive day-2 ops via MCP servers, scoped tokens, and agent-operable CLIs. We optimize instead, in weighted order, for: **portability (container-first, no lock-in)** · **scale-to-zero / idle cost** · **egress economics at 10×/100×** · then **agentic-operability** as a tie-filter (now table-stakes — even GCP ships a Cloud Run MCP server, so it disqualifies laggards rather than breaking ties) · **credential safety** · **DR / residency / compliance** (an explicit line item, not an implicit DB property). GCP is no longer the mandatory default: Cloud Run is now one of two co-equal container defaults (with Cloudflare Containers), re-justified on merit. There is no single hosting winner — the **Hosting Decision Framework** below picks per project by scale and needs. The guardrail is container-first: capturing the agentic wins tempts proprietary primitives (Durable Objects, Vectorize) that are *tighter* lock-in than a portable container, so "more portable" only holds if we stay container-first. (Hyperdrive is lighter — a pass-through accelerator for standard Postgres; exit = repoint the connection string.)

---

## Stack Table

| Layer | Choice | Rationale |
|---|---|---|
| **Language** | TypeScript | Type safety DB-to-UI. AI assistants generate far better TS than JS — catch errors at write time, not runtime. |
| **Runtime** | Node.js | Stable, mature, universal tooling. Capacitor-compatible. The strongest backend runtime for AI-assisted work. |
| **Backend** | Hono | ESM-native, 14KB, typed routes, Zod middleware built-in. Express 5 is active, but Hono uses Web Standard APIs (portable to CF Workers, Deno, Bun) — that edge portability is why we default to it. Well-supported by current models. |
| **ORM** | Drizzle | No codegen, no engine binary (50KB vs Prisma's 2-3MB), SQL-like API, native pgvector support, faster cold starts. Schema-as-code in TypeScript. |
| **Auth** | Better Auth | Framework-agnostic, Drizzle adapter, signed sessions, refresh rotation, CSRF, plugins for 2FA/passkeys/RBAC/bearer. Replaces hand-rolled auth and NextAuth alike. |
| **Database** | PostgreSQL — Neon (default) | Neon for **all environments including production** — serverless, scale-to-zero, copy-on-write branch-per-PR (an agent runs migrations on a temp branch, then promotes — arguably safer than the human-console path), native pgvector. Cloud SQL and PlanetScale are situational escalations (see Database Strategy + DR/Residency). Drizzle abstracts the provider — only the connection string changes. |
| **Real-time** | Ably | Managed pub/sub with guaranteed delivery, automatic reconnection, message history, presence. Eliminates the entire class of Socket.io bugs (dropped connections, room leaks, reconnect storms). |
| **Frontend** | React 19 + Vite | Component model, hooks (use, useOptimistic, useFormStatus), massive ecosystem. The strongest frontend framework for AI-assisted work by far. Vite 8 (Rolldown — single Rust bundler, 10–30× faster builds) for sub-second HMR. |
| **Routing** | TanStack Router | Type-safe params + search validation, file-based routing, loaders, pending UI. Better TypeScript story than React Router. |
| **Server State** | TanStack Query | Caching, background refetch, optimistic updates, request deduplication, pagination. Essential for offline-first (3G users). |
| **Client State** | useState + React Context | TanStack Query handles server state. No Zustand/Redux needed — useState + context is sufficient for UI state. |
| **Forms** | React Hook Form + Zod | Performant (uncontrolled), Zod resolvers shared with backend validation. One schema, two runtimes. |
| **Styling** | Tailwind CSS v4 | Utility-first, consistent, fast to build. AI assistants generate Tailwind fluently — no class-naming debates. |
| **UI Components** | shadcn/ui | Copy-paste components (not a dependency), accessible, Tailwind-based. Buttons, modals, sheets, tables, forms — all pre-built. |
| **i18n** | Paraglide | Compile-time, zero runtime cost, fully typed (`m.key()` not `t('key')`). Typos caught by TypeScript. Ideal for 2-5 languages. |
| **Email** | Resend | Simple API, React Email templates, good deliverability. Transactional only (receipts, notifications, disputes). |
| **File Storage** | Cloudflare R2 (signed URLs) | S3-compatible presigned PUT/GET (SigV4, ≤7-day expiry; presigns work on the S3 API domain only, not custom domains) — a near-drop-in for the existing signed-URL flow, with **$0 internet egress** (the single biggest flat-scale lever; note Infrequent Access adds $0.01/GB retrieval, so hot/public objects stay on Standard). GCS stays valid only when compute is on Cloud Run *and* egress is low. |
| **Monitoring** | Sentry + Pino + OTLP backend | Sentry for error tracking, traces, source maps (`@sentry/cloudflare` exports to the edge too). Pino for structured logging **on Node only** — it breaks on workerd/edge, so it is a Node convenience, *not* the portability layer. The real portable seam is a vendor-neutral **OTLP backend** (Grafana Cloud / Honeycomb / Axiom): instrument once, export anywhere — and the most agent-operated layer in the stack. |
| **Mobile** | Capacitor | Native iOS/Android from React codebase. Camera, GPS, push notifications, haptics, secure storage — all via plugins. No React Native context-switching. |
| **PWA** | vite-plugin-pwa | Service worker + manifest generation. Works inside Capacitor WebView too. Network-first caching for 3G resilience. |
| **Package Manager** | pnpm | Faster, stricter (no phantom deps), disk-efficient. Monorepo workspaces built-in. |
| **Testing** | Vitest + Playwright | Vitest for unit + integration (fast, ESM-native, same config as Vite). Playwright for E2E (cross-browser, reliable). |
| **Hosting** | Container-first — Cloud Run / CF Containers (co-default) | One Node image serves API + static build (no CORS), portable across **Cloud Run, Cloudflare Containers, Fly, Railway** — the image ports cleanly; migration cost is config + platform glue, not an app rewrite. CF Containers (GA Apr 2026) needs a thin Worker + Durable Object shim in front (no direct HTTP ingress) and caps at 4 vCPU / 12 GiB per instance — fine for this stack's containers; Cloud Run scales larger per instance. **Hetzner** (cost / always-on / egress-heavy / EU residency), **Runpod** (GPU / self-hosted models), and **Workers-edge** (stateless latency-critical routes) are signal-driven escalations — see Hosting Decision Framework. |
| **CI/CD** | GitHub Actions | Tests, Docker build, **target-agnostic deploy leg** (parameterized registry + deploy step → Cloud Run / Fly / Railway / CF Containers), smoke test, promote. Keyless auth is the gold standard: GCP WIF, npm OIDC trusted publishing, per-run ~5-min OIDC tokens. |
| **Runtime Secrets** | Infisical | One source of truth for the ~10 long-lived runtime secrets (DB URL, Resend, Ably, Sentry DSN, Better Auth secret); open-core (MIT except enterprise `ee/`), official MCP server, native Secret Syncs to **CF Workers, GCP Secret Manager, GitHub, Fly.io, and Railway** — every hosting peer this guide names. App reads the native binding at runtime. Multi-provider multiplies native vaults — this keeps them in sync. WIF/OIDC trims the keyless subset; the residue (third-party SaaS keys) has no federation exchange and stays here. |

---

## Project Structure

All projects use a pnpm monorepo with 4 packages:

```
packages/
  shared/    — Types, Zod validations, constants, enums, utils
  database/  — Drizzle schema, migrations, client, seed
  server/    — Hono server, routes, services, middleware, auth
  web/       — Vite + React frontend, TanStack Router, components
scripts/     — Production scripts only (build, deploy, release, CI)
dev/         — Local dev tooling (restart.sh, kill-zombies.sh)
logs/        — Dev server output (gitignored)
```

For multi-role apps (e.g., customer + staff + admin), the `web/` package can be split:

```
packages/
  shared/
  database/
  server/
  customer/   — React + Capacitor (native mobile)
  staff/      — React + Capacitor (native mobile)
  admin/      — React + PWA (browser-only, no Capacitor)
```

---

## Database Strategy

| Environment | Provider | Why |
|---|---|---|
| **Development** | Local Docker PG | Fast, free, no cold starts, offline capable |
| **CI/CD** | Neon (free tier) | Serverless, no Docker in CI; ephemeral branch per run |
| **Staging** | Neon (branch of prod) | Copy-on-write branch — real prod shape, near-zero cost |
| **Production** | **Neon (default)** | Scale-to-zero, instant branch restore ("dropped a table at 3am" → branch back online while prod stays up), native pgvector, one MCP + one branching model dev→prod. Floor for prod = **Launch plan (7-day PITR)** — Free's 6h window is disqualifying. |
| **Production (escalation)** | Cloud SQL / PlanetScale | **Cloud SQL** when you need region-survivable DR (promotable cross-region replicas — promotion is a deliberate manual step, not auto-failover), HIPAA/BAA, or hard data residency. **PlanetScale** (Postgres GA Sept 2025; Metal = NVMe-attached I/O) when sustained throughput / horizontal scale matters more than scale-to-zero — it is deliberately always-on (the anti-Neon), with an official hosted MCP (OAuth, ephemeral creds). Caveat: its branches are backup-restore copies, **not** Neon-style copy-on-write — don't expect instant branch-per-PR. |

Drizzle abstracts the provider — only the connection string changes between environments. Collapsing the old Neon-dev / Cloud-SQL-prod split to one provider is the highest-leverage, lowest-risk move in the stack: it kills Cloud SQL's 24/7 idle bill and unifies the branching model — and it needs no agentic argument to justify.

---

## Architecture Pattern

```
Browser / Capacitor App
        |
        | All requests (static + API)
        v
  Container (Hono)  — Cloud Run / CF Containers / Fly / Railway
  - Serves static Vite build
  - Hono API routes (/api/*)
  - Better Auth (/api/auth/*)
  - Drizzle ORM → PostgreSQL
  - Services layer (business logic)
  - External: Ably, Resend, R2 (signed URLs), payment gateway
        |
        v
  PostgreSQL (Neon default; Cloud SQL / PlanetScale on escalation)
```

Single deployment, no CORS headaches. API and frontend share the same origin. The same Node image runs on any of the four container hosts — Hono is the portability insurance, so an agent can re-point the deploy target without an app rewrite.

---

## Day-1 Topology (dogfood phase)

Every new project **starts here**, regardless of its eventual hosting pick: one small VPS running the whole stack in Docker Compose behind a Cloudflare tunnel — the tunnel as sole ingress, no inbound ports except SSH, app + data tiers on a private Docker bridge, billing/compliance-vendor/GPU integrations stubbed. The Hosting Decision Framework below is the **public-launch phase**, entered at a named trigger (real concurrency, open signup, live billing) recorded in the Blueprint. Planning the managed platform from day one guarantees drift — the as-built audit reads as one long "deferred" column — and builds infra before it earns its keep. The single box also ships a *tighter* boundary posture than most managed platforms: nothing listens on the internet, TLS terminates at the edge, the clear-text hop never leaves the private bridge.

**Two mandatory guardrails** — the only non-benign risks the single box introduces; ship them with it, not as afterthoughts:

1. **Offsite backup + a tested restore, from day one.** A `pg_dump` living on the same box as the data is not a backup — wire an offsite copy (object storage, e.g. R2) and run one restore drill before real user data is at stake.
2. **The single-instance constraint is load-bearing** while generation/background work runs in-process. Document "run exactly one API instance"; gate horizontal scale behind a job queue + shared store (e.g. Redis) first — an in-memory rate limiter silently leaks to N× its ceiling the moment a second instance appears.

During dogfood, the DR/Residency line item reduces to guardrail 1; the full posture is a public-launch-trigger item.

---

## Hosting Decision Framework

**This is the public-launch phase** — projects arrive here from the Day-1 Topology at their named trigger, not on day one. There is no single hosting default. The stack is **container-first** (Cloud Run + Cloudflare Containers as co-equal defaults); the brain picks per project by scale and needs, with an agentic-operability tie-bias. This mirrors the Language Decision Framework: if no signal points elsewhere, ship the container default.

| Signal | Choice | Why |
|--------|--------|-----|
| Most projects (default) | **Cloud Run *or* CF Containers** (co-equal); Fly / Railway are peers | One Node image, near-zero migration between them. Both are agent-operable (Cloud Run MCP GA; CF Containers GA Apr 2026) and scale to zero. Portable container = the deploy target stays swappable. |
| Cost-dominant / always-on / egress-heavy / EU residency | **Hetzner** (via Kamal 2) | ~10× compute-per-dollar and near-$0 egress vs hyperscalers; EU residency; dedicated + GPU boxes. Kamal 2 (text-only CLI over SSH, auto-TLS) makes an IaaS box genuinely agent-operable. Cost: no scale-to-zero, you own the DB + patching + backups, and its API tokens are **coarse project-scoped bearers (no OIDC / no short-lived)** — the weakest credential model here, so rotate hard and isolate blast radius by per-env projects. |
| GPU / self-hosted open-weight models / embeddings at scale / fine-tuning | **Runpod** | The GPU / self-hosted-model tier that hosts the Python ML sidecar (see Language Decision Framework's ML/AI row). Serverless GPU scales to zero, per-second billing, official MCP + scoped keys. **Not a general app host** — the TS+Hono+Postgres core stays put. A hosted inference API (Anthropic/OpenAI/Together/Fireworks) is the more-agentic, less-ops default for low/bursty volume; reach for Runpod when you own a fixed open-weight model at sustained volume. A leaked full-scope key is radioactive — the default spend limit is an $80/**hour** rate cap, not a budget cap, so sustained abuse still compounds to ~$1.9k/day; mint endpoint-scoped, least-privilege keys. |
| Latency-critical **stateless** routes | Cloudflare Workers (edge) | A documented, **taxed** option — not a default. Edge is not a lateral move from a container; agentic-ops does *not* lower the tax (an agent hits these code-level breakages exactly as a human would): the `neon-http` driver has no interactive transactions and Better Auth signup needs them (better-auth#4747), so edge Postgres must be Hyperdrive+pg or neon-serverless-over-WebSocket, never neon-http; Pino dies on workerd (Node build unsupported — use `console.log`-JSON → OTLP there); Better Auth's scrypt formerly blew the Worker CPU budget (better-auth#8860 — fixed Apr 2026 via native `node:crypto` fallback; verify you're on a post-fix version). Keep Hono as portability insurance and peel *stateless* latency slices onto Workers later — do not go edge-first. |
| Region-survivable DR / HIPAA-BAA / GCP-committed | Cloud Run + Cloud SQL | GCP is a re-justified peer (now agent-operable), not the default. It wins when managed cross-region DR, compliance gating, or an existing GCP commitment genuinely tips the balance. |

**The guardrail again:** going all-in on any one provider's proprietary primitives (CF Durable Objects/Vectorize; GCP-native everything) is *tighter* lock-in than a portable container. (Hyperdrive doesn't count — it's a pass-through for standard Postgres; exit is repointing the connection string.) Stay container-first; adopt proprietary features only when a signal demands it, the same discipline the Language Framework applies to languages.

---

## DR / Residency (explicit line item)

Making Neon the default prod DB trades one managed property for a DIY one that must be **owned, not buried**: Neon has **no cross-region replication at any tier** — a region-wide outage means unbounded RTO (you wait for the cloud provider). Cloud SQL offers promotable cross-region replicas as a managed checkbox. This is architectural, not a plan knob.

Rules:

- **Every Neon prod** ships on **Launch plan or above (7-day PITR)** *and* a scheduled **cross-region `pg_dump` → object storage** job for an off-region cold copy. Free-tier 6h PITR is disqualifying for production.
- **Region-survivable DR, HIPAA/BAA, or hard data residency** → escalate the DB to **Cloud SQL** (name it in the Blueprint; don't discover the gap at go-live). Neon Inc. is a US CLOUD-Act entity and HIPAA/BAA is Scale-plan-only.
- DR posture is a **first-class Blueprint decision**, not an implicit consequence of the DB choice. `/press` verifies it at go-live.

---

## Logging Convention

Every new project must ship with structured server-side logging from day one. Logging serves two distinct purposes depending on the environment.

### Dev & Staging — AI-Assisted Debugging

In dev and staging, verbose logging is the foundation of evidence-based debugging. With few users, logs stay readable and directly traceable to reported issues.

When writing code for dev/testing, every route handler and service method should log its outcomes. This means when a bug is reported, the AI debugging workflow is:

1. Read the server log (`logs/dev.log` or Cloud Logging)
2. Correlate with browser dev tools console output (errors, network responses)
3. Trace what actually happened from the combined evidence
4. Only then look at code — guided by what the logs revealed

Without logs, AI debugging degrades into speculative code reading, which wastes time and often reaches wrong conclusions. Logs turn debugging from guesswork into forensics.

### Production — Action Audit Trail

In production, log every **human-initiated action** and **pertinent system decision**:

| What to log | Examples |
|---|---|
| **User actions** | Login, logout, profile update, payment, document upload, settings change |
| **System decisions** | Cron job triggered (with outcome), scheduled sweep results, subscription state changes, auto-retry outcomes |
| **Auth events** | Login success/failure, token refresh, role changes, lockouts |
| **State transitions** | Order placed → confirmed → shipped, document pending → approved |

### What NOT to log

Do **not** log high-frequency automated events that produce noise without diagnostic value:

- Heartbeats and health checks
- Polling cycles (WebSocket pings, keep-alive)
- Repeated status checks with no state change
- Background sync ticks with nothing to report

These events drown out the signal. If a polling cycle *does* detect something noteworthy (e.g., a stale session to clean up), log the outcome — not every tick.

### What every log entry must include

- **Who** — `userId`, session ID, or request identifier
- **What** — entity IDs (`orderId`, `documentId`, `itemId`), action name
- **Result** — status transitions, counts, outcomes
- **Never** log passwords, tokens, or full credit card numbers

### Log levels

| Outcome | Level | Example |
|---|---|---|
| Successful action | `logger.info` | `logger.info({ userId, orderId }, 'order_placed')` |
| Validation/auth failure | `logger.warn` | `logger.warn({ email, issues }, 'login_rejected')` |
| Unexpected error | `logger.error` | `logger.error({ err, userId }, 'payment_failed')` |

### Local dev setup

- Pino outputs JSON to `logs/dev.log` (or stdout with `pino-pretty` for readability)
- Every API route logs on the happy path *and* every rejection — a route with no logging is incomplete

### Anti-pattern

```typescript
// BAD: Silent on success, only logs crashes
catch (error) { logger.error(error); }
```

### Correct pattern

```typescript
// GOOD: Every outcome leaves a trace
logger.info({ userId, orderId, amount }, 'order_placed');
logger.warn({ userId, issues: parsed.error.issues }, 'order_validation_failed');
logger.error({ err, userId, orderId }, 'order_placement_failed');
```

---

## Key Learnings (Hard-Won)

These are patterns confirmed across multiple projects. Not opinions — battle scars.

### Drizzle
- `drizzle-kit` can't resolve `.js` extensions in TS files — use extensionless imports in schema files
- No native `upsert()` — use `onConflictDoUpdate` or manual find-then-update-or-insert
- `db.transaction()` gives `PgTransaction` type, not `Database` — use `type DbOrTx = any` for tx params
- `count()` import gets shadowed by function params named `count` — rename import to `dbCount`
- `innerJoin` results use capitalized table name as key (`{ Order: order, Item: item }`)
- `pgEnum` columns reject plain strings in `eq()` — export `enumEq(col, val)` and `enumInArray(col, vals)` helpers that centralize the single `as never` cast
- JSON/JSONB columns return `unknown` — casting `as T` is the standard workaround. A `typedJson<T>()` helper can centralize it, but Drizzle has no native solution. Don't flag as critical debt.
- Self-referencing FK (e.g., `parentId → table.id`) requires `(): any` return type on the `.references()` callback — TypeScript can't resolve the table type during its own definition

### Hono
- `secureHeaders()` without args — CSP not included by default (unlike Helmet)
- Request context: `c.get('userId')`, not `req.userId`
- Body: `await c.req.json()`, not `req.body`
- Response: `return c.json(data, statusCode)`

### Better Auth
- Claims `/api/auth/*` — plan routes around this
- Bearer plugin for Capacitor clients (token in header, not cookie). Cookie auth also works if using `androidScheme: "https"` + same-origin serving.
- Social auth in Capacitor: see **Capacitor → Social Auth** section below
- Phone-first users need placeholder email
- `freshAge` session cache: direct DB writes (e.g., role switch) won't be reflected in `auth.api.getSession()` until cache expires. Read mutable fields directly from DB in session endpoints.
- Hono middleware `c.header()` before `await next()` corrupts Better Auth's raw Response cookies. Only set headers on the rejection response (e.g., 429), never on pass-through.

### Paraglide
- Compile-time = zero runtime bundle cost
- `m.wallet_balance()` not `t('wallet_balance')` — typos caught by TypeScript
- Vite plugin handles message extraction

### GCS
- Use `getSignedUrl({ action: 'write' })` (XML API) — `createResumableUpload()` (JSON API) ignores bucket CORS

### Capacitor
- `@capacitor/preferences` is **not encrypted** (plaintext SharedPreferences/UserDefaults) — fine for non-sensitive prefs, but **not** for auth tokens. For tokens use a Keychain/Keystore-backed plugin (Capawesome Secure Preferences or `aparajita/capacitor-secure-storage`), never `@capacitor/preferences` or `localStorage`.
- `androidScheme: "https"` in capacitor.config.ts — required for cookie auth in Android WebView (without it, cookies are treated as cross-origin)
- Same-origin dev: set `MOBILE_DIST_PATH` env var → API serves mobile `www/` content, Capacitor `server.url` points at API. Avoids CORS/cookie issues entirely.
- External API calls (geocoding, maps, etc.) should be proxied through your API server — Android emulator DNS resolution is unreliable for external domains. Better pattern regardless (no CORS/CSP issues, enables caching).

#### Social Auth in Capacitor
WebView OAuth redirects don't work — the OAuth provider can't redirect back into a WebView. Two approaches:

**Recommended: `better-auth-capacitor` plugin** (system browser + deep links)
- OAuth opens in system browser (not WebView), completes normally, deep links back to app
- Requires App Links (Android) + Universal Links (iOS) on your production domain
- Server-side: Better Auth handles providers as normal — no mobile-specific server code
- Client-side: `setupBetterAuthCapacitor()` in app entry, then standard `signIn.social()` calls
- **Blocked by production domain** — App Links / Universal Links require a real domain with `assetlinks.json` (Android) and `apple-app-site-association` (iOS). Cannot test with localhost.
- Reference: https://github.com/daveyplate/better-auth-capacitor

**Alternative: Native SDK + ID token pass-through**
- Native Google/Facebook/Apple SDK gets ID token, pass to Better Auth via `signIn.social({ idToken })`
- More complex (native SDK per provider), but works without App Links

**Provider priority:** Google, Facebook, and Apple are the three that matter for most markets. Research your target market's social login adoption rates to decide priority. If you offer any social login on iOS, Apple Sign-In is **required by App Store policy**. When first implementing, add a TODO to resolve provider priority based on market research.

#### Mobile Build Scripts

Two scripts in `scripts/` handle the build-to-release pipeline:

**`build-mobile.sh`** — Builds all mobile SPAs and merges into `www/`:
- Vite builds each SPA with `VITE_CAPACITOR=true` (disables SPA base paths, hides web-only features)
- Merges multiple `dist/` outputs into a single `www/` directory (worker at root, employer at `/employer/`)
- `VITE_API_URL` unset = relative `/api` (same-origin dev); set = absolute URL for staging/production
- `www/` is gitignored — build artifact only

**`release-apk.sh`** — Builds debug APK and uploads to distribution host:
- `--api-url <url>` flag bakes the staging or production API target into the APK
- `--skip-build` flag for upload-only (reuse existing APK)
- Debug APK via `./gradlew assembleDebug` (release signing is a separate concern)
- Host on GCS public bucket — GitHub Releases requires auth for private repos
- Landing page shows download via `VITE_APK_URL` build arg (Dockerfile + deploy.yml)

**Vite `envDir` in monorepos:** Vite reads `.env` from the package root by default, not the monorepo root. Set `envDir: path.resolve(__dirname, "../..")` in every SPA's vite.config.ts so shared `VITE_*` vars from the root `.env.local` reach all SPAs in local dev. Docker builds are unaffected (use `--build-arg`).

**Android edge-to-edge (Capacitor 8 / Android 16):** Edge-to-edge is now mandatory — Android 16 (API 36) disables `windowOptOutEdgeToEdgeEnforcement`, and Google Play requires targetSdk 36 by 2026-08-31. **Capacitor 8 removed the `adjustMarginsForEdgeToEdge` config** in favor of the new **System Bars** core plugin (bundled with `@capacitor/core`), which manages status/nav-bar insets via CSS `env(safe-area-inset-*)` variables; use the `SystemBars` API for fine control. (Capacitor 7 only: the legacy fix was `android: { adjustMarginsForEdgeToEdge: "force" }` in `capacitor.config.ts` — do not carry it into Cap 8; `StatusBar.setOverlaysWebView(false)` and bare `env(safe-area-inset-top)` never worked on Android WebView.) Capacitor 8 also targets Android SDK 36 and requires Node 22+.

**Android SDK in WSL:** Gradle needs native Linux binaries — Windows `.exe` tools don't execute under WSL. Install cmdline-tools + build-tools natively (e.g., `/root/android-sdk`). Emulator stays on Windows (needs GPU passthrough) — manage via `powershell.exe` or a Node.js helper script for reliable argument handling.

**APK distribution via GCS:**
- Create a public bucket (e.g., `gs://my-public-releases`) with `allUsers` as `objectViewer`
- Upload APKs via `gcloud storage cp`
- Direct download URL: `https://storage.googleapis.com/<bucket>/<path>`
- Landing page controlled by env vars: `VITE_APK_URL` (tester sideload), `VITE_GOOGLE_PLAY_URL`, `VITE_APP_STORE_URL` — empty = hide section

### pnpm
- v10+ blocks dependency build scripts by default — allow them via `pnpm.onlyBuiltDependencies` in root `package.json` (pnpm 10), or the newer `allowBuilds` map (preferred; **required on pnpm 11**, which removed `onlyBuiltDependencies`)
- `dotenv` in monorepo: `import 'dotenv/config'` looks in CWD, not package root — use explicit path

### TypeScript
- `as const` gives literal types — when mutating, explicitly type as `number`
- `Record<string, unknown>` return values need explicit annotations or arithmetic fails downstream
- For monorepo dev workflow: `moduleResolution: "bundler"` — workspace packages resolve from source without `tsc --build`
- `array.filter(Boolean)` does NOT narrow away `null`/`undefined`. Use `array.filter((x): x is T => Boolean(x))` for proper type narrowing.
- Never `catch (e: any)` — use `catch (e: unknown)` + a `parseError(e)` helper that handles Error, string, and unknown. Catches `(e as Error).message` crashes on non-Error throws.
- Define runtime arrays `as const` FIRST, then derive types: `export const ROLES = ['a', 'b'] as const; export type Role = (typeof ROLES)[number];`. Standalone `type Role = 'a' | 'b'` can't be used in `.includes()`, `z.enum()`, or `pgEnum`.
- `z.coerce.number()` has input type `unknown` — `useForm<ExplicitType>()` with zodResolver causes type conflicts. Use untyped `useForm()` and cast in onSubmit.

### React
- Never place a conditional `return` between hooks — React counts hooks per render. Changing the count throws "Rendered fewer hooks than expected". Move early returns before all hooks or remove them.
- Radix UI `DialogContent` uses `{...props}` which silently overrides internal `style` (positioning). Destructure and merge: `style={{ ...basePositioning, ...style }}`.
- React video `srcObject` timing: conditionally rendered `<video>` elements need `useEffect` to assign `srcObject` after re-render — can't set it in the same function that triggers the render.

### Tailwind v4
- `@theme` registers `@property` rules that resist class overrides. Inline `style` prop with `--color-*` variables is the only guaranteed override for forced-light containers.
- `@tailwindcss/vite` may not follow pnpm workspace symlinks to scan shared packages. Classes used only in shared UI packages won't generate CSS. Fix: `@source` directive in globals.css pointing to the shared package.

### GCP
- `gcloud.cmd` on Windows: use Node subprocess with explicit argument arrays (bash can't find gcloud auth context)
- WIF providers require `--attribute-condition` on OIDC setup
- Cloud Run: `min-instances: 1` avoids cold starts in production
- **Non-production bot protection**: Distinguish internal vs customer-facing staging. *Internal staging* (dev/QA only): use `--no-allow-unauthenticated` (blocks all traffic unless caller has `roles/run.invoker`) + `robots.txt Disallow: /` + `X-Robots-Tag: noindex, nofollow`. *Customer-facing staging* (beta testers, real users): keep `--allow-unauthenticated` and rely on app-level bot protection only (`robots.txt Disallow: /` + `X-Robots-Tag: noindex, nofollow` header). IAM gating locks out real users when the staging environment serves actual customers. Wire bot protection into `deploy.yml` — never deploy staging without at least app-level access controls.

---

## Language Decision Framework

The default stack above is optimized for **server-rendered APIs + client-side React SPAs** targeting **mobile + web**. It's the right choice for most projects — but not all. Use the signals below to evaluate fit.

### Decision Signals

| Signal | Points toward | Why |
|--------|---------------|-----|
| Full-stack web app (API + SPA) | TypeScript/Node.js | Shared types DB-to-UI, one language for everything |
| Mobile + web (Capacitor) | TypeScript/Node.js | Capacitor needs JS frontend, shared types with API |
| CRUD / auth / payments | TypeScript/Node.js | Library ecosystem maturity, rapid iteration |
| High-concurrency API (10K+ req/s) | Go | Goroutines, tiny memory footprint, single binary deploy |
| CLI tool or standalone microservice | Go | Fast compile, zero dependencies, cross-compile |
| Latency-critical (sub-ms p99) | Rust | Zero-cost abstractions, no GC pauses |
| High-throughput data processing | Rust | Memory safety without GC overhead |
| ML/AI-adjacent (model serving, embeddings) | Python/FastAPI | PyTorch, transformers, numpy — unmatched ML ecosystem |
| Data pipeline / ETL | Python | pandas, polars, native Jupyter support |
| Static/content site | Astro, Hugo | Not a backend language decision |
| Rapid prototype (< 1 week) | Whatever ships fastest | Pragmatism over purity |

### AI-Assisted Development

Modern AI coding assistants write production-quality code in TypeScript, Go, Rust, and Python. AI-assisted velocity is no longer a TypeScript-only advantage. The differentiator is ecosystem depth — most current models' knowledge of TypeScript libraries (React, Drizzle, Hono, Better Auth) is deeper than their knowledge of Go/Rust web frameworks, but this gap narrows over time.

### The Rule

If no signals point away from TypeScript, use the default stack above. If signals point elsewhere, `/prime`'s blueprint process walks through the evaluation. If signals conflict (e.g., web app + ML model serving), the answer may be two languages — TypeScript API + Python ML service. Multi-language architectures are a valid choice, not a compromise.

The goal is never dogma — it's velocity with quality. If a better tool exists for the job, use it.
