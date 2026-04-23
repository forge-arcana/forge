# /probe Learnings

> Accumulated learnings from probe sessions (architecture review). Absorbed by the `/forge` cycle.

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

## Free Tier Limits Change Without Notice (2026-03-29)
**Learning**: Cloud API providers silently change free tier limits without announcements. Always verify current limits against the actual API pricing page at architecture review time, never trust cached or remembered values. Secondary models or tiers may become the practical workhorse when primary tier limits drop.
**Apply when**: evaluating any cloud API free tier during architecture review or probe — verify limits are current, not assumed.

## ML Library Language Ecosystem Compatibility (2026-03-29)
**Learning**: Python ML libraries (speech processing, embeddings, computer vision) often have no JavaScript/WebView implementation path. When a blueprint specifies an ML model for on-device mobile use in a hybrid app, verify the language ecosystem compatibility first. ONNX export + native runtime is the bridge, but adds significant complexity vs. a server-side approach.
**Apply when**: any blueprint or architecture that specifies ML inference on a mobile/hybrid client — verify the model has a JS-compatible runtime or plan for server-side inference.

## Unlimited Neural TTS via Edge TTS Package (2026-03-29)
**Learning**: The `edge-tts-universal` npm package provides unlimited access to Microsoft neural TTS voices (same quality as paid Azure TTS) with no API key and no monthly limit. Superior to cloud TTS free tiers for any project where the monthly character ceiling is a concern.
**Apply when**: selecting a TTS provider for any voice-enabled project — evaluate this zero-cost option before committing to a paid TTS API.

## Serverless DB + Container Cold Start Warming Strategy (2026-03-29)
**Learning**: Scale-to-zero serverless databases (300-500ms cold start) combined with scale-to-zero compute containers (2-5s cold start at min-instances=0) produce first-request latencies of 4-9 seconds. A health-check cron every 4 minutes during business hours is the free-tier warming strategy.
**Apply when**: deploying any app on serverless DB + serverless compute free tiers where scale-to-zero is enabled.

## iframe Sandbox Defense-in-Depth for AI-Generated Content (2026-03-29)
**Learning**: `sandbox="allow-scripts"` without `allow-same-origin` prevents the classic sandbox escape, but is insufficient alone for AI-generated HTML. LLM output injection (OWASP LLM05:2025) means the generated content itself is the attack surface. Required layers: (1) serve from separate origin, (2) CSP headers `connect-src 'none'` to block exfiltration, (3) server-side DOMPurify sanitization before storage, (4) content safety scan before first render (not async post-publish).
**Apply when**: Any platform serving AI-generated content in sandboxed iframes.

## Auth Libraries With Flat User Models Need Custom Sub-Profile Tables (2026-03-29)
**Learning**: Auth libraries with flat data models (User → Account, e.g., Better Auth) have no native support for hierarchical relationships like parent-child accounts. Organization plugins are for SaaS tenancy, not family structures. The correct pattern: auth library handles primary user auth only; subordinate profiles (children, sub-accounts) use a first-party table with scoped session tokens managed entirely by application code. This is what Netflix, Disney+, and Roblox do.
**Apply when**: Any project using an auth library that needs hierarchical user relationships (parent-child, manager-employee, guardian-ward).

## Scalability Analysis Belongs in /probe, Not /press or /pound (2026-04-02)
**Learning**: Scalability is an architecture concern ("does this design scale?"), not an ops concern ("are we ready to deploy?"). It belongs in `/probe` as a "Scaling Runway" evaluation section that assesses: (1) stateless request handling, (2) database scaling path (pooling → replicas → partitioning → sharding), (3) external dependency scaling (AI provider, CDN, queue), (4) what user count triggers each scaling tier. Present as a table: user range → required change → effort level. `/press` evaluates current state (go-live readiness); `/probe` evaluates future state (design validity). A scaling ceiling is a design flaw, not a deployment gap.
**Apply when**: Running `/probe` on any blueprint or architecture. The scaling runway should be part of every probe report.
