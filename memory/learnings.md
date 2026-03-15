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
- `FORGE_HOME` resolution chain: env var → `forge-home:` in CLAUDE.md → fallback `/root/dev/forge`
- `/wow` renamed to `/wawa` ("Where Are We At?")
- Sibling file sync added to `/reforge` Step 7 — ensures `~/.claude/skills/` copies match forge source
- Learning review/expiry added as `/reforge review` — prunes stale, merges duplicates, rewrites evolved entries
