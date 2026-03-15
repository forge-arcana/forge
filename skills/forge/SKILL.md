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
3. If the resolved path doesn't exist, error: "Forge not found. Clone the forge repo and run `install.sh` first."

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

### 1a: Skill Sync (manifest-based)

Read `~/.claude/skills/.forge-manifest.json`. For each skill in `<forge-path>/skills/`:

1. Hash the skill directory
2. Compare against the manifest hash
3. Classify: `ADDED` (new skill in forge), `UPDATED` (hash differs), `REMOVED` (in manifest but gone from forge), `UNCHANGED`

Present the sync report:
```markdown
## Skill Sync Report

| Skill | Status | Action |
|-------|--------|--------|
| arch | UNCHANGED | — |
| wrap | UPDATED | Overwrite ~/.claude/skills/wrap/ |
| newskill | ADDED | Deploy to ~/.claude/skills/newskill/ |
| oldskill | REMOVED | Remove from ~/.claude/skills/oldskill/ |
```

After user confirms:
- Deploy ADDED skills (copy directory)
- Update UPDATED skills (replace directory)
- Remove REMOVED skills (delete directory)
- Update the manifest with new hashes

If no manifest exists (new machine), run `<forge-path>/install.sh` instead and skip to Step 2.

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

1. Read `<forge-path>/code/claude-code-rules.md` — workflow rules
2. Read `<forge-path>/code/stack-guide.md` — tech stack reference
3. Read `<forge-path>/skills/forge/forge-conventions.md` — distilled conventions checklist

## Step 3: Scan Current Project

1. Does `CLAUDE.md` exist? Read it.
2. Does `.claude/settings.json` exist? Read it.
3. Does `memory/` directory exist?
4. Does `docs/` directory exist?
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
| .claude/settings.json | Standard permissions | [exists/missing] | [create/update] |
| memory/ directory | Required | [exists/missing] | [create] |
| Shorthand commands | wawa/wrap as skill refs | [present/missing] | [add] |
| restart.sh | Recommended (run /srs) | [exists/missing] | [suggest /srs] |
| kill-zombies.sh | Recommended | [exists/missing] | [suggest /srs] |
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

## Current Context
[branch, recent work, test status — to be filled by /wrap]
```

### .claude/settings.json (create or update)
- Standard auto-allowed commands from forge reference
- WebFetch auto-allowed domains
- Do NOT overwrite project-specific `additionalDirectories` or `hooks`

### Directories
- Create `memory/` if missing
- Create `logs/` if missing

## Step 6: Summary

Report what was applied. Do NOT commit — instead ask:
> "Changes applied. Ready to wrap up? Run `/wrap` to commit with full context."
