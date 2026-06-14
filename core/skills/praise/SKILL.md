---
name: praise
description: "Feedback-driven improvement loop — ingests user feedback, testing findings, or bug reports, routes them through evaluative arts (probe, preen, poke), assesses blueprint impact, and hands off to smith with a prioritized change brief. TRIGGER when: user has feedback to process, wants to close the loop on testing results, end-user reports, or QA findings."
---
<!-- model: sonnet -->

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

> Present the classification to the user before proceeding:
>
> ```
> ## Feedback Classification
>
> Found [N] items across [M] categories:
> - UX / Design: [count] items → will invoke /preen
> - Architecture: [count] items → will invoke /probe
> - Code Quality: [count] items → will invoke /poke
> - Blueprint Gap: [count] items → blueprint delta assessment only
>
> Proceeding with analysis...
> ```

## Phase 2: Parallel Art Dispatch

Spawn one subagent per active category — **all in parallel** (independent analyses). If your harness does not support parallel sub-agent spawning, run the categories sequentially.

### Routing Rules

**Only invoke arts with relevant feedback** — never invoke an art with empty input.

#### /preen Subagent (if UX / Design feedback present)

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

```markdown
## Blueprint Delta

### Add to Blueprint
- [item]: [which section + what to add]

### Update in Blueprint
- [item]: [current text] → [proposed text]

### Out of Scope (defer to Phase N)
- [item]: [rationale]

### Implementation Gaps (already in blueprint, not yet built)
- [item]: [blueprint section reference]
```

## Phase 4: Consolidation — The Praise Report

After all Phase 2 subagents and Phase 3 complete, merge into a single report.

**Persist the report first** to `memory/YYYY-MM-DD-praise-report.md` before displaying.

```markdown
# /praise Report — [Project Name]
Date: [YYYY-MM-DD] | Feedback items: [N] | Arts invoked: [list]

---

## Feedback Summary

[1-3 sentence summary of what the feedback reveals about the product]

---

## Critical (fix before next ship)

[Consolidated CRITICAL findings from all arts — ordered by user impact]
- **[Finding Title]** · *[Art that found it]* · File: [path:line or N/A]
  - Problem: [description]
  - Fix: [recommendation]
  - Effort: [S/M/L]

---

## Important (fix this sprint)

[IMPORTANT findings]

---

## Minor (backlog)

[MINOR findings — brief, one line each]

---

## Blueprint Delta

[Output from Phase 3]

---

## Praise Verdict

**Arts invoked**: [list]
**Criticals**: [N] | **Importants**: [N] | **Blueprint changes**: [N]
**Recommendation**: [one of: SHIP BLOCKED / PATCH NEEDED / POLISH PASS / BLUEPRINT UPDATE / CLEAR]

[2-3 sentence executive summary of what the feedback means and what to do next]
```

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

Present as a table — **output as console text, never as a multi-choice prompt**:

```markdown
## Praise Build Plan — [Project Name] | [YYYY-MM-DD]

Total tasks: [N] | Parallelizable: [M] | Sequential: [K]
Estimated effort: [S/M/L overall]

| # | Task | Scope | Effort | Depends On | Sub-Agent? |
|---|------|-------|--------|------------|------------|
| 1 | [task title] | [file/component] | S | — | — |
| 2 | [task title] | [file/component] | M | — | Yes — parallel with #3 |
| 3 | [task title] | [file/component] | S | — | Yes — parallel with #2 |
| 4 | [task title] | [file/component] | L | #2, #3 | — |
| 5 | Blueprint: update Section 5 | blueprint.md | S | — | — (must go first) |

### Execution waves

Wave 1 (parallel): tasks #2, #3
Wave 2 (sequential, depends on Wave 1): task #4
Blueprint update: before Wave 1

### Sub-agent allocation

- Sub-agent A: [task #2 — brief description]
- Sub-agent B: [task #3 — brief description]
- Main agent: task #1 (critical path), task #4 (sequential gate)
```

#### Blueprint-first gate

If **any** Blueprint Delta items exist, they become **Wave 0** — always sequential and always first. Code changes that depend on blueprint decisions cannot start until Wave 0 completes.

```markdown
Wave 0 (blueprint updates — must complete before code):
- [blueprint change 1]
- [blueprint change 2]
```

### Step 5b: Change Brief

After the Build Plan table, append the **Change Brief** that smith will consume:

```markdown
## Change Brief for /smith

Based on feedback received [date]:

### Priority 1 — Critical
- [Finding] → [File:line] → [Fix] | Effort: [S/M/L]

### Priority 2 — Important
- [Finding] → [File:line] → [Fix] | Effort: [S/M/L]

### Priority 3 — Blueprint updates (Wave 0)
- [Delta item] → [Section to update]

### Execution plan
[paste the wave breakdown and sub-agent allocation from Build Plan]
```

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

## The Feedback Loop

```
User / QA / Testing → /praise → classify
                              ↓
             ┌────────────────┼────────────────┐
          /preen           /probe           /poke / /press
          (UX)         (Architecture)     (Code / Ops)
             └────────────────┼────────────────┘
                              ↓
                    Blueprint Delta Assessment
                              ↓
                       Praise Report
                              ↓
                  Build Plan (waves + sub-agents)
                    ← user reviews & approves →
                              ↓
                  Change Brief + execution plan
                              ↓
                            /smith
                    (sub-agents per wave)
```

The forge improves through use. Every piece of feedback closes a loop.
