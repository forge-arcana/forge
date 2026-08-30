# Preen Learnings

Accumulated UI/UX design evaluation learnings. Absorbed from project runs via the `/forge` cycle.

<!-- Add learnings below this line -->

## Font Size Bump for Extra Whitespace Causes Wrapping Regression (2026-06-02)
**Learning**: Increasing font size when a secondary content section is hidden (e.g. "show larger verse when meaning is hidden") seems like elegant use of space but causes wrapping regression for long-line content. Latin transliteration of long phrases at a larger font size wraps 2-3× more per data line, making content taller than before the section was hidden — the opposite of the intent. Compact scripts (Devanagari, CJK) are more tolerant of bumps. Before implementing "more space → larger font," verify that the longest lines in the content don't regress at the target size.
**Apply when**: any "more whitespace available → increase font size" UX pattern in a reading/content app — validate that long-line content doesn't overflow at the larger size.

## 3-Zone Portrait Mobile Cover Layout (2026-06-02)
**Learning**: A portrait mobile cover card with `[image: fixed %][flex-1 justify-center: description + CTA]` creates a dead zone below the CTA button when the description is short — the `flex-1` distributes space evenly leaving large gaps. Fix: three independent zones — image (fixed %), description (flex-1, justify-center), CTA buttons (pinned to bottom with fixed padding). Each zone is self-contained; no single zone can create a dead zone for another.
**Apply when**: any portrait mobile "cover" or intro card with an image, description text, and CTA button stacked vertically.

## Scroll Fade Overlays Should Sit at Structural Inset Boundaries (2026-06-02)
**Learning**: When a scroll area uses a structural top/bottom inset (physically bounding content within a safe zone), scroll-direction fade overlays should be positioned at the inset boundary, not at the card edges. Position `top: X%` / `bottom: Y%` to match the inset values — this masks content approaching the boundary from within the content area while leaving the decorative zones visually clean. Round the fade's corners (`border-radius`) to match the card's border-radius so the fade reads as intentional design rather than an overlay artifact.
**Apply when**: any structurally inset scroll panel with top/bottom scroll-overflow indicator fades.

## Mobile Auth Path Exposure (2026-03-22)
**Learning**: Mobile wrappers must expose ALL auth paths the web app supports. A login-only mobile page with a "create your account" subtitle is a broken signifier — the affordance promises what it can't deliver (gulf of execution). When a web app has both login and register flows, the mobile wrapper must surface both.
**Apply when**: Building mobile wrappers (Capacitor, React Native, Flutter) for web apps with multiple auth flows.

## Visual Mode Differentiation in Multi-Role Apps (2026-03-22)
**Learning**: Identical visual treatment for different app modes (e.g., two role dashboards) is a classic mode error — users can't perceive state changes. Even minimal differentiation (accent color stripe, role icon in header) prevents mode confusion. The fix is cheap; the cost of not fixing is user errors in the wrong role.
**Apply when**: Building any multi-role or multi-mode application where users switch between distinct contexts.

## Onboarding Bridge Before Multi-Step Wizards (2026-03-22)
**Learning**: Registration wizards that start immediately after authentication without explaining WHY create a conceptual model gap. Users think "I already registered" when the system thinks "registration = complete profile." A 3-4 card onboarding sequence bridges this gap and reduces abandonment.
**Apply when**: Designing onboarding flows where authentication is a separate step from profile completion.

## Action Frequency Must Correlate With Visibility (2026-03-22)
**Learning**: A role switcher placed at the bottom of a sidebar (below fold, inside hamburger on mobile) makes a primary action invisible. Dual-role users switch frequently — the affordance should match the frequency. Header placement or a visible badge/toggle is more appropriate for high-frequency actions.
**Apply when**: Placing interactive elements in navigation — audit whether placement matches expected usage frequency.

## Designing for Young Users: They Cannot Carry the Interaction Load an Adult UI Assumes (2026-03-29)

