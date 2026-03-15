# Quick Review Learnings

> Populated by `/quick` runs across projects. Absorbed into forge by `/reforge`.

<!-- Add learnings below this line -->

## Batch-Added Routes Skip Error Path Logging (2026-03-15)
**Learning**: When routes are added in bulk (e.g., an admin module with many endpoints), validation failure logging (`logger.warn` on `safeParse` rejection, 404, 403) is easy to miss even when the pattern is established in other modules. A route template, code snippet, or custom lint rule that flags `safeParse` failures without a preceding `logger.warn` prevents this class of gap.
**Apply when**: Adding multiple route handlers at once, especially in admin/CRUD modules.
