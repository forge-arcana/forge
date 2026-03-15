# Forge Learnings

## 2026-03-15 — Initial Skills Restructure
- Forge restructured from flat markdown files into Claude Code skills (`~/.claude/skills/<name>/SKILL.md` format)
- 13 global skills created: pitch, bluep, arch, forge, dive, audit, wow, wrap, quick, qt, srs
- 1 forge-local skill: reforge (merged old upforge + reforge into one)
- Pitch/blueprint frameworks moved from repo root to `pitch/` subdirectory with project-specific outputs in `pitch/<project>/`
- Self-improving skills (arch, audit, quick) write to project `memory/*-learnings.md`, reforge absorbs into `forge/learnings/`
- Old vsix directory removed (claudemeter binary doesn't belong in forge)
- `/qt` replaces old `dd` debug-dev inline command
- `/wrap` includes compaction step to keep CLAUDE.md lean

## 2026-03-15 — Reforge Enhancements & Settings Fix
- `/reforge` now includes: (1) triage-before-absorb — shows summary of new vs known learnings before writing, (2) genericization — strips all project-specific details before writing to forge learnings, (3) general.md redistribution — routes ad-hoc human learnings to the right skill files
- `allowed-tools` is NOT a valid SKILL.md frontmatter attribute — use `user-invocable: true` instead
- `~/.claude/settings.json` additionalDirectories must include all 3 path formats for Windows/WSL compatibility: Windows (`D:\`), WSL-mount (`/mnt/d/`), native Linux (`/root/dev/`)
- Missing bash commands added to settings.json allow list: kill, tee, cd, for, ip, ss, netstat, ipconfig, tasklist, wsl, powershell, cmd, pandoc, start, git rm/mv/check-ignore

## 2026-03-15 — Knowledge Flow Architecture
- `/wrap` is two-stage: (1) project level — repo `memory/` + Claude project memory, (2) promote generics to global `~/.claude/learnings/` + `~/.claude/memory/`
- `/wrap` NEVER touches the forge repo — global Claude space is the staging area
- `/reforge` consumes ONLY from global Claude space (`~/.claude/learnings/`, `~/.claude/memory/`) + forge's own `general.md`
- `/reforge` NEVER deletes from user's global space — only tracks what's been processed (dedup)
- Promotion is always a COPY, never a move — project entries persist after promotion
- Dedup at every level: project learnings, project memory, global learnings, global memory
- `/wow` renamed to `/wawa` ("Where Are We At?")
- Sibling file sync added to `/reforge` Step 7 — ensures `~/.claude/skills/` copies match forge source
- Learning review/expiry added as `/reforge review` — prunes stale, merges duplicates, rewrites evolved entries

## 2026-03-15 — Robustness & Hole-Plugging
- `/forge` now deploys global skills to `~/.claude/skills/` + has bootstrap sequence for new machines
- `/reforge` uses `.reforge-tracker.json` with content hashes to avoid re-evaluating already-processed learnings
- Self-improving skills (`/arch`, `/audit`, `/quick`) now flag learnings as `Forge-worthy: yes/no` so `/wrap` doesn't have to guess
- `/wrap` Stage 2 is conditional — only runs when new learnings exist and prioritizes flagged entries
- Forge's human-contributed inbox renamed from `general.md` to `inbox.md` to avoid confusion with user's `~/.claude/learnings/general.md`
- All `wow` references updated to `wawa` across forge skills, conventions, and rules

## 2026-03-15 — Three Pillars Architecture & Install Bootstrap
- Forge now has three git-tracked pillars: `skills/` (team tools), `learnings/` (team wisdom), `memory/` (team identity)
- All three pillars flow bidirectionally: DOWN via `/forge` + `install.sh`, UP via `/wrap` + `/reforge`
- `~/.claude/` is the staging membrane between forge and project work — not a source of truth
- `install.sh` created as the bootstrap script (`npm install` equivalent for forge): deploys skills, learnings, memory, writes `.forge-manifest.json`
- Manifest tracks SHA256 hashes per skill directory for drift detection — `/forge` uses this for ADDED/UPDATED/REMOVED/UNCHANGED classification
- Skills moved from `~/.claude/skills/` (untracked) to `forge/skills/` (git-tracked) as source of truth — enables PR review, git history, team sync
- All sibling framework files (blueprint-framework.md, qa-framework.md, pitch-framework.md, forge-conventions.md, restart-template.sh) co-located in their skill directories for self-contained packages
- FORGE_HOME env var and resolution blocks removed from all skills — replaced with `forge-path:` in `~/.claude/CLAUDE.md`
- `/forge` SKILL.md updated with Step 1: three-pillar sync (manifest-based skills + learning sync + memory sync)
- `/reforge` SKILL.md updated with Part 3: Memory Absorption — triages `~/.claude/memory/` into team-worthy vs personal, absorbs into `forge/memory/`
- `/reforge` Step 7 (skill sibling sync) removed — skill sync is now `/forge`'s responsibility
- Clean separation: `/forge` handles DOWN flow (forge → user), `/reforge` handles UP flow (user → forge)

## 2026-03-15 — Self-Contained Skills & Root Cleanup
- Reference docs absorbed into their owning skills: `code/stack-guide.md` → `skills/forge/`, `code/claude-code-rules.md` → `skills/forge/`, `code/qa-review-prompt.md` was already `skills/dive/qa-framework.md`
- Root `code/` directory eliminated — skills are self-contained, no orphan reference docs
- Root `pitch/` directory eliminated — project-specific outputs moved to general repo, framework files already in `skills/pitch/`
- Forge root is now minimal: three pillars (`skills/`, `learnings/`, `memory/`) + `install.sh` + `CLAUDE.md` + `README.md`
- All skill references updated from `code/` paths to `skills/forge/` paths (forge, arch, audit, quick, srs, reforge, forge-conventions)
- Principle: static reference docs should live inside the skill that owns and iterates on them — prevents stale orphans

## 2026-03-15 — Skill Frontmatter Cleanup
- `context` is NOT a valid SKILL.md frontmatter attribute — removed `context: fork` from audit, arch, dive, quick
- Valid SKILL.md frontmatter attributes: `name`, `description`, `user-invocable`, `argument-hint`, `compatibility`, `disable-model-invocation`, `license`, `metadata`

## 2026-03-15 — Forge Path Resolution Simplification
- Verbose inline parenthetical `(resolve forge path from ~/.claude/CLAUDE.md forge-path: line, fallback /root/dev/forge)` replaced with one-line `## Forge Path` section per skill
- Skills now use `<forge>/...` notation for all forge repo references
- `install.sh` writes `forge-path:` to `~/.claude/CLAUDE.md` — idempotent, updates if forge moves
- Only `/forge` SKILL.md keeps full resolution block with fallback (it's the entry point that may run before `install.sh`)

## 2026-03-15 — Unified Reforge Flow with Auto-Triggered Review
- `/reforge review` separate mode eliminated — review is now Part 2 of the unified `/reforge` flow
- Review fires automatically based on size thresholds (learnings >50 entries, memory >20 files), skipped if below
- Review runs BEFORE absorption (Part 3-4) to prune stale knowledge before piling new entries on top
- Staging archival (Part 5) also auto-triggers based on thresholds (>100 entries, >30 files)
- Principle: don't split one skill into separate modes — integrate conditional steps with auto-triggers instead