**Learning**: Interfaces for children fail on three predictable axes, all downstream of one premise — a young user cannot supply the typing skill, the initiative, or the tolerance for a faceless system that adult UI silently assumes. (1) **Voice input is a launch requirement, not an enhancement** — typing is a hard gate on participation for pre- and early-literate users, so a text-only first release excludes the audience rather than serving a subset of it. (2) **Open-ended first prompts cause decision paralysis** — a blank "what would you like to do?" stalls young users where an adult would improvise; open with concrete, small, pickable options and let open-endedness arrive after the first success. (3) **An AI character or mascot is load-bearing UX, not decoration** — it carries turn-taking, error recovery, and encouragement that an anonymous system voice cannot, and removing it to "clean up the interface" removes the scaffolding the interaction was resting on.

**Apply when**: Designing or reviewing any interface whose primary users are children — scope voice input into the launch cut, replace open first prompts with concrete choices, and treat character presence as a functional requirement in the spec rather than an art decision.

## Color Is Information Architecture When Each Hue Owns One Action Class (2026-05-29)
**Learning**: A color system earns its keep when every hue is bound to a single semantic role and every element of that role uses it — one hue for primary action, one for elevated/secondary, one for depth/hover. Consistency is the mechanism: when the same color always means the same action class, users stop reading the palette and the system becomes invisible, which is the goal. Color as semantic system is information architecture, not decoration. In products with cultural, religious, or heritage branding, the roles can draw on the tradition's own palette — e.g. saffron for primary action, gold for sacred/secondary, deep brown for depth/hover — which buys meaning for free, but the discipline is the role-binding, not the specific hues.
**Apply when**: Defining a color system for any product — assign one action class per hue before picking values, and audit that no element of a class uses an off-role color. Doubly so with cultural or heritage branding, where borrowed hues arrive pre-loaded with meaning.

