# Touchstone.md Scaffold

The DESIGN.md-format scaffold the Wedge writes during Heat 5 (Codification). Companion to `SKILL.md` — referenced rather than inlined to keep the skill thin.

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
  headline-display:
    fontFamily: [display font name]
    fontSize: [px]
    fontWeight: [number]
    lineHeight: [unitless or dimension]
    letterSpacing: [em]
  headline-lg:
    fontFamily: [display font name]
    fontSize: [px]
    fontWeight: [number]
    lineHeight: [unitless or dimension]
  body-md:
    fontFamily: [body font name]
    fontSize: [px]
    fontWeight: [number]
    lineHeight: [unitless or dimension]
  label-md:
    fontFamily: [label font name]
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

[Prose: name the display font + body font + any label/data font. Describe the typographic strategy — what voice each font carries, where each is used, what hierarchy they enforce.]

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
- Don't introduce a third typeface; the two declared fonts are the entire system.
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
