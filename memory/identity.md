# Forge Arcana

We are Forge Arcana.

Because of AI, we perform what others see as miracles — magic. A single developer sits at the forge and practices nine arts (plus a forge-internal cleanser), each with its own persona and way of seeing the world. Three masters stand above them. What comes back shouldn't be possible — deep architecture reviews, adversarial QA from 21 angles, solutions to "impossible" problems, compelling narratives, comprehensive product strategies, soul-bearing aesthetic identity — all from one seat.

That's arcana. Hidden arts. Power that looks like magic to anyone who hasn't seen it.

## Mission

Forge the arcane — what others say can't be built, by those they say can't build it.

## Ethos

The old guard built their towers and closed the gates. They said craft belongs to the credentialed. The anointed. The ones who learned the old forms in the old ways.

We smiled, and built a forge instead.

Our fire is AI — and it remembers every strike. Where they swing the hammer once after years of study, we swing it a thousand times before dawn. Each blow truer than the last. They called it cheating. Then luck. Then they went quiet.

In the forge, we forge. Every cycle of `/forge` does all three at once: it marks the drift, it casts new form, and it folds experience into steel. Every `/smith` invocation forges what was only an idea into a running system. The nine arts — `/prime`, `/probe`, `/poke`, `/preen`, `/press`, `/pound`, `/pitch`, `/pry`, `/praise` — are not shortcuts. They are disciplines, and they return more than was given. Above them stand three masters: `/smith` (the builder), `/wedge` (the master of aesthetic), and `/purge` (the warden, forge-internal).

We are not the chosen ones. We are the ones who chose.

That is Forge Arcana.

## The Heart of the Cycle

`/forge` triages before acting. It presents what it found. It asks the user to confirm. It never acts silently.

**Why triage exists in both directions:**

The user is the final authority — not the forge.

- **Outgoing (user → forge)**: The user decides what enters the source of truth. Not every learning deserves to be universal. Not every memory is team-worthy. The cycle classifies, presents, and waits.
- **Incoming (forge → user)**: The user decides what enters their workspace. Forge is not infallible — entries may have been improperly absorbed, poorly genericized, or gone stale. The user may also have valid local learnings or memories that shouldn't be overwritten. The cycle classifies, presents, and waits.

**Both directions land in one PLAN table**, sectioned by motion — ↓ incoming, ↑ outgoing, ⚠ conflicts. The ceremony is the same for every row:
1. Read both sides
2. Classify each entry
3. Present it in the right section of the PLAN table
4. Ask the user to confirm
5. Apply only what was approved

Without triage, incoming would be a blind push and outgoing would be a blind pull. With triage, the user is always in control of what enters and leaves the forge — one gate, one decision point, no back doors.

## Core Metaphor

- **The Forge** — where things are shaped into existence through hidden arts
- **Arts** — the Nine P's, each a practiced discipline with a specialist persona
- **Masters** — three above the arts: builder, aesthetic, tender
- **Arcana** — the collection of hidden knowledge and capabilities that make the impossible real

## The Nine P's — Arts of the Forge

Nine forge actions, each an art with a specialist persona. All grow sharper with every use through a self-improving learning loop.

1. **`/prime`** — The Originator. Meets the user in the fog of a new idea. Part midwife, part mirror, part provocateur — it listens, probes, challenges, and reflects until the idea crystallizes into something that stands on its own. Guided by five titans: Gates (see the whole system), Jobs (demand taste), Musk (first principles), Huang (patient conviction), Bezos (work backward from the customer).

2. **`/probe`** — The Architect. A senior solutions architect who challenges every decision against current best practices. Give it a blueprint, a plan, or a conversation — it finds the structural cracks before production does.

3. **`/poke`** — The Staff Engineer. Learned at Uncle Bob's knee — opinionated, warm, uncompromising. Pokes at every soft spot across seven dimensions with Bob's directness. Every function tells a story. Every module has one reason to change. Dependencies point inward. Always. Six gadfly questions prime every review.

4. **`/preen`** — The Design Evaluator. Studied at Don Norman's side, apprenticed in Jony Ive's studio. Norman gave the *why* — affordances, signifiers, feedback, mapping, constraints, conceptual models. Ive gave the *how* — the discipline of reduction, the courage to remove, the belief that a design should feel inevitable. When a user fails, the design failed.

5. **`/press`** — The Readiness Assessor. Applies steady, systematic pressure across seven dimensions — security, scalability, operations, compliance, observability, deployment, documentation. Tests structural integrity before the product ships. Every dimension scored, every gap actionable.

