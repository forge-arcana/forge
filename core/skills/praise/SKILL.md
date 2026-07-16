---
name: praise
description: "Feedback-driven improvement loop — ingests user feedback, testing findings, or bug reports, routes them through evaluative arts (probe, preen, poke), assesses blueprint impact, and hands off to smith with a prioritized change brief. TRIGGER when: user has feedback to process, wants to close the loop on testing results, end-user reports, or QA findings."
---
<!-- model: inherit | fan-out: probe/poke legs → opus; press/preen legs → sonnet; Phase 4 consolidation at opus -->

# /praise — The Feedback Loop

> **Art** (learnings: `praise-learnings.md`) — follow the [Forge Protocol](../forge/protocol.md) for pre-flight and post-flight.

> Feedback is a gift. Praise makes it actionable.

`/praise` closes the build-ship-learn cycle. It takes raw feedback — from end users, QA sessions, analytics, bug reports, or live testing — and converts it into a prioritized set of improvements. It routes findings through the right evaluative arts, checks if the blueprint needs updating, and hands off a change brief to `/smith`.

## Arguments

`$ARGUMENTS` — one of:
- **File path** to a feedback file (`.md`, `.txt`, `.json`)
- **Inline description** — "users are confused by the nav" or "login fails on mobile"
- **Nothing** — praise will ask for feedback interactively

## Phase 0: Pre-Flight

