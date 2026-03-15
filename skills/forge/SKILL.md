---
name: forge
description: Initialize or sync a project workspace with forge conventions. Pulls latest forge, analyzes divergence, applies CLAUDE.md, settings, and structure. Use when setting up a new project or syncing conventions.
user-invocable: true
---

# /forge — Workstation Initializer

You are applying forge conventions to a project workspace. This ensures every project has consistent rules, structure, and tooling.

## Resolve Forge Path
Before starting, determine the forge directory:
1. Check `~/.claude/CLAUDE.md` for a `forge-path:` line
2. If not found, fall back to `/root/dev/forge`
3. If the resolved path doesn't exist, error: "Forge not found. Clone the forge repo first."
4. If the resolved path differs from the `forge-path:` line in `~/.claude/CLAUDE.md` (or the line doesn't exist), update/add it. `/forge` owns `forge-path:` management.

## Arguments
`$ARGUMENTS` — optional path to target project (e.g., `/forge /root/dev/myproject`). If not provided, use the current working directory.

## Step 0: Pull Latest Forge (MANDATORY)

Before doing ANYTHING else, pull the latest forge repo:

```
git -C <forge-path> pull --ff-only
```

If the pull fails (diverged, conflicts), warn the user: "Forge repo has diverged. Run `git -C <forge-path> status` to investigate." Do NOT proceed with stale forge data.

## Step 1: Sync All Three Pillars

Before touching the project, ensure the user's `~/.claude/` is up to date with forge.

### 1a: Skill Sync (manifest-based, with reverse-drift detection)

Read `~/.claude/skills/.forge-manifest.json`. For each skill in `<forge-path>/skills/`:

1. Hash the forge source skill directory
2. Hash the deployed skill directory (`~/.claude/skills/<name>/`)
3. Compare both against the manifest hash
4. Classify using **three-way comparison**:

| Forge vs Manifest | Deployed vs Manifest | Classification |
|-------------------|---------------------|----------------|
| Same | Same | `UNCHANGED` |
| Different | Same | `UPDATED` (forge is newer — deploy it) |
| Same | Different | `REVERSE-DRIFT` (deployed is newer — warn, run /reforge) |
| Different | Different | `CONFLICT` (both changed — manual review needed) |
| New skill | — | `ADDED` |
| Gone from forge | — | `REMOVED` |

Present the sync report:
```markdown
## Skill Sync Report

| Skill | Status | Action |
|-------|--------|--------|
| arch | UNCHANGED | — |
| wrap | UPDATED | Overwrite ~/.claude/skills/wrap/ |
| qt | REVERSE-DRIFT | ⚠️ Deployed copy has changes not in forge — run /reforge first |
| srs | CONFLICT | ⚠️ Both forge and deployed changed — manual review |
| newskill | ADDED | Deploy to ~/.claude/skills/newskill/ |
| oldskill | REMOVED | Remove from ~/.claude/skills/oldskill/ |
```

After user confirms:
- Deploy ADDED skills (copy directory)
- Update UPDATED skills (replace directory)
- Remove REMOVED skills (delete directory)
- **REVERSE-DRIFT**: Do NOT overwrite. Warn user to run `/reforge` first to absorb deployed changes into forge source. Skip these skills.
- **CONFLICT**: Present a diff and let the user decide (merge, keep forge, keep deployed)
- Update the manifest with new hashes (only for skills that were synced)

If no manifest exists (fresh machine):
- Create `~/.claude/skills/`, `~/.claude/learnings/`, `~/.claude/memory/` if they don't exist
- Deploy ALL skills from `<forge-path>/skills/` (treat every skill as ADDED)
- Write a fresh manifest
- Then continue to Steps 1b and 1c as normal

### 1b: Learning Sync (forge → user)

For each `.md` file in `<forge-path>/learnings/`:
- If the file doesn't exist in `~/.claude/learnings/`, copy it
- If it exists but differs, report: "forge has updates — run /reforge to reconcile"
- If identical, skip

### 1c: Memory Sync (forge → user)

For each `.md` file in `<forge-path>/memory/`:
- If the file doesn't exist in `~/.claude/memory/`, copy it (team memory → user)
- If it exists but differs, report: "forge has updates — user copy may have local additions"
- If identical, skip

Report what was synced across all three pillars before proceeding.

## Step 2: Read Forge Reference

1. Read `<forge-path>/skills/forge/claude-code-rules.md` — workflow rules
2. Read `<forge-path>/skills/forge/stack-guide.md` — tech stack reference
3. Read `<forge-path>/skills/forge/forge-conventions.md` — distilled conventions checklist

## Step 3: Scan Current Project

1. Does `CLAUDE.md` exist? Read it.
2. Does `.claude/settings.json` exist? Read it.
3. Does `memory/` directory exist?
4. Does `docs/` directory exist? If not, does CLAUDE.md have a `## Documentation` section with a `**Docs path:**` declaring an external docs repo?
5. What's the project structure? (ls, glob for package.json, tsconfig, etc.)
6. Is it a monorepo? (check for `packages/`, `pnpm-workspace.yaml`)
7. Does `restart.sh` exist?
8. Does `kill-zombies.sh` exist?

## Step 4: Divergence Report

Produce a table showing what needs to change:

```markdown
## Divergence Report — [PROJECT NAME]

| Aspect | Forge Convention | Current Project | Action |
|--------|-----------------|-----------------|--------|
| CLAUDE.md | Required with standard sections | [exists/missing] | [create/update] |
| No auto-commit rule | Must be present | [present/missing] | [add] |
| No command chaining rule | Must be present | [present/missing] | [add] |
| Communication style (timestamps) | Required | [present/missing] | [add] |
| .claude/settings.json | Only if project-specific overrides needed | [exists/missing/not needed] | [skip/create] |
| memory/ directory | Required | [exists/missing] | [create] |
| logs/ directory | Required (app projects with services only) | [exists/missing/N/A] | [create/skip] |
| Shorthand commands | wawa/wrap as skill refs | [present/missing] | [add] |
| restart.sh | Recommended (run /srs) | [exists/missing] | [suggest /srs] |
| kill-zombies.sh | Recommended | [exists/missing] | [suggest /srs] |
| Documentation | `docs/` in-repo OR `## Documentation` section with `**Docs path:**` | [in-repo/external/missing] | [add section] |
| Logging setup | dev.log + browser forwarding | [present/missing] | [flag for /quick] |
```

Present this to the user and ask for confirmation before applying.

## Step 5: Apply Changes

After user confirms:

### CLAUDE.md (create or update)
Standard sections to include:
```markdown
# [Project Name] — Project Rules

## HARD RULE — No Auto-Commit
> NEVER commit automatically after completing any sprint, phase, or piece of work.
> Always ask the user: "Ready to wrap up? Run `/wrap` to commit with full context."

## HARD RULE — No Command Chaining in Bash — EVER
> NEVER use `&&`, `;`, or `||` to chain commands in a single Bash tool call.

## Stack
[from project's package.json and tsconfig]

## Communication Style
- Timestamp all messages: `[HH:MM]` format
- Elapsed time after tool calls

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

## Step 6: Summary

Report what was applied. Do NOT commit — instead ask:
> "Changes applied. Ready to wrap up? Run `/wrap` to commit with full context."
