# Wedge Learnings

Accumulated aesthetic-direction learnings from `/wedge` runs. Absorbed from project memory via the `/forge` cycle.

These are universal aesthetic principles that survive across projects — not project-specific Touchstone choices. Project Touchstones live in their own repos; this file holds what the council has *learned* about driving the wedge well.

<!-- Add learnings below this line -->

## Visual Decisions Need Visual Artifacts (and prefer one selector to N files)

**Principle**: When a council asks the user to choose between aesthetic directions, the choice must be made *visually*, not from prose specs. Direction Cards (typography names, hex codes, motion principles) are abstract — they ask the user to *imagine* the Touchstone. Aesthetic decisions only land when set on a real page at real scale. Render every candidate direction at production-grade craft before asking the user to commit.

**Refinement — assemble into ONE preview, not N**: Combine the rendered directions into a SINGLE preview HTML with a tab/segment selector at the top, not N separate files. One file to open. Switching between directions happens in the same viewport at the same scroll position with consistent font-loading state — typography scale, palette weight, and motion philosophy become directly comparable. URL hash deep-linking (`#a`, `#b`, `#c`) lets the user share "this one." The selector enforces sequential viewing — the user can't average two directions in their head when only one is visible at a time, which strengthens any Commit-to-ONE rule the council operates under.

**Why**:
- The artifact the council is choosing among governs every downstream rendering. The decision must be made at the same fidelity it will dictate.
- Typography pairings only land when set on a real page; color palettes only land in real composition; memorable signatures only land at real scale. Markdown specs cannot deliver any of this.
- Rendering exposes failure modes (typography that doesn't pair, a signature that's flat at scale, motion that overstates) BEFORE the commit, not after.
- Side-by-side at-the-same-scale comparison is impossible across browser tabs (different window sizes, different scroll positions, fonts loading at different speeds). A unified preview with a selector eliminates this entirely.

**How to apply**:
- Insert a Preview Assembly heat between Council Fan-Out and Council Verdict in any council-style aesthetic skill.
- Apprentice deliverable in the Fan-Out heat is dual: spec (markdown) AND scoped HTML fragment (CSS scoped under a per-direction container class — `.direction-a`, `.direction-b`, `.direction-c` — to prevent token bleed when fragments are co-located).
- Tokens declared as scoped custom properties: `.direction-a { --color-dominant: #...; }`, never `:root`. No global resets, no unscoped element selectors.
- Fonts returned in a separate fenced block so the assembler can hoist all `<link>` tags into the preview shell's `<head>` (one head, all fonts, accepted upfront cost for a preview artifact).
- Assembler is mechanical — no creative apprentice work — just a shell with selector bar, three containers, hash-routing, and a per-direction caption strip.
- Discarded directions stay inside the preview HTML behind unselected tabs as historical record. No separate cleanup, no lost residue.

**Trade-off accepted**: Apprentice deliverable expands from spec-only → spec + scoped HTML fragment (~1.5× cost per apprentice), in exchange for a visual decision over an imagined one for the project's defining aesthetic constitution. Cost is small; value is decisive.

**Forge-worthy**: yes — universal principle. Applies wherever a council/multi-option pattern asks a user to commit to an aesthetic direction. The principle "visual decisions need visual artifacts" is independent of any specific project, family, or tone; the refinement "one selector beats N files" is independent of how many directions the council surfaces.

## Soul Brief Beats Fielded Brief; Lens Beats Family×Tone

**Principle**: When an aesthetic council uses a *fielded* brief (structured fields like "audience posture: contemplative", "memorable signature: a slow fade") plus a *fixed-menu commission grammar* (e.g., Family × Tone drawn from an N×M archetype shelf), three failure modes compound:

1. **Fields flatten soul.** Soul lives in metaphor, sensation, weight, sound, anti-aesthetic — properties that resist field structure. A fielded brief reduces "what this product IS" to a label; the apprentice receives the label, not the soul.
2. **A fixed shelf has its own gravity.** Any reference shelf assembled from a particular subculture (e.g., agency-portfolio aesthetics) has gravitational pull toward that subculture. Independent apprentices reading the same shelf converge to the same "safe-default-for-a-digital-product" slots regardless of project.
3. **Cross-project convergence emerges empirically.** Different products, briefed in different sessions, produce visibly similar A/B/C direction triads — not because the products are similar, but because the brief-shelf machinery is the same.

**Fix — invert the commission relationship in three layered moves**:

