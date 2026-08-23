#!/usr/bin/env bash
#
# UserPromptSubmit hook — injects the top-tier delegation rubric, but only
# when the session is actually running on a top-tier model.
#
# Why: this used to be model-blind (no model field is given to hooks) and
# injected generic text on every turn. We now derive the model ourselves by
# reading the tail of the transcript for the last `.message.model` seen, so
# cheap sessions (sonnet/haiku) get zero injected text — only top-tier
# sessions (fable/mythos/opus) get steered toward planning + delegation.
#
# Why fail open / fail silent on every error path: this hook runs on EVERY
# user prompt. A crash, a missing transcript, a malformed JSONL line, or an
# unknown model must never block or corrupt the prompt. When we cannot prove
# the session is top-tier, we say nothing — silence is always safe here;
# emitting the rubric to a cheap session is not.
#
# Contract: read JSON on stdin, emit hookSpecificOutput.additionalContext on
# stdout (or nothing), exit 0. Exit 2 would BLOCK and erase the prompt —
# never do that here. Timeout is 30s; this must stay dependency-light,
# read only a bounded tail of the transcript, and never touch the network.

set -uo pipefail

# Read stdin JSON (the hook payload). Tolerate empty/malformed input.
payload="$(cat 2>/dev/null)"

transcript_path="$(printf '%s' "$payload" | jq -r '.transcript_path // empty' 2>/dev/null)"

model=""
if [ -n "${transcript_path:-}" ] && [ -f "$transcript_path" ]; then
  model="$(tail -n 400 "$transcript_path" 2>/dev/null \
    | jq -R 'fromjson? | select(.message.model) | .message.model' 2>/dev/null \
    | tail -n 1 \
    | jq -r . 2>/dev/null)"
fi

if [ -z "${model:-}" ] || [ "$model" = "null" ]; then
  # Unknown model — say nothing.
  exit 0
fi

case "$model" in
  *fable*|*mythos*|*opus*)
    : # top tier — fall through and emit the rubric
    ;;
  *)
    # Not top tier — cheap session gets no injected text.
    exit 0
    ;;
esac

text="You are running on ${model} — a top-tier model. Your output is a PLAN, not an artifact.

Read what you need to understand the problem and design the solution. Then delegate every unit of implementation to a subagent, passing the model parameter explicitly: model: haiku for mechanical work (collation, formatting, template filling, scanning), model: sonnet for implementation-to-spec (writing code, editing files, running tests, building scripts to a design you have already settled).

Keep for yourself only: the design, the delegation brief, review of what comes back, and the final verdict.

Writing to files is blocked on this tier — that is deliberate, not a malfunction. If a write is denied, spawn a subagent to make the edit."

jq -n --arg text "$text" '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":$text}}' 2>/dev/null

exit 0
