# core/hooks/

Tool-neutral bodies of forge's hooks: the tier work-router pair and the
opt-in auto-pass pair.

## Tier pair

Enforces the delegation doctrine in `core/skills/forge/protocol.md` Model
Tiers rules 5-7: a top-tier session plans and delegates, never holds the
implementation artifact.

- `tier-routing.sh` — `UserPromptSubmit` hook. Detects the running model from
  the transcript tail; on a top-tier model (fable/mythos/opus) it injects a
  plan-and-delegate rubric as additional context. On a haiku model it injects
  a one-line label (cheap tier, writes allowed, no delegation required). Silent
  (fails open) on any other model or when the model can't be determined.
- `tier-guard.sh` — `PreToolUse` hook, matcher `Edit|Write|NotebookEdit|Agent`.
  Structurally enforces the rubric with two gates. The **write gate** denies
  direct writes when the session is top-tier. The **spawn gate** denies an
  `Agent` spawn that carries no explicit `model` parameter — rule 5-7 says a
  tier binds *only* via that parameter, so a parameterless spawn silently
  inherits the parent's top tier and runs grep-shaped work on the most
  expensive model in the fleet. Subagent calls are always allowed on both
  gates (detected via the payload's `agent_id`) so delegated work goes
  through. Spawn-gate exemptions that need no parameter: `subagent_type:
  fork` (inherits by design; the harness ignores a model parameter there) and
  any agent whose `.claude/agents/<name>.md` frontmatter already pins a
  `model:`. Separate escape hatches — `FORGE_ALLOW_INLINE_EDITS` disarms only
  the write gate, `FORGE_ALLOW_UNTRIAGED_SPAWN` only the spawn gate; wanting
  to hand-edit a file is not the same as wanting untriaged spawns. Fails open
  on any uncertain path — never blocks a cheap-tier session.

**Known blind spot, both hooks**: the running model is read from the
transcript tail, and on a session's *first* prompt the transcript may carry
no `.message.model` line yet. Both hooks fail open there — and first prompts
are exactly when large investigation fan-outs happen. No sturdier model
signal is exposed to a hook payload today.

## Pass pair (opt-in, tmux only)

Lets a long-running tmux session clear its own context at a clean boundary
without losing the thread. A session opts in to model-initiated pass with `/pass auto` (name derived from the /rename title); an explicit `/pass` also works without it (`write` creates a one-shot opt-in, `oneshot=1`, that `status` reports as off); when
a unit of work is complete the model runs `/pass`, which writes a note to
`~/.claude/passes/pane-<N>.md` (N = the tmux pane id) plus a ready marker.
The note must contain a line that is exactly `## Done last session` (what was
done or shipped, plus key decisions, at most about 5 bullets; trailing
whitespace on the heading is accepted). It may appear anywhere in the note,
right after the title by convention; position is not enforced. Decisions are
written as what was decided, never as approvals for future actions. `pass.sh write` rejects a note without it (exit 4, no note, no ready
marker, no opt-in created). Old notes and archives without it still inject.
The note is written via the skill's `pass.sh` helper through Bash, not the
Write tool, because `tier-guard.sh` denies Write on top-tier sessions.

- `pass-stop.sh` — `Stop` hook, no matcher. At turn end, if a ready marker
  exists, it schedules a detached job that types `/clear <name>` into the
  pane via tmux and, once the note is injected and the pane idle, `/rename
  <name>` and then a resume prompt. `/rename` is needed because Claude Code
  titles a cleared session from its first prompt and `/clear`'s argument does
  not set the title.
- `pass-start.sh` — `SessionStart` hook, matcher `clear`. Injects the note
  as context, archives it to
  `~/.claude/passes/archive/<name>-pane-<N>-<YYYYmmdd-HHMMSS>.md` (spaces
  in the name become `_`). Archives: newest 20 per pane, and any archive
  older than 30 days is deleted whatever its pane (judged by the timestamp in
  the file name; only names matching the archive pattern are touched). Then it
  writes an
  `injected` marker. Its preamble also tells the model to open its first reply
  with a short status block ("Last session" from `## Done last session`,
  "Next" from `## Next task` and `## Open items`), whether the first turn is the
  hook's resume prompt or one the user typed; a note without the section gets a
  one-line "no such section" instead. The hook never requires the section.

Hook payloads carry no session name, so state is keyed by the tmux pane
(`$TMUX_PANE`), bound to the pane's pid and to the Claude Code process. The
name is used only in the typed `/clear <name>` and in logs. Guards, each of
which fails safe (log, drop the token, type nothing):

- **tmux only**: no `$TMUX_PANE`, no action. Not opted in: silent, no state
  written.
- **Process binding**: `on` records the pane pid and the pid of the Claude
  Code process above the helper (nearest ancestor whose `comm` is `claude`,
  or `node` with `claude` in its args). The opt-in is valid only while the
  pane pid matches, that Claude is alive, and it is the Claude above the hook.
  A new Claude in the same shell, or a reused pane id, starts opted out.
  Before every keystroke the job re-checks that Claude is alive, that
  `#{pane_current_command}` is `claude` (or `node`), and that the pane is not
  in copy mode (`#{pane_in_mode}` 0).
- **Ready marker with TTL**: nothing happens unless `/pass` wrote one, and
  a marker older than `PASS_READY_TTL` is dropped.
- **Loop guard**: if this pane was auto-cleared less than
  `PASS_MIN_INTERVAL` ago, `pass.sh write` still saves the note but sets
  no ready marker and prints `auto-clear is on cooldown for <s>s … nothing
  will clear this turn`; the Stop hook refuses to schedule in that window too.
  The resume prompt also tells the model not to run `/pass` in that turn.
- **Transcript quiet check (authoritative, allowlist)**: the job records the
  transcript's size and the time the Stop hook started. Right before typing
  `/clear` it reads the bytes appended since then once, drops a trailing
  partial line from that same buffer, and ignores only:
  - types `last-prompt`, `custom-title`, `agent-name`, `mode`,
    `permission-mode`, `atis-latch`, `cost-state`, `bridge-session`,
    `tools-used`, `ai-title`, `artifact-autoreact-ledger`, `frame-link`,
    `artifact-comment-monitor`, and `system` (any subtype);
  - a waiver for any complete line with no timestamp (neither `.timestamp`
    nor `.snapshot.timestamp`) whose type is a lower-case string (`^[a-z][a-z-]*$`) that is not an
    activity type (`user`, `assistant`, `attachment`, `queue-operation`,
    `progress`, `summary`, `system`, `tool_result`, `file-history-*`,
    `api-request*`), and which has no `timestamp` key at all (`"timestamp":null`
    counts as timestamped): unknown untimestamped types are
    session metadata. Typeless, non-string-typed and oddly-cased types are
    never waived. `attachment`, `queue-operation`, `progress`,
    `file-history-*` and `api-request*` are activity even when untimestamped.
    The explicit list stays load-bearing for TIMESTAMPED metadata such as
    `system` and `mode`. The same rules
    apply to the post-clear resume guard, so session metadata written at the
    top of a new transcript (Remote Control, artifact watches, tools-used)
    does not read as user activity. `user` and `assistant` lines are never
    waived through this way (an untimestamped `user` line is activity).
  - `assistant` lines timestamped no later than the Stop start + 2 s (the
    turn's own final message).

  Every other line is activity and aborts: `user`, `attachment`,
  `queue-operation`, `progress`, `api-request*`, `file-history-snapshot`,
  any unknown type, a later assistant line, an unparseable complete line, or a
  shrunk or missing file. Calibrated on live transcripts: after Stop only
  the ignored types appear, and the final assistant line precedes
  `stop_hook_summary` by 29–256 ms.
- **Last-box screen check (secondary)**: the input box must be the last box
  on screen: a `─` border, an empty `❯` line, a `─` border, then only footer
  lines. It is busy if `esc to interrupt` appears in the footer or in the 3
  lines directly above the top border, where the spinner renders. Text in
  the input box, placeholder text, or a multi-line input aborts. Before
  `/clear` it is checked `PASS_POLL_TRIES` times, 1 s apart, with no
  longer wait.
- **Cancel**: `/pass cancel` or `/pass manual` deletes the ready marker and the
  clearing token. The job checks the token before each step, so cancel
  works until `/clear` is typed. The token carries a per-job id; a job whose
  id no longer matches (cancel, then a fresh `/pass`) exits without
  touching the newer token, so only one clear happens.
- **Fresh token**: the start hook injects only if this pane's clearing token
  is younger than `PASS_TOKEN_TTL` and names the same Claude pid, so a
  manual `/clear` never loads an old note.
- **Injected marker**: the resume prompt is typed only if the start hook
  printed its context and wrote `state/pane-<N>.injected`. If the note
  vanished during the delay, `/clear` still happens but no resume prompt is
  typed.
- **Resume guard**: the injected marker records the new transcript's path and
  size. Before typing the resume prompt the job applies the same quiet check
  to it; `user`, `attachment` and `file-history-snapshot` lines timestamped
  within 2 s of the injection are the clear's own and are ignored (Claude
  Code creates the new transcript only after SessionStart returns, then
  flushes them). A `user` line carrying `promptId`, `promptSource` or
  `turnOrigin` is a real prompt and is activity whatever its timestamp; any
  `assistant` line is activity. Activity logs
  `resume skipped: transcript activity: <type> line <N>` (with ` no-ts` when
  the line has no timestamp; the pre-clear abort logs the same detail) and nothing is typed. The guard runs
  before `/rename`, so its own transcript lines never count as activity;
  after `/rename` the pane must be idle again (up to ~5 checks) before the
  resume prompt, else `not idle after /rename` and nothing more is typed.
- **Verified typing**: only a regex-checked name (in `/clear` and `/rename`)
  or the fixed resume prompt is typed, with `send-keys -l` (literal). Verify before Enter: 0.3 s later
  the last input box must hold exactly that text (`❯` + space/NBSP + text;
  a wrapped prompt is compared joined across its lines, whitespace
  removed), or Enter is not sent and the text is left as is (nothing is
  erased; the log says `input box does not hold exactly the typed text`).
  Verify after Enter: the box must be empty again within 2.5 s, or the log
  says `Enter swallowed or not submitted` and the job stops. `lastclear` is
  written only once `/clear` is confirmed submitted.
- **Fully detached**: the job runs under `setsid -f` after a delay, so the
  turn is never held open. If `setsid` fails, the token is removed.
- **Fails open**: any error exits 0 silently; the session is never blocked.

Log: `~/.claude/passes/state/pass.log` (`date +%FT%T%z` timestamps).
Env overrides (all three scripts read what applies):

| Var | Default | Meaning |
|---|---|---|
| `PASS_DIR` | `~/.claude/passes` | state root |
| `PASS_TMUX` | `tmux` | tmux command, word-split (tests use `tmux -L <sock>`) |
| `PASS_DELAY` | `3` | seconds after turn end before the first check |
| `PASS_POLL_TRIES` | `4` | idle checks before `/clear`, 1 s apart |
| `PASS_TOKEN_TTL` | `180` | seconds a clearing token stays valid for the start hook |
| `PASS_READY_TTL` | `900` | seconds a ready marker stays valid for the Stop hook |
| `PASS_MIN_INTERVAL` | `600` | minimum seconds between auto-clears of one pane |

### Migration from /handoff (2026-11-02)

- The first run of the helper or either hook (with `PASS_DIR` unset) moves a real `~/.claude/handoffs` to `~/.claude/passes` and leaves `handoffs` as a symlink, so old detached jobs and the old helper keep working.
- State-file names are unchanged, so opted-in sessions carry over.
- Done (2026-11-05): the cast strips any retired `handoff-*` entry from `settings.json` (`FORGE_HOOK_RETIRED`) and then unlinks the leftover `handoff-stop.sh` and `handoff-start.sh` bodies from `<membrane>/hooks/` (`rm -f`, never an overwrite), with one `RETIRED` row per body removed. `--verify-hooks` reports a body still on disk as a non-fatal `RETIRED-BODY` warning (the next `--hooks` removes it) and a still-wired entry as `RETIRED-WIRED` (an error).
- Done (2026-11-05): the `handoff` alias skill is deleted from forge, and `cast-deploy.sh` removes it from `<membrane>/skills` and `~/.agents/skills` (`FORGE_SKILL_RETIRED`, `--retire-skills`, also run by `--all`) only when the dir holds exactly the shipped files unmodified; a modified dir is kept and reported as `RETIRED-SKILL-KEPT`.
- Done (2026-11-05): the `on` / `off` aliases of `auto` / `manual` are removed from `pass.sh`; they now print the usage error (exit 64).

After `/clear` the job waits up to ~20 s for the injected marker and an idle
pane before typing the resume prompt.

Limitations: tmux only; a Remote Control or desktop session gets nothing.
Typing in the input box during the delay leaves text in the box, so the
screen check aborts; typing during the 0.3 s verify gap makes the box
mismatch, so Enter is not sent and the mixed text stays for the user to
fix; submitting a prompt or any other new turn appends a non-allowlisted
line, so the transcript check aborts. Placeholder or suggestion text in
the input box blocks the clear unless it is dim (SGR 2, Claude Code's grey
suggested prompt), which is read as empty; colour alone is never ignored. The
resume guard's 2 s grace covers only the clear's own lines (no `promptId`);
it relies on Claude Code keeping that field on real prompts.

Verified against Claude Code 2.1.302. The screen check (prompt box rendering, `esc to interrupt` footer) and the transcript line types depend on the CLI version; after an upgrade, a rendering change makes the hook abort (safe, but silent apart from pass.log) — re-run a live check.

Test the screen reading (dim suggestion vs typed text, spinner, `BOX_RAW`) with `bash core/hooks/tests/test-pass-stop.sh`. It runs on a private `tmux -L` server and sources the hook with `PASS_SOURCE_ONLY=1`; it exits non-zero on any failure. Tests live in `core/hooks/tests/`, not beside the hooks, so cast-deploy's `core/hooks/*.sh` glob does not install them.

The transcript check (`test-pass-quiet.sh`), the start hook's status-block instruction (`test-pass-start.sh`) and the `write` section check (`test-pass-write.sh`) have their own tests there; they need no tmux and use temp dirs and fake transcripts. The rename added `test-pass-name.sh` (name derivation), `test-pass-cmds.sh` (`auto`/`manual`/`on`/`off` commands), `test-pass-migrate.sh` (legacy root migration) and `test-pass-cast.sh` (cast retirement of the old hook entries).

## Install

`cast-deploy.sh --hooks` copies every script verbatim into `<membrane>/hooks/`
(creating the directory if missing), preserves the executable bit, and wires
them into `settings.json` (see below). `cast-deploy.sh --verify-hooks` checks
both halves — bodies *and* registration — and exits non-zero if either is
wrong.

## settings.json wiring is forge-managed (narrowly)

`cast-deploy.sh --hooks` installs the bodies **and** wires them, via an
idempotent `jq` merge of forge's own entries into the membrane's
`settings.json`.

This reverses the earlier "forge never writes settings.json" rule. That rule
assumed a single-user membrane whose owner would read the printed
`not wired` line and act on it. On a multi-user box it became N manual steps
nobody performed: an audit of every human membrane found hook **bodies** with
no registration at all. Bodies without nerves are worse than neither — the
membrane reads as enforced and enforces nothing.

What the merge touches, and nothing else:

- only `.hooks.PreToolUse`, `.hooks.UserPromptSubmit`, `.hooks.Stop` and
  `.hooks.SessionStart`;
- within those, only array entries whose `command` names a forge hook file.
  Your permissions, env, model, statusline and hand-written hooks are read
  and re-emitted verbatim.

The filename match is a regex (`jq test()`; dots match any char), so no forge
hook filename may regex-match another's. Keep filenames distinct.

Properties: **remove-then-append**, so repeated casts yield one entry and a
stale matcher (e.g. the pre-Agent `Edit|Write|NotebookEdit`) self-heals;
**atomic** temp-file + `mv`, so an interrupted cast cannot truncate the file;
**one-time backup** to `settings.json.pre-forge-hooks.bak` before the first
managed write; **refuses** to touch a `settings.json` that is not valid JSON.

The registrations are declared in `cast-deploy.sh`'s `FORGE_HOOK_WIRING`
array — add a row there when adding a hook.

`cast-deploy.sh --verify-hooks` byte-compares the bodies against forge source
**and** checks registration and matcher, exiting non-zero on `UNWIRED` or
`STALE-MATCHER`. Installed-but-dark is a failure, not a printed line.
