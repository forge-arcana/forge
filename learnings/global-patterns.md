# Global Patterns

> Cross-cutting patterns merged from all learning sources by the `/forge` cycle.

<!-- Add patterns below this line -->

## h-full vs min-h-full in Scroll-Container Chains (2026-06-02)
**Learning**: In a flex-column scroll container chain, `min-height: 100%` does NOT establish a height reference for children's `justify-center` — only `height: 100%` does. For cards that must both center short content AND allow expansion for dense content: chain is `overflow-y-auto (fixed height)` → `h-full` wrapper → `min-h-full` content div. The `min-h-full` expands for dense content (overflow handled by scroll container), while `justify-center` still works for short content because the div fills to its min-height.
**Apply when**: any scrollable card with vertically centered content that can also overflow.

## Structural Inset for Decorated Scroll Backgrounds (2026-06-02)
**Learning**: When a scroll area's background image has decorative zones (borders, corner ornaments, framing elements), CSS padding-based safe zones fail — scrolled content flows freely through those zones regardless of padding. Only reliable solution: outer div (`overflow-hidden` + background image), inner div (`position: absolute; top: X%; bottom: Y%; overflow-y-auto`). Content is physically bounded within the safe zone. CSS padding, mask-image, and gradient overlays are incomplete substitutes.
**Apply when**: any scrollable UI panel with a decorated or framed background image where content must not enter the decoration zone.

## CSS Percentage Padding Is Width-Based, Not Height-Based (2026-06-02)
**Learning**: `padding-top: 8%` (or Tailwind `pt-[8%]`) computes to 8% of the containing block's **width**, not its height. On a tall portrait mobile card (e.g. 360×640px), `pt-[8%]` = 29px — far less than 8% of the 640px height (51px). When using percentage padding for vertical clearance against height-relative zones (e.g. image ornaments covering 10% of card height), always verify the absolute pixel equivalent. Consider using `vh`-based or fixed-pixel values for height-sensitive vertical clearances.
**Apply when**: any vertical safe-zone or clearance calculation using percentage padding on portrait/mobile layouts.

## Show-Once Flag Must Be Written Inside the Async Callback (2026-06-02)
**Learning**: Writing a "seen" flag to localStorage BEFORE a setTimeout (or any async callback) fires permanently marks the event as triggered before it happens. If the user navigates away during the delay, the milestone/modal/notification is permanently suppressed. Pattern: write the flag INSIDE the callback with a re-check guard: `setTimeout(() => { if (!localStorage.getItem(key)) { localStorage.setItem(key, "1"); show(); } })`. The re-check also prevents double-firing when the same component is mounted twice (e.g. layout + page both render the same component).
**Apply when**: any "show once" modal, tooltip, or notification triggered by a timer, scroll event, or async callback using localStorage as the deduplication mechanism.

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

