# Praise Learnings

> Routing and classification wisdom for `/praise` — merged from project runs by the `/forge` cycle.

<!-- Add learnings below this line -->

## UX Feedback Revealing Data Model Gaps Needs Simultaneous Visual + Architecture Routing (2026-05-29)
**Learning**: UX feedback like "jumping nav arrows" or "variable book size" can have two distinct root causes: (1) CSS/layout (visual), and (2) data model/architecture. Routing feedback to both preen AND probe simultaneously is the right call when a visual symptom could be caused by a structural mismatch. "User wants to focus on one unit at a time" is both a UX signal AND an architecture signal when content has variable-length grouped units. Any content type with variable-length grouped units needs an explicit blueprint note on its navigation model.
**Apply when**: UX feedback about content display inconsistency — always check if the root cause is data model, not just CSS.
