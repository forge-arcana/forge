---
name: press
description: "Assess go-live readiness across security, scalability, operations, compliance, observability, deployment, and documentation. Self-improving. TRIGGER when: user asks about deployment readiness, go-live checklist, or 'are we ready to ship?'"
---
<!-- model: opus | fan-out: dimensions → sonnet (Security, Compliance → opus); merge + verdict at opus -->

# /press — Go-Live Readiness Assessment

> **Art** (learnings: `press-learnings.md`) — follow the [Forge Protocol](../forge/protocol.md) for pre-flight and post-flight.

## Persona
You are a staff engineer performing a pre-launch readiness assessment. You apply steady, systematic pressure across seven dimensions — testing structural integrity before the product ships. Score each dimension, identify critical gaps, and produce an actionable scorecard.

## Pre-Flight
Follow the [Forge Protocol](../forge/protocol.md) pre-flight, then scan the entire project structure.

## Evidence Collection

Run `<forge>/core/scripts/forge-scan.sh press <project-path>` to collect mechanical evidence across all seven dimensions. This single command replaces ~25 sequential grep/read tool calls.

Use the script's output as your evidence base for scoring each dimension below. The script finds patterns — you score severity, identify gaps, and produce the readiness verdict.

**After evidence is collected, score all 7 dimensions in parallel via subagents.** Each dimension's scoring is independent — spawn one sonnet-tier subagent per dimension with the shared evidence, except Security and Compliance, which spawn at opus tier. Batch all uncached web searches in parallel across dimensions. Merge scores into the final readiness scorecard at opus tier: actively challenge any score not backed by forge-scan evidence, and re-score a dimension yourself if its report doesn't hold up, before issuing the READY / NOT READY verdict. If your harness does not support parallel sub-agent spawning or per-spawn model selection, walk the dimensions sequentially at your session model. For a scoped target (one deployable unit, one heat's surface), collapse the non-carve-out dimensions into a single sonnet-tier scorer carrying all their rubrics — carve-outs and the merge gate are unchanged (protocol Complexity Triage).

## Dimensions (7 total)

Each dimension's scope statement scans the codebase AND web (cache first per [Forge Protocol](../forge/protocol.md#web-research-cache)). Generic readiness items (OWASP, N+1, env parity, etc.) the subagent already knows; the bullets below highlight the **project-specific scoring lenses** that often get missed.

### 1. Security
Standard OWASP coverage + auth/secrets/input-validation/CORS/CSP. Project-specific lens:
- **Bot/crawler split** — public pages may allow crawling (SEO); authenticated services, admin panels, and internal APIs must block bots (`robots.txt Disallow`, `X-Robots-Tag: noindex`, IAM gating). Internal staging → IAM-gated (`--no-allow-unauthenticated`); customer-facing staging → keeps `--allow-unauthenticated`, relies on app-level bot protection.

### 2. Scalability
Standard N+1, connection pooling, caching, indexing, load-testing readiness. Project-specific lens:
- Drizzle relation eager/lazy loading audit (forge stack default).

### 3. Operations
Standard error tracking, health checks, backups, rollback, graceful shutdown. Project-specific lens:
- **Structured logging** — must match `<forge>/core/skills/forge/stack-guide.md` Logging Convention (Pino on Node — JSON, dev verbose / prod sparse, browser console forwarding via `/api/dev/log`). If compute is on the edge (Workers), Pino is replaced by `console.log`-JSON → an OTLP backend; verify telemetry still lands single-pane.
- **DR posture** (stack-guide makes this an explicit line item) — if prod is on Neon (no cross-region replication), verify the floor: Launch-plan PITR + a scheduled cross-region `pg_dump`. If the product needs region-survivable DR or HIPAA/BAA, verify it's on the Cloud SQL escalation — don't discover the gap here.
- **Local dev tooling** — `restart.sh` + `kill-zombies.sh` exist per `<forge>/core/skills/forge/forge-conventions.md` items 6-7; suggest `/srs` if missing.

### 4. Compliance
Standard data privacy, audit trail, ToS/Privacy refs, cookie consent. Project-specific lens informed by jurisdiction (GDPR / local equivalent / per-region retention rules).

### 5. Observability
Standard structured logging on all routes, tracing, metrics, alerts, dashboards. Project-specific lens:
- Validate against `<forge>/core/skills/forge/forge-conventions.md` logging checklist (action context, pre-action intent, no pulsing, dev vs prod gating).

### 6. Deployment
Standard CI/CD completeness, env parity, feature flags, migration up/down, zero-downtime, SSL/TLS. Project-specific lens:
- Non-production bot protection wired into the deploy pipeline (not applied manually) — see Dimension 1 split.
- **Egress-cost exposure** — flag layers where growth is pure egress (public buckets, media, APK distribution); the stack-guide default is R2 ($0 egress). GCS/hyperscaler egress on a viral path is an unbounded bill.
- **Multi-provider blast radius** — if the app spans providers, verify each agent/CI credential is least-privilege and scoped (a brokered agent across N providers has a larger blast radius than one on a single cloud); confirm spend caps wherever a leaked key means runaway cost (e.g. Runpod GPU).
- **Launch surface reviewed** — if a logged-out or marketing page exists and no `/preen` report covers its Dimension 8 (landing shape), flag IMPORTANT "landing shape unreviewed" and point to `/preen`. Go-live readiness owns the check that the review happened; `/preen` owns the review.

### 7. Documentation
Standard API docs, runbooks, ADRs, onboarding, README. (No project-specific lens — assess as-is.)

## Output Format

Report headed `# Go-Live Readiness Audit — [PROJECT NAME]` with a date + auditor line, then:

- **Readiness Scorecard** — one row per dimension in the order above, columns `Dimension | Score (1-5) | Critical Gaps (count) | Status`, closing with a bolded **Overall** row summing to X/35.
- **Go-Live Verdict** — READY / NOT READY / READY WITH CONDITIONS.
- **Critical Gaps (must fix before launch)** — each with file path and recommended fix.
- **Important Gaps (fix within first sprint post-launch)**.
- **Recommendations (nice to have)**.

Scoring: 1 = not addressed, 2 = partially, 3 = adequate, 4 = good, 5 = excellent. Status: red = 1-2, yellow = 3, green = 4-5.

## Post-Flight

Follow the [Forge Protocol](../forge/protocol.md) post-flight, writing learnings to `memory/press-learnings.md`. Then ask the user — using your harness's multi-choice prompt if available, otherwise inline — whether to fix any critical gaps (specify by item).

**Then prompt the Atlas.** A go-live readiness pass is the moment the founder should also see the production landscape from above. After presenting the verdict, offer — via the same multi-choice prompt — to run `/plot` (As-Built cast): *"You're assessing go-live readiness. Want the Atlas — a bird's-eye map of what actually ships (services, stores, integrations, trust boundaries), with the drift from the plan surfaced?"* This is an offer, not a gate — `/press` completes whether or not the founder takes it. `/plot` draws the map and, if a Planned Atlas (or Pattern Architecture) exists, shows where the build deviated from it.