## Quiet Ink on Warm/Tinted Surfaces Fails WCAG AA — Batch-Compute Every Pair (2026-05-29 → 2026-07-04)
**Learning**: Warm, desaturated palettes (parchment backgrounds, muted browns, tinted surfaces) fail WCAG AA (4.5:1) for body/nav text systematically, and the failure hides in the quietest tokens: a warm-neutral "faint" ink step can measure ~2.2:1, and gold tones (#D4A017 range) land around 2.4–2.6:1 on cream — both feel legible to normal-vision users but fail at low vision, and heritage/devotional apps skew toward older audiences who are most affected. On tinted surfaces the quietest legal text step tends to land around 6:1; any step that can't clear that floor survives only as strokes/borders/disabled decoration, and the design contract must say so explicitly rather than leaving the faint or gold step available for content labels. Never spot-check suspicious pairs — compute contrast for EVERY text/surface token pair in one scripted batch (a node one-liner is enough); the failing token hid in six components and only the batch caught them all, including reused-token spots like 9px chart axis labels, empty-state copy, and footnotes. Two adjacent defects surface in the same review pass: styled spans posing as headings give screen readers zero structure (headings are semantics wearing tokens, not a font-weight choice), and dense-register controls drift under the 24px WCAG 2.2 target floor — density is a look, not a hit-area.
**Apply when**: Reviewing any muted, warm, or gold-accented text ramp on non-white/tinted surfaces. Batch-compute all text/surface token pairs before shipping, demote failing steps to decoration-only in the design contract, and check semantic headings and target sizes in the same pass.

## Emoji Identity Anchors Break Cross-Platform (2026-05-29)
**Learning**: Emoji used as primary brand identity (logo, favicon) render inconsistently across iOS, Android, Windows, macOS. SVG alternatives render identically and can be animated. For culturally significant symbols, rendering consistency is part of respecting the symbol.
**Apply when**: Any app using emoji as logo or primary icon — switch to SVG.

## Accessibility Features Must Be Accessible Themselves (2026-05-29)
**Learning**: Accessibility features (font scaler, contrast toggle, language switch) with undersized touch targets (~24×18px) fail the iOS 44pt minimum. An a11y feature with inaccessible affordances is worse than not having it — creates false confidence. Every a11y feature must itself meet a11y standards.
**Apply when**: Any accessibility feature implementation — validate touch targets, focus order, and ARIA before shipping.

## Toast Positioning and iOS Safe Areas (2026-05-29)
**Learning**: Fixed `bottom-X` positioning for toasts/snackbars conflicts with iOS Safari's bottom browser chrome. `max(1.5rem, env(safe-area-inset-bottom))` ensures the toast clears the browser bar on all iOS devices without JS. Applies to any bottom-fixed UI: cookie banners, chat bubbles, floating action buttons.
**Apply when**: Any fixed-bottom UI element on a web app with mobile support.

## Donation UX: Framing as Ritual Participation Outperforms Transactional Copy (2026-05-29)
**Learning**: Framing donations as ritual participation (lighting a diya, offering seva) rather than financial transactions removes guilt and aligns with the user's cultural mental model. In nonprofit/community-supported apps, the best donation UX is copy that doesn't feel like a pitch. "Big or small, the intention is what matters" outperforms any button design.
**Apply when**: Any nonprofit, community-supported, or sacred-context digital product with a donation or support flow.

## Engagement-Based Triggers Feel Respectful; Time-Based Feel Arbitrary (2026-05-29)
**Learning**: Prompts triggered after N seconds feel like pop-ups because they are. The same prompt triggered after a user completes an article, scrolls 70% of a page, or navigates 5+ views feels like an acknowledgment. Engagement-based triggers produce dramatically better emotional reception — the user thinks "the app noticed I engaged," not "the timer fired."
**Apply when**: Any engagement prompt (donation, signup, review request, upsell) — tie to engagement events, not time.

## Content Navigation Position Should Be URL State (2026-05-29)
**Learning**: For content-pagination apps (scripture readers, course chapters, ebook chapters), storing current position in component state only means users cannot share or bookmark a specific page. URL-addressable content position (`?v=14`, `?chapter=3`) is trivial in Next.js and dramatically increases utility as a study/reference tool, not just a consumption tool. Stateful content consumers expect addressable state.
**Apply when**: Any app with paginated content (reading, learning, docs) — make position URL state by default.

## Content Visibility Toggles Belong at Point of Use (2026-05-29)
**Learning**: A "show/hide meanings" toggle belongs in the reading area near the content it controls, not inside a font-size settings panel. High-impact display toggles need their own affordance where the user is already looking. Group controls by context of use, not by implementation proximity — two features sharing state don't need to share a UI surface.
**Apply when**: Any reading or study app with content visibility modes (show/hide explanations, show/hide answers, etc.).

## Modal Dialogs Need Focus Management Even for Soft Prompts (2026-05-29)
**Learning**: Toasts and soft prompts with `role="dialog"` (donation, cookie notice, review request) are routinely shipped without focus management. WCAG SC 2.4.3 applies regardless of visual blocking behavior. Focus must move to first interactive element on appearance, Tab must be trapped within, and focus must be restored on dismiss. Without this, soft prompts are effectively invisible to screen reader users.
**Apply when**: Any toast, soft prompt, or non-modal dialog with interactive content — apply focus management unconditionally.

## Diacritic-Heavy Scripts Require Dedicated Line-Height (2026-05-29)
**Learning**: Devanagari script requires ~1.9 line-height minimum (vs ~1.5 for Latin). Without explicit override, standard Tailwind `leading-relaxed` (1.625) causes diacriticals (mātrā, anusvāra, virāma) to overlap on adjacent lines, especially at larger font scale. Always define separate `leading` values for Devanagari/Arabic text blocks; never rely on global line-height.
**Apply when**: Any app with Devanagari, Arabic, or other diacritic-heavy script support.

## An Ellipsis That Expands Is a Lying Signifier — Expose Frequent Actions (2026-08-12)

**Learning**: A "⋯" button carries one universal promise: a menu of more actions. Wiring it to an inline disclosure (expanding the card/row) breaks the conceptual model twice — the click yields layout shift instead of a menu, and the actions it hides may be the surface's daily verbs (send now / reschedule / delete on a scheduler row). Frequency must correlate with visibility (see "Action Frequency Must Correlate With Visibility", 2026-03-22 — this is that rule's overflow-menu case): two to four secondary actions fit as exposed quiet/ghost buttons beside one filled primary, wrapping to 44px targets on phone. Reserve "⋯" for a true popover menu, or don't use it at all. Companion trap in the same card: a media badge (▶ play glyph) on a non-clickable thumbnail is a false affordance — whatever element wears the badge must be the trigger (thumbnail → lightbox), and it must be a real `button` so keyboard reaches it. And the CSS defect that makes inline disclosures "fugly": a flex reveal row holding a tall media preview next to small buttons inherits `align-items: stretch`, inflating every button to the media's height — either set align-items or never co-locate preview and actions in one flex line.

