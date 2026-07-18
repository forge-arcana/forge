# /poke Learnings

> Populated by `/poke` runs across projects. Absorbed into forge by the `/forge` cycle.

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

## Pino Logger Exists But Nobody Calls It (2026-03-28)
**Learning**: When agents build modules in parallel, they all import and instantiate the logger but may not actually call log.info/warn/error in the code paths. Verify that logger calls exist on both success AND failure paths — not just the import statement. The forge-scan detects `logger.` calls, so zero matches despite imports means the logger is dead code. In this case, the server actions DID log correctly (58 calls), but middleware and auth had zero logging despite being the security layer.
**Apply when**: Reviewing any codebase where logging infrastructure was set up by one agent and consumed by others. Check for dead logger imports.

## Edge Runtime Logger Compatibility (2026-03-28)
**Learning**: Next.js middleware runs in the Edge Runtime, which does not support Node.js APIs like `fs` or `net`. Pino relies on Node.js streams and won't work in edge middleware. For edge-compatible logging, use `console.warn` with structured JSON objects as a fallback, or a lightweight edge-compatible logger. Don't import Pino in middleware.ts.
**Apply when**: Adding logging to Next.js middleware or any Edge Runtime code.

## Bash Script Exit Code Semantics — Always Exit 0 Masks Failures (2026-05-06)
**Learning**: When a bash script always exits 0 regardless of outcome (to "never fail the caller"), it prevents the caller from distinguishing success, no-op, transient failure, and permanent failure. Use exit codes to signal outcome: 0=success/no-op, 1=transient failure (retry later), 2=permanent failure (missing dependency, corrupt config). Callers can then decide whether to retry, escalate, or ignore. The "always exit 0" pattern is appropriate only for optional enhancements (e.g., a cache warmup that shouldn't block the main workflow), not for critical operations where the caller needs to know if the action succeeded.
**Apply when**: Writing bash scripts that are invoked by other scripts or automation, especially for operations with multiple failure modes (missing dependencies, network errors, corrupt state).

## Bash Function Decomposition — Extract Before 200 Lines (2026-05-06)
**Learning**: Bash scripts that exceed 200 lines with multiple responsibilities (path resolution, remote sync, drift detection, status reporting) become hard to test, debug, and reuse. Extract each responsibility into a named function that outputs its section independently. The main script becomes an orchestrator. This mirrors the Single Responsibility Principle from OOP but applies to procedural scripts. Functions enable: (1) testing individual pieces in isolation, (2) reusing logic across scripts, (3) clearer error handling (each function can exit with its own code), (4) easier debugging (set -x on one function, not the whole script).
**Apply when**: Writing bash scripts longer than 100 lines, or when a script does more than one conceptually distinct thing (e.g., "check status AND deploy" should be two functions).

## Bash Shared Utilities — Extract Duplicate Functions to lib/ (2026-05-06)
**Learning**: When multiple bash scripts define identical utility functions (Windows path conversion, JSON parsing wrappers, verification patterns), extract them to a shared `lib/` directory and source them. This prevents drift where one script's version gets a bug fix but others don't. The pattern: create `scripts/lib/utils.sh` with shared functions, then `source "$SCRIPT_DIR/lib/utils.sh"` at the top of each script. For portability, resolve `$SCRIPT_DIR` with `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` so sourcing works regardless of how the script is invoked.
**Apply when**: Writing the second script that needs a function you already wrote in another script (DRY principle).

## Bash Dependency Checks — Fail Fast with Clear Error Messages (2026-05-06)
**Learning**: When a bash script depends on external tools (jq, python3, gh, rg), check for them at script start and exit with a clear error message if missing. Silent degradation (outputting empty strings or "0" when the tool is missing) makes debugging hard — the user sees "No results found" when the real issue is "jq not installed". The pattern: `if ! command -v jq >/dev/null 2>&1; then echo "ERROR: jq not found. Install with: sudo apt-get install jq"; exit 2; fi`. Use exit code 2 for missing dependencies (permanent failure), not 1 (transient failure).
**Apply when**: Writing any bash script that calls external tools (not just built-ins like grep, awk, sed).

## Repeated Auth Guards Belong in One Decorator/Middleware, Not Copy-Pasted Per Handler (2026-06-21)
**Learning**: When N route handlers each open with the same authentication/authorization guard (resolve caller → return 401/redirect if absent), copy-pasting that block is a security-grade DRY violation, because the guards drift: one handler later gains a tightened check (a new role test, an expiry check, a CSRF check) and the sibling copies silently don't — opening a gap that still *reads* as "protected" at every call site. Extract the guard into ONE decorator/middleware, parameterized by the only thing that legitimately differs between routes — usually the unauthenticated RESPONSE shape (JSON 401 for API routes vs 302 redirect for page routes). A single definition enforces the policy uniformly and means a new check lands on every protected route at once. This is SRP + OCP applied to a cross-cutting concern: the auth policy gets one reason to change and one place to change it.
**Apply when**: Reviewing any codebase where multiple endpoints repeat an inline auth/authorization check. If the same guard appears 3+ times, propose a decorator/middleware; verify the extraction preserves per-route differences (response type, required role) as parameters rather than forking the guard.

## Status Layers Must Separate HANDLED Events From Genuine Failures (2026-07-09)
**Learning**: A run-summary or monitoring layer that flags every error-marker — a `✗` line, any caught exception, any retry — as a "failure" makes HEALTHY runs read as broken. The operator sees ERROR daily even when the system handled everything, so real failures become indistinguishable from noise (alert fatigue) and trust erodes into "why can we never have a clean run?". Classify events by the only question that matters: **does a human have to act?** Transient-and-retried, gracefully-degraded (fell back, kept previous state), quality-control skips (a guard rejecting bad output is the guard WORKING), and standing advisories (an available-not-required upgrade) belong in an informational NOTICES tier that does NOT colour run status. Only unrecoverable breakage needing a human is an error — a run that did its job reads "ok". Persistent versions of a soft event (a slot empty for days, a fallback firing every run) get escalated by a SEPARATE detector, so a one-off is correctly just a notice. Key: share the classification list between the status summariser and any independent alert scanner, or the status badge and the alert panel will disagree.
**Apply when**: Building or reviewing any cron/pipeline/CI summary or ops dashboard. If healthy runs render as ERROR, the classifier — not the pipeline — is the bug.

## Manual useState+useEffect for Server Data (2026-03-21)
<!-- relocated from global-patterns.md by /forge learning review, 2026-07-14 — a review-time framework-misuse heuristic, which is poke's territory -->
**Learning**: In projects using TanStack Query, manual `useState` + `useEffect` + fetch patterns for server data indicate framework misuse. These miss caching, deduplication, retry, background refetch, and optimistic updates. Common in admin/settings pages added later in the project lifecycle when the pattern isn't enforced. A quick grep for `useState.*loading.*true` or `useEffect.*api.get` catches these.
**Apply when**: Reviewing frontend code in TanStack Query projects, especially admin/settings pages.
