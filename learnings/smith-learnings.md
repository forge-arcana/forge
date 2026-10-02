# /smith Learnings

> Accumulated learnings from smith runs (orchestration, apprentice delegation, art proficiency).
> Absorbed by the `/forge` cycle. See `<forge>/core/skills/forge/protocol.md` for the absorb protocol.

<!-- Add learnings below this line -->


## A Locked Platform Decision Covers Its Implementation Details (2026-05-16)
**Learning**: When the user's brief locks a platform/service decision, treat the platform's actual API shape as covered by that decision — the integration mechanics are implementation details, not a fresh decision point. Don't re-interview when discovering that the platform exposes a different protocol than the existing code expects (e.g., the platform wraps an upstream service behind its own queue API rather than passing through native endpoints). The decision was "use platform X"; building the adapter for X's actual API is part of executing that decision, not a new "should we use X" question. Distinguish "what platform/service" (user decision) from "how to integrate with the platform's actual API shape" (engineering detail).
**Apply when**: Mid-build, you discover that a locked platform choice requires an adapter or transport layer the original plan didn't anticipate. Build the adapter; don't re-open the platform decision. Only escalate if the discovery genuinely invalidates the platform choice (e.g., the platform can't satisfy a hard requirement at all, not just "it requires more code than expected").

## A Skill's Action Override Binds Only Where the Global Rule Sanctions It (2026-05-16, evolved 2026-10-02)
**Learning**: When a user's global rule conflicts with an override declared in a skill's documentation, the global rule wins — the skill protocol is subordinate to the global ruleset. An override (auto-commit, auto-push, auto-deploy, auto-send) is legitimate only when the global rule itself names the exception, and only within the bounds it names: the No Auto-Commit rule now carves out explicitly delegated commit authority for a multi-step build, bounded to that invocation, which is what makes smith's phase-gate commits valid. Absent such a carve-out, the skill batches the actions the override would have triggered and defers them to a user-triggered step at end-of-run; gate evaluations and progress updates still happen.
**Apply when**: Designing a skill protocol that includes an action override. Write the exception into the global rule, not just the skill, and bound it (which actions, which invocation). Where the rules file is silent, the skill defers to the user.

## Never Trim the Art Gates — Least of All at Go-Live or on an Unattended Run (2026-05-16 → 2026-08-09)
**Learning**: The "save time" rationalization for skipping evaluative arts is a trap in exactly the two situations where it is most tempting. (1) Go-live to paid infrastructure with externally-exposed surfaces: the final-gate convergence (/press + /pound, optionally /temper) runs as subagents in ~5 minutes of wall time and routinely catches BLOCK-class findings — legal-exposure gaps, security holes (replay attacks, missing auth defenses), audit-chain breaks, broken reconciler probes in newly-introduced lanes, missing fallback safety on cost-accounting paths — that would ship silently otherwise; unit tests cover individual surfaces, the convergence covers cross-cutting concerns. (2) Unattended/overnight runs: one such run kept the skeleton (heats, verify, phase-gate commits) but substituted inline self-evaluation for the per-heat art passes without declaring it. Every correctness gate that ran held; every later finding was exactly the class the skipped gate owns, arriving as user-prompted post-hoc review — including one the author's self-review missed and a fresh pass caught. Unattended is when the ceremony matters MOST. Trim scope, never gates; any substitution goes in the ledger, because "the run happened" reads as "the gates ran." If the user pushes back on a skip, the user is right.
**Apply when**: A build phase is about to invoke /wrap and the work touched paid infrastructure, externally-exposed routes, content moderation, audit logging, financial accounting, or any compliance-adjacent surface — run the convergence even if the build-phase tests are green; and when configuring any autonomous/overnight orchestrated build.

## Test the Safety-Net Path, Not Just the Golden Path (2026-05-16)
**Learning**: When writing a "fallback" or "safety net" code path that activates only on invalid/missing/malformed input, write a test that explicitly exercises that path. Happy-path tests won't trigger it, so the fallback often ships untested — and the fallback is precisely the code that's supposed to be the last line of defense. Common shapes: data-validation fallbacks (clamp, default, retry with alternate source), timeout fallbacks, missing-field fallbacks, type-coercion fallbacks. For each, write tests that pass valid input (golden), invalid input (triggers fallback), AND boundary input (just-barely-valid, just-barely-invalid). The safety net is what shouldn't crash; tested code shouldn't be the place the system actually breaks.
**Apply when**: Reviewing or writing any function that has a `try / except` block, an `if missing → default` branch, a numeric clamp, or a "use this when the primary fails" alternative. Walk each branch and ask: does an explicit test cover this path? If not, write one before merging.

## Cross-Cutting Concerns Drop Quietly in Transport-Layer Refactors (2026-05-16)
**Learning**: When a refactor splits a previously-monolithic function into multiple transport-specific lanes (local vs cloud, on-prem vs SaaS, sync vs async, primary vs fallback), cross-cutting concerns tend to drop silently on one of the lanes. The most common drop-outs: audit logging, content moderation, output hashing, security checks (CSRF, rate limiting, role enforcement), observability (metrics, structured logs), and idempotency. The pattern: the original function did all of these inline; the new transport lane re-implements only the "main" logic and forgets the cross-cutting pieces. Before merging such a refactor, walk every lane against an explicit checklist of cross-cutting concerns derived from the original function. The checklist should be a written artifact, not an implicit memory. /press or /poke at the refactor boundary catches this; better to bake the checklist into the design.
**Apply when**: Refactoring an auth/audit/moderation-adjacent function into multiple lanes, or adding a new transport/protocol/backend to an existing system. Make the cross-cutting checklist explicit; review each lane against it; write tests that verify each cross-cutting concern fires on each lane.

## Schema Heats: Review Before Regenerating Migrations (2026-07-04)
**Learning**: On a fresh project with an empty dev DB, sequence schema work as build → typecheck → art review → batch-fix → delete + regenerate ONE clean migration. Fixing schema findings after data exists costs a real migration per finding; before, it costs nothing.
**Apply when**: Every greenfield schema heat, before any data exists.

## ORM Single-Instance Rule in pnpm Monorepos (2026-07-04)
**Learning**: When an auth/library dependency carries optional peers of the ORM, pnpm resolves a second ORM instance with an incompatible type identity. Re-export the ORM's query surface from the database package and ban direct ORM imports elsewhere — one instance, one type identity.
**Apply when**: pnpm monorepo + any ORM whose types cross package boundaries (drizzle/kysely-class failures).

## Final-Gate Convergence: Verify the Fix's REACH, Not Just the Fix (2026-07-05)
**Learning**: A fix applied to one instance of a defect class left the same class open on two sibling adapters; the re-evaluation caught it only because it re-verified the finding's *reach*, not just that the named file changed. When fixing a defect class, grep for every instance before declaring it closed, and have the next convergence cycle explicitly re-verify reach.
**Apply when**: Any defect-class fix during convergence.

## Convergence Loop: Decreasing Findings = Converging, Not Stalling (2026-07-05)
**Learning**: A strictly decreasing serious-finding count across cycles is the healthy convergence signature. Fix-then-re-evaluate with fresh adversarial lenses each cycle surfaces the second-order defects the fixes themselves introduce.
**Apply when**: Judging whether a final-gate loop is converging or should trip the stall check.

## Interim Crash-Safety Commits Inside Long Units (2026-07-04)
**Learning**: A 15-heat unit is too long for a single gate commit. Committing at the unit's halfway point (tests green, prior heats reviewed) converts hours of exposure into zero without violating the no-per-heat-commit rule. Label it an interim checkpoint in the ledger.
**Apply when**: Any unit longer than ~6 heats.

## Injectable Effect Boundaries Make Pipelines Testable Day One (2026-07-04)
**Learning**: Pipelines composing an expensive external call (LLM, platform API) should take the effect as an injectable parameter defaulting to the real client. Every downstream branch becomes unit-testable without credentials, and the real client keeps a single seam.
**Apply when**: Building any pipeline around an external effect.

## Append-Only Enforcement: Trigger Beats Role REVOKE in Dev (2026-07-04)
**Learning**: Role-based REVOKE UPDATE/DELETE is toothless when the app connects as table owner (every dev environment). A BEFORE UPDATE OR DELETE trigger raising an exception enforces append-only in all environments; role separation is production hardening on top, not the mechanism.
**Apply when**: Any audit-trail or ledger table that must be append-only.

## Transcript-Resume Makes Apprentices Interruption-Proof (2026-08-05)
**Learning**: When a session limit kills a running subagent, re-dispatching to the same agent id resumes from its saved transcript with full context. Pair with commissions that open "re-establish state via git status/typecheck before continuing" and resume cost approaches zero.
**Apply when**: Any harness whose subagents persist transcripts, on long multi-heat runs.

## Reviewers Must RUN Probes, Not Read Code (2026-08-05)
**Learning**: Two real concurrency races survived a green 800-test suite and were caught only because the reviewer was commissioned to write and execute its own concurrent probes against the real DB. Read-only review verdicts on concurrency code are speculation; the probe then becomes the regression test.
**Apply when**: Reviewing any concurrency-bearing code (claims, budgets, counters).

## Mode-Gated Features Break Precisely in the Modes Nobody Tests (2026-08-05)
**Learning**: Every serious finding in an env-gated unit was a dormant-mode defect. Suites naturally accrete at the permissive default. Rule: every mode of a mode-ladder feature gets at least one test AT that mode, and rollout-posture combinations (flag A without flag B) are first-class test cases.
**Apply when**: Building or reviewing anything behind a mode ladder or feature flags.

## Per-Heat Reviews Can't See Heat Boundaries; Keep a Whole-Diff Final Gate (2026-08-05)
**Learning**: After every heat was individually reviewed and fixed, fresh whole-diff lenses still found six IMPORTANTs — all at seams BETWEEN heats. Scoped reviews validate a heat's internal contract; only a fresh-eyes pass over the combined diff sees the composition.
**Apply when**: Budgeting the final gate on any multi-heat run — it is not redundant with per-heat review.

## Interleaved Heats in Shared Files Force Combined Phase Commits (2026-08-05)
**Learning**: Concurrent heats editing different regions of the same files make per-unit selective staging impossible — git cannot split within a file. Accept combined multi-unit gate commits, declare it in the ledger early, and sequence heats that must own the same file regions.
**Apply when**: Planning parallel heats that touch shared route/config files.

## A Hand-Maintained Inverse Is a Distinct Defect Class, and It Hides (2026-08-08)
**Learning**: Forward builders paired with reverse parsers (build a key / parse it back, arm a cooldown / poll for it) drift silently and fail as an EMPTY UI rather than an error — the reverse side simply finds nothing. Grep for the CONSTRUCTED VALUES, not just the table names; a first-pass inventory found none of four such pairs, a value-pattern sweep found all four.
**Apply when**: Auditing any codebase with derived string keys, scope names, or serialized identifiers.

## "Fix Everything" Still Requires Distinguishing Absence-by-Design From Omission (2026-08-08)
**Learning**: When a user overrides scoping caution with "fix it all," the honest execution is to fix what is genuinely forgotten and DECLARE what is deliberate — with the reason, in the type system. Several "missing" capabilities were correct behaviour that was merely undeclared; shipping the declaration satisfies the real complaint without inventing capability.
**Apply when**: Executing a broad-scope mandate over a codebase with intentional gaps.

## A Guard Test That Moves Must Be Re-Aimed, Never Relaxed (2026-08-08)
**Learning**: Refactoring tripped a compliance guard asserting a component imported assets from a specific module. The correct fix is following the invariant to its new home and asserting it in BOTH places plus a negative pattern for what must never return — not deleting the assertion. A guard failing after a legitimate move is asking where the rule lives now.
**Apply when**: Any refactor that trips an existing guard test.

## A De-Duplication Refactor Can Introduce the Duplication It Removes (2026-08-08)
**Learning**: While consolidating hand-copied tables into one registry, the refactor itself added a second copy of a helper the registry already exported — building the abstraction re-creates the "I need a small helper here" impulse that made the original mess. After any consolidation pass, grep the new shared module's export names against every package touched.
**Apply when**: Reviewing your own consolidation/DRY refactor before calling it done.

## Enable the Compiler Check That Would Have Caught Your Own Miss (2026-08-08)
**Learning**: When a self-review finds a defect class (dead imports), check whether a compiler flag closes it permanently before hand-fixing instances — measuring the blast radius first turns "should we?" into a bounded job. Do NOT reflexively enable noisy sibling flags: an unused parameter is often a kept signature, and noise trains people to ignore the gate.
**Apply when**: Any repo lacking a lint gate where typecheck is the only mechanical reviewer.

## Inspect the Installed Dependency, Don't Recall It — Builders and Reviewers Alike (2026-06-29 → 2026-07-04)
**Learning**: For code against a fast-moving SDK or library, the exact schema/contract lives in the installed package on disk (`node_modules/<pkg>/dist`), not in anyone's training-data memory. Grep the installed source for ground truth before authoring a factory/adapter/wrapper; instruct build apprentices to inspect the package rather than recall the API — it produced correct current-API usage the orchestrator's own context could not supply; and feed the extracted contracts to the gate reviewer so it verifies against reality, not assumptions. Pair the build order with an exact file whitelist, verbatim hard rules, and "your final message is a build report."
**Apply when**: Wrapping, adapting, or delegating any heat that codes against a fast-moving dependency.

## Parallel Writing Apprentices: Declare Write Scopes, Name the Neighbours' Paths, Re-Read Shared Files (2026-07-04 → 2026-08-05)
**Learning**: Concurrent build apprentices avoid conflict when their write scopes are disjoint (ideally whole packages) and every commission states three things: its writable paths, the paths concurrent apprentices own ("do NOT touch X"), and any declared shared touchpoint with "re-read any shared file immediately before editing" so the later writer preserves the earlier one's edit. Measured: ~20 apprentice runs at 3-4 concurrent with zero write collisions; both near-misses were in a shared constants file, and the re-read instruction absorbed the earlier edits cleanly.
**Apply when**: Fanning out two or more writing apprentices. See also the "Fence Every Subagent Brief" HARD RULE (`core/rules/development-discipline.md`) for the deletion-side fence.

## Normative Checklists Make Review Apprentices Decisive (2026-07-04)
**Learning**: Giving an evaluation apprentice an explicit PASS/FAIL checklist of normative requirements plus a "do NOT re-litigate" list of recorded decisions yields directly actionable output and zero duplicate findings. Free-form "review this" prompts re-open settled decisions.
**Apply when**: Commissioning any delegated review.

## Fix Verification Piggybacks on the Next Review (2026-07-04)
**Learning**: Instead of re-running an art solely to verify fixes, fold "verify these N fixes (PASS/FAIL each)" into the next heat's review prompt. One apprentice, two jobs, no extra latency.
**Apply when**: Sequencing fix verification inside a heat cycle.

## Tiered Build/Review Cadence: Findings Formatted as Fix Commissions (2026-08-05)
**Learning**: Lower-tier builders produce honest deviation sections when commissions demand them explicitly; higher-tier scoped reviewers then find 2-5 IMPORTANT per heat, and fix apprentices close them reliably when each finding carries file:line + a concrete fix + a named test to add. The finding format IS the fix commission — vague findings produce vague fixes.
**Apply when**: Structuring any multi-tier build/review/fix pipeline.

## Infra-Gated Multi-Repo Builds: Build+Verify the Core, Document the Gated Tail (2026-06-29)
**Learning**: When downstream code cannot compile or run until an upstream artifact is published/deployed, do not speculatively commit unverifiable code across live repos. Build and hard-verify the self-contained foundation; implement only consumer changes verifiable in isolation; deliver the infra-gated remainder as a runbook with exact ready-to-apply code, explicit at each gate about verified vs awaiting-provisioning.
**Apply when**: Any platform/migration build with a publish→deploy→consume dependency chain.

## Multi-Session Shared-Tree Builds Need Deploy Windows, Not Just Lane Claims (2026-08-15)
**Learning**: When several agent sessions build concurrently in one working tree and deploys bundle that tree, lane claims (which FILES are whose) are insufficient — the scarce resource is the DEPLOY WINDOW (a moment the whole tree is committed, migrated, and safe to bundle). The working pattern: each session commits its half as it completes; a session needing to deploy asks the in-flight peer for a go signal defined as "migration in prod + server half committed"; migrate-first applies to WHOEVER deploys next, not whoever wrote the migration — a bundle carries every committed line, so the migration its passenger code selects must be in prod before any peer's deploy, and the migration author should apply it before handing over the window.
**Apply when**: Orchestrating any build where multiple sessions share a working tree that deploys as a bundle.

## Order Work So a Kill Leaves the Tree Better, Not Worse (2026-09-05)

**Learning**: Under rate limits and process kills, the only state that survives is what's on disk — so sequence work to write fixes before attempting proofs, never the other way round, and never use a live-tree mutation (`stash`, an in-place revert) to stage a proof when a scratch copy would do the same job with zero blast radius. Two apprentices were killed mid-proof having written nothing recoverable; one `git stash` left the tree uncompilable for about a minute before it was resolved; and a resume record that still said "heat 1 pending" after eleven heats had actually landed would have replayed heat 1 on the next resume, redoing finished work and risking drift from what was actually built. Stamping orchestration checkpoints as heats complete — not just at the end — closes that last gap.

**Apply when**: Running any multi-step build or review under conditions where a kill or interruption is plausible (rate limits, long agent sessions, flaky infra) — order writes before proofs, revert in scratch copies never live trees, and keep resume/progress records current as you go rather than batching them at the end.

## Lock the Foundation, Then Fan Out Pages in Parallel (2026-06-27)
<!-- relocated from prime-learnings.md by /purge, 2026-10-02 — build-orchestration wisdom, which is smith's territory -->
**Learning**: Parallel subagents can build a cohesive single-codebase app with zero integration type-errors IF the entire shared substrate is built and type-checked FIRST: data layer, design tokens, complete UI primitive kit, shared pickers, modal context, app shell, stub pages — all green before fan-out. Then one agent per page with a strict disjoint file scope, an exhaustive API contract in the prompt, "read the real source for signatures," and NO builds inside agents (they would see each other's incomplete work) — verify centrally. The single hard barrier: the foundation must compile before the fan-out starts.
**Apply when**: Building any multi-screen app with parallel agents sharing one codebase.
