# Forge — Project Rules

## Purpose
Forge is the shared tooling, conventions, and reference documentation repo used across all projects. Skills, stack guides, and workflow rules live here as the source of truth.

## Key Files & Directories
- `skills/` — Git-tracked source of truth for all 11 global skills (self-contained packages)
- `learnings/` — Absorbed team wisdom (populated by `/reforge`)
- `memory/` — Team identity & shared conventions (populated by `/reforge`)
- `install.sh` — Bootstrap script for new machines (deploys skills + learnings + memory + manifest)

## Global Skills (available everywhere)
| Skill | Purpose |
|-------|---------|
| `/pitch` | Elevator pitch generator (5-round interview) |
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

## Project-Local Skills (forge repo only)
| Skill | Purpose |
|-------|---------|
| `/reforge` | Config sync + absorb learnings AND memories from all projects into forge |

## Three Pillars (all bidirectional via forge)
| Pillar | DOWN (forge → user) | UP (user → forge) |
|--------|--------------------|--------------------|
| `skills/` | `/forge` deploys to `~/.claude/skills/` | Edit in forge, commit, push |
| `learnings/` | `/forge` syncs to `~/.claude/learnings/` | `/wrap` promotes → `/reforge` absorbs |
| `memory/` | `/forge` syncs to `~/.claude/memory/` | `/wrap` promotes → `/reforge` absorbs |

## Self-Improving Skills Loop
`/arch`, `/audit`, `/quick` write learnings to project's `memory/*-learnings.md` → `/wrap` promotes to `~/.claude/` → `/reforge` absorbs into `forge/learnings/` → next skill run reads global learnings first.

## HARD RULE — No Auto-Commit
> **NEVER commit automatically after completing any sprint, phase, or piece of work.** Always ask the user: "Ready to wrap up? Run `/wrap` to commit with full context."

## HARD RULE — No Command Chaining in Bash — EVER
> **NEVER use `&&`, `;`, or `||` to chain commands in a single Bash tool call.**
> This applies to the main agent AND all subagents. Zero exceptions. Zero tolerance.

## Current Context
- **Branch**: main
- **Last commit**: `0b826fe` — Simplify forge-path resolution across skills
- **Completed**: Three-pillar architecture, `install.sh` bootstrap, manifest-based skill drift, self-contained skill packages, `<forge>` path notation, unified `/reforge` flow with auto-triggered review & staging archival, frontmatter cleanup
- **Pending**: P2 items (cache web research). Not blocking.
