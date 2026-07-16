---
name: temper
description: Repeated evaluative passes (poke + press) with confidence-weighted consolidation. Runs each art 3x via subagents, deduplicates findings, and produces a single hardened report.
---
<!-- model: inherit | fan-out: poke+press passes → sonnet (ship-gate runs → opus); consolidation + Temper Verdict at opus -->

# /temper — Hardened Evaluation

Tempering is repeated thermal cycles that transform brittle metal into resilient steel. This skill runs `/poke` and `/press` analyses multiple times in parallel, then consolidates findings by confidence — issues that surface consistently across independent runs are real; one-off findings might be noise.

## Arguments
`$ARGUMENTS` — optional: number of passes per art (default 3), e.g., `/temper 5` for 5 passes each. Optional project path as second arg.

## When to Use
- Before major releases (more thorough than a single poke + press)
- When you want confidence-weighted findings instead of a single opinion
- When you suspect false positives from a single evaluative pass

## Step 0: Setup

1. **Resolve forge path** from your harness's global config (e.g., `~/.claude/CLAUDE.md` `forge-path:` line for Claude Code, or the equivalent rules file for other harnesses), managed by `/forge`
2. **Determine project path**: from `$ARGUMENTS` or current working directory
3. **Determine pass count**: from `$ARGUMENTS` or default to 3
4. **Read project context**: the project's `CLAUDE.md`/`AGENTS.md`

## Step 1: Evidence Collection (once)

Evidence is deterministic — collect it once and share across all passes.

Run both scans in parallel (they are independent):

```bash
<forge>/core/scripts/forge-scan.sh poke <project-path>
```

```bash
<forge>/core/scripts/forge-scan.sh press <project-path>
```

Save the outputs as `POKE_EVIDENCE` and `PRESS_EVIDENCE` respectively.

## Step 2: Parallel Analysis Passes

Launch subagents to perform independent analyses (or sequential passes at your session model if your harness lacks parallel sub-agent spawning or per-spawn model selection). Each subagent gets the same evidence but analyzes independently — the LLM reasoning is where variance occurs.

### Finding Format (shared by both poke and press prompts)

All subagent findings MUST use this exact format:

```
FINDING_START
TITLE: [short title]
SEVERITY: [CRITICAL | IMPORTANT | MINOR]
DIMENSION: [which dimension]
SCORE: [1-5, press only — omit for poke]
FILE: [path:line or "N/A" if architectural]
PROBLEM: [description]
FIX: [recommended fix]
EFFORT: [S/M/L]
CODE: [problematic code snippet max 5 lines, poke only — omit for press]
FINDING_END
```

### Shared subagent prompt template

Spawn N sonnet-tier subagents per art (poke + press) in a single parallel batch. Ship-gate branch: when `/temper` is invoked at a ship gate (final gate, hardening gate, or an explicitly hardened run such as `/temper 5` pre-ship), spawn the passes at opus tier instead. Each subagent receives the same scaffold with five variant slots:

```
You are {{PERSONA}}. Analyze the following project evidence
for {{TASK_DESCRIPTION}}.
NEVER use && or ; to chain bash commands.
Do NOT run forge-scan.sh — evidence is provided below.

PROJECT CONTEXT:
[paste project rules-file content]

STACK GUIDE:
Read <forge>/core/skills/forge/stack-guide.md for tech reference.

LEARNINGS:
Read <forge>/learnings/{{LEARNINGS_FILE}} if it exists.

EVIDENCE:
[paste {{EVIDENCE_VAR}}]

REVIEW DIMENSIONS:
{{DIMENSIONS_LIST}}

For each finding, output EXACTLY the FINDING format ({{FINDING_VARIANT}}).
Output ONLY findings. No preamble, no summary, no commentary.
```

**Variant fills:**

