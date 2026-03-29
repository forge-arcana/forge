# Stack Guide

A reference architecture for new projects. Derived from production decisions across multiple projects, refined through full rewrites.

**Core bias:** We favor technologies that Claude AI has deep familiarity with — maximizing AI-assisted development velocity. We will not sacrifice solution quality for this, but when two options are comparable, we pick the one Claude knows best.

---

## Stack Table

| Layer | Choice | Rationale |
|---|---|---|
| **Language** | TypeScript | Type safety DB-to-UI. Claude generates far better TS than JS — catches errors at write time, not runtime. |
| **Runtime** | Node.js | Stable, mature, universal tooling. Capacitor-compatible. Claude's strongest backend runtime. |
| **Backend** | Hono | ESM-native, 14KB, typed routes, Zod middleware built-in. Express is legacy — Hono uses Web Standard APIs (portable to CF Workers, Deno, Bun). Claude knows Hono deeply. |
| **ORM** | Drizzle | No codegen, no engine binary (50KB vs Prisma's 2-3MB), SQL-like API, native pgvector support, faster cold starts. Schema-as-code in TypeScript. |
| **Auth** | Better Auth | Framework-agnostic, Drizzle adapter, signed sessions, refresh rotation, CSRF, plugins for 2FA/passkeys/RBAC/bearer. Replaces hand-rolled auth and NextAuth alike. |
| **Database** | PostgreSQL | Neon (dev/staging/CI — free tier, serverless), Cloud SQL (production — always-on, VPC peering, SLA). Drizzle abstracts the provider — only the connection string changes. Add pgvector when you need embeddings. |
| **Real-time** | Ably | Managed pub/sub with guaranteed delivery, automatic reconnection, message history, presence. Eliminates the entire class of Socket.io bugs (dropped connections, room leaks, reconnect storms). |
| **Frontend** | React 19 + Vite | Component model, hooks (use, useOptimistic, useFormStatus), massive ecosystem. Claude's strongest frontend framework by far. Vite for sub-second HMR. |
| **Routing** | TanStack Router | Type-safe params + search validation, file-based routing, loaders, pending UI. Better TypeScript story than React Router. |
| **Server State** | TanStack Query | Caching, background refetch, optimistic updates, request deduplication, pagination. Essential for offline-first (3G users). |
| **Client State** | useState + React Context | TanStack Query handles server state. No Zustand/Redux needed — useState + context is sufficient for UI state. |
| **Forms** | React Hook Form + Zod | Performant (uncontrolled), Zod resolvers shared with backend validation. One schema, two runtimes. |
| **Styling** | Tailwind CSS v4 | Utility-first, consistent, fast to build. Claude generates Tailwind fluently — no class-naming debates. |
| **UI Components** | shadcn/ui | Copy-paste components (not a dependency), accessible, Tailwind-based. Buttons, modals, sheets, tables, forms — all pre-built. |
| **i18n** | Paraglide | Compile-time, zero runtime cost, fully typed (`m.key()` not `t('key')`). Typos caught by TypeScript. Ideal for 2-5 languages. |
| **Email** | Resend | Simple API, React Email templates, good deliverability. Transactional only (receipts, notifications, disputes). |
| **File Storage** | GCS (signed URLs) | Secure uploads via signed PUT URLs (XML API, honors CORS). Private bucket + presigned read URLs for admin review. |
| **Monitoring** | Sentry + Pino | Sentry for error tracking, performance traces, source maps, native crash reporting. Pino for structured server-side logging (JSON, fast, child loggers). |
| **Mobile** | Capacitor | Native iOS/Android from React codebase. Camera, GPS, push notifications, haptics, secure storage — all via plugins. No React Native context-switching. |
| **PWA** | vite-plugin-pwa | Service worker + manifest generation. Works inside Capacitor WebView too. Network-first caching for 3G resilience. |
| **Package Manager** | pnpm | Faster, stricter (no phantom deps), disk-efficient. Monorepo workspaces built-in. |
| **Testing** | Vitest + Playwright | Vitest for unit + integration (fast, ESM-native, same config as Vite). Playwright for E2E (cross-browser, reliable). |
| **Hosting** | GCP Cloud Run | Single deployment serves API + static build (no CORS). pick the region closest to your users. Split to CDN later if needed. |
| **CI/CD** | GitHub Actions | Tests, Docker build, push to Artifact Registry, canary deploy to Cloud Run, smoke test, promote. WIF for keyless GCP auth. |

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
| **CI/CD** | Neon (free tier) | Serverless, no Docker in CI |
| **Staging** | Neon (free tier) | Good enough, saves cost |
| **Production** | GCP Cloud SQL | Always-on, auto backups, VPC peering, SLA |

Drizzle abstracts the provider — only the connection string changes between environments.

---

## Architecture Pattern

```
Browser / Capacitor App
        |
        | All requests (static + API)
        v
  Cloud Run (Hono)
  - Serves static Vite build
  - Hono API routes (/api/*)
  - Better Auth (/api/auth/*)
  - Drizzle ORM → PostgreSQL
  - Services layer (business logic)
  - External: Ably, Resend, GCS, payment gateway
        |
        v
  PostgreSQL (Neon or Cloud SQL)
```

Single deployment, no CORS headaches. API and frontend share the same origin.

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
- `@capacitor/preferences` for secure token storage (replaces localStorage)
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

**Android 15 edge-to-edge:** Android 15 (API 35+) enforces edge-to-edge rendering — app content renders behind the status bar by default. `StatusBar.setOverlaysWebView(false)` and CSS `env(safe-area-inset-top)` do NOT work on Android WebView. The fix is `android: { adjustMarginsForEdgeToEdge: "force" }` in `capacitor.config.ts`. Do not stack with XML `windowOptOutEdgeToEdgeEnforcement` or Java `WindowCompat.setDecorFitsSystemWindows` — they add padding independently, causing a visible gap.

**Android SDK in WSL:** Gradle needs native Linux binaries — Windows `.exe` tools don't execute under WSL. Install cmdline-tools + build-tools natively (e.g., `/root/android-sdk`). Emulator stays on Windows (needs GPU passthrough) — manage via `powershell.exe` or a Node.js helper script for reliable argument handling.

**APK distribution via GCS:**
- Create a public bucket (e.g., `gs://my-public-releases`) with `allUsers` as `objectViewer`
- Upload APKs via `gcloud storage cp`
- Direct download URL: `https://storage.googleapis.com/<bucket>/<path>`
- Landing page controlled by env vars: `VITE_APK_URL` (tester sideload), `VITE_GOOGLE_PLAY_URL`, `VITE_APP_STORE_URL` — empty = hide section

### pnpm
- v10 blocks build scripts by default — add `pnpm.onlyBuiltDependencies` to root package.json
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

Claude writes production-quality code in TypeScript, Go, Rust, and Python. AI-assisted velocity is no longer a TypeScript-only advantage. The differentiator is ecosystem depth — Claude's knowledge of TypeScript libraries (React, Drizzle, Hono, Better Auth) is deeper than its knowledge of Go/Rust web frameworks, but this gap narrows over time.

### The Rule

If no signals point away from TypeScript, use the default stack above. If signals point elsewhere, `/prime`'s blueprint process walks through the evaluation. If signals conflict (e.g., web app + ML model serving), the answer may be two languages — TypeScript API + Python ML service. Multi-language architectures are a valid choice, not a compromise.

The goal is never dogma — it's velocity with quality. If a better tool exists for the job, use it.
