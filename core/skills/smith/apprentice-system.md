# Apprentice System — Parallel Mastery

> Referenced by [SKILL.md](SKILL.md) — loaded on demand during build planning.

A human smith works alone. This smith commands apprentices — subagents summoned to multiply throughput.

## The Waste Principle

> **Sequential execution of independent work is waste.**

Before each heat, smith scans the dependency graph for work whose inputs are already satisfied. Every such opportunity spawns an apprentice. Idle capacity is a failure of the master, not a limitation of the forge.

## Fan-Out Patterns

| Pattern | When | Example |
|---------|------|---------|
| **Build fan-out** | Independent heats within a unit | Two unrelated API routes built simultaneously |
| **Evaluate fan-out** | Multiple arts on the same heat | /poke + /preen on a UI heat |
| **Build + evaluate overlap** | Heat N+1 independent of Heat N's evaluation | Apprentice evaluates Heat N while smith starts Heat N+1 |
| **Fix fan-out** | Independent findings across different files | Auth fix + logging fix in parallel |
| **Anticipatory work** | Future heat's inputs already satisfied | Dev tooling (Heat 3) starts while auth (Heat 2) is still building |

**Tiering**: build, fix, and anticipatory apprentices spawn at sonnet tier — they implement against a complete spec the master produced. Evaluate and build + evaluate overlap apprentices run evaluative arts and spawn at opus tier — they ARE the review gate for sonnet-built code.

## Apprentice Rules

1. **Scope**: Each apprentice gets a focused, self-contained task with all context pre-loaded (blueprint sections, evidence, stack guide). They never coordinate with each other — only smith sees the full picture and merges results.
2. **Concurrency cap**: Maximum 3-4 apprentices running simultaneously. More causes diminishing returns — merge resolution overhead grows faster than throughput gains.
3. **Timeouts**: If an apprentice hasn't completed within the expected scope (no progress signal for 3+ minutes), smith checks status. Stuck apprentices are terminated and their work restarted or absorbed by smith directly.
4. **Sync points**: All apprentices must complete before: unit boundaries, phase gates, and any heat whose output is a dependency for another. No sonnet apprentice output merges past a unit boundary before an opus-tier art pass covers it.
5. **Context loading**: Apprentices receive the relevant blueprint sections, project CLAUDE.md, stack guide, and any evidence they need. They do NOT read the smith ledger or smith learnings — that's the master's domain.
6. **No overlapping dependencies**: Never fan out heats that modify the same files or modules. Build fan-out is only for truly independent code paths.
7. **Merge conflicts**: If two apprentices modify the same file, smith resolves the merge. This is tracked in Layer 3 (apprentice proficiency) as a learning.
8. **HARD RULE**: Apprentices NEVER use `&&`, `;`, or `||` to chain bash commands. Copy this rule verbatim into every apprentice prompt.
