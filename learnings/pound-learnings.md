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
**Learning**: A reviewer subagent told to "attack by executing" started writer threads inside a test whose fixture redirected the data directory to a temp path. An assertion failed before the stop flag was set, the fixture tore down and restored the real paths, and the still-running threads wrote millions of synthetic rows into the live data files for minutes. Rule: any brief that asks a subagent to run threaded or background probes must require (a) every thread joined in a `finally` before the test returns, and (b) the data path passed explicitly to the code under test or held in an environment that cannot revert while threads live (a subprocess with its own env), never only a fixture-scoped monkeypatch. Stop a live service that shares the data directory before adversarial probing, or run the probes on a copy of the repo.
**Apply when**: Assigning a subagent or adversarial review to run threaded or background tasks against shared data with fixture-based isolation.

## A Fix Introduced in Response to a Gate Finding Needs a Convergence Pass on What It Added (2026-10-11)
**Learning**: A fix that was added in response to a gate finding (removing unreadable lines that contain an erased token) introduced a cross-tenant deletion that two independent final-gate reviewers both reproduced: the match was a bare quoted string, so a field name passed as the token matched other tenants' lines. Rule: a fix that deletes by raw byte or substring match must be anchored to the field it claims to match and to the caller's tenant, and every fix round gets a convergence pass aimed at what the fix added, not a re-run of the original findings.
**Apply when**: Responding to a gate finding with a fix that deletes or filters data by pattern match, or running a final gate pass on a fix from an earlier gate round.

## Hardening Each Failure Path Does Not Produce Cross-Row Invariants (2026-10-11)
**Learning**: Several review rounds each hardened one failure path of a queue-driven state machine (a clone fails, a request fails, a credential is missing) and each round's fix was sound in isolation. The defects that remained were all between rows and across time: a later item requested around an earlier undecided one, a plan re-aimed when its configuration changed mid-flight, an external operation created but not recorded. Per-path review cannot find these because no single path is wrong. State the invariants of the whole queue first (ordering key, head-of-line blocking, one live operation, plan identity, operation identity) and review every path against them.
**Apply when**: Reviewing any worker that processes rows in order against an external system — write the cross-row invariants down before reading a single failure path.

## Two Parsers of One File Are Tested With the Same Bytes (2026-10-11)
**Learning**: A shell wrapper and an application reader both parsed the same key=value file, each with its own tests, and disagreed on empty values, a byte-order mark, non-ASCII whitespace and NUL bytes — so one accepted what the other called missing. Separate test suites for each parser encode each parser's own assumption. One table of raw byte inputs fed to both, asserting the same verdict per row, is the only test that catches the disagreement.
**Apply when**: Any file or wire format read by more than one implementation (shell and application, client and server, two languages) — share one fixture table across both.

## Check the Shipped Commit Before Stating Exposure (2026-10-11)
**Learning**: A review scoped to an uncommitted diff found serious defects, and it was natural to describe them as risks of the new work. A reviewer who ran the same reproductions against the already-deployed commit showed every one of them was present there too. The exposure statement that matters is about what is running, not about what is being reviewed.
**Apply when**: Reporting any finding from a diff-scoped review — reproduce it against the deployed version before saying whether it is a regression or a standing defect.
