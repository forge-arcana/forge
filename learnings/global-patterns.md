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

## pnpm --filter: exec vs Script Name (2026-03-15)
**Learning**: `pnpm --filter <pkg> <arg>` treats `<arg>` as a package.json script name. To run a binary (tsx, tsc, vitest, etc.) scoped to a workspace package, use `pnpm --filter <pkg> exec <binary> <args>`. Without `exec`, pnpm fails with `ERR_PNPM_RECURSIVE_RUN_NO_SCRIPT`. This commonly bites CI workflows where commands are written as raw shell rather than package scripts.
**Apply when**: Running CLI tools scoped to a specific workspace package in a pnpm monorepo.
