# Preen Learnings

Accumulated UI/UX design evaluation learnings. Absorbed from project runs via `/fold`.

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
