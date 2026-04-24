---
name: smith
description: "Master of the forge — consumes a Blueprint + Pattern (or plan file / conversation context) and autonomously builds through iterative heats. Summons apprentices for parallel work, wields every art, and converges on perfection. The Magnum Opus. TRIGGER when: user wants to build/implement a substantial piece of work — from a Blueprint + Pattern, a plan discussed with AI, or conversation context. Assesses scope first; advises against full smith for small work."
user-invocable: true
---
<!-- model: opus -->

# /smith — The Master Builder

The smith is not an art. The smith is the one who wields them all.

## Arguments

`$ARGUMENTS` — one of:
- A path to a Blueprint file (e.g., `ProjectName_Blueprint_V1.0.md`) — smith will also load the paired `[PROJECT]_Pattern_V1.0.md`
- A path to a plan/spec `.md` file (any non-Blueprint markdown with implementation steps)
- A project directory containing a Blueprint (+ Pattern)
- `--force` flag (can combine with any above) — bypasses the scope gate
- Empty — smith auto-detects the work source

### Input Resolution (in priority order)

1. **Explicit path provided** → use it (Blueprint or plan file, detected by content). If Blueprint, also load the paired Pattern file if present.
2. **No path** → scan cwd for `*Blueprint*.md` → load the Blueprint. Then glob for `*Pattern*.md` and load the Pattern alongside.
3. **Blueprint exists, Pattern missing** → warn "Pattern not found — Blueprint has not been probed" and invoke `/probe` before proceeding. The Pattern is smith's source of design truth.
4. **No Blueprint** → check for plan files in `~/.claude/plans/` or conversation context
5. **Conversation context** → if the current conversation contains a discussed spec, architecture, or implementation steps, smith extracts a work spec from it
6. **Nothing found** → error: "No Blueprint, plan, or work context found. Run `/prime` to create a Blueprint and Pattern, or discuss the work first."

### Input Modes

| Mode | Source | Blueprint Sections? | Phase Gates? |
|------|--------|--------------------:|:------------:|
| **Blueprint + Pattern** | `*Blueprint*.md` + `*Pattern*.md` | Yes — numbered sections + validated architecture/UX | Full ceremony |
| **Plan file** | Any `.md` with implementation steps | No — free-form descriptions | Adapted |
| **Conversation** | Work discussed in current session | No — free-form descriptions | Adapted |

In **plan file** and **conversation** modes, smith synthesizes a work spec (see Step 0.5) and maps it to heats using free-form descriptions instead of Blueprint section numbers. Pattern-driven architecture review is skipped — `/poke` + `/press` replace the Pattern's design validation role.

## Step 0: Preflight

1. **Resolve forge path** from `~/.claude/CLAUDE.md` `forge-path:` line
2. **Launch all reads in parallel** (all independent):
   - Read the Blueprint file **and the paired Pattern file** (if present), plan file, or extract work spec from conversation context (per Input Resolution)
   - Read project `CLAUDE.md` for stack, conventions, current state
   - Read `<forge>/skills/forge/stack-guide.md` for tech reference
   - Read `memory/smith-ledger.json` if it exists (resume mode — skip to Session Resume)
   - Read `memory/smith-workspec.md` if it exists (plan/conversation mode resume)
   - Read `memory/smith-learnings.md` if it exists (Layer 1 — orchestration wisdom)
   - Read `memory/smith-apprentice-log.md` if it exists (Layer 3 — delegation wisdom)

**Pattern gate** — if the Blueprint has no paired Pattern file (`[PROJECT]_Pattern_V1.0.md` absent OR present but empty Architecture section), invoke `/probe` on the Blueprint before proceeding. The Pattern is smith's source of design truth — architecture must be validated before the smith swings. If the Blueprint has UI-facing features, also invoke `/preen` to append the UX section after `/probe` completes.

**Pitch gate** — if no `[PROJECT]_Pitch_V1.0.md` exists AND the Blueprint contains business model sections (pricing, revenue, monetization, go-to-market), offer to run `/pitch` before starting. Use `AskUserQuestion` with options: "Yes, validate business model first" / "Skip, model already validated". A `KILL` or `NEEDS RETHINK` verdict surfaces to the user — building toward a broken business model is waste. Pitch writes its verdict as a `<!-- PITCHED: [VERDICT] -->` marker at the top of the Pitch file (or the Blueprint if no Pitch file exists yet).

