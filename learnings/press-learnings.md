# /press Learnings

> Populated by `/press` runs across projects. Absorbed into forge by `/fold`.

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
