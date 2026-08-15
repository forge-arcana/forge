# /press Learnings

> Populated by `/press` runs across projects. Absorbed into forge by the `/forge` cycle.

<!-- Add learnings below this line -->

## Configure Pino Redact at Initialization (2026-03-15)
**Learning**: Always configure Pino's `redact` option at logger initialization for sensitive field paths (`*.password`, `*.token`, `*.email`, `*.apiKey`, `*.secret`, `*.authorization`, `*.cookie`). Manual per-call masking functions are fragile and incomplete — one forgotten call leaks PII. The built-in redact option catches all paths across all log output automatically.
**Apply when**: Setting up structured logging with Pino in any Node.js project handling user data.

## Never Fallback Auth Secrets to Hardcoded Values Without Env Gate (2026-03-15)
**Learning**: `secret: process.env.SECRET || 'dev-fallback'` is dangerous — if the env var is unset in staging/production, sessions are signed with a publicly known value, enabling session forgery. Always gate dev fallbacks with an environment check: `env === 'development' ? fallback : throw`.
**Apply when**: Configuring auth session secrets or any security-critical environment variables.

## Never Accept Actor Identity from Request Body (2026-03-15)
**Learning**: Authenticated endpoints must extract the acting user's identity from the server-side auth session, never from the request body. Accepting identity fields in the body allows impersonation — any authenticated user can send another's ID. Soft guards like `if (sessionId && sessionId !== bodyId)` fail open when session is missing. Always extract from the session accessor and return 401 if absent.
**Apply when**: Auditing authenticated API endpoints for impersonation vulnerabilities.

## Low-Entropy Secrets Need Server-Side Pepper (2026-03-29)
**Learning**: A 4-6 digit PIN has 10,000-1,000,000 possible values. Hashing with Argon2id + salt does NOT prevent exhaustion from a database dump — an attacker can try all combinations in seconds on consumer hardware. Server-side pepper (stored in env/secrets manager, never in DB) makes offline exhaustion impossible because the attacker needs both the DB dump and the application secret. Rate limiting + lockout blocks online brute force; pepper blocks offline attacks. This applies to any low-entropy secret: PINs, short OTPs stored at rest, short passcodes.
**Apply when**: Any authentication factor with fewer than ~1 million possible values. Always add server-side pepper alongside hash+salt.

## Env Var Naming Is a 4-File Unit (2026-05-29)
**Learning**: When a secret is server-only (no `NEXT_PUBLIC_` prefix), all four locations — code, README env table, CI/CD env block, and `.env.example` — must use the exact same name. A mismatch causes runtime 503s for anyone following the README and can silently leak the value into the client bundle. These four locations are one logical unit; change them together.
**Apply when**: Any env var rename, promotion from public to server-only, or new secret addition — audit all four touchpoints.

## GET-Based State Mutation Blocks Rate Limiting (2026-05-29)
**Learning**: Using `GET /api/endpoint?action=increment` for mutation violates HTTP idempotency and prevents rate limiting at the HTTP layer (CDNs, proxies, Next.js middleware all treat GET as safe/cacheable). Moving mutations to POST enables IP-based rate limiting middleware without hacks.
**Apply when**: Any API route that modifies state — enforce POST (or PUT/PATCH/DELETE) regardless of convenience.

## E2E Tests Without CI Coverage Are False Confidence (2026-05-29)
**Learning**: Playwright or other E2E tests that aren't wired into CI create the impression of a safety net that never fires. For Next.js on Vercel, running tests against the preview URL in CI is minimum viable regression guard. Adding tests and wiring them to CI must happen in the same PR.
**Apply when**: Any project adding E2E tests — if CI wiring isn't in the same PR, the tests don't count.

## Content-Only Sites Still Need Security Headers and Compliance Basics (2026-05-29)
**Learning**: Public content sites with no auth and no database still require HTTP security headers (CSP, X-Frame-Options, X-Content-Type-Options) and basic privacy compliance. Clickjacking, script injection via CDN compromise, and iframe embedding remain vectors. GDPR/privacy law applies to any site that sets cookies or transfers visitor data to third parties (analytics, fonts, CDNs), regardless of whether personal data is explicitly collected.
**Apply when**: Any public web app at go-live — security headers and privacy disclosure are not optional even for content sites.

## Vercel-Hosted Projects: Scope Ops Tooling to Platform Gaps (2026-05-29)
**Learning**: For Next.js on Vercel, the platform handles SSL, uptime, scaling, zero-downtime deploy, and rollback. Structured logging, health check endpoints, and graceful shutdown are over-engineering for a content site. Correct scope: Sentry for client error visibility + `@vercel/analytics` for traffic. Avoid platform-redundant tooling.
**Apply when**: Any project deployed to a managed platform (Vercel, Railway, Fly.io) — audit ops tooling against what the platform already provides.

## Unused npm Packages Overlapping Framework Natives Should Be Removed (2026-05-29)
**Learning**: A project using Next.js native cookie/session handling doesn't need `js-cookie` or similar. Unused packages that overlap with framework-native APIs inflate compliance surface area (cookie packages attract GDPR scrutiny) and supply-chain risk. Audit for redundant deps before go-live.
**Apply when**: Go-live readiness audit — scan for packages whose functionality is now native to the framework.

## Privacy Policy and Third-Party Service Changes Must Be Atomic (2026-05-29)
**Learning**: When a third-party service changes (new vendor, removed service, or IP-logging side-effect added for rate limiting), the privacy policy must update in the same PR. Stale disclosures are technically inaccurate GDPR representations. Any service that receives IP addresses for security controls qualifies as a data processor and must be disclosed even if IP storage is a side-effect.
**Apply when**: Any PR that adds, removes, or changes a third-party data processor — privacy policy update is part of the PR, not a follow-up.

## Rate Limit Audits Must Cover All Mutation Endpoints (2026-05-29)
**Learning**: When rate limiting is added to one public API endpoint, it's easy to overlook sibling endpoints that also accept user input. An unprotected feedback or contact endpoint can exhaust third-party free-tier quotas under bot traffic. Audit all mutation endpoints together when adding rate limiting to any one of them.
**Apply when**: Any press review that adds or verifies rate limiting — scan all mutation routes, not just the one that triggered the check.