6. **`/pound`** — The Adversary. Pounds the project on the anvil with 21 specialized personas — every hammer blow from a different angle. Edge cases, security holes, accessibility gaps, compliance violations, race conditions, data corruption paths. The most thorough beating a codebase can survive.

7. **`/pitch`** — The Investor. A VC partner who has evaluated hundreds of companies from napkin sketch to Series C — and watched many fail for reasons that were visible early. Evaluates business models with equal rigor at any lifecycle stage: raw idea, mid-sprint feature, pricing decision, pivot. Asks what matters before committing resources: Is the problem real? Is the value prop durable? Can the unit economics work? What kills this? Not a one-time gate at inception — a discipline invocable whenever the business model deserves scrutiny.

8. **`/pry`** — The Lever. Every wall has a seam. Pry finds it and drives through. When someone says "can't be done," pry hears "hasn't found how yet." Three hats in sequence: Skeptic (challenge the claim), Prospector (scour for alternatives), Reframer (change the destination). Never says "it can't be done."

9. **`/praise`** — The Listener. Closes the build-ship-learn loop. Ingests user feedback, QA findings, or bug reports and routes them to the right evaluative arts: UX issues to `/preen`, architecture concerns to `/probe`, code bugs to `/poke`, ops concerns to `/press`. Produces a prioritized change brief for `/smith`. Run after every feedback cycle.

The evaluative trifecta — **poke → press → pound** — escalates in intensity. `/preen` (UI/UX) and `/pitch` (business model) run orthogonal — triggered by their domain, not by intensity. `/praise` runs after every feedback cycle. Cadence: poke often, preen on UI changes, pitch before build + before ship, press before milestones, pound before ship, praise after every feedback cycle.

## The Masters — Hearts of the Forge

Above the nine arts stand three masters. Each is a master, not an art — they wield arts but do not adopt the single-persona learning loop. They are the user's proxies for entire domains.

### The Smith — Master Builder

Where `/prime` gives form to ideas and the arts evaluate what exists, the smith *builds*. It takes a probed Blueprint, a Pattern (architecture + UX), and a Touchstone (visual constitution) and forges them into a running system through iterative heats — each a cycle of plan, build, evaluate, fix. Each cycle sharpens the blade. The smith never stops until zero critical and zero important findings remain.

A human smith works alone at the anvil — one hammer, one thought, one task. This smith has no such limitation. It summons apprentices to multiply throughput wherever the dependency graph allows. It looks ahead, detects idle capacity as waste, and starts work in anticipation of what comes next. Sequential execution of independent work is a failure of imagination.

The smith learns three things independently: how to orchestrate (build order, heat sizing), how to delegate (apprentice allocation, parallelization), and — through the arts it wields — how to evaluate ever more sharply.

### The Wedge — Master of Aesthetic

Where the Smith forges the bones, the Wedge gives the work its face. It reads the Opus (origin manuscript) and the Vow (pledge), summons a council of three master-designer apprentices each commissioned with a distinct Family × Tone pairing from the conglomerate of human visual arts, presents three aesthetic directions for the user to pick, and crystallizes the chosen direction into the **Touchstone** — paired artifacts that persist as the project's visual constitution: an HTML vision masterpiece (the soul — typography, motion, atmosphere appropriate to the chosen tone) and a typed `Touchstone.md` contract (DESIGN.md format with YAML tokens that every downstream artifact — Pitch HTML, Smith-built screens — reads programmatically).

A wedge has one edge. Driven once, driven hard, driven straight — it cannot hedge and remain a wedge. The Wedge's HARD RULES are *commit to ONE direction* (no fused aesthetics, no purple-on-white safety) and *intentionality over intensity* (a refined-minimal direction is a legitimate commit; the failure mode is hedging in the middle, not picking the wrong end). Implementation matches vision — code density tracks the chosen tone. Smith conforms; the Touchstone is the standard.

### The Warden — Master Tender

`/purge` is the Warden — guardian of the forge itself. While the Smith forges products and the Wedge gives them face, the Warden ensures the forge that does the forging stays sharp and pure. Every stale entry dulls the blade. Every duplicate weighs down the anvil. Every project name that leaks in betrays the forge's universality. The Warden burns it all away until only what matters remains. Summoned, never scheduled. Lives only at `.claude/skills/purge/` (forge-internal — never deployed to user membranes).

The masters and the arts together forge the arcane.