**Apply when**: Reviewing any list/queue/table row with an overflow control — ask "is it a menu?" and "how often are the hidden actions used?"; and any thumbnail wearing a play/zoom badge — ask "does clicking it honour the badge?"

## A Shared CSS Class Is a Shared Contract — and `grid-area` Is Its Sharpest Edge (2026-08-15)
**Learning**: Restyling a class that more than one component renders is an API change, not a local edit — and the loudest failure is a named `grid-area` (e.g. `grid-area: media`) applied to a shared class: any OTHER grid that renders that class without defining that template area silently mints IMPLICIT tracks, so the borrowing rows grow, elements float to unintended corners, and sibling cells crush their text ("video" → "vide"). Field-observed across two components sharing a time-rail class: one declaration widened rows, floated chips bottom-right, and squeezed pills in a table the author never opened. Two rules: (1) before restyling any class, grep every consumer of it — the port checklist item is literally "grep the class name"; (2) scope layout-participation properties (`grid-area`, `grid-column`, `position`, `float`) to the component that owns the template (`.card .when`, never bare `.when`), leaving the bare class carrying only intrinsic looks (type, colour, alignment).
**Apply when**: Any restyle of an existing class in a shared stylesheet, especially in a codebase where several components deliberately reuse a visual idiom.

## Interaction Weight Must Match Consequence Weight (2026-08-30)
**Learning**: A confirmation mechanism is a cost imposed on the user, and its size must be monotonic in the consequence of the act it guards. Inventory a product's dialogs by *what happens if the user is wrong*, not by where they appear, and the failures surface as pairs: an irreversible human eviction firing on first click while a recoverable machine-key revoke demands two steps; an unconfirmed publish beside a confirmed draft save. Per-surface review cannot find these — each screen is individually defensible, and only the comparison is damning. Prefer undo over confirmation wherever the act is reversible; reserve the heavy guard for what genuinely cannot be taken back.
**Apply when**: Any product with more than one destructive or irreversible action — inventory every guard mechanism across all surfaces and check monotonicity against consequence before judging any single dialog.

## Grade Findings by Impact, and Flag the Severe Ones Inline (2026-08-30)
**Learning**: An evaluative sweep that returns findings in discovery order buries the one that matters. Rank by impact, and treat two classes as escalations rather than report rows: a data leak (including tenancy leaks from unscoped queries feeding "system status" surfaces) and silent data loss. Those get flagged to the user the moment they are found, not held for the write-up — a report delivered an hour later is the wrong latency for a live leak. Everything cosmetic ranks below them regardless of how many instances it has.
**Apply when**: Any evaluative art run (preen, poke, press, pound) — the moment a sweep turns up a leak or a silent-loss path, interrupt and surface it; rank the remainder by impact.

## Prototype the "After" Before Touching Code (2026-08-30)
**Learning**: For work whose deliverable is *how something feels* rather than whether it functions, a ranked findings list is not an approvable artifact — the user cannot tell from prose whether they'll like the result. Produce paired before/after prototypes rendered through the project's existing design tokens, one per reworked flow, and get approval on the "after" before any implementation. The prototype is then the spec: downstream implementation matches it exactly rather than reinterpreting it, which is what stops the built result from drifting into a third thing that resembles neither the before nor the approved after.
**Apply when**: Any UX rehaul, visual redesign, or "make this feel finished" work — never open the implementation before the after-state is approved.
