# Forge Learnings

Consolidated current-state learnings. Historical entries that were superseded have been pruned — git log has the full history.

## Architecture

### Three Pillars (2026-03-15)
- Forge has three git-tracked pillars: `skills/` (team tools), `learnings/` (team wisdom), `memory/` (team identity)
- All three flow bidirectionally: DOWN via `/forge`, UP via `/wrap` + `/reforge`
- `~/.claude/` is the staging membrane — not a source of truth

### Knowledge Flow (2026-03-15)
- `/wrap` is two-stage: (1) project level — repo `memory/` + Claude project memory, (2) promote generics to `~/.claude/learnings/` + `~/.claude/memory/`
- `/wrap` NEVER touches the forge repo — global Claude space is the staging area
- `/reforge` consumes ONLY from global Claude space + forge's own `learnings/inbox.md`
- `/reforge` NEVER deletes from user's global space — tracks processed entries via content hashes
- Promotion is always a COPY, never a move — project entries persist after promotion
- Dedup at every level: project learnings, project memory, global learnings, global memory

### Self-Improving Loop (2026-03-15)
- `/arch`, `/audit`, `/quick` flag learnings as `Forge-worthy: yes/no` at write time
- `/wrap` Stage 2 auto-promotes flagged entries, skips judgment on unflagged ones
- `/reforge` absorbs into `forge/learnings/` → next skill run reads them first

## Skills

### Structure (2026-03-15)
- 11 global skills: pitch, bluep, arch, forge, dive, audit, wawa, wrap, quick, qt, srs
- 1 forge-local skill: reforge (in `.claude/skills/reforge/`)
- Skills are self-contained packages — reference docs live inside the owning skill directory
- `skills/` is the git-tracked source of truth; `~/.claude/skills/` is the deployment target

### Bootstrap (2026-03-15)
- `.claude/skills/forge/SKILL.md` is a thin bootstrap pointing to `skills/forge/SKILL.md`
- On fresh clone, Claude Code discovers this bootstrap → user runs `/forge` → full setup
- No `install.sh` needed — `/forge` handles both fresh-machine setup and ongoing sync
- Thin bootstrap avoids symlinks (OS-dependent) and full duplication (drift risk)

### Frontmatter (2026-03-15)
- Valid SKILL.md frontmatter attributes: `name`, `description`, `user-invocable`, `argument-hint`, `compatibility`, `disable-model-invocation`, `license`, `metadata`
- `allowed-tools` and `context` are NOT valid attributes

### Forge Path Resolution (2026-03-15)
- Skills use `<forge>` notation with a one-line `## Forge Path` section
- `/forge` SKILL.md has the full resolution block with fallback (entry point)
- `/forge` owns `forge-path:` management — writes/updates it in `~/.claude/CLAUDE.md`

## Deployment

### Manifest (2026-03-15)
- `.forge-manifest.json` tracks SHA256 hashes per skill directory for drift detection
- `/forge` classifies each skill as ADDED/UPDATED/REMOVED/UNCHANGED
- Forge's human-contributed inbox is `learnings/inbox.md` (not `general.md`)

### /reforge Unified Flow (2026-03-15)
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

### /qt (2026-03-15)
- `/qt` replaces old `dd` debug-dev inline command
