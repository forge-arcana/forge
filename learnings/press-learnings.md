# /press Learnings

> Populated by `/press` runs across projects. Absorbed into forge by the `/forge` cycle.

<!-- Add learnings below this line -->

## Configure Pino Redact at Initialization (2026-03-15)
**Learning**: Always configure Pino's `redact` option at logger initialization for sensitive field paths (`*.password`, `*.token`, `*.email`, `*.apiKey`, `*.secret`, `*.authorization`, `*.cookie`). Manual per-call masking functions are fragile and incomplete — one forgotten call leaks PII. The built-in redact option catches all paths across all log output automatically.
**Apply when**: Setting up structured logging with Pino in any Node.js project handling user data.

## A Signing-Secret Fallback Must Fail Closed Outside Dev: Hardcoded Forges Sessions, Ephemeral Breaks Them (2026-03-15 → 2026-06-21)
**Learning**: When a session/JWT/HMAC signing secret is unset, either "helpful" fallback ships a defect. (1) **Hardcoded** (`process.env.SECRET || 'dev-fallback'`): if the variable is unset in staging or production, sessions are signed with a publicly known value and can be forged. (2) **Ephemeral** (a process-generated random key): it passes single-process dev testing, then fails silently in production two ways. Each worker or instance holds a different key, so a session minted on one fails validation on another and users are logged out intermittently (load-balancer-dependent, near-impossible to reproduce locally); and every restart or redeploy invalidates all live sessions at once. Both turn a missing-config error into something worse. Gate the fallback on an explicit environment check (`env === 'development' ? fallback : throw`) and fail closed everywhere else; at minimum the ephemeral path emits a loud one-time startup warning. Any horizontally scaled signer needs a persisted, shared secret.
**Apply when**: Configuring or reviewing auth session secrets or any security-critical environment variable, especially on a service that may run more than one process (multi-worker, autoscaling, serverless, blue-green). Flag any `secret || literal` or `secret or random()` fallback that does not fail closed outside dev.

## Low-Entropy Secrets Need Server-Side Pepper (2026-03-29)
**Learning**: A 4-6 digit PIN has 10,000-1,000,000 possible values. Hashing with Argon2id + salt does NOT prevent exhaustion from a database dump — an attacker can try all combinations in seconds on consumer hardware. Server-side pepper (stored in env/secrets manager, never in DB) makes offline exhaustion impossible because the attacker needs both the DB dump and the application secret. Rate limiting + lockout blocks online brute force; pepper blocks offline attacks. This applies to any low-entropy secret: PINs, short OTPs stored at rest, short passcodes.
**Apply when**: Any authentication factor with fewer than ~1 million possible values. Always add server-side pepper alongside hash+salt.

## Env Var Naming Is a 4-File Unit (2026-05-29)
**Learning**: When a secret is server-only (no `NEXT_PUBLIC_` prefix), all four locations — code, README env table, CI/CD env block, and `.env.example` — must use the exact same name. A mismatch causes runtime 503s for anyone following the README and can silently leak the value into the client bundle. These four locations are one logical unit; change them together.
**Apply when**: Any env var rename, promotion from public to server-only, or new secret addition — audit all four touchpoints.

## Content-Only Sites Still Need Security Headers and Compliance Basics (2026-05-29)
**Learning**: Public content sites with no auth and no database still require HTTP security headers (CSP, X-Frame-Options, X-Content-Type-Options) and basic privacy compliance. Clickjacking, script injection via CDN compromise, and iframe embedding remain vectors. GDPR/privacy law applies to any site that sets cookies or transfers visitor data to third parties (analytics, fonts, CDNs), regardless of whether personal data is explicitly collected.
**Apply when**: Any public web app at go-live — security headers and privacy disclosure are not optional even for content sites.

