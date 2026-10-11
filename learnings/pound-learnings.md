# /pound Learnings

> Accumulated learnings from adversarial QA reviews. Absorbed by the `/forge` cycle.

<!-- Add learnings below this line -->

## SessionStorage Guard for Counters on Content Sites (2026-05-29)
**Learning**: Client-side visit counters that fire on every page load inflate metrics and can be gamed trivially. A sessionStorage guard (set a flag after first increment, check before firing) limits the counter to once per browser session — no auth required, no server changes needed.
**Apply when**: Any client-side counter, analytics ping, or "once per visit" event — default to sessionStorage guard.

## NEXT_PUBLIC_ Env Vars Are Always Public — Use API Routes for Third-Party Endpoints (2026-05-29)
**Learning**: Any `NEXT_PUBLIC_*` environment variable is bundled into client JavaScript and visible in browser DevTools. Third-party service endpoints that should not be public (webhooks, form handlers, non-publishable keys) must route through a Next.js API route reading a server-only env var. This prevents endpoint scraping and abuse.
**Apply when**: Any Next.js project with third-party service integration — audit env var prefix vs. actual need for client access.

## CSP unsafe-inline in script-src Defeats XSS Protection (2026-05-29)
**Learning**: Adding `'unsafe-inline'` to `script-src` nullifies CSP protection against XSS entirely. If inline styles are required (Tailwind, CSS-in-JS), allow `'unsafe-inline'` in `style-src` only — never `script-src`. For dynamic inline scripts in Next.js App Router, use nonce-based CSP set per request in `proxy.ts` (named `middleware.ts` before Next.js 16).
**Apply when**: Any Next.js or web project adding a Content-Security-Policy header — enforce the script-src boundary explicitly.

## Consent Follows Purpose, Not Storage Mechanism (2026-05-29, corrected 2026-10-02)
**Learning**: ePrivacy Art. 5(3) is technology-neutral: cookies, `localStorage`, `sessionStorage` and IndexedDB are all "storing information on the user's terminal equipment" (EDPB Guidelines 2/2023). Moving a value from a cookie to `sessionStorage` changes nothing legally. What decides consent is PURPOSE: storage strictly necessary for a service the user explicitly requested (a language or theme choice they made, a cart, a login session) is exempt in any mechanism; analytics, visit counters and tracking need consent in any mechanism, including a session-only flag. Choose the mechanism on functional grounds — must the server read it (cookie), must it outlive the tab (`localStorage`), or is per-tab enough (`sessionStorage`) — and disclose it in the privacy notice either way.
**Apply when**: Any app storing preferences or client-side flags — classify each stored item by purpose before picking a mechanism; never accept "it's only sessionStorage" as a compliance argument.

## Mocks Must Model the Vendor's Real Contract, Not the Code's Assumption (2026-09-19)
**Learning**: Bugs ship green when a test mock encodes the same wrong assumption as the code under test — e.g. a composite identifier modeled as its bare component, or a post-transaction object modeled as carrying the pre-transaction catalog fields. A mock that shares the code's assumption validates the bug instead of catching it. Derive mock shapes from the vendor's actual payloads or published types, not from how the code consumes them.
**Apply when**: Writing or reviewing tests that mock a third-party SDK or API — check each mocked shape against a captured real payload or the vendor's type definitions.

## Reviewer Subagents With Live Data Must Join Threads Before Test Teardown (2026-10-11)
**Learning**: A reviewer told to "attack by executing" can start background threads inside a test whose fixture redirects the data directory to a temp path. If an assertion fails before the stop flag is set, the fixture tears down and restores the real paths while the threads are still running, and they write synthetic data into the live files. Any brief that asks a subagent to run threaded or background probes must require (a) every thread joined in a `finally` before the test returns, and (b) the data path passed explicitly to the code under test or held in an environment that cannot revert while threads live (a subprocess with its own env), never only a fixture-scoped monkeypatch. Stop a live service that shares the data directory before adversarial probing, or run the probes on a copy of the repo.
**Apply when**: Assigning a subagent or adversarial review to run threaded or background tasks against shared data with fixture-based isolation.

