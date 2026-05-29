# Praise Learnings

> Routing and classification wisdom for `/praise` — merged from project runs by the `/forge` cycle.

<!-- Add learnings below this line -->

## Animation Package Evaluation: "What Should Migrate?" Not "Should We Add It?" (2026-05-29)
**Learning**: When a project already has an animation library installed, the right probe question is "what in the codebase should migrate to it?" not "should we add it?" An installed-but-underused dependency is a signal, not a decision point. Also: when a component needs both CSS `transform` for positioning AND an animation library's transforms, all transforms must live inside the animation library's state definitions — never split between className and animated state.
**Apply when**: Any project with an installed animation library — audit coverage before proposing addition; enforce transform consolidation in code review.

## UX Feedback Revealing Data Model Gaps Needs Simultaneous Visual + Architecture Routing (2026-05-29)
**Learning**: UX feedback like "jumping nav arrows" or "variable book size" can have two distinct root causes: (1) CSS/layout (visual), and (2) data model/architecture. Routing feedback to both preen AND probe simultaneously is the right call when a visual symptom could be caused by a structural mismatch. "User wants to focus on one unit at a time" is both a UX signal AND an architecture signal when content has variable-length grouped units. Any content type with variable-length grouped units needs an explicit blueprint note on its navigation model.
**Apply when**: UX feedback about content display inconsistency — always check if the root cause is data model, not just CSS.
