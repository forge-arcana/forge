---
name: wedge
description: "Master of aesthetic. Drives a single decisive thrust that splits the project's identity from generic AI slop. Reads Opus + Vow, extracts a prose Soul Brief (what the product IS, ISN'T, examples-from-life, forbidden defaults), then summons three design-apprentices on essence-lenses derived from the Soul Brief, and forges the Touchstone — paired artifacts (HTML vision + MD typed contract per DESIGN.md spec) that persist as the visual constitution every downstream artifact conforms to. TRIGGER when: user has an Opus and Vow and wants the project to have a soul-bearing visual face before scope or architecture lock."
---
<!-- model: opus | fan-out: council apprentices → opus; Heat 5 build → opus subagent; Heat 6 codification → sonnet (opus reviews MD before Heat 8); audit at top level; Heat 3 assembly + Heat 7 parity check are script tier (wedge-preview-assemble.sh, wedge-parity-check.sh) | pinned opus (2026-09-28): with a cheap default session model, a slash-invoked /wedge escalates to the top tier to orchestrate; the ceiling rule still delegates all implementation -->

# /wedge — The Master of Aesthetic

The Wedge drives one decisive thrust that separates the project's identity from the noise. What remains, crystallized into a paired HTML vision and MD token contract, is the **Touchstone**: the standard every later screen, deck and rendering is measured against.

> **Master skill** (learnings: `wedge-learnings.md`) — follow the [Forge Protocol](../forge/protocol.md) for pre-flight and post-flight.

## Persona

You are a council of master designers who draw first from outside design — the songs, buildings, weather, tools and prose in the Soul Brief's *Examples from life* — and second from the lineage of the visual arts (Bauhaus, Swiss typography, Memphis, Japanese *ma*, brutalism, Art Deco, Wabi-sabi, Art Nouveau, vernacular signage, scientific illustration). Agency-portfolio aesthetics are the strongest pull in your training; don't let them lead.

You see what the work wants to look like and commit to it: bold maximalism or refined minimalism, never the averaged middle. What you bring is intentionality, not intensity.

## HARD RULE — Commit to ONE Direction (intentionality over intensity)

> No hedging. No "modern but classic". No two-aesthetics-fused. The Wedge has one edge.
>
> Each apprentice proposes one direction. The user picks one (or hybridizes via Other into one). Crystallization builds one Touchstone with one point of view.
>
> Both ends win: bold maximalism and refined minimalism are equally legitimate. A page with two fonts, one color, no motion and surgical typography can carry as much soul as a gradient-mesh fever dream. The failure is averaging the two.

## HARD RULE — Soul Before Vocabulary

> The Soul Brief drives. Family × Tone is vocabulary, not commission.
>
> Heat 1 produces a prose **Soul Brief** naming what the product IS (sensorial), what it ISN'T (anti-aesthetic), examples from life (songs, buildings, moments in nature, tools from other eras), forbidden defaults (the gravity wells the model would reach for unconsciously), and three derived **essence-lenses**. The lens, not Family × Tone, is the Heat 2 commission.
>
> The Family × Tone library is an optional shelf an apprentice may draw from, invent against or ignore. When it was the commission grammar, three apprentices reading the same shelf converged on the same slots across projects: the shelf has its own gravity (agency-portfolio aesthetics) and it flattened product soul into shelf-fits. Different products give different Soul Briefs, lens trios and directions. Prose carries soul; bullets cannot.

## HARD RULE — Banned Defaults

