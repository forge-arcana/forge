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

Run `<forge>/scripts/forge-status.sh --pull` to execute the preflight. Use the Skill Drift Report from its output for Step 1a below.

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
| `CONFLICT` | Show both diffs (forge vs baseline, deployed vs baseline). Ask user to reconcile before proceeding |
| `ADDED` | Deploy to `~/.claude/skills/<name>/` |
| `REMOVED` | Remove from `~/.claude/skills/<name>/` |

After user confirms, deploy using the cast-deploy script:

```bash
# Deploy specific skills (FORGE-UPDATED or ADDED)
bash <forge>/scripts/cast-deploy.sh skill1 skill2 ...

# Or deploy all (fresh machine)
bash <forge>/scripts/cast-deploy.sh --all
```

**NEVER use `cp -r` directly for skill deployment.** Always use `cast-deploy.sh` — it handles the rm-then-copy correctly and verifies no nesting bugs occurred.

For DEPLOYED-DIFFERS: warn before overwriting — user may want to `/fold` first.
For REMOVED: `rm -rf ~/.claude/skills/<name>/`.

After deploying, verify with:
```bash
bash <forge>/scripts/cast-deploy.sh --verify
```

If no deployed skills exist (fresh machine):
- Create `~/.claude/learnings/`, `~/.claude/memory/` if they don't exist
- Deploy ALL skills: `bash <forge>/scripts/cast-deploy.sh --all`
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

### 1d: Record Cast Baseline

After all three pillars are synced, record the current forge commit as the deployment baseline:

Write `~/.claude/.last-cast.json`:
```json
{ "lastCastCommit": "<output of git -C <forge-path> rev-parse HEAD>" }
```

This enables three-way drift detection on subsequent `/mark` and `/fold` runs. The SHA marks what was deployed, so future comparisons can distinguish "forge updated since cast" from "deployed copy was modified".

Report what was synced across all three pillars before proceeding.

## Steps 2-3: Read Forge Reference + Scan Project (parallel)

Launch **all of these reads in parallel** (all independent):

**Forge reference reads:**
- Read `<forge-path>/skills/forge/claude-code-rules.md` — workflow rules
- Read `<forge-path>/skills/forge/stack-guide.md` — tech stack reference
- Read `<forge-path>/skills/forge/forge-conventions.md` — distilled conventions checklist

**Project scan reads:**
- Read `CLAUDE.md` (if it exists)
- Read `.claude/settings.json` (if it exists)
- Glob for `package.json`, `tsconfig*`, `pnpm-workspace.yaml`, `packages/`
- Check for `memory/`, `docs/`, `restart.sh`, `kill-zombies.sh` (project root)

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

Present a **Forge Transfer** table summarizing everything that moved between forge and the user's membrane during Steps 1-5. Build it from what actually happened — only include rows for items that changed.

```markdown
## Forge Transfer — /cast | [DATE]

| Direction | What |
|-----------|------|
| ⬇ RECEIVED | `/temper` skill — hardened evaluation via repeated poke + press |
| ⬇ RECEIVED | `/probe` update — context-aware target resolution |
| ⬇ RECEIVED | 2 new learnings — mobile testing progression, integer money pattern |
| ⬆ SENT | (rare — only if deployed-differs was detected and user chose to overwrite) |
```

- **⬇ RECEIVED** — skills deployed, learnings synced, memory copied from forge
- **⬆ SENT** — deployed-differs warnings where user's membrane had changes (advise `/fold` first)
- If nothing changed: just say "Everything in sync."
- Each row should have a brief human description of what was transferred, not just a filename

After the table, do NOT commit — ask:
> "Ready to wrap up? Run `/wrap` to commit with full context."
