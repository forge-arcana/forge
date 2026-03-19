# /probe Learnings

> Accumulated learnings from probe sessions (architecture review). Absorbed by `/fold`.

<!-- Add learnings below this line -->

## Drizzle Programmatic Migration Journal Schema (2026-03-15)
**Learning**: Drizzle's `migrate()` stores applied migrations in schema `drizzle` (not `public`) in table `__drizzle_migrations`. When switching an existing DB from `drizzle-kit push` to versioned migrations, seed the journal by creating the `drizzle` schema + table and inserting a row for the baseline migration. The migrator compares `created_at` (bigint timestamp) to decide which migrations to run.
**Apply when**: Transitioning from drizzle-kit push to versioned migrations on an existing database.

## Migration Fixup Scripts Must Guard Against Fresh DBs (2026-03-15)
**Learning**: Pre-migration fixup SQL (e.g., `ALTER TABLE X ADD COLUMN IF NOT EXISTS`) crashes on fresh databases where the base table doesn't exist yet. Always wrap fixups in a table-existence check (`SELECT 1 FROM information_schema.tables WHERE table_name='X'`). Only run fixups when the table exists (i.e., DB was created via a different mechanism); skip on fresh DBs where the initial migration creates everything from scratch.
**Apply when**: Writing database migration fixup or pre-migration scripts that may run against both existing and fresh databases.

## Drizzle Migration Strategy: Versioned for Persistent, Push for Ephemeral (2026-03-19)
**Learning**: Use versioned migrations (`db:migrate`) for production and any persistent database. Reserve `drizzle-kit push` only for ephemeral/throwaway databases (CI test runs, local dev reset). Mixing push and migrate on the same persistent DB causes drift — push doesn't track migration history, so `migrate()` can't know what's already applied. Deploy pipelines should auto-stamp the baseline migration before running `db:migrate` on databases that were originally created via push.
**Apply when**: Setting up a Drizzle project's migration strategy, or transitioning from push-only to versioned migrations.
