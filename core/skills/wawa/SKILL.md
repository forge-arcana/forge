---
name: wawa
description: 'Where Are We At? — concise status snapshot. Use when user types "wawa" or asks about project status.'
---
<!-- model: haiku | collation via wawa-status.sh; no fan-out -->

# /wawa — Where Are We At?

Concise status snapshot. No prose preamble — just the header and table.

## Steps

1. **Gather all state in parallel** (MANDATORY — never rely on conversation memory):

   **Batch A** — launch ALL of these in parallel (independent reads):
   - Read the project's `AGENTS.md` (legacy: `CLAUDE.md` if not yet migrated), especially the `## Current Context` section
   - Glob for active plan files in your harness's plan directory (e.g. `.claude/plans/*.md` for Claude Code; check the equivalent path for other harnesses)
   - Glob for project memory files: `memory/project_*.md`
   - Run `<forge>/core/scripts/wawa-status.sh` (collapses `git status` + `git log` + `git diff --stat` into one call)

   **Batch B** — after globs return, read any found plan files and project memory files in parallel

2. **Source check: a missing source is a finding, never a clean slate.** Before building any row, confirm the rules file contains a `## Current Context` heading.
   - **Absent**: do NOT print `Slate clean`. Print the header line, then `⚠ No "## Current Context" section in <rules file>: status cannot be sourced.` On the next line, list the status-like headings that do exist (for example `## Progress`, `## Status`, `## Roadmap`, `### Pending`) and any launch, roadmap or backlog document the rules file points to, as `Open work may be under: ...`. Then show only git-derived rows (uncommitted or untracked files) and end with `Run /wrap to create the section.` Do not read those other headings into rows: say where the work is, do not guess what it is.
   - **Present but holds only pointers** to other files, with no items listed: print the table from what is there and add one line, `⚠ "## Current Context" points elsewhere and lists no open work.`
   - **Present and over ~20k characters in the rules file** (a cheap `wc -c`): add one line, `⚠ Rules file is over 20k characters; /wrap compaction is due.`

3. **STRICT sourcing — ZERO inference**:
   - **Phase work**: ONLY from an active plan file in the harness's plan directory. No plan file = no phase rows.
   - **Other items**: ONLY from the project rules file's `## Current Context`. Copy verbatim — do not add items.
   - Do NOT infer tasks from conversation memory, audit findings, or code exploration.

4. **Filter ruthlessly** — from the sourced items, only keep rows that meet ONE of:
   - **In-progress** — uncommitted changes, active plan work, current conversation work
   - **Blocked** — has a clear blocker that could be resolved soon
   - **Next up** — the single next planned task (not the entire backlog)

   **OMIT only these** — they are history, not status:
   - Completed phases (anything marked DONE)
   - Historical audit summaries with all items resolved

5. **Output format** — a one-line header (Branch / Last commit / Dirty count) followed by a markdown table grouped by section header rows (`Active Work`, `Outstanding`, `Parked`).
   - Columns: `# | Task | Status | Notes`
   - Active items: `in-progress` / `blocked` / `next`. Cap at 5. If none, single row `Slate clean`, and only when the source check in step 2 passed.
   - Outstanding items: `outstanding`. Sources: rules-file `### Deferred`, incomplete plan items, `project_*.md` memory files with unresolved work. Omit items marked "Do NOT surface in status updates" or fully resolved. If none, omit the Outstanding section entirely.
   - Parked items: `parked`. Source: items the rules file explicitly marks parked/deferred-indefinitely (e.g. a "Parked:" line or list). Copy verbatim as rows — these are intentional non-blockers, not backlog. If none, omit the Parked section entirely.

6. No narrative. No invented rows. The step 2 warning lines are not narrative: always print them when they apply.
