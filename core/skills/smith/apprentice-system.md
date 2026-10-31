# Apprentice System — Parallel Mastery

> Referenced by [SKILL.md](SKILL.md) — loaded on demand during build planning.

A human smith works alone. This smith commands apprentices — subagents summoned to carry the implementation.

## When to Fan Out

Before each heat, smith scans the dependency graph for work whose inputs are satisfied. Independent work that is big enough to earn its own context (a full vertical slice, a multi-file module) gets its own apprentice. Small or tightly coupled work goes to a single apprentice in sequence. The graph decides, not idle capacity: an extra spawn costs real tokens and time.

## Fan-Out Patterns

| Pattern | When | Example |
|---------|------|---------|
| **Build fan-out** | Independent heats within a unit | Two unrelated API routes built simultaneously |
| **Evaluate fan-out** | Multiple arts on the same heat | /poke + /preen on a UI heat |
| **Build + evaluate overlap** | Heat N+1 independent of Heat N's evaluation | Apprentice evaluates Heat N while smith starts Heat N+1 |
| **Fix fan-out** | Independent findings across different files | Auth fix + logging fix in parallel |
| **Anticipatory work** | Future heat's inputs already satisfied | Dev tooling (Heat 3) starts while auth (Heat 2) is still building |

**Tiering**: build, fix and anticipatory apprentices spawn at the tier the heat's grade sets (SKILL.md → Grade Each Heat: T1 low-effort sonnet, haiku for pure boilerplate; T2 sonnet; T3 opus). Evaluate and build + evaluate overlap apprentices run evaluative arts at opus tier — they are the review gate for sonnet-built code.

## Apprentice Rules

1. **Scope**: Each apprentice gets a focused, self-contained task with all context pre-loaded (blueprint sections, evidence, stack guide). They never coordinate with each other — only smith sees the full picture and merges results.
2. **Concurrency cap**: at most 3-4 apprentices at once. Where the installed Claude Code supports it, bind the cap with `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` rather than relying on this sentence.
3. **Completion**: wait for each apprentice's completion notification; do not poll. An apprentice that returns incomplete or off-scope is re-briefed once; after that, smith commissions a fresh apprentice.
4. **Sync points**: All apprentices complete before unit boundaries, phase gates, and any heat whose output is a dependency for another. No sonnet apprentice output merges past a unit boundary before an opus-tier art pass covers it.
5. **Context loading**: Apprentices receive the relevant blueprint sections, the project's `AGENTS.md` (legacy: `CLAUDE.md` if not yet migrated), stack guide, and any evidence they need. They do not read the smith ledger or smith learnings — that's the master's domain.
6. **No overlapping dependencies**: Do not fan out heats that modify the same files or modules. Build fan-out is only for truly independent code paths.
7. **Merge conflicts**: If two apprentices modify the same file, smith resolves the merge and records it in Layer 3 (apprentice proficiency) as a learning.
8. **No command chaining**: apprentices never use `&&`, `;`, or `||` to chain bash commands. Copy this rule verbatim into every apprentice prompt.
