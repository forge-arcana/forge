# Claude Code — Harness Reference (descriptive)

This file is **descriptive, not authoritative**. It is the Claude Code target of `/forge` Phase 3a: approved config rows merge into its harness tables. No script classifies config drift — the model assembles those rows — and the HARD RULES are never synced through it. It records the Claude-Code-specific harness setup: which tools and permissions the reference template grants, editor conventions, and the shorthand/auto-invocation behaviour a Claude Code membrane exhibits. Since the rules moved to the FORGE-RULES block, a current membrane rules file carries only `forge-path:` and that block; the sections below describe behaviour delivered by skills and by `core/rules/`, and have no counterpart in the membrane file to diff against.

**The HARD RULES are not owned here.** They live in `<forge>/core/rules/` (`development-discipline.md` + `forge-governance.md`) and deploy one-way into the marker-delimited `FORGE-RULES` block of `~/.claude/CLAUDE.md` on every `/forge` cast (`cast-deploy.sh --rules`). Read `core/rules/` for the current rule text; any rule quoted below is a convenience copy that may lag.
---

## Workflow Orchestration

### 1. Plan Mode Default

Claude enters **plan mode** for any non-trivial task (3+ steps or architectural decisions). This means it writes a detailed spec before touching code. If something goes wrong mid-task, it stops and re-plans rather than pushing forward blindly. Plan mode is also used for verification steps — not just building.

### 2. Subagent Strategy

Complex work is parallelized using **subagents** — lightweight child contexts that handle focused subtasks (research, exploration, analysis) without polluting the main conversation window. Each subagent gets one task. This keeps context clean and lets Claude throw more compute at hard problems.

### 3. Self-Improvement Loop