| Slot | Poke | Press |
|---|---|---|
| `PERSONA` | "a staff engineer who learned at Uncle Bob's knee" | "a staff engineer performing a pre-launch readiness assessment" |
| `TASK_DESCRIPTION` | "code quality and tech debt issues" | "go-live readiness across 7 dimensions (assign each a score 1-5, 1=not addressed, 5=excellent)" |
| `LEARNINGS_FILE` | `poke-learnings.md` | `press-learnings.md` |
| `EVIDENCE_VAR` | `POKE_EVIDENCE` | `PRESS_EVIDENCE` |
| `DIMENSIONS_LIST` | `1. SOLID & Strategy Patterns / 2. Band-Aids (including source-field fallbacks and client-supplied actor identity) / 3. Framework Misuse / 4. Logging Hygiene / 5. Clean Functions / 6. Dependency Direction & Law of Demeter / 7. Composition over Inheritance` | `1. Security  2. Scalability  3. Operations  4. Compliance / 5. Observability  6. Deployment  7. Documentation` |
| `FINDING_VARIANT` | "with CODE, without SCORE" | "with SCORE, without CODE" |

**Important**: Launch ALL subagents (poke + press) in a single parallel batch. Do not wait for poke to finish before starting press.

## Step 3: Consolidation

Consolidation runs at opus tier — together with the Step 4 Temper Verdict it is the review gate over the sonnet passes: challenge findings whose evidence doesn't hold up before counting them, and adjudicate fuzzy-title merges on defect identity rather than wording (a wrong merge corrupts the confidence counts).

Parse all subagent outputs. For each unique finding (match by TITLE + FILE, fuzzy-match similar titles):

### Confidence Scoring

| Appearances | Confidence | Label |
|-------------|------------|-------|
| N/N passes | **Confirmed** | Every independent pass found this — definitely real |
| >= N/2 passes (round up) | **Likely** | Majority of passes found this — probably real |
| 1 pass only | **Possible** | Single pass found this — may be noise or edge case |

### Severity Promotion

If a finding appears at different severities across passes, use the **highest** severity observed.

### Press Score Consolidation

For each press dimension, average the scores across passes (round to nearest 0.5).

## Step 4: Persist & Output — The Temper Report

**HARD RULE — Always persist the report before displaying it.**

Write the full report to `memory/YYYY-MM-DD-temper-report.md` in the project directory (create `memory/` if needed). This ensures the report survives context compaction, distractions, and session breaks. The user can delete it when done acting on it.

Produce a markdown report with these sections in order:

1. **Header**: Project name, date, pass count, stack
2. **Confidence Legend**: Confirmed / Likely / Possible definitions with pass thresholds
3. **Readiness Scorecard** (press): Table with columns `Dimension | Avg Score | Gaps | Status` — one row per press dimension (7 dims + overall total out of 35). Status: red/yellow/green.
4. **Code Quality Summary** (poke): Table with columns `Dimension | Confirmed | Likely | Possible` — one row per poke dimension (7 dims + total).
5. **Confirmed Findings** (fix these): Each finding with Confidence, Dimension, File, Problem, Fix, Effort. Ordered by severity.
6. **Likely Findings** (review these): Same format.
7. **Possible Findings** (may be noise): Brief, one line each.
8. **Temper Verdict** (opus tier — owned by the orchestrator, never a pass subagent): Confirmed criticals count, confirmed importants count, ship-ready verdict (YES / NO / WITH CONDITIONS), 2-3 sentence executive summary.

## Step 5: Next Steps

After presenting the report, suggest:
- "Report saved to `memory/YYYY-MM-DD-temper-report.md` — delete when done acting on it."
- "Want me to fix the confirmed criticals? Specify by finding title."
- "Run `/pound` for adversarial QA on the weak dimensions."
- Ask the user — using your harness's multi-choice prompt if available, otherwise inline — "Ready to wrap up?" with options "Yes, run /wrap" / "Not yet".

## Notes

- `/temper` does NOT write learnings (it's a task skill, not an art). The individual poke/press analyses within subagents don't write learnings either — they're ephemeral passes.
- For the learning loop, run `/poke` or `/press` individually after temper identifies areas of concern.
- Default 3 passes is a good balance of thoroughness vs. cost. Use 5 for pre-ship critical paths.