## Shared Package @/ Alias Breaks in Consumers (2026-03-19)
**Learning**: When app A's tsc processes files from a shared package via path mapping, the `@/` alias resolves using app A's tsconfig (not the shared package's). Fix: use relative imports in shared packages, never `@/` aliases.
**Apply when**: Creating shared packages in pnpm/npm workspaces with TypeScript path aliases.

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

## TTS Economics: Cache, Stream, Treat as Primary Cost Driver (2026-03-29)
**Learning**: For voice-first apps, TTS API spend is typically the single biggest scaling cost — model it separately and identify the tier boundary where it dominates (often ~50% of total infra). Two practices keep it under control: (1) **persist audio on first generate** — store the rendered audio (base64 in a column or jsonb map keyed by content) and serve from storage on every replay; never regenerate the same text twice; (2) **stream when latency matters** — full TTS adds 3–5s for long messages. WebSocket streaming sends PCM chunks as they're generated; first audio plays in ~200–500ms via client-side AudioContext scheduling. Persistence kills cost; streaming kills wait. Voice playback opt-in is also a UX win (avoids uncanny valley).
**Apply when**: Any project with TTS — make these three decisions on day one (cost model, persistence layer, streaming vs blocking).

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

## Bidirectional Sync System Design (2026-03-28)
**Learning**: When designing any system that syncs files between a source-of-truth repo and deployed copies (skills, configs, knowledge), six rules must hold together:
1. **Three-way comparison** — source vs manifest vs deployed, so you can distinguish "source updated" (deploy it), "deployed updated" (reverse-sync it back), "both updated" (conflict, manual review), "neither" (skip). A two-way comparison can't tell which side moved without a baseline.
2. **Atomic edit-then-deploy** — direct source edits must immediately re-deploy to targets; otherwise a concurrent absorption run sees DIFFERS, treats the stale deployed copy as "newer," and silently reverts the source edit.
3. **Reverse-sync writes to source, never to deployed** — writing to deployed copies creates a permanent gap (deployed has more entries than source) that re-running cannot heal because trackers mark entries as already processed.
4. **Idempotent absorption tracker** — when absorbing entries from a source you don't own (append-only logs, learning files, changelogs), maintain a tracker (content hashes or titles) of already-processed entries so each run only evaluates new material.
5. **Self-flagging entries beat heuristic triage** — when a producing skill writes learnings, it should self-classify each as "promote-worthy" or "local-only" at write time; downstream consumers auto-promote without guessing.
6. **Don't duplicate the layer above** — forward-sync deploying conventions into a project workspace must check whether the global config layer already covers the convention before adding a project-level copy. Duplicating rules across layers creates drift.
**Apply when**: Designing or operating any bidirectional sync system (deploy + absorb) between a canonical repo and its consumers.

## Skills Own Their Dependencies and Their Discovery (2026-03-26)
**Learning**: A skill package must be self-contained in two senses. (1) **Dependencies**: any framework or reference doc the skill cites must live inside the skill's directory, not at repo root. Static reference docs in shared locations become stale orphans because the skill self-iterates but the orphan doesn't — co-location ensures everything evolves together. (2) **Discovery**: when a skill needs to be discoverable on fresh clone before global deployment, use a thin bootstrap file in the project's local skill directory (~3 lines) that points to the real skill file. Avoids symlinks (OS-dependent) and full duplication (drift risk).
**Apply when**: Structuring skill or plugin directories in any repo that is itself the source of truth for those skills.

## Firebase API Key Restriction for Public Repos (2026-03-29)
**Learning**: Firebase API keys are project identifiers (not secrets), but in public repos, ALWAYS restrict the key to the deployment domain via Google Cloud API Keys API. Add HTTP referrer restrictions (deployment domain + `localhost/*` + `127.0.0.1/*`). Security rules protect data integrity, but unrestricted keys let unauthorized apps consume quota or abuse Firebase resources from other origins.
**Apply when**: Setting up Firebase in any project, especially public repos or GitHub Pages sites.

## Silent Browser API Failures — Check Security Headers FIRST (2026-03-29)
**Learning**: When a browser API (`getUserMedia`, `Notification.requestPermission`, `navigator.geolocation`) fails silently — no prompt, no error UI, just a quiet `NotAllowedError` — the root cause is almost always a `Permissions-Policy` response header blocking it. `curl -sI <url> | grep -i permissions-policy` is step 0 before reading any client code. The HTML `capture` attribute on `<input type="file">` is also silently ignored when the policy blocks camera.
**Apply when**: Any browser API behaves as if the user denied permission but no prompt was ever shown.

## Bot and Crawler Protection Strategy (2026-03-29)
**Learning**: Block crawlers at every non-production tier and on every authenticated production surface — not just staging. Internal-only environments should layer all defenses (`robots.txt Disallow`, `X-Robots-Tag: noindex,nofollow` header, infrastructure-level auth gating, `noindex` meta). Customer-facing pre-prod that needs unauthenticated user access can only use app-level headers — infrastructure auth gating locks out the real users you're trying to test with. Production: allow crawling only on truly public pages (marketing, docs); every authenticated path gets `X-Robots-Tag: noindex` plus `Disallow` rules. A bot reaching an admin panel is a security incident, not an SEO miss. Platform-specific gating commands belong in a stack guide, not in this evergreen learning.
**Apply when**: Deploying any application. Decide upfront whether each environment needs unauthenticated end-user access — that decision dictates whether infrastructure gating or app-level headers is correct.

## Next.js 16 Process Renaming Breaks Zombie Kill Scripts (2026-03-29)
**Learning**: Next.js 16 renames its dev server process to `next-server (v16.x.x)` — a custom process title with no `node`, `next dev`, or project name in the command string. Standard pgrep patterns (`node.*next.*dev`, `node.*(next|playwright).*<project>`) miss it entirely. The process also auto-selects non-standard ports when the configured port is busy, so port-based `fuser -k` also misses it. Kill/restart scripts must match the literal string `next-server` and scope to the project by checking `/proc/$PID/cwd`.
**Apply when**: Writing or updating restart/kill-zombie scripts for any Next.js 16+ project. The `/srs` skill templates need this pattern.

## Voice Clone Consent Flow Is a Legal Requirement (2026-03-29)
**Learning**: Voice biometrics are sensitive data under GDPR, UK DPA, and emerging US state laws. Before cloning a user's voice, present a dedicated consent screen with: what you collect (audio sample), how it's used (private TTS only), user rights (delete anytime), and third-party processing disclosure (name the provider). Use a checkbox-based explicit consent mechanism — implied consent from "tapping record" is insufficient.
**Apply when**: Any feature that processes voice biometrics — clone, voiceprint, speaker ID. Not needed for plain speech-to-text.

## Fire-and-Forget Background Processing Keeps Capture Instant (2026-03-29)
**Learning**: When a user captures input, the response must feel instant (<200ms). Heavy processing (LLM classification, theme assignment, TTS pre-generation) should fire-and-forget after the capture response is sent. Use `promise.catch(() => {})` pattern — don't await. The user sees results on next view. This is the "three-layer cost architecture" in practice: capture is free/instant, processing is async/cheap, generation is on-demand/expensive.
**Apply when**: Any capture-first app where input frequency is high and processing is heavy.

## Auth Library Territory: Don't Recreate, Don't Bypass (2026-03-29)
**Learning**: Any auth library that manages its own user/session/account tables owns identity, sessions, password hashing, and credential validation. Two anti-patterns to avoid together: (1) **never create a parallel "user-like" table** with overlapping fields (email, name, provider ID) — FK directly to the auth library's user table, extend via the library's own field-extension mechanism if supported, or use a thin profile table with only app-specific fields. (2) **never hand-craft sessions for mock/staging login** — use the library's own sign-in method and seed credentials via the library's own password-hash function. Unsigned cookies you craft by hand won't verify when the auth middleware checks them. If you're writing `response.cookies.set("session_token", ...)` in a mock auth route, STOP. The library is the single source of truth for identity AND for session shape.
**Apply when**: Designing schemas or building staging/dev mock login for any project using an auth library with its own user table.

## Cloud Services Must Have Local Dev Fallbacks (2026-03-29)
**Learning**: Every cloud service call (GCS, S3, email, push notifications) needs an env-gated local fallback. Write the local branch FIRST. Three tiers: local dev = filesystem/mock/console.log, staging = real cloud service, prod = real cloud service. Module-scope cloud client instantiation without an env check (`new Storage()`) crashes local dev immediately.
**Apply when**: File uploads, email sending, push notifications, or any external service integration. The local fallback is step 1, not step last.

## Read-Only Auth Routes Must Be Excluded from Mutation Rate Limits (2026-03-29)
**Learning**: Rate limiting `/api/auth/*` by URL prefix catches read-only GET endpoints (session checks, user lists, config) alongside mutations (login, signup, verify). After a normal login+logout cycle exhausts the auth budget, GET endpoints return 429, breaking UI features. Better pattern: rate limit by HTTP method — only POST/PUT/DELETE on auth paths get the strict limit; GET gets the default limit.
**Apply when**: Adding rate limiting middleware that matches URL prefixes, or adding new routes under a rate-limited prefix. Always check if the new route is read-only.

## Long-Running Agents Must Write Incrementally, Never Buffer-Then-Flush (2026-04-01)
**Learning**: When spawning a subagent to generate large outputs (training data, reports, migration files, test fixtures), the agent MUST write to disk incrementally — every 20-50 items — not buffer everything in memory and write at the end. If the agent hits a rate limit, OOMs, times out, or crashes for any reason, all buffered work is permanently lost. Agent prompts must explicitly instruct: "Write incrementally — append every 20 items. Do NOT buffer everything and write at the end." The correct pattern is generate batch → write to file → generate next batch → append → repeat.
**Apply when**: Spawning any agent for data generation, bulk file creation, large report generation, or any task expected to run >5 minutes. The longer the expected runtime, the more critical incremental writes become.

## No Auto-CI for Solo Dev Projects (2026-04-03)
**Learning**: Solo dev projects should use `workflow_dispatch` (manual trigger) for CI, not auto-trigger on push/PR. Run CI explicitly via `/cicd` or `/ponci` when ready. Auto-CI wastes Actions minutes and creates noise during rapid iteration where every push is WIP.
**Apply when**: Setting up CI for any solo dev project. Default to manual trigger unless the user explicitly wants auto-CI on every push.

## GCP Artifact Registry Cleanup Policy Must Be Set Per-Repo (2026-04-16)
**Learning**: Artifact Registry cleanup policies are per-repository only — no project-level default. Every new Docker repo starts with NO cleanup policy. Old images accumulate silently and cost money. Standard policy: keep last 5 versions, delete rest (`{"action":{"type":"Keep"},"mostRecentVersions":{"keepCount":5}}` + `{"action":{"type":"Delete"},"condition":{"tagState":"ANY"}}`). Apply immediately on repo creation via `gcloud artifacts repositories set-cleanup-policies`.
**Apply when**: Any blueprint or deploy script that creates Artifact Registry repos for Cloud Run. Should be a checklist item in GCP deploy setup.

## Cloudflare / Anti-Bot Investigation Playbook (2026-04-16)
**Learning**: When a scrape/fetch returns 403 from Cloudflare or similar, follow the playbook in order — each step is free and eliminates a class of cause before the next:
1. **Read the response headers**. `cf-mitigated: challenge` confirms a JS challenge (vs. IP block / WAF rule / origin error). The exact value (`challenge` / `block` / `captcha`) tells you which fix path applies.
2. **Diagnose by IP**. Cloudflare's challenge tier is often IP-reputation-driven; cloud provider ranges are heavily flagged. Test the same URL from a different IP pool (residential vs. cloud). If only the cloud IP is challenged, a residential proxy solves it. If both are challenged, the site is in full challenge mode — no IP swap will help.
3. **Probe every surface**. WordPress sites expose 7+ scraper-friendly surfaces (`/`, `/robots.txt`, `/sitemap.xml`, `/wp-sitemap.xml`, `/wp-json/wp/v2/posts`, `/feed/?paged=N`, direct asset URLs). Test ALL in one parallel batch — protection rules often differ across surfaces (block HTML, leave RSS or REST API open).
4. **Reframe before investing in bypass**. Search for alternative unprotected sources for the same content. Most "only on site X" claims are false; content usually exists on at least one mirror, aggregator, or secondary publisher. The reframe ships faster and stays cheaper than maintaining bypass tooling.
5. **Treat bypass tools as 6-month assets**. Stealth-patched browsers and similar Chromium-fingerprint patches periodically lose effectiveness when Cloudflare ships a new challenge tier. Before integrating, confirm a public report of success against the *current* challenge tier (last ~30 days). Budget for replacement. Specific tool names belong in a stack guide with a "verified" date, not in an evergreen learning.
**Apply when**: Any 403 from Cloudflare or similar bot-protection layer. Run the steps in order before declaring a hard wall.

## Pipeline Silent-Failure Alerts: "Last Produced Output" Metric (2026-04-16)
**Learning**: A scraping/ingestion pipeline can run cleanly and log success for weeks while producing zero documents — if the listing-discovery layer is broken. "Last successful run" is necessary but insufficient. Add a per-source "days since last new document" alert. Silent discovery failure is a real failure mode that unit tests and HTTP status checks will never catch.
**Apply when**: Designing observability for any source→sink pipeline. Add a "last produced output" metric alongside "last successful run."

## Three Hats Before Conceding a Wall (2026-04-16)
**Learning**: The investigative sequence for blockers is Skeptic (challenge the "can't" claim) → Prospector (scour for alternative tools) → Reframer (change the destination if the path is blocked). The failure mode is skipping the Reframer hat and defaulting to "keep banging on the wall." Many apparent dead-ends dissolve when the question changes from "how do I get through this wall?" to "does the actual goal require this wall to be cleared?"
**Apply when**: Any blocker investigation, any time a direct fix has been exhausted. The Reframer question must be asked explicitly before reporting a hard wall.

## Single-Use Refresh Tokens Race Under Concurrent Processes (2026-04-26)
**Learning**: When several processes share one OAuth credential and the provider issues *single-use* (rotating) refresh tokens, simultaneous expiry triggers a race: each process refreshes with the same refresh token, the first wins, the rest get `invalid_grant` and crash. The durable client-side fix is a **cross-process lock on the credential write** — refresh under a lock, re-read fresh inside it, and preserve the existing refresh token if the provider's response omits one (RFC 6749 §6). A proactive scheduled-refresher is a lighter mitigation, but if you build one, mind three traps: (1) **scheduled, not polling** — sleep until `expiresAt - margin`, refresh once, recompute; (2) **the refresher races itself** — serialize bursts via non-blocking `flock -n`, exit on lock loss; (3) **clock-skew on suspend** — re-read `expiresAt` on every wake. (Historical note: Claude Code hit exactly this race with concurrent subagent fan-out; it was fixed upstream in v2.1.136 via a cross-process credential lock. Forge's WA-001 mitigation was retired when that shipped.)
**Apply when**: Designing or reviewing any multi-process system that shares a rotating OAuth credential — your own SDK integrations, not Claude Code (which now handles it internally).

