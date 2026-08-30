# core/hooks/

Tool-neutral bodies of the tier work-router hook pair. Enforces the delegation
doctrine in `core/skills/forge/protocol.md` Model Tiers rules 5-7: a top-tier
session plans and delegates, never holds the implementation artifact.

- `tier-routing.sh` — `UserPromptSubmit` hook. Detects the running model from
  the transcript tail; on a top-tier model (fable/mythos/opus) it injects a
  plan-and-delegate rubric as additional context. Silent (fails open) on any
  other tier or when the model can't be determined.
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

## Install

`cast-deploy.sh --hooks` copies both scripts verbatim into `<membrane>/hooks/`
(creating the directory if missing), preserves the executable bit, and wires
them into `settings.json` (see below). `cast-deploy.sh --verify-hooks` checks
both halves — bodies *and* registration — and exits non-zero if either is
wrong.

## settings.json wiring is forge-managed (narrowly)

`cast-deploy.sh --hooks` installs the bodies **and** wires them, via an
idempotent `jq` merge of forge's own two entries into the membrane's
`settings.json`.

This reverses the earlier "forge never writes settings.json" rule. That rule
assumed a single-user membrane whose owner would read the printed
`not wired` line and act on it. On a multi-user box it became N manual steps
nobody performed: an audit of every human membrane found hook **bodies** with
no registration at all. Bodies without nerves are worse than neither — the
membrane reads as enforced and enforces nothing.

What the merge touches, and nothing else:

- only `.hooks.PreToolUse` and `.hooks.UserPromptSubmit`;
- within those, only array entries whose `command` names a forge hook file.
  Your permissions, env, model, statusline and hand-written hooks are read
  and re-emitted verbatim.

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
