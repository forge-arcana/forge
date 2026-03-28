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

## Client-Supplied Identity in Validation Schemas (2026-03-21)
**Learning**: When a validation schema accepts an identity field (e.g., `targetUserId`, `ownerUserId`) from the request body for an authenticated endpoint, the backend must verify the relationship between the caller and the referenced entity — not just that the entity exists. Without engagement/relationship verification, any authenticated user can target arbitrary entities with false claims. Especially dangerous for complaint, dispute, and review endpoints.
**Apply when**: Reviewing any endpoint that accepts an entity ID from the request body and creates a record linking the caller to that entity.

## Leaflet Map Z-Index Blocks Nearby Dropdowns (2026-03-22)
**Learning**: Leaflet map tiles use `z-index: 200-800` internally. Any absolutely positioned dropdown (autocomplete, select, popover) rendered near a Leaflet map container will be hidden behind the map tiles if using standard z-index values (e.g., `z-50`). Use `z-[1000]` or higher for dropdowns adjacent to maps.
**Apply when**: Building search/autocomplete UI components that render near Leaflet or similar map libraries.

## Schema Defaults Must Match Code Defaults (2026-03-21)
**Learning**: When auditing DB schemas, verify that column defaults match what the application code actually inserts. A default of `'occupied'` when code always inserts `'empty'` is a bug waiting to happen. Unused schema defaults are silent time bombs — they only fire when someone forgets to specify the value explicitly, and then they produce wrong data instead of an error.
**Apply when**: Reviewing database schemas for tech debt, especially columns with default values that aren't tested by normal application flows.

## Pino Logger Exists But Nobody Calls It (2026-03-28)
**Learning**: When agents build modules in parallel, they all import and instantiate the logger but may not actually call log.info/warn/error in the code paths. Verify that logger calls exist on both success AND failure paths — not just the import statement. The forge-scan detects `logger.` calls, so zero matches despite imports means the logger is dead code. In this case, the server actions DID log correctly (58 calls), but middleware and auth had zero logging despite being the security layer.
**Apply when**: Reviewing any codebase where logging infrastructure was set up by one agent and consumed by others. Check for dead logger imports.

## Edge Runtime Logger Compatibility (2026-03-28)
**Learning**: Next.js middleware runs in the Edge Runtime, which does not support Node.js APIs like `fs` or `net`. Pino relies on Node.js streams and won't work in edge middleware. For edge-compatible logging, use `console.warn` with structured JSON objects as a fallback, or a lightweight edge-compatible logger. Don't import Pino in middleware.ts.
**Apply when**: Adding logging to Next.js middleware or any Edge Runtime code.
