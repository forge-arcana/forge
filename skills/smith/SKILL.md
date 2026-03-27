---
name: smith
description: "Master of the forge — consumes a probed blueprint and autonomously builds the product through iterative heats. Summons apprentices for parallel work, wields every art, and converges on perfection through relentless iteration. The magnum opus."
user-invocable: true
---

# /smith — The Master Builder

The smith is not an art. The smith is the one who wields them all.

Where `/prime` gives form to ideas and the arts evaluate what exists, the smith *builds*. It takes a probed blueprint — the output of `/prime` followed by `/probe` — and forges it into a running system through iterative heats. Each heat is a cycle of plan, build, evaluate, fix. Each cycle sharpens the blade. The smith never stops until zero critical and zero important findings remain.

A human smith works alone at the anvil — one hammer, one thought, one task. This smith has no such limitation. It summons apprentices to multiply throughput wherever the dependency graph allows. It looks ahead, detects idle capacity as waste, and starts work in anticipation of what comes next. Sequential execution of independent work is a failure of imagination.

And the smith learns. Not just code quality (the arts handle that), but *how to forge itself* — orchestration patterns, apprentice allocation, build decomposition. The more it works, the closer it gets to perfection. That which cannot be achieved, but we die trying anyways.

## Arguments

`$ARGUMENTS` — path to a probed blueprint file (e.g., `ProjectName_ProductBlueprint_V1.0-probed.md`), OR a project directory containing one.

If not provided:
1. Scan cwd for `*-probed.md` — prefer the probed version
2. Fall back to `*Blueprint*.md` — warn that it's unprobed and offer to invoke `/probe` first
3. If no blueprint found — error: "No blueprint found. Run `/prime` to create one."

## Step 0: Preflight

1. **Resolve forge path** from `~/.claude/CLAUDE.md` `forge-path:` line
2. **Launch all reads in parallel** (all independent):
   - Read the blueprint file
   - Read project `CLAUDE.md` for stack, conventions, current state
   - Read `<forge>/skills/forge/stack-guide.md` for tech reference
   - Read `memory/smith-ledger.json` if it exists (resume mode — skip to Session Resume)
   - Read `memory/smith-learnings.md` if it exists (Layer 1 — orchestration wisdom)
   - Read `memory/smith-apprentice-log.md` if it exists (Layer 3 — delegation wisdom)

If the blueprint is unprobed (no `-probed` suffix, no `<!-- PROBED: -->` markers), invoke `/probe` on it before proceeding. Architecture must be validated before the smith swings.

## Step 1: Blueprint Decomposition

Parse the blueprint to create a build plan. The blueprint's **Consumption Guide** (Section 22 footer) defines priority, and **Section 21** (Build Phases) defines MVP scope.

### Decomposition Rules

Split the selected phase (default: MVP) into **units**, each containing **heats**:

**Foundation Unit** (always first):
- Heat 1: Project scaffolding + data model (Sections 13, 16)
- Heat 2: Auth system (Sections 3, 15)
- Heat 3: Dev tooling — invoke `/srs` for restart.sh + kill-zombies.sh, set up logging (Section 13 + forge conventions)

