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

**Claude Code is the one holdout.** Two issues exist for Claude users:

1. Claude Code has not yet implemented native `AGENTS.md` auto-loading
   (tracked at [anthropics/claude-code#6235](https://github.com/anthropics/claude-code/issues/6235)
   and [#34235](https://github.com/anthropics/claude-code/issues/34235)).
   Workaround: a 1-line `CLAUDE.md` containing `@AGENTS.md` uses Claude Code's
   officially documented `@-import` mechanism to load AGENTS.md content.
2. Claude Code has an OAuth token-refresh race that breaks long-running
   sub-agent skills (see `<forge>/claude-helpers/WORKAROUNDS.md` WA-001). Workaround: a
   SessionStart hook that proactively refreshes the token.

Both workarounds are **opt-in**. Run `bootstrap.sh <project>` to apply them.

## Contents

```
claude-helpers/
├── README.md             ← this file
├── bootstrap.sh          ← idempotent per-project Claude bridge
├── refs/
│   ├── auto-allowed-bash.md       ← descriptive: which Bash commands are
│   │                                  Claude-Code-default-permitted (used by
│   │                                  /forge cycle's config-sync phase)
│   └── permissions-template.json  ← reference shape for ~/.claude/settings.json
│                                     `permissions.allow` array (one-time
│                                     user-side install, not runtime)
└── scripts/
    ├── agent-preflight.sh         ← WA-001 Layer 1 entry: token warmup +
    │                                  scheduler spawn
    ├── agent-token-warmup.sh      ← WA-001: refresh OAuth token if <30 min remaining
    ├── agent-token-scheduler.sh   ← WA-001: background daemon ensuring token stays fresh
    ├── install-token-hook.sh      ← WA-001: idempotent SessionStart hook installer
    ├── user-agent-preflight.sh    ← WA-001 Layer 2: SessionStart hook target
    └── sync-workaround-side-effects.sh  ← /forge cycle helper for tracking
                                            workaround-installed artifacts
```

## Retiring this directory

Each contained file has a clear retirement criterion:

- **All scripts under `scripts/`** retire when Anthropic ships the OAuth
  refresh-token race fix (see `<forge>/claude-helpers/WORKAROUNDS.md` WA-001). At that point,
  `claude-helpers/scripts/` should be deleted entirely.
- **`bootstrap.sh`** retires when Claude Code natively reads `AGENTS.md`
  ([#6235](https://github.com/anthropics/claude-code/issues/6235) /
  [#34235](https://github.com/anthropics/claude-code/issues/34235)).
- **`refs/`** is descriptive-only and will be reviewed/cleaned during routine
  `/purge` cycles.

When all three retirement criteria have been met, the entire `claude-helpers/`
directory is deleted. Until then, this is an honest box of "things Claude needs
that no other tool needs," kept isolated from `core/`.