## Exhibit A — How a Project-Name Leak Happens (2026-04-25)
**Learning**: A `/forge` fold-phase run absorbed seven learnings from a project session and committed them with the project name, the contributor's full name, the local currency price, project schema field names, a competitor product name, and region-specific framing all preserved verbatim. Even the commit title named the project and the person. Three layers of "no project names" rules (forge `CLAUDE.md` HARD RULE, `skills/forge/SKILL.md` Phase 3 instructions, "No Project Names Rule" footer) were prose instructions the agent was supposed to follow on its honor — there was no scanner, no reject step, and `Forge-worthy: yes` was treated as a citation slot rather than a flag. Worse, prior `/cast` improvements had wired contributor attribution into PLAN/DONE *tables*, and the agent generalized that to mean attribution belongs in absorbed *content* too. The boundary was lost.

**Lessons baked into the fix**:
1. Prose rules without enforcement get ignored when the agent is mid-flow. A literal scanner (`scripts/fold-purity-check.sh`) now runs in fold phases 3e and 3i and on commit messages, blocking writes with non-zero exit if it detects: currency-symbol prices, attribution lines (`contributor:`, `(<X> session, YYYY-MM-DD)`), CamelCase compound names not on an allowlist, project schema names in backticks, or `Firstname Lastname` patterns in body text.
2. Attribution lives in the PLAN/DONE table, NEVER in the absorbed content body. `Forge-worthy: yes` is a flag, not a citation slot.
3. The first cure for a precedent leak is to canonize it as the cautionary example future runs read in pre-flight.

