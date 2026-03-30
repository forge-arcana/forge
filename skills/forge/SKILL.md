---
name: forge
description: "Toggle all forge skills on/off for the current session. /forge on enables, /forge off disables. The trifecta (/cast, /mark, /fold) and /forge itself are always active."
user-invocable: true
---
<!-- model: haiku -->

# /forge — Session Toggle

Toggle all forge skills for the current session. This is session-scoped — each VS Code instance / CLI session is independent. No files written, no shared state.

**Always active regardless of toggle state:** `/cast`, `/mark`, `/fold`, `/forge`

**Everything else is controlled by the toggle:** all arts (auto-invocation AND explicit), all task skills (/wawa, /wrap, /qt, /smith, /srs, etc.)

## Arguments

`$ARGUMENTS` — `on`, `off`, or empty.

### `on`

Output exactly:

> **FORGE ENABLED** — all forge skills and art auto-invocation are active for this session.

Do not use AskUserQuestion. This is immediate.

### `off`

Output exactly:

> **FORGE DISABLED** — all forge skills are suspended for this session. Only `/cast`, `/mark`, `/fold`, and `/forge` remain active. To re-enable: `/forge on`

Do not use AskUserQuestion. This is immediate.

When forge is disabled and the user invokes a disabled skill (e.g., `/poke`, `/wawa`), respond:

> Forge is disabled for this session. Run `/forge on` to re-enable.

### Empty (no argument)

Use `AskUserQuestion`: "Enable or disable forge for this session?"
- "Enable" → output the `on` message
- "Disable" → output the `off` message
