---
name: temper
description: Repeated evaluative passes (poke + press) with confidence-weighted consolidation. Runs each art 3x via subagents, deduplicates findings, and produces a single hardened report.
user-invocable: true
---

# /temper — Hardened Evaluation

Tempering is repeated thermal cycles that transform brittle metal into resilient steel. This skill runs `/poke` and `/press` analyses multiple times in parallel, then consolidates findings by confidence — issues that surface consistently across independent runs are real; one-off findings might be noise.

## Arguments
`$ARGUMENTS` — optional: number of passes per art (default 3), e.g., `/temper 5` for 5 passes each. Optional project path as second arg.

## When to Use
- Before major releases (more thorough than a single poke + press)
- When you want confidence-weighted findings instead of a single opinion
- When you suspect false positives from a single evaluative pass
- As a pre-ship gate alongside or instead of the evaluative trifecta

## Step 0: Setup

1. **Resolve forge path** from `~/.claude/CLAUDE.md` `forge-path:` line
2. **Determine project path**: from `$ARGUMENTS` or current working directory
3. **Determine pass count**: from `$ARGUMENTS` or default to 3
4. **Read project context**: the project's `CLAUDE.md`

## Step 1: Evidence Collection (once)

Evidence is deterministic — collect it once and share across all passes.

```bash
<forge>/scripts/forge-scan.sh poke <project-path>
```

Save the output as `POKE_EVIDENCE`.

```bash
<forge>/scripts/forge-scan.sh press <project-path>
```

Save the output as `PRESS_EVIDENCE`.

## Step 2: Parallel Analysis Passes

Launch subagents to perform independent analyses. Each subagent gets the same evidence but analyzes independently — the LLM reasoning is where variance occurs.

### Poke Passes

Spawn N subagents in parallel (where N = pass count), each with this prompt template:

```
You are a staff engineer who learned at Uncle Bob's knee. Analyze the following
project evidence for code quality and tech debt issues.

RULES:
- NEVER use && or ; to chain bash commands
- Do NOT run forge-scan.sh — evidence is provided below
- Produce findings in the EXACT format specified below

PROJECT CONTEXT:
[paste project CLAUDE.md content]

STACK GUIDE:
Read <forge>/skills/forge/stack-guide.md for tech reference.

LEARNINGS:
Read <forge>/learnings/poke-learnings.md if it exists.

EVIDENCE:
[paste POKE_EVIDENCE]

REVIEW DIMENSIONS (from /poke):
1. SOLID & Strategy Patterns
2. Band-Aids (including source-field fallbacks and client-supplied actor identity)
3. Framework Misuse
4. Logging Hygiene
5. Clean Functions
6. Dependency Direction & Law of Demeter
7. Composition over Inheritance

For each finding, output EXACTLY this format (one per finding):

FINDING_START
TITLE: [short title]
SEVERITY: [CRITICAL | IMPORTANT | MINOR]
DIMENSION: [which of the 7 dimensions]
FILE: [path:line]
PROBLEM: [why this is an issue]
FIX: [recommended fix]
EFFORT: [S/M/L]
CODE: [problematic code snippet, max 5 lines]
FINDING_END

Output ONLY findings in this format. No preamble, no summary, no commentary.
```

### Press Passes

Spawn N subagents in parallel, each with this prompt template:

```
You are a staff engineer performing a pre-launch readiness assessment.
Analyze the following project evidence across 7 readiness dimensions.

RULES:
- NEVER use && or ; to chain bash commands
- Do NOT run forge-scan.sh — evidence is provided below
- Produce findings in the EXACT format specified below

PROJECT CONTEXT:
[paste project CLAUDE.md content]

STACK GUIDE:
Read <forge>/skills/forge/stack-guide.md for tech reference.

LEARNINGS:
Read <forge>/learnings/press-learnings.md if it exists.

EVIDENCE:
[paste PRESS_EVIDENCE]

REVIEW DIMENSIONS (from /press):
1. Security
2. Scalability
3. Operations
4. Compliance
5. Observability
6. Deployment
7. Documentation

For each dimension, also assign a score: 1-5 (1=not addressed, 5=excellent).

For each finding, output EXACTLY this format (one per finding):

FINDING_START
TITLE: [short title]
SEVERITY: [CRITICAL | IMPORTANT | MINOR]
DIMENSION: [which of the 7 dimensions]
SCORE: [1-5 for this dimension]
FILE: [path:line or "N/A" if architectural]
PROBLEM: [what the gap is]
FIX: [recommended fix]
EFFORT: [S/M/L]
FINDING_END

Output ONLY findings in this format. No preamble, no summary, no commentary.
```

