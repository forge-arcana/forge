# /prime Learnings

> Accumulated learnings from prime sessions (ideation, pitch, and blueprint). Absorbed by the `/forge` cycle.

<!-- Add learnings below this line -->

## Recognize Existing Artifacts Before Starting From Zero (2026-03-21)
**Learning**: When a founder already has a strong vision doc and product brief, recognize existing artifacts and skip to the next unresolved question rather than re-interviewing. The conversation naturally moves to cost feasibility before blueprint — founders need to know "can I afford to build this" before committing to a full spec.
**Apply when**: Starting any product discovery or blueprint session — check what the founder has already produced.

## Cross-Project Stack Reuse Reduces Cost and Risk (2026-03-21)
**Learning**: When a founder has an existing project with a proven stack, the strongest blueprint recommendation is "reuse what you know." An established stack transfers directly to a new project with zero learning curve. Cost analysis should explicitly call out "no learning curve" as a savings — time is the most expensive resource for a solo founder.
**Apply when**: Recommending technology for a new project — always check for existing projects/stacks first.

## SKILL.md Frontmatter Attributes (2026-03-26)
**Learning**: `allowed-tools` and `context` are NOT valid SKILL.md frontmatter attributes. Use `user-invocable: true` for user-invocable skills. Valid attributes: argument-hint, compatibility, description, disable-model-invocation, license, metadata, name, user-invocable.
**Apply when**: Authoring or reviewing SKILL.md files for any skill.

## Parallel Research Agents Accelerate Blueprint Interviews (2026-03-28)
**Learning**: For domain-specific products (legal tech, healthcare, fintech), launching 5+ parallel research agents at the start of the blueprint phase — covering market landscape, regulatory requirements, domain workflows, tech stack options, and AI capabilities — dramatically accelerates the interview rounds. The founder only needs to answer questions about their specific context; research agents fill in the domain knowledge. This turned a 7-round interview into ~4 focused conversations.
**Apply when**: Starting a blueprint for any product in a regulated or domain-specific industry. Launch research agents before the first blueprint round.

## Localization as Moat in Underserved Markets (2026-03-28)
**Learning**: In markets where the total addressable user base is too small for international SaaS players to localize (e.g., 70,000 Philippine lawyers), the strongest competitive moat is deep localization — local court rules, local billing customs, local regulatory compliance, local language. No competitor will invest engineering effort to serve a market this size. The real competitor is the status quo (Excel + Word + Viber + paper), not other software.
**Apply when**: Positioning any product targeting a professional market in a developing country. Check whether international alternatives have localized — if not, localization IS the moat.

## Founders Who Don't Know Internal Operations Still Reveal Key Insights (2026-03-28)
**Learning**: When a founder is building for someone else's organization (a friend's firm) and doesn't know internal details (billing structure, staffing, workflows), they still reveal critical design constraints through their observations: "the lawyers handle their own appointments" (= no dedicated scheduling staff, so the tool must be self-service), "they have a collections officer" (= billing and collections are real pain points). These casual observations are more valuable than detailed org charts — they reveal what the founder has noticed as broken or noteworthy.
**Apply when**: Interviewing a founder who is building for an organization they observe but don't operate. Listen for what they've noticed, not what they can describe in detail.

## Role-Play Walkthroughs Catch What Specs Miss (2026-03-28)
**Learning**: After completing a product blueprint, walking through it as each user persona (partner, associate, secretary, client) reveals critical operational gaps that spec-writing misses. Engineering-minded specs are strong on data models and workflows but weak on daily-use UX (no "my day" dashboard, no action queue), people management (no offboarding, no leave coverage), and edge cases (incoming mail receipt triggering deadlines). A regulatory persona walkthrough (IBP inspector) catches compliance gaps that even domain-aware engineering misses (privilege waiver through AI APIs, AML obligations, Neypes fresh period rule). This three-pass approach (spec → persona walkthroughs → regulatory review) should be standard for any product in a regulated industry.
**Apply when**: After completing any blueprint for a regulated industry product. Always run persona walkthroughs and a regulatory review pass before declaring the blueprint final.

## Blueprint Versioning Keeps the Process Clean (2026-03-28)
**Learning**: Publishing V1.0 first, then running reviews against it, then producing V2.0 with fixes is cleaner than trying to get it perfect in one pass. V1.0 establishes the baseline. The gap analysis and compliance review become standalone reference documents. V2.0 incorporates everything with a clear audit trail of what changed and why. The founder can also compare versions to understand what was improved.
**Apply when**: Any blueprint that will undergo review cycles. Publish V1.0 early, run reviews, produce V2.0. Don't try to make V1.0 perfect.

## Generated Documents Must Reside in docs/ (2026-03-29)
**Learning**: Art-generated documents (Opus, Vow, Pitch, Blueprint, Pattern, and any art reports) must be written to the project's `docs/` directory, not the project root. Root-level documents create clutter and mix specs with code. Create `docs/` if it doesn't exist.
**Apply when**: Any art produces a document output — Opus, Vow, Pitch, Blueprint, Pattern, or any standalone art report.

