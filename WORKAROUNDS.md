# Active Forge Workarounds

> Workarounds that exist because of upstream bugs. Each entry tracks the upstream issue
> so we can remove the workaround once it's fixed.
>
> **Periodic check**: every `/forge` run invokes `scripts/forge-workarounds-check.sh`.
> The actual GitHub API call is time-gated to once per 7 days per workaround.
> A status banner is always printed above the PLAN table — when an upstream issue closes,
> the banner shouts "READY FOR REMOVAL" and points at the procedure below.

---

## WA-001: Smith Token Warmup

**Workaround**: `/smith` performs proactive OAuth token refresh in preflight + via background keeper to avoid the Claude Code token-refresh race during multi-apprentice builds.

**Reason**: Concurrent claude processes (smith + apprentices) race on the OAuth refresh token. The refresh token is single-use server-side. First process to call refresh wins; the rest get `invalid_grant` from the API and crash mid-build with "auth failed".

**Affected files**:
- `scripts/smith-token-warmup.sh` — one-shot conditional refresh
- `scripts/smith-token-keeper.sh` — background loop (every 5 min during smith lifetime)
- `skills/smith/SKILL.md` — Step 0a (preflight warmup + keeper spawn) + Step 5.0 (keeper teardown) + Hard Rule 9

**Upstream issues**:
- https://github.com/anthropics/claude-code/issues/43392 (Linux, parallel agents)
- https://github.com/anthropics/claude-code/issues/24317 (macOS, multi-session)

**Removal procedure**: When ANY of the above issues is closed AND the fix is verified shipped in the current Claude Code version:

1. Remove `scripts/smith-token-warmup.sh`
2. Remove `scripts/smith-token-keeper.sh`
3. Remove the warmup section from `skills/smith/SKILL.md`:
   - Delete Step 0a (Token Warmup)
   - Delete Step 5.0 (Stop token keeper)
   - Delete Hard Rule 9 (token keeper requirement)
4. Remove this entry from `WORKAROUNDS.md`
5. Remove the corresponding entry from `learnings/smith-learnings.md` (or mark as resolved)
6. Update `CLAUDE.md` "Recent" section with the removal note
7. Run `/forge` to propagate changes through the cycle

**Added**: 2026-04-25
**Last verified active**: 2026-04-25
