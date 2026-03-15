---
name: wawa
description: "Where Are We At?" — produces a tabular summary of the current project work slate. Use when the user types "wawa" or asks about project status / outstanding work.
user-invocable: true
---

# /wawa — Where Are We At?

You are generating a concise status report for the user. No prose preamble — just the status line and table.

## Steps

1. **Re-read project state** (MANDATORY — never rely on conversation memory):
   - Read the project's `CLAUDE.md` (especially `## Current Context` section)
   - Glob for any active plan files: `.claude/plans/*.md`
   - Read any found plan files

2. **Check git state**:
   - Run `git status` (never use `-uall` flag)
   - Run `git log --oneline -10`
   - Run `git diff --stat` for uncommitted changes

3. **Cross-reference**: Compare completed items in CLAUDE.md against plan items. If CLAUDE.md says something is DONE, do NOT list it as pending.

4. **Output format**:

```
**Branch**: `<branch>` | **Last commit**: `<hash> <message>` | **Uncommitted**: <count> files
**Tests**: <unit count> unit, <e2e count> E2E | **Lint/Type errors**: <count or "clean">
```

| # | Category | Task | Priority | Status | Notes |
|---|----------|------|----------|--------|-------|
| 1 | Phase work | ... | P0/P1/P2 | pending/in-progress/blocked | ... |
| 2 | Deferred | ... | ... | ... | ... |
| 3 | Tech debt | ... | ... | ... | ... |

**Categories**:
- **Phase work** — active/next planned phases from the execution plan
- **Deferred** — items explicitly deferred in the Current Context section
- **Tech debt** — known divergences, migrations, or cleanup tasks

5. Keep it concise. One row per item. No narrative.