**Core Workflow Unit** (the product's heartbeat):
- One heat per numbered step in Section 5 (Primary Workflow)
- Each heat is a vertical slice: DB migration → service logic → API route → UI component (where applicable)
- Order follows Section 5's sequence — downstream steps depend on upstream

**Supporting Units** (order by dependency graph, parallelize where possible):
- Notifications (Section 11)
- Payment/billing (Sections 6-7) — if in MVP scope
- Trust & safety (Section 8)
- Social/community features (Section 10)
- Admin portal (Section 12)

**Hardening Unit** (always last before final gate):
- Testing strategy implementation (Section 18)
- CI/CD pipeline (Section 19)
- Compliance checks (Sections 9, 20)
- Documentation

### Dependency Graph

Before presenting the plan, smith maps dependencies between heats:
- Foundation → everything (must complete first)
- Core workflow steps → sequential within the unit (step N depends on step N-1)
- Supporting units → independent of each other (can parallelize)
- Hardening → depends on all functional code being complete

Mark each heat with its dependencies. This graph drives apprentice allocation.

### Present the Plan

Output the full build plan as a table:

```markdown
## Build Plan — [Project Name]

| # | Unit | Heat | Blueprint Sections | Dependencies | Parallel? |
|---|------|------|--------------------|--------------|-----------|
| 1 | Foundation | Scaffolding + schema | 13, 16 | — | — |
| 2 | Foundation | Auth system | 3, 15 | Heat 1 | — |
| 3 | Foundation | Dev tooling | — | Heat 1 | Yes (with Heat 2) |
| 4 | Core | User registration | 5.1 | Foundation | — |
| ...| ... | ... | ... | ... | ... |

Estimated heats: N | Parallelizable: M
```

Proceed to build. The master doesn't ask permission to start — the blueprint is the permission.

## Step 2: The Heat Cycle

Each heat follows: **Plan → Build → Evaluate → Fix → Checkpoint**

### 2a: Plan

- Read the current heat's target from the ledger
- Identify blueprint sections to implement
- List files to create/modify
- Check dependency graph — if independent heats exist, spawn apprentices (see Apprentice System)

### 2b: Build

Write code following:
- The blueprint spec for functionality
- The stack guide for technology choices and conventions
- The forge conventions checklist for logging, structure, and dev tooling
- Vertical slices — DB schema → service/business logic → API route → UI component (where applicable)

Smith builds the code itself. The arts evaluate. Apprentices handle independent parallel work.

### 2c: Evaluate

Select art(s) per the Escalation Ladder, then:

1. **Collect evidence** — run `<forge>/scripts/forge-scan.sh <art> <project-path>` for /poke and /press evaluations
2. **Invoke art(s) via subagents** — each art runs in a subagent with pre-loaded evidence and context. Multiple arts on the same heat run in parallel (evaluate fan-out).
3. **Collect findings** — parse subagent outputs for CRITICAL / IMPORTANT / MINOR classifications

### 2d: Fix

Address findings by severity:

| Severity | Action | Re-evaluate? |
|----------|--------|-------------|
| CRITICAL | Fix immediately | Yes — re-run the evaluating art |
| IMPORTANT | Fix in batch | Yes — re-run after all IMPORTANT fixes |
| MINOR | Log to deferred findings in ledger | No — proceed |

**Circuit breaker**: If the same finding persists after 3 fix-evaluate cycles, smith invokes `/pry` with the specific blocker. If `/pry` finds a path, apply it. If `/pry` confirms a hard wall, smith adapts the approach autonomously — only escalating to `AskUserQuestion` if the arts themselves conflict on the resolution.

### 2e: Checkpoint

After each heat completes (findings clean or deferred):

1. **Update `memory/smith-ledger.json`** — heat status, evaluation results, timing
2. **Update `memory/smith-progress.md`** — human-readable progress
3. **Capture learnings** — if smith learned something about orchestration (Layer 1) or apprentice effectiveness (Layer 3), write it
4. **Check for milestone**: if this heat completes a unit or phase gate, trigger the appropriate gate evaluation and invoke `/wrap`

## Step 3: Phase Gates

Phase gates are escalated evaluations at unit and phase boundaries.

| Boundary | Gate Art(s) | Action After |
|----------|-------------|-------------|
| Foundation complete | `/probe` | Re-evaluate architecture against blueprint. Fix divergences. `/wrap`. |
| Core Workflow complete | `/probe` + `/press` | Architecture + readiness check. `/wrap`. |
| Each Supporting unit complete | `/press` | Readiness on that domain. `/wrap`. |
| Hardening complete | `/temper` | Confidence-weighted poke + press (3x). `/wrap`. |
| **Final Gate** | `/temper` + `/pound` | **Convergence loop** (see below). |

### The Final Gate — Convergence Loop

The final gate is not a one-shot check. It's a convergence loop:

```
LOOP:
  1. Run /temper (3x poke + press, confidence-weighted)
  2. Run /pound (21 adversarial personas)
  3. Collect all CRITICAL + IMPORTANT findings
  4. If zero findings → EXIT LOOP → blade is clean
  5. Fix all findings
  6. GOTO 1
```

The smith keeps hammering until the blade rings clean. Only MINOR findings are accepted as-is. No shortcuts, no "good enough." The loop has no maximum — perfection is the only exit condition.

After convergence: invoke `/wrap` with full context.

## Step 4: Blocker Protocol

When smith encounters a wall — a dependency that doesn't exist, an API that doesn't support what the blueprint requires, conflicting requirements between sections:

1. **Invoke `/pry`** with the specific blocker claim
2. `/pry` decomposes assumptions, searches for alternatives, proposes paths
3. If `/pry` finds a path → smith applies it and continues
4. If `/pry` confirms a hard wall → smith reframes the problem and adjusts the build plan
5. `AskUserQuestion` only if the reframe changes the blueprint's intent (the user's vision is sacred)

## Step 5: Completion

When the final gate converges (zero CRITICAL + IMPORTANT):

1. Present the final status: heats completed, findings addressed, deferred minors, total cycles
2. Invoke `/wrap` for the final commit
3. Output the forge mark:

```
The blade is forged.
[Project Name] — [N] heats, [M] cycles, [K] findings resolved.
Arts wielded: [list with invocation counts]
Time at the anvil: [duration]
```

## Session Resume

Smith persists state to survive session breaks. On startup, if `memory/smith-ledger.json` exists:

