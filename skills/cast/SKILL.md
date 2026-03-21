---
name: cast
description: Deploy forge conventions into a project workspace. Pulls latest forge, syncs the membrane, analyzes divergence, applies CLAUDE.md, settings, and structure. Use when setting up a new project or syncing conventions.
user-invocable: true
---

# /cast — Deploy Forge Into Project

You are casting forge conventions into a project workspace. This ensures every project has consistent rules, structure, and tooling.

Cast is a thin directional wrapper around the shared classification engine (`forge-status.sh`). It runs the same script as `/mark`, then deploys everything in the **cast column** of the [universal classification table](../forge/preflight.md).

## Arguments
`$ARGUMENTS` — optional path to target project (e.g., `/cast /root/dev/myproject`). If not provided, use the current working directory.

## Step 0: Preflight + Classification

> Execute [Forge Preflight](../forge/preflight.md) in **pull** mode.

Run `<forge>/scripts/forge-status.sh --pull` to pull the latest forge and produce the **full classification report** across all pillars (skills, learnings, memory). This single script call replaces ~30 sequential tool calls.

Use the script's output as your action plan for Step 1.

**Additional /cast responsibility**: If the resolved forge path differs from the `forge-path:` line in `~/.claude/CLAUDE.md` (or the line doesn't exist), update/add it. `/cast` owns `forge-path:` management.

## Step 1: Membrane Sync (forge → user)

For each classified entry in the script output, apply the **cast direction**:

| Classification | Cast Action |
|----------------|-------------|
| `IDENTICAL` | Skip |
| `FORGE-UPDATED` | Deploy forge version (show diff first) |
| `DEPLOYED-DIFFERS` | Skip — advise user to run `/fold` first |
| `CONFLICT` | Show both versions, user decides via `AskUserQuestion` |
| `ADDED` | Deploy to membrane |
| `REMOVED` | Skip — flows via `/fold` |

Follow the **triage ceremony** (preflight.md): classify → present report table → `AskUserQuestion` to confirm → apply only confirmed entries.

### Skill Deployment

After user confirms, deploy using the cast-deploy script:

```bash
# Deploy specific skills (FORGE-UPDATED or ADDED)
bash <forge>/scripts/cast-deploy.sh skill1 skill2 ...

# Or deploy all (fresh machine)
bash <forge>/scripts/cast-deploy.sh --all
```

**NEVER use `cp -r` directly.** Always use `cast-deploy.sh`. Verify with `cast-deploy.sh --verify`.

For REMOVED: `rm -rf ~/.claude/skills/<name>/`.

If no deployed skills exist (fresh machine): create `~/.claude/learnings/`, `~/.claude/memory/` if needed, deploy ALL skills, then continue.

### Config Sync (forge → user)

Deploy forge rules from `<forge>/skills/forge/claude-code-rules.md` into `~/.claude/CLAUDE.md`. Same cast direction applies:
- ADDED (forge-only rules) → propose adding
- REMOVED (user-only rules) → skip (flow via `/fold`)
- CONFLICT → present both, user decides

**Never sync**: hooks, additionalDirectories, machine-specific paths. `forge-path:` is managed in Step 0.

### Record Cast Baseline

After all pillars are synced, write `~/.claude/.last-cast.json`:
```json
{ "lastCastCommit": "<output of git -C <forge-path> rev-parse HEAD>" }
```

Present a **Pillar Sync Summary** before proceeding to the project scan.

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
| Hard rules | Live in global `~/.claude/CLAUDE.md` — do NOT duplicate | [global/missing] | Skip if global exists |
| .claude/settings.json | Only if project-specific overrides needed | [exists/missing] | [skip/create] |
| memory/ directory | Required | [exists/missing] | [create] |
| logs/ directory | Required (app projects with services only) | [exists/missing/N/A] | [create/skip] |
| Shorthand commands | wawa/wrap as skill refs | [present/missing] | [add] |
| restart.sh / kill-zombies.sh | Recommended (run /srs) | [exists/missing] | [suggest /srs] |
| Documentation | `docs/` or `**Docs path:**` section | [in-repo/external/missing] | [add section] |
| Logging setup | dev.log + browser forwarding | [present/missing] | [flag for /poke] |
```

Use `AskUserQuestion` to confirm before applying. Options: "Apply all" / "Skip some" / "Abort".

## Step 5: Apply Changes

After user confirms via AskUserQuestion:

### CLAUDE.md (create or update)
Hard rules live in the global `~/.claude/CLAUDE.md`. Do NOT duplicate them in project CLAUDE.md files.

```markdown
# [Project Name] — Project Rules

## Stack
[from project's package.json and tsconfig]

## Shorthand Commands
- **wawa** — Runs the `/wawa` skill
- **wrap** — Runs the `/wrap` skill

## Documentation
<!-- docs/ in-repo OR **Docs path:** /absolute/path -->

## Current Context
[branch, recent work, test status — to be filled by /wrap]
```

### .claude/settings.json (only if project-specific overrides needed)
- Only create if the project needs extra env var prefixes, hooks, or domain restrictions
- Add overrides only — do NOT duplicate the global allow list
- Do NOT overwrite existing `additionalDirectories` or `hooks`

### Directories
- Create `memory/` if missing
- Create `logs/` if missing (only for projects with running services)

## Step 6: Summary

Present a **Forge Transfer** table summarizing what changed:

```markdown
## Forge Transfer — /cast | [DATE]

| Direction | What |
|-----------|------|
| ⬇ RECEIVED | `/temper` skill — hardened evaluation via repeated poke + press |
| ⬇ RECEIVED | `/probe` update — context-aware target resolution |
| ⬇ RECEIVED | 2 new learnings — mobile testing progression, integer money pattern |
```

- **⬇ RECEIVED** — skills deployed, learnings synced, memory copied, config rules installed
- If DEPLOYED-DIFFERS was detected, note: "X items have membrane changes — run `/fold` to absorb before next `/cast`"
- If nothing changed: just say "Everything in sync."

If changes were applied to the project, do NOT commit — use `AskUserQuestion` to prompt: "Ready to wrap up?" with options "Yes, run /wrap" / "Not yet". If nothing changed, skip the prompt.
