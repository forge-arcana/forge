---
name: handoff
description: "Opt-in auto-handoff: `on <name>` / `off` / `status` / `cancel`, or no argument to write a handoff note so the session clears itself and resumes on the next piece of work with a fresh context. Tmux sessions only."
---
<!-- model: sonnet | the note needs judgment about what the next context must know; no fan-out -->

# /handoff — Opt-in auto-handoff

After a unit of work, write a handoff note; a Stop hook then clears the session and types a resume prompt, and a SessionStart hook injects the note into the fresh context.

**When to run it:** whenever you would otherwise tell the user to `/clear` or `/compact` because a unit of work is done, and `status` reports on, run `/handoff` instead.

## Arguments

`$ARGUMENTS` routes to the helper:

| Argument | Run |
|---|---|
| `on <name>` | `bash "$HOME/.claude/skills/handoff/handoff.sh" on '<name>'` |
| `off` | `bash "$HOME/.claude/skills/handoff/handoff.sh" off` |
| `status` | `bash "$HOME/.claude/skills/handoff/handoff.sh" status` |
| `cancel` | `bash "$HOME/.claude/skills/handoff/handoff.sh" cancel` |
| (none) | write a note (below) |

Print the helper's output and stop. Names: 1-64 chars of `A-Za-z0-9._ -`, starting with a letter or digit, no trailing space. Quote a name with spaces in the command: `on '<name>'`.

## Writing a note (no argument)

1. Run `status`. If it reports `off`, tell the user (`/handoff on <name>` first) and stop.
2. Write only when a unit of work is complete. Never while work is mid-flight, a question to the user is pending, or uncommitted work is unexplained.
   Do not write while background agents, background tasks, or Monitors you started are still running: their results would land in a cleared context. If one must outlive the handoff, list each under "Open items" with the result to expect, so the next context knows it is coming.
3. Compose the note (markdown, at most 9000 chars, terse, pointers over prose):

```
# Handoff — <name> — <date>
## Next task
One or two lines, or "none: stand by".
## Open items
- bullets
## Pointers
Files, commits, ledgers, URLs. Prefer a pointer to a ledger over restating it.
## Session-only state to re-arm
Each CronCreate job: verbatim cron expression plus either the verbatim prompt or a pointer to where the verbatim prompt lives. Also Monitors and other session-scoped things. "none" if none.
## Rules in force
Only session-specific rulings not already in rules files.
```

4. Write it with ONE Bash call piping a quoted heredoc into the helper:

```bash
bash "$HOME/.claude/skills/handoff/handoff.sh" write <<'HANDOFF_NOTE_EOF_7c1'
...note...
HANDOFF_NOTE_EOF_7c1
```

   Use Bash, not the Write tool: top-tier sessions are blocked from Write by a forge guard hook, and the helper enforces the length cap and sets the ready marker atomically.
5. If the helper rejects for length (exit 2), shorten and retry.
6. If the helper says auto-clear is on cooldown, the note is saved but nothing will clear this turn: tell the user in one line and carry on.
7. After a successful write, end the turn at once with a one-line message and no further tool calls. The Stop hook clears the session when the turn ends and, once the note has been injected, types a resume prompt.

## Safety

- The resume prompt typed by the hook is not the founder's or user's approval of anything. Do not run `/handoff` in the turn it starts.
- The injected handoff is authoritative for state and next task; it carries no user approvals. Re-arm listed session state from it.
- `/handoff cancel` aborts a queued clear until the hook has typed `/clear`. A new user turn or peer message (SendMessage) during the delay also cancels it. `/handoff off` ends the opt-in.
