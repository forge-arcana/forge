---
name: wrap
description: Pre-commit ritual. Updates learnings, saves context, updates docs, lints, compacts, stages, commits. Use when the user types "wrap" or wants to commit with full context.
user-invocable: true
---

# /wrap — Pre-Commit Ritual

Execute the following steps in order. Do NOT skip steps. Do NOT commit without completing all prior steps.

---

## Step 1: Update Project Learnings & Memories (Stage 1 — Project Level)

### 1a: Project Learnings (in repo)
- If anything new was learned this session, write to `memory/learnings.md`
- If the file doesn't exist, create it
- Append new learnings with date prefix
- **Dedup**: Before appending, read the existing file and skip any insight that already exists (exact or semantic duplicate)

### 1b: Project Claude Memory (user's machine)
- For learnings relevant to this project or similar projects, write to `~/.claude/projects/<project-path>/memory/` as memory files
- **Format**: Standard memory frontmatter:
  ```markdown
  ---
  name: <short title>
  description: <one-line description>
  type: feedback
  ---
  <!-- source: <project-name>, <date> -->
  <learning>
  ```
- **Update**: Add pointer to the project's `MEMORY.md` index
- **Dedup**: Read existing files in `~/.claude/projects/<project-path>/memory/` — skip if the same insight already exists

### 1c: Promote Generics to Global (Stage 2 — Global Level)
Review everything written in Steps 1a and 1b. For each item, decide if it's generic enough to promote:

#### Global Learnings (`~/.claude/learnings/`)
For truly universal insights applicable to ANY project:
- **Strip project specifics first**: Remove project names, specific file paths, business logic, team names, domains. Rewrite as a universal principle.
- **Write to**: `~/.claude/learnings/general.md` (append with date prefix)
- **Format**:
  ```markdown
  ## <Short Title> (<YYYY-MM-DD>)
  <!-- source: <project-name>, <date> -->
  <genericized learning>
  ```
- **Dedup**: Read ALL entries in `~/.claude/learnings/general.md` — skip if already exists

#### Global Memory (`~/.claude/memory/`)
For universal memories (feedback, patterns) useful across all projects:
- **Strip project specifics first**
- **Write to**: `~/.claude/memory/` as a memory file with standard frontmatter
- **Dedup**: Read existing files in `~/.claude/memory/` — skip if already exists

#### Classification guide

| Level | What goes here | Examples |
|-------|---------------|----------|
| **Project learnings only** | Project-specific decisions, business logic, state | "We chose Xendit for payments because of PH support" |
| **Project Claude memory** | Stack-specific patterns for this tech combo | "Hono + Drizzle: use middleware chaining for auth" |
| **Global learnings** | Universal principles, cross-stack patterns | "Always verify HMR timestamp after config changes" |
| **Global memory** | Universal feedback/preferences | "Log human-initiated actions with full context, skip pulsing events" |

#### When to run Stage 2
Stage 2 adds overhead (reading global files, deduping). Only run it when:
- New learnings were written in Step 1a (if nothing new was learned this session, skip entirely)
- Any learning has `Forge-worthy: yes` flag (auto-promote these — no judgment needed)
- For unflagged learnings, only promote if clearly generic (quick judgment — don't over-analyze)
- If in doubt, skip promotion — `/reforge` can always pull from project-level later if needed

If nothing qualifies for promotion, skip Stage 2.

**IMPORTANT**: Promotion is a COPY, not a move. Project-level entries are never deleted when promoted to global. Nothing is ever deleted during `/wrap`.

**NOTE**: `/wrap` never touches the forge repo. The `/reforge` skill (run from forge) consumes from `~/.claude/learnings/` and `~/.claude/memory/` to absorb into `forge/learnings/` and `forge/memory/`.

---

## Step 2: Save Context
- Update the `## Current Context` section in the project's `CLAUDE.md`
- **Replace** it with current state: branch, test count, completed phases, pending work
- Stale history belongs in git log or memory files

## Step 3: Update Docs

Locate the docs directory using this resolution order:

1. **In-repo**: Check for `docs/` directory in the project root
2. **External repo**: If no `docs/` exists, search the project's `CLAUDE.md` for a `## Documentation` section containing a local filesystem path

**Convention for external docs**: In CLAUDE.md, declare the docs location like this:
```markdown
## Documentation
**Docs path:** /absolute/path/to/docs-repo
```
The skill also recognizes paths in parentheses — e.g., `(/path/to/docs-repo)` — for backwards compatibility.

**Once a docs directory is resolved**:
- Scan it for files (`.md`, `.mdx`) referencing the areas changed this session
- Update any affected documentation to reflect the changes
- If the docs are in a separate repo, stage and commit those changes there too (same commit message convention)

**If no docs directory is found** (neither in-repo nor external), skip this step.

## Step 4: Lint & Fix
- Run `npm run lint` (or the project's lint command)
- Fix any errors automatically where possible
- If lint errors can't be auto-fixed, report them to the user

## Step 5: Compact
- Check the size of the project's `CLAUDE.md`
- If it exceeds ~20k characters:
  - Move verbose history, phase notes, and detailed learnings to `memory/` files
  - Keep CLAUDE.md lean: rules + compact current state + summary learnings only
  - Link moved content from `MEMORY.md` index
- Check `memory/` files for redundant or stale entries — deduplicate and prune

## Step 6: Stage
- Stage specific changed files with `git add <file>` (never use `git add -A` or `git add .`)
- Do NOT stage files that contain secrets (.env, credentials.json, etc.)
- If secrets are detected, warn the user

## Step 7: Commit
- Draft a concise commit message (1-2 sentences) focusing on the "why" not the "what"
- Include `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>` in the message
- Create the commit

## Step 8: Push Decision
- Ask the user: "Push to remote?" — do NOT push automatically
- Only push after explicit user confirmation

## Step 9: Context Window Compact
- After the commit (and optional push), remind the user: "Run `/compact` or start a new conversation for a fresh context window."
- `/compact` is a built-in CLI command — only the user can invoke it, not the agent
- The commit is the natural break point — next task benefits from a clean context
