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
- **What** — entity IDs (`tripId`, `documentId`, `orderId`), action name
- **Result** — status transitions, counts, outcomes
- **Never** log passwords, tokens, or full credit card numbers

### Log levels

| Outcome | Level | Example |
|---|---|---|
| Successful action | `logger.info` | `logger.info({ userId, tripId }, 'trip_started')` |
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
- `innerJoin` results use capitalized table name as key (`{ Seat: seat, Trip: trip }`)

### Hono
- `secureHeaders()` without args — CSP not included by default (unlike Helmet)
- Request context: `c.get('userId')`, not `req.userId`
- Body: `await c.req.json()`, not `req.body`
- Response: `return c.json(data, statusCode)`

### Better Auth
- Claims `/api/auth/*` — plan routes around this
- Bearer plugin for Capacitor clients (token in header, not cookie)
- Phone-first users need placeholder email

### Paraglide
- Compile-time = zero runtime bundle cost
- `m.wallet_balance()` not `t('wallet_balance')` — typos caught by TypeScript
- Vite plugin handles message extraction

### GCS
- Use `getSignedUrl({ action: 'write' })` (XML API) — `createResumableUpload()` (JSON API) ignores bucket CORS

### Capacitor
- Google Sign-In: native plugin gets ID token, pass to Better Auth via `signIn.social({ idToken })`
- `@capacitor/preferences` for secure token storage (replaces localStorage)

### pnpm
- v10 blocks build scripts by default — add `pnpm.onlyBuiltDependencies` to root package.json
- `dotenv` in monorepo: `import 'dotenv/config'` looks in CWD, not package root — use explicit path

### TypeScript
- `as const` gives literal types — when mutating, explicitly type as `number`
- `Record<string, unknown>` return values need explicit annotations or arithmetic fails downstream
- For monorepo dev workflow: `moduleResolution: "bundler"` — workspace packages resolve from source without `tsc --build`

### GCP
- `gcloud.cmd` on Windows: use Node subprocess with explicit argument arrays (bash can't find gcloud auth context)
- WIF providers require `--attribute-condition` on OIDC setup
- Cloud Run: `min-instances: 1` avoids cold starts in production

---

## When NOT To Use This Stack

This stack is optimized for **server-rendered APIs + client-side React SPAs** targeting **mobile + web**. Consider alternatives when:

| Scenario | Consider Instead |
|---|---|
| Static/content site | Astro, Hugo |
| Heavy SSR/SEO needs | Next.js (but beware the complexity tax) |
| Embedded/IoT | Go, Rust |
| ML/data pipeline | Python (FastAPI + SQLAlchemy) |
| Real-time game | Elixir/Phoenix, or raw WebSockets |
| Solo prototype (< 1 week) | Whatever ships fastest |

The goal is never dogma — it's velocity with quality. If a better tool exists for the job, use it.
