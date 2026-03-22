# Forge — Project Rules

## Purpose
Forge is the shared tooling, conventions, and reference documentation repo used across all projects. Skills, stack guides, and workflow rules live here as a shared reference — but forge is NOT the source of truth. The user is the source of truth. Forge is a proposal, not an authority.

## Key Files & Directories
- `skills/` — Git-tracked shared reference for all global skills (self-contained packages)
- `learnings/` — Absorbed team wisdom (populated by `/fold`)
- `memory/` — Team identity & shared conventions (populated by `/fold`)
- `.claude/skills/cast/` — Thin bootstrap so `/cast` is discoverable on fresh clone

## Core Loop (the forge cycle)
| Command | Action | Analogy |
|---------|--------|---------|
| `/mark` | Inspect membrane status (read-only) | Hallmark — inspect and stamp quality |
| `/cast` | Deploy forge → membrane | Pour molten metal into the mold |
| `/fold` | Absorb membrane → forge | Layer experience into the steel |

## Arts (Eight P's)
Arts are skills that adopt a specialist persona and have a self-improving learning loop. Protocol: `skills/forge/protocol.md`.

| Art | Persona | Mode |
|-----|---------|------|
| `/prime` | The originator (ideation → blueprint) | Generative |
| `/probe` | Senior solutions architect | Evaluative |
| `/poke` | Staff engineer (code quality + tech debt) | Evaluative — light |
| `/preen` | UI/UX evaluator (Don Norman's design principles) | Evaluative — design |
| `/press` | Staff engineer (go-live readiness) | Evaluative — medium |
| `/pound` | 21 adversarial QA personas | Evaluative — heavy |
| `/pry` | The Lever (relentless solution-finder) | Investigative |
| `/purge` | The Purist (forge master) | Cleansing |

**Evaluative trifecta** — poke often, press before milestones, pound before ship.
**When blocked** — `/pry` to crack the wall.
**For UI/UX** — `/preen` to evaluate interfaces through Don Norman's lens.

## Task Skills
| Skill | Purpose |
|-------|---------|
| `/cast` | Deploy forge conventions into a project (membrane sync + divergence analysis) |
| `/fold` | Absorb knowledge back into forge — config sync + learnings & memories (runnable from any project) |
| `/mark` | Inspect membrane status — skill drift, learnings, memory report |
| `/wawa` | "Where Are We At?" — outstanding work summary table |
| `/wrap` | Pre-commit ritual (lint → stage → context → docs → compact → commit) |
| `/qt` | Quick test — verify fixes before user tests manually |
| `/srs` | Setup run scripts (restart + kill-zombies) for local dev |
| `/monci` | Monitor CI — watch GitHub Actions runs on current branch |
| `/ponci` | Push to remote and monitor CI |
| `/vsix` | Publish a VS Code extension |
| `/dig` | Think deeper — reframe agent as staff engineer for current discussion |
| `/temper` | Hardened evaluation — runs poke + press N times, consolidates with confidence scoring |
| `/eli5` | Explain Like I'm 5 — distill current topic into simplest possible terms |

## Three Pillars (all bidirectional via forge)
| Pillar | DOWN (forge → user) | UP (user → forge) |
|--------|--------------------|--------------------|
| `skills/` | `/cast` deploys to `~/.claude/skills/` | Edit in forge, commit, push |
| `learnings/` | `/cast` syncs to `~/.claude/learnings/` | Auto-accumulates → `/fold` absorbs |
| `memory/` | `/cast` syncs to `~/.claude/memory/` | Auto-accumulates → `/fold` absorbs |

## Self-Improving Loop
Arts (`/prime`, `/probe`, `/poke`, `/preen`, `/press`, `/pound`, `/pry`, `/purge`) write learnings to project's `memory/*-learnings.md` with `Forge-worthy: yes/no` flags → `/fold` scans project memories for `Forge-worthy: yes` entries, genericizes, and promotes to `~/.claude/learnings/general.md` → `/fold` absorbs into `forge/learnings/` → next art run reads global learnings in pre-flight.

## HARD RULE — Only /fold Writes to Forge
> **No project, no skill, no manual edit touches forge repo files directly.**
> `/fold` is the gatekeeper for learnings, memory, and config sync.
> Direct edits to forge are only for skill development (editing SKILL.md files in `skills/`).
>
> **When a user says "add this to forge" from a project context**, they mean:
> 1. Write the learning to `~/.claude/learnings/general.md` (the membrane)
> 2. Tell the user to run `/fold` from forge to absorb it
>
> **NEVER** open the forge repo and edit `learnings/`, `memory/`, or `skills/forge/` files from a project context.
> The membrane is the inbox. `/fold` is the quality gate. No shortcuts.

## HARD RULE — The User Is the Source of Truth, Not Forge
> **Forge is a shared reference, not an authority. Neither forge nor the membrane is automatically correct.**
> Both `/cast` (forge → user) and `/fold` (user → forge) are PROPOSALS that require user confirmation.
> Cast does NOT blindly deploy learnings and memory — it presents them for triage just like fold does.
> A learning in forge can be stale. A memory in forge can be wrong. A convention in forge can be outdated.
> The only source of truth is the user's judgment at the PLAN table.
>
> **Corollary**: Both directions need the same quality gate. If fold triages before absorbing,
> cast must triage before deploying. No direction gets to skip the user's review.

## HARD RULE — All Transfers Are Guarded by User Wisdom
> **ALL pillars (skills, config, learnings, memory) require user review in BOTH directions.**
> Cast and fold both present a PLAN table. Both require user approval. Both execute only approved items.
> Nothing transfers without the user's judgment at the PLAN table.
> A skill can have a bad update. A config can have stale rules. A learning can be wrong.
> The user reviews every item — no pillar gets a mechanical bypass.

## HARD RULE — No Project Names in Forge
> **Forge is a shared repo. NEVER include project-specific details in learnings, memory, or commit messages.**
> Strip all project names, specific file paths, domains, and business logic before writing.
> Learnings must read as universal principles. Commit messages must describe *what* was absorbed, not *where* it came from.

## HARD RULE — No Auto-Commit
> **NEVER commit automatically after completing any sprint, phase, or piece of work.**
> Use `AskUserQuestion` to prompt: "Ready to wrap up?" with options "Yes, run /wrap" / "Not yet".

## HARD RULE — No Command Chaining in Bash — EVER
> **NEVER use `&&`, `;`, or `||` to chain commands in a single Bash tool call.**
> This applies to the main agent AND all subagents. Zero exceptions. Zero tolerance.

## Shorthand Commands
- **wawa** — Runs the `/wawa` skill
- **wrap** — Runs the `/wrap` skill

## Documentation
No docs/ directory — forge is a tooling repo. Skill documentation lives inside each skill's directory (`skills/<name>/SKILL.md`).

## Current Context
- **Branch**: main
- **Completed**: Three-pillar architecture, git-based drift detection, 21 global skills (8 arts + 13 task skills), `/cast` + `/fold` + `/mark` core loop, forge protocol formalization, Forge Arcana identity + ethos, project name sanitization, shared preflight extraction, hash-free trackers, performance scripts, evaluative trifecta (poke → press → pound), cast/fold restructured as thin directional wrappers around shared classification engine
- **Arts**: prime, probe, poke, preen, press, pound, pry, purge — shared protocol in `skills/forge/protocol.md`
- **Shared architecture**: `forge-status.sh` is the shared classification engine. Mark presents its output (read-only). Cast acts on the cast column (forge → user). Fold acts on the fold column (user → forge). One engine, three interpretations.
- **Shared references**: `skills/forge/protocol.md` (art pre/post-flight), `skills/forge/preflight.md` (universal classification system for /mark, /cast, /fold)
- **Scripts**: `scripts/forge-status.sh` (shared classification engine — all 3 cycle skills use this), `scripts/cast-deploy.sh` (skill deployment for /cast), `scripts/forge-scan.sh` (project evidence for /poke, /press), `scripts/forge-purge-scan.sh` (forge hygiene for /purge), `scripts/fold-evidence.sh` (learning/memory collection for /fold), `scripts/wawa-status.sh` (git state for /wawa), `scripts/gh-poll.sh` (CI polling for /monci, /ponci)
- **Trackers**: `learnings/.reforge-tracker.json` (title-based: processedEntries + promotedEntries), `memory/.memory-tracker.json` (skippedFiles for PERSONAL memories, diff for sync)
- **Baseline**: `~/.claude/.last-cast.json` stores last-cast commit SHA for three-way drift detection (written by /cast, consumed by forge-status.sh)
- **Recent**: Fixed forge-path resolution bug in all 4 scripts — `tr -d '[:space:]'` destroyed paths with spaces (e.g., `VS Projects`), replaced with `sed 's/[[:space:]]*$//'` to trim only trailing whitespace.
- **Pending**: 11 orphan entries in reforge tracker (titles in tracker but not in any forge learning file) — cosmetic, `/purge` can clean.
