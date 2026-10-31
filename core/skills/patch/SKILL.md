---
name: patch
description: "Feedback-driven improvement loop — ingests user feedback, testing findings, or bug reports, routes them through evaluative arts (probe, preen, poke, press), assesses blueprint impact, and hands off to smith with a prioritized change brief. TRIGGER when: user has feedback to process, wants to close the loop on testing results, end-user reports, or QA findings."
---
<!-- model: opus | fan-out: probe/poke legs → opus; preen + non-security press legs → sonnet; security/auth/compliance press items → own opus leg; Phase 4 consolidation at opus -->

# /patch — The Feedback Loop

> **Art** (learnings: `patch-learnings.md`) — follow the [Forge Protocol](../forge/protocol.md) for pre-flight and post-flight.

> Feedback is a gift. Patch makes it actionable.

`/patch` closes the build-ship-learn cycle. It takes raw feedback — from end users, QA sessions, analytics, bug reports, or live testing — and converts it into a prioritized set of improvements. It routes findings through the right evaluative arts, checks if the blueprint needs updating, and hands off a change brief to `/smith`.

## Arguments

`$ARGUMENTS` — one of:
- **File path** to a feedback file (`.md`, `.txt`, `.json`)
- **Inline description** — "users are confused by the nav" or "login fails on mobile"
- **Nothing** — patch will ask for feedback interactively
- `--brief-only` (with any of the above) — stop after the Change Brief (Step 5a) and return it; no prompt, no `/smith`. `/parse` passes this.

## Phase 0: Pre-Flight

Follow the [Forge Protocol](../forge/protocol.md) pre-flight, then scan `opus/` and then cwd for Blueprint + Pattern files (`*Blueprint*.md` and `*Pattern*.md` — the Pattern is /smith's design source; feedback often challenges its decisions). Backward compatibility: if the project still has `memory/praise-learnings.md` (this art's older name), read it too.

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

Spawn one subagent per active category, all in parallel. Spawn the /probe and /poke legs as opus-tier subagents (their diagnoses have no downstream verification gate). Spawn the /preen leg and the non-security /press items as sonnet-tier subagents. Any /press item about security, auth or compliance goes to its own opus-tier leg, matching /press's carve-out. Phase 4 consolidation runs at opus tier, re-grades the sonnet findings, and owns the verdicts (including SHIP BLOCKED). Bind each tier through the spawn's explicit model parameter (protocol Model Tiers rule 6). If your harness does not support parallel sub-agent spawning or per-spawn model selection, run the categories sequentially at your session model.

### Routing Rules

**Only invoke arts with relevant feedback** — never invoke an art with empty input.

#### Subagent brief (one per active category)

Spawn each active category with this brief, substituting the art, tier, and closing instruction from the table below:

```
You are running /[ART] on behalf of /patch.
Focus ONLY on the following feedback — do not run a full audit.
Skip your standard pre-flight (already done by patch).

FEEDBACK TO ANALYZE:
[the classified items for this category]

PROJECT CONTEXT:
[project rules file; for /probe also paste relevant Blueprint sections]

[CLOSING INSTRUCTION]
```

| Art | Fires on | Tier | Closing instruction |
|-----|----------|------|---------------------|
| `/preen` | UX / Design | sonnet | Apply Don Norman's principles and Ive's Razor to each item. For each: the component/screen/flow affected, the principle violated, the concrete fix. Output: Critical / Improvements / Reduce / Polish. |
| `/probe` | Architecture / Tech | opus | For each item: architectural gap, wrong decision, or scaling concern? Check the web for current best practices on the specific concern. Severity: CRITICAL / IMPORTANT / MINOR. |
| `/poke` | Code Quality / Performance | opus | For each item: trace the likely code location, diagnose the root cause, propose the fix. Output FILE, PROBLEM, FIX, EFFORT with severity CRITICAL / IMPORTANT / MINOR. |
| `/press` | Readiness / Operations | sonnet (security, auth, compliance items: opus) | For each item: name the readiness dimension (Security, Scalability, Operations, Compliance, Observability, Deployment, Documentation), score 1–5, identify the gap, propose the remediation. |

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

## Phase 4: Consolidation — The Patch Report

After all Phase 2 subagents and Phase 3 complete, merge into a single report. Run the consolidation at opus tier: it is the review gate over the sonnet legs (/preen, /press) — re-grade their findings rather than merging them as-is — and it owns the final verdict, including SHIP BLOCKED.

**Persist the report first** to `memory/YYYY-MM-DD-patch-report.md` before displaying.

Structure (markdown, sections in this order):
- **Title + meta**: `# /patch Report — <project>`, then `Date | Feedback items: N | Arts invoked: <list>`.
- **Feedback Summary** — 1-3 sentences on what the feedback reveals about the product.
- **Critical (fix before next ship)** — consolidated CRITICAL findings from all arts, **ordered by user impact**; each as `**<Title>** · *<art>* · File: <path:line or N/A>` with Problem / Fix / Effort (S/M/L) sub-bullets.
- **Important (fix this sprint)** — IMPORTANT findings, same shape.
- **Minor (backlog)** — MINOR findings, one line each.
- **Blueprint Delta** — output from Phase 3.
- **Patch Verdict** — Arts invoked; counts of Criticals / Importants / Blueprint changes; **Recommendation** (one verdict from the table below); 2-3 sentence executive summary of meaning + next step.

### Verdict Definitions

| Verdict | Meaning |
|---------|---------|
| **SHIP BLOCKED** | Critical findings that must be fixed before the next release |
| **PATCH NEEDED** | Important findings; patch release warranted |
| **POLISH PASS** | Only minor + UX improvements; invoke `/smith` with polish scope |
| **BLUEPRINT UPDATE** | Blueprint needs revision before new features are built |
| **CLEAR** | Feedback processed, no actionable code changes needed |

## Phase 5: Smith Handoff

### Step 5a: Change Brief

Write the **Change Brief for /smith**, the input smith decomposes into heats. Open it with "Based on feedback received <date>", then list in priority order:
- **Blueprint deltas first**: any Add or Update items from Phase 3, as `<Delta item> → <Section to update>`. They land before any code that depends on them.
- **Priority 1 — Critical**: `<Finding> → <File:line> → <Fix> | Effort: S/M/L`.
- **Priority 2 — Important**: same shape.
- **Dependencies and risk notes**: ordering constraints the findings imply (schema before API before UI), and any auth, payment or migration item smith must grade T3.

Smith does its own heat decomposition, grading and parallelization. Patch supplies the what and the order constraints, not the waves.

### Step 5b: User Confirmation

Ask the user with your harness's multi-choice prompt if available, otherwise inline. The recommended option comes first:
- "Yes — hand this brief to /smith"
- "Just the criticals" (blueprint deltas plus Priority 1)
- "Update the blueprint only"
- "Adjust the brief first"

On **Yes** or **Just the criticals**, invoke `/smith` with the brief, scoped as chosen, as its work source. On **Blueprint only**, apply the deltas, then offer the brief again. On **Adjust**, incorporate the changes and ask again.

With `--brief-only` (as `/parse` passes), stop after 5a and return the brief. Do not ask, and do not invoke `/smith`.

## Post-Flight

Follow the [Forge Protocol](../forge/protocol.md) post-flight, writing learnings to `memory/patch-learnings.md`. Capture:
- Which feedback categories consistently triggered which arts
- Feedback formats that were easy vs. hard to classify
- Cases where a blueprint delta was found vs. implementation gaps
- Effective change brief formats that smith consumed cleanly
