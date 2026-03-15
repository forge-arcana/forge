# Pitch & Blueprint Subdirectory

## Purpose
Contains interview frameworks and sample outputs for product ideation.

## Skills (migrated from legacy shorthand commands)
- `/pitch` — AI-guided investor pitch interview. See `~/.claude/skills/pitch/SKILL.md`
- `/bluep` — AI-guided product blueprint interview. See `~/.claude/skills/bluep/SKILL.md`

## Legacy Commands (removed)
The `upforge` and `reforge` shorthand commands previously defined here have been migrated:
- `upforge` config sync → now part of `/reforge` skill (forge project-local)
- `reforge` config pull → now handled by `/forge` skill (global)

## Sample Outputs
- `jeepi/` — Jeepi project pitch + blueprint
- `kain/` — Kain project pitch + blueprint
- `sookie/` — Sookie project pitch

## HARD RULE — No Command Chaining in Bash — EVER
> **NEVER use `&&`, `;`, or `||` to chain commands in a single Bash tool call.**