## A Delete by Substring Match Must Be Anchored to Its Field and Its Tenant (2026-10-11)
**Learning**: A fix that removes records by raw byte or bare quoted-string match deletes more than it names: a value that also occurs as a field name, or inside another tenant's record, matches too, so the cleanup becomes a cross-tenant deletion. Anchor any pattern-based delete or filter to the field it claims to match and to the caller's tenant, and test it against a second tenant's data that contains the same string. Fixes written in response to a gate finding are where this appears, so the next gate pass aims at what the fix added (see `smith-learnings.md`, "Convergence Re-Evaluates the Fix: Its Reach, and What It Added").
**Apply when**: Writing or reviewing any fix that deletes or filters data by pattern match, especially one made in response to a gate finding.

## Hardening Each Failure Path Does Not Produce Cross-Row Invariants (2026-10-11)
**Learning**: Review rounds that each harden one failure path of a queue-driven worker can all be sound and still leave the serious defects, because those sit between rows and across time: a later item processed around an earlier undecided one, an in-flight item re-aimed when its configuration changes, an external operation created but never recorded. No single path is wrong, so per-path review cannot find them. State the invariants of the whole queue first (ordering key, head-of-line blocking, one live operation per item, plan identity, operation identity) and review every path against them.
**Apply when**: Reviewing any worker that processes rows in order against an external system — write the cross-row invariants down before reading a single failure path.

## Two Parsers of One File Are Tested With the Same Bytes (2026-10-11)
**Learning**: A shell wrapper and an application reader both parsed the same key=value file, each with its own tests, and disagreed on empty values, a byte-order mark, non-ASCII whitespace and NUL bytes — so one accepted what the other called missing. Separate test suites for each parser encode each parser's own assumption. One table of raw byte inputs fed to both, asserting the same verdict per row, is the only test that catches the disagreement.
**Apply when**: Any file or wire format read by more than one implementation (shell and application, client and server, two languages) — share one fixture table across both.

## Check the Shipped Commit Before Stating Exposure (2026-10-11)
**Learning**: A review scoped to an uncommitted diff found serious defects, and it was natural to describe them as risks of the new work. A reviewer who ran the same reproductions against the already-deployed commit showed every one of them was present there too. The exposure statement that matters is about what is running, not about what is being reviewed.
**Apply when**: Reporting any finding from a diff-scoped review — reproduce it against the deployed version before saying whether it is a regression or a standing defect.

## E2E Port Isolation from Dev Server (2026-03-15)
<!-- relocated from global-patterns.md by /purge, 2026-10-11 — sharpens one art, not cross-cutting -->
**Learning**: E2E test configs should use a dedicated test port constant or env var (e.g., `E2E_PORT`), never fall through to the dev server's `PORT`. With `reuseExistingServer: true`, tests silently connect to the running dev server instead of starting a fresh test server — causing mysterious failures from unrelated state.
**Apply when**: Configuring Playwright or similar E2E test runners in a project that also runs a dev server.

## A Deterministic Guard That Only Speaks One Language Silently Stops Guarding (2026-08-15)
<!-- relocated from global-patterns.md by /purge, 2026-10-11 — sharpens one art, not cross-cutting -->
**Learning**: A regex/keyword safety net over user-generated text (force-review triggers, abuse filters, escalation nets) written in English-only stops guarding the moment a real audience arrives — and it fails silent: the guarded system keeps running, the net keeps passing everything, and the miss surfaces as a public incident, not an error. The failure compounds with an LLM judge in the same lane: a polite factual correction ("Eso no es correcto") reads as neither complaint nor question to the model, so BOTH nets pass it. Fixes: (1) name the semantic category explicitly in the LLM's instructions ("claims the post is wrong/mislabeled/AI-generated/fake, in any language") — the model handles languages the regex will never list; (2) extend the deterministic net with the audiences' actual languages, accepting over-match (cost: one human glance) over miss (cost: an automated reply defending a wrong statement); (3) mind JS \b: it is ASCII-word-based, so accented phrases ("não é") need substring matching, not word boundaries. Test both directions: claims force review AND plain praise in the same languages does not.
**Apply when**: Any deterministic text-trigger list over user content in a product with a non-English (or even potentially non-English) audience; any auto-send/auto-action lane gated by keyword nets.
