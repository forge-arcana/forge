# Audit Learnings

> Populated by `/audit` runs across projects. Absorbed into forge by `/reforge`.

<!-- Add learnings below this line -->

## Configure Pino Redact at Initialization (2026-03-15)
**Learning**: Always configure Pino's `redact` option at logger initialization for sensitive field paths (`*.password`, `*.token`, `*.email`, `*.apiKey`, `*.secret`, `*.authorization`, `*.cookie`). Manual per-call masking functions are fragile and incomplete — one forgotten call leaks PII. The built-in redact option catches all paths across all log output automatically.
**Apply when**: Setting up structured logging with Pino in any Node.js project handling user data.

## Never Fallback Auth Secrets to Hardcoded Values Without Env Gate (2026-03-15)
**Learning**: `secret: process.env.SECRET || 'dev-fallback'` is dangerous — if the env var is unset in staging/production, sessions are signed with a publicly known value, enabling session forgery. Always gate dev fallbacks with an environment check: `env === 'development' ? fallback : throw`.
**Apply when**: Configuring auth session secrets or any security-critical environment variables.
