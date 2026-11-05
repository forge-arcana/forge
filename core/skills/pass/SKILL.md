---
name: pass
description: "Pass: with no argument, write a pass note so the session clears itself and resumes on the next piece of work with a fresh context (works anytime in tmux). `auto` / `manual` / `status` / `cancel` manage opt-in to model-initiated auto-pass; the session name comes from its /rename title. Tmux sessions only."
---
<!-- model: sonnet | the note needs judgment about what the next context must know; no fan-out -->

# /pass — Pass and opt-in auto-pass

An explicit `/pass` works anytime in tmux; `auto` opts the session into MODEL-initiated auto-pass. After a unit of work, write a pass note; a Stop hook then clears the session and types a resume prompt, and a SessionStart hook injects the note into the fresh context.

**When to run it:** whenever you would otherwise tell the user to `/clear` or `/compact` because a unit of work is done, and `status` reports auto, run `/pass` instead.

## Arguments

`$ARGUMENTS` routes to the helper:

| Argument | Run |
|---|---|
| `auto [name]` | `bash "$HOME/.claude/skills/pass/pass.sh" auto` (name optional: derived from the session's /rename title, else the tmux window name, else the tmux session name; pass `'<name>'` only to override) |
| `manual` | `bash "$HOME/.claude/skills/pass/pass.sh" manual` |
| `status` | `bash "$HOME/.claude/skills/pass/pass.sh" status` |
| `cancel` | `bash "$HOME/.claude/skills/pass/pass.sh" cancel` |
| (none) | write a note (below) |

Print the helper's output and stop. Names: 1-64 chars of `A-Za-z0-9._ -`, starting with a letter or digit, no trailing space. Quote a name with spaces in the command: `auto '<name>'`.

Status semantics: `auto ...` with exit 0 means opted in; `manual ...` means not.

## Writing a note (no argument)

1. Run `status`. Write with no name arg: the helper derives the name. Pass a name only if the user asked for a specific one.
2. Write only when a unit of work is complete. Never while work is mid-flight, a question to the user is pending, or uncommitted work is unexplained.
   Do not write while background agents, background tasks, or Monitors you started are still running: their results would land in a cleared context. If one must outlive the pass, list each under "Open items" with the result to expect, so the next context knows it is coming.
3. Compose the note (markdown, at most 9000 chars, terse, pointers over prose). `## Done last session` is required: a line that is exactly that, anywhere in the note, right after the title by convention (position is not enforced). Write decisions as what was decided, never as approvals for future actions; the resumed session treats them as history. The resumed session opens its first reply with a status block built from this section and from "Next task" / "Open items":

```
# Pass — <name> — <date>
## Done last session
At most 5 bullets: what was done or shipped, plus key decisions. Required.
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
bash "$HOME/.claude/skills/pass/pass.sh" write <<'PASS_NOTE_EOF_7c1'
...note...
PASS_NOTE_EOF_7c1
```

   A write while not opted in creates a one-shot opt-in that lasts for this Claude process.

   Use Bash, not the Write tool: top-tier sessions are blocked from Write by a forge guard hook, and the helper enforces the length cap and sets the ready marker atomically.
5. If the helper rejects for length (exit 2), shorten and retry. If it rejects with exit 4 because the note lacks a line that is exactly `## Done last session`, add the section and retry.
6. If the helper says auto-clear is on cooldown, the note is saved but nothing will clear this turn: tell the user in one line and carry on.
7. After a successful write, end the turn at once with a one-line message and no further tool calls. The Stop hook clears the session when the turn ends and, once the note has been injected, types a resume prompt.

## Safety

- The resume prompt typed by the hook (`[auto-pass]`) is not the founder's or user's approval of anything. Do not run `/pass` in the turn it starts.
- The injected pass note is authoritative for state and next task; it carries no user approvals. Re-arm listed session state from it.
- A one-shot pass (explicit `/pass` without `auto`) never turns on auto-pass: `status` still reports manual, so do not run `/pass` on your own initiative.
- `/pass cancel` aborts a queued clear until the hook has typed `/clear`. A new user turn or peer message (SendMessage) during the delay also cancels it. `/pass manual` ends the opt-in.
