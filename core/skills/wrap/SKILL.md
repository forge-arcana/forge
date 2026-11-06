---
name: wrap
description: Pre-commit ritual. Lints, stages, saves context, updates docs, compacts, commits. Use when the user types "wrap" or wants to commit with full context.
---
<!-- model: sonnet | escalate: Step 4 memory compaction → opus; no other fan-out -->

# /wrap — Pre-Commit Ritual

Run the steps in order; the commit comes only after every earlier step.

---

## Step 1: Lint & Fix
- Run `npm run lint` (or the project's lint command)
- Fix any errors automatically where possible
- If lint errors can't be auto-fixed, report them to the user
- **Why first:** Lint can change code, which affects what gets staged, documented, and learned.

## Step 1b: Rules-file Shadow Check
- Check for `CLAUDE.md` with a command that does not fail when it is absent, such as one `ls -a <project-root>` listing (read the names) or the harness's file-search tool; absent is the passing result.
- If `CLAUDE.md`'s whole content is exactly `@AGENTS.md` (a leftover import shim), it shadows nothing — note it in one line, suggest `/forge` to remove it, and continue the wrap. Do not stop.
- Otherwise, if BOTH `AGENTS.md` and `CLAUDE.md` (real content) exist at the project root, stop and flag it before staging. On Claude Code only `CLAUDE.md` loads, so `AGENTS.md` (the real rules) is silently ignored. This usually means `/init` or a memory-append shortcut recreated `CLAUDE.md`.
- Show the stray `CLAUDE.md` content and ask the user — using your harness's multi-choice prompt if available, otherwise inline: "Propose a merge into AGENTS.md for my approval" / "Leave it (I'll resolve)". On the first, show the proposed merged `AGENTS.md`; write it and delete `CLAUDE.md` only after the user approves that result.
- Never delete it without approval. If prompts are suppressed (e.g., invoked by `/smith`), report the shadow and do not delete. On Claude Code below 2.1.277 (or version unknown) never delete `CLAUDE.md` — report only.

## Step 1c: Version Check
- If the staged or working diff changes a unit's version source (a `VERSION` file or a manifest `version` field): verify `CHANGELOG.md` has an entry for the new version and that any derived manifest matches. Fix both in place before staging.
- If the project has deployable or publishable units and its rules file has no `## Versions` table, report it in one line and point to `<forge>/core/skills/forge/versioning.md`. Report only; never block the commit on it and never bump a version unasked.
- A commit that does not change a version source needs no bump: raising the version is a release act, not a per-commit one.

## Step 2: Stage
- Stage specific changed files with `git add <file>` (never use `git add -A` or `git add .`)
- Do NOT stage files that contain secrets (.env, credentials.json, etc.)
- If secrets are detected, warn the user
- **Why before context/docs:** Now you see exactly what's going in — context and docs describe the final state.

## Step 2b: Arts Gate
- If `$HOME/.claude/hooks/arts-gate.sh` exists, run `bash "$HOME/.claude/hooks/arts-gate.sh" --check <repo>`; it judges the staged set exactly as the commit will be judged. If the file is absent, continue silently. A `note —` line about untracked files is information only.
- `arts-gate: blocked — …`: stop here, before docs, compaction and commit, and tell the user which arts to run (/poke code, /pound security/identity/auth, /preen UI). If the user says to commit anyway, make the Step 5 commit as `FORGE_ARTS_SKIP='<their reason>' git commit ...`.
- Invoked by `/smith`: never self-skip. Run `/poke` on the staged diff, then re-run the check.

## Step 3: Save Context + Locate Docs (parallel)

Do both of these **in parallel** (independent operations — sequentially if your harness lacks parallel tool calls):

