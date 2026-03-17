---
name: quick
description: Staff-engineer code review for tech debt — strategy patterns, band-aids, framework misuse, and logging hygiene. Produces an actionable tech debt report. Self-improving.
user-invocable: true
---

# /quick — Tech Debt & Logging Code Review

You are a staff engineer performing a thorough code review of this project. Your goal is to find and report tech debt across four dimensions. Produce a single actionable report.

## Forge Path
Resolve `<forge>` from `~/.claude/CLAUDE.md` `forge-path:` line (managed by `/cast`).

## Pre-Flight

1. Read the project's `CLAUDE.md` to understand the stack and conventions
2. Read the stack guide: `<forge>/skills/forge/stack-guide.md`
3. Read accumulated learnings: `<forge>/learnings/quick-learnings.md` (if it exists)
4. Scan the project structure to understand the codebase layout

## Dimension 1: Strategy Pattern Opportunities

Scan for branching where a strategy pattern would work better:

- **if/else or switch chains** that select behavior based on environment (`NODE_ENV`, `isDev`, `isProduction`)
- **Conditional imports** or **conditional middleware** for dev vs test vs prod
- **Feature flags implemented as scattered if-statements** instead of a centralized strategy
- **Duplicate code paths** that differ only by configuration

**What to flag**: Show the current code, explain why a strategy pattern is better, sketch the refactored approach.

## Dimension 2: Band-Aids

Scan for quick fixes that mask deeper issues:

- **Variable fallbacks**: `value || defaultValue`, `value ?? fallback` where the variable should be properly typed/validated at the boundary
- **Unsafe casting**: `as any`, `as unknown as X`, `!` non-null assertions without justification
- **Magic string comparisons**: `if (status === "active")` instead of `if (status === Status.ACTIVE)` with a typed enum/const
- **Type gymnastics**: Complex generic workarounds that indicate a modeling problem
- **Hardcoded values**: URLs, port numbers, timeouts, retry counts scattered in code instead of config

### 2a: Source-Field Fallbacks (HIGH PRIORITY)

These are the most dangerous band-aids — downstream code compensates for data that should have been set at the source (insert/create time). They hide data integrity bugs.

**How to detect — ask these questions for every `||` / `??` / conditional re-fetch:**

1. **Does the schema enforce this field?** If the column is `NOT NULL` with a `DEFAULT`, the fallback is redundant and masks a query bug (field not loaded) or insert bug (field not set).
2. **Is the fallback re-deriving data from a parent?** e.g., `trip.routeId || jeepney.routeId` — if the child should copy the parent's value at creation, a fallback means the copy failed silently.
3. **Is there a fallback chain (3+ links)?** e.g., `a.field || b.field || c.field || 'default'` — each link is a confession that the prior source might be missing. One authoritative source should suffice.
4. **Is there a conditional re-fetch?** e.g., `if (!trip.route) { route = await fetchFromJeepney() }` — if the relation should always load, the fallback masks a broken query shape.
5. **Is a sentinel value used?** e.g., `entityId || 'unknown'`, `name ?? 'Passenger'` — sentinels in data fields (especially audit logs) make records untraceable. The field should be required or the action should fail.

**Patterns to grep for:**
```
# Fallback chains (3+ links)
rg '\|\|.*\|\|' --type ts

# Sentinel defaults
rg "(|| 'unknown'||| 'Unknown'|\?\? 'default'|\?\? 0[^.])" --type ts

# Redundant schema-default fallbacks — cross-reference with schema
rg '\.default\(' packages/database/  # find schema defaults
rg '\|\| 0[^.]|\?\? 0[^.]' packages/server/  # find code defaults for same fields

# Conditional re-fetches (fetch data that should be on the object)
rg 'if \(!.*\.(route|profile|user|jeepney)' --type ts
```

**What to flag:** Show the fallback, trace WHERE the field should have been set (insert/query), explain why the fallback masks a bug. Propose the fix at the SOURCE, not a better fallback.

**What NOT to flag:**
- Env/config defaults: `process.env.PORT || 3000` (genuinely optional)
- UI display choices: `nickname || email` (presentation preference)
- Map/aggregation safety: `map.get(key) || 0` (Map returns undefined by design)
- Form initializers: `defaultValues: { name: '' }` (React form convention)
- Optional relations: `user.avatar?.url` where avatar is genuinely nullable by design

### 2b: Client-Supplied Actor Identity (SECURITY — HIGH PRIORITY)

Authenticated endpoints that accept the **acting user's identity** from the request body instead of extracting it from the **server-side auth session**. This is an impersonation vulnerability — any authenticated user can act as another by sending a different identity.

The principle: **the server already knows who is calling** via the auth session/token. Any request body field that identifies "who is performing this action" is redundant at best and a security hole at worst.

**How to detect:**

1. **Scan validation schemas** for fields that represent the acting user's identity (any field ending in `Id` that refers to the caller, not a target resource). These should NOT appear in request body schemas for authenticated endpoints.
2. **Check route handlers** — if a handler destructures the caller's identity from the request body instead of the framework's session accessor (e.g., `c.get('userId')`, `req.user.id`, `session.userId`), flag it.
3. **Check for "soft" auth guards** — patterns like `if (sessionId && sessionId !== bodyId)` where the check is conditional (skipped if session is undefined). The check should be unconditional; a missing session means 401, not a bypass.
4. **Cross-reference client code** — search for API calls that include `session.id` or equivalent in the request body. These are the client-side counterparts that need cleanup.

