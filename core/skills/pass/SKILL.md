---
name: pass
description: "Pass: with no argument, write a pass note so the session clears itself and resumes on the next piece of work with a fresh context (works anytime in tmux). Auto-pass is on by default in tmux; `manual` opts this session name out, `auto` opts back in, `status` / `cancel` as named. The session name comes from its /rename title. Works in tmux; a background-job session is moved into tmux by an explicit /pass, or by a model-initiated one when a tmux window named after the session holds its leftover view."
---
<!-- model: sonnet | the note needs judgment about what the next context must know; no fan-out -->

# /pass — Pass and auto-pass

Auto-pass is ON by default in tmux. An explicit `/pass` works anytime; model-initiated passes follow `status`. `/pass manual` opts this session name out persistently (it survives restarts and `--resume`); `/pass auto` removes the opt-out. After a unit of work, write a pass note; a Stop hook then clears the session and types a resume prompt, and a SessionStart hook injects the note into the fresh context.

**When to run it:** whenever you would otherwise tell the user to `/clear` or `/compact` because a unit of work is done, and `status` reports auto, run `/pass` instead.

## Arguments

`$ARGUMENTS` routes to the helper:

| Argument | Run |
|---|---|
| `auto [name]` | removes the opt-out for the name, then opts in: `bash "$HOME/.claude/skills/pass/pass.sh" auto` (name optional: derived from the session's /rename title, else the tmux window name, else the tmux session name; pass `'<name>'` only to override) |
| `manual` | opts this session name out, persistently: `bash "$HOME/.claude/skills/pass/pass.sh" manual` |
| `status` | `bash "$HOME/.claude/skills/pass/pass.sh" status` |
| `cancel` | `bash "$HOME/.claude/skills/pass/pass.sh" cancel` |
| (none) | write a note (below) |

Print the helper's output and stop. Names: 1-64 chars of `A-Za-z0-9._ -`, starting with a letter or digit, no trailing space. Quote a name with spaces in the command: `auto '<name>'`.

The opt-out follows the session name: after /rename, run /pass manual again.

Status semantics: `auto ...` with exit 0 means auto-pass applies (the default; `auto name=<n> relocate=<pane>` is a background-job session whose leftover view sits in a window named after it); `manual ...` means opted out, not in tmux, or a background job with no such window.

## Writing a note (no argument)

1. Run `status`. Write with no name arg: the helper derives the name. Pass a name only if the user asked for a specific one. If the USER typed `/pass`, use `write --explicit` (it skips the minimum-context gate); a model-initiated pass uses plain `write`; in an opted-out session it only saves the note (no clear), and the helper and hook skip it (note kept, no clear, and the helper says so) when context is under ~90k tokens (`PASS_MIN_CONTEXT`).
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
bash "$HOME/.claude/skills/pass/pass.sh" write [--explicit] <<'PASS_NOTE_EOF_7c1'
...note...
PASS_NOTE_EOF_7c1
```

   A write with no opt-out behaves like `auto`; in an opted-out session it creates a one-shot opt-in that lasts for this Claude process (status stays manual).

   Use Bash, not the Write tool: top-tier sessions are blocked from Write by a forge guard hook, and the helper enforces the length cap and sets the ready marker atomically.
5. If the helper rejects for length (exit 2), shorten and retry. If it rejects with exit 4 because the note lacks a line that is exactly `## Done last session`, add the section and retry.
6. If the helper says auto-clear is on cooldown, the note is saved but nothing will clear this turn: tell the user in one line and carry on.
7. Background-job session (no tmux pane): a reply "this session runs as a background job; note saved ... reopened in tmux window" means the move is queued: end the turn at once exactly as in step 8. When the turn ends the background job is STOPPED and anything it still runs in the background (shells, monitors, tasks) ends with it; so write only after that work is done or listed under "Open items". The conversation reopens in tmux window `<name>`, is cleared and resumed from the note. If the move fails after the stop, pass.log and `relocate/<id>.failed` hold the recovery line (`cd <folder>`, then `claude --resume <id>`), the user is notified when a notifier is set, and the reopened pane shows it. `/pass cancel` only works before the turn ends. The reopened session keeps the model and permission mode found in the conversation record (an unrecorded or bypass mode becomes manual); other launch flags are not carried over. A reply "note saved, not moving it" (or "not clearing") means nothing will clear: tell the user in one line and carry on, do not end the turn. A refusal with a reason (exit 1, e.g. a tmux window of that name that is not this session's view) goes to the user in one line, then carry on.
8. After a successful write, end the turn at once with a one-line message and no further tool calls. The Stop hook clears the session when the turn ends and, once the note has been injected, types a resume prompt.

## Safety

- The resume prompt typed by the hook (`[auto-pass]`) is not the founder's or user's approval of anything. Do not run `/pass` in the turn it starts.
- The injected pass note is authoritative for state and next task; it carries no user approvals. Re-arm listed session state from it.
- A one-shot pass (explicit `/pass` in an opted-out session) never turns auto-pass back on: `status` still reports manual, so do not run `/pass` on your own initiative.
- `/pass cancel` aborts a queued clear until the hook has typed `/clear` (for a background job, only before the turn ends). A new user turn or peer message (SendMessage) during the ~25 s delay also cancels it. `/pass manual` opts the session out.
