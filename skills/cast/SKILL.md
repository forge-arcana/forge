---
name: cast
description: Deploy forge conventions into a project workspace. Pulls latest forge, syncs the membrane, analyzes divergence, applies CLAUDE.md, settings, and structure. Use when setting up a new project or syncing conventions.
user-invocable: true
---
<!-- model: sonnet -->

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

Build a unified table from the preflight output showing everything that will change across all three pillars (skills, learnings, memory). Use the Learning Details section from `forge-status.sh` for contributor names and summaries.

**Every row that represents a change must include a sub-row showing the essence of the change** — not the filename or commit title, but the rule, principle, or knowledge that will land in the membrane. The user must be able to judge each item before approving.

- **Skill row** → the specific rule, step, or behaviour that changed (not the commit message)
- **Learning row** → the full `**Learning**:` body + `**Apply when**:` line
- **Memory row** → the key principle or convention the file encodes

```markdown
## Forge Transfer — /cast | YYYY-MM-DD | PLAN

| What | Action | Contributor |
|------|--------|-------------|
| `/fold` skill | update | Pauee OSB |
|   → HARD RULE added: write absorbed learnings to `<forge>/learnings/`, never `~/.claude/learnings/`. Writing to membrane silently skips forge, creating a permanent gap no future fold run can fix. | | |
| Android 15 Edge-to-Edge Status Bar Overlap | sync → global-patterns.md | cygnum |
|   → Learning: Android 15 enforces edge-to-edge by default. `StatusBar.setOverlaysWebView` is silently ignored. CSS `env(safe-area-inset-top)` returns 0 on Android WebView. Only working fix in Capacitor 7: `adjustMarginsForEdgeToEdge: "force"` in `capacitor.config.ts`. Do not stack multiple fixes — they add padding independently. | | |
|   → Apply when: Capacitor 7 + Android 15 target, status bar overlap reported | | |
| deploy-practices.md (memory) | sync | — |
|   → Convention: gate all deploy scripts behind environment checks; never run destructive ops without explicit env confirmation | | |

17 skills identical, 5 learnings in sync, memory in sync — omitted.
```

**Action vocabulary**: `update` (skill forge-updated), `create` (skill added), `sync` (learning/memory), `conflict` (both changed — needs resolution), `fold first` (deployed-differs — warn user)

If everything is in sync: skip the table, say "Everything in sync." and proceed directly to project scan.

Present the table, then **AskUserQuestion**: "Apply all / Adjust / Skip".

## Step 2: Execute Sync

After user confirms, apply all three pillars:

### Skills
- **FORGE-UPDATED / ADDED**: `bash <forge>/scripts/cast-deploy.sh skill1 skill2 ...` (or `--all` for fresh machine)
- **DEPLOYED-DIFFERS**: warn before overwriting — user may want to `/fold` first
- **CONFLICT**: show both diffs, ask user to reconcile
- **REMOVED**: `rm -rf ~/.claude/skills/<name>/`
- Verify: `bash <forge>/scripts/cast-deploy.sh --verify`

**NEVER use `cp -r` directly.** Always use `cast-deploy.sh`.

If no deployed skills exist (fresh machine): create `~/.claude/learnings/`, `~/.claude/memory/` if needed, deploy ALL with `--all`.

### Learnings (forge → user)
For each `.md` in `<forge>/learnings/`: copy if missing, skip if identical, report if different.

### Memory (forge → user)
For each `.md` in `<forge>/memory/`: copy if missing, skip if identical, report if different.

### Record Baseline
Write `~/.claude/.last-cast.json` **after** all pillars are synced:
```json
{ "lastCastCommit": "<output of git -C <forge-path> rev-parse HEAD>" }
```

> **Crash recovery**: If the session ends before this write completes, the baseline will be missing. On the next `/mark` or `/fold` run, all differing skills will appear as `CONFLICT (no-baseline)`. Fix: re-run `/cast` — it will re-deploy from current HEAD and write a fresh baseline. No manual intervention needed.

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

**After all parallel reads complete**, proceed to:

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
| Shorthand commands (wawa/wrap/qt) | Live in global `~/.claude/CLAUDE.md` — do NOT duplicate in project | [global/duplicated] | Skip if global membrane exists; remove from project if duplicated |
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

Shorthand commands (wawa, wrap, qt) live in the global `~/.claude/CLAUDE.md`. Do NOT duplicate them in project CLAUDE.md files — the global membrane already covers all projects. If the project already has a `## Shorthand Commands` section, remove it during this cast.

```markdown
# [Project Name] — Project Rules

## Stack
[from project's package.json and tsconfig]

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

**Every changed row must include a sub-row showing the essence of the change** — not the filename or commit title, but the rule, principle, or knowledge that now lives in the membrane. A reader who never saw the PLAN table must understand *what shifted* from this report alone.

- **Skill row** → the specific rule, step, or behaviour that changed (not the commit message)
- **Learning row** → the full `**Learning**:` body + `**Apply when**:` line
- **Memory row** → the key principle or convention the file encodes

```markdown
## Forge Transfer — /cast | YYYY-MM-DD | DONE

| What | Result | Contributor |
|------|--------|-------------|
| `/fold` skill | updated | Pauee OSB |
|   → HARD RULE added: write absorbed learnings to `<forge>/learnings/`, never `~/.claude/learnings/`. Writing to membrane silently skips forge, creating a permanent gap no future fold run can fix. | | |
| Android 15 Edge-to-Edge Status Bar Overlap | synced → global-patterns.md | cygnum |
|   → Learning: Android 15 enforces edge-to-edge by default. `StatusBar.setOverlaysWebView` is silently ignored. CSS `env(safe-area-inset-top)` returns 0 on Android WebView. Only working fix in Capacitor 7: `adjustMarginsForEdgeToEdge: "force"` in `capacitor.config.ts`. Do not stack multiple fixes — they add padding independently. | | |
|   → Apply when: Capacitor 7 + Android 15 target, status bar overlap reported | | |
| deploy-practices.md (memory) | synced | — |
|   → Convention: gate all deploy scripts behind environment checks; never run destructive ops without explicit env confirmation | | |

Baseline recorded: `abc1234`
```

**Result vocabulary** (past tense of PLAN actions): `updated`, `created`, `synced`, `reconciled`, `skipped (user chose)`

If nothing changed: just say "Everything in sync." and skip both PLAN and DONE reports.

After the DONE report: include the baseline commit SHA, then output:

> **FORGE ENABLED** — all forge skills and art auto-invocation are active for this session.

Do NOT commit project changes — use `AskUserQuestion` to prompt: "Ready to wrap up?" with options "Yes, run /wrap" / "Not yet".
