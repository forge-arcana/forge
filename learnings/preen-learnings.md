# Preen Learnings

Accumulated UI/UX design evaluation learnings. Absorbed from project runs via the `/forge` cycle.

<!-- Add learnings below this line -->

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

## Voice Input Is a Launch Requirement for Kids Products (2026-03-29)
**Learning**: A neurodiverse-first product that forces typing as the only creative input has a structural accessibility hole. For kids 8-10 with motor differences, dyslexia, or low spelling confidence, typing a creative idea in prose is a real barrier. The Web Speech API is browser-native, zero-cost, and requires no server infrastructure. This is not a Phase 2 feature.
**Apply when**: Any kid-facing AI product. Voice input ships on day one.

## Open-Ended First Prompts Cause Decision Paralysis in Kids (2026-03-29)
**Learning**: "What do you want to make?" is a high-anxiety open prompt for neurodiverse kids. Research on autistic and ADHD children shows abstract open-ended prompts cause avoidance and app abandonment. Fix: 3-4 visible suggestion chips below the free-text input that pre-fill on tap. Chips should rotate to create infinite possibility without overwhelming. This serves every kid — not just neurodiverse ones — and is a conversion optimization (Duolingo's pre-filled response pattern).
**Apply when**: Any AI onboarding targeting children or low-confidence users. Open-ended prompts need scaffolding.

## AI Character Mascots Are Load-Bearing UX for Kids Products (2026-03-29)
**Learning**: A character mascot is not decoration — it is the emotional anchor of a kid-facing AI product. Duolingo's Duo drives 25% lower drop-off. Kids form parasocial attachments to characters. The attachment is what brings them back. Without a visual form (distinctive character), facial expressions (context-responsive), and animations (generation wait state), an AI buddy is just a chat box. The character design is the single highest-leverage design investment.
**Apply when**: Any kid-facing AI product. The mascot is P0, not "nice to have."

## Devotional Web App Design Patterns (2026-05-29)
**Learning**: Color systems work best when they carry semantic meaning tied to cultural/religious context — saffron for primary action, gold for sacred/secondary, dark brown for depth/hover. When every interactive element uses the same color for the same class of action, the system becomes invisible (the goal). Color as semantic system is information architecture, not decoration.
**Apply when**: Any app with cultural, religious, or heritage branding — define color semantics early and enforce them consistently.

## Contrast Ratio Fails at Small Text in Muted Palettes (2026-05-29)
**Learning**: Warm, desaturated palettes (parchment backgrounds, muted browns) fail WCAG AA (4.5:1) for body/nav text systematically. Heritage/devotional apps skew toward older audiences who are most affected by low contrast. Check every text color against its background programmatically before shipping.
**Apply when**: Any app with warm/earthy palettes — audit contrast ratios explicitly, never trust visual judgment alone.

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

## Gold Accent Colors Almost Always Fail WCAG AA on Light Backgrounds (2026-05-29)
**Learning**: Gold tones (#D4A017 range) fail WCAG AA (4.5:1) on cream/parchment backgrounds, landing around 2.4–2.6:1. They feel legible to normal-vision users but fail at low vision. Fix: darken toward amber/ochre for text labels, or reserve gold strictly for decorative elements (borders, icons, ornaments) — never for content labels.
**Apply when**: Any app with warm-palette gold accents — audit before shipping; gold is a decoration color, not a text color.

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
