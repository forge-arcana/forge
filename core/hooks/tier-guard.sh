#!/usr/bin/env bash
#
# PreToolUse hook — denies direct write tools (Edit/Write/NotebookEdit) on
# top-tier sessions, forcing the top-tier model to delegate the edit to a
# subagent instead of performing it inline.
#
# Why: pairs with tier-routing.sh's UserPromptSubmit rubric. That hook can
# only ask nicely; this hook enforces it structurally for the highest tier by
# denying the tool call and telling the model to spawn a subagent instead.
#
# Subagent detection: a subagent's PreToolUse payload carries the SAME
# transcript_path as its parent session (they share one transcript), so
# model detection alone cannot tell a subagent's write apart from the
# top-tier parent's own write. The payload's `agent_id` field is the
# discriminator — present and non-empty only on subagent tool calls, absent
# on the parent session's own calls. Subagent writes are deliberately always
# allowed: delegating the edit to a subagent is exactly the behaviour this
# hook exists to force, so blocking the subagent would make delegation
# impossible (this failure mode was hit and confirmed empirically before
# this check was added).
#
# Why fail open on every uncertain path (WRONG-BLOCK IS WORSE THAN
# WRONG-ALLOW): this hook runs on every tool call, for every tier, in every
# project. If it crashes, gets malformed JSON, can't find/parse the
# transcript, or can't determine the model, it must ALLOW the tool call
# (exit 0, no output) rather than deny it. A false deny silently breaks a
# legitimate edit on a cheap-tier session with no recovery path other than
# noticing and re-running; a false allow just means the rubric didn't fire
# this one time. Never block when uncertain.
#
# Contract: read JSON on stdin. To allow, exit 0 with empty stdout. To deny,
# exit 0 (NOT 2) and print hookSpecificOutput.permissionDecision="deny" JSON
# — the JSON carries the decision, not the exit code. Timeout is short; stay
# dependency-light, read only a bounded tail of the transcript, no network.

set -uo pipefail

# Read stdin JSON (the hook payload). Tolerate empty/malformed input.
payload="$(cat 2>/dev/null)"

# 1. Escape hatch first: explicit opt-out always wins, no further checks.
if [ -n "${FORGE_ALLOW_INLINE_EDITS:-}" ]; then
  exit 0
fi

# 2. Only gate the write-shaped tools; everything else is always allowed.
tool_name="$(printf '%s' "$payload" | jq -r '.tool_name // empty' 2>/dev/null)"

case "${tool_name:-}" in
  Edit|Write|NotebookEdit)
    : # gated tool — continue to subagent/model check
    ;;
  *)
    exit 0
    ;;
esac

# 3. Subagent calls are always allowed. A subagent's payload carries the
# same transcript_path as its parent, so it would otherwise be misread as
# the parent's own (top-tier) model. agent_id presence is the real signal
# that this call is delegated work, not the parent writing inline.
agent_id="$(printf '%s' "$payload" | jq -r '.agent_id // empty' 2>/dev/null)"

if [ -n "${agent_id:-}" ]; then
  exit 0
fi

# 4. Determine the model from the transcript tail.
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

reason="Blocked: ${tool_name} on ${model}. Top-tier sessions plan and delegate; they do not write artifacts. Spawn a subagent to make this change and pass model: sonnet (or model: haiku if it is purely mechanical). Give it the exact change you want — you have already done the thinking. To override for a one-off, restart with FORGE_ALLOW_INLINE_EDITS=1 set."

jq -n --arg reason "$reason" '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$reason}}' 2>/dev/null

exit 0
