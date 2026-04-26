# Active Forge Workarounds

> Workarounds that exist because of upstream bugs. Each entry tracks the upstream issue
> so we can remove the workaround once it's fixed.
>
> **Periodic check**: every `/forge` run invokes `scripts/forge-workarounds-check.sh`.
> The actual GitHub API call is time-gated to once per 7 days per workaround.
> A status banner is always printed above the PLAN table — when an upstream issue closes,
> the banner shouts "READY FOR REMOVAL" and points at the procedure below.

---

## WA-001: Subagent-Spawning Workflow OAuth Token Warmup

**Workaround**: Any forge skill that spawns subagents (or runs in parallel with other claude sessions) calls a universal token-preflight helper that refreshes the OAuth token if <30 min remain and spawns a single background keeper for the session. Newly-spawned subagents inherit fresh tokens, so they don't all race on refresh and crash with `invalid_grant`.

**Reason**: Concurrent claude processes race on the OAuth refresh token. The refresh token is single-use server-side. First process to call refresh wins; the rest get `invalid_grant` from the API and crash with "auth failed". This breaks every multi-process Claude Code workflow — not just smith. Confirmed in the wild: `/smith` builds, `/temper` evaluations.

**Affected files**:
- `scripts/agent-token-warmup.sh` — one-shot conditional refresh
- `scripts/agent-token-keeper.sh` — background loop (every 5 min during caller's lifetime)
- `scripts/agent-preflight.sh` — universal one-line entry point (warmup + idempotent keeper spawn)
- `skills/forge/protocol.md` — Pre-Flight step 0 (covers all 10 arts automatically: prime, probe, poke, preen, press, pound, pitch, pry, purge, praise)
- `skills/smith/SKILL.md` — Step 0a (master builder)
- `skills/purge/SKILL.md` — covered via protocol (Warden tends the forge)
- `skills/temper/SKILL.md` — Step 0
- `skills/forge/SKILL.md` — Phase 0 (cycle's own subagent fan-out in 3f)
- `skills/cicd/SKILL.md` — Step 1 (escalates to /pry which spawns subagents)

**Upstream issues**:
- https://github.com/anthropics/claude-code/issues/43392 (Linux, parallel agents)
- https://github.com/anthropics/claude-code/issues/24317 (macOS, multi-session)

**Removal procedure**: When ANY of the above issues is closed AND the fix is verified shipped in the current Claude Code version:

1. Remove `scripts/agent-token-warmup.sh`
2. Remove `scripts/agent-token-keeper.sh`
3. Remove `scripts/agent-preflight.sh`
4. Remove the Pre-Flight step 0 (Token preflight) block from `skills/forge/protocol.md` — this single removal covers all 10 arts.
5. Remove the one-line preflight call from each non-art SKILL.md:
   - `skills/smith/SKILL.md` Step 0a
   - `skills/temper/SKILL.md` Step 0.0
   - `skills/forge/SKILL.md` Phase 0.0
   - `skills/cicd/SKILL.md` Step 1.0
6. Remove smith Hard Rule 9
7. Remove this entry from `WORKAROUNDS.md`
8. Remove the corresponding entry from `learnings/global-patterns.md` (or mark as resolved)
9. Update `CLAUDE.md` "Recent" section with the removal note
10. Run `/forge` to propagate changes through the cycle

**Added**: 2026-04-25
**Last verified active**: 2026-04-25