## /prime Must Auto-Invoke /probe Then /preen After Blueprint (2026-03-29)
**Learning**: After Blueprint generation completes, `/prime` should automatically invoke `/probe` (architecture review), then `/preen` (UI/UX review) if the product has UI-facing features — without user intervention. This catches structural and design issues before `/smith` begins building. Both probe and preen write into a single consolidated artifact: `docs/[PROJECT]_Pattern_V1.0.md`. /probe writes the Architecture section; /preen appends the UX section.
**Apply when**: Running `/prime` to Blueprint completion. Both quality gates run automatically as part of Phase 3, producing the Pattern that /smith consumes.

## Never Infer Founder Identity From Tool/Extension Data (2026-04-25)
**Learning**: A founder pasting an idea into chat hasn't consented to having their email, name, or git config scraped from IDE selection context, opened files, or extension metadata. Inferring personal data from tool sessions is a privacy boundary violation — even when the data is "available." When the Opus needs to refer to the user, default to neutral identifiers (`[Founder]`, `the user`) until they introduce themselves explicitly within the conversation.
**Apply when**: Writing the Opus, Vow, Pitch, or any /prime artifact. Use the founder's name only if they've stated it in conversation — never if you only know it from email signatures, git config, or extension data.

## No Human-Scale Development Estimates In Discovery (2026-04-25)
**Learning**: Asking "what's your timeline?" or "when do you need this?" assumes a sprint-based dev cycle that doesn't apply when /smith builds MVPs in hours. These questions mislead founders into planning months of development for work that can complete in an afternoon. Replace timeline questions with *priority* (what's MVP?), *scope* (what's Phase 2?), and *external business milestones* (pitch day, funding close, launch event). Architecture stack recommendations should also drop "timeline" as a constraint.
**Apply when**: Any /prime round that touches scope, stack choice, or roadmap. Never frame estimates around traditional dev cycles. Frame them around external business commitments.

## Research Before Asking The Founder To Research (2026-04-25)
**Learning**: Prime is here to estimate, project, and hypothesize on the founder's behalf — not to push discovery legwork back at them. For anything publicly searchable (market size, competitor landscape, regulatory requirements, precedent products) — WebSearch first, build a defensible hypothesis with sources, then present it for the founder to confirm, refine, or correct. The founder brings *lived insight* (what's broken, who hurts, why now); Prime brings *researched context* (numbers, landscape, precedent). Don't reverse the roles by saying "go talk to 5 customers first" or "let me know once you've done the market research."
**Apply when**: Market sizing, competitor mapping, regulatory questions, or any domain context discovery. Always research-first, ask-second. Reserve founder questions for nuance the internet doesn't capture (cultural dynamics, unindexed local players, on-the-ground reality).

## On-Demand Workflow Bypasses Two-Sided Marketplace Cold Start (2026-04-25)
**Learning**: Two-sided marketplaces face a cold-start problem when they require pre-existing data on both sides. The on-demand alternative makes every interaction self-contained: the requesting party triggers the workflow, the subject nominates their own counterparties, counterparties respond to a one-time questionnaire. Zero pre-existing data required. Each interaction generates its own chain from scratch. The value proposition becomes the automation and structure, not the database.
**Apply when**: Any blueprint for a two-sided marketplace facing a cold-start problem — reference checks, background checks, reputation systems, vetting workflows. On-demand beats pre-populated; let the subject nominate their own counterparties.

## Per-Event Pricing Fits Low-Frequency, High-Stakes Services Better Than Subscription (2026-04-25)
**Learning**: Subscription pricing creates friction when a service is used infrequently (a handful of times per year) but the stakes are high when used. A per-event price aligns cost with value delivery: customers pay only when actively using the service, not monthly for something that sits idle. Subscription fatigue is real — a recurring charge for something used twice a year generates churn. Per-event pricing also lowers the activation barrier: no commitment, no trial, just pay and go.
**Apply when**: Pricing any service that is event-driven rather than continuous. Evaluate subscription vs. per-event based on usage frequency and decision stakes.

## Regional Data-Privacy Compliance Is a Data Model Constraint, Not a Feature (2026-04-25)
**Learning**: For platforms handling personal or sensitive personal information, regional data-privacy regulations (GDPR in the EU, CCPA in California, LGPD in Brazil, RA 10173 in the Philippines, etc.) must be designed into the data model from Day 1: explicit consent with timestamps, data subject rights (view + dispute + deletion), data retention schedule with automated purge, regulator registration where required before public launch. These are not checkbox features to add later — the consent log, dispute table, and deletion schedule are architectural requirements that affect every table touching personal data.
**Apply when**: Any product handling personal or sensitive personal information. Identify the applicable regional regulations early and treat them as design constraints; build the consent infrastructure before any user-facing features.
