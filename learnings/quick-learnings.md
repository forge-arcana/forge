# Quick Review Learnings

> Populated by `/quick` runs across projects. Absorbed into forge by `/reforge`.

<!-- Add learnings below this line -->

## Batch-Added Routes Skip Error Path Logging (2026-03-15)
**Learning**: When routes are added in bulk (e.g., an admin module with many endpoints), validation failure logging (`logger.warn` on `safeParse` rejection, 404, 403) is easy to miss even when the pattern is established in other modules. A route template, code snippet, or custom lint rule that flags `safeParse` failures without a preceding `logger.warn` prevents this class of gap.
**Apply when**: Adding multiple route handlers at once, especially in admin/CRUD modules.

## Toast/Snackbar Redundancy — Platform Guidelines (2026-03-15)
**Learning**: Success toasts are redundant when the UI already shows the outcome: (1) page navigation after action, (2) toggle/switch updates inline, (3) dialog closes and parent list refreshes. Keep error toasts always — error feedback is never redundant. Validation errors belong inline near the field (Apple HIG, Material Design), not in toasts/snackbars. Form-level errors should render as inline text under the input, not as ephemeral notifications.
**Apply when**: Reviewing toast/snackbar usage in any UI codebase during tech debt audits.

## Band-Aid Fallback Detection: Ask "Where Should This Be Set?" (2026-03-15)
**Learning**: When reviewing `||`/`??` fallback patterns, the key question is: "Where should this field have been set?" If the answer is "at creation/insert time" and the fallback re-derives the value from a parent or sibling, it's a band-aid masking a data integrity bug. Fallback chains (3+ links) are a strong code smell — one authoritative source should suffice.
**Apply when**: Reviewing code for tech debt, especially around data access patterns with fallback defaults.
