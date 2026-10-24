---
name: parse
description: "The Sorter — front step for a raw task (bug report, issue, or feedback). Restates what done means, sizes the work with a read-only look at the repo, picks one tier (not-actionable, minor, standard, substantial) and runs the matching arts. Works headless for a caller that cannot answer questions. Self-improving. TRIGGER when: user hands over a raw bug report, issue, ticket, or piece of feedback and wants it handled end to end, or asks 'what should we do with this?'"
---
<!-- model: opus | sizing + tier verdict at opus; implementation of minor fixes and standard briefs delegated to sonnet-tier subagents per the protocol ceiling rule; the arts it invokes carry their own tiers -->

# /parse — The Sorter

> **Art** (learnings: `parse-learnings.md`) — follow the [Forge Protocol](../forge/protocol.md) for pre-flight and post-flight.

> Not every task deserves the full forge. Parse decides how much it does.

`/parse` is the front step for any raw task. It reads the task, says what done means, sizes the work, picks one tier, and runs only the arts that tier earns.

## Arguments

`$ARGUMENTS` — one of:
- **Inline text** — the raw task (a bug report, issue, or feedback)
- **File path** to a file holding it (`.md`, `.txt`, `.json`)
- **Nothing** — interactive: ask what to parse (`AskUserQuestion`); headless: write the result with tier `not-actionable` and "no task given" under Findings

The arguments may start with `--headless` and `--out <absolute dir>` (see Headless Mode in the [Forge Protocol](../forge/protocol.md)). These are stripped before reading the task.

## Mode

- **Headless** when env `FORGE_HEADLESS=1` or `--headless` is given. Follow Headless Mode in the [Forge Protocol](../forge/protocol.md): never ask, record decisions in `$FORGE_OUT/decisions.md`, no commit, no web. The output directory (`$FORGE_OUT`) is `--out` if given, otherwise env `FORGE_OUT`. It is required; if it is missing, write nothing to the repo, print `parse: an output directory is required in headless mode (--out <abs dir> or FORGE_OUT)`, and stop.
- **Interactive** otherwise. Report in chat. If `--out` or `FORGE_OUT` is set, also write the result file.

## Phase 0: Pre-Flight

Follow the [Forge Protocol](../forge/protocol.md) pre-flight. In headless mode, learnings are written to `$FORGE_OUT/learnings/parse-learnings.md`. In headless mode, first create `$FORGE_OUT/decisions.md` containing the single line `# Decisions taken without the founder` (leave it alone if it already exists). It must exist at the end of every headless run, even an empty one.

## Phase 1: Read and Restate

Read the task in full. Write one line: **Done means** — the observable outcome that closes the task. Without one, the task is not actionable.

## Phase 2: Size It (read-only)

Take a quick, read-only look at the repo. Change nothing in this phase. Establish:
- Files likely touched, and how many
- Whether UI is involved
- Risk: security, auth, data loss, money
- How many heats of work it is (a heat is one build-evaluate cycle)

## Phase 3: Pick ONE Tier

| Tier | When | Arts that run |
|------|------|---------------|
| `not-actionable` | Nothing to change: a question, duplicate, works-as-intended, or not enough information | None. Draft a reply; change nothing |
| `minor` | A one-file or narrow fix | State what the fix must achieve, fix it directly, then `/poke` scoped to the diff, plus `/preen` if it touches UI |
| `standard` | Several items, or one feature-sized change of about 1-2 heats | `/patch`, then implement its brief, then `/poke` and a `/pound` scoped to the change (plus `/preen` if UI) |
| `substantial` | 3+ heats, new architecture, or a cross-cutting change | `/smith` (it runs its own gates), then a final `/poke` and a scoped `/pound` |

**Escalation.** Security, auth, data-loss or money risk raises a `minor` to at least `standard` and always includes `/pound`. When torn between two tiers, take the higher.

**Announce.** Interactive: in one line, say the tier, why, and which arts will run, then proceed. Ask (`AskUserQuestion`, recommended option first) only if the task is genuinely ambiguous, such as two readings that need different fixes. Headless: take the recommended reading and record it in `$FORGE_OUT/decisions.md`.

## Phase 4: Run the Tier

Run the arts in the order the tier lists. Scope every evaluative art to the change (the diff, the touched files), not the whole repo. Fix findings in the same pass. Tier arts run as their own skills; where a leg needs a given model tier, spawn it with the explicit model parameter (protocol Model Tiers, rule 6). Under a headless caller, pass `--headless --out <resolved dir>` at the front of every art's and `/smith`'s arguments (and the env too, where a shell is involved).

For `not-actionable`, draft the reply to the reporter and stop.

## Phase 5: Result File

Written whenever an output directory is set (always in headless mode): `<out>/parse-result.md`. A headless caller parses it, so the first two lines are exact:

```
tier: <not-actionable|minor|standard|substantial>
arts: <comma-separated art names, lowercase, no slashes, no spaces, in the order they ran; none if none ran>
```

Example: `arts: poke,preen`. Then these markdown sections, in order:

- `## Task` — the raw task, verbatim or tightly paraphrased
- `## Done means` — the one-line outcome
- `## Why this tier` — sizing evidence and any escalation applied
- `## What ran` — each art and its outcome
- `## Changes` — files changed (none for `not-actionable`)
- `## Findings` — what the arts found and what was fixed, what remains
- `## Decisions taken without the founder` — copied from `$FORGE_OUT/decisions.md` (none if empty)
- `## Unverified (no web)` — claims that would need the web
- `## Reply draft` — required for `not-actionable`; otherwise optional

Interactive without an output directory: present the same content in chat, no file.

## Post-Flight

Follow the [Forge Protocol](../forge/protocol.md) post-flight, writing learnings to `memory/parse-learnings.md` (headless: `$FORGE_OUT/learnings/parse-learnings.md`). Capture:
- Tasks that were tiered too low or too high, and the signal that would have caught it
- Task phrasings that looked actionable but were not (and the reverse)
- Which sizing signals (file count, UI, risk class) predicted the tier best
- Replies to non-actionable tasks that closed the thread cleanly
