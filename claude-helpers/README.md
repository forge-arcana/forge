# claude-helpers

> **Optional. Forge core does not require these.**
> This directory is a *box of Claude Code helpers* — reference docs and
> one-shot migration glue — explicitly NOT a vendor adapter. The vendor-adapter
> concept was rejected during the MAXIMA pivot (see `archive/maxima-pivot-plan.md`).

## Why this exists

Forge emits a single universal output: `.agents/FORGE.md` (skill registry) +
`.agents/skills/` per the [Open Agent Skills specification](https://agentskills.io/)
(Anthropic, December 2025; cross-tool standard since January 2026). Project
rules live in the project's own `AGENTS.md`, which every major agent — Claude
Code included — reads natively.

Native `AGENTS.md` loading shipped in Claude Code v2.1.277, so `bootstrap.sh`
(the 1-line `CLAUDE.md` `@AGENTS.md` bridge) was retired. One caveat matters: a
project-root `CLAUDE.md` shadows `AGENTS.md` (with both present, only
`CLAUDE.md` loads). Forge projects therefore carry no project `CLAUDE.md` —
`/forge` Phase 4 migrates one and `/wrap` flags a stray one.

> An earlier helper here — a SessionStart hook working around Claude Code's
> OAuth token-refresh race (WA-001) — was retired when Claude Code v2.1.136
> shipped the upstream fix.

## Contents

```
claude-helpers/
├── README.md             ← this file
├── retire-wa001.sh       ← transient: cleans leftover WA-001 hook wiring from
│                            membranes (invoked by the /forge Phase 2 cast)
└── refs/
    ├── auto-allowed-bash.md       ← descriptive: which Bash commands are
    │                                  Claude-Code-default-permitted (used by
    │                                  /forge cycle's config-sync phase)
    └── permissions-template.json  ← reference shape for ~/.claude/settings.json
                                      `permissions.allow` array (one-time
                                      user-side install, not runtime)
```

## Retiring this directory

- **`retire-wa001.sh`** is throwaway migration code; delete it (and its
  invocation in the `/forge` cast step) once every membrane has run `/forge`
  after 2026-06-13.
- **`refs/`** is descriptive-only and is reviewed/cleaned during routine
  `/purge` cycles.

When both are gone, the entire `claude-helpers/` directory is deleted.