**3a: Save Context**
- Update the `## Current Context` section in the project's `AGENTS.md`
- Un-migrated project (only `CLAUDE.md` exists): write to that `CLAUDE.md` and print one line suggesting `/forge` to migrate. Never create a second rules file.
- **If the rules file has no `## Current Context` heading, create it** as the last section. Never append to a look-alike heading (`## Progress`, `## Status`, `## Roadmap`): `/wawa` reads `## Current Context` only, so anything written elsewhere is invisible to it. If a look-alike section exists, say so in one line and offer to split it (open work into `## Current Context`, dated history into `memory/`, standing reference under its own heading). Do not move it unasked.
- **Replace** the section with current state: branch, test count, completed phases, pending work. Never append a dated entry to it; a section that grows on every commit has become a changelog.
- **List open work by name inside the section**: a `### Deferred` list for known unfinished items and a `Parked:` line for intentional non-blockers. A pointer to another document reads as empty to `/wawa`.
- Stale history belongs in git log or memory files

**3b: Locate Docs Directory**

Locate the docs directory using this resolution order:

1. **In-repo**: Check for `docs/` directory in the project root
2. **External repo**: If no `docs/` exists, search the project's `AGENTS.md` (legacy: `CLAUDE.md` if not yet migrated) for a `## Documentation` section containing a local filesystem path

**Convention for external docs**: In the rules file, declare the docs location like this:
```markdown
## Documentation
**Docs path:** /absolute/path/to/docs-repo
```
The skill also recognizes paths in parentheses — e.g., `(/path/to/docs-repo)` — for backwards compatibility.

**Once a docs directory is resolved**:
- Scan it for files (`.md`, `.mdx`) referencing the areas changed this session
- Update any affected documentation to reflect the changes
- If the docs are in a separate repo, stage those changes there, then ask the user for explicit confirmation — using your harness's multi-choice prompt if available, otherwise inline — before committing to that second repository (same commit message convention). Never commit a second repo unconfirmed.

**If no docs directory is found** (neither in-repo nor external), skip this step.

## Step 4: Compact (gated — skip entirely in the common case)
- Check the size of the project's `AGENTS.md` (legacy: `CLAUDE.md` if not yet migrated) — a cheap `wc -c`.
- **If it is under ~20k characters, skip this entire step.** Don't read or scan `memory/` files just to confirm they're fine. This is the common case and the single biggest cost lever in `/wrap` — an unconditional memory dedup re-reasons over the whole corpus on every commit.
- **Only if the rules file exceeds ~20k characters:**
  - Hand the compaction to an opus-tier subagent — curating long-term memory is judgment work, and a wrong keep/move call loses knowledge permanently. If your harness lacks subagent spawning or per-spawn model selection, defer: flag the oversized rules file to the user and skip compaction rather than running it at the current tier.
  - Move verbose history, phase notes, and detailed learnings to `memory/` files.
  - Keep the rules file lean: rules + compact current state + summary learnings only.
  - Link moved content from `MEMORY.md` index.
  - Deduplicate **only the memory files you touched this session** — not the whole `memory/` corpus. Full memory hygiene is a separate, deliberate tending pass, not part of a routine commit.

## Step 5: Commit
- Draft a concise commit message (1-2 sentences) focusing on the "why" not the "what"
- No AI/agent attribution metadata (no `Co-Authored-By` footers)
- Create the commit

## Step 6: Push Decision
- Ask the user — using your harness's multi-choice prompt if available, otherwise inline — and don't push automatically
  - Options: "Yes, push" / "No, keep local"
- This prompt is the user-review gate for the sonnet-tier work above: present the commit message and a summary of any doc updates in full alongside it, so the user reviews them before anything leaves the machine
- Only push after explicit user confirmation
- If the user declines, skip the push

## Step 7: Fresh Context
- The commit is the natural break point. If `bash "$HOME/.claude/skills/pass/pass.sh" status` reports auto, run `/pass`. Otherwise tell the user in one line: "`/clear` for unrelated next work, `/compact` to carry this context on." Both are user commands; the agent can't run them.
