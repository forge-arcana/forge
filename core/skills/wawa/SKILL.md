---
name: wawa
description: "Where Are We At?" — concise status snapshot. Use when user types "wawa" or asks about project status.
---

# /wawa — Where Are We At?

Concise status snapshot. No prose preamble — just the header and table.

## Steps

1. **Gather all state in parallel** (MANDATORY — never rely on conversation memory):

   **Batch A** — launch ALL of these in parallel (independent reads):
   - Read the project's `CLAUDE.md`/`AGENTS.md` (especially `## Current Context` section)
   - Glob for active plan files in your harness's plan directory (e.g. `.claude/plans/*.md` for Claude Code; check the equivalent path for other harnesses)
   - Glob for project memory files: `memory/project_*.md`
   - Run `<forge>/core/scripts/wawa-status.sh` (collapses `git status` + `git log` + `git diff --stat` into one call)

   **Batch B** — after globs return, read any found plan files and project memory files in parallel

3. **STRICT sourcing — ZERO inference**:
   - **Phase work**: ONLY from an active plan file in the harness's plan directory. No plan file = no phase rows.
   - **Other items**: ONLY from `CLAUDE.md`/`AGENTS.md` `## Current Context`. Copy verbatim — do not add items.
   - Do NOT infer tasks from conversation memory, audit findings, or code exploration.

4. **Filter ruthlessly** — from the sourced items, only keep rows that meet ONE of:
   - **In-progress** — uncommitted changes, active plan work, current conversation work
   - **Blocked** — has a clear blocker that could be resolved soon
   - **Next up** — the single next planned task (not the entire backlog)

   **OMIT only these** — they are history, not status:
   - Completed phases (anything marked DONE)
   - Historical audit summaries with all items resolved

5. **Output format** — a one-line header (Branch / Last commit / Dirty count) followed by a markdown table grouped by section header rows (`Active Work`, `Outstanding`).
   - Columns: `# | Task | Status | Notes`
   - Active items: `in-progress` / `blocked` / `next`. Cap at 5. If none, single row `Slate clean`.
   - Outstanding items: `outstanding`. Sources: rules-file `### Deferred`, incomplete plan items, `project_*.md` memory files with unresolved work. Omit items marked "Do NOT surface in status updates" or fully resolved. If none, omit the Outstanding section entirely.

6. No narrative. No invented rows.
