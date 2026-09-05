# Surface Checks — Typographic Voice & Landing Shape

> Referenced by [SKILL.md](SKILL.md) Dimensions 7 and 8. Mechanical evidence: `<forge>/core/scripts/preen-surface-scan.sh <project-path> [Touchstone.md]`. Origin: two post-launch findings on a shipped consumer app (2026-09) — a display serif reaching every heading and money figure made marketing and product read as two voices; an SEO-first landing never showed the product.

## §1 Typographic voice (Dimension 7)

**The rule**: One family for the interface. The wordmark may keep its own. Nothing else may.

1. **Two-voice test** — the scan's §2 table. Each row is a site where a family other than the Touchstone `ui_face` reaches a heading, figure, or dialog title. Pass only when the table is empty, or every row is the wordmark beside the brand mark, or the Touchstone declares a `heading_face` with its audience and reason sentences filled — and even then no row may be a figure. Report every site as `file:line` + selector. Severity: IMPORTANT; CRITICAL when a figure is affected (money in a display face reads as marketing, not a ledger).
2. **Figures are tabular** — every money or count column sets `font-variant-numeric: tabular-nums` on the UI face, emphasis by weight. Scan §3 counts declarations against figure-class elements; a project with figures and zero tabular declarations is a FLAG.
3. **Family is not hierarchy** — a heading rule whose only difference from body is `font-family` is a finding. Hierarchy is size, weight, tracking, colour.
4. **Monospace** — permitted only as a declared `code_face`, for code, identifiers, and log output. Timestamps, counts, and money are figures and stay on the UI face. (Decision 2026-09-05: monospace does not count as a permitted second interface face.)
5. **Blame the right layer** — if the Touchstone itself names a display face for headings without the audience and reason sentences, the finding is against the Touchstone. Route it to `/wedge`; do not have `/smith` patch stylesheets around a broken constitution.

**Remedy shape**: one family everywhere; the display face survives on the logotype only; hierarchy by weight and tracking; figures tabular. Propose the missing primitive — a `ui_face` token plus the scan as a lint — never a per-heading patch list.

## §2 Landing shape (Dimension 8)

Applies to any logged-out or marketing page. Evidence: screenshots at 375×667 and ≥1280 wide (dark scheme too when the project has one), plus scan §4–5. The scan covers the greppable half; the first four checks are visual and need the screenshots.

1. **Product above the fold** — the hero shows the product itself: a screenshot or a static mock of a real screen, built from the same tokens as the shipped product. Illustration alone, or copy alone, fails. A mascot is welcome on the mock, not instead of it.
2. **Section rhythm** — at desktop width at least one section differs in shape from the others (split hero, full-bleed band, multi-column strip). A single centred column at one max-width, stretched to desktop, fails.
3. **One sticky nav, one primary call to action** — a slim sticky nav with a single CTA. Two CTAs of equal weight is zero CTAs.
4. **Mobile at 375** — the primary CTA sits within the first 1.6 screens (≈1070px of scroll); no horizontal overflow (`document.documentElement.scrollWidth` ≤ 375); sections are designed to stack, not merely wrapped until they fit.
5. **Brand marks are the published geometry** — third-party marks (sign-in providers, payment, social) use the vendor's published SVG. Scan §4 flags short path data as the hand-drawn tell; any mark that differs from the published geometry fails regardless of path length.
6. **Providers at equal weight** — a secondary row of sign-in providers rendered as outline, ghost, or muted needs a stated reason in the Pattern or Touchstone. Default is full weight, same size, same row.
7. **Copy is preserved** — a layout fix keeps every sentence verbatim unless the finding is about the copy. Diff the text nodes before and after.

Severity: 1–3 IMPORTANT; 4 CRITICAL on overflow, else IMPORTANT; 5–6 IMPORTANT; 7 CRITICAL when a layout change silently rewrote copy.

**Cluster**: these findings name two absent primitives — *the page has no shape rule* and *the page never shows the product*. Propose the hero-with-product and the section-shape alternation as rules, then sweep.
