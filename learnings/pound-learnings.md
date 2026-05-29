# /pound Learnings

> Accumulated learnings from adversarial QA reviews. Absorbed by the `/forge` cycle.

## SessionStorage Guard for Counters on Content Sites (2026-05-29)
**Learning**: Client-side visit counters that fire on every page load inflate metrics and can be gamed trivially. A sessionStorage guard (set a flag after first increment, check before firing) limits the counter to once per browser session — no auth required, no server changes needed.
**Apply when**: Any client-side counter, analytics ping, or "once per visit" event — default to sessionStorage guard.

## NEXT_PUBLIC_ Env Vars Are Always Public — Use API Routes for Third-Party Endpoints (2026-05-29)
**Learning**: Any `NEXT_PUBLIC_*` environment variable is bundled into client JavaScript and visible in browser DevTools. Third-party service endpoints that should not be public (webhooks, form handlers, non-publishable keys) must route through a Next.js API route reading a server-only env var. This prevents endpoint scraping and abuse.
**Apply when**: Any Next.js project with third-party service integration — audit env var prefix vs. actual need for client access.

## CSP unsafe-inline in script-src Defeats XSS Protection (2026-05-29)
**Learning**: Adding `'unsafe-inline'` to `script-src` nullifies CSP protection against XSS entirely. If inline styles are required (Tailwind, CSS-in-JS), allow `'unsafe-inline'` in `style-src` only — never `script-src`. For dynamic inline scripts in Next.js App Router, use nonce-based CSP via middleware.
**Apply when**: Any Next.js or web project adding a Content-Security-Policy header — enforce the script-src boundary explicitly.

## SessionStorage Avoids Consent for Ephemeral Preferences (2026-05-29)
**Learning**: A persistent cookie for language/theme preference technically requires GDPR/privacy consent disclosure as a non-essential cookie. `sessionStorage` is consent-free (non-persistent, browser-only, never sent to server) and is a valid alternative for preferences that don't need to outlive the session. Use cookies only when server-side reading is genuinely required.
**Apply when**: Any app storing user preferences — evaluate whether sessionStorage eliminates the compliance burden before defaulting to cookies.
