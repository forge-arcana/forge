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