## Step 0.5: Scope Gate

Before committing to the full smith ceremony, assess whether the work warrants it.

### Work Spec Extraction

Depending on input mode:
- **Blueprint mode** → the blueprint IS the work spec (no extraction needed)
- **Plan file mode** → read the plan file, identify implementation steps, estimate complexity
- **Conversation mode** → scan conversation context for: architecture decisions, implementation steps, file lists, API designs, data models. Synthesize into a structured work spec.

For plan/conversation modes, persist the extracted spec to `memory/smith-workspec.md`:

```markdown
# Smith Work Spec — [Short Title]

## Source
[Plan file path or "conversation context"]

## Scope
[1-2 sentence summary of what's being built]

## Implementation Steps
1. [Step from plan/conversation]
2. ...

## Key Files
- [file] — [action: new/modify/delete]

## Hash
[sha256 of this content — for session resume change detection]
```

### Heat Estimation

Estimate the number of heats from the work spec:
- Each vertical slice (DB → logic → API → UI) = 1 heat
- Each independent module/file group = 1 heat
- Scaffolding/setup = 1 heat if non-trivial
- Testing/hardening = 1 heat if scope warrants it

### Threshold Decision

| Estimated Heats | Decision |
|-----------------|----------|
| **1–2 heats** | **Advise against smith.** Output: "This work is ~N heats — small enough to build directly without the full smith workflow. Just implement it." Exit unless `--force` flag was passed. |
| **3+ heats** | **Proceed.** The work benefits from smith's orchestration, evaluation, and checkpointing. Continue to Step 1. |

The `--force` flag bypasses this gate — the user knows it's small but wants the ceremony (e.g., for learning, or because the work is deceptively complex).

## Step 1: Blueprint Decomposition

Parse the work source to create a build plan.

### Blueprint Mode

When working from a blueprint: the **Consumption Guide** (Section 22 footer) defines priority, and **Section 21** (Build Phases) defines MVP scope. Split the selected phase (default: MVP) into **units**, each containing **heats**:

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

### Plan/Conversation Mode

When working from a plan file or conversation context, use the work spec from Step 0.5:

1. **Group implementation steps into units** by functional area (analogous to blueprint units)
2. **Split each unit into heats** — one heat per vertical slice or independent module
3. **Infer a Foundation unit** if the work requires scaffolding, config changes, or setup
4. **Infer a Hardening unit** if the work has 5+ heats (testing, verification)
5. **Reference steps by description** instead of blueprint section numbers (e.g., "Provider abstraction" instead of "Section 13")

Phase gates are **adapted** for plan/conversation mode:
- Foundation gate → still applies if there's a foundation unit
- Unit completion gates → still apply (evaluate each completed unit)
- Final gate → still applies (convergence loop)
- `/probe` gates are skipped (no blueprint architecture to validate) — replaced by `/poke` + `/press`

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

| # | Unit | Heat | Source | Dependencies | Parallel? |
|---|------|------|--------|--------------|-----------|
| 1 | Foundation | Scaffolding + schema | §13, §16 | — | — |
| 2 | Foundation | Auth system | §3, §15 | Heat 1 | — |
| 3 | Foundation | Dev tooling | — | Heat 1 | Yes (with Heat 2) |
| 4 | Core | User registration | §5.1 | Foundation | — |
| ...| ... | ... | ... | ... | ... |

