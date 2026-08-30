# /polish — draft notes (REJECTED as an art; absorbed into /preen)

> Captured 2026-08-30 from a live orchestrated polish run on a mature project.
>
> **VERDICT 2026-08-30 (/purge): REJECTED as an art. Substantially absorbed
> into `/preen`.** Do not re-propose `/polish` as an eleventh P without reading
> this note first.
>
> Four of the six dimensions below already existed in `/preen` (dialog guards →
> Dim 1 "Error prevention"; flow dead-ends → Dim 1 "Dead ends"/"How do I go
> back?"; control placement → Dim 2 + Dim 4; information hierarchy → Dim 2
> "Visual weight"). The persona is indistinguishable from `/preen`'s — it
> cannot be written without plagiarising Norman-and-Ive.
>
> What was genuinely new — **cross-surface consistency** as an axis (per-surface
> review cannot see that surface A and surface B disagree), the **audience
> gate**, **terminology coherence**, and the **missing-primitive synthesis
> frame** — is now `/preen` Dimension 6 and the Output section's clustering
> rule. The three learnings this document cites as pre-existing were phantom
> (see below); they have since been written as real entries in
> `learnings/preen-learnings.md`.
>
> ⚠ **This document cites three forge learnings that did not exist when it was
> written**: "the existing /preen law: interaction weight must match consequence
> weight", "grade-findings-by-impact", and "the existing
> match-prototype-pixel-exact learning". All three grepped to zero hits across
> `learnings/`, `memory/`, and `core/skills/`. They were sound ideas presented
> as established forge doctrine. Read every claim of prior art below as
> unverified. The pattern is recorded in `memory/purge-learnings.md` → "A
> Proposal Invents Its Own Provenance".
>
> Retained as the record of the originating run's procedure, which remains
> useful evidence for how the cross-surface sweep was actually executed.

## What /polish is

The art for taking a working-but-raw product and removing the "college
project" feel: inconsistent mechanics, incoherent flows, wrong information
hierarchy, leaked implementation vocabulary. Distinct from the existing arts:

- /preen judges surfaces against usability principles — /polish hunts
  **cross-surface inconsistency** (the same class of action done three ways).
- /poke judges code quality — /polish judges the **experienced product**.
- /pound breaks things — /polish makes what works feel finished.

The output is NOT a fix-list first. It is: ranked audit → **before/after
prototypes** → user approval → build. Nothing touches code until the "after"
is approved. (Founder-confirmed ordering; matches the existing
match-prototype-pixel-exact learning.)

## Procedure that worked

1. **Decompose the complaint into orthogonal dimensions**, one read-only
   investigation subagent per dimension, spawned in a single parallel batch.
   Dimensions that proved orthogonal and complete on the first run:
   - **Dialog/confirmation inventory** — every confirm/alert/modal/two-step/
     unguarded destructive action, mechanism per action, graded by
     consequence (native dialogs vs custom modal vs inline vs nothing).
   - **Flow trace** — one end-to-end map per user journey: entry points,
     step sequence with file:line, the decision **state machine** (states,
     existing transitions, MISSING transitions — dead-ends are the finding),
     copy that lies about what will happen, where the user lands after.
   - **Control placement/layout conventions** — where primaries sit per
     surface, with the CSS primitive responsible; check whether the design
     contract even has a rule (often the finding is "no rule exists").
   - **Information hierarchy vs attention** — render order of the main
     screen vs where action-needed items sit; click-path AND scroll-path to
     the most urgent item; badges/counts present vs absent per surface.
   - **System-noise vs audience** — every surface showing machine rows to a
     human, graded: can THIS audience act on THIS row type? Check stated
     contracts in code comments (they are often violated in the same repo).
     This dimension also catches tenancy leaks (unscoped queries feeding
     "system status" screens).
   - **Metaphor/terminology glossary** — term → meaning → surfaces →
     verdict (coherent / inconsistent / implementation-leak / mixed
     metaphor); include emails and API-facing strings, not just the UI.
2. **Subagent model triage is mandatory** (protocol.md Model Tiers rules
   5-7): these are grep-and-report tasks — spawn them on cheap tiers with an
   explicit model parameter. Top tier orchestrates and synthesizes only.
   Breach of this in the originating run drew a founder correction; the
   rule was already in the forge and must be restated inside the /polish
   skill body so the orchestrator cannot miss it.
3. **Report shape per agent**: facts with file:line only, no fixes, tables
   over prose, "worst offenders" ranked at the end. Explicitly forbid
   proposing solutions — synthesis owns that.
4. **Synthesis frame that emerged**: the findings are rarely N local
   blemishes — they cluster into **missing primitives** (no confirmation
   policy graded by consequence, no action-placement rule, no unified
   feedback/toast channel, no attention-priority rule, no audience gate on
   system rows, no glossary). The rehaul proposal should be organized as
   "write the missing rule + primitive, then sweep the instances," never as
   an instance-by-instance patch list.
5. **Grade by impact** (grade-findings-by-impact): a leak or a
   silent-data-loss found during the sweep outranks every cosmetic finding
   and is flagged inline immediately, not held for the report.
6. **Prototypes**: paired before/after, rendered through the project's
   design tokens, one per rehauled flow, presented for approval before any
   code. Pixel-exact porting rule applies downstream.

## Findings vocabulary worth keeping (cross-project patterns)

- "Interaction weight must match consequence weight" (existing /preen law) —
  /polish operationalizes it: inventory dialogs BY CONSEQUENCE, then check
  mechanism monotonicity (heavier act must never have lighter guard; the
  worst finds are first-click human eviction next to two-step machine-key
  revoke, and unconfirmed irreversible publish next to confirmed drafts).
- "The design contract's stated home for X is used by nothing that is X" —
  check the contract's own claims against call sites.
- "Copy that lies": success banners shown unconditionally, hints referencing
  deleted surfaces, promises false at some authority level.
- "Terminal states with no way back": an edit action that is secretly an
  approval; signatures that never expire; the only undo being destruction.
- "One state variable, three meanings" — shared confirm state across
  unrelated confirmations.
- Labels that exist for events nothing emits + events emitted with no label:
  audit both directions of the mapping.
- Raw machine tokens (error codes, queue names, scope keys, slugs) reaching
  a human surface verbatim.

## Open design questions for the SKILL.md

- Name: /polish (working). Distinguish from /preen in the trigger text.
- Does /polish own the prototype phase or hand off to /wedge-style
  design-apprentices? (This run: orchestrator owns it, on the top tier.)
- Verdict tier: synthesis and prototypes on the top/opus tier; sweeps pinned
  cheap. Follow the 11-arts precedent for verdict-tier pinning.
- Whether the dimension list is fixed or derived from the user's complaint
  (this run: derived, but the six above covered every complaint raised).
- Re-run mode: /polish should be re-runnable to verify the rehaul landed
  (before/after becomes before/now).
