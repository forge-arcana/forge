# claude-helpers

> **Optional. Forge core does not require these.**
> This directory is a *box of Claude Code helpers* — bootstrap glue and bug
> workarounds — explicitly NOT a vendor adapter. The vendor-adapter concept
> was rejected during the MAXIMA pivot (see `memory/maxima-pivot-plan.md`).

## Why this exists

Forge emits a single universal output: `AGENTS.md` + `.agents/skills/` per the
[Open Agent Skills specification](https://agentskills.io/) (Anthropic, December
2025; cross-tool standard since January 2026). Tools that natively read those
artifacts — OpenAI Codex CLI, Cursor, Gemini CLI, DeepSeek TUI, Bob, Amp,
Factory, etc. — work out of the box with zero forge-side configuration.

**Claude Code is the one holdout.** Claude Code has not yet implemented native
`AGENTS.md` auto-loading (tracked at
[anthropics/claude-code#6235](https://github.com/anthropics/claude-code/issues/6235)
and [#34235](https://github.com/anthropics/claude-code/issues/34235)).
Workaround: a 1-line `CLAUDE.md` containing `@AGENTS.md` uses Claude Code's
officially documented `@-import` mechanism to load AGENTS.md content.

This bridge is **opt-in**. Run `bootstrap.sh <project>` to apply it.

> A second helper used to live here — a SessionStart hook working around Claude
> Code's OAuth token-refresh race (WA-001). That upstream bug was fixed in Claude
> Code v2.1.136 (cross-process credential lock), so the workaround and all its
> scripts were retired.

## Contents

```
claude-helpers/
├── README.md             ← this file
├── bootstrap.sh          ← idempotent per-project Claude bridge
└── refs/
    ├── auto-allowed-bash.md       ← descriptive: which Bash commands are
    │                                  Claude-Code-default-permitted (used by
    │                                  /forge cycle's config-sync phase)
    └── permissions-template.json  ← reference shape for ~/.claude/settings.json
                                      `permissions.allow` array (one-time
                                      user-side install, not runtime)
```

## Retiring this directory

Each contained file has a clear retirement criterion:

- **`bootstrap.sh`** retires when Claude Code natively reads `AGENTS.md`
  ([#6235](https://github.com/anthropics/claude-code/issues/6235) /
  [#34235](https://github.com/anthropics/claude-code/issues/34235)).
- **`refs/`** is descriptive-only and will be reviewed/cleaned during routine
  `/purge` cycles.

(The `scripts/` directory and its WA-001 OAuth-race workaround were already
retired when Claude Code v2.1.136 shipped the upstream fix.)

When both remaining retirement criteria have been met, the entire
`claude-helpers/` directory is deleted. Until then, this is an honest box of
"things Claude needs that no other tool needs," kept isolated from `core/`.
