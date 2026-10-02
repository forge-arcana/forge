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