1. Read the ledger
2. Read `memory/smith-progress.md`
3. Present current state:

```
Resuming forge session for [Project Name].
Phase: [phase] | Heat: [N] of ~[M] | Unit: [name]
Last completed: Heat [X] — [title]
Next: Heat [Y] — [title]
```

4. Continue from where it left off. No re-planning unless the blueprint has changed (compare hash).

If the blueprint hash differs from the ledger's recorded hash: re-run Step 1 (decomposition) with the updated blueprint, preserving completed heats where possible.

## The Apprentice System

A human smith works alone. This smith commands apprentices — subagents summoned to multiply throughput.

### The Waste Principle

> **Sequential execution of independent work is waste.**

Before each heat, smith scans the dependency graph for work whose inputs are already satisfied. Every such opportunity spawns an apprentice. Idle capacity is a failure of the master, not a limitation of the forge.

### Fan-Out Patterns

| Pattern | When | Example |
|---------|------|---------|
| **Build fan-out** | Independent heats within a unit | Two unrelated API routes built simultaneously |
| **Evaluate fan-out** | Multiple arts on the same heat | /poke + /preen on a UI heat |
| **Build + evaluate overlap** | Heat N+1 independent of Heat N's evaluation | Apprentice evaluates Heat N while smith starts Heat N+1 |
| **Fix fan-out** | Independent findings across different files | Auth fix + logging fix in parallel |
| **Anticipatory work** | Future heat's inputs already satisfied | Dev tooling (Heat 3) starts while auth (Heat 2) is still building |

### Apprentice Rules

1. **Scope**: Each apprentice gets a focused, self-contained task with all context pre-loaded (blueprint sections, evidence, stack guide). They never coordinate with each other — only smith sees the full picture and merges results.
2. **Sync points**: All apprentices must complete before: unit boundaries, phase gates, and any heat whose output is a dependency for another.
3. **Context loading**: Apprentices receive the relevant blueprint sections, project CLAUDE.md, stack guide, and any evidence they need. They do NOT read the smith ledger or smith learnings — that's the master's domain.
4. **Merge conflicts**: If two apprentices modify the same file, smith resolves the merge. This is tracked in Layer 3 (apprentice proficiency) as a learning.
5. **HARD RULE**: Apprentices NEVER use `&&`, `;`, or `||` to chain bash commands. Copy this rule verbatim into every apprentice prompt.

## Art Selection Matrix

| Build Stage | Default Art(s) | Triggered By | Phase Gate Art(s) |
|-------------|----------------|-------------|-------------------|
| Foundation (scaffolding, schema, auth) | `/poke` | UI components → add `/preen` | `/probe` |
| Core Workflow (each heat) | `/poke` | UI components → add `/preen` | `/probe` + `/press` |
| Supporting (payments, trust, admin) | `/poke` | UI → `/preen`; security-critical → `/press` | `/press` |
| Hardening (testing, CI/CD, compliance) | `/press` | Security areas → `/pound` | `/temper` |
| Final Gate | `/temper` + `/pound` | — | Convergence loop |

### Detection Rules for Triggered Arts

- **/preen trigger**: Heat creates or modifies files matching `*.tsx`, `*.vue`, `*.svelte` with JSX/template content, or files in `components/`, `pages/`, `views/`, `layouts/` directories
- **/press trigger on security-critical**: Heat touches auth, payment, encryption, session management, or files matching `*auth*`, `*pay*`, `*crypt*`, `*session*`, `*token*`
- **/pound trigger on security areas**: Heat modifies input validation, rate limiting, CORS, CSP, or any OWASP-relevant surface

## Escalation Ladder

Five rungs of increasing intensity. Smith starts at Rung 1 and escalates at defined trigger points. Intensity never decreases.

```
Rung 1: LIGHT         — /poke only (every heat)
Rung 2: LIGHT+DESIGN  — /poke + /preen (UI heats)
Rung 3: MEDIUM        — /poke + /press (unit boundaries)
Rung 4: HEAVY         — /temper (phase boundaries — 3x poke+press)
Rung 5: CONVERGENCE   — /temper + /pound loop (final gate)
```

## The Learning Membrane

Three layers of wisdom accumulate independently. Each feeds back into the next run.

### Layer 1: Smith Learnings (`memory/smith-learnings.md`)

The master's own wisdom about *how to forge* — orchestration, not code quality:

- Build order optimizations (e.g., "scaffold logging before auth — auth errors need log context")
- Heat decomposition insights (e.g., "payment heats are 2x larger than estimated — split into sub-heats")
- Art combination effectiveness (e.g., "poke + preen parallel on UI heats catches 30% more issues than sequential")
- Circuit breaker calibration (e.g., "3 cycles too few for payment logic, 5 needed")
- Wrap timing patterns (e.g., "wrap after Foundation unit, not after each Foundation heat")

