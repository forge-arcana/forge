# Global Patterns

> Cross-cutting patterns merged from all learning sources by `/fold`.

<!-- Add patterns below this line -->

## WSL Path Compatibility (2026-03-15)
**Learning**: When running across Windows + WSL2, tool configuration that references directories must include all 3 path formats: Windows (`D:\`), WSL-mount (`/mnt/d/`), native Linux (`/root/dev/`). Without all three, permission prompts re-appear depending on which environment the session runs from.
**Apply when**: Setting up any tool that uses directory allow-lists on a WSL2 machine.

## Configurable Paths via Resolution Chain (2026-03-15)
**Learning**: Never hardcode absolute paths in portable tools or skills. Use a resolution chain: (1) env var, (2) config file entry, (3) fallback default. This makes tools portable across machines and environments.
**Apply when**: Any tool or skill references a directory that varies by machine (repos, config dirs, data dirs).

## Global Config Over Per-Project Duplication (2026-03-15)
**Learning**: When a tool supports both global and per-project configuration, put all standard settings in the global config. Only create per-project config for overrides. Duplicating the full config into every project is a DRY violation that creates drift and maintenance burden.
**Apply when**: Setting up project-level configuration files for tools that also have a global config.

## Disable Rate Limiting in E2E Test Mode (2026-03-15)
**Learning**: E2E test suites run dozens of tests from a single IP in minutes, easily exceeding production rate limits. Gate rate limiting middleware with an environment check (e.g., `NODE_ENV !== "test"`) so tests aren't blocked. Rate limiting itself should have its own unit tests, not be tested implicitly via E2E.
**Apply when**: Adding rate limiting to a web server that has E2E tests.

## E2E Port Isolation from Dev Server (2026-03-15)
**Learning**: E2E test configs should use a dedicated test port constant or env var (e.g., `E2E_PORT`), never fall through to the dev server's `PORT`. With `reuseExistingServer: true`, tests silently connect to the running dev server instead of starting a fresh test server — causing mysterious failures from unrelated state.
**Apply when**: Configuring Playwright or similar E2E test runners in a project that also runs a dev server.

## Schema Enum Migration: Update All Raw SQL (2026-03-15)
**Learning**: After migrating string/text columns to database enums (pgEnum, MySQL ENUM, etc.), all raw SQL in test fixtures, E2E setup/cleanup, and seed scripts must be updated to use valid enum values. A value that worked with unconstrained text columns will throw constraint errors after migration.
**Apply when**: Converting text/varchar columns to enum types in any database.

## Test Factories Must Mirror DI Container (2026-03-15)
**Learning**: When adding a new service to the production DI container, always update test helper factories (e.g., `createTestApp`) to create and inject the same service. CI tests use the test factory, not the production startup — so a missing service causes `undefined` errors that only surface in CI, not local dev.
**Apply when**: Adding new services to a DI container in a project with separate test factory setup.

## Barrel Imports Break Vite in Monorepos (2026-03-19)
**Learning**: A shared package barrel (`index.ts`) that re-exports server-only code (pino, fs, path, crypto) causes Vite to pull Node.js modules into browser builds, failing with `"X" is not exported by "__vite-browser-external:path"`. Frontend files must use deep imports (`@pkg/utils/money.js`, `@pkg/constants/enums.js`) instead of the barrel. Enable with `"./*": "./src/*"` in package.json exports.
**Apply when**: Any monorepo where a shared package has both server-only AND browser-safe exports.

## Shared Package @/ Alias Breaks in Consumers (2026-03-19)
**Learning**: When app A's tsc processes files from a shared package via path mapping, the `@/` alias resolves using app A's tsconfig (not the shared package's). Fix: use relative imports in shared packages, never `@/` aliases.
**Apply when**: Creating shared packages in pnpm/npm workspaces with TypeScript path aliases.

## Integer Money Pattern (2026-03-19)
**Learning**: Store all currency as smallest-unit integers (cents/centavos) in the database. $19.95 → `1995`. Convert at boundaries: user input → `toSmallest()` before DB writes, `fromSmallest()` at payment provider boundary, `format()` for display. Eliminates floating-point drift. Industry standard (Stripe, Xendit, PayMongo, Square). ORM `numeric`/`decimal` types map to strings in most ORMs (Drizzle, Prisma), causing scattered cast bugs.
**Apply when**: Any project handling currency. Decide this on day one — retrofitting is painful.

## Error Handler Environment Check (2026-03-19)
**Learning**: `=== "production"` should be `!== "development"` for error handler stack trace visibility. Staging, preview, and unknown environments should hide stack traces too. Fail-safe toward production behavior.
**Apply when**: Writing error handlers that conditionally expose stack traces or debug info.

## Cross-SPA Navigation Must Use window.location.href (2026-03-19)
**Learning**: In multi-SPA architectures (separate Vite builds per role), cross-role redirects (login, role-switch, route guards) must use `window.location.href`. Framework router `navigate()` only works within a single SPA boundary — it can't cross to a different Vite build.
**Apply when**: Building multi-SPA apps where different roles/portals are separate Vite builds.

## XHR withCredentials for Cookie-Based Auth (2026-03-19)
**Learning**: When using HttpOnly cookie sessions (Better Auth, etc.), XHR requests (file uploads) must set `xhr.withCredentials = true`. Without it, cookies aren't sent and the upload gets 401. `fetch` with `credentials: "include"` has the same requirement.
**Apply when**: Any file upload or XHR request in a cookie-based auth system.

## pnpm --filter: exec vs Script Name (2026-03-15)
**Learning**: `pnpm --filter <pkg> <arg>` treats `<arg>` as a package.json script name. To run a binary (tsx, tsc, vitest, etc.) scoped to a workspace package, use `pnpm --filter <pkg> exec <binary> <args>`. Without `exec`, pnpm fails with `ERR_PNPM_RECURSIVE_RUN_NO_SCRIPT`. This commonly bites CI workflows where commands are written as raw shell rather than package scripts.
**Apply when**: Running CLI tools scoped to a specific workspace package in a pnpm monorepo.