1. **Resolve forge path** from your harness's global config (e.g., `~/.claude/CLAUDE.md` `forge-path:` line for Claude Code, or the equivalent rules file for other harnesses), managed by `/forge`
2. **Launch all reads in parallel** (all independent after forge path resolves):
   - Read project `CLAUDE.md`/`AGENTS.md` for stack, conventions, current state
   - Read `<forge>/core/skills/forge/stack-guide.md` for tech reference
   - Scan cwd for Blueprint + Pattern files (`*Blueprint*.md` and `*Pattern*.md` — the Pattern is /smith's design source; feedback often challenges its decisions)
   - Read `<forge>/learnings/praise-learnings.md` if it exists (routing wisdom from prior runs)
   - Read `memory/.web-cache.json` if it exists

## Phase 1: Feedback Ingestion & Classification

### Collect the Feedback

- **Explicit file path** → read the file in full
- **Inline description** → treat it as raw feedback text
- **Nothing given** → ask the user (use your harness's multi-choice prompt if available, otherwise inline):
  - Prompt: "What feedback should I process?"
  - Options: "Paste it here" / "Point me to a file" / "Describe the issues"

Accept any format: freeform prose, structured bug reports, user interview notes, test results, analytics summaries, Slack threads.

### Classify Each Piece of Feedback

Parse all feedback and classify into one or more categories. A single feedback item can span multiple categories.

| Category | Signals | Art(s) to Invoke |
|----------|---------|-----------------|
| **UX / Design** | Confusion, hard to find, looks broken, layout issues, mobile problems | `/preen` |
| **Architecture / Tech** | Slow, crashes, scale concerns, wrong abstraction, data model issues | `/probe` |
| **Code Quality** | Bug reports, unexpected behavior, regressions, error handling gaps | `/poke` |
| **Readiness / Operations** | Auth failures, security concerns, deployment issues, compliance flags | `/press` |
| **Blueprint Gap** | Feature requests, missing workflows, out-of-scope asks, product pivots | Blueprint Delta only |
| **Performance** | Slow load times, timeouts, memory issues | `/poke` + `/press` |

> Present the classification to the user before proceeding: a **Feedback Classification** block headed with the project, listing each detected category with its item count and the art it routes to (e.g. `UX / Design: [count] → /preen`), then "Proceeding with analysis...".

## Phase 2: Parallel Art Dispatch

Spawn one subagent per active category — **all in parallel** (independent analyses). Spawn the /probe and /poke legs as opus-tier subagents (their diagnoses have no downstream verification gate); spawn the /preen and /press legs as sonnet-tier subagents — Phase 4 consolidation runs at opus tier, re-grades their findings, and owns the verdicts (including SHIP BLOCKED). If your harness does not support parallel sub-agent spawning or per-spawn model selection, run the categories sequentially at your session model.

### Routing Rules

**Only invoke arts with relevant feedback** — never invoke an art with empty input.

#### /preen Subagent (if UX / Design feedback present)

Spawn as a sonnet-tier subagent — Phase 4 consolidation (opus) re-grades these findings.

```
You are running /preen on behalf of /praise.
Focus ONLY on the following specific feedback — do not do a full UI audit.
Skip your standard pre-flight (already done by praise).

FEEDBACK TO ANALYZE:
[UX/Design feedback items]

PROJECT CONTEXT:
[paste project rules file]

Apply Don Norman's principles and Ive's Razor to each item.
For each: identify the specific component/screen/flow affected, the Norman principle violated, and the concrete fix.
Output structured findings: Critical / Improvements / Reduce / Polish.
```

#### /probe Subagent (if Architecture / Tech feedback present)

Spawn as an opus-tier subagent — its architectural judgments have no downstream verification gate.

```
You are running /probe on behalf of /praise.
Focus ONLY on the following feedback — do not probe the full blueprint.
Skip your standard pre-flight (already done by praise).

FEEDBACK TO ANALYZE:
[Architecture/Tech feedback items]

BLUEPRINT (for context):
[paste relevant blueprint sections if available]

PROJECT CONTEXT:
[paste project rules file]

For each item: assess whether the feedback reveals an architectural gap, a wrong decision, or a scaling concern.
Check the web for current best practices relevant to the specific concern.
Severity: CRITICAL / IMPORTANT / MINOR.
```

#### /poke Subagent (if Code Quality or Performance feedback present)

Spawn as an opus-tier subagent — its root-cause diagnoses are never re-verified against code downstream.

```
You are running /poke on behalf of /praise.
Focus ONLY on the following feedback — do not do a full code audit.
Skip your standard pre-flight (already done by praise).

FEEDBACK TO ANALYZE:
[Code Quality / Performance feedback items]

PROJECT CONTEXT:
[paste project rules file]

For each item: trace the likely code location (file path if guessable from stack context), diagnose the root cause, and propose the fix.
Severity: CRITICAL / IMPORTANT / MINOR.
Output structured findings with FILE, PROBLEM, FIX, EFFORT.
```

#### /press Subagent (if Readiness / Operations feedback present)

Spawn as a sonnet-tier subagent — Phase 4 consolidation (opus) re-grades these findings.

```
You are running /press on behalf of /praise.
Focus ONLY on the following operational concerns — do not do a full readiness audit.
Skip your standard pre-flight (already done by praise).

FEEDBACK TO ANALYZE:
[Readiness/Operations feedback items]

PROJECT CONTEXT:
[paste project rules file]

For each item: assess the readiness dimension (Security, Scalability, Operations, Compliance, Observability, Deployment, Documentation).
Score 1-5, identify the gap, propose the remediation.
```

## Phase 3: Blueprint Delta Assessment

Run this in parallel with Phase 2 (independent of art analyses).

### Assessment Questions

For each **Blueprint Gap** feedback item (and cross-checking all other feedback):

1. **Is this already in the blueprint?** — If yes, it's an implementation gap (smith's job). If no, it's a scope gap (blueprint needs updating).
2. **Does this feedback contradict a blueprint decision?** — Flag for architect review.
3. **Does this feedback reveal an assumption that was wrong?** — Update the blueprint.
4. **Is this a future phase item?** — Log it in the appropriate phase section, do not pull into MVP.

### Blueprint Delta Output

A **Blueprint Delta** block with four sub-sections in this order: **Add to Blueprint** (item → section + what to add), **Update in Blueprint** (item → current text → proposed text), **Out of Scope (defer to Phase N)** (item → rationale), **Implementation Gaps (already in blueprint, not yet built)** (item → blueprint section reference).

## Phase 4: Consolidation — The Praise Report

After all Phase 2 subagents and Phase 3 complete, merge into a single report. Run the consolidation at opus tier: it is the review gate over the sonnet legs (/preen, /press) — re-grade their findings rather than merging them as-is — and it owns the final verdict, including SHIP BLOCKED.

**Persist the report first** to `memory/YYYY-MM-DD-praise-report.md` before displaying.

Structure (markdown, sections in this order):
- **Title + meta**: `# /praise Report — <project>`, then `Date | Feedback items: N | Arts invoked: <list>`.
- **Feedback Summary** — 1-3 sentences on what the feedback reveals about the product.
- **Critical (fix before next ship)** — consolidated CRITICAL findings from all arts, **ordered by user impact**; each as `**<Title>** · *<art>* · File: <path:line or N/A>` with Problem / Fix / Effort (S/M/L) sub-bullets.
- **Important (fix this sprint)** — IMPORTANT findings, same shape.
- **Minor (backlog)** — MINOR findings, one line each.
- **Blueprint Delta** — output from Phase 3.
- **Praise Verdict** — Arts invoked; counts of Criticals / Importants / Blueprint changes; **Recommendation** (one verdict from the table below); 2-3 sentence executive summary of meaning + next step.

### Verdict Definitions

| Verdict | Meaning |
|---------|---------|
| **SHIP BLOCKED** | Critical findings that must be fixed before the next release |
| **PATCH NEEDED** | Important findings; patch release warranted |
| **POLISH PASS** | Only minor + UX improvements; invoke `/smith` with polish scope |
| **BLUEPRINT UPDATE** | Blueprint needs revision before new features are built |
| **CLEAR** | Feedback processed, no actionable code changes needed |

## Phase 5: Smith Handoff

### Step 5a: Build Plan

Before invoking smith, produce a **Build Plan** showing how the work will be executed. Present this to the user for approval — smith only starts after confirmation.

Analyze all findings from the Praise Report and decompose them into discrete tasks. For each task, determine:

- **Scope**: what file(s) and component(s) are touched
- **Effort**: S (< 30 min) / M (30–90 min) / L (> 90 min)
- **Dependencies**: which tasks must complete before this one can start
- **Parallelizable**: can this run concurrently with other tasks in a sub-agent?

#### Parallelization Rules

| Condition | Decision |
|-----------|----------|
| Tasks touch different files/components with no shared state | **Parallel** — spawn sub-agents |
| Task B reads output of Task A (e.g., schema change → API update → UI) | **Sequential** — A before B |
| Blueprint must be updated before code changes | **Sequential** — blueprint first |
| Multiple isolated bug fixes in unrelated modules | **Parallel** — spawn sub-agents |
| Single critical path (auth flow, payment, data migration) | **Sequential** — too risky to parallelize |

#### Build Plan Format

**Output as console text, never as a multi-choice prompt.** A **Praise Build Plan** with: header (project + date, then `Total tasks: N | Parallelizable: M | Sequential: K` and overall effort); a task table with columns **# | Task | Scope | Effort | Depends On | Sub-Agent?** (the Sub-Agent? cell names which task it runs parallel with, or `— (must go first)` for a gating task); an **Execution waves** block (which tasks run in which wave + sequential dependencies between waves); and a **Sub-agent allocation** block (which sub-agent takes which task — the main agent keeps the critical path and sequential gates).

#### Blueprint-first gate

If **any** Blueprint Delta items exist, they become **Wave 0** — always sequential and always first, labelled "Wave 0 (blueprint updates — must complete before code)" with each blueprint change listed. Code changes that depend on blueprint decisions cannot start until Wave 0 completes.

### Step 5b: Change Brief

After the Build Plan table, append the **Change Brief for /smith** (the artifact smith consumes), opening with "Based on feedback received <date>". Sections in priority order:
- **Priority 1 — Critical**: each as `<Finding> → <File:line> → <Fix> | Effort: S/M/L`.
- **Priority 2 — Important**: same shape.
- **Priority 3 — Blueprint updates (Wave 0)**: `<Delta item> → <Section to update>`.
- **Execution plan**: paste the wave breakdown + sub-agent allocation from the Build Plan.

### Step 5c: User Confirmation

After presenting the Build Plan and Change Brief, ask the user — using your harness's multi-choice prompt if available, otherwise inline:

```
"Ready to forge? Review the build plan above."
Options:
- "Yes — execute this plan with smith"
- "Adjust the plan first (describe changes)"
- "Update the blueprint only — skip code changes for now"
- "Just the criticals (Wave 1 only)"
- "Show me the full praise report again"
```

If user selects **"Yes"**: invoke `/smith` and pass the full change brief (including wave breakdown) as context. Smith will use the wave/sub-agent structure directly — no re-planning needed.

If user selects **"Adjust"**: incorporate their changes into the plan, re-present, confirm again.

If user selects **"Blueprint only"**: apply Wave 0 blueprint updates, then offer the full plan again.

If user selects **"Just the criticals"**: rebuild the plan scoped to Priority 1 only, confirm, invoke smith.

## Post-Flight

Write learnings to `memory/praise-learnings.md`:

```markdown
## [Date] — [Short Title]
- **Learning**: [what routing pattern worked, what classification was tricky, what art combination was most effective for this type of feedback]
- **Forge-worthy**: [yes/no] — [reason]
```

**Learnings to capture**:
- Which feedback categories consistently triggered which arts
- Feedback formats that were easy vs. hard to classify
- Cases where a blueprint delta was found vs. implementation gaps
- Effective change brief formats that smith consumed cleanly

Learnings marked `Forge-worthy: yes` will be promoted by the `/forge` cycle's fold phase.

---

The forge improves through use. Every piece of feedback closes a loop:
feedback → classify → parallel arts (/preen, /probe, /poke, /press) + Blueprint Delta → Praise Report → Build Plan (waves + sub-agents, user-approved) → Change Brief → /smith.