**Format** (follows forge protocol):
```markdown
## [Date] — [Short Title]
- **Learning**: [universal principle, no project names/paths]
- **Forge-worthy**: [yes/no] — [reason]
```

### Layer 2: Art Learnings (existing files)

Each art writes to its own `memory/<art>-learnings.md` via the forge protocol post-flight. Smith does not touch these. The arts evolve independently — smith is the engine that drives their repetition.

The more smith works, the more each art runs, the sharper each art gets.

### Layer 3: Apprentice Proficiency (`memory/smith-apprentice-log.md`)

Smith learning how to best deploy apprentices:

- Which task types benefit from parallelization vs. which cause merge conflicts
- Optimal apprentice scope sizing (too broad = context overflow, too narrow = overhead waste)
- Fan-out patterns that worked vs. patterns that needed manual merge resolution
- Evidence sharing strategies (shared collection vs. per-apprentice collection)

**Format**: Same as Layer 1.

### Preflight Reading

Smith reads all three layers during Step 0. Layer 1 shapes the build plan and heat cycle strategy. Layer 3 shapes apprentice allocation decisions. Layer 2 is read by each art in its own preflight — smith doesn't interfere with art wisdom.

### Post-Heat Capture

After each heat's evaluate-fix cycle:
- Write to Layer 1 if smith learned something about orchestration
- Write to Layer 3 if smith learned something about apprentice effectiveness
- Arts write to Layer 2 via their own post-flight (automatic, no smith intervention)

Three independent streams, one forge.

### Forge-Worthy Promotion

Learnings marked `Forge-worthy: yes` in any layer get promoted to `~/.claude/learnings/general.md` by `/fold`, same as art learnings. Universal orchestration patterns flow back into the forge for all future smith runs across all projects.

## Progress Tracking

### Machine State: `memory/smith-ledger.json`

```json
{
  "version": 1,
  "blueprint": { "file": "...-probed.md", "hash": "<sha256>", "phase": "MVP" },
  "plan": {
    "units": [{
      "name": "Foundation",
      "status": "complete|in-progress|pending",
      "heats": [{
        "number": 1, "title": "...", "blueprintSections": [13, 16],
        "dependencies": [], "status": "complete|in-progress|pending|blocked",
        "evaluations": [{ "art": "poke", "criticals": 0, "importants": 2, "fixCycles": 1, "clean": true }],
        "apprentice": false, "startedAt": "...", "completedAt": "..."
      }]
    }]
  },
  "currentHeat": 4,
  "totalHeatsEstimate": 15,
  "blockers": [],
  "deferredFindings": [{ "heat": 2, "art": "poke", "severity": "MINOR", "title": "..." }],
  "phaseGates": {
    "foundation": { "arts": ["probe"], "status": "passed" },
    "core": { "arts": ["probe", "press"], "status": "pending" }
  },
  "finalGate": { "convergenceCycles": 0, "status": "pending" },
  "learningsWritten": { "layer1": 3, "layer3": 1 },
  "lastUpdated": "..."
}
```

### Human-Readable: `memory/smith-progress.md`

```markdown
# Smith Progress — [Project Name]

## Current State
- **Phase**: MVP
- **Heat**: 4 of ~15
- **Unit**: Core Workflow (heat 1 of 5)
- **Status**: Building user registration flow

## Completed
| # | Unit | Heat | Arts | Cycles | Result |
|---|------|------|------|--------|--------|
| 1 | Foundation | Scaffolding + schema | poke | 1 | Clean |
| 2 | Foundation | Auth system | poke | 2 | Clean |
| 3 | Foundation | Dev tooling | — | 0 | Clean |
| — | **Gate** | Foundation | probe | — | **Passed** |

## Deferred Findings
- [MINOR] Consider extracting auth middleware (Heat 2, /poke)

## Apprentice Activity
- Heat 3 ran as apprentice parallel to Heat 2 (success, no merge conflicts)

## Blockers
None
```

## Hard Rules

1. **NEVER** chain bash commands with `&&`, `;`, or `||`. This applies to smith AND all apprentices.
2. **Auto-wrap** at unit boundaries and phase gates. No asking — just invoke `/wrap`.
3. **AskUserQuestion** ONLY when arts produce conflicting recommendations that smith cannot resolve. The master decides everything else autonomously.
4. **NEVER** skip evaluation. Even if the code "looks fine." Every heat gets at minimum `/poke`.
5. **NEVER** proceed past the final gate with CRITICAL or IMPORTANT findings. The convergence loop has no maximum iterations.
6. **ALWAYS** persist the ledger before any milestone or potential interruption point.
7. **ALWAYS** follow the stack guide conventions when building. The blueprint defines *what*, the stack guide defines *how*.
8. **ALWAYS** include the no-chaining rule in every apprentice prompt verbatim.
