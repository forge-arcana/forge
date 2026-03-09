# Forge Project Rules

## Purpose
Forge is the shared tooling, conventions, and reference documentation repo used across all projects.

## Key Files
- `code/claude-code-rules.md` — **Canonical reference** for Claude Code global rules and tool permissions. All projects' `~/.claude/CLAUDE.md` and `~/.claude/settings.json` should mirror this file.
- `code/stack-guide.md` — Technology decisions and logging conventions shared across projects.

## Shorthand Commands

### `upforge` — Push local config INTO the reference doc

**Meaning:** "My global CLAUDE.md and settings.json have evolved — sync the reference doc to match."

Steps:
1. Read `~/.claude/CLAUDE.md` (global rules)
2. Read `~/.claude/settings.json` (tool permissions)
3. Read `code/claude-code-rules.md` (reference doc)
4. Diff all three — identify additions, removals, and conflicts
5. Present a summary table of deviations to the user
6. After user confirms, apply changes to `code/claude-code-rules.md` to match the current global config
7. Commit the updated reference doc

**Direction:** `CLAUDE.md + settings.json` → `code/claude-code-rules.md`

### `reforge` — Pull reference doc INTO local config

**Meaning:** "The reference doc is the source of truth — reset my global config to match it."

Steps:
1. Read `code/claude-code-rules.md` (reference doc — source of truth)
2. Read `~/.claude/CLAUDE.md` (global rules)
3. Read `~/.claude/settings.json` (tool permissions)
4. Diff all three — identify deviations in CLAUDE.md and settings.json
5. Present a summary table of deviations to the user
6. After user confirms, apply changes:
   - Update `~/.claude/CLAUDE.md` rules sections to match the reference
   - Update `~/.claude/settings.json` permissions to match the reference (auto-allowed commands, WebFetch domains, env vars)
   - Preserve project-specific additions in settings.json that are clearly per-project (e.g., `additionalDirectories`, hooks)
7. Do NOT commit — these are local config files outside the repo

**Direction:** `code/claude-code-rules.md` → `CLAUDE.md + settings.json`

## Sync Rules

When syncing in either direction:
- **CLAUDE.md "Bash Permissions" section** mirrors the **Auto-Allowed Commands** table in the reference. Keep them identical.
- **settings.json `permissions.allow`** is the executable form of the same table. Every command in the reference's auto-allowed table must have a corresponding `Bash(command:*)` entry.
- **WebFetch domains** in settings.json must match the reference's domain list exactly (including `www.` prefixes).
- **Commands That Prompt** (destructive commands like `rm`, `git push`, `git reset`, `git clean`, `git restore`) must NEVER appear in settings.json `allow` list.
- **Env var prefixes** in settings.json (`DATABASE_URL=`, `PORT=`, etc.) must match the reference's env vars list.
- **Hooks and additionalDirectories** in settings.json are machine-specific — never sync these.
- **Project-specific CLAUDE.md files** (e.g., `jeepi/CLAUDE.md`) are NOT affected by either command — only the global `~/.claude/CLAUDE.md`.

## HARD RULE — No Command Chaining in Bash — EVER
> **NEVER use `&&`, `;`, or `||` to chain commands in a single Bash tool call.**
> This applies to the main agent AND all subagents. Zero exceptions. Zero tolerance.
> - `git -C <path> <cmd>` for git in other directories
> - Separate Bash tool calls for everything else
> - When spawning subagents, copy this rule verbatim into the prompt
