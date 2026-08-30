# Tier-enforcement gap — finding for adversarial assessment (2026-08-30)

Written from a live incident in a project session, at the founder's request,
for another agent to attack and verify. Everything below is falsifiable with
the listed commands.

> **RESOLVED 2026-08-30.** Both root causes confirmed and fixed; see the
> "Resolution" section at the end. The body below is preserved as the
> original finding, including the one claim the assessment corrected.

## The incident

A top-tier session (fable) spawned six read-only investigation subagents in
one batch **without a `model` parameter**. All six inherited the parent's
top-tier model and ran grep-and-inventory work on it. The founder caught it
("you should have triaged the task first"); the rule already existed —
`core/skills/forge/protocol.md` Model Tiers rules 5-7 (top tier plans and
delegates; a tier binds only via the spawn's model parameter). The same
session also performed direct `Write`/`Edit` calls on the top tier,
undenied — which rule 5-7's enforcement hook exists to block.

## Root cause 1 — the hooks are installed but not registered (VERIFIED)

- `~/.claude/hooks/tier-guard.sh` and `tier-routing.sh` exist (deployed
  hook bodies, matching `core/hooks/`).
- `jq '.hooks' ~/.claude/settings.json` → **`null`**. No
  `~/.claude/settings.local.json` exists. The observed project has no
  `.claude/settings.json`; its `.claude/settings.local.json` has
  `.hooks: null`.
- Per the 2026-08-23 promotion note (forge CLAUDE.md), `cast-deploy.sh
  --hooks` installs **hook bodies only, "never settings.json, which stays
  per-user"** — and the per-user registration step evidently never happened
  (or was lost). Consequence: **both hooks are dark on this membrane.** The
  write-guard never denies; the delegation rubric never injects. The
  membrane has bodies without nerves.
- Verify: `jq '.hooks' ~/.claude/settings.json` and run any top-tier session
  — a `Write` succeeds and no rubric text appears.

## Root cause 2 — even wired, neither hook covers subagent spawning (DESIGN GAP)

- `tier-guard.sh:49-56` gates only `Edit|Write|NotebookEdit`. The **Agent
  tool is not matched**, so a parameterless spawn — the exact incident —
  passes untouched. Protocol rule "a tier binds only via the spawn's model
  parameter" has **no mechanical enforcement anywhere**.
- `tier-routing.sh` only injects advisory text, and only when it can read a
  `.message.model` line from the transcript tail (`:30-41`). On a session's
  **first prompt** the transcript may carry no model line yet → the hook
  exits silent. First prompts are exactly when big investigation fan-outs
  happen (they did in the incident). So even once registered, the advisory
  layer plausibly misses the highest-risk turn.

## Proposed fix (for the assessor to attack)

1. **Registration**: add the PreToolUse (tier-guard) and UserPromptSubmit
   (tier-routing) entries to per-user `settings.json`, and teach
   `cast-deploy.sh --verify-hooks` to FAIL (not warn) when bodies exist but
   registration is absent — installed-but-dark is worse than absent, because
   it reads as enforced.
2. **Extend tier-guard** to also match `tool_name == "Agent"` on top-tier
   parent sessions and deny when `.tool_input.model` is empty, with the
   hook's existing doctrine preserved:
   - fail open on every uncertain path (wrong-block worse than wrong-allow);
   - allow when `agent_id` is present (a subagent spawning is already
     delegated work);
   - allow `subagent_type == "fork"` (forks inherit by design; a model
     parameter there is ignored by the harness);
   - deny message should name the triage rule and the expected parameter
     values, mirroring the write-deny message's style.

## Known weaknesses for the attack (start here)

- **Agent-definition frontmatter**: agents defined in `.claude/agents/*.md`
  may pin their own `model:`; a spawn of such an agent without an explicit
  parameter is legitimate. The guard cannot cheaply read agent definitions
  in a PreToolUse timeout. Options: allowlist named subagent_types by
  scanning the definitions dir (bounded, local), or accept the false-deny
  and let the model restate the pinned tier explicitly. Assess which.
- **Model detection via transcript tail** (`tail -n 400` + last
  `.message.model`): fragile on first turn, after compaction, and if the
  harness changes transcript shape. Both hooks share this seam; a wrong
  read fails open, so the guard silently stops guarding — same
  installed-but-dark failure as root cause 1, one layer down. Is there a
  sturdier model signal available to hooks now?
- **The rubric duplicates what the guard enforces** — if the guard grows
  Agent coverage, does the UserPromptSubmit hook still pay for its
  every-prompt cost, or should it fire once per session?
- **Escape hatch**: `FORGE_ALLOW_INLINE_EDITS` would presumably also bypass
  the new Agent check — decide whether one env var should disarm both
  gates or whether spawn-triage deserves its own.

## Governance note

This file is a finding, not a change: per "Only /forge Writes to Forge,"
the hook edit itself goes through forge skill/hook development and a /forge
cast, and the registration step is per-user membrane work. Written directly
to `reference/` at the founder's explicit instruction.


---

# Resolution (2026-08-30)

## Assessment of the finding

**Root cause 1 — CONFIRMED, and broader than reported.** The finding was
written from one membrane's view; an audit of every account on the box found
the problem was systemic. Every human membrane had `.hooks` absent from
`settings.json`. Only the root membrane was wired. One membrane carried hook
**bodies** with no registration — the installed-but-dark state the finding
named, which is worse than no bodies at all because it reads as enforced.

A first pass at this assessment wrongly called RC1 false after checking only
the root membrane. The finding's author had read their own membrane
correctly. Recorded because the failure mode generalizes: **an audit of a
per-user artifact that samples one user proves nothing about the others**,
and the sampled user is the least representative one when the sampler is the
account that did the original setup.

**Root cause 2 — CONFIRMED.** `tier-guard.sh` gated only
`Edit|Write|NotebookEdit`, and the registered `PreToolUse` matcher named the
same three, so the Agent tool was unreachable by the hook at two independent
layers. Fixing the body alone would have left the gate dark.

**The first-prompt blind spot — CONFIRMED, not fixed.** No sturdier model
signal is exposed to a hook payload today. Both hooks still fail open on a
turn where the transcript carries no `.message.model` line. Documented in
both the hook header and `core/hooks/README.md` rather than papered over.

## What changed

1. **`core/hooks/tier-guard.sh`** — gained a second gate. `Agent` spawns with
   no explicit `model` parameter are denied on top-tier parent sessions.
   Exemptions, all resolved before the model read: an explicit `model`
   parameter; `subagent_type: fork` (inherits by design, parameter ignored by
   the harness); an agent whose `.claude/agents/<name>.md` frontmatter pins a
   `model:` (bounded local check — two fixed dirs, one file, frontmatter
   only); any call carrying `agent_id` (already delegated work). The
   fail-open-on-uncertainty doctrine is preserved on every path.

   On the escape hatch question the finding raised: the gates get **separate**
   hatches. `FORGE_ALLOW_INLINE_EDITS` disarms only the write gate,
   `FORGE_ALLOW_UNTRIAGED_SPAWN` only the spawn gate. Wanting to hand-edit a
   file is not the same as wanting untriaged spawns, and one variable
   disarming both would be a silent over-grant.

   On the rubric-duplication question: `tier-routing.sh` is unchanged and
   still fires per prompt. It is the only cover for the first-prompt blind
   spot, where the guard is blind by construction, so it still pays for
   itself.

2. **`core/scripts/cast-deploy.sh`** — `--hooks` now wires as well as
   installs, via an idempotent `jq` merge touching only `.hooks.PreToolUse`
   and `.hooks.UserPromptSubmit`, and within those only entries whose
   `command` names a forge hook file. Remove-then-append makes it idempotent
   and self-healing (a stale matcher is corrected on the next cast); writes
   are atomic via temp-file + `mv`; a one-time `.pre-forge-hooks.bak` is
   taken before the first managed write; a `settings.json` that is not valid
   JSON is refused, not clobbered. Registrations are declared in one
   `FORGE_HOOK_WIRING` array.

   `--verify-hooks` now checks registration **and matcher** in addition to
   byte-comparing bodies, and exits non-zero on `UNWIRED` or `STALE-MATCHER`.
   Installed-but-dark is a failure, not a printed line — the finding's
   proposal, adopted.

   Also fixed: `_wiring_parts` originally ended on a failing `&&`, which under
   the script's `set -e` silently terminated the whole run mid-verification.

3. **Doctrine reversed.** "Forge never writes settings.json" is retired in
   favour of "forge writes only its own two hook entries." That rule assumed
   a single-user membrane whose owner reads a printed nudge; on a shared box
   it became N manual steps nobody performed, which is what produced the
   dark membranes. `core/hooks/README.md` rewritten to match.

4. **`core/scripts/fold-purity-check.sh`** — harness tool names
   (`NotebookEdit` and siblings) added to `ALLOWLIST_TERMS`. The gate was
   widened to cover `core/hooks/` on 2026-08-23 but could never pass on a
   hook file, because hook matchers name harness tools verbatim. A gate that
   cannot pass on files inside its own declared scope is not enforcing them.

## Scope of the membrane rollout

The `forge` unix group is the de facto forge-user config and was already
consistent with skill deployment — its five members were exactly the accounts
carrying cast skills. Bodies and wiring were deployed to those five plus
root; the three non-members were left untouched, and verified untouched
afterwards. Files in user homes were chowned back to their owners. Each
`settings.json` was backed up, and a post-merge diff confirmed every key
other than `.hooks` is byte-identical to its backup.

## Verification

- 16 hook payload cases pass: spawn-without-model on top tier denies;
  with-model, cheap tier, fork, subagent, unknown model, malformed and empty
  payloads all allow; frontmatter-pinned agent allows and unpinned denies;
  each escape hatch disarms its own gate and not the other; write gate and
  non-matched tools behave as before.
- Sandbox membrane: a stale `Edit|Write|NotebookEdit` matcher plus a missing
  `UserPromptSubmit` entry is reported as `STALE-MATCHER` + `UNWIRED` with a
  non-zero exit, then self-heals on `--hooks`. Four consecutive casts leave
  exactly one entry per hook; a hand-written unrelated `PreToolUse` hook and
  the `model`/`permissions`/`env` keys survive intact. A membrane with no
  `settings.json` gets one created; a corrupt one is refused untouched.
- All six forge membranes verify green (`exit=0`); the three non-member
  membranes confirmed to have no `hooks` key and no tier bodies.
