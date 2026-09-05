---
title: One UI face, and a landing that shows the product
status: implemented 2026-09-05
owner: founder
created: 2026-09-05
touches: core/skills/wedge, core/skills/preen, core/skills/smith, core/rules
---

## Why

Two findings from polishing a shipped consumer app this week, both of which the founder wants the forge to catch by default rather than after launch.

1. The Touchstone had named a serif display face for headings and a sans for body. Two stylesheet rules fed the display face to every heading and money figure, so the marketing page and the product read as two voices, and non-technical family members read it as inconsistent. The fix was one sans everywhere, the display face surviving only on the logotype next to the brand mark, hierarchy carried by weight and tracking, figures tabular. A sibling app was found to have the same mix by constitution.
2. The logged-out landing had been written SEO-first: one centred column stretched to desktop, product never shown. The fix was a product-led hero (copy and sign-in card left, a static mock of the real product right, mascot on it), section rhythm that changes shape, a slim sticky nav with one CTA, and every sentence kept verbatim. Also: hand-drawn stand-ins for third-party brand marks had shipped; real published geometry replaced them, and a demoted secondary row of sign-in providers was restored to full weight.

## Proposed changes to the forge

### A. Touchstone rule: one interface face (wedge)

- The Touchstone's typography block gets a required `ui_face` (one family for all UI text, headings included) and an optional `logotype_face` that may only be applied to the wordmark adjacent to the brand mark.
- A second face for headings is allowed only when the Touchstone states the audience and the reason in one sentence, and even then never on figures.
- Figures: tabular numerals, weight not face, on the same family as body.
- Hierarchy: size, weight, tracking, colour. A change of family is not a hierarchy tool.
- Do's/Don'ts prose gets: "One family for the interface. The wordmark may keep its own. Nothing else may."

### B. Preen check: the two-voice test

- New preen dimension "typographic voice": grep the stylesheet and components for any second `font-family` or `font-serif` reaching headings, figures, or dialog titles; report each site; pass only if the second face appears solely on the wordmark.
- Second check "figures are tabular": every money or count column uses tabular numerals on the UI face.

### C. Preen check: landing page shape

- A logged-out or marketing page must show the product itself (a screenshot or a static mock of a real screen) above the fold; illustration alone fails.
- At desktop width the page must have at least one section whose layout differs in shape from the others (split, full-bleed band, multi-column strip); a single centred column at one max width fails.
- One sticky nav with one primary call to action.
- Mobile check at 375: primary calls to action within the first 1.6 screens, no horizontal overflow, sections designed to stack rather than merely fitting.
- Every third-party brand mark must be the published geometry; hand-drawn approximations are flagged.
- Providers or options must not be demoted to muted outlines without a stated reason; equal weight by default.

### D. Smith gate: prototype before implementation for visual decisions

- When a heat changes a visual identity decision (typeface, brand marks, page layout), smith publishes a comparison prototype (before, and each candidate, at phone and desktop, light and dark) and waits for the founder's pick before editing the repo. Record the pick in the ledger.

### E. Rule candidate for core/rules

- "Visual decisions are shown, then built." One sentence rule: any change to typeface, colour tokens, brand marks, or page architecture is presented as a prototype the founder can compare before code changes land.

## Acceptance

- wedge emits the new typography fields and the Do/Don't line.
- preen reports the two-voice test and landing shape checks with file and line evidence.
- smith refuses to edit visual-identity files in a heat without a recorded founder pick.
- A dry run of preen on an app with a serif heading face produces the finding; on an app with one face it does not.

## Decisions taken (2026-09-05)

- **Monospace for figures and timestamps**: folded into the one-face rule. A Touchstone may declare `code_face` for code, identifiers, and log output only; money, counts, and timestamps are figures and stay on `ui_face` with tabular numerals. The sibling app's monospace figures are therefore a Dimension 7 finding, routed to its Touchstone.
- **Where the landing checks live**: `/preen` Dimension 8 owns the review; `/press` Deployment only checks that a Dimension 8 report exists for any logged-out or marketing page.
