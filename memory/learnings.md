# Forge Learnings

Consolidated current-state learnings. Historical entries that were superseded have been pruned — git log has the full history.

## Architecture

### Three Pillars (2026-03-15)
- Forge has three git-tracked pillars: `skills/` (team tools), `learnings/` (team wisdom), `memory/` (team identity)
- All three flow bidirectionally: DOWN via `/cast`, UP via auto-memory + `/fold`
- `~/.claude/` is the staging membrane — forge is the source of truth for structure, but the user is the source of truth for judgment

### Knowledge Flow (2026-03-21)
- Cast and fold are symmetric mirrors — both triage ALL pillars (skills, config, learnings, memory) before acting, both present PLAN tables, both require user approval. The user decides what gets transferred at the PLAN table. Nothing transfers without user judgment — no pillar gets a mechanical bypass.
- Both use the **universal classification system** (IDENTICAL, FORGE-UPDATED, DEPLOYED-DIFFERS, CONFLICT, ADDED, REMOVED) from `preflight.md`
- **Cast (forge → user)**: Triages ALL pillars in PLAN table. User reviews → approves/rejects individual items → only approved items deploy. Actions: `update`, `create`, `sync`, `conflict`, `fold first`.
- **Fold (user → forge)**: Triages ALL pillars in PLAN table. User reviews → approves/rejects individual items → only approved items absorb. Fold has richer skip reasons (duplicate, incorporated, superseded, personal) and routes to specific files. Actions: `absorb`, `merge`, `skip (reason)`, `conflict`.
- **Symmetry principle**: Same gate, both directions. User reviews every item. No direction skips the user's review.
- **Config sync**: 1:1 mapping — `claude-code-rules.md` ↔ `~/.claude/CLAUDE.md`, `claude-code-settings.json` ↔ `~/.claude/settings.json`. Neither direction removes the other side's content.
- Arts flag learnings as `Forge-worthy: yes/no` at write time during art runs
- Learnings accumulate in project memory (`~/.claude/projects/*/memory/*-learnings.md`), then `/fold` Part 3 Step 0 scans for `Forge-worthy: yes` entries, genericizes, and promotes to `~/.claude/learnings/general.md`
- `/fold` Part 3 Steps 1-4 triage and absorb into `forge/learnings/` → next art run reads them first
- `/fold` NEVER deletes from user's global space — tracks processed entries via title-based tracker
- Promotion is always a COPY, never a move — project entries persist after promotion
- `/fold` and `/cast` both use unified PLAN/DONE two-report system — same 3-column format (What | Action/Result | Contributor). PLAN table is always output as console text (compressed UI makes tables unreadable), then AskUserQuestion for confirmation. DONE table is the post-execution receipt.
- **Smith learning membrane** (three independent layers): Layer 1 — smith-learnings.md (orchestration: build order, heat sizing, art selection, wrap timing). Layer 3 — smith-apprentice-log.md (delegation: parallelization patterns, scope sizing). Layer 2 — art learnings (unchanged, each art writes to its own file via forge protocol). Smith reads all three in preflight. Arts evolve independently through smith's repeated use.

## Skills

### Structure (2026-03-27)
- **The Master**: `/smith` — the user's proxy, wields all arts autonomously through iterative heats. Summons apprentices for parallel work. Converges on perfection via temper+pound convergence loop. Has its own three-layer learning membrane (orchestration, delegation, art proficiency).
- Arts (9): prime, probe, poke, preen, press, pound, pitch, pry + purge (forge-internal) — specialist agent skills with self-improving loops. Purge is the cleanser (forge-internal, `.claude/skills/purge/`).
- Evaluative trifecta: poke (code quality + tech debt) → press (go-live readiness) → pound (adversarial QA) — escalates in intensity. Preen (UI/UX design) and pitch (business model) run orthogonal — triggered by domain, not intensity. Cadence: poke often, preen on UI changes, pitch before build + before ship, press before milestones, pound before ship
- Task skills (14): forge, cast, fold, mark, wawa, wrap, qt, srs, vsix, ponci, monci, dig, temper, eli5
- `skills/forge/` holds reference docs (stack-guide, rules, conventions, protocol) AND the `/forge` session toggle skill
- Skills are self-contained packages — reference docs live inside the owning skill directory
- `skills/` is the git-tracked shared reference; `~/.claude/skills/` is the deployment target

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

### /fold Unified Flow (2026-03-22)
- Six parts: preflight → config & skill sync → learning absorption → memory absorption → membrane compaction → commit & push → DONE report
- Review & prune of existing forge knowledge moved to `/purge` (fold absorbs new knowledge, purge audits existing)
- Size-threshold triggers (learnings >50, memory >20 files) now belong to `/purge` or flagged by `/mark`
- Membrane compaction stays in fold — tied to absorption lifecycle (compact what fold just confirmed as fully absorbed)

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
