# /prime Learnings

> Accumulated learnings from prime sessions (ideation, pitch, and blueprint). Absorbed by the `/forge` cycle.

<!-- Add learnings below this line -->

## Recognize What The Founder Already Brings (2026-03-21)
**Learning**: Before asking discovery questions, scan for what the founder has already produced or revealed: (1) **explicit artifacts** — vision docs, product briefs, prior pitches; skip re-interviewing and jump to the next unresolved question. (2) **prior stacks** — an established proven stack from another project transfers with zero learning curve; "no learning curve" is itself a savings worth naming in cost analysis (time is the most expensive resource for a solo founder). (3) **indirect signals** — when the founder is building for an organization they don't operate, offhand remarks ("the team handles their own scheduling", "they have a dedicated collections role") reveal more than detailed org charts; listen for what they've *noticed* as broken or noteworthy.
**Apply when**: Opening any /prime session. Before drafting interview questions, audit the founder's existing artifacts, prior projects, and incidental observations.

## SKILL.md Frontmatter Attributes (2026-03-26)
**Learning**: `allowed-tools` and `context` are NOT valid SKILL.md frontmatter attributes. Use `user-invocable: true` for user-invocable skills. Valid attributes: argument-hint, compatibility, description, disable-model-invocation, license, metadata, name, user-invocable.
**Apply when**: Authoring or reviewing SKILL.md files for any skill.

## Parallel Research Agents Accelerate Blueprint Interviews (2026-03-28)
**Learning**: For domain-specific products (legal tech, healthcare, fintech), launching 5+ parallel research agents at the start of the blueprint phase — covering market landscape, regulatory requirements, domain workflows, tech stack options, and AI capabilities — dramatically accelerates the interview rounds. The founder only needs to answer questions about their specific context; research agents fill in the domain knowledge. This turned a 7-round interview into ~4 focused conversations.
**Apply when**: Starting a blueprint for any product in a regulated or domain-specific industry. Launch research agents before the first blueprint round.

## Localization as Moat in Underserved Markets (2026-03-28)
**Learning**: In markets where the total addressable user base is too small for international SaaS players to localize, the strongest competitive moat is deep localization — local rules, local billing customs, local regulatory compliance, local language. No competitor will invest engineering effort to serve a market this size. The real competitor is the status quo (general-purpose tools, messaging apps, paper-based workflows), not other software.
**Apply when**: Positioning any product targeting a professional market in a developing country. Check whether international alternatives have localized — if not, localization IS the moat.

## Role-Play Walkthroughs Catch What Specs Miss (2026-03-28)
**Learning**: After completing a product blueprint, walking through it as each user persona reveals critical operational gaps that spec-writing misses. Engineering-minded specs are strong on data models and workflows but weak on daily-use UX (no "my day" dashboard, no action queue), people management (no offboarding, no leave coverage), and edge cases (external triggers that create downstream deadlines). A regulatory persona walkthrough catches compliance gaps that even domain-aware engineering misses (privilege/confidentiality boundaries with third-party APIs, anti-fraud reporting obligations, jurisdiction-specific procedural rules). This three-pass approach (spec → persona walkthroughs → regulatory review) should be standard for any product in a regulated industry.
**Apply when**: After completing any blueprint for a regulated industry product. Always run persona walkthroughs and a regulatory review pass before declaring the blueprint final.

## Blueprint Versioning Keeps the Process Clean (2026-03-28)
**Learning**: Publishing V1.0 first, then running reviews against it, then producing V2.0 with fixes is cleaner than trying to get it perfect in one pass. V1.0 establishes the baseline. The gap analysis and compliance review become standalone reference documents. V2.0 incorporates everything with a clear audit trail of what changed and why. The founder can also compare versions to understand what was improved.
**Apply when**: Any blueprint that will undergo review cycles. Publish V1.0 early, run reviews, produce V2.0. Don't try to make V1.0 perfect.

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
**Learning**: For platforms handling personal or sensitive personal information, regional data-privacy regulations (GDPR in the EU, CCPA in California, LGPD in Brazil, and country-specific data-protection acts in other jurisdictions) must be designed into the data model from Day 1: explicit consent with timestamps, data subject rights (view + dispute + deletion), data retention schedule with automated purge, regulator registration where required before public launch. These are not checkbox features to add later — the consent log, dispute table, and deletion schedule are architectural requirements that affect every table touching personal data.
**Apply when**: Any product handling personal or sensitive personal information. Identify the applicable regional regulations early and treat them as design constraints; build the consent infrastructure before any user-facing features.

## /prime Artifacts Belong in `opus/`, Not Project Root (2026-05-09)
**Learning**: /prime's six founding artifacts (`[PROJECT]_01_Opus_V1.0.md`, `_02_Vow_V1.0.md`, `_03e_Touchstone_V1.0.html`, `_04_Pitch_V1.0.html`, `_05_Blueprint_V1.0.md`, `_06_Pattern_V1.0.md`) — collectively the "Magnum Opus" — currently land at the project root. For prose-only projects (decks, one-pagers) root is fine. For engineering projects with `src/`, tests, package manifests, and configs, six founding documents at root creates real clutter alongside operational files. Move them to a dedicated `opus/` subdirectory — short, central-concept-named (the Opus is the anchor), grouping the founding documents together while keeping the engineering tree clean.
**Apply when**: Updating /prime's protocol — three concrete changes: (1) Pre-Flight glob scans `opus/*` first, then falls back to project root for backward compatibility with existing prose-only projects; (2) default write target becomes `opus/[PROJECT]_NN_*.md` — create `opus/` if absent; (3) cross-references between artifacts (Opus ↔ Vow) stay basename-relative and resolve naturally once both files share a directory; README and CLAUDE.md references in the consumer project point at `opus/[file]`. For projects that already have founding artifacts at the root from a previous run, leave them there (don't auto-migrate — that's a `/purge` concern); for new founding runs, write to `opus/` from the start.