## Managed-Platform Projects: Scope Ops Tooling to Platform Gaps (2026-05-29, revised 2026-10-31)
**Learning**: On a managed host (Vercel, Cloudflare, Railway, Fly.io) the platform handles SSL, uptime, scaling, zero-downtime deploy and rollback, so a content site does not need graceful-shutdown handlers or its own uptime stack. It still needs client error visibility, traffic analytics, and a readable running version (the versioning rule's `/version` or visible build string), which no platform provides. Audit ops tooling against what the platform already gives; never drop the version surface.
**Apply when**: Any go-live review of a project on a managed platform.

## Privacy Policy and Third-Party Service Changes Must Be Atomic (2026-05-29)
**Learning**: When a third-party service changes (new vendor, removed service, or IP-logging side-effect added for rate limiting), the privacy policy must update in the same PR. Stale disclosures are technically inaccurate GDPR representations. Any service that receives IP addresses for security controls qualifies as a data processor and must be disclosed even if IP storage is a side-effect.
**Apply when**: Any PR that adds, removes, or changes a third-party data processor — privacy policy update is part of the PR, not a follow-up.

## Rate Limit Audits Must Cover All Mutation Endpoints (2026-05-29)
**Learning**: When rate limiting is added to one public API endpoint, it's easy to overlook sibling endpoints that also accept user input. An unprotected feedback or contact endpoint can exhaust third-party free-tier quotas under bot traffic. Audit all mutation endpoints together when adding rate limiting to any one of them.
**Apply when**: Any press review that adds or verifies rate limiting — scan all mutation routes, not just the one that triggered the check.

## Verifying a Deploy Through a CDN: Fetch the New Asset Hash Directly — for Additions and Removals (2026-08-16)

**Learning**: Checking a shipped CSS/JS change by grepping the SERVED asset can false-fail behind a CDN: the HTML often returns a cache HIT still referencing the previous asset hash, so "new rule absent from served CSS" reads exactly like a stale-dist deploy — the very failure the check exists to catch — making the false positive expensive. The discriminating sequence: (1) fetch the NEW asset hash's URL directly — 200 + contains the change proves the deploy landed; (2) re-request the HTML with `Cache-Control: no-cache` to confirm the reference updates. Only when the direct-hash fetch ALSO lacks the change is the deploy actually stale. The check has a deletion-shaped twin: verifying an ADDITION means proving the new thing IS in the served bytes; verifying a REMOVAL means proving the old strings are NOT — because a stale dist deploys as a silent no-op that is indistinguishable from success at the deploy line (the version id increments either way). Grep the directly-fetched new bundle for the removed identifiers/copy and require zero hits.

**Apply when**: Any post-deploy verification of static assets served through Cloudflare or another CDN; any "my change isn't live" report within minutes of a deploy; any deploy whose change is a removal (dead feature, retired copy, deleted route) — run both checks when a change adds and removes.

## Craft and Posture Are Different Questions (2026-09-05)

**Learning**: A mechanism can be 5/5 on craft — hash-pinned, locked, fully audited — and still be unready, because craft asks "is the mechanism correct" while posture asks "what does the assembled default do." A well-built decision path sitting behind a default-open route is unready regardless of how good the path is. Gate go-live review on the assembled default a stranger would actually hit, not on the mechanism in isolation, and give the safe posture a supported install path — a flag that cannot survive a restart is not a posture, it is a demo.

**Apply when**: Reviewing a feature that is individually well-engineered but reachable through a default configuration — especially auth, authorization, or anything gating code execution.

## A Vendor Onboarding Command Can Publish a Domain-Wide Policy as a Side Effect (2026-10-10)

**Learning**: A vendor's "enable" command can write shared configuration as a side effect, effective at once and binding on every other provider that uses the same resource: for example a mail-authentication policy published at its strictest setting, with no reporting address, on a domain that had none. The tool's own login may lack the scope to change it back. Before running an onboarding or "enable" command against a shared resource (a DNS zone, an account, an organization), read which records or settings it will write, decide the policy yourself and publish it first, and have a credential ready that can undo it. Worked case: `stack-guide.md` → Cloudflare Email Service → "Decide the DMARC policy before enabling".

**Apply when**: Running any vendor "enable" or setup command against a domain or account that other providers or products already use.

## A Native Plugin Upgrade Is Not Go-Live Ready on a Debug Build and a Changelog (2026-10-11)

**Learning**: Plugin version numbers and changelogs do not track behaviour, and debug builds are not minified. At go-live, a native plugin bump on an auth or money path (biometric, purchase, secure storage) is unverified until the native source has been diffed across the version jump and a signed, minified build has booted. The four rules and the worked case live in the stack guide: `stack-guide.md` → "Capacitor 8 and Xcode 27 Upgrade" → Plugins, and the Android "signed, minified build" bullet.

**Apply when**: Reviewing readiness after any native plugin bump, or an upgrade that passed only on debug builds.

## Selling a Subscription in Many Countries: Fixed Local Prices Tiered by Platform Evidence, No Silent Default (2026-10-22, rewritten 2026-10-31)

**Learning**: A product sold in many countries charges a fixed price in each market's own currency, not one base currency that the payment processor converts. Buyers pay more readily when the price is in their currency and is a round local "charm" amount. This entry guards against three failures: single-currency pricing, a tier list copied from another product without its local-currency scheme, and every unlisted country defaulting to the dearest tier. The scheme:
(a) **A country's tier is what worldwide subscription platforms charge there.** For each country, divide each major global subscription platform's local price by that platform's own US price. The country index is the median across the platforms found. A country with only one platform is tiered on that platform and flagged provisional. Leave a platform out until a plan-matched per-country source exists for it. Tier lines sit where the platforms' own price groups break. Never tier by income group, GDP, PPP or any other economic index, and no pin or exception overrides the platform evidence. Every product reads one sourced survey. A tier changes only through a survey diff, and the survey is redone at most once a year.
(b) **No silent default tier.** Every sellable country gets its tier from the survey. A test fails when a sellable country has no survey-derived tier or falls through to a default. A drift check that only reports is not enough, because nobody reads it before launch.
(c) **Local amount = tier price × an offline exchange-rate baseline, snapped to a charm amount.** Use endings like …49 or …99 at small amounts, trailing 9s at mid-range amounts, and one tenth of a unit below a round figure at large amounts. Volume bands strictly decrease. Each product sets its own yearly-to-monthly ratio; the tiering is shared. Record the rate date, and never reprice automatically.
(d) **Currency exceptions are explicit lists, never a silent fallback.** List the currencies the processor cannot present; those markets fall back to the base currency, and a test pins that list. A currency not yet confirmed in live mode fails loudly when the live price is written and goes to the founder to decide.
(e) **Processor mechanics (Stripe-style price APIs).** Per-currency price options override automatic currency conversion for those currencies. Each currency needs its own tax behaviour, and a missing one sends checkout back to the default currency without any error. Graduated prices need tiers per currency. Invoice items built from raw amounts are not localised, so reference the price id. Write prices before deploying checkout code, add only (exit non-zero on any replacement), and expand the per-currency options when reading them back. Display and charge both come from the same table.
(f) **All products share one scheme**: the survey, the tier lines, the rounding rules and the exception lists. A fix in one product goes to the others the same day.

**Apply when**: Designing or reviewing any paid plan sold outside one country, adding countries to a sellable list, or changing a tier. Read the shared survey first, and change a tier only through a survey diff.

## A Clean HEAD Is Not a Clean History: Scan Every Commit Before a Private Repo Goes Public (2026-11-03)

**Learning**: Making a private repository public publishes every commit, message and tag, not just the current tree. A content guard that checks staged changes, and a cleanup commit that removed private material, both leave that material in history. Before the flip, grep the full `git log -p` of the branch to be published (and every commit message and author email) against the private word list and secret shapes. Decide between a fresh repo with squashed history, a history rewrite, or accepting what is there. Any rewrite invalidates signed tags, so do it before the first public signed release, and never push `--all` or `--mirror` from a working clone.

**Apply when**: Any go-live review that includes changing a repository's visibility, or open-sourcing a project that was developed privately.

## A Missing GitHub Environment Is Created Unprotected on First Use (2026-11-03)

**Learning**: A workflow job that names an `environment:` which does not exist yet makes GitHub create it with no required reviewers and no branch or tag limits. A publish job gated "behind the release environment" is therefore ungated until someone creates that environment by hand. Create it with its protection rules before turning on the trigger that can reach the job.

**Apply when**: Reviewing or enabling any release or deploy workflow that relies on an environment for human approval.
