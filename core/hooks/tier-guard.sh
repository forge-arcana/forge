#!/usr/bin/env bash
#
# PreToolUse hook — enforces the delegation doctrine structurally on top-tier
# sessions (protocol.md Model Tiers rules 5-7: a top-tier session plans and
# delegates; it never holds the implementation artifact, and a tier binds only
# via the spawn's model parameter).
#
# Two gates, one hook:
#
#   1. WRITE GATE  (Edit|Write|NotebookEdit) — denies direct writes, forcing
#      the top-tier model to delegate the edit to a subagent instead.
#
#   2. SPAWN GATE  (Agent) — denies a subagent spawn that carries no explicit
#      `model` parameter. Rule 5-7 says a tier binds ONLY via that parameter;
#      a parameterless spawn silently inherits the parent's top tier, so a
#      batch of grep-and-report investigators runs on the most expensive model
#      in the fleet. This is the failure that motivated the gate: six
#      read-only investigation subagents spawned in one batch with no model
#      parameter, all inheriting the parent's top tier.
#
# Subagent detection: a subagent's PreToolUse payload carries the SAME
# transcript_path as its parent session (they share one transcript), so model
# detection alone cannot tell a subagent's call apart from the top-tier
# parent's own. The payload's `agent_id` field is the discriminator — present
# and non-empty only on subagent tool calls, absent on the parent session's
# own calls. Subagent calls are deliberately always allowed on BOTH gates:
# delegating is exactly the behaviour this hook exists to force, so blocking
# the subagent would make delegation impossible (this failure mode was hit and
# confirmed empirically before the check was added).
#
# Why fail open on every uncertain path (WRONG-BLOCK IS WORSE THAN
# WRONG-ALLOW): this hook runs on every matched tool call, for every tier, in
# every project. If it crashes, gets malformed JSON, can't find/parse the
# transcript, or can't determine the model, it must ALLOW the tool call
# (exit 0, no output) rather than deny it. A false deny silently breaks
# legitimate work on a cheap-tier session with no recovery path other than
# noticing and re-running; a false allow just means the gate didn't fire this
# one time. Never block when uncertain.
#
# Contract: read JSON on stdin. To allow, exit 0 with empty stdout. To deny,
# exit 0 (NOT 2) and print hookSpecificOutput.permissionDecision="deny" JSON
# — the JSON carries the decision, not the exit code. Timeout is short; stay
# dependency-light, read only a bounded tail of the transcript, no network.
#
# settings.json matcher must be: Edit|Write|NotebookEdit|Agent
# A membrane still on the old Edit|Write|NotebookEdit matcher leaves the spawn
# gate dark. cast-deploy.sh --verify-hooks fails on that stale matcher.

set -uo pipefail

# Read stdin JSON (the hook payload). Tolerate empty/malformed input.
payload="$(cat 2>/dev/null)"

tool_name="$(printf '%s' "$payload" | jq -r '.tool_name // empty' 2>/dev/null)"

# Which gate applies? Everything else is always allowed.
case "${tool_name:-}" in
  Edit|Write|NotebookEdit) gate="write" ;;
  Agent)                   gate="spawn" ;;
  *)                       exit 0 ;;
esac

# 1. Escape hatches first: explicit opt-out always wins, no further checks.
#    The two gates have SEPARATE hatches on purpose — wanting to hand-edit a
#    file is not the same as wanting untriaged spawns, and one env var
#    disarming both would be a silent over-grant.
if [ "$gate" = "write" ] && [ -n "${FORGE_ALLOW_INLINE_EDITS:-}" ]; then
  exit 0
fi
if [ "$gate" = "spawn" ] && [ -n "${FORGE_ALLOW_UNTRIAGED_SPAWN:-}" ]; then
  exit 0
fi

# 2. Subagent calls are always allowed (see header). A subagent that spawns or
#    writes is already delegated work.
agent_id="$(printf '%s' "$payload" | jq -r '.agent_id // empty' 2>/dev/null)"
if [ -n "${agent_id:-}" ]; then
  exit 0