After any correction from the user, Claude **immediately updates its learnings** (in memory files or the project's `AGENTS.md`). It writes rules for itself to prevent the same mistake from recurring. This creates a feedback loop where error rates drop over time as the rule set grows.

### 4. Verification Before Done

Owned by `core/rules/development-discipline.md` ("Verification Before Done" and "Visual Changes Require Screenshots") and deployed in the FORGE-RULES block. Not restated here.

### 5. Demand Elegance (Balanced)

For non-trivial changes, Claude pauses to consider whether there's a more elegant approach. If a fix feels hacky, it restarts with full context. However, this is balanced — simple, obvious fixes don't get over-engineered.

### 6. Autonomous Bug Fixing — Logs First, Always

Owned by `core/rules/development-discipline.md` ("Logs First, Always") and deployed in the FORGE-RULES block. Not restated here.

### 7. Documentation & Context Updates

Before committing, Claude follows a strict flow:
1. Confirm doc updates with the user
2. Update docs
3. Save context
4. Commit everything together

Code is never committed separately from its documentation. This applies to implementation plans, walkthroughs, architecture docs, and any files referencing the changed area.

---

## Task Management

1. **Plan First** — Use plan mode or todo lists for multi-step tasks
2. **State the Plan** — say in one line which arts will run, then start; ask only when the decision is the user's (irreversible, outward-facing, a real preference)
3. **Track Progress** — Mark items complete incrementally
4. **Explain Changes** — Provide a high-level summary at each step

---

## Context Persistence

Each project has **one `AGENTS.md`** in its root containing rules, current state, and key learnings. `/wrap` compacts it at 20k chars and hard-flags it above 25k; older history overflows to memory files (`memory/`).

The command **"save context"** triggers a full replacement of the Current Context section with a snapshot of the current state (branch, test count, completed phases, pending work).

No separate task/context/todo files are created in the repo — everything lives in `AGENTS.md` or memory files.

---

## Shell & Platform

- Always uses **bash** (Unix shell syntax), never Windows cmd/PowerShell — even on Windows
- Forward slashes in paths, `/dev/null` not `NUL`, `rm -rf` not `rmdir /s /q`
- For `.cmd`/`.bat` tools (e.g., `gcloud.cmd`), uses Node/Python subprocess with explicit argument arrays to avoid Windows shell quoting issues

---

## Shorthand Commands

The shorthand commands are skills, not rules-file text. Their behaviour is owned by the skill files; this table only names them.

| Command | Skill | Meaning |
|---------|-------|---------|
| **wawa** | `core/skills/wawa/SKILL.md` | "Where are we at?" — sourced status table (Active Work / Outstanding / Parked), with a warning when the rules file has no `## Current Context` |
| **wrap** | `core/skills/wrap/SKILL.md` | Pre-commit ritual: lint → stage → context → docs → compact → commit |
| **qt** | `core/skills/qt/SKILL.md` | Quick test — verify a fix works before the user tests manually |

---

## Testing Strategy

- **E2E debugging**: Fix each failing test individually (single test runs), then re-run the full suite only after all individual fixes pass
- **E2E long runs**: Run full E2E suites in foreground with `timeout: 300000` (5 min). Config has `maxFailures: 1` so it stops on first failure. If running in background for any reason, check output at the 3-minute mark proactively.
- **E2E pre-flight**: Kill zombie processes, verify DB connectivity, sync schema if changed

---

## Bash Rules and Permissions

### No Command Chaining

The rule text is owned by `core/rules/development-discipline.md` ("No Command Chaining in Bash — EVER") and deploys in the FORGE-RULES block. Claude Code specifics: the permission matcher keys on a command's first token, so one command per Bash call; for git in another directory use `git -C <path>`; instruct subagents explicitly.

### Permissions

The reference shape is `claude-helpers/refs/permissions-template.json`: `Read`, `Write`, `Edit`, `Glob`, `Grep`, `WebFetch(*)`, `WebSearch(*)`, `Bash(*)`, `Agent`, `TodoWrite`, `NotebookEdit`. `Bash(*)` and `WebFetch(*)` are blanket allows — the template carries no `deny` or `ask` list, so no shell command and no domain prompts, including `rm`, `git push`, `git reset`, `git clean` and `git restore`. Restraint on those commands comes from the HARD RULES (No Auto-Commit, Only /forge Writes to Forge), not from the permission system. A membrane that wants prompts on destructive commands adds its own `permissions.ask` entries.

---

## Art Auto-Invocation

When the user's intent clearly matches a single art's TRIGGER condition:
1. Inform the user which art you're invoking and why
2. Proceed with the invocation

When the user's intent matches multiple arts:
- For a feature, redesign, or multi-file change: do not ask. Follow the "Builds Go Through the Forge Arts" HARD RULE — build with `/smith`, gate with the evaluative arts that apply, and name them in one line at the start.
- For any other multi-art match: use `AskUserQuestion` to let the user choose which art to invoke

When the user's intent doesn't match any art:
- Proceed normally without invoking any art

Explicit invocation (e.g., "/poke") always overrides auto-routing.

If forge is disabled (via `/forge off`), ALL forge skills are suspended except `/forge` and `/purge`. No auto-invocation, no explicit skill invocation. Respond with "Forge is disabled. Run `/forge on` to re-enable."

### Skill Model Recommendations

Skills carry a neutral `<!-- model: opus/sonnet/haiku/inherit -->` hint, which `cast-deploy.sh` translates into a `model:` frontmatter field on the Claude copy at deploy time, as an exact model id (`claude-opus-5-5`, `claude-sonnet-5-5`, `claude-haiku-5-5`) — a floating alias that resolves outside the org's availableModels allowlist is silently ignored. Two mechanisms exist and they behave differently (measured 2026-08-16 and 2026-09-28 — see `core/skills/forge/protocol.md` → Model Tiers, rules 6 and 7):

- **`model:` frontmatter is an escalation floor, not a ceiling — and only on a user slash invocation.** It raises a session that sits *below* the skill's needed tier when the user types the slash command. A model-initiated Skill-tool invocation runs at the session model regardless of frontmatter. It does **not** pull a session down: a skill pinned one tier down, invoked inline on a higher-tier session, runs every turn — including the invocation turn — at the session model.
- **A spawn's model parameter binds in both directions, including downward.** Subagents spawned from a top-tier session run at whatever tier the spawn names, for the whole of their work. This is the only reliable lever for running a leg below the session.

Consequence: work that should run below the session tier must be **delegated to a subagent with an explicit model parameter** — an inline skill invocation is not a delegation and spends the session's tier. Prefer a cheap session default with deliberate escalation over a high default plus inline skills. On a cheap default session, users invoke opus arts themselves by slash command; a flow that needs an art at opus from inside another skill spawns a subagent with an explicit model parameter instead of calling the Skill tool.

---

## Presentation upkeep (forge-internal convention — not a deployed HARD RULE)

> When a skill or art is added to `core/skills/`, or changes its name, description, or core purpose, update `presentation/index.html` in the same commit. This governs the forge repo only, so it is not in `core/rules/` and does not deploy to membranes.

For a **new art**, ALL of the following slides must be updated:

| Slide | What to update |
|-------|---------------|
| Arts Overview (slide 9) | Add a persona card with art-name, art-title, and art-desc; keep the slide title's count equal to the Arts table in `AGENTS.md` |
| Evaluative Trifecta (or equivalent cadence slide) | Add supplementary art chip with cadence label |
| Arts deep-dive slide (Pry/Purge/Patch or equivalent) | Add a full card with description, routing behaviour, and kitchen analogy |
| Daily Workflow | Add or extend a scenario that shows when to invoke the new art |
| Quick Reference Cheatsheet | Add to the appropriate section (SPECIALIST, BUILD ARTS, etc.) |
| One-Time vs Iterative | Add to the correct frequency bucket |
| Full Project Lifecycle Map | Add an entry to the stage it belongs in |
| Command Frequency table | Add a row for its run cadence |
| Closing stats | Increment the arts count and total skills count |

For a **description change**: update the matching persona card's `art-desc` text.
For a **skill rename**: grep for all occurrences in the file and update every one.

The presentation is the canonical human-readable overview of what forge does. Letting it drift from the actual skill set makes it misleading. A new art that only appears in one slide is as misleading as no mention at all.

---

## Core Principles

| Principle | Description |
|-----------|-------------|
| **Simplicity First** | Every change should be as simple as possible, impacting minimal code |
| **No Laziness** | Find root causes. No temporary fixes. Senior developer standards. |
| **Minimal Impact** | Changes only touch what's necessary. Avoid introducing bugs. |