**Apply when**: Authoring or modifying any forge fold logic. Reviewing any commit that touches `<forge>/learnings/` or `<forge>/memory/`. When rules are repeatedly violated despite being documented in HARD RULE form, the next layer is mechanical enforcement, not louder prose.

## DNS, Email, and App Hosting Are Fully Decoupled — Don't Bundle Them (2026-04-22)
**Learning**: Domain registration, DNS hosting, email hosting, and application hosting are four independent decisions. Users (and sometimes agents) instinctively bundle them — "we're deploying to GCP, so we should get Google Workspace" or "the registrar offers email, so use theirs." This bundling is almost always wrong for bootstrapped projects. GCP/AWS/Vercel don't care where DNS lives; they only need records pointing at them. Email providers don't care where the domain is registered; they only need MX/SPF/DKIM/DMARC records in whatever DNS you use. Each layer should be chosen on its own merits (cost, features, lock-in). The only coupling is convenience: same-vendor domain verification is slightly faster, but never worth paying a markup for.
**Apply when**: Any "what should I use for X" question touching domains, DNS, email, or hosting. Before recommending a bundle, decompose into the four independent layers and price each separately. Challenge any "we need X because we're using Y" reasoning unless Y literally requires X.

## Cloudflare Registrar + Email Routing Is the Default Bootstrap Stack (2026-04-22)
**Learning**: For any bootstrapped project (solo founder, small team, pre-revenue), the default stack is: Cloudflare Registrar (at-cost domain pricing, no markup — typically the cheapest available for major TLDs) + Cloudflare DNS (free, fastest anycast) + Cloudflare Email Routing (free forwarding to a personal mailbox) + whatever app host fits the workload. Total cost is the registration fee plus zero. Managed productivity suites (per-user-per-month inbox + collaboration) are premature for a single founder — email forwarding plus a "Send As" identity in a personal mailbox (via a free SMTP relay) covers send + receive. Upgrade triggers are concrete: (1) hiring, (2) needing shared inboxes like `support@`, (3) needing org-grade Docs/Drive/Meet collaboration. Separate concern: transactional email (signup, password reset) always needs its own provider regardless of inbox choice — don't conflate "receiving email at your domain" with "your app sending email."
**Apply when**: User asks about email setup, DNS hosting, or domain registration for a new project. Default to Cloudflare unless there's a concrete reason otherwise (TLD not supported, team already in a productivity-suite ecosystem, compliance requirement). Registrar transfers require 60 days after registration, so if the user just bought from another registrar, note the wait time.

