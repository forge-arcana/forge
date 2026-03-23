---
name: cast
description: Deploy forge conventions into a project workspace. Pulls latest forge, syncs the membrane, analyzes divergence, applies CLAUDE.md, settings, and structure. Use when setting up a new project or syncing conventions.
user-invocable: true
---

# /cast — Deploy Forge Into Project

You are casting forge conventions into a project workspace. This ensures every project has consistent rules, structure, and tooling.

## Arguments
`$ARGUMENTS` — optional path to target project (e.g., `/cast /root/dev/myproject`). If not provided, use the current working directory.

## Step 0: Preflight

> Execute [Forge Preflight](../forge/preflight.md) in **pull** mode.

Run `<forge>/scripts/forge-status.sh --pull` to execute the preflight. Use the Skill Drift Report and Learning Details from its output for the PLAN Report in Step 1.

This resolves the forge path, pulls the latest forge (aborting if diverged), and produces the **Skill Drift Report**.

**Additional /cast responsibility**: If the resolved forge path differs from the `forge-path:` line in `~/.claude/CLAUDE.md` (or the line doesn't exist), update/add it. `/cast` owns `forge-path:` management.

## Step 1: PLAN Report — Decision Gate

Build a unified table from the preflight output showing everything that will change across ALL pillars (skills, config, learnings, memory). Use the Learning Details section from `forge-status.sh` for contributor names and summaries.

**ALL pillars require user review.** No pillar gets a mechanical bypass — a skill can have a bad update, a config can have stale rules, a learning can be wrong.

```markdown
## Forge Transfer — /cast | YYYY-MM-DD | PLAN

| What | Action | Contributor |
|------|--------|-------------|
| `/fold` skill | update | Pauee OSB |
| `/temper` skill | update | cygnum |
| claude-code-rules.md (config) | sync | — |
| claude-code-settings.json (config) | sync | — |
| Android 15 Edge-to-Edge Status Bar Overlap | sync | cygnum |
|   → Android 15 enforces edge-to-edge rendering — only fix is adjustMarginsForEdgeToEdge | | |
| deploy-practices.md (memory) | sync | — |

17 skills identical, 5 learnings in sync, memory in sync — omitted.
```

**Action vocabulary**: `update` (skill forge-updated), `create` (skill added), `sync` (learning/memory/config new in forge), `conflict` (both changed — needs resolution), `fold first` (deployed-differs — warn user)

If everything is in sync: skip the table, say "Everything in sync." and proceed directly to project scan.

**Output the PLAN table as console text (markdown), NEVER via AskUserQuestion** — compressed UI makes tables unreadable. Then use AskUserQuestion with "Apply all / Adjust / Skip" prompt.

User reviews → approves/rejects individual items → Step 2 executes only approved.

## Step 2: Execute Sync

**Only execute items the user approved in the PLAN table.** Skip any items the user rejected.

### Skills (approved items only)
- **FORGE-UPDATED / ADDED**: `bash <forge>/scripts/cast-deploy.sh skill1 skill2 ...` (or `--all` for fresh machine)
- **DEPLOYED-DIFFERS**: warn before overwriting — user may want to `/fold` first
- **CONFLICT**: show both diffs, ask user to reconcile
- **REMOVED**: `rm -rf ~/.claude/skills/<name>/`
- Verify: `bash <forge>/scripts/cast-deploy.sh --verify`

**NEVER use `cp -r` directly.** Always use `cast-deploy.sh`.

If no deployed skills exist (fresh machine): create `~/.claude/learnings/`, `~/.claude/memory/` if needed, deploy ALL with `--all`.

### Config (approved items only)
- `claude-code-rules.md` → diff against `~/.claude/CLAUDE.md`, propose additions/removals
- `claude-code-settings.json` → diff against `~/.claude/settings.json`, propose additions/removals
- Machine-specific entries (hooks, additionalDirectories) are never synced

### Learnings (approved items only)
Deploy only the learning files the user approved. Copy if missing in membrane, update if forge has newer version. Skip items the user rejected.

### Memory (approved items only)
Deploy only the memory files the user approved. Copy if missing in membrane, update if forge has newer version. Skip items the user rejected.

### One-Off Migrations
Remove stale files from previous forge layouts:
- If `~/.claude/learnings/purge-learnings.md` exists, delete it (moved to forge-internal `memory/`)
- If `~/.claude/skills/purge/` exists, remove it (`rm -rf`) — /purge is forge-only, no longer deployed to users

### Record Baseline
Write `~/.claude/.last-cast.json`:
```json
{ "lastCastCommit": "<output of git -C <forge-path> rev-parse HEAD>" }
```

## Step 3: Read Forge Reference + Scan Project (parallel)

Launch **all of these reads in parallel** (all independent):

**Forge reference reads:**
- Read `<forge-path>/skills/forge/claude-code-rules.md` — workflow rules
- Read `<forge-path>/skills/forge/stack-guide.md` — tech stack reference
- Read `<forge-path>/skills/forge/forge-conventions.md` — distilled conventions checklist

**Project scan reads:**
- Read `CLAUDE.md` (if it exists)
- Read `.claude/settings.json` (if it exists)
- Glob for `package.json`, `tsconfig*`, `pnpm-workspace.yaml`, `packages/`
- Check for `memory/`, `docs/`, `dev/restart.sh`, `dev/kill-zombies.sh`

## Step 4: Divergence Report

Produce a table showing what needs to change:

```markdown
## Divergence Report — [PROJECT NAME]

| Aspect | Forge Convention | Current Project | Action |
|--------|-----------------|-----------------|--------|
| CLAUDE.md | Required with standard sections | [exists/missing] | [create/update] |
| Hard rules (no auto-commit, no chaining) | Live in global `~/.claude/CLAUDE.md` — do NOT duplicate in project | [global/missing] | Skip if global membrane exists |
| .claude/settings.json | Only if project-specific overrides needed | [exists/missing/not needed] | [skip/create] |
| memory/ directory | Required | [exists/missing] | [create] |
| logs/ directory | Required (app projects with services only) | [exists/missing/N/A] | [create/skip] |
| Shorthand commands | wawa/wrap as skill refs | [present/missing] | [add] |
| dev/restart.sh | Recommended (run /srs) | [exists/missing] | [suggest /srs] |
| dev/kill-zombies.sh | Recommended | [exists/missing] | [suggest /srs] |
| Documentation | `docs/` in-repo OR `## Documentation` section with `**Docs path:**` | [in-repo/external/missing] | [add section] |
| Logging setup | dev.log + browser forwarding | [present/missing] | [flag for /poke] |
```

**IMPORTANT: Always present the divergence table as console text (markdown), then use `AskUserQuestion` with a simple confirmation prompt** (e.g., "Apply all changes?" with options like "Apply all", "Skip some", "Skip all"). Never use inline text questions — they're easy to miss and don't provide structured options. Wait for user confirmation before proceeding to Step 5.

## Step 5: Apply Changes

After user confirms via AskUserQuestion:

### CLAUDE.md (create or update)
Standard sections to include:
Hard rules (No Auto-Commit, No Command Chaining) live in the global `~/.claude/CLAUDE.md`. Do NOT duplicate them in project CLAUDE.md files — the global membrane already covers all projects.

```markdown
# [Project Name] — Project Rules

## Stack
[from project's package.json and tsconfig]

## Shorthand Commands
- **wawa** — Runs the `/wawa` skill
- **wrap** — Runs the `/wrap` skill

## Documentation
<!-- Include ONE of the following: -->
<!-- Option A: docs live in this repo -->
Docs are in the `docs/` directory.
<!-- Option B: docs live in a separate repo -->
**Docs path:** /absolute/path/to/docs-repo

## Current Context
[branch, recent work, test status — to be filled by /wrap]
```

### .claude/settings.json (only if project-specific overrides needed)
- Global `~/.claude/settings.json` handles all standard permissions — no per-project file needed by default
- Only create if the project needs extra env var prefixes, hooks, or domain restrictions
- If creating, add overrides only — do NOT duplicate the global allow list
- Do NOT overwrite existing project-specific `additionalDirectories` or `hooks`

### Directories
- Create `memory/` if missing
- Create `logs/` if missing (only for projects with running services — skip for tooling-only repos)

## Step 6: DONE Report

Present the receipt of what was actually executed. Only include rows for items that changed — no "in sync" rows.

```markdown
## Forge Transfer — /cast | YYYY-MM-DD | DONE

| What | Result | Contributor |
|------|--------|-------------|
| `/fold` skill | updated | Pauee OSB |
| `/temper` skill | updated | cygnum |
| claude-code-rules.md (config) | synced | — |
| Android 15 Edge-to-Edge Status Bar Overlap | synced | cygnum |
| deploy-practices.md (memory) | synced | — |

Baseline recorded: `abc1234`
```

**Result vocabulary** (past tense of PLAN actions): `updated`, `created`, `synced`, `reconciled`, `skipped (user chose)`

If nothing changed: just say "Everything in sync." and skip both PLAN and DONE reports.

After the DONE report: include the baseline commit SHA. Do NOT commit project changes — use `AskUserQuestion` to prompt: "Ready to wrap up?" with options "Yes, run /wrap" / "Not yet".

## IMPORTANT — Stale Context Warning

If ANY skills were deployed (updated or created), warn the user:

> **Skills updated on disk.** Other running Claude Code sessions still have the OLD skill text in their context window. Run `/compact` or restart those sessions before running `/fold` — otherwise fold may revert these changes using stale in-context instructions.

This warning is critical because `/cast` writes new SKILL.md files to `~/.claude/skills/`, but already-running sessions have the old skill text baked into their conversation. A `/fold` run in a stale session will treat its in-context (old) skill definitions as authoritative and "merge" them back into forge, silently undoing the cast.
