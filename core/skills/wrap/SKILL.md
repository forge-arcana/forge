---
name: wrap
description: Pre-commit ritual. Lints, stages, saves context, updates docs, compacts, commits. Use when the user types "wrap" or wants to commit with full context.
---

# /wrap — Pre-Commit Ritual

Execute the following steps in order. Do NOT skip steps. Do NOT commit without completing all prior steps.

---

## Step 1: Lint & Fix
- Run `npm run lint` (or the project's lint command)
- Fix any errors automatically where possible
- If lint errors can't be auto-fixed, report them to the user
- **Why first:** Lint can change code, which affects what gets staged, documented, and learned.

## Step 2: Stage
- Stage specific changed files with `git add <file>` (never use `git add -A` or `git add .`)
- Do NOT stage files that contain secrets (.env, credentials.json, etc.)
- If secrets are detected, warn the user
- **Why before context/docs:** Now you see exactly what's going in — context and docs describe the final state.

## Step 3: Save Context + Locate Docs (parallel)

Do both of these **in parallel** (independent operations — sequentially if your harness lacks parallel tool calls):

**3a: Save Context**
- Update the `## Progress` section in the project's `CLAUDE.md`/`AGENTS.md`
- **Replace** it with current state: branch, test count, completed phases, pending work
- Stale history belongs in git log or memory files

**3b: Locate Docs Directory**

Locate the docs directory using this resolution order:

1. **In-repo**: Check for `docs/` directory in the project root
2. **External repo**: If no `docs/` exists, search the project's rules file (`CLAUDE.md`/`AGENTS.md`) for a `## Documentation` section containing a local filesystem path

**Convention for external docs**: In the rules file, declare the docs location like this:
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

## Step 5: Compact
- Check the size of the project's rules file (`CLAUDE.md`/`AGENTS.md`)
- If it exceeds ~20k characters:
  - Move verbose history, phase notes, and detailed learnings to `memory/` files
  - Keep the rules file lean: rules + compact current state + summary learnings only
  - Link moved content from `MEMORY.md` index
- Check `memory/` files for redundant or stale entries — deduplicate and prune

## Step 6: Commit
- Draft a concise commit message (1-2 sentences) focusing on the "why" not the "what"
- Do NOT add AI/agent attribution metadata (no `Co-Authored-By` footers)
- Create the commit

## Step 7: Push Decision
- Ask the user — using your harness's multi-choice prompt if available, otherwise inline — do NOT push automatically
  - Options: "Yes, push" / "No, keep local"
- Only push after explicit user confirmation
- If the user declines, skip the push

## Step 8: Context Window Compact
- After the commit (and optional push), remind the user: "Run `/compact` or start a new conversation for a fresh context window."
- `/compact` is a built-in CLI command (where the harness exposes one) — only the user can invoke it, not the agent
- The commit is the natural break point — next task benefits from a clean context
