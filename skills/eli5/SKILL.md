---
name: eli5
description: Explain Like I'm 5 — distill the current topic into the simplest possible explanation. No jargon, no assumptions.
user-invocable: true
---
<!-- model: haiku -->

# /eli5 — Explain Like I'm 5

## What It Does

Take whatever is being discussed — the current topic, a concept, a piece of code, an architecture decision, an error message — and explain it in the simplest terms possible.

## Arguments
`$ARGUMENTS` — optional. A specific thing to explain. If not provided, explain the most recent topic in the conversation.

## Rules

1. **No jargon.** If a technical term is unavoidable, define it immediately in plain words.
2. **Use analogies.** Connect abstract concepts to everyday things.
3. **Short sentences.** One idea per sentence.
4. **Build up.** Start with the simplest version, then add layers only if the user asks for more.
5. **No condescension.** Simple doesn't mean patronizing. Respect the user — they're asking because they want clarity, not because they don't understand.
