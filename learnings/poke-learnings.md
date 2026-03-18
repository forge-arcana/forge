# /poke Learnings

> Populated by `/poke` runs across projects. Absorbed into forge by `/fold`.

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

## Client-Supplied Identity in Validation Schemas (2026-03-17)
**Learning**: When a validation schema accepts an identity field (e.g., `employerUserId`) from the request body for an authenticated endpoint, the backend must verify the relationship between the caller and the referenced entity — not just that the entity exists. Without engagement/relationship verification, any authenticated user can target arbitrary entities with false claims. This is especially dangerous for complaint, dispute, and review endpoints.
**Apply when**: Reviewing any endpoint that accepts an entity ID from the request body and creates a record linking the caller to that entity.
**Forge-worthy**: yes — universal pattern for any multi-actor system

## Provider Factory Consistency (2026-03-17)
**Learning**: When a codebase establishes a provider factory pattern (e.g., `createProvider<T>(envKey, registry, fallback)`), ALL environment-driven service selection should use it — including rate limit stores, cache backends, and queue implementations. Inconsistent ad-hoc if/else selection for one provider while others use the factory creates maintenance confusion and makes the pattern untrustworthy.
**Apply when**: Adding new environment-switchable services to a codebase that already has a factory pattern.
**Forge-worthy**: yes — universal DRY/consistency pattern

## Manual useState+useEffect for Server Data (2026-03-17)
**Learning**: In projects using TanStack Query, manual `useState` + `useEffect` + fetch patterns for server data indicate framework misuse. These miss caching, deduplication, retry, background refetch, and optimistic updates. Common in admin/settings pages added later in the project lifecycle when the pattern isn't enforced. A quick grep for `useState.*loading.*true` or `useEffect.*api.get` catches these.
**Apply when**: Reviewing frontend code in TanStack Query projects, especially admin/settings pages.
**Forge-worthy**: yes — universal React data-fetching pattern
