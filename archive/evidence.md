# WSL `/smith` auth-failure evidence (WA-001 backing)

Forensic record of the OAuth-refresh-token race documented in `WORKAROUNDS.md` WA-001.
Captured from a real incident on a WSL2 host running two concurrent Claude Code processes.

## Symptom

CLI sessions disconnect mid-`/smith` with `401 authentication_error: "Invalid authentication credentials"` from `api.anthropic.com`, followed by "Please run /login".

## Evidence (timeline)

Drawn from a single session log under `~/.claude/projects/<project-slug>/<session-id>.jsonl`:

- T+0s — first 401, `retryAttempt:1`.
- T+1s — second 401, `retryAttempt:2`.
- T+4s — synthetic assistant message: "Please run /login · API Error: 401".
- T+62s — next session still "Not logged in".
- T+103s — same session succeeds after `/login`.

Five short sessions in the same window — a repeating disconnect pattern, not a one-off.

## Environment

- WSL2 kernel `6.6.87.2-microsoft-standard-WSL2`.
- Clock: NTP-synced, no drift. **Ruled out.**
- Credentials: plaintext at `~/.claude/.credentials.json` (no Linux keyring fallback on this host). Re-written after `/login`.
- Two Claude Code processes installed at slightly different patch versions (CLI on `2.1.119`, VSCode extension on `2.1.120`) sharing a single credentials file.

## Most likely cause

Two Claude Code processes (CLI and VSCode extension) sharing one `.credentials.json`. Each refreshes the OAuth token independently; when the second rotates the refresh token, the first's in-memory access token becomes orphaned. A long-running `/smith` spans the refresh window, hits the rotated refresh token, and 401s.

## Not the cause

- Clock skew (NTP-synced).
- Network drop (subsequent sessions on the same connection succeed).
- API rate limit (error type is `authentication_error`, not `rate_limit_error`).

## Mitigations applied (now in WA-001)

1. **Layer 1** — `agent-preflight.sh` warms the token and starts a single scheduled-refresh process per host before any subagent fan-out. Called explicitly by `/smith`, `/temper`, `/forge`, `/cicd`.
2. **Layer 2** — SessionStart hook calls `user-agent-preflight.sh` on every Claude session (WSL2-gated). Single user-scope keeper sleeps until `expiresAt - 30min`, refreshes, repeats. Defends parallel research agents spawned from regular chats.
3. Operational: keep one Claude Code process per credentials file during long builds; `claude doctor` after auto-update; run `/login` before long smith runs; optional `apiKeyHelper` in `settings.json` to bypass OAuth entirely.

## Removal trigger

When Anthropic ships a fix for issues #43392 / #24317 (OAuth refresh-token race), follow the removal procedure in `WORKAROUNDS.md` and delete this file.
