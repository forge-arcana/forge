# Forge — Project Rules

## Purpose
Forge is the shared tooling, conventions, and reference documentation repo used across all projects. Skills, stack guides, and workflow rules live here as the source of truth.

## Key Files & Directories
- `skills/` — Git-tracked source of truth for all global skills (self-contained packages)
- `learnings/` — Absorbed team wisdom (populated by `/fold`)
- `memory/` — Team identity & shared conventions (populated by `/fold`)
- `.claude/skills/cast/` — Thin bootstrap so `/cast` is discoverable on fresh clone

## Core Loop (the forge cycle)
| Command | Action | Analogy |
|---------|--------|---------|
| `/mark` | Inspect membrane status (read-only) | Hallmark — inspect and stamp quality |
| `/cast` | Deploy forge → membrane | Pour molten metal into the mold |
| `/fold` | Absorb membrane → forge | Layer experience into the steel |

## Global Skills (available everywhere)
| Skill | Purpose |
|-------|---------|
| `/cast` | Deploy forge conventions into a project (membrane sync + divergence analysis) |
| `/fold` | Absorb knowledge back into forge — config sync + learnings & memories (runnable from any project) |
| `/mark` | Inspect membrane status — skill drift, learnings, memory report |
| `/pitch` | Elevator pitch generator (6-round interview) |
| `/bluep` | Product blueprint generator (7-round interview) |
| `/arch` | Architecture polisher (self-improving) |
| `/dive` | Deep QA testing with 19 adversarial personas |
| `/audit` | Go-live readiness assessment (self-improving) |
| `/wawa` | "Where Are We At?" — outstanding work summary table |
| `/wrap` | Pre-commit ritual (lint → stage → context → docs → compact → commit) |
| `/quick` | Tech debt & logging code review (self-improving) |
| `/qt` | Quick test — verify fixes before user tests manually |
| `/srs` | Setup restart script for local dev stack |

## Three Pillars (all bidirectional via forge)
| Pillar | DOWN (forge → user) | UP (user → forge) |
|--------|--------------------|--------------------|
| `skills/` | `/cast` deploys to `~/.claude/skills/` | Edit in forge, commit, push |
| `learnings/` | `/cast` syncs to `~/.claude/learnings/` | Auto-accumulates → `/fold` absorbs |
| `memory/` | `/cast` syncs to `~/.claude/memory/` | Auto-accumulates → `/fold` absorbs |

## Self-Improving Skills Loop
`/arch`, `/audit`, `/quick` write learnings to project's `memory/*-learnings.md` → auto-memory accumulates to `~/.claude/` → `/fold` absorbs into `forge/learnings/` → next skill run reads global learnings first.

## HARD RULE — Only /fold Writes to Forge
> **No project, no skill, no manual edit touches forge repo files directly.**
> `/fold` is the gatekeeper for learnings, memory, and config sync.
> Direct edits to forge are only for skill development (editing SKILL.md files in `skills/`).

## HARD RULE — No Auto-Commit
> **NEVER commit automatically after completing any sprint, phase, or piece of work.** Always ask the user: "Ready to wrap up? Run `/wrap` to commit with full context."

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
- **Last commit**: `46730cc` — Fix pillar hash mismatches
- **Completed**: Three-pillar architecture, manifest-based drift detection, global skills (+ monci/ponci/vsix), `/cast` + `/fold` + `/mark` core loop, deterministic path-relative hashing for pillar sync
- **Pending**: Personas (evolving role-specific agents with metallurgy names — separate plan). P2 items (embed logging/restart.sh guidance in skills, cache web research). Not blocking.
