# Forge Learnings

Consolidated current-state learnings. Historical entries that were superseded have been pruned — git log has the full history.

## Architecture

### Three Pillars (2026-03-15)
- Forge has three git-tracked pillars: `skills/` (team tools), `learnings/` (team wisdom), `memory/` (team identity)
- All three flow bidirectionally: DOWN via `/cast`, UP via auto-memory + `/fold`
- `~/.claude/` is the staging membrane — not a source of truth

### Knowledge Flow (2026-03-21)
- Cast and fold are symmetric mirrors — both triage before acting, both present tables, both ask for confirmation. See `memory/identity.md` "The Heart of Cast and Fold" for design rationale.
- Both use the **universal classification system** (IDENTICAL, FORGE-UPDATED, DEPLOYED-DIFFERS, CONFLICT, ADDED, REMOVED) from `preflight.md`
- **Cast (forge → user)**: Deploys ADDED and FORGE-UPDATED entries. Skips DEPLOYED-DIFFERS (advises `/fold` first). Never overwrites silently.
- **Fold (user → forge)**: Absorbs REMOVED and DEPLOYED-DIFFERS entries. Adds fold-specific sub-classifications (NEW, CROSS-CUTTING, DUPLICATE, INCORPORATED, SUPERSEDED) for quality gating. Never removes forge-only content.
- **Config sync**: Cast deploys forge rules → `~/.claude/CLAUDE.md`. Fold absorbs user additions → `claude-code-rules.md`. Neither direction removes the other side's content.
- Arts flag learnings as `Forge-worthy: yes/no` at write time during art runs
- Learnings accumulate in project memory (`~/.claude/projects/*/memory/*-learnings.md`), then `/fold` Part 3 Step 0 scans for `Forge-worthy: yes` entries, genericizes, and promotes to `~/.claude/learnings/general.md`
- `/fold` Part 3 Steps 1-4 triage and absorb into `forge/learnings/` → next art run reads them first
- `/fold` NEVER deletes from user's global space — tracks processed entries via title-based tracker
- Promotion is always a COPY, never a move — project entries persist after promotion
- `/fold` triage must output as console text, never AskUserQuestion (compressed UI is unreadable for large tables)

## Skills

### Structure (2026-03-18)
- Arts (7): prime, probe, poke, press, pound, pry, purge — specialist agent skills with self-improving loops
- Evaluative trifecta: poke (code quality + tech debt) → press (go-live readiness) → pound (adversarial QA) — poke often, press before milestones, pound before ship
- Task skills (13): cast, fold, mark, wawa, wrap, qt, srs, vsix, ponci, monci, dig, temper, eli5
- `skills/forge/` holds reference docs (stack-guide, rules, conventions, protocol) — not a deployable skill
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

### Drift Detection (2026-03-21)
- `forge-status.sh` is the shared classification engine — one script, three interpretations
- `/mark` runs it in fetch mode (read-only), `/cast` and `/fold` run it in pull mode (before acting)
- Script handles skill drift (three-way with baseline SHA), learning status, memory status — all mechanically
- Git-based comparison using `diff --strip-trailing-cr` (no CRLF issues across OSes)
- Cast acts on the cast column (deploy ADDED/FORGE-UPDATED), fold acts on the fold column (absorb REMOVED/DEPLOYED-DIFFERS)
- No manual inbox needed — all knowledge flows through auto-memory → staging → `/fold`

### /fold Unified Flow (2026-03-17)
- Seven parts: classification + config sync → review & prune (auto-triggered) → learning absorption → memory absorption → staging archival → commit & push → report
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

### /ponci + /monci (2026-03-15)
- `/ponci` = push + invoke `/monci`
- `/monci` = monitor CI only (no push)