fi

# 3. Spawn-gate-specific allowances, checked before the (costlier) model read.
if [ "$gate" = "spawn" ]; then
  spawn_model="$(printf '%s' "$payload" | jq -r '.tool_input.model // empty' 2>/dev/null)"

  # An explicit model parameter is the whole point — the tier is bound.
  if [ -n "${spawn_model:-}" ]; then
    exit 0
  fi

  subagent_type="$(printf '%s' "$payload" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null)"

  # A fork inherits the parent model BY DESIGN and the harness ignores a model
  # parameter on it, so demanding one would be a guaranteed false deny.
  if [ "${subagent_type:-}" = "fork" ]; then
    exit 0
  fi

  # An agent defined in .claude/agents/<name>.md may pin its own tier in
  # frontmatter. Spawning such an agent without a parameter is legitimate —
  # the definition binds the tier. Bounded local check: two fixed directories,
  # one file, frontmatter only. Any uncertainty here falls through to the
  # model check and, ultimately, fails open.
  if [ -n "${subagent_type:-}" ]; then
    cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)"
    for agents_dir in "${cwd:-/nonexistent}/.claude/agents" "$HOME/.claude/agents"; do
      def="$agents_dir/$subagent_type.md"
      [ -f "$def" ] || continue
      # Frontmatter is the leading --- block; a model: line in it pins the tier.
      if sed -n '/^---[[:space:]]*$/,/^---[[:space:]]*$/p' "$def" 2>/dev/null \
         | grep -qiE '^model:[[:space:]]*[^[:space:]]' 2>/dev/null; then
        exit 0
      fi
    done
  fi
fi

# 4. Determine the parent session's model from the transcript tail.
transcript_path="$(printf '%s' "$payload" | jq -r '.transcript_path // empty' 2>/dev/null)"

model=""
if [ -n "${transcript_path:-}" ] && [ -f "$transcript_path" ]; then
  model="$(tail -n 400 "$transcript_path" 2>/dev/null \
    | jq -R 'fromjson? | select(.message.model) | .message.model' 2>/dev/null \
    | tail -n 1 \
    | jq -r . 2>/dev/null)"
fi

if [ -z "${model:-}" ] || [ "$model" = "null" ]; then
  # Unknown model — FAIL OPEN. Never block when uncertain.
  # NOTE: on a session's FIRST prompt the transcript may carry no model line
  # yet, and first prompts are exactly when large investigation fan-outs
  # happen. Both gates are blind on that turn. There is no sturdier model
  # signal available to a hook payload today; the UserPromptSubmit rubric in
  # tier-routing.sh is the only (advisory) cover for it.
  exit 0
fi

# 5. Only top tier gets denied.
case "$model" in
  *fable*|*mythos*|*opus*)
    : # top tier — fall through and deny
    ;;
  *)
    exit 0
    ;;
esac

if [ "$gate" = "write" ]; then
  reason="Blocked: ${tool_name} on ${model}. Top-tier sessions plan and delegate; they do not write artifacts. Spawn a subagent to make this change and pass model: sonnet (or model: haiku if it is purely mechanical). Give it the exact change you want — you have already done the thinking. To override for a one-off, restart with FORGE_ALLOW_INLINE_EDITS=1 set."
else
  reason="Blocked: Agent spawn with no model parameter on ${model}. A tier binds ONLY via the spawn's model parameter — without it this subagent inherits ${model}, the most expensive tier in the fleet. Triage the task first, then respawn with model set explicitly: model: haiku for mechanical work (grep, inventory, collation, formatting, scanning), model: sonnet for implementation-to-spec (writing code, editing files, running tests). Reserve the top tier for your own synthesis. Exempt without a parameter: subagent_type 'fork' (inherits by design) and agents whose .claude/agents/<name>.md frontmatter already pins a model. To override for a one-off, restart with FORGE_ALLOW_UNTRIAGED_SPAWN=1 set."
fi

jq -n --arg reason "$reason" '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$reason}}' 2>/dev/null

exit 0
