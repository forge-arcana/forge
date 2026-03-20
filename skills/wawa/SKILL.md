---
name: wawa
description: "Where Are We At?" — concise status snapshot. Use when user types "wawa" or asks about project status.
user-invocable: true
---

# /wawa — Where Are We At?

Concise status snapshot. No prose preamble — just the header and table.

## Steps

1. **Re-read project state** (MANDATORY — never rely on conversation memory):
   - Read the project's `CLAUDE.md` (especially `## Current Context` section)
   - Glob for any active plan files: `.claude/plans/*.md`
   - Read any found plan files
   - Glob for project memory files: `memory/project_*.md` (in the project's memory directory)
   - Read any found project memory files — these contain planned work, decisions, and outstanding items that may not be in CLAUDE.md yet

2. **Check git state**:
   - Run `git status` (never use `-uall` flag)
   - Run `git log --oneline -5`
   - Run `git diff --stat` for uncommitted changes

3. **STRICT sourcing — ZERO inference**:
   - **Phase work**: ONLY from an active plan file in `.claude/plans/`. No plan file = no phase rows.
   - **Other items**: ONLY from CLAUDE.md `## Current Context`. Copy verbatim — do not add items.
   - Do NOT infer tasks from conversation memory, audit findings, or code exploration.

4. **Filter ruthlessly** — from the sourced items, only keep rows that meet ONE of:
   - **In-progress** — uncommitted changes, active plan work, current conversation work
   - **Blocked** — has a clear blocker that could be resolved soon
   - **Next up** — the single next planned task (not the entire backlog)

   **OMIT only these** — they are history, not status:
   - Completed phases (anything marked DONE)
   - Historical audit summaries with all items resolved

5. **Output format** — one table with inline section headers:

```
**Branch**: `<branch>` | **Last commit**: `<hash> <msg>` | **Dirty**: <count> files
```

| # | Task | Status | Notes |
|---|------|--------|-------|
| | **Active Work** | | |
| 1 | ... | in-progress | ... |
| 2 | ... | blocked | ... |
| | **Outstanding** | | |
| 3 | ... | outstanding | ... |
| 4 | ... | outstanding | ... |

**Rules**:
- **Active Work** header row, then active items (max 5). If none, single row: `Slate clean` in Task column.
- **Outstanding** header row, then deferred/plan items + project memory items. Sources: CLAUDE.md `### Deferred`, incomplete plan items, and `project_*.md` memory files with unresolved work. Omit items that say "Do NOT surface in status updates" or are marked as fully resolved. If none, omit the Outstanding section entirely.
- Active statuses: `in-progress` / `blocked` / `next`
- Outstanding status: `outstanding`

6. No narrative. No invented rows.