## Avoid Em-Dashes and Tricolon Negation Cadence in User-Facing Copy (2026-04-27)
**Learning**: Two specific prose patterns now read as obviously AI-generated to skeptical readers, regardless of the surrounding writing quality. (1) Em-dashes — every length, every position. Even "elegant" usage is a tell because current LLM defaults overuse them. Rewrite with commas, periods, colons, semicolons, or parentheses depending on the logical relationship. (2) Tricolon negation cadence: the "No X. No Y. No Z." or "No X. No Y. Just Z." three-beat hook. Pattern is so widespread in AI marketing/landing copy that it now signals templated output rather than original thinking. Both make text feel manufactured rather than written, undermining trust on pitches, decks, and any external-facing artifact where the reader's "is this AI slop?" filter is on.
**Apply when**: Drafting or reviewing any external-facing copy — pitches, decks, marketing pages, in-app strings, landing copy, email outreach. Treat both patterns as defects on review passes; do not rely on "single em-dash is fine" carve-outs. To replace the tricolon, describe what the thing IS rather than enumerating what it is not.

## Grep Defaults Are Tuned for Humans, Not Token-Metered Agents (2026-05-01)
**Learning**: The Grep tool's default `output_mode: "content"` mirrors Unix `grep` — sensible for a human skimming output, wasteful for an LLM that pays per token to read every returned line. The analogy "grep has worked this way for 50 years" doesn't hold: a Unix tool returns bytes to a free reader; an agent tool returns tokens to a metered one. Default behavior should be the cheapest shape that preserves correctness, with verbosity opted *into*, not out of.
**Apply when**: Any Grep call. Decision order:
  1. **Default to `output_mode: "files_with_matches"`** — paths only. 10-100x fewer tokens. Sufficient for "where is X defined / referenced."
  2. **Use `output_mode: "content"` only when surrounding lines matter for reasoning** (e.g., understanding how a symbol is used, not just where).
  3. **Always set `head_limit`** when you expect more than a handful of hits. Unbounded content searches are the worst offender.
  4. **For broad sweeps (>50 expected hits, or open-ended "find anything related to X")**, delegate to an exploration subagent — its context is isolated, only the summary crosses back.
  5. **For known symbols/paths**, prefer Read or `rg` via Bash with tight flags over Grep — direct lookups don't need the tool's full result formatting.