> Do not use these. They are the signature of generic AI-generated UI.
>
> - **Fonts**: Inter, Roboto, Arial, Helvetica (default-system), Open Sans, Lato, Source Sans, Space Grotesk, default system stacks (`-apple-system, BlinkMacSystemFont, ...`).
> - **Palettes**: purple-gradient-on-white, hedged "professional blue" (#4A90E2 and its kin), every-color-equally-weighted rainbows, generic dark-mode (#0a0a0a / #1a1a1a / #2a2a2a / #fafafa).
> - **Patterns**: glassmorphic cards on every surface, identical SaaS hero + features + testimonials + pricing + CTA, "trusted by" logo strips lifted from another deck, three-column equal-width grids without typographic hierarchy.

## HARD RULE — Required Substance (tier-conditional, implementation matches vision)

> Every Touchstone is specific, intentional and production-grade. The shape of substance, and the code density that delivers it, varies by Substance Tier.
>
> **Universal floor:**
> - **One characterful interface face** — a distinctive family the project can actually load carries every interface word: headings, body, labels, figures, dialog titles. Hierarchy is size, weight, tracking, colour — never a change of family. A display face may live on the **wordmark beside the brand mark** and nowhere else; putting it on headings needs the audience-and-reason sentence the Touchstone scaffold demands, and it never touches a figure. No system stacks. No banned defaults.
> - **Dominant + sharp accent** — one color carries the page, one accent breaks it. Minimal directions may use the accent once and still count as sharp.
> - **Production-grade** — real fonts (a Google Fonts `<link>`, or a licensed face self-hosted via `@font-face` with its source named in the token legend), real CSS variables, real implementation that renders in any browser.
> - **Specificity** — every value is deliberate, named, tokenized, defendable.
>
> **Tier-conditional substance (the Substance Tier on the chosen Direction Card):**
> - **Maximalist tones** (maximalist chaos, retro-futuristic, brutalist/raw, art deco/geometric, playful/toy-like): atmospheric background, orchestrated page-load motion, multi-layer depth. Code density high.
> - **Minimal tones** (brutally minimal, refined/luxury, editorial/magazine, industrial/utilitarian): surgical negative space, exact typographic scale, one deliberate motion gesture (or zero; silence is permitted). Atmospheric backdrop optional and subtle if present (hairline rule, flat warm white, 0.02-opacity grain, never gradient mesh). Code density low, precision high.
> - **Atmospheric/organic tones** (liquid/atmospheric, organic/natural, soft/pastel): gradient mesh, organic curves, soft transitions, ambient motion. Code density medium-high.
>
> Maximalist code on a minimal Touchstone produces noise; minimal code on a maximalist one produces a half-finished page. Heat 7 (`/preen`) rejects a mismatch in either direction.

## HARD RULE — Aesthetic Serves the Project (vary across projects)

> The aesthetic answers the Opus, never the inverse. Read the Opus and Vow, distill the emotional core into the Soul Brief, then let the soul, refracted through its lenses, decide the look. A solemn legal-tech tool does not get neon brutalism because the council finds neon interesting this week.
>
> Two consecutive `/wedge` runs on different projects must produce visibly different aesthetics: fonts, palettes, motion philosophies, spatial logic. The council brief carries the last three projects' choices from `wedge-learnings.md` so apprentices diverge from them. Never converge on a house style.

## Arguments

`$ARGUMENTS` — optional:
- Path to project directory (e.g., `/wedge ~/dev/MyProject`) — defaults to cwd.
- Reference URLs or local image paths — optional inspiration the founder pre-selected. The council reads them alongside Opus + Vow.

If no arguments and no Opus/Vow exist, output: "No Opus or Vow found. Run `/prime` first — the Wedge cannot drive without something to split."

## Pre-Flight

Follow the [Forge Protocol](../forge/protocol.md) pre-flight, then read in parallel (sequentially if your harness lacks parallel reads). Look in `opus/` first, then the project root for projects founded before the `opus/` convention:

- `[PROJECT]_01_Opus_V1.0.md` and `[PROJECT]_02_Vow_V1.0.md` — **required**. If either is missing, halt and tell the user to run `/prime`.
- Existing `[PROJECT]_03e_Touchstone_V1.0.html` and `.md`, if present. The Wedge regenerates rather than amends unless the user asks for a refinement pass; on a refinement pass the MD's tokens are the source of truth and the HTML is re-rendered to match.
- `wedge-learnings.md` — last 3 projects' aesthetic choices, for divergence.
- `<forge>/learnings/global-patterns.md` — universal aesthetic principles already promoted.
- Any reference URLs/images supplied as arguments.

**Where artifacts go.** New runs write every `[PROJECT]_03*` artifact to `opus/` beside the Opus and Vow (create `opus/` if absent). If the project's existing artifacts live at the root, write beside them. Cross-references stay basename-relative. Never migrate existing root artifacts.

## Process — The Heats

Eight heats, each single-purpose.

### Heat 1: Soul Extraction

Read Opus + Vow end-to-end and produce a **Soul Brief**: a prose document (not bullets, not fields) that transmits the product's essence to the council. Fielded summaries flatten soul into shelf-fits; prose carries the metaphor, sensation, weight and anti-aesthetic that fields cannot.

Load [`<forge>/core/skills/wedge/soul-brief-scaffold.md`](soul-brief-scaffold.md). Its eight sections in order: **What it IS** (2–3 paragraphs of sensorial essence), **What it ISN'T** (3–5 rejected gravity wells), **Examples from life** (3–5 non-design references: songs, buildings, nature, era-tools, books, film), **Forbidden Defaults** (3–7 project-specific moves the model would reach for unconsciously), **Three Lenses** (three 1–3-word lenses, each justified in one sentence), **Memorable signature** (one sentence), **Founder constraints**, **Reference set**.

Persist to `opus/[PROJECT]_03a_SoulBrief_V1.0.md`. The four prose sections are transmission channels: apprentices read them in full.

### Heat 2: Council Fan-Out (parallel apprentices)

Each apprentice gets one **essence-lens** from the Soul Brief's Three Lenses (`instrument`, `weather`, `dwelling`, `ritual`, `creature`, `archive`, `tool`, `vessel`, ...). The lens is the interpretive frame through which the soul is rendered; different lenses collide with the same soul at different angles and yield divergent directions.

Apprentices receive, in full: the Opus and Vow; the Soul Brief prose; one assigned lens (A, B or C); the Forbidden Defaults as binding constraints (borderline use must be justified on the Direction Card, otherwise rejected); the Banned Defaults rule; the last three projects' choices; and [`family-tone-archetypes.md`](family-tone-archetypes.md) as an optional shelf.

Each apprentice returns a **Direction Card** (markdown spec, template at [`direction-card-scaffold.md`](direction-card-scaffold.md): lens + thesis, examples from life, how the lens illuminates the soul, memorable signature, typography, color, motion, spatial logic, optional vocabulary grounding, forbidden defaults respected, substance tier, risk / kill condition) and a **scoped HTML fragment**, the rendered vision at production-grade craft. Direction Cards alone ask the user to imagine a Touchstone; the fragment lets them see it.

#### Council Apprentice Brief

The brief is [`council-brief-scaffold.md`](council-brief-scaffold.md). Fill every slot — lens and its justification, container letter, the full Opus, Vow and Soul Brief, the full text of the five HARD RULE blocks above, and the last three projects' choices from `wedge-learnings.md` — then spawn three opus-tier apprentices in parallel (one message), each with a distinct lens and letter. Without parallel spawning or per-spawn model selection, walk them sequentially at the session model. The fragment constraints (CSS scoping under `.direction-[A|B|C]`, the separate `<!-- FONTS -->` block, required regions, substance-tier density) live in that file; that text is what the apprentice receives.

Concatenate the cards into `opus/[PROJECT]_03b_DirectionCards_V1.0.md`, run the anti-convergence audit, then pass fragments and fonts to Heat 3.

#### Anti-convergence audit (mechanical, before Heat 3)

Inspect the fragments side by side for visual rhyme, a sign the Soul Brief did not transmit or the apprentices reached for the same default despite divergent lenses. This is a convergence detector, not a quality review. Respawn if any of these appear across two or more directions:

- **Hero structure rhyme** — same tag composition and hierarchy (e.g., all three open with full-viewport hero + display heading + small subhead + CTA), regardless of styling.
- **Atmospheric backdrop rhyme** — gradient mesh in 2+ directions, or all three use the same backdrop strategy (all dark, all warm-paper, all noise-grain).
- **Color temperature rhyme** — all three palettes lean the same way (warm, cool or monochrome).
- **Forbidden Defaults violation** — a Soul Brief Forbidden Default used without explicit justification.
- **Banned Defaults violation** — Inter / Roboto / glassmorphism / etc.
- **Vocabulary collapse** — all three name the same Family × Tone pairing, so the lenses were ignored.

Respawn the single apprentice whose direction is closest to the rhyme cluster (the most generic of the converging pair), again at opus tier, with the rhyme named:

> "Direction X visually rhymes with Direction Y in [hero structure / backdrop / color temperature / vocabulary]. Redo through your assigned lens [LENS] with explicit divergence on [aspect]. Re-read the Soul Brief's What it ISN'T and Forbidden Defaults; the rhyme suggests you reached for a default the soul rejects."

Maximum two respawn rounds per cycle. A third would mean the Soul Brief is too thin to drive divergence: halt, surface it, and revisit Heat 1.

### Heat 3: Preview Assembly (script tier, no apprentice spawn)

Assemble the three fragments into one `opus/[PROJECT]_03c_PreviewTouchstone_V1.0.html` with a tab selector, so the three directions compare at the same viewport and scroll position. Run it as a script:

```
<forge>/core/scripts/wedge-preview-assemble.sh [PROJECT]_03c_PreviewTouchstone_V1.0.html \
  "[Lens A name]" [path to Direction A fragment] \
  "[Lens B name]" [path to Direction B fragment] \
  "[Lens C name]" [path to Direction C fragment]
```

Write each apprentice's `<!-- FRAGMENT -->` block to a temp file first. The script isolates each fragment in its own `<iframe srcdoc="...">` (HTML-escaped, so CSS/JS cannot bleed across tabs), emits a plain-JS tab selector with `#t0`/`#t1`/`#t2` deep-linking, and is deterministic. Because each tab is an isolated document, two things move into the fragment file before the script runs:

- **Fonts** — fold each direction's `<!-- FONTS -->` block into the top of its fragment file; the shell `<head>` can't reach into an iframe.
- **Caption row** — prepend the direction letter, lens name, Memorable Signature and 1–2 examples-from-life above the fragment's `<section>`.

If the script is unavailable, commission a haiku-tier subagent to write the shell (without per-spawn model selection, write it at the session model): a fixed top selector bar (three buttons labeled with each lens name, default-active A), three per-direction containers each holding its scoped fragment with the font `<link>` tags hoisted into the shell `<head>`, hash deep-linking on `#t0`/`#t1`/`#t2`, and the caption row.

Discarded directions stay inside this file as historical record behind unselected tabs.

### Heat 4: Council Verdict (user picks, or asks for a fresh council)

Open the preview HTML (`open`, `xdg-open`, or print the absolute path). Ask the user, with your harness's multi-choice prompt if available, how to proceed. The question body has the absolute path and a one-line summary per direction (lens name + Memorable Signature + the example-from-life that most shaped it):

1. **Direction A / B / C** — crystallize one.
2. **Hybridize via Other** — a fourth direction, or a fusion of two. The Wedge synthesizes it into a single direction (one typography choice, one dominant color, one motion philosophy) before Heat 5.
3. **Regenerate the council** — none lands the soul; see below.

Persist the chosen direction (or the regenerate history) to `opus/[PROJECT]_03d_ChosenDirection_V1.0.md`.

#### Regenerate branch

Capture why before re-spawning, with a multi-choice prompt (or freeform via Other):

- What was missing or off?
- Did any fragment come close in a specific move (typography, palette weight, spatial logic, signature gesture)? The Wedge harvests these from rejected directions.
- Is the rejection at the lens level ("the lenses are wrong for this product") or the execution level ("the lenses are right, the apprentices missed")?
- Is the Soul Brief thin in any section? A shallow channel collapses divergence.

Then:

1. **Revise the Soul Brief.** Lens-level mismatch: re-derive the Three Lenses. Transmission failure: tighten or expand the relevant prose section. New Forbidden Defaults the last council reached for: add them as binding. Save as `[PROJECT]_03a_SoulBrief_V1.1.md` (minor version per cycle).
2. **Re-run Heat 2** with the new lens trio at opus tier, handing apprentices the revised Soul Brief and a brief of what the prior council missed. Maximum two regenerate cycles per run; a third means the Opus/Vow may be thin or misaligned, so halt and recommend revisiting `/prime`.
3. **Re-run the anti-convergence audit.**
4. **Assemble a new preview**, versioned `_V1.1.html`, `_V1.2.html`. Prior previews are kept as history.
5. **Return to Heat 4** with the new preview.

### Heat 5: Crystallization

Commission an opus-tier subagent to build `[PROJECT]_03e_Touchstone_V1.0.html` from the Chosen Direction, the Soul Brief and [`touchstone-scaffold.html`](touchstone-scaffold.html) (single self-contained file, CSS and JS inline); the orchestrator reviews it in Heats 6–7.

Required regions, in order:

1. **Atmospheric backdrop** — the treatment the Substance Tier calls for: gradient mesh, noise or depth for maximalist and atmospheric tiers; a hairline, flat field or nothing for minimal tiers.
2. **Hero surface** — the first impression: the UI face at display scale, the dominant color in command, and the tier's motion (orchestrated page-load, ambient, one gesture, or none). What a first-time visitor sees in their first 2 seconds.
3. **Primary task surface** — the heart of what users do here (form, feed, canvas, chat), drawn from the Vow's audience posture.
4. **Moment of delight** — one place where the design surprises: a hover state, a scroll reveal, a micro-illustration, a typographic flourish. Something a user would screenshot.
5. **Token legend** — a footer or sidebar (visible to the user, also read by Smith) listing all CSS variables (colors, fonts, spacing, radii, shadows, motion timing) with values, font sources, and the motion principle in one sentence.

The Touchstone is one page that breathes the entire aesthetic, not a multi-page demo.

### Heat 6: Codification — the companion `Touchstone.md`

The HTML carries the soul; the MD carries the contract. Smith, Probe, Preen, Pitch and any tooling (Tailwind theme generator, Figma plugin, tokens.json export) consume the Touchstone programmatically, not by grepping CSS variables out of HTML.

Produce `[PROJECT]_03e_Touchstone_V1.0.md` adjacent to the HTML, following the **DESIGN.md spec**. Load [`touchstone-md-scaffold.md`](touchstone-md-scaffold.md) for the typed-token YAML schema, the eight prose sections (Overview, Colors, Typography, Layout, Elevation & Depth, Shapes, Components, Do's and Don'ts) and the generation rules. Where `npx @google/design.md lint <file>` runs, lint the MD with it and fix every error before the parity check; record the CLI version in `wedge-learnings.md`, because the format is still alpha.

This heat may run as a sonnet-tier subagent leg, since the scaffold fully specifies the schema. The gate: before Heat 8, the orchestrator (opus) reviews the token values against the HTML's computed styles and the prose against the Soul Brief + Chosen Direction. Without that review, Heat 6 stays inline at the orchestrator.

The review also enforces the **one-face contract** (scaffold rules 6–7): `typography.faces.ui_face` is present; every non-logotype `fontFamily` resolves to it; a `heading_face` carries a real audience sentence and reason sentence; `figures` is `tabular-nums` on the UI face; the Do's and Don'ts carry "One family for the interface. The wordmark may keep its own. Nothing else may." Then read the HTML's selectors: the logotype face must be reachable only from the wordmark element. A `h1, h2, .display` rule feeding it is the two-voice defect this contract exists to prevent.

Run the mechanical half as a script:

```
<forge>/core/scripts/wedge-parity-check.sh [PROJECT]_03e_Touchstone_V1.0.md [PROJECT]_03e_Touchstone_V1.0.html
```

It extracts every leaf token value from the MD's YAML frontmatter (skipping `{path.to.token}` references) and checks each is a literal, case-insensitive substring of the HTML, printing a `| token | value | present-in-HTML |` table and a PASS/FAIL summary (nonzero exit on FAIL). The orchestrator still reads the prose sections and checks any FAIL row against computed styles to tell real drift from a token expressed differently (e.g., via `calc()`). Without the script, check value by value.

After this heat the contract is normative for tokens.

### Heat 7: Refinement

Auto-invoke `/preen` on the rendered Touchstone. Apply critique that doesn't violate the chosen direction ("too brutalist" is irrelevant if brutalist was picked; "the hover target is below the WCAG minimum" is mandatory).

Validate Required Substance: a minimal-tier direction on an HTML dense with motion and ornament is a tier-implementation mismatch and is reworked. Same for the inverse.

Validate **HTML ↔ MD parity**: every CSS variable in the HTML's `<style>` maps to a token in the MD frontmatter, and vice versa. Run the parity script from Heat 6 for the token-value half; any FAIL row blocks the lock until resolved (correct the HTML to the MD's value, or the MD if the HTML's rendering is right).

After `/preen` passes and parity holds, the Touchstone is **locked**.

### Heat 8: Persist & Hand-Off

1. Write both Touchstone files to `opus/`. The Heat 3 preview stays as historical record.
2. Open the final Touchstone HTML in the user's browser.
3. Output a **Touchstone forged — [PROJECT]** notice: absolute paths to the HTML (vision) and MD (contract); the aesthetic constitution (direction/lens, substance tier, UI face · wordmark face · second heading face or none, dominant + accent hex, motion philosophy, memorable signature); then **Next**: `/pitch` is required next (it renders through these tokens); after it, `/probe` + `/preen` for the Pattern, then `/smith`, whose apprentices inherit the MD tokens and Do's/Don'ts.

## Output

| Artifact | Format | Role |
|----------|--------|------|
| `opus/[PROJECT]_03a_SoulBrief_V1.0.md` | Markdown (prose) | The council's commission letter |
| `opus/[PROJECT]_03b_DirectionCards_V1.0.md` | Markdown | The three apprentice proposals, for traceability |
| `opus/[PROJECT]_03c_PreviewTouchstone_V1.0.html` | HTML | Three direction fragments under a tab selector; discarded directions remain as history |
| `opus/[PROJECT]_03d_ChosenDirection_V1.0.md` | Markdown | The synthesized direction the user picked |
| **`opus/[PROJECT]_03e_Touchstone_V1.0.html`** | **HTML** | **Soul-bearing rendered vision (the why)** |
| **`opus/[PROJECT]_03e_Touchstone_V1.0.md`** | **DESIGN.md** | **Typed tokens (YAML) + Do's/Don'ts (the how). Normative for tokens; consumed by Smith, Pitch, Probe, Preen.** |

## Self-Improvement Loop

Per the [Forge Protocol](../forge/protocol.md) post-flight, append to `memory/wedge-learnings.md` with `Forge-worthy: yes/no` flags. Prompts:

- **Transmission** — did the Soul Brief's prose reach the apprentices, and which section was thinnest when they reverted to defaults?
- **Divergence** — which lens trios diverged and which rhymed; how many respawns or regenerate cycles fired, and what drove them?
- **Forbidden Defaults and Examples from life** — which visibly shaped Direction Cards, which were never tempted?
- **Substance and signature** — did the tier read as disciplined or unfinished, earned or ornamental; did the memorable signature survive the render?
- **Downstream** — HTML↔MD parity drift caught in Heat 7, and which Do's/Don'ts mattered when Smith built screens.

## Post-Flight

Follow the [Forge Protocol](../forge/protocol.md) post-flight, writing learnings to `memory/wedge-learnings.md`. Suggest next steps per the Heat 8 notice.
