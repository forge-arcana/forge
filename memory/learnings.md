# Forge Learnings

Consolidated current-state learnings. Historical entries that were superseded have been pruned — git log has the full history.

## Architecture

### Three Pillars (2026-03-15)
- Forge has three git-tracked pillars: `skills/` (team tools), `learnings/` (team wisdom), `memory/` (team identity)
- All three flow bidirectionally: DOWN via `/cast`, UP via auto-memory + `/fold`
- `~/.claude/` is the staging membrane — not a source of truth

### Knowledge Flow (2026-03-17)
- Learnings accumulate automatically during work sessions via Claude Code's auto-memory system
- `/fold` consumes ONLY from global Claude space (`~/.claude/learnings/` + `~/.claude/memory/`)
- `/fold` NEVER deletes from user's global space — tracks processed entries via content hashes
- Promotion is always a COPY, never a move — project entries persist after promotion
- Dedup at every level: project learnings, project memory, global learnings, global memory

### Self-Improving Loop (2026-03-15)
- Arts (`/prime`, `/probe`, `/poke`, `/press`, `/pound`) flag learnings as `Forge-worthy: yes/no` at write time
- Auto-memory promotes flagged entries during sessions
- `/fold` absorbs into `forge/learnings/` → next skill run reads them first

### Core Loop Rename (2026-03-17)
- `/forge` → `/cast` (deploy forge → membrane → project — "pour molten metal into the mold")
- `/reforge` → `/fold` (absorb knowledge back into forge — "layer experience into the steel")
- New: `/mark` (inspect membrane status — "hallmark inspection", read-only)
- All one-syllable metallurgy verbs. `/wrap` is a utility skill, not part of the forge loop.

## Skills

### Structure (2026-03-18)
- Arts (5): prime, probe, poke, press, pound — specialist agent skills with self-improving loops
- Task skills (11): cast, fold, mark, wawa, wrap, qt, srs, vsix, ponci, monci, forge (reference-only)
- `skills/forge/` directory still exists but only holds reference docs (no SKILL.md) — not a skill
- Skills are self-contained packages — reference docs live inside the owning skill directory
- `skills/` is the git-tracked source of truth; `~/.claude/skills/` is the deployment target

### Bootstrap (2026-03-17)
- `.claude/skills/cast/SKILL.md` is a thin bootstrap pointing to `skills/cast/SKILL.md`
- On fresh clone, Claude Code discovers this bootstrap → user runs `/cast` → full setup
- No `install.sh` needed — `/cast` handles both fresh-machine setup and ongoing sync
- Thin bootstrap avoids symlinks (OS-dependent) and full duplication (drift risk)

### Frontmatter (2026-03-15)
- Valid SKILL.md frontmatter attributes: `name`, `description`, `user-invocable`, `argument-hint`, `compatibility`, `disable-model-invocation`, `license`, `metadata`
- `allowed-tools` and `context` are NOT valid attributes

### Forge Path Resolution (2026-03-17)
- Skills use `<forge>` notation with a one-line `## Forge Path` section
- `/cast` SKILL.md has the full resolution block with fallback (entry point)
- `/cast` owns `forge-path:` management — writes/updates it in `~/.claude/CLAUDE.md`

## Deployment

### Drift Detection (2026-03-18)
- Git-based drift detection using `diff --strip-trailing-cr` (no CRLF issues across OSes)
- `/mark` always runs `git fetch` first, then diffs forge source vs deployed membrane
- `/cast` does `git pull` then diff-based skill sync — no manifest file needed
- `/fold` Part 1a does skill reverse-sync: diffs deployed `~/.claude/skills/` against `<forge>/skills/`, absorbs deployed-side changes back into forge source
- Both directions covered: `/cast` warns about drift, `/fold` absorbs it
- `/mark` provides read-only inspection of the full membrane state
- No manual inbox needed — all knowledge flows through auto-memory → staging → `/fold`

### /fold Unified Flow (2026-03-17)
- Six parts: config sync → review & prune (auto-triggered) → learning absorption → memory absorption → staging archival → report
- Review fires automatically based on size thresholds (learnings >50, memory >20 files)
- Review runs BEFORE absorption to prune stale knowledge first
- Staging archival also auto-triggers (>100 entries, >30 files)

## Conventions

### Settings Hierarchy (2026-03-15)
- Global `~/.claude/settings.json` handles all standard permissions — no per-project file needed by default
- Per-project `.claude/settings.json` only for overrides (extra env vars, hooks, domain restrictions)
- Don't duplicate the global allow list into every project — DRY violation

### Conditional Directories (2026-03-15)
- `memory/` is required in every project
- `logs/` only for app projects with running services (dev.log, browser console forwarding) — skip for tooling-only repos
- `docs/` only if project has documentation

## Settings & Platform

### WSL Compatibility (2026-03-15)
- `~/.claude/settings.json` additionalDirectories must include all 3 path formats: Windows (`D:\`), WSL-mount (`/mnt/d/`), native Linux (`/root/dev/`)

### Timestamps Removed (2026-03-15)
- Communication Style (timestamps, elapsed times) convention removed from all forge docs and global config
- Claude's `[HH:MM]` timestamps are inaccurate — they don't reflect real wall-clock time
- Removed from: `~/.claude/CLAUDE.md`, `claude-code-rules.md`, `forge-conventions.md`, `/cast` SKILL.md template and divergence report

### /qt (2026-03-15)
- `/qt` replaces old `dd` debug-dev inline command

### /ponci + /monci Split (2026-03-15)
- `/ponci` = push + invoke `/monci` (was monolithic push+monitor)
- `/monci` = monitor CI only (no push) — useful for watching runs without pushing
- `/fold` triage must output as console text, never AskUserQuestion (compressed UI is unreadable for large tables)
