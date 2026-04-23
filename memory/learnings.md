# Forge Learnings

Consolidated current-state learnings. Historical entries that were superseded have been pruned — git log has the full history.

## Architecture

### Three Pillars (2026-03-15)
- Forge has three git-tracked pillars: `skills/` (team tools), `learnings/` (team wisdom), `memory/` (team identity)
- All three flow bidirectionally through the `/forge` cycle — incoming (forge → user) and outgoing (user → forge) share one PLAN table
- `~/.claude/` is the staging membrane — forge is the source of truth for structure, but the user is the source of truth for judgment

### Knowledge Flow (2026-03-21, updated 2026-04-23)
- `/forge` triages ALL pillars (skills, config, learnings, memory) before acting. One PLAN table, three directional sections (↓ incoming, ↑ outgoing, ⚠ conflicts). The user decides what gets transferred at each row. Nothing transfers without user judgment — no pillar gets a mechanical bypass.
- Uses the **universal classification system** (IDENTICAL, FORGE-UPDATED, DEPLOYED-DIFFERS, CONFLICT, ADDED, REMOVED) from `preflight.md`
- **Incoming (forge → user)**: `FORGE-UPDATED` / `ADDED` rows. User approves → cycle's cast phase deploys. Action vocabulary: `update`, `create`, `sync`.
- **Outgoing (user → forge)**: `DEPLOYED-DIFFERS` / `REMOVED` rows. User approves → cycle's fold phase absorbs. Richer skip reasons (duplicate, incorporated, superseded, personal); routes to specific files. Action vocabulary: `absorb`, `merge`, `skip (reason)`.
- **Conflicts (both changed)**: user picks a side per row (`[↓]` accept forge / `[↑]` keep membrane / `[ ]` skip).
- **Symmetry principle**: one gate, both directions, same review ceremony. User reviews every row. No direction skips review.
- **Config sync**: 1:1 mapping — `claude-code-rules.md` ↔ `~/.claude/CLAUDE.md`, `claude-code-settings.json` ↔ `~/.claude/settings.json`. Neither direction removes the other side's content.
- Arts flag learnings as `Forge-worthy: yes/no` at write time during art runs
- Learnings accumulate in project memory (`~/.claude/projects/*/memory/*-learnings.md`), then `/forge`'s fold phase (3d) scans for `Forge-worthy: yes` entries, genericizes, and promotes to `~/.claude/learnings/general.md`
- Fold phase (3e) then triages and absorbs into `forge/learnings/` → next art run reads them first
- `/forge` NEVER deletes from user's global space — tracks processed entries via title-based tracker
- Promotion is always a COPY, never a move — project entries persist after promotion
- `/forge` uses the unified PLAN/DONE two-report system — one 4-column format (What | Direction | Action/Result | Contributor). PLAN table always output as console text (compressed UI makes tables unreadable), then AskUserQuestion for confirmation. DONE table is the post-execution receipt.
- **Smith learning membrane** (three independent layers): Layer 1 — smith-learnings.md (orchestration: build order, heat sizing, art selection, wrap timing). Layer 3 — smith-apprentice-log.md (delegation: parallelization patterns, scope sizing). Layer 2 — art learnings (unchanged, each art writes to its own file via forge protocol). Smith reads all three in preflight. Arts evolve independently through smith's repeated use.

## Skills

### Structure (2026-03-27)
- **The Master**: `/smith` — the user's proxy, wields all arts autonomously through iterative heats. Summons apprentices for parallel work. Converges on perfection via temper+pound convergence loop. Has its own three-layer learning membrane (orchestration, delegation, art proficiency).
- Arts (9): prime, probe, poke, preen, press, pound, pitch, pry + purge (forge-internal) — specialist agent skills with self-improving loops. Purge is the cleanser (forge-internal, `.claude/skills/purge/`).
- Evaluative trifecta: poke (code quality + tech debt) → press (go-live readiness) → pound (adversarial QA) — escalates in intensity. Preen (UI/UX design) and pitch (business model) run orthogonal — triggered by domain, not intensity. Cadence: poke often, preen on UI changes, pitch before build + before ship, press before milestones, pound before ship
- Task skills (12): forge, wawa, wrap, qt, srs, cicd, vsix, ponci, monci, dig, temper, eli5
- `skills/forge/` holds both the `/forge` cycle SKILL.md AND reference docs (stack-guide, rules, conventions, protocol)
- `/forge` absorbs the retired `/cast`, `/mark`, `/fold` trio — their verbs survive as internal cycle phases (inspect / apply-incoming / absorb-outgoing)
- Skills are self-contained packages — reference docs live inside the owning skill directory
- `skills/` is the git-tracked shared reference; `~/.claude/skills/` is the deployment target

### Bootstrap (2026-03-17, updated 2026-04-23)
- `.claude/skills/forge/SKILL.md` is the bootstrap copy — full `/forge` logic mirrored here so fresh clones can run the cycle before skills are deployed
- On fresh clone, Claude Code discovers this bootstrap → user runs `/forge` → full setup (skills + learnings + memory + project scan)
- No `install.sh` needed — `/forge` handles fresh-machine setup and ongoing sync in the same flow
- Full mirror (not thin) avoids symlinks (OS-dependent) and drift between bootstrap and deployed copy

### Frontmatter (2026-03-15)
- Valid SKILL.md frontmatter attributes: `name`, `description`, `user-invocable`, `argument-hint`, `compatibility`, `disable-model-invocation`, `license`, `metadata`
- `allowed-tools` and `context` are NOT valid attributes

### Forge Path Resolution (2026-03-17, updated 2026-04-23)
- Skills use `<forge>` notation with a one-line `## Forge Path` section
- `/forge` SKILL.md has the full resolution block with fallback (entry point)
- `/forge` owns `forge-path:` management — writes/updates it in `~/.claude/CLAUDE.md`

## Deployment

### Drift Detection (2026-03-21, updated 2026-04-23)
- `forge-status.sh` is the shared classification engine — one script, one interpretation, consumed by `/forge`
- `/forge --dry` runs it in fetch mode (read-only inspection); `/forge` runs it in pull mode (before acting)
- Script handles skill drift (three-way with baseline SHA), learning status, memory status — all mechanically
- Git-based comparison using `diff --strip-trailing-cr` (no CRLF issues across OSes)
- Classifications route directly to PLAN table sections: `FORGE-UPDATED`/`ADDED` → ↓ incoming; `DEPLOYED-DIFFERS`/`REMOVED` → ↑ outgoing; `CONFLICT` → ⚠ conflicts
- No manual inbox needed — all knowledge flows through auto-memory → staging → `/forge`

### /forge Unified Cycle (2026-03-22, updated 2026-04-23)
- Five phases: preflight → mark (build PLAN table) → cast (apply incoming) → fold (absorb outgoing) → project scan → DONE report
- Cast phase runs BEFORE fold so the ruleset is current when absorption logic runs
- Review & prune of existing forge knowledge invoked from fold phase (3c) via `/purge` triggers (learnings >50, memory >20 files)
- Membrane compaction runs in fold phase (3h) — tied to absorption lifecycle (compact what the fold phase just confirmed as fully absorbed)
- Commit & push for forge changes runs at end of fold phase (3i); the cycle owns its own commit flow for the forge side
- `/forge --dry` skips cast, fold, and commit phases — prints the PLAN table and exits

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
