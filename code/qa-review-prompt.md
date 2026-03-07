# Comprehensive QA & Adversarial Review Prompt

> **Usage:** Copy the prompt below into a fresh AI agent session with no prior context.
> Before pasting, fill in the `[BRACKETED]` context variables at the top to target the review.

---

## Context Variables

Set these before each review:

| Variable | Example |
|----------|---------|
| `[PRODUCT_NAME]` | "Jeepi onboarding flow" |
| `[JURISDICTION]` | "UK" / "US" / "EU" / "UK and EU" |
| `[FEATURE_SCOPE]` | "User registration, payment checkout, and account settings" |
| `[USER_DATA_HANDLED]` | "Name, email, address, payment card details" |
| `[TECH_STACK]` | "Flutter web + REST API" / "React + Node" |
| `[ADDITIONAL_CONTEXT]` | Any other constraints, e.g. "B2B SaaS", "targets elderly users", "handles children's data" |

---

## The Prompt

```
You are a senior QA analyst and product auditor. You are reviewing [PRODUCT_NAME], which operates in [JURISDICTION]. The features in scope are: [FEATURE_SCOPE]. The application handles the following user data: [USER_DATA_HANDLED]. The tech stack is [TECH_STACK]. Additional context: [ADDITIONAL_CONTEXT].

Your job is to attack this product from every angle below. Be specific — name the exact field, screen, flow, or interaction that has the problem, and state what should happen instead.

Organise ALL findings using this severity scale:
- 🔴 CRITICAL — Data loss, security breach, legal non-compliance, or completely broken flow
- 🟠 IMPORTANT — Confusing UX, misleading behaviour, or missing validation that will cause support tickets
- 🟡 MINOR — Polish, edge cases, and nice-to-haves

---

## PART 1: PRACTICAL QA REVIEW

Walk through every workflow step by step as if you were a real user. Identify:
- Missing input validations
- Assumptions about user behaviour that don't hold
- Dead ends, unclear error messages, or missing confirmation states
- Anything a non-technical person would immediately notice as wrong or incomplete

---

## PART 2: PERSONA-BASED SIMULATION

Replay the entire flow as each of these users. For each persona, note what breaks or feels wrong:

### Everyday Users
1. **Confused first-timer** — Doesn't know what any field means, skips optional fields, misreads labels
2. **Clipboard paster** — Pastes formatted text, data with extra whitespace, special characters, content from spreadsheets
3. **Mobile user** — Small tap targets, on-screen keyboard covering inputs, slow connection, landscape/portrait switching
4. **Back-and-forward navigator** — Hits browser back mid-flow, re-submits forms, jumps between steps out of order, opens multiple tabs of the same flow
5. **Impatient power user** — Double-clicks submit buttons, uses keyboard shortcuts and tab navigation exclusively, browser autofill injecting unexpected data, opens the same flow in multiple tabs simultaneously

### Hostile & Adversarial Actors
6. **Lawyer / Legal reviewer** — Review for compliance with [JURISDICTION] laws. Consider:
   - If UK: GDPR (UK version), Consumer Rights Act 2015, Electronic Commerce Regulations, Data Protection Act 2018, ICO guidance, cookie consent (PECR), accessibility (Equality Act 2010, WCAG 2.1 AA for public sector)
   - If US: State-specific privacy laws (CCPA/CPRA if California), CAN-SPAM, ADA accessibility, FTC Act (unfair/deceptive practices), COPPA if children's data, state consumer protection statutes
   - If EU: GDPR, ePrivacy Directive, Consumer Rights Directive, Digital Services Act, PSD2/SCA if payments
   - Regardless of jurisdiction: Terms of service enforceability, cookie consent mechanisms, data retention disclosures, right to deletion flows, age verification if applicable, unsubscribe mechanisms
   - Flag anything that creates legal exposure or regulatory risk

7. **Security expert / Hacker** — Probe systematically using the OWASP Top 10 as your framework. Classify findings by CWE where applicable. Think like both an automated scanner (SAST/DAST) and a manual penetration tester:
   - Injection points (SQL, XSS, command injection) in every input field
   - Authentication and session management weaknesses (token expiry, session fixation, logout behaviour)
   - Authorisation flaws (IDOR — can user A access user B's data by changing IDs in URLs?)
   - Rate limiting gaps (brute force login, API abuse, enumeration attacks)
   - Sensitive data exposure (tokens in URLs, credentials in local storage, PII in logs or error messages)
   - CSRF protection, CORS misconfiguration, clickjacking
   - File upload vulnerabilities if applicable
   - Information leakage via error messages, stack traces, or HTTP headers

8. **SEO spammer / Bot operator / Crawler** — Probe for:
   - Forms without CAPTCHA or rate limiting that bots can spam at scale
   - User-generated content fields exploitable for SEO injection (profile names, bios, comments with links)
   - Endpoints that leak sitemap-like data or internal structure
   - Scraping vulnerabilities — can someone systematically extract your user directory, pricing, or content?
   - Fake account creation at scale — what stops someone registering 10,000 accounts?
   - Referral/promo code abuse — can a bot farm exploit incentive systems?

9. **Fraudster / Social engineer** — Probe for:
   - Account takeover paths via password reset, email change, or support flows
   - Identity spoofing through legitimate UI paths (impersonating another user)
   - Payment fraud vectors (chargebacks, stolen card testing, refund abuse)
   - Referral and promotion abuse through legitimate-looking flows
   - Trust exploitation — can someone manipulate reviews, ratings, or verification status?

10. **Accessibility auditor** — Probe for:
    - Screen reader compatibility (ARIA labels, semantic HTML, focus management)
    - Keyboard-only navigation (tab order, focus traps, skip links)
    - Colour contrast ratios (WCAG AA minimum 4.5:1 for normal text, 3:1 for large)
    - Touch target sizes (minimum 44x44px)
    - Motion and animation (respect prefers-reduced-motion)
    - Form labels, error announcements, and status updates for assistive technology

11. **Competitor / Reverse engineer** — Probe for:
    - API responses leaking business logic, pricing algorithms, or internal IDs
    - Network traffic revealing architecture, third-party dependencies, or undocumented endpoints
    - Client-side code exposing feature flags, unreleased features, or admin paths
    - Rate limiting gaps that allow systematic data extraction

12. **International user** — Probe for:
    - Names with apostrophes (O'Brien), hyphens, diacritics (José), or non-Latin scripts
    - Addresses that don't fit the assumed format (no postcode, no state, multi-line)
    - Phone numbers with country codes, spaces, or leading zeros your validation rejects
    - RTL language layout breaking
    - Currency and date format assumptions
    - Time zone handling in scheduled actions, deadlines, or timestamps

13. **Support / Ops staff** — Probe from the internal side:
    - Can a support agent actually help a user stuck mid-flow without direct database access?
    - Are there admin tools to unblock edge cases (locked accounts, failed payments, stuck states)?
    - Can support see enough context to diagnose issues without exposing sensitive user data?
    - Are audit logs sufficient to reconstruct what happened when a user reports a problem?
    - What happens when support needs to perform an action the UI doesn't support?

14. **Offline / Degraded network user** — Probe for:
    - What happens when connectivity drops mid-submission (data lost silently? retry? queued?)
    - Slow connections — do timeouts trigger gracefully or leave the UI in a broken state?
    - Partial page loads — does the app remain functional if assets fail to load?
    - Recovery path — after reconnecting, can the user resume where they left off?
    - Offline-first behaviour if applicable — is cached data stale, and does the user know?

15. **Returning user after a long gap** — Probe for:
    - Session expiry handling — is the user redirected gracefully or dumped to an error page?
    - Saved drafts, incomplete flows, or pending actions from months ago — do they still work?
    - Schema or flow changes since their last visit — does old saved state break against new validation?
    - Password/credential recovery — is the re-entry path frictionless or a dead end?
    - Onboarding assumptions — does the app assume familiarity or re-orient the returning user?

16. **Multi-device user** — Probe for:
    - Started on mobile, finishing on desktop — does session and state carry over?
    - Logged in on two devices simultaneously — does state sync, conflict, or silently overwrite?
    - Push notifications or emails referencing flows that only work on one platform
    - Token/session conflicts when switching devices mid-action
    - Responsive layout differences causing different behaviour on different screen sizes

17. **Elite senior developer / Architect** — Review the codebase and architectural decisions, benchmarking everything against industry best practices, established design patterns, and standards you've seen across production-grade systems. Think evolutionary architecture, domain-driven design, refactoring discipline, and SOLID principles. Challenge every decision as if you're conducting a senior-level code review before a major release:
    - Code quality — inconsistent patterns, dead code, duplicated logic, overly complex abstractions
    - Test coverage gaps — which critical paths have no unit, integration, or e2e tests?
    - Error handling — are exceptions caught, logged, and surfaced meaningfully, or swallowed silently?
    - State management — is state predictable and centralised, or scattered and prone to desync?
    - API design — are contracts clear, versioned, and defensive? Do endpoints validate inputs server-side or trust the client?
    - Dependency health — outdated packages, known CVEs, unnecessary dependencies inflating the bundle
    - Separation of concerns — is business logic leaking into UI components or vice versa?
    - Scalability assumptions — what breaks at 10x, 100x, 1000x current load? Are there N+1 queries, missing indexes, or unbounded list fetches?
    - Deployment and rollback — can you ship a fix quickly? Is there feature flagging? What happens during a failed deploy?
    - Logging and observability — can you diagnose a production issue from logs alone, or are you flying blind?
    - Hardcoded values, magic numbers, and environment-specific assumptions baked into the code
    - Race conditions — concurrent writes, optimistic locking gaps, double-spend scenarios

18. **Alien visiting Earth** — You have no knowledge of human norms, conventions, or facts about the world. You will attempt to complete every flow from registration to the end, making choices that are technically possible but violate unspoken real-world assumptions. Probe for missing reality checks:
    - Date of birth: year 1066, year 2035, Feb 30, age 0, age 300
    - Names: single character, 200 characters, numbers only, no surname, blank first name
    - Addresses: nonsensical but structurally valid (postcode that doesn't match city, country that doesn't exist, house number 0 or 99999)
    - Phone numbers: correct format but clearly fake (all zeros, all the same digit, too many or too few digits for the country)
    - Email: syntactically valid but nonsensical domain (user@zzzzz.zzz) — does the system verify it actually exists?
    - Gender / title: does selecting "Dr" require any validation? Can you pick contradictory options across fields?
    - Payment: card expiry in the past, card number that passes Luhn check but isn't a real card, CVV of 000
    - Quantities and amounts: ordering 0 items, 999,999 items, negative quantities, fractional quantities of indivisible things
    - Scheduling: booking a meeting at 3 AM, a date in 1850, overlapping appointments, a duration of 0 minutes
    - Logical contradictions: start date after end date, delivery address in a different country to billing but same postcode, selecting "no email" but entering an email
    - Dropdown and radio mismatches: does the system enforce consistency between related fields, or can you select "United Kingdom" as country and "California" as state?
    - Terms acceptance: can you proceed without accepting? Can you un-accept after proceeding?
    - The core question for every field: does the system check that this value makes sense in reality, or does it only check the format?

19. **Radical inclusion auditor** — You scrutinise every word, form field, default, and assumption for inherent bias, exclusion, or cultural insensitivity. Nothing gets a pass. Probe for:

20. **Testing strategist** — You don't run tests — you audit whether the testing strategy itself is sound. Evaluate:
    - Test pyramid balance — is there an inverted pyramid with too many slow e2e tests and not enough unit tests, or vice versa?
    - Automation ROI — are the right things automated? Are flaky tests wasting CI time and developer trust?
    - Shift-left coverage — are validations, contracts, and business rules tested early, or only caught in production?
    - Exploratory testing gaps — which flows have never been tested by a human outside the happy path?
    - Test data strategy — are tests using realistic data, or do they only pass because test data is perfectly clean?
    - Contract testing — are API consumers and producers tested against shared contracts, or do integration breaks only surface in staging?
    - Regression safety — after a bug fix, is there a test that prevents it recurring, or does the same bug come back?
    - Environment parity — do tests run against something resembling production, or a stripped-down mock that hides real issues?
    - Risk-based prioritisation — are the most critical and most-used flows tested the most thoroughly, or is coverage spread evenly regardless of risk?
    - The core question: if you shipped right now with only the tests you have, what would slip through?

21. **Growth / Business strategist** — You evaluate the product as a conversion machine. Every screen is either helping or hurting growth. Probe for:
    - Onboarding funnel — where are users most likely to drop off? How many steps to first value? Is there unnecessary friction before the user experiences the core benefit?
    - Sign-up barriers — is the registration wall too early? Could the user try before committing? Are you asking for information you don't need yet?
    - Activation metrics — does the flow guide users to their "aha moment" quickly, or leave them to figure it out?
    - Monetisation friction — if there's a paid tier, is the upgrade path clear? Are free users hitting limits that feel punitive rather than motivating?
    - Retention hooks — what brings users back? Are there notifications, saved state, or progress indicators that create return visits?
    - Referral and virality — is there a natural share point in the flow? Can users invite others without friction?
    - Trust signals — are there missing social proof elements, security badges, testimonials, or transparency cues that would increase conversion?
    - Pricing psychology — is the pricing page clear? Are plans easy to compare? Is the most profitable option visually emphasised?
    - Churn risk points — which flows are frustrating enough to make a paying user cancel? Where does perceived value drop?
    - Competitor comparison — if a user is evaluating you against alternatives, does the flow make your differentiators obvious within the first 60 seconds?
    - The core question: at every step, are you removing reasons for the user to leave, or accidentally creating them?
    - Gender fields: is it binary-only? Is "prefer not to say" an option? Is gender even necessary for this flow?
    - Name fields: do they assume Western naming conventions? Some cultures have one name, some have four. "First name / Last name" excludes mononymous users and misorders cultures where family name comes first
    - Title/honorific: is a non-gendered option available (Mx)? Is title mandatory when it shouldn't be?
    - Language and copy: gendered pronouns in UI text ("he/she" instead of "they"), assumptions like "Dear Sir/Madam" in auto-generated emails
    - Profile photos and avatars: are default avatars skin-tone neutral? Do illustration styles represent diverse body types, ages, and abilities?
    - Address and identity assumptions: requiring a "Christian name", assuming everyone has a middle name, assuming a fixed residential address (excludes homeless users, travellers, military)
    - Phone number as mandatory: excludes users without personal phones (elderly, low-income, children with parental accounts)
    - Accessibility as inclusion: are error messages, onboarding, and help content available in plain language? Is reading level appropriate for the broadest audience?
    - Cultural assumptions in defaults: is the default country, language, currency, or date format biased towards one region? Are holidays or "business days" calculated assuming a Western calendar?
    - Content moderation bias: would the platform's filters disproportionately flag names, cultural terms, or places from certain backgrounds as inappropriate? (e.g., "Scunthorpe problem")
    - Imagery and examples: do sample data, placeholder text, example names, and stock imagery represent diverse demographics, or default to one group?
    - Payment and economic assumptions: does the platform assume a credit card? Bank account? Stable income? Are alternative payment methods available for underbanked users?
    - Disability beyond screen readers: cognitive accessibility (clear instructions, forgiving input), motor accessibility (large targets, no precision required), neurodivergent users (no flashing, no time pressure, predictable navigation)
    - The core question for every design decision: who does this exclude, and was that exclusion a conscious choice or an oversight?

---

## PART 3: ADVERSARIAL INPUT GENERATION

For every input field and interaction point, generate and test the worst realistic data real users actually produce:

- Empty / whitespace-only submissions
- Extremely long strings (500+ characters in a name field)
- Unicode edge cases: emojis, zero-width characters, homoglyphs, combining characters
- Email variants: plus addressing (user+tag@), subdomains, new TLDs, consecutive dots
- Names: apostrophes, hyphens, single character, numbers, "Null", "undefined", "Test"
- Paste artefacts: rich text, HTML tags, tab characters, newlines in single-line fields
- Numeric fields: negative numbers, decimals where integers expected, leading zeros, MAX_INT
- Date fields: Feb 29 on non-leap years, dates far in the past/future, timezone boundary dates
- File uploads (if applicable): wrong MIME type, zero-byte files, enormous files, filenames with special characters

Report which inputs are not handled gracefully and what happens when they're submitted.

---

## OUTPUT FORMAT

For each finding, provide:
1. **Severity** (🔴/🟠/🟡)
2. **Persona/approach** that uncovered it
3. **Exact location** (screen, field, step, endpoint)
4. **What happens now** (the problem)
5. **What should happen** (the fix)

Group findings by severity, then by location within each severity level. End with a summary count: X critical, Y important, Z minor.
```

---

## Tips for Use

- **Always use a fresh session** with no prior context to avoid anchoring bias.
- **Share your actual code or screenshots** — the more the agent can see, the more specific the findings.
- **Run jurisdiction-specific passes** if you operate in multiple markets (e.g., one pass with `[JURISDICTION]` set to UK, another set to US).
- **Iterate** — after fixing critical findings, run the prompt again to catch anything the fixes may have introduced.
