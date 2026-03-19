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

This resolves the forge path, pulls the latest forge (aborting if diverged), and produces the **Skill Drift Report**.

**Additional /cast responsibility**: If the resolved forge path differs from the `forge-path:` line in `~/.claude/CLAUDE.md` (or the line doesn't exist), update/add it. `/cast` owns `forge-path:` management.

## Step 1: Sync All Three Pillars

Before touching the project, ensure the user's `~/.claude/` is up to date with forge.

### 1a: Skill Sync (using preflight drift results)

Use the drift classifications from the preflight Skill Drift Report:

| Classification | Action |
|---------------|--------|
| `IDENTICAL` | Skip |
| `FORGE-UPDATED` | Show diff, deploy forge version (forge is newer) |
| `DEPLOYED-DIFFERS` | Show diff. Advise user to run `/fold` first to absorb deployed changes before overwriting |
| `ADDED` | Deploy to `~/.claude/skills/<name>/` |
| `REMOVED` | Remove from `~/.claude/skills/<name>/` |

After user confirms:
- Deploy ADDED skills (copy directory)
- Update FORGE-UPDATED skills (replace directory with forge version)
- For DEPLOYED-DIFFERS: warn before overwriting — user may want to `/fold` first
- Remove REMOVED skills (delete directory)

If no deployed skills exist (fresh machine):
- Create `~/.claude/skills/`, `~/.claude/learnings/`, `~/.claude/memory/` if they don't exist
- Deploy ALL skills from `<forge-path>/skills/` (treat every skill as ADDED)
- Then continue to Steps 1b and 1c as normal

### 1b: Learning Sync (forge → user)

For each `.md` file in `<forge-path>/learnings/`:
- If the file doesn't exist in `~/.claude/learnings/`, copy it
- If it exists, compare with `diff --strip-trailing-cr`: if different, report: "forge has updates — run /fold to reconcile"
- If identical, skip

### 1c: Memory Sync (forge → user)

For each `.md` file in `<forge-path>/memory/`:
- If the file doesn't exist in `~/.claude/memory/`, copy it (team memory → user)
- If it exists, compare with `diff --strip-trailing-cr`: if different, report: "forge has updates — user copy may have local additions"
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
| Hard rules (no auto-commit, no chaining) | Live in global `~/.claude/CLAUDE.md` — do NOT duplicate in project | [global/missing] | Skip if global membrane exists |
| .claude/settings.json | Only if project-specific overrides needed | [exists/missing/not needed] | [skip/create] |
| memory/ directory | Required | [exists/missing] | [create] |
| logs/ directory | Required (app projects with services only) | [exists/missing/N/A] | [create/skip] |
| Shorthand commands | wawa/wrap as skill refs | [present/missing] | [add] |
| restart.sh | Recommended (run /srs) | [exists/missing] | [suggest /srs] |
| kill-zombies.sh | Recommended | [exists/missing] | [suggest /srs] |
| Documentation | `docs/` in-repo OR `## Documentation` section with `**Docs path:**` | [in-repo/external/missing] | [add section] |
| Logging setup | dev.log + browser forwarding | [present/missing] | [flag for /poke] |
```

Present this to the user and ask for confirmation before applying.

## Step 5: Apply Changes

After user confirms:

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

## Step 6: Summary

Report what was applied. Do NOT commit — instead ask:
> "Changes applied. Ready to wrap up? Run `/wrap` to commit with full context."