## /forge Runs From Anywhere (2026-05-01)
**Learning**: The `/forge` skill is invocable from any cwd, not just from inside the forge repo. It resolves the forge path internally (via the `forge-path:` line in the global `~/.claude/CLAUDE.md`) and runs the bidirectional sync from wherever the user is. The HARD RULE "never write to forge from a project" governs *direct file edits* to the forge repo from project context — it does NOT restrict invoking `/forge` itself, which is the sanctioned channel for absorbing membrane learnings into forge.
**Apply when**: User says "run /forge" or "absorb to forge" from any project. Do not tell them to `cd` into the forge repo first — that's wrong guidance. Just invoke the skill. The only forge-internal skill (cwd-restricted to forge repo) is `/purge`.

## AGENTS.md Is the Cross-Tool Standard; Per-Vendor Adapters Are a Soft Lock-In (2026-05-09)
**Learning**: When building tooling that targets multiple AI coding agents, the temptation is to build per-vendor adapters that emit each tool's specific config (a Claude-coupled rules file, a Cursor rules file, a Copilot instructions file, per-vendor command directories, etc.). This is a softer flavor of vendor lock-in: the tooling multiplies by the cardinality of the vendor matrix, drifts apart over time, and silently couples the build pipeline to whichever adapter manifests are maintained. The actual answer is **`AGENTS.md`** — an open standard stewarded by the Agentic AI Foundation under the Linux Foundation, adopted by tens of thousands of open-source projects. Plain markdown, no required schema, no YAML frontmatter. Most agent CLIs read it natively. For agents that don't yet read `AGENTS.md` natively, a thin bootstrap (a one-line `@AGENTS.md` import in the vendor's expected file, or a symlink) is enough — zero behavior change, no per-vendor build path. One source, one universal output, plus a tiny per-tool bootstrap only where the vendor genuinely cannot read AGENTS.md.
**Apply when**: Designing or evaluating tooling that produces config for multiple coding agents. **Default to AGENTS.md** as the single output. **Reject per-vendor adapters** unless a vendor genuinely cannot read AGENTS.md. Keep vendor-specific surfaces (permissions, MCP, hooks) as opt-in helpers, not in the main build. **Anti-pattern**: a build pipeline with one target per vendor (`build vendor-a`, `build vendor-b`, …) — that's the lock-in trap with extra steps.

## Memory-Write Discipline Is Required For Any AGENTS.md Divorce (2026-05-09)
**Learning**: Divorcing a vendor-specific rules file from `AGENTS.md` (whether via symlink or via a 1-line `@AGENTS.md` import) is fragile because most agent harnesses provide memory-append paths that bypass the abstraction — keyboard shortcuts, slash commands, and init/regen tools that write directly to the vendor file with no target override and no awareness of imports/symlinks. There is typically no settings option to redirect these writes. Without an explicit discipline rule in AGENTS.md, repeated memory-append invocations slowly pollute either the thin pointer file (with `@-import`) or the rules file itself (with symlink — since the write transparently lands in AGENTS.md). Either way, the cosmetic divorce erodes back into the same vendor-coupled blob over time. The fix is *not* technical — it's a codified rule + behavior change.
**Apply when**: Setting up an AGENTS.md divorce in any project. Always include a "Memory write discipline" section in AGENTS.md stating: (1) AGENTS.md is rules, not storage; (2) memory storage lives in `memory/` (always-on) or `<sphere>/memory/` (sphere-scoped); (3) users must NOT use the harness's direct memory-append paths — instead, ask the agent to "remember X" so it saves via auto-memory (which lands in `memory/`, divorce-safe). Bonus: bake a janitor scan into the pre-commit ritual that walks every vendor rules file in the repo and flags any content beyond the bare `@AGENTS.md` line / symlink target — catches the bypass before commit.

## Multi-Sphere Vaults: Per-Sphere AGENTS.md + Per-Sphere memory/ Makes Focus Convention Structural (2026-05-09)
**Learning**: Multi-domain vaults (one repo containing many semi-independent peer subdirs) benefit from giving each sphere its own `AGENTS.md` + its own `memory/MEMORY.md` index, with sphere-scoped memory files inside the sphere's `memory/` dir (sphere prefix dropped from filenames since the path encodes sphere). The root `memory/MEMORY.md` becomes a thin index: always-on entries (load every conversation) + a pointer table per sphere ("for sphere-X memory, see `<sphere-x>/memory/MEMORY.md`"). Sphere AGENTS.md files reference their local `memory/MEMORY.md`. The win: the **focus convention becomes structural rather than procedural** — agents reading `<sphere>/AGENTS.md` literally only see that sphere's memory; off-sphere entries are physically out of sight, not just behind a "don't read this" rule. Bonus: `git add <sphere>/` captures everything sphere-related (rules, memory, content) in one diff scope.
**Apply when**: Divorcing a multi-sphere vault (or any repo with peer-equal subdirs that are semi-independent domains). Single-domain projects don't need this — a flat root-level `AGENTS.md` + root `memory/` is fine. The pattern only earns its keep when the project has 3+ peer domains AND memory accumulates per-domain. For harnesses with auto-loading subdir rules files (e.g., a one-line `@AGENTS.md` pointer in each sphere's vendor file), the cross-tool divorce composes cleanly with the harness's existing auto-load behavior.