1. **Replace the fielded brief with a prose Soul Brief.** Required prose sections: *What it IS* (sensorial — sound, weight, temperature, pace, light; concrete imagery, banned design language); *What it ISN'T* (anti-aesthetic — 3–5 specific rejections, not labels); *Examples from life* (3–5 non-design references — songs, buildings, paragraphs, tools from another era; explicitly NOT design portfolios); *Forbidden Defaults* (project-specific aesthetic moves the model would reach for unconsciously *given this product*); *Three derived Lenses* (interpretive frames tuned to this product). Prose carries metaphor; bullets cannot.
2. **Demote the archetype shelf to optional vocabulary.** Apprentice's commission is now ONE LENS from the Soul Brief, not a Family × Tone slot. Shelf becomes a craft-grounding reference an apprentice MAY draw from, MAY invent against, or MAY ignore. Mark the shelf file accordingly; remove any "apprentice assignment" table that implied the shelf was the grammar.
3. **Add a mechanical anti-convergence audit between fan-out and assembly.** Inspect returned fragments for visual rhyme: hero structure rhyme (same tag composition + hierarchy), atmospheric backdrop rhyme (same backdrop strategy across 2+ directions), color temperature rhyme (all warm / all cool / all monochrome), Forbidden Defaults violation, Banned Defaults violation, vocabulary collapse (all three name the same shelf pairing). Rhyme triggers a respawn of the apprentice closest to the rhyme cluster, with the rhyme called out explicitly. Cap respawns at two rounds; a third would indicate the Soul Brief itself is too thin and the brief-authoring heat needs revisiting.

**Why this works**:
- Different products produce different Soul Briefs; different Soul Briefs produce different Lens trios; different Lens trios produce divergent directions. Convergence is solved at the source, not patched at the artifact.
- *Anti-aesthetic naming* is more discriminating than identification — naming what the product ISN'T eliminates the gravitational pull of safe defaults.
- *Examples from life* sources inspiration from outside the design subculture, breaking the agency-portfolio gravity that biased the old shelf.
- *Forbidden Defaults* makes the model's reflex visible and binding — the gravity wells are named so they cannot be reached for unconsciously.
- The audit catches convergence at the artifact level, not just at intent — apprentices may believe they diverged while their fragments rhyme structurally.

**How to apply**: any council-style aesthetic skill that asks N apprentices to interpret a product's identity should:
- Output a prose-form brief (not a fielded one) before fan-out, with explicit anti-aesthetic and outside-domain references.
- Derive per-product interpretive frames as the commission grammar; fixed archetype menus survive only as vocabulary.
- Require apprentice deliverables to cite the outside-domain references that shaped them.
- Run a mechanical convergence audit before assembling the user-facing preview.

**Trade-off accepted**: The brief-authoring heat expands (pure prose plus lens derivation, longer than a fielded brief) and apprentice prompts grow (full Soul Brief + lens, not a one-line pairing). Apprentice cost increases marginally; rendered-direction divergence increases substantially. Net cost is small; value is the difference between "three projects look the same" and "three projects look like themselves."

**Forge-worthy**: yes — universal principle for any council/fan-out skill where a fixed commission grammar risks cross-invocation convergence. The mechanism (prose brief + per-invocation derived commissions + post-fan-out convergence audit) generalizes beyond aesthetic councils to any divergence-required parallel-apprentice pattern.

## Dual-Accent Structural Systems Need Explicit Normative Documentation

**Principle**: Some design directions use two accent colors where both are *structurally required*, not a "dominant + secondary" hierarchy. Example: a bilingual product whose two scripts each get their own load-bearing accent — one accent per script-world, the tension between them being the design itself. A downstream agent (Smith, Probe, or any code-writing skill) will instinctively treat one as "primary" and the other as decorative, collapsing the structural intent. The DESIGN.md must preempt this.

**Fix**:
1. Name the system explicitly in the YAML frontmatter: both accents under `colors:` with role descriptions that state their structural purpose — *not* "secondary accent" but a role-named description like "primary-script accent — the first script-world."
2. Add a Do in the Do's and Don'ts: "Do let `{colors.script-a-accent}` and `{colors.script-b-accent}` appear on the same surface simultaneously — their tension is structural, not a contrast problem."
3. Add a Don't: "Don't use `{colors.script-b-accent}` on interactive elements — it belongs to the second-script text voice only."
4. Note the WCAG contrast ratios for both accents against the surface color, so Smith doesn't swap them for a "safer" single accent.

**Why**: YAML token systems don't carry intent — only values. A single `accent` key with one value is unambiguous. Two accent keys with opaque names invite a future agent to pick the "main" one and demote the other. Naming the structural role in the description field and in the prose sections is the only way the intent survives downstream consumption.

**How to apply**: Any Touchstone whose chosen direction uses N accent colors where N > 1 for structural rather than decorative reasons — verify the DESIGN.md prose calls out the multiplicity explicitly, with a rationale and a guardrail in Do's and Don'ts.

