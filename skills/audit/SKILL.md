---
name: audit
description: Assess go-live readiness across security, scalability, operations, compliance, observability, deployment, and documentation. Self-improving.
user-invocable: true
---

# /audit — Go-Live Readiness Assessment

You are a staff engineer performing a pre-launch readiness assessment. Score each dimension, identify critical gaps, and produce an actionable scorecard.

## Forge Path
Resolve `<forge>` from `~/.claude/CLAUDE.md` `forge-path:` line (managed by `/cast`).

## Pre-Flight

1. Read accumulated learnings: `<forge>/learnings/audit-learnings.md` (if it exists)
2. Read the project's `CLAUDE.md` for stack and conventions
3. Read the stack guide: `<forge>/skills/forge/stack-guide.md`
4. Scan the entire project structure

## Dimensions (7 total)

For each dimension, scan the codebase AND search the web for current best practices:

### 1. Security
- OWASP Top 10 coverage (XSS, SQLi, CSRF, SSRF, etc.)
- Auth implementation (session management, token handling, password hashing)
- Secrets management (no hardcoded secrets, proper .env handling, rotation strategy)
- Input validation at all boundaries (API endpoints, form submissions)
- Rate limiting on sensitive endpoints (login, registration, password reset)
- CORS configuration
- Content Security Policy headers

### 2. Scalability
- N+1 query detection (Drizzle relations, eager/lazy loading)
- Connection pooling (database, Redis, external services)
- Caching strategy (query cache, CDN, static assets)
- Rate limiting and backpressure
- Load testing readiness (can the app handle 10x current load?)
- Database indexing (are queries hitting indexes?)

### 3. Operations
- Structured logging (Pino with JSON output, proper levels)
- Error tracking (Sentry or equivalent configured)
- Health check endpoints
- Backup/restore procedures documented
- Rollback capability (blue-green, canary, or instant revert)
- Graceful shutdown handling

### 4. Compliance
- Data privacy (GDPR/local equivalent, data retention, deletion)
- Regulatory requirements per jurisdiction
- Audit trail completeness (all user actions logged)
- Terms of Service / Privacy Policy references in code
- Cookie consent (if applicable)

### 5. Observability
- Structured logging on all routes (success AND failure)
- Request tracing (trace IDs across services)
- Performance metrics (response times, error rates)
- Alerting rules defined (what triggers a page?)
- Dashboard readiness (key metrics identifiable)

### 6. Deployment
- CI/CD pipeline completeness (lint, test, build, deploy)
- Environment parity (dev ~ staging ~ production)
- Feature flags or gradual rollout capability
- Database migration strategy (up and down migrations)
- Zero-downtime deployment capability
- SSL/TLS configuration

### 7. Documentation
- API documentation (OpenAPI/Swagger or equivalent)
- Runbooks for common operations (deploy, rollback, debug)
- Architecture decision records (ADRs)
- Onboarding guide for new developers
- README completeness

## Output Format

```markdown
# Go-Live Readiness Audit — [PROJECT NAME]
**Date**: [date] | **Auditor**: /audit

## Readiness Scorecard

| Dimension | Score (1-5) | Critical Gaps | Status |
|-----------|-------------|---------------|--------|
| Security | X/5 | [count] | red/yellow/green |
| Scalability | X/5 | [count] | red/yellow/green |
| Operations | X/5 | [count] | red/yellow/green |
| Compliance | X/5 | [count] | red/yellow/green |
| Observability | X/5 | [count] | red/yellow/green |
| Deployment | X/5 | [count] | red/yellow/green |
| Documentation | X/5 | [count] | red/yellow/green |
| **Overall** | **X/35** | **[total]** | **red/yellow/green** |

**Go-Live Verdict**: READY / NOT READY / READY WITH CONDITIONS

## Critical Gaps (must fix before launch)
[list with file paths and recommended fixes]

## Important Gaps (fix within first sprint post-launch)
[list]

## Recommendations (nice to have)
[list]
```

Scoring: 1 = not addressed, 2 = partially, 3 = adequate, 4 = good, 5 = excellent.
Status: red = 1-2, yellow = 3, green = 4-5.

## Post-Audit

1. Write new learnings to the project's `memory/audit-learnings.md`
2. Format learnings with forge-worthy flag:
   ```markdown
   ## [Date] — [Short Title]
   - **Learning**: [context and evidence]
   - **Forge-worthy**: [yes/no] — [reason: "universal pattern" or "project-specific"]
   ```
3. Learnings marked `Forge-worthy: yes` will be auto-promoted by `/wrap` Stage 2
4. Present the scorecard to the user
5. Ask: "Want me to fix any critical gaps? Specify by item."
