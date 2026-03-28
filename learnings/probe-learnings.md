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

## Supabase RLS Must Use JWT Claims, Not Subqueries (2026-03-28)
**Learning**: RLS policies with subqueries like `WHERE firm_id = (SELECT firm_id FROM profiles WHERE id = auth.uid())` re-execute the subquery per row — O(N) instead of O(1). The fix: store `firm_id` and `role` as custom JWT claims via a Supabase Auth hook, then use `auth.jwt()->'app_metadata'->>'firm_id'` in policies. This is a constant comparison with no subquery. Mark helper functions as `STABLE` not `IMMUTABLE` to avoid stale cache issues within transactions.
**Apply when**: Writing Supabase RLS policies for any multi-tenant app. Always use JWT claims over subqueries.

## Supabase + Drizzle Dual-Access Pattern for Complex Apps (2026-03-28)
**Learning**: For apps with 20+ tables and complex queries (joins, CTEs, aggregations, transactions), use BOTH Supabase JS client and Drizzle ORM. Supabase JS for: auth, realtime, storage, and simple client-side CRUD (benefits from RLS). Drizzle for: server-side queries, reports, transactions, and complex joins (bypasses RLS, so enforce auth in application code). Connect Drizzle via Supabase's connection pooler URL (port 6543, transaction mode), not direct connections (which exhaust limits from serverless functions).
**Apply when**: Starting any Supabase project with more than 15 tables or complex reporting requirements.

## LibreOffice in Docker Needs a Persistent Daemon (2026-03-28)
**Learning**: LibreOffice headless Docker images are 400MB-1.2GB. Each conversion spawns a fresh `soffice` process (1-3 second cold start, 200-500MB memory spike). For production: use Gotenberg (Go microservice wrapping LibreOffice with queuing) or unoserver (keeps LibreOffice as a persistent daemon). Never convert documents synchronously in an API request — always queue conversions. Budget $7-10/month for a dedicated conversion container, not $5 free tier.
**Apply when**: Adding document conversion to any project. Never put LibreOffice on a free-tier container.
