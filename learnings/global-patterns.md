# Global Patterns

> Cross-cutting patterns merged from all learning sources by `/fold`.

<!-- Add patterns below this line -->

## WSL Path Compatibility (2026-03-15)
**Learning**: When running across Windows + WSL2, tool configuration that references directories must include all 3 path formats: Windows (`D:\`), WSL-mount (`/mnt/d/`), native Linux (`/root/dev/`). Without all three, permission prompts re-appear depending on which environment the session runs from.
**Apply when**: Setting up any tool that uses directory allow-lists on a WSL2 machine.


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

## Mobile Testing Progression: Browser → Emulator → Device → Store (2026-03-21)
**Learning**: Start mobile development testing in the browser (DevTools device mode, F12 → target device). As the product matures, build APKs for local device testing. For iteration velocity, lean heavily on emulators. Only pursue Play Store / App Store integration when the product is solid — store submissions have cost (developer accounts, review cycles, compliance), so readiness matters before that step.
**Apply when**: Setting up the testing strategy for any mobile-first or hybrid app project. Decide this progression on day one.

## Camera getUserMedia Succeeds But Produces Black Feed on Emulators (2026-03-21)
**Learning**: Android emulators with `hw.camera.back=emulated` return a valid MediaStream from `getUserMedia()` but produce a black/checkerboard feed — no error thrown, so `catch`-based fallbacks miss it. Fix: (1) use `hw.camera.back=virtualscene` for testable video, (2) always show manual-entry alongside the camera viewfinder (silent failure can't be reliably detected).
**Apply when**: Building camera features (QR scanner, barcode, photo) in hybrid apps tested on Android emulators.

## Android AVD Segregation Across Projects (2026-03-21)
**Learning**: Prefix AVDs with project name (`<project>-<role>`) to avoid collisions across projects sharing an Android SDK. Nuke commands must clean orphaned `.avd` data dirs under `ANDROID_AVD_HOME` — left behind when emulators run during `avdmanager delete`. Each project owns its own emulator config; no shared state.
**Apply when**: Setting up Android emulator workflows for Capacitor/hybrid projects in multi-project environments.

## Voice TTS Is the Dominant Cost at Scale (2026-03-21)
**Learning**: For voice-first apps, TTS API cost is the single biggest scaling concern. At low user counts, TTS can be ~50% of total infrastructure cost. Making voice playback opt-in is both a good UX decision (avoids uncanny valley) and a critical cost lever. Always model voice costs separately and identify which tier boundary triggers the cost jump.
**Apply when**: Any voice-first product — model TTS costs as the primary scaling constraint.

## Three-Layer Architecture as Cost Control (2026-03-21)
**Learning**: For AI-powered apps with high-frequency input, separating processing into layers with different cost profiles (free capture → cheap classification → expensive generation only on-demand) makes the product viable for solo founders. Most user interactions touch only the cheap layers. The expensive layer fires only when the user explicitly asks. This is an architecture decision that IS a business decision.
**Apply when**: Designing any AI-powered product — layer processing by cost, make expensive layers on-demand.

## Offline-First Is Non-Negotiable for Capture Apps (2026-03-21)
**Learning**: When the core use case happens in a place with no internet (commute, underground, spotty signal), offline-first isn't a nice-to-have — it's the difference between the product working and not working. Auto-sync (not manual push) is correct because the whole point of a capture app is reducing cognitive load. Requiring the user to remember to sync defeats the purpose.
**Apply when**: If your primary use case happens offline, offline-first is table stakes.

## Trust Ladder Onboarding for Sensitive Features (2026-03-21)
**Learning**: When a product requires sensitive data (voice biometrics, diary-level thoughts), don't ask for everything upfront. Build a trust ladder: deliver core value first (basic features), then progressively unlock sensitive features (voice input → voice customization). The user should feel "of course I'll give you this" by the time you ask, not "why do you need this?"
**Apply when**: Any app requiring biometric or deeply personal data — design the onboarding progression.

## Modes as a Volume Dial, Not Separate Machines (2026-03-21)
**Learning**: When a product has multiple "modes" of interaction, check whether these are genuinely different processing pipelines or just different amounts of the same processing. Often all modes use the same engine — the mode is injected as context into one system prompt. This avoids maintaining N separate AI pipelines. The modes are a "volume dial" of AI involvement: from zero (quick action) to full (open dialogue with history).
**Apply when**: Prefer one adaptive system over many specialized systems when the variation is in degree, not kind.

## Provider Factory Consistency (2026-03-21)
**Learning**: When a codebase establishes a provider factory pattern (e.g., `createProvider<T>(envKey, registry, fallback)`), ALL environment-driven service selection should use it — including rate limit stores, cache backends, and queue implementations. Inconsistent ad-hoc if/else selection for one provider while others use the factory creates maintenance confusion and makes the pattern untrustworthy.
**Apply when**: Adding new environment-switchable services to a codebase that already has a factory pattern.

## ML/OCR Confidence Defaults Must Reject, Not Pass (2026-03-21)
**Learning**: Defaulting missing confidence scores to a HIGH value (e.g., 0.9) means unscored items silently pass as confident. Always default to 0 (reject by default) for safety/trust/verification scoring. A missing score is unknown confidence — treating it as high confidence is a silent bug.
**Apply when**: Reviewing default values for ML confidence scores, trust scores, verification scores, or any probability-based threshold.

## Manual useState+useEffect for Server Data (2026-03-21)
**Learning**: In projects using TanStack Query, manual `useState` + `useEffect` + fetch patterns for server data indicate framework misuse. These miss caching, deduplication, retry, background refetch, and optimistic updates. Common in admin/settings pages added later in the project lifecycle when the pattern isn't enforced. A quick grep for `useState.*loading.*true` or `useEffect.*api.get` catches these.
**Apply when**: Reviewing frontend code in TanStack Query projects, especially admin/settings pages.


## AI Timestamps Are Unreliable (2026-03-26)
**Learning**: Do not add conventions requiring AI agents to prefix messages with wall-clock timestamps (e.g., `[HH:MM]`) or report elapsed times after tool calls. The agent's reported times are not accurate and add noise without value. If timing matters, instrument it at the tool/platform level, not in agent output formatting.
**Apply when**: Designing output formatting conventions for AI agents or reviewing proposals that include timestamp requirements.


## Real-Time WebSocket ≠ Push Notifications (2026-03-26)
**Learning**: WebSocket real-time (Ably, Pusher, Socket.io) and push notifications (FCM/APNs) solve different problems. WebSockets deliver updates while the app is open — they require an active connection. Push notifications reach users when the app is closed or backgrounded — they require platform-specific infrastructure (Firebase project, APNs key, server-side device token storage). For pilot/MVP launches with small user bases, WebSocket real-time is sufficient. Push notifications add significant infrastructure complexity (two vendor integrations, token lifecycle management, platform review requirements) and can be deferred to a post-launch sprint informed by real engagement data.
**Apply when**: Scoping real-time features for mobile apps. Don't conflate "real-time updates" with "push notifications" — decide which you actually need for launch.

## Configurable Paths via Resolution Chain (2026-03-15)
**Learning**: Never hardcode absolute paths in portable tools or skills. Use a resolution chain: (1) env var, (2) config file entry, (3) fallback default. This makes tools portable across machines and environments.
**Apply when**: Any tool or skill references a directory that varies by machine (repos, config dirs, data dirs).

## Global Config Over Per-Project Duplication (2026-03-15)
**Learning**: When a tool supports both global and per-project configuration, put all standard settings in the global config. Only create per-project config for overrides. Duplicating the full config into every project is a DRY violation that creates drift and maintenance burden.
**Apply when**: Setting up project-level configuration files for tools that also have a global config.

## Android 15 Edge-to-Edge Status Bar Overlap in Capacitor (2026-03-22)
**Learning**: Android 15 (API 35) enforces edge-to-edge rendering by default — app content renders behind the status bar. `StatusBar.setOverlaysWebView({ overlay: false })` is silently ignored. CSS `env(safe-area-inset-top)` returns `0px` on Android WebView (only `safe-area-inset-bottom` works). `WindowCompat.setDecorFitsSystemWindows(window, true)` in MainActivity also fails — Capacitor's BridgeActivity overrides it. The only working fix in Capacitor 7 is `android: { adjustMarginsForEdgeToEdge: "force" }` in `capacitor.config.ts`. Do NOT stack multiple fixes — they each add padding independently, causing a visible gap.
**Apply when**: Building Capacitor Android apps targeting API 35+ where content overlaps system status bar.

## Self-Flagging Learnings (2026-03-26)
**Learning**: When a skill generates learnings, it should self-classify each as "forge-worthy" or "project-specific" at write time. Downstream consumers (like commit rituals or absorption tools) can then auto-promote flagged entries without heuristic judgment. This eliminates guessing and ensures universal patterns reach the shared knowledge base.
**Apply when**: Designing learning/knowledge capture systems where entries need to be triaged for promotion to a shared store.

## Processing Tracker for Idempotent Absorption (2026-03-26)
**Learning**: When a system absorbs entries from a source it doesn't own (and can't delete from), maintain a tracker file with content hashes or titles of already-processed entries. This makes absorption idempotent — each run only evaluates new entries, not the full history. Without a tracker, every run re-triages everything, leading to duplicate work and potential inconsistencies.
**Apply when**: Building any pipeline that reads from append-only sources (log files, learning files, changelog) and needs to process each entry exactly once.

## Self-Contained Skill Packages (2026-03-26)
**Learning**: When skills reference documentation or frameworks, those files must live inside the skill's directory — not in a separate shared location. Static reference docs at repo root become stale orphans because the skill self-iterates but the orphaned doc doesn't. Co-locating ensures everything evolves together.
**Apply when**: Structuring skill or plugin directories in any system where skills/plugins reference supplementary docs or frameworks.

## Thin Bootstrap for Skill Discovery (2026-03-26)
**Learning**: When a skill repo needs a particular skill to be discoverable on fresh clone (before global deployment), use a thin bootstrap file in the project's local skill directory that simply points to the real skill file. Avoids symlinks (OS-dependent behavior) and full duplication (drift risk). The bootstrap is 3 lines; the real skill lives in the source directory.
**Apply when**: Setting up local skill discovery in repos that are also the source of truth for those skills.

## Three-Way Drift Detection for Bidirectional Sync (2026-03-26)
**Learning**: When a system syncs files bidirectionally (source repo ↔ deployed copies), use a three-way comparison: source vs manifest vs deployed. This catches four cases: source updated (deploy it), deployed updated (reverse-sync it back), both updated (conflict — manual review), neither (skip). A two-way comparison (source vs deployed) can't distinguish "source is newer" from "deployed is newer" without a baseline.
**Apply when**: Designing any bidirectional file sync mechanism between a source of truth and deployed copies.

## Fold/Cast Race Condition on Direct Source Edits (2026-03-26)
**Learning**: When source-of-truth files are edited directly, deployed copies in the sync target become stale instantly. If the absorption command runs from another session before the deployment command updates the target, it sees DIFFERS and absorbs the stale deployed version — silently reverting the source edit. This is a race condition in bidirectional sync: concurrent sessions can undo each other's work via the absorption path. Prevention: always run the deployment command immediately after direct source edits.
**Apply when**: Operating any bidirectional sync system (deploy + absorb) where source files are edited directly.

## Firebase API Key Restriction for Public Repos (2026-03-29)
**Learning**: Firebase API keys are project identifiers (not secrets), but in public repos, ALWAYS restrict the key to the deployment domain via Google Cloud API Keys API. Add HTTP referrer restrictions (deployment domain + `localhost/*` + `127.0.0.1/*`). Security rules protect data integrity, but unrestricted keys let unauthorized apps consume quota or abuse Firebase resources from other origins.
**Apply when**: Setting up Firebase in any project, especially public repos or GitHub Pages sites.

## Silent Browser API Failures — Check Security Headers FIRST (2026-03-29)
**Learning**: When a browser API (`getUserMedia`, `Notification.requestPermission`, `navigator.geolocation`) fails silently — no prompt, no error UI, just a quiet `NotAllowedError` — the root cause is almost always a `Permissions-Policy` response header blocking it. `curl -sI <url> | grep -i permissions-policy` is step 0 before reading any client code. The HTML `capture` attribute on `<input type="file">` is also silently ignored when the policy blocks camera.
**Apply when**: Any browser API behaves as if the user denied permission but no prompt was ever shown.

## Bot and Crawler Protection Strategy (2026-03-29)
**Learning**: Bot/crawler access must be controlled at every deployment tier — not just staging.

**Non-production (staging, preview, dev) — block crawlers, but distinguish internal vs customer-facing.**

*Internal staging* (only developers/QA access): layer all defenses — (1) `robots.txt` with `Disallow: /` and `X-Robots-Tag: noindex, nofollow` response header, (2) IAM-gated access on Cloud Run (`--no-allow-unauthenticated`), (3) basic auth or IP allowlisting as fallback, (4) `noindex` meta tag in HTML `<head>`. Wire into the deploy pipeline — every `deploy.yml` targeting internal non-production must include bot protection as a required step.

*Customer-facing staging* (beta testers, drivers, passengers use it): IAM gating (`--no-allow-unauthenticated`) locks out real users. Keep `--allow-unauthenticated` and rely on app-level bot protection only: `robots.txt Disallow: /` + `X-Robots-Tag: noindex, nofollow` header + `noindex` meta tag. Well-behaved crawlers respect these; malicious scrapers bypass them, but IAM gating isn't viable when real unauthenticated users need access.

**Production — public pages only.** Only public-facing, unauthenticated pages (marketing, landing, docs, blog) should allow crawling for SEO. Everything behind authentication — dashboards, admin panels, internal tools, private APIs — must block bots. Serve `robots.txt` with targeted `Disallow` rules for authenticated paths. Set `X-Robots-Tag: noindex` on all responses that require auth. Never expose private services to crawlers — a bot that reaches an admin panel or internal API is a security incident waiting to happen.

**Platform specifics**: GCP Cloud Run `--no-allow-unauthenticated` blocks all traffic at the infrastructure level. Vercel Password Protection, AWS WAF IP restrictions, Netlify Identity for other platforms.
**Apply when**: Deploying any application to any environment. Non-production: check whether real end users need unauthenticated access — internal staging gets IAM gating, customer-facing staging gets app-level headers only. Production = allow crawling only on public-facing pages, block on private services.

## Reverse-Sync Must Write to Source, Not Deployed Copies (2026-03-28)
**Learning**: A reverse-sync process that classifies entries from a staging file into category-specific files must write to the **source repo copies**, NOT the **deployed copies**. Writing only to deployed copies creates a permanent gap: deployed has more entries than source, and every status check reports "new entries — sync needed." Re-running doesn't fix it because the staging file entries are already marked as processed in the tracker.
**Apply when**: Building or debugging any bidirectional sync system where a staging area feeds into categorized files. The write target must always be the source of truth.

## Forward-Sync Must Not Duplicate Global Config Content (2026-03-28)
**Learning**: A forward-sync that deploys conventions into a project workspace must check whether the global config layer already covers a convention before adding it to the project-level config. Duplicating rules (shorthand commands, hard rules, style guides) across global and project config creates maintenance drift. The user has corrected this pattern multiple times.
**Apply when**: Running forward-sync on any project. Skip adding sections that already exist in the global config layer.

## Next.js 16 Process Renaming Breaks Zombie Kill Scripts (2026-03-29)
**Learning**: Next.js 16 renames its dev server process to `next-server (v16.x.x)` — a custom process title with no `node`, `next dev`, or project name in the command string. Standard pgrep patterns (`node.*next.*dev`, `node.*(next|playwright).*<project>`) miss it entirely. The process also auto-selects non-standard ports when the configured port is busy, so port-based `fuser -k` also misses it. Kill/restart scripts must match the literal string `next-server` and scope to the project by checking `/proc/$PID/cwd`.
**Apply when**: Writing or updating restart/kill-zombie scripts for any Next.js 16+ project. The `/srs` skill templates need this pattern.

## Persist TTS Audio on First Generate, Not Every Play (2026-03-29)
**Learning**: Voice TTS APIs charge per generation. Every "Listen" tap that hits the API is wasted money if the text hasn't changed. Persist audio on first generation: store base64 in a DB column (voice samples on the user record, message audio in a jsonb map keyed by message index). Serve the stored file on subsequent plays — zero API cost. For voice clone samples, generate and persist at clone time so the preview is instant.
**Apply when**: Any app with TTS playback — never regenerate audio for the same text twice.

## WebSocket Streaming TTS for Low-Latency Voice Dialogue (2026-03-29)
**Learning**: Full TTS generation (send text → wait for complete WAV → play) adds 3-5s latency for long messages. WebSocket streaming TTS sends PCM audio chunks as they're generated — first audio plays in ~200-500ms. On the client, use AudioContext to schedule and play raw PCM chunks as they arrive. Fall back to non-streaming if WebSocket fails. Essential for voice dialogue loops where latency kills the conversational feel.
**Apply when**: Any real-time voice dialogue feature — always use streaming TTS, never wait for the full audio file.

## Voice Clone Consent Flow Is a Legal Requirement (2026-03-29)
**Learning**: Voice biometrics are sensitive data under GDPR, UK DPA, and emerging US state laws. Before cloning a user's voice, present a dedicated consent screen with: what you collect (audio sample), how it's used (private TTS only), user rights (delete anytime), and third-party processing disclosure (name the provider). Use a checkbox-based explicit consent mechanism — implied consent from "tapping record" is insufficient.
**Apply when**: Any feature that processes voice biometrics — clone, voiceprint, speaker ID. Not needed for plain speech-to-text.

## Fire-and-Forget Background Processing Keeps Capture Instant (2026-03-29)
**Learning**: When a user captures input, the response must feel instant (<200ms). Heavy processing (LLM classification, theme assignment, TTS pre-generation) should fire-and-forget after the capture response is sent. Use `promise.catch(() => {})` pattern — don't await. The user sees results on next view. This is the "three-layer cost architecture" in practice: capture is free/instant, processing is async/cheap, generation is on-demand/expensive.
**Apply when**: Any capture-first app where input frequency is high and processing is heavy.
