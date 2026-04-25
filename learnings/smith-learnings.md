# /smith Learnings

> Accumulated learnings from smith runs (orchestration, apprentice delegation, art proficiency).
> Absorbed by the `/forge` cycle. See `<forge>/skills/forge/protocol.md` for the absorb protocol.

<!-- Add learnings below this line -->

## OAuth Token Race Workaround Required for Multi-Apprentice Builds (2026-04-26)
**Learning**: Claude Code's OAuth refresh-token rotation is not safely serialized across concurrent processes. When multiple claude processes (smith + apprentices, or any parallel sessions) hit access-token expiry simultaneously, they all attempt to refresh using the same single-use refresh token. The first wins; the rest receive `invalid_grant` from the API and crash with "auth failed". This breaks smith builds mid-run.
**Workaround**: Smith preflight runs an explicit token warmup that refreshes when <30 min remaining, then spawns a background keeper that loops every 5 min for the smith lifetime. New apprentices always inherit fresh tokens; no apprentice ever needs to refresh during its lifetime (assuming individual apprentice lifespans stay <60 min, which is already smith's design).
**Apply when**: Any workflow that spawns concurrent claude processes. The pattern generalizes — proactive refresh from a single point eliminates the race for newly-spawned children. The workaround is tracked in `WORKAROUNDS.md` (WA-001) with upstream issue links and a removal procedure for when Anthropic ships a fix.
**Forge-worthy**: yes — applies to any multi-process Claude Code use case, not just smith.
