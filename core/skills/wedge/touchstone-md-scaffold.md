# Touchstone.md Scaffold

The DESIGN.md-format scaffold the Wedge writes during Heat 6 (Codification). Companion to `SKILL.md` — referenced rather than inlined to keep the skill thin.

The Touchstone has two paired forms:
- **HTML** carries the soul (rendered vision — atmosphere, motion, typography in motion).
- **MD** carries the contract (typed YAML tokens + prose rationale, consumed programmatically by Smith / Probe / Preen / Pitch / future tooling).

Where they conflict, the YAML wins and the HTML is corrected. The MD is normative for tokens.

## Required structure

```markdown
---
version: alpha
name: [PROJECT — e.g., "Daylight Prestige"]
description: [one-line aesthetic thesis from the Chosen Direction]
colors:
  primary: "#______"
  secondary: "#______"
  tertiary: "#______"
  neutral: "#______"
  surface: "#______"
  on-surface: "#______"
  # add accent / atmosphere tokens as the chosen direction requires
typography:
  faces:
    ui_face: [REQUIRED — the one family for all interface text: headings, body, labels, figures, dialog titles]
    logotype_face: [OPTIONAL — applied ONLY to the wordmark adjacent to the brand mark; omit if the wordmark uses ui_face]
    code_face: [OPTIONAL — monospace for code, identifiers, log output ONLY; never money, counts, or timestamps]
    heading_face: [OPTIONAL — a second face on headings. Permitted only with the next two lines filled; never on figures]
    heading_face_audience: [one sentence — who this audience is and why a second voice serves them]
    heading_face_reason: [one sentence — why weight and tracking on ui_face cannot carry the hierarchy]
  figures:
    fontFamily: "{typography.faces.ui_face}"
    fontVariantNumeric: tabular-nums
    fontWeight: [number — weight carries emphasis, not face]
  headline-display:
    fontFamily: "{typography.faces.ui_face}"   # or {typography.faces.heading_face} when declared
    fontSize: [px]
    fontWeight: [number]
    lineHeight: [unitless or dimension]
    letterSpacing: [em]
  headline-lg:
    fontFamily: "{typography.faces.ui_face}"
    fontSize: [px]
    fontWeight: [number]
    lineHeight: [unitless or dimension]
  body-md:
    fontFamily: "{typography.faces.ui_face}"
    fontSize: [px]
    fontWeight: [number]
    lineHeight: [unitless or dimension]
  label-md:
    fontFamily: "{typography.faces.ui_face}"
    fontSize: [px]
    fontWeight: [number]
    lineHeight: [unitless or dimension]
    letterSpacing: [em — for caps treatments]
  # add tokens for caption, label-sm, etc. as the direction requires
rounded:
  none: 0px
  sm: [px]
  md: [px]
  lg: [px]
  full: 9999px
spacing:
  base: [px]
  xs: [px]
  sm: [px]
  md: [px]
  lg: [px]
  xl: [px]
  gutter: [px]
  margin: [px]
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.md}"
    padding: [px]
  button-primary-hover:
    backgroundColor: "{colors.tertiary}"
  # add input, card, link, chip variants as the direction requires
---

# Touchstone — [PROJECT]

## Overview

[Brand & Style — holistic prose: brand personality, target audience posture, the emotional response the UI must evoke, whether it should feel dense or spacious, playful or solemn. Foundational context for any agent making a stylistic decision when no token covers it. Pull directly from WedgeBrief + Chosen Direction.]

## Colors

[Prose: name each color palette with descriptive language ("Midnight Forest Green", "Furnace Ember Red") that maps to the systematic token names. Explain what each color does in the page — what carries, what breaks, what calms.]

## Typography

[Prose: name the `ui_face` and, if declared, the `logotype_face` / `code_face` / `heading_face`. Describe the typographic strategy — how hierarchy is carried by size, weight, tracking, and colour on ONE family; where the logotype face appears (the wordmark, nowhere else); that figures are tabular numerals on the UI face. A change of family is not a hierarchy tool. If `heading_face` is declared, restate its audience and reason here in one sentence.]

## Layout

[Prose: spacing strategy (8px scale, 4px half-step, etc.), grid model (fluid mobile + fixed-max desktop, asymmetric, broken-grid, etc.), containment principles (cards with internal padding, full-bleed, etc.).]

## Elevation & Depth

[Prose: how visual hierarchy is conveyed. Tonal layers vs. shadow systems vs. flat-with-borders. If the chosen direction is brutally minimal, this section may declare "no elevation — hierarchy is typographic only" and that is correct.]

## Shapes

[Prose: shape language — corner radius (architectural sharpness vs. soft pill), edge treatments, decorative borders, whether sharp and rounded mix.]

## Components

[Prose: per component (buttons, inputs, cards, chips, links, navigation), describe states, sizing, padding, typography assignment. Reference token names from the YAML frontmatter.]

## Do's and Don'ts

[Practical guardrails the apprentices and Smith inherit. Examples:
- Do use the accent color only for the single most important action per screen.
- Don't mix rounded and sharp corners in the same view.
- Do maintain WCAG AA contrast (4.5:1 for body text).
- One family for the interface. The wordmark may keep its own. Nothing else may.
- Don't set money, counts, or timestamps in any face but the UI face; figures are tabular numerals, emphasis by weight.
- Do let the atmospheric backdrop carry depth — additional shadows compete with it.
- Don't animate on scroll if the chosen tone is brutally minimal — silence is the gesture.

These are project-specific. Generate them from the Chosen Direction's commitments. They are normative, not advisory.]
```

## Generation rules

1. **Tokens are normative.** The HTML must implement what the YAML declares. Where they conflict, the YAML wins and the HTML is corrected.
2. **Prose is contextual.** Use descriptive color names ("Furnace Ember Red") in prose; reference systematic tokens (`{colors.tertiary}`) in components.
3. **No invented sections.** Stick to: Overview, Colors, Typography, Layout, Elevation & Depth, Shapes, Components, Do's and Don'ts. Omit any that don't apply (e.g., a Touchstone with no components defined yet may omit the Components section); never reorder.
4. **Token references** use `{path.to.token}` syntax — `{colors.primary}`, `{rounded.md}`, `{typography.label-md}`. Composite references permitted only inside `components:`.
5. **Do's and Don'ts are project-specific** — derived from the Chosen Direction's commitments and the WedgeBrief's Refused Tones. Generic guardrails ("maintain contrast") permitted only if directly load-bearing for this Touchstone.
6. **One interface face.** `typography.faces.ui_face` is required and every non-logotype token's `fontFamily` resolves to it (or to `heading_face` under rule 7). `logotype_face` may be applied only to the wordmark adjacent to the brand mark — the HTML must not reach it from any heading, figure, or dialog title selector. `code_face` covers code, identifiers, and log output only. The line "One family for the interface. The wordmark may keep its own. Nothing else may." is always emitted in Do's and Don'ts — it is the one generic guardrail that is always load-bearing.
7. **A second heading face must be argued.** `heading_face` is permitted only when `heading_face_audience` and `heading_face_reason` are each filled with one sentence, and it never reaches `figures`. A blank or generic sentence ("for elegance") fails the Heat 6 review. Figures are always `{typography.faces.ui_face}` with `tabular-nums`; hierarchy is size, weight, tracking, colour — never a change of family.
