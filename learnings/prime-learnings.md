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