**Important**: Launch ALL subagents (poke + press) in a single parallel batch. Do not wait for poke to finish before starting press.

## Step 3: Consolidation

Parse all subagent outputs. For each unique finding (match by TITLE + FILE, fuzzy-match similar titles):

### Confidence Scoring

| Appearances | Confidence | Label |
|-------------|------------|-------|
| N/N passes | **Confirmed** | Every independent pass found this — definitely real |
| >= N/2 passes (round up) | **Likely** | Majority of passes found this — probably real |
| 1 pass only | **Possible** | Single pass found this — may be noise or edge case |

### Severity Promotion

If a finding appears at different severities across passes, use the **highest** severity observed. Confidence should already be HIGH if multiple passes flagged it.

### Press Score Consolidation

For each press dimension, average the scores across passes (round to nearest 0.5). Use the averaged score for the final scorecard.

## Step 4: Output — The Temper Report

```markdown
# Temper Report — [PROJECT NAME]
**Date**: [date] | **Passes**: [N] poke + [N] press | **Method**: /temper
**Stack**: [frameworks]

## Confidence Legend
- **Confirmed** (N/N) — every pass flagged this independently
- **Likely** (>=half) — majority consensus
- **Possible** (1/N) — single pass only, may be noise

---

## Readiness Scorecard (from /press passes)

| Dimension | Avg Score | Gaps | Status |
|-----------|-----------|------|--------|
| Security | X.X/5 | [count] | red/yellow/green |
| Scalability | X.X/5 | [count] | red/yellow/green |
| Operations | X.X/5 | [count] | red/yellow/green |
| Compliance | X.X/5 | [count] | red/yellow/green |
| Observability | X.X/5 | [count] | red/yellow/green |
| Deployment | X.X/5 | [count] | red/yellow/green |
| Documentation | X.X/5 | [count] | red/yellow/green |
| **Overall** | **X.X/35** | **[total]** | **verdict** |

## Code Quality Summary (from /poke passes)

| Dimension | Confirmed | Likely | Possible |
|-----------|-----------|--------|----------|
| SOLID & Strategy Patterns | X | X | X |
| Band-Aids | X | X | X |
| Framework Misuse | X | X | X |
| Logging Hygiene | X | X | X |
| Clean Functions | X | X | X |
| Dependency Direction & Demeter | X | X | X |
| Composition > Inheritance | X | X | X |
| **Total** | **X** | **X** | **X** |

---

## Confirmed Findings (high confidence — fix these)

### [SEVERITY] [Poke|Press] Finding Title
- **Confidence**: Confirmed (N/N passes)
- **Dimension**: [dimension]
- **File**: `path:line`
- **Problem**: [consolidated description]
- **Fix**: [recommended fix]
- **Effort**: S/M/L

[repeat for all confirmed findings, ordered by severity]

## Likely Findings (medium confidence — review these)

[same format, for findings appearing in >=half of passes]

## Possible Findings (low confidence — may be noise)

[same format, for single-pass findings — keep brief, one line each]

---

## Temper Verdict

**Confirmed criticals**: [count] | **Confirmed importants**: [count]
**Ship-ready**: YES / NO / WITH CONDITIONS

[2-3 sentence executive summary: what's hardened, what needs work]
```

## Step 5: Next Steps

After presenting the report, suggest:
- "Want me to fix the confirmed criticals? Specify by finding title."
- "Run `/pound` for adversarial QA on the weak dimensions."
- Use `AskUserQuestion` to prompt: "Ready to wrap up?" with options "Yes, run /wrap" / "Not yet".

## Notes

- `/temper` does NOT write learnings (it's a task skill, not an art). The individual poke/press analyses within subagents don't write learnings either — they're ephemeral passes.
- For the learning loop, run `/poke` or `/press` individually after temper identifies areas of concern.
- Default 3 passes is a good balance of thoroughness vs. cost. Use 5 for pre-ship critical paths.
