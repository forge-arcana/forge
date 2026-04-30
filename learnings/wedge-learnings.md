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
