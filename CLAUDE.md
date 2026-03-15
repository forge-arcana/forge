# Forge — Project Rules

## Purpose
Forge is the shared tooling, conventions, and reference documentation repo used across all projects. Skills, stack guides, and workflow rules live here as the source of truth.

## Key Files & Directories
- `skills/` — Git-tracked source of truth for all 12 global skills (self-contained packages)
- `learnings/` — Absorbed team wisdom (populated by `/reforge`)
- `memory/` — Team identity & shared conventions (populated by `/reforge`)
- `.claude/skills/forge/` — Thin bootstrap so `/forge` is discoverable on fresh clone

## Global Skills (available everywhere)
| Skill | Purpose |
|-------|---------|
| `/pitch` | Elevator pitch generator (6-round interview) |
| `/bluep` | Product blueprint generator (7-round interview) |
| `/arch` | Architecture polisher (self-improving) |
| `/forge` | Workstation initializer (divergence analysis + apply) |
| `/dive` | Deep QA testing with 19 adversarial personas |
| `/audit` | Go-live readiness assessment (self-improving) |
| `/wawa` | "Where Are We At?" — outstanding work summary table |
| `/wrap` | Pre-commit ritual (learnings → context → docs → lint → compact → commit) |
| `/quick` | Tech debt & logging code review (self-improving) |
| `/qt` | Quick test — verify fixes before user tests manually |
| `/srs` | Setup restart script for local dev stack |
| `/reforge` | Feed knowledge back to forge — config sync + absorb learnings & memories (runnable from any project) |

## Three Pillars (all bidirectional via forge)
| Pillar | DOWN (forge → user) | UP (user → forge) |
|--------|--------------------|--------------------|
| `skills/` | `/forge` deploys to `~/.claude/skills/` | Edit in forge, commit, push |
| `learnings/` | `/forge` syncs to `~/.claude/learnings/` | `/wrap` promotes → `/reforge` absorbs |
| `memory/` | `/forge` syncs to `~/.claude/memory/` | `/wrap` promotes → `/reforge` absorbs |

## Self-Improving Skills Loop
`/arch`, `/audit`, `/quick` write learnings to project's `memory/*-learnings.md` → `/wrap` promotes to `~/.claude/` → `/reforge` absorbs into `forge/learnings/` → next skill run reads global learnings first.

## HARD RULE — Only /reforge Writes to Forge
> **No project, no skill, no manual edit touches forge repo files directly.**
> `/reforge` is the gatekeeper for learnings, memory, and config sync.
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
- **Last commit**: `4ad7600` — Fix /wrap Step 9
- **Completed**: Three-pillar architecture, manifest-based drift detection, 12 global skills, `/forge` pillar sync + `/reforge` absorption operational, Communication Style (timestamps) removed from all docs — inaccurate times
- **Pending**: P2 items (embed logging/restart.sh guidance in skills, cache web research). Not blocking.