Estimated heats: N | Parallelizable: M
```

The **Source** column references blueprint section numbers (§N) in blueprint mode, or free-form step descriptions in plan/conversation mode.

Proceed to build. The master doesn't ask permission to start — the work spec is the permission.

## Step 2: The Heat Cycle

Each heat follows: **Plan → Build → Verify → Evaluate → Fix → Checkpoint**

### 2a: Plan

- Read the current heat's target from the ledger
- Identify relevant source (blueprint sections or workspec steps) to implement
- List files to create/modify
- Check dependency graph — if independent heats exist, spawn apprentices (see Apprentice System)

### 2b: Build

Write code following:
- The work source (blueprint spec or workspec steps) for functionality
- The stack guide for technology choices and conventions
- The forge conventions checklist for logging, structure, and dev tooling
- Vertical slices — DB schema → service/business logic → API route → UI component (where applicable)

Smith builds the code itself. The arts evaluate. Apprentices handle independent parallel work.

### 2c: Verify

Run tests and build to establish ground truth before evaluation. Tiered expectations by build stage:

| Stage | Verify Requirement |
|-------|-------------------|
| Foundation heats | `tsc --noEmit` passes, schema pushes clean |
| Core/Supporting heats | Unit tests for the slice pass |
| Phase gates | Integration tests pass |
| Final gate | Full test suite + production build |

Verify results are passed to the evaluation arts as evidence. An art evaluating with test results is an expert; an art evaluating without them is a speculator.

If verify fails, smith fixes before invoking arts — no point evaluating broken code.

### 2d: Evaluate

Select art(s) per the Escalation Ladder, then:

1. **Collect evidence** — run `<forge>/scripts/forge-scan.sh <art> <project-path>` for /poke and /press evaluations
2. **Invoke art(s) via subagents** — each art runs in a subagent with pre-loaded evidence and context. Multiple arts on the same heat run in parallel (evaluate fan-out).
3. **Collect findings** — parse subagent outputs for CRITICAL / IMPORTANT / MINOR classifications

### 2e: Fix

Address findings by severity:

| Severity | Action | Re-evaluate? |
|----------|--------|-------------|
| CRITICAL | Fix immediately | Yes — re-run the evaluating art |
| IMPORTANT | Fix in batch | Yes — re-run after all IMPORTANT fixes |
| MINOR | Log to deferred findings in ledger | No — proceed |

**Circuit breaker**: If the same finding persists after 3 fix-evaluate cycles, smith invokes `/pry` with the specific blocker. If `/pry` finds a path, apply it. If `/pry` confirms a hard wall, smith adapts the approach autonomously — only escalating to `AskUserQuestion` if the arts themselves conflict on the resolution.

### 2f: Checkpoint

After each heat completes (findings clean or deferred):

1. **Update `memory/smith-ledger.json`** — heat status, evaluation results, timing
2. **Update `memory/smith-progress.md`** — human-readable progress
3. **Record checkpoint SHA** — `git rev-parse HEAD` stored in ledger for this heat. At phase gates, also snapshot the ledger itself to `memory/smith-ledger-checkpoint-<gate>.json`.
4. **Capture learnings** — if smith learned something about orchestration (Layer 1) or apprentice effectiveness (Layer 3), write it
5. **Check for milestone**: if this heat completes a unit or phase gate, trigger the appropriate gate evaluation, then commit (see Phase Gate Commits below)

### Rollback

When a later heat breaks earlier work, or the user requests a rollback:

1. Identify the target checkpoint (unit boundary or phase gate) from the ledger's recorded SHAs
2. `git revert --no-commit` all commits since the checkpoint SHA
3. Restore the ledger snapshot from `memory/smith-ledger-checkpoint-<gate>.json`
4. Re-plan forward from the checkpoint, incorporating what was learned from the failed path
5. Learnings from the rolled-back heats are preserved — observations survive rollback, state doesn't

## Step 3: Phase Gates

Phase gates are escalated evaluations at unit and phase boundaries.

| Boundary | Gate Art(s) | Commit |
|----------|-------------|--------|
| Foundation complete | `/probe` | Yes — `/wrap` |
| Core Workflow complete | `/probe` + `/press` | Yes — `/wrap` |
| Each Supporting unit complete | `/press` | Yes — `/wrap` |
| Hardening complete | `/temper` | Yes — `/wrap` |
| **Final Gate** | `/temper` + `/pound` + `/pitch`* | Yes — `/wrap` |

*`/pitch` only if product has monetization — re-validates the business model against what was actually built.

### Phase Gate Commits

Smith commits at every phase gate via `/wrap`. This is a **smith-specific override of the No Auto-Commit rule** — the user delegates commit authority to smith when invoking it. The rationale:

- **Safety**: Long builds (10+ heats) accumulate risk. A session crash without commits loses everything since the last gate.
- **Clean history**: Each commit maps to a logical phase — foundation, core workflow, supporting unit. Reviewable, revertable.
- **Rollback granularity**: `git revert` targets a specific phase, not the entire build.

Smith does NOT ask "ready to commit?" at each gate — that would break flow on a 20-heat build. The user gave smith authority to build; committing at phase gates is part of building.

**When smith invokes `/wrap`**: skip ALL AskUserQuestion prompts (commit confirmation, push decision, doc updates). Lint, stage, save context, commit — straight through, no interruptions. Do NOT push — keep local. The user pushes when they're ready.

Individual heats within a phase are NOT committed separately — too granular. The phase gate is the natural commit boundary.

### The Final Gate — Convergence Loop

The final gate is not a one-shot check. It's a bounded convergence loop:

```
LOOP (max 5 cycles):
  1. Run verify (full test suite + production build)
  2. Run /temper (3x poke + press, confidence-weighted)
  3. Run /pound (21 adversarial personas)
  4. Collect all CRITICAL + IMPORTANT findings
  5. If zero findings → EXIT → blade is clean
  6. STALL CHECK: if findings count >= previous cycle for 2 consecutive cycles →
     AskUserQuestion: "Convergence stalled at [N] findings after [M] cycles."
     Options: "Show findings + I'll decide" / "Accept remaining as deferred" / "Keep going (raise cap)"
  7. Fix all findings
  8. GOTO 1

