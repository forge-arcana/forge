# Architecture Learnings

> Populated by `/arch` runs across projects. Absorbed into forge by `/reforge`.

<!-- Add learnings below this line -->

## Drizzle Programmatic Migration Journal Schema (2026-03-15)
**Learning**: Drizzle's `migrate()` stores applied migrations in schema `drizzle` (not `public`) in table `__drizzle_migrations`. When switching an existing DB from `drizzle-kit push` to versioned migrations, seed the journal by creating the `drizzle` schema + table and inserting a row for the baseline migration. The migrator compares `created_at` (bigint timestamp) to decide which migrations to run.
**Apply when**: Transitioning from drizzle-kit push to versioned migrations on an existing database.