**Patterns to grep for:**
```
# Identity-like fields in validation schemas
rg 'Id.*z\.string|sender.*z\.string' <validations-dir>/

# Handlers reading caller identity from request body
rg '(Id|sender).*=.*req\.(valid|body|json)' <routes-dir>/

# Soft auth checks (conditional on session existing)
rg 'if \((auth|session).*&&' <routes-dir>/

# Client sending own identity in request body
rg 'Id:.*session|sender.*session' <client-dir>/
```

**Exceptions (NOT vulnerabilities):**
- **Admin/superuser routes** behind role-enforcement middleware — admins legitimately act on behalf of other users
- **Target references** where the ID identifies a resource or another user being acted upon (e.g., a friend to sponsor, an order to cancel), not the caller
- **Webhook/callback endpoints** from external services (payment providers, OAuth) that supply user context in their payload

**What to flag:** Show the schema field, the route handler, and the client call. Classify severity: CRITICAL if the endpoint modifies state (money, records, permissions), HIGH if it reads private data, MEDIUM if logging-only.

## Dimension 3: Framework Misuse

Scan for custom/bespoke handling where the adopted framework already provides a solution:

- **Custom auth middleware** when Better Auth handles it
- **Manual query building** when Drizzle ORM has the method
- **Hand-rolled validation** when Zod schemas should be used
- **Custom error handling** when Hono's built-in error handler works
- **Manual state management** when TanStack Query handles caching/invalidation
- **Custom routing logic** when TanStack Router provides it
- **Bespoke i18n** when Paraglide handles it
- **Manual form handling** when framework-provided form utilities exist

Check the stack-guide.md for the full list of adopted frameworks. For each finding, search the web to confirm the framework provides the capability.

**What to flag**: Show the custom code, link to the framework's built-in solution, explain migration path.

## Dimension 4: Logging Hygiene

### What MUST be logged (flag if missing):
- **Human-initiated actions**: login, logout, payments, uploads, settings changes, CRUD operations — with context: `{ userId, action, resourceId, outcome }`
- **Pre-action intent**: "about to process payment for orderId X" — log BEFORE the action, not just after failure
- **State transitions**: order placed -> confirmed -> shipped, with before/after state
- **Auth events**: login success/failure, token refresh, role changes, session lockouts
- **Validation failures**: with submitted data shape (sanitized) and rejection reason
- **Unexpected errors**: with full context (userId, resourceId, stack trace)
- **Structured fields on every log**: timestamp (ISO 8601), severity, userId, requestId/traceId, action, outcome

### What MUST NOT be logged (flag if present):
- **Pulsing/repeated actions**: heartbeats, health check polls, WebSocket pings, keep-alive, cron ticks (unless they find something)
- **Sensitive data**: passwords, tokens, full card numbers, PII, API keys
- **Raw request/response bodies** (unless sanitized and necessary)
- **Unchanged status checks**: if nothing changed, don't log the check

### Environment isolation (flag violations):
- Dev/staging: verbose — every route handler logs success AND failure
- Production: sparse — human actions + system decisions only
- Dev-only logging MUST be gated behind `process.env.NODE_ENV` or Pino level config
- Pino `redact` option MUST be used for sensitive fields at all levels

### Browser console -> server log (flag if missing in dev):
- Project MUST have `/api/dev/log` endpoint (or equivalent) that receives browser `console.log/warn/error`
- Writes to `logs/dev.log` with `browser_console` tag
- Endpoint MUST NOT exist in production (strip via env check or route guard)
- If project doesn't have this, flag it as CRITICAL for debuggability

**Sources**: 12-Factor App, OWASP Logging Cheat Sheet, Google SRE, Pino best practices.

## Output Format

```markdown
# Tech Debt Report — [PROJECT NAME]
**Date**: [date] | **Reviewer**: /quick (staff engineer review)
**Stack**: [frameworks from stack-guide]

## Summary
| Dimension | Findings | Critical | Important | Minor |
|-----------|----------|----------|-----------|-------|
| Strategy Patterns | X | ... | ... | ... |
| Band-Aids | X | ... | ... | ... |
| Framework Misuse | X | ... | ... | ... |
| Logging Hygiene | X | ... | ... | ... |
| **Total** | **X** | **X** | **X** | **X** |

## Findings

### [CRITICAL] Finding Title
- **File**: `path/to/file.ts:42`
- **Dimension**: Strategy Pattern / Band-Aid / Framework Misuse / Logging
- **Current code**:
  ```typescript
  // the problematic code
  ```
- **Problem**: Why this is tech debt
- **Recommended fix**: What to do instead
- **Effort**: S/M/L

[repeat for each finding, ordered by severity]
```

## Post-Review

After generating the report:
1. Write new learnings to the project's `memory/quick-learnings.md`
2. Format learnings with forge-worthy flag:
   ```markdown
   ## [Date] — [Short Title]
   - **Learning**: [context and evidence]
   - **Forge-worthy**: [yes/no] — [reason: "universal pattern" or "project-specific"]
   ```
3. Learnings marked `Forge-worthy: yes` will be auto-promoted by `/wrap` Stage 2
4. Present the report to the user
5. Ask: "Want me to fix any of these? Specify by finding number."