## Diffusion LLMs Are a Speed/Infill Tier, Not a Drop-In Swap (2026-06-13)
**Learning**: When evaluating a new "faster LLM" for an existing serving stack, the load-bearing constraints are (1) VRAM fit on the actual target hardware and (2) runtime support in the current serving path — not headline quality. Text-diffusion LLMs win on throughput (parallel block denoising), native infilling (fill-the-middle edits), and format/length controllability, but trade away raw quality versus autoregressive peers of similar size. Slot such a model as a new fast/edit tier in a multi-provider gateway, never as a replacement for the quality anchor. Best fit: code/markup generation with edit loops and structured-output constraints; worst fit: language-fidelity-sensitive paths where a domain-specialist autoregressive model already exists.
**Apply when**: assessing a new model class (diffusion, MoE, distilled) for adoption into a tiered or multi-provider inference gateway. Verify it on the real serving substrate before designing it in.

## MoE VRAM Tracks Total Params, Not Active — Probe the Real GPU First (2026-06-13)
**Learning**: A Mixture-of-Experts model's "active params" (e.g. 4B of 26B) mislead on memory: all experts must be resident in VRAM, so footprint tracks total parameters, not the active subset. A small active-param count does not mean a small-VRAM model. Always measure the actual target GPU (probe it — don't trust a remembered spec) before designing a serving path. When the local box can't fit even the quantized weights, route the model to where the stack already has headroom (cloud serving) rather than bridge-hacking it onto undersized hardware.
**Apply when**: sizing hardware for an MoE model, or deciding local-vs-cloud placement for a new model. Pairs with the detect-don't-ask discipline — confirm hardware empirically before committing to an architecture.
