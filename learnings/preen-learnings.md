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
