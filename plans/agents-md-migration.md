---
title: Project rules move to AGENTS.md only
status: implemented 2026-10-01
owner: founder
created: 2026-10-01
touches: core/skills/forge, core/skills/{wrap,wawa,praise,smith,temper,srs}, core/scripts/cast-deploy.sh, bin/forge-build, claude-helpers, README.md, presentation, forge's own rules file
---

## Source

Conversation, 2026-10-01.

## Founder's decisions

- Project rules files are `AGENTS.md` only. No `CLAUDE.md` shim; a project-root `CLAUDE.md` must not exist.
- Forge dogfoods the change in the same pass: its own `CLAUDE.md` is renamed to `AGENTS.md`.

## Verified facts (Claude Code 2.1.284, tested 2026-10-01)

| Setup | Result |
|-------|--------|
| Project `AGENTS.md` only (user-level `~/.claude/CLAUDE.md` present) | AGENTS.md loaded natively (needs v2.1.277+) |
| Project `AGENTS.md` + project `CLAUDE.md` | Only CLAUDE.md loaded; AGENTS.md silently ignored |
| Project `CLAUDE.md` containing `@AGENTS.md` | AGENTS.md loaded via import |

Also: `/init` still writes `CLAUDE.md`; `AGENTS.local.md` and anything under `.agents/` are not read as instructions; `@path` imports expand inside a natively loaded `AGENTS.md`. Official docs carry no deprecation of `CLAUDE.md` — `AGENTS.md` is a native fallback, not a successor.

## Risk accepted with the decision

- A recreated project `CLAUDE.md` (via `/init` or a memory append) shadows `AGENTS.md` with no error.
- Collaborators below v2.1.277 lose project rules.

Mitigations built:

1. `/forge` Phase 4 rules-file state check — OK / LEGACY (`git mv CLAUDE.md AGENTS.md`) / SHADOWED (user-merged conflict) / MISSING (create) — behind a Claude Code >=2.1.277 version gate.
2. `/wrap` flags a stray project `CLAUDE.md` before commit.

## Heats

1. `core/skills/forge/{SKILL,forge-conventions,protocol}.md` + `.claude/skills/forge/SKILL.md` — Phase 4 state check, version gate, reading-art fallback convention.
2. wrap, wawa, praise, smith (+ apprentice-system), temper, srs — target `AGENTS.md`, legacy `CLAUDE.md` fallback on read.
3. `bin/forge-build` (registry emitted to `build/.agents/FORGE.md`, deployed to `<project>/.agents/FORGE.md`, so it cannot overwrite a project `AGENTS.md`), `claude-helpers/*` (`bootstrap.sh` retired), `README.md`, `presentation/index.html`.
4. Forge's own rules file `CLAUDE.md` → `AGENTS.md`, `core/scripts/{forge-purge-scan,fold-purity-check,cast-deploy}.sh` (cast-deploy: one comment), `.claude/skills/purge/SKILL.md`, this plan, and the membrane learning correction.

## Rollout

The procedure lives in `forge-conventions.md` §1, which Phase 4 reads fresh from the repo after Phase 0's pull, so it applies on a teammate's first `/forge` after this is pushed.

## Deliberately left alone

- The membrane rules file `~/.claude/CLAUDE.md` (forge-path line, FORGE-RULES block): Claude Code reads no user-level `AGENTS.md`.
- The `claude-md-and-agents-md` setting.
- `core/rules/` text.
- `core/skills/forge/preflight.md`: its only hit is the membrane rules-file definition. Not modified.
- `CONTRIBUTING.md`: its only hit is the membrane `~/.claude/CLAUDE.md`. Not modified.
- `learnings/` and `memory/` (corrections route through the membrane inbox and `/forge`).

## Review gate (/poke)

Findings fixed after review:

- Bootstrap-era layout handled as `SHIM` state plus stale-registry detection.
- Ancestor `CLAUDE.md`, `CLAUDE.local.md` and `.claude/CLAUDE.md` treated as blockers.
- `LINKED` symlink state added.
- Untracked `CLAUDE.md` uses plain `mv`, not `git mv`.
- Unknown Claude Code version fails the gate.
- `forge-build` deploy made additive (no `rm -rf` of a project's `scripts/` or `.agents/` directories); registry retitled "Skill Registry"; stale generated `AGENTS.md` warned about on deploy.
- `/wrap` and `/forge` aligned on propose-then-approve merges.
- Rules-file procedure moved into `forge-conventions.md` §1 as single source so older deployed Phase 4 text cannot act on the new convention without the blockers and gate.
