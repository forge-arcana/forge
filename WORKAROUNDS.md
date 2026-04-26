# Active Forge Workarounds

> Workarounds that exist because of upstream bugs. Each entry tracks the upstream issue
> so we can remove the workaround once it's fixed.
>
> **Periodic check**: every `/forge` run invokes `scripts/forge-workarounds-check.sh`.
> The actual GitHub API call is time-gated to once per 7 days per workaround.
> A status banner is always printed above the PLAN table — when an upstream issue closes,
> the banner shouts "READY FOR REMOVAL" and points at the procedure below.
>
> **Side-effect management**: each workaround declares a `Side effects` block listing
> the artifacts (scripts, hooks, etc.) it owns. The `/forge` cycle reads these blocks
> via `scripts/sync-workaround-side-effects.sh` and surfaces install/uninstall rows
> in the PLAN table. Per-row approval applies, same as every other deployable.

---

## WA-001: Subagent-Spawning Workflow OAuth Token Warmup

**Workaround**: Two layers of proactive OAuth token refresh prevent Claude Code's documented refresh-token race from breaking concurrent multi-process workflows. Newly-spawned subagents always inherit a fresh token, so they don't all race to refresh the same single-use refresh token.

- **Layer 1 — Forge-internal preflight**: every subagent-spawning forge skill (smith, temper, pound, all 10 arts via `skills/forge/protocol.md` Pre-Flight step 0) calls `scripts/agent-preflight.sh $$` before fan-out. Spawns a `--parent`-mode scheduler scoped to the skill's lifetime.
- **Layer 2 — User-level scheduled refresher (WSL2 only)**: a SessionStart hook calls `~/.claude/scripts/user-agent-preflight.sh` on every Claude session start. Spawns a `--user`-mode scheduler that lives until the WSL VM shuts down. Refreshes the token on schedule (read `expiresAt`, sleep until `expiresAt - 30min`, refresh, repeat). Protects every Claude session — forge or not, parallel research agents or single chat.

Both layers share the unified `scripts/agent-token-scheduler.sh` implementation; they differ only in lifecycle (full sleep vs chunked-with-parent-watch). The Layer 1 scheduler short-circuits at startup if Layer 2 is already active (no redundant refresh work).

**Reason**: Concurrent claude processes race on the OAuth refresh token. The refresh token is single-use server-side. First process to call refresh wins; the rest get `invalid_grant` from the API and crash with "auth failed". This breaks every multi-process Claude Code workflow — confirmed in the wild: `/smith` builds, `/temper` evaluations, parallel research-agent fan-outs from regular chats.

**Side effects** (managed by /forge cycle — apply on cast, remove on retirement):
- script: scripts/agent-token-warmup.sh → ~/.claude/scripts/
- script: scripts/agent-token-scheduler.sh → ~/.claude/scripts/
- script: scripts/user-agent-preflight.sh → ~/.claude/scripts/
- hook: SessionStart → "$HOME/.claude/scripts/user-agent-preflight.sh"  (platform: WSL2)

**Affected files** (tracked in forge):
- `scripts/agent-token-warmup.sh` — single refresh action, flock-serialized; called by both schedulers
- `scripts/agent-token-scheduler.sh` — unified scheduled-refresh loop, two modes (`--user`, `--parent`)
- `scripts/agent-preflight.sh` — Layer 1 entry point (skills call it)
- `scripts/user-agent-preflight.sh` — Layer 2 entry point (SessionStart hook calls it)
- `scripts/install-token-hook.sh` — idempotent installer for the SessionStart hook (with `--uninstall`)
- `scripts/sync-workaround-side-effects.sh` — parses this file's Side effects blocks for /forge
- `skills/forge/protocol.md` — Pre-Flight step 0 (Layer 1 — covers all 10 arts automatically)
- `skills/smith/SKILL.md` — Step 0a (master builder)
- `skills/purge/SKILL.md` — covered via protocol (the Warden tends the forge)
- `skills/temper/SKILL.md` — Step 0
- `skills/forge/SKILL.md` — Phase 0 (cycle's own subagent fan-out in 3f)
- `skills/cicd/SKILL.md` — Step 1 (escalates to /pry which spawns subagents)

**Failure recovery**: the warmup tracks consecutive refresh failures in `~/.claude/.token-fail-count`. After 3 consecutive failures, it writes `~/.claude/.token-stale` as a sentinel. Every preflight (Layer 1 or Layer 2) reads this sentinel at startup and prints a loud warning to stderr if present:

> **OAuth refresh has failed N times. Run `claude` from a terminal to re-authenticate before continuing.**

Without this, a real auth failure (network down, refresh token genuinely beyond grace) would silently mask itself until the user hits `invalid_grant` mid-conversation.

**Upstream issues**:
- https://github.com/anthropics/claude-code/issues/43392 (Linux, parallel agents)
- https://github.com/anthropics/claude-code/issues/24317 (macOS, multi-session)

**Upstream fix detection — TWO possible fix shapes**:
- **Client-side fix**: Claude Code serializes refresh-token rotation. Issues close as "fixed" → `forge-workarounds-check.sh` detects and surfaces the removal banner automatically.
- **Server-side fix**: API allows brief grace window for rotated refresh tokens, or implements refresh-token chains. Issues might be marked "won't fix — addressed differently" or never close at all. Current `forge-workarounds-check.sh` would NOT detect this.

Future work: extend the check to also detect server-side fixes by analyzing `~/.claude/.smith-token.log` for `invalid_grant` frequency under heavy concurrent usage. If we go N days with zero failures despite known race-prone usage patterns, the workaround may be retiring itself organically.

**Removal procedure** — when an upstream issue closes AND the fix is verified shipped in current Claude Code version:

1. Remove all entries from the **Side effects** block above. Run `/forge` — the cycle will surface uninstall rows for each (script delete, hook uninstall) and apply on user approval.
2. Remove the script files from forge: `scripts/agent-token-warmup.sh`, `scripts/agent-token-scheduler.sh`, `scripts/agent-preflight.sh`, `scripts/user-agent-preflight.sh`, `scripts/install-token-hook.sh`, `scripts/sync-workaround-side-effects.sh`.
3. Remove Pre-Flight step 0 from `skills/forge/protocol.md` — single removal covers all 10 arts.
4. Remove the per-skill preflight calls:
   - `skills/smith/SKILL.md` Step 0a
   - `skills/temper/SKILL.md` Step 0.0
   - `skills/forge/SKILL.md` Phase 0.0
   - `skills/cicd/SKILL.md` Step 1.0
5. Remove smith Hard Rule 9.
6. Remove this entry (WA-001) from `WORKAROUNDS.md`.
7. Remove the OAuth-refresh entry from `learnings/global-patterns.md` (or mark as resolved).
8. Update `CLAUDE.md` "Recent" with the removal note.
9. Run `/forge` to propagate changes through the cycle.

**Added**: 2026-04-25
**Last verified active**: 2026-04-26
