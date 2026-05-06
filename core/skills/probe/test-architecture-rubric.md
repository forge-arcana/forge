# Test Architecture Rubric — for `/probe` Section 18

`/probe` references this rubric when evaluating Section 18 (Testing) of a Blueprint or when auditing test infrastructure in a Codebase.

## Blueprint mode — 6 substantive-vs-vague criteria

A substantive testing strategy names specifics; a vague one uses declarative placeholders.

| Criterion | Substantive | Vague (flag it) |
|-----------|-------------|-----------------|
| Tool selection | Names frameworks + rationale tied to the stack (e.g., "Vitest for unit tests because collocated with Vite build") | "We will write tests" or tool names with no justification |
| Layer boundaries | Defines what gets unit vs integration vs E2E and why | "We will have unit and E2E tests" with no delineation |
| Critical path identification | Lists specific flows requiring E2E coverage (auth, payments, primary user workflow from Section 5, data mutations) | "Critical paths will be tested" without naming them |
| Test data strategy | Specifies factories, fixtures, seed data approach, test DB provisioning | No mention of how test state is managed |
| CI integration | Which tests run at which pipeline stage (PR checks vs nightly vs deploy gate) | "Tests will run in CI" |
| Coverage approach | Explicit targets per layer OR deliberate rationale for no numeric targets | Silent on coverage |

If Section 18 is under 100 words or matches zero substantive criteria → flag as **IMPORTANT**: "Testing strategy is declarative, not architectural. A build agent cannot implement tests from this section — it needs layer boundaries, critical paths, and data strategy."

## Codebase mode — 7 infrastructure checks

When probing a live codebase, verify actual test infrastructure.

| Check | What to look for | Severity if absent |
|-------|-----------------|-------------------|
| Test files exist | `.test.ts`, `.spec.ts`, `__tests__/` directories | CRITICAL if zero in project; IMPORTANT if major packages lack them |
| E2E tests for UI packages | Playwright test files, `playwright.config.ts` | CRITICAL if any UI package has zero E2E |
| Test runner configured | `vitest.config.ts`, `playwright.config.ts` in relevant packages | IMPORTANT |
| Critical path coverage | Auth, payment, and data mutation flows have corresponding test files | CRITICAL for auth/payments; IMPORTANT for other mutations |
| Test infrastructure | Shared fixtures, factories, helpers, test utilities | MINOR |
| CI runs tests | GitHub Actions or CI config includes test commands | IMPORTANT |
| Test isolation | `beforeEach`/`afterEach` patterns, DB reset between tests, no sequential dependencies | IMPORTANT |

## Test Coverage Map output

In Codebase mode, produce a one-line-per-package summary like:

```
packages/server/   — 12 test files, vitest ✓, auth ✓, payments MISSING
packages/web/      — 3 test files, no E2E (CRITICAL)
packages/shared/   — 0 test files (IMPORTANT — validation logic untested)
```

The map is the artifact that surfaces gaps to the user; the criteria above are the reasoning behind each line.