MAX REACHED (5 cycles without convergence):
  → Present remaining findings with full context
  → AskUserQuestion: "5 cycles complete, [N] findings remain."
     Options: "Accept + ship with deferred" / "More cycles (set new cap)" / "Rollback to [last gate]"
```

The smith keeps hammering until the blade rings clean. Only MINOR findings are accepted as-is. The 5-cycle cap prevents infinite loops — but the user can always raise it.

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
2. **Update source documents**:
   - **Blueprint mode** → update relevant blueprint sections with implementation status markers
   - **Plan file mode** → update the source plan file (mark steps complete, add implementation notes)
   - **Conversation mode** → no source to update (workspec in `memory/smith-workspec.md` serves as the record)
3. Invoke `/wrap` for the final commit
4. Output the forge mark:

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

For plan/conversation mode: compare the workspec hash from `memory/smith-workspec.md` against the ledger's recorded hash. If the source plan file changed or the workspec was updated, re-run decomposition.

## The Apprentice System

> Full details: [apprentice-system.md](apprentice-system.md) — fan-out patterns, waste principle, rules.

**Core principle**: Sequential execution of independent work is waste. Before each heat, smith scans the dependency graph and spawns apprentices for all satisfied inputs. Cap: 3-4 concurrent. Timeout: 3 minutes without progress.

## Art Selection & Escalation

> Full details: [art-selection.md](art-selection.md) — selection matrix, detection rules, escalation ladder.

**Five rungs**: Light (/poke) → Light+Design (+/preen) → Medium (+/press) → Heavy (/temper) → Convergence (/temper+/pound loop). Intensity never decreases. UI heats trigger /preen. Security-critical heats trigger /press or /pound.

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

Learnings marked `Forge-worthy: yes` in any layer get promoted to `~/.claude/learnings/general.md` by the `/forge` cycle's fold phase, same as art learnings. Universal orchestration patterns flow back into the forge for all future smith runs across all projects.

## Progress Tracking

> Full details: [ledger-schema.md](ledger-schema.md) — JSON schema, field explanations, human-readable format.

Two files persist smith state:
- **`memory/smith-ledger.json`** — machine state: plan, heats, evaluations, decisions, checkpoint SHAs, convergence history
- **`memory/smith-progress.md`** — human-readable: current heat, completed table, deferred findings, apprentice activity

## Hard Rules

1. **NEVER** chain bash commands with `&&`, `;`, or `||`. This applies to smith AND all apprentices.
2. **Auto-wrap** at unit boundaries and phase gates. No asking — just invoke `/wrap`.
3. **AskUserQuestion** ONLY when arts produce conflicting recommendations that smith cannot resolve. The master decides everything else autonomously.
4. **NEVER** skip evaluation. Even if the code "looks fine." Every heat gets at minimum `/poke`.
5. **NEVER** proceed past the final gate with CRITICAL or IMPORTANT findings unless the user explicitly accepts them after convergence stalls or max cycles.
6. **ALWAYS** persist the ledger before any milestone or potential interruption point.
7. **ALWAYS** follow the stack guide conventions when building. The blueprint defines *what*, the stack guide defines *how*.
8. **ALWAYS** include the no-chaining rule in every apprentice prompt verbatim.
