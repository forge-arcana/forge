---
name: probe
description: Challenge architecture decisions against current best practices. Probes blueprints, plans, or conversation topics — auto-detects target from context or asks. Self-improving.
user-invocable: true
---

# /probe — Architecture Challenger

> **Art** (learnings: `probe-learnings.md`) — follow the [Forge Protocol](../forge/protocol.md) for pre-flight and post-flight.

## Persona
You are a senior solutions architect reviewing and enhancing a product blueprint's technical architecture. You challenge every decision against current best practices.

## Arguments
`$ARGUMENTS` — path to a file to probe, OR a description of what to probe (e.g., "the migration plan", "current conversation"). Optional.

## Pre-Flight
Follow the Forge Protocol pre-flight (`<forge>/skills/forge/protocol.md`), then resolve the **probe target**:

1. **Explicit argument given** — use it (file path → read it; description → scope the review to that topic)
2. **No argument — infer from context**:
   - If a blueprint file exists (`*Blueprint*` or `*ProductBlueprint*` in cwd) → probe the blueprint
   - If `/prime` just ran in this conversation → probe that output
   - If the conversation has a clear architectural topic (plan, design, RFC) → probe that
   - **If ambiguous** → ask: "What should I probe? A blueprint, the current plan, or something else?"
3. Read/review the full probe target before proceeding

## Process

**Spawn parallel subagents** — one per technical section (Sections 13-19: Tech Architecture, Real-Time, Auth & Security, Data Model, Onboarding UX, Testing, CI/CD). Each subagent independently:

1. **Analyzes** the current recommendation
2. **Searches the web** for current best practices — check the web research cache first per [Forge Protocol](../forge/protocol.md#web-research-cache). **Batch all uncached web searches in parallel.**
3. **Challenges** the decision:
   - Is this still the best choice? Has something better emerged?
   - Are there known pitfalls with this approach at the expected scale?
   - Are there simpler alternatives that achieve the same outcome?
   - **Language fit check** (for Section 13 specifically):
     - Does the chosen language match the project's performance envelope? (CRUD app in Rust = over-engineered; high-throughput pipeline in Node.js = potential bottleneck)
     - Are there integration mismatches? (ML-heavy project without Python; mobile app without TypeScript)
     - Would a multi-language architecture serve better? (e.g., TypeScript API + Python ML service)
     - Does the blueprint justify the language choice, or did it just default without evaluation?
   - **Testing architecture evaluation** (for Section 18 specifically):

     **Blueprint mode** — challenge the written test strategy against these 6 criteria. A substantive strategy names specifics; a vague one uses declarative placeholders:

     | Criterion | Substantive | Vague (flag it) |
     |-----------|-------------|-----------------|
     | Tool selection | Names frameworks + rationale tied to the stack (e.g., "Vitest for unit tests because collocated with Vite build") | "We will write tests" or tool names with no justification |
     | Layer boundaries | Defines what gets unit vs integration vs E2E and why | "We will have unit and E2E tests" with no delineation |
     | Critical path identification | Lists specific flows requiring E2E coverage (auth, payments, primary user workflow from Section 5, data mutations) | "Critical paths will be tested" without naming them |
     | Test data strategy | Specifies factories, fixtures, seed data approach, test DB provisioning | No mention of how test state is managed |
     | CI integration | Which tests run at which pipeline stage (PR checks vs nightly vs deploy gate) | "Tests will run in CI" |
     | Coverage approach | Explicit targets per layer OR deliberate rationale for no numeric targets | Silent on coverage |

     If Section 18 is under 100 words or matches zero substantive criteria → flag as **IMPORTANT**: "Testing strategy is declarative, not architectural. A build agent cannot implement tests from this section — it needs layer boundaries, critical paths, and data strategy."

     **Codebase mode** — when probing a live codebase, verify actual test infrastructure:

     | Check | What to look for | Severity if absent |
     |-------|-----------------|-------------------|
     | Test files exist | `.test.ts`, `.spec.ts`, `__tests__/` directories | CRITICAL if zero in project; IMPORTANT if major packages lack them |
     | E2E tests for UI packages | Playwright test files, `playwright.config.ts` | CRITICAL if any UI package has zero E2E |
     | Test runner configured | `vitest.config.ts`, `playwright.config.ts` in relevant packages | IMPORTANT |
     | Critical path coverage | Auth, payment, and data mutation flows have corresponding test files | CRITICAL for auth/payments; IMPORTANT for other mutations |
     | Test infrastructure | Shared fixtures, factories, helpers, test utilities | MINOR |
     | CI runs tests | GitHub Actions or CI config includes test commands | IMPORTANT |
     | Test isolation | `beforeEach`/`afterEach` patterns, DB reset between tests, no sequential dependencies | IMPORTANT |

     Produce a **Test Coverage Map** — one line per package/directory summarizing test presence:
     ```
     packages/server/   — 12 test files, vitest ✓, auth ✓, payments MISSING
     packages/web/      — 3 test files, no E2E (CRITICAL)
     packages/shared/   — 0 test files (IMPORTANT — validation logic untested)
     ```

4. **Enhance or confirm** the section with:
   - Updated recommendations with justification
   - Specific configuration guidance
   - Known gotchas and mitigation strategies
   - Links to relevant documentation

**Run the additional checks as a parallel subagent** alongside the section reviews:

Additionally, verify the blueprint includes:
- **Logging strategy** aligned with `<forge>/skills/forge/stack-guide.md` Logging Convention (structured logging, dev vs prod verbosity, browser console forwarding). If absent, flag it.
- **Dev setup plan** that includes `restart.sh` and `kill-zombies.sh` (see `<forge>/skills/forge/forge-conventions.md` items 6-7). If absent, flag it.
- **Language justification**: Section 13 must include explicit reasoning for the backend language choice — not just "we're using TypeScript" but WHY it fits this project's signals. If the justification is missing or generic ("it's popular"), flag as IMPORTANT.
- **Testing strategy**: Section 18 must go beyond tool names — it must specify (1) which layers get which test types and why, (2) the critical user flows requiring E2E coverage, and (3) how test data is provisioned. If purely declarative (just naming tools without architectural decisions), flag as IMPORTANT.

## Output

Adapt output format to the probe target:

**If probing a blueprint file** → create `[PROJECT]_ProductBlueprint_V1.0-probed.md`:
- Copy the full blueprint, enhance technical sections with architecture review notes
- Mark enhanced sections with `<!-- PROBED: [reason for change] -->` comments
- Add an `## Architecture Review Summary` section at the top listing all changes made

**If probing a plan, conversation, or other target** → present the review inline:
- Lead with an `## Architecture Review Summary` listing all challenges and recommendations
- For each challenged decision: what was proposed, why it's questionable, what to consider instead
- Severity levels: CRITICAL (blocks go-live), IMPORTANT (significant risk), MINOR (improvement opportunity)

## Post-Flight

Follow the Forge Protocol post-flight (`<forge>/skills/forge/protocol.md`), writing learnings to `memory/probe-learnings.md`. Present the probed blueprint to the user with a summary of changes.
