# Forge — Project Rules

## Purpose
Forge is the shared tooling, conventions, and reference documentation repo used across all projects. Skills, stack guides, and workflow rules live here as the source of truth.

## Key Files
- `code/claude-code-rules.md` — Canonical workflow rules reference
- `code/stack-guide.md` — Technology decisions and logging conventions
- `code/qa-review-prompt.md` — QA review framework (19 adversarial personas)
- `learnings/` — Global learning store (populated by `/reforge`)

## Global Skills (available everywhere)
| Skill | Purpose |
|-------|---------|
| `/pitch` | Elevator pitch generator (5-round interview) |
| `/bluep` | Product blueprint generator (7-round interview) |
| `/arch` | Architecture polisher (self-improving) |
| `/forge` | Workstation initializer (divergence analysis + apply) |
| `/dive` | Deep QA testing with 19 adversarial personas |
| `/audit` | Go-live readiness assessment (self-improving) |
| `/wow` | Outstanding work summary table |
| `/wrap` | Pre-commit ritual (learnings → context → docs → lint → compact → commit) |
| `/quick` | Tech debt & logging code review (self-improving) |
| `/qt` | Quick test — verify fixes before user tests manually |
| `/srs` | Setup restart script for local dev stack |

## Project-Local Skills (forge repo only)
| Skill | Purpose |
|-------|---------|
| `/reforge` | Config sync + absorb learnings from all projects into `forge/learnings/` |

## Self-Improving Skills Loop
`/arch`, `/audit`, `/quick` write learnings to project's `memory/*-learnings.md` → run `/reforge` from forge repo to absorb into `learnings/` → next skill run reads global learnings first.

## HARD RULE — No Auto-Commit
> **NEVER commit automatically after completing any sprint, phase, or piece of work.** Always ask the user: "Ready to wrap up? Run `/wrap` to commit with full context."

## HARD RULE — No Command Chaining in Bash — EVER
> **NEVER use `&&`, `;`, or `||` to chain commands in a single Bash tool call.**
> This applies to the main agent AND all subagents. Zero exceptions. Zero tolerance.