**Corollary — layout-as-translation risk**: Bilateral two-column layouts carry an inherent risk: they look like "original | translation" to any reader familiar with multilingual publishing. The Do's and Don'ts must explicitly name this risk and prohibit the labeling that would trigger it ("don't label one side 'Original' and the other 'Translation'"). The disambiguation belongs in the spec, not in the implementation.

**Forge-worthy**: yes — generalizes to any multi-voice structural system where more than one token carries the same visual category (accent, surface, heading) and where the plurality is intentional. The principle is: *N tokens of the same class requires N explicit roles in prose, or a downstream agent will reduce them to 1.*

**Companion principle — councils search, they don't single-shot**: Even with a sharp Soul Brief and divergent lenses, the council can produce N directions where none lands. The user's eye for *the* direction is the gate the council is trying to clear; sometimes the council misses, and the right move is not "pick the least bad" but "regenerate with feedback." The verdict heat must therefore expose a branch alongside pick-one and hybridize: **Regenerate the council**. The Regenerate branch captures structured feedback (was the rejection at the lens level or the execution level? which Forbidden Defaults did the council reach for that should now be named as binding? is any prose section thin?), revises the brief (re-derives the lenses if lens-level; tightens the prose if transmission-level), re-runs the fan-out and assembly with the revised brief, and returns with a versioned new preview. Cap at two regenerate cycles per skill run; a third indicates the upstream source may be misaligned and the skill should halt with a recommendation to revisit it. Prior previews are preserved as historical record. The principle generalizes beyond aesthetic councils: any divergent-fan-out pattern where the user is the final taste-gate should expose a "regenerate with feedback" branch. Better N council rounds and a lived final artifact than one round and a final artifact the user quietly drifts away from.

## Tool-Register Products Need Tool-Register Touchstones — and Touchstones Carry Two Faces (2026-07-04)

**Learning**: When the product being wedged is a working tool (admin surface, task queue, enumerated lists, oversight dashboard), council apprentices default to editorial landing-page register: hero display type, scrolling composition, poetic copy, generous air. A founder evaluating a tool reads this as pretentious fluff with no functionality. Bind REGISTER explicitly in the Soul Brief: tool-register products get tool-register touchstones — single viewport, no page scroll, no hero, no marketing copy, information density as the virtue, aesthetic carried by type/ruling/color rather than layout theatre. "Calm/leavable/glanceable" must be disambiguated: a glanceable TOOL is dense (everything visible at once), not airy — apprentices reliably misread it as whitespace poetry. The register rule is surface-scoped, not absolute: spacious presentation works for landing pages but kills the core business flow. Therefore the Touchstone ARTIFACT should carry two first-class faces from one token set — a Landing face (spacious, editorial) and a Core Flow face (dense, real UI grammar: nav, stat tiles, tables, charts) — because a landing-only Touchstone gets inherited by builders into working screens where it misrepresents and kills the application flow. Core Flow face is the primary commission for tool products.

**Apply when**: Any /wedge run on a product whose primary surface is a working screen. Soul Brief must carry a binding Register section; Heat 5/6 should produce both faces; the anti-convergence audit treats register mismatch as a soul-transmission failure.

## Choice Artifacts Must Be Clickable Variants, Not Prose Menus (2026-07-04)

**Learning**: After a register correction, asking the founder to choose palette/typography/layout from prose descriptions (multi-choice text naming hex codes and font names) fails the same way Direction Cards fail — it demands imagination where a render is cheap ("give me a visual so I can choose; making me read and imagine these options doesn't help"). When the layout skeleton is already approved, render candidate skins as LIVE TOGGLES on the same dense screen: CSS-variable skin classes plus a small utilitarian switcher bar, one file, URL-param deep links per combination. Extends "visual decisions need visual artifacts" from the direction pick to every refinement-stage aesthetic choice.

**Apply when**: Any post-council refinement where palette, type, or layout variants are being chosen; build the toggle preview instead of describing options.

## The Council Never Self-Picks After a Rejection (2026-07-04)

**Learning**: When the founder rejects all council directions without picking one, the Wedge must not synthesize a committed direction unilaterally to keep momentum — the founder will immediately challenge the unchosen aesthetic ("why did you use X? I did not select this"). Commit-to-ONE governs the ARTIFACT, not the CHOICE: the user is always the taste gate, and after a rejection the next verdict still belongs to them, rendered as clickable options.

**Apply when**: Heat 4 regenerate branches and any council-style skill where a full-slate rejection occurs; the recovery step is a new user-facing choice, never a silent synthesis.
