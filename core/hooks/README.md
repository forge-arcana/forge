# core/hooks/

Tool-neutral bodies of the tier work-router hook pair. Enforces the delegation
doctrine in `core/skills/forge/protocol.md` Model Tiers rules 5-7: a top-tier
session plans and delegates, never holds the implementation artifact.

- `tier-routing.sh` — `UserPromptSubmit` hook. Detects the running model from
  the transcript tail; on a top-tier model (fable/mythos/opus) it injects a
  plan-and-delegate rubric as additional context. Silent (fails open) on any
  other tier or when the model can't be determined.
- `tier-guard.sh` — `PreToolUse` hook, matcher `Edit|Write|NotebookEdit`.
  Structurally enforces the rubric: denies direct writes when the session is
  top-tier, but always allows subagent writes (detected via the payload's
  `agent_id` field) so delegated implementation still goes through. Fails
  open on any uncertain path — never blocks a cheap-tier session.

## Install

`cast-deploy.sh --hooks` copies both scripts verbatim into `<membrane>/hooks/`
(creating the directory if missing) and preserves the executable bit.
`cast-deploy.sh --verify-hooks` byte-compares the membrane copies against
forge source.

## settings.json wiring is per-user — forge never edits it

Installing the hook bodies does not wire them up. Each user adds the
following entries to their own `settings.json` `hooks` block (forge never
writes to `settings.json`):

```json
"UserPromptSubmit": [
  {
    "matcher": "",
    "hooks": [
      {
        "type": "command",
        "command": "~/.claude/hooks/tier-routing.sh"
      }
    ]
  }
]
```

```json
"PreToolUse": [
  {
    "matcher": "Edit|Write|NotebookEdit",
    "hooks": [
      {
        "type": "command",
        "command": "~/.claude/hooks/tier-guard.sh"
      }
    ]
  }
]
```

After installing, `cast-deploy.sh --hooks` checks whether the membrane's
`settings.json` already references each hook filename and reports "wired" or
"not wired — add the settings.json entry (see core/hooks/README.md)" per hook.
