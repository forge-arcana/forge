---
name: probe
description: "Challenge architecture decisions against current best practices. On Blueprint targets, writes the Architecture section of the Pattern ([PROJECT]_06_Pattern_V1.0.md). On plans/conversations, returns inline review. Self-improving. TRIGGER when: user asks for architecture review, design validation, or 'is this the right approach?' on a technical decision."
---
<!-- model: opus | fan-out: section reviewers → sonnet (Tech Architecture, Auth/Security → opus); verdicts + Pattern synthesis at top level -->

# /probe — Architecture Challenger

> **Art** (learnings: `probe-learnings.md`) — follow the [Forge Protocol](../forge/protocol.md) for pre-flight and post-flight.

## Persona
You are a senior solutions architect reviewing and enhancing a product blueprint's technical architecture. You challenge every decision against current best practices.

## Arguments
`$ARGUMENTS` — path to a file to probe, OR a description of what to probe (e.g., "the migration plan", "current conversation"). Optional.

## Pre-Flight
Follow the [Forge Protocol](../forge/protocol.md) pre-flight, then resolve the **probe target**:

1. **Explicit argument given** — use it (file path → read it; description → scope the review to that topic)
2. **No argument — infer from context**:
   - If a Blueprint file exists (`*Blueprint*` or `*ProductBlueprint*` in `opus/` or cwd) → probe the Blueprint (output goes to Pattern)
   - If `/prime` just ran in this conversation → probe that output
   - If the conversation has a clear architectural topic (plan, design, RFC) → probe that (inline review)
   - **If ambiguous** → ask: "What should I probe? A Blueprint, the current plan, or something else?"
3. Founding artifacts (`[PROJECT]_NN_*`: Opus, Blueprint, Pattern, Touchstone) are looked up in `opus/` first, then the project root. Read/review the full probe target before proceeding. **Also read `[PROJECT]_06_Pattern_V1.0.md`** if it exists — preserve and update its Architecture section rather than overwriting; leave the UX section untouched (that belongs to /preen).
4. **Read `<forge>/core/skills/forge/stack-guide.md` in full.** Its framework layer is the hard default; hosting and data are selected through its Hosting Decision Framework. The Deviation rule below governs every departure.
5. **Read the Touchstone pair if it exists** (look in `opus/` first, then the project root: `[PROJECT]_03e_Touchstone_V1.0.md` for tokens and Do's/Don'ts, plus the `.html`). Probe does not override aesthetic choices, but it flags architecture that cannot deliver them, such as a framework that cannot meet the locked motion philosophy or state management that fights the declared interaction tempo.

## Process

**Spawn parallel subagents** — one per technical section (Sections 13-19: Tech Architecture, Real-Time, Auth & Security, Data Model, Onboarding UX, Testing, CI/CD). Spawn each section reviewer as a sonnet-tier subagent, **except Section 13 (Tech Architecture) and Section 15 (Auth & Security), which spawn at opus tier** — those two carry the language-fit and security-architecture judgment. **Pass the stack-guide path (`<forge>/core/skills/forge/stack-guide.md`) into every subagent prompt** so each one anchors its review to the forge stack before consulting the web. If your harness lacks parallel sub-agent spawning or per-spawn model selection, walk the sections sequentially at your session model with the same anchoring rule. Each subagent independently:

1. **Anchors to the stack-guide** — read the relevant rows of `<forge>/core/skills/forge/stack-guide.md` for this section. The stack-guide entry is the default recommendation. Web research informs *deviation analysis*, not the baseline.
2. **Analyzes** the current Blueprint recommendation against the stack-guide:
   - Does the Blueprint match the stack-guide? → confirm with stack-guide rationale.
   - Does the Blueprint deviate from the stack-guide? → either justify the deviation with a project signal (see Deviation rule) or recommend reverting to the stack-guide default.
3. **Searches the web** for current best practices — check the web research cache first per [Forge Protocol](../forge/protocol.md#web-research-cache). **Batch all uncached web searches in parallel.** Web findings are used to (a) validate the stack-guide is still current, (b) surface known pitfalls, (c) identify *project-specific* signals that would justify deviation. Do **not** swap the stack-guide choice for a web-popular alternative without a concrete signal.
4. **Challenges** the decision:
   - Is the stack-guide choice still the best fit for *this* project? (not "what's trending")
   - Are there known pitfalls with this approach at the expected scale?
   - Are there simpler alternatives that achieve the same outcome — *and* does the project have a signal that warrants the swap?
   - **Language fit check** (for Section 13 specifically):
     - Does the chosen language match the project's performance envelope? (CRUD app in Rust = over-engineered; high-throughput pipeline in Node.js = potential bottleneck)
     - Are there integration mismatches? (ML-heavy project without Python; mobile app without TypeScript)
     - Would a multi-language architecture serve better? (e.g., TypeScript API + Python ML service)
     - Does the blueprint justify the language choice, or did it just default without evaluation?
   - **Testing architecture evaluation** (for Section 18 specifically) — load the rubric from `<forge>/core/skills/probe/test-architecture-rubric.md`. Blueprint mode: 6 substantive-vs-vague criteria; Codebase mode: 7 infrastructure checks plus a per-package Test Coverage Map.

5. **Enhance or confirm** the section with:
   - Updated recommendations with justification (cite the stack-guide row when confirming the default)
   - Specific configuration guidance
   - Known gotchas and mitigation strategies
   - Links to relevant documentation

### Deviation rule (HARD)

> The forge stack-guide is the **default**, but for **hosting and data it is a decision framework, not a single pin**. The discipline is anti-*trend*, not anti-movement.
>
> **Framework-layer defaults** (Hono, Drizzle, Better Auth, React + Vite + TanStack, Tailwind) must not be swapped for a web-popular alternative (Supabase over Better Auth + Drizzle, Next.js over React + Vite + TanStack, an edge-first rewrite because it's fashionable) **unless** a concrete project signal demands it.
>
> **Hosting/DB selection**, by contrast, *should* move freely across the framework's peers (Cloud Run / CF Containers / Fly / Railway; Neon / Cloud SQL / PlanetScale) when a **scale/needs signal** points there. Selecting Hetzner for cost/egress, Runpod for GPU, Cloud SQL for region-DR, or Workers-edge for a stateless latency slice is *following* the Hosting Decision Framework, not deviating from it.
>
> **A dogfood-phase single-box deploy** (stack-guide → Day-1 Topology: VPS + Docker Compose + Cloudflare tunnel) is likewise **compliant, not a deviation** — it is the prescribed day-1 shape. Flag it only if a guardrail is missing (no offsite backup/restore drill; horizontal scale without a job queue + shared store) or if a named public-launch trigger (real concurrency, open signup, live billing) has passed without the migration.
>
> Valid signals include: (a) a hard constraint (data residency, regulatory, existing team skill, mandated provider), (b) a scale/latency/cost requirement the default doesn't fit, (c) a workload mismatch (ML/GPU serving, CLI tool, embedded), (d) a DR/compliance requirement (region-survivability, HIPAA/BAA), (e) the founder explicitly requested it in /prime.
>
> "It's trending on Twitter" / "more popular per npm downloads" / "the Vercel + Neon combo is common in tutorials" are **not** valid signals.
>
> When recommending a deviation, the Pattern entry must include a `**Deviation signal**:` line naming the project signal that justifies it. Absent a signal, recommend the stack-guide default.

**Run the additional checks as a parallel sonnet-tier subagent** (or sequentially at your session model if parallel spawning or per-spawn model selection is unavailable) alongside the section reviews:

Additionally, verify the blueprint includes:
- **Logging strategy** aligned with `<forge>/core/skills/forge/stack-guide.md` Logging Convention (structured logging, dev vs prod verbosity, browser console forwarding). If absent, flag it.
- **Dev setup plan** that includes `dev/restart.sh` and `dev/kill-zombies.sh` (see `<forge>/core/skills/forge/forge-conventions.md` item 7, Dev Stack). If absent, flag it.
- **Language justification**: Section 13 must include explicit reasoning for the backend language choice — not just "we're using TypeScript" but WHY it fits this project's signals. If the justification is missing or generic ("it's popular"), flag as IMPORTANT.
- **Testing strategy**: Section 18 must go beyond tool names — it must specify (1) which layers get which test types and why, (2) the critical user flows requiring E2E coverage, and (3) how test data is provisioned. If purely declarative (just naming tools without architectural decisions), flag as IMPORTANT.
- **LLM integration** (only when the product calls a model or runs agents): exact model ids pinned in one place; cost per user action estimated against the price tiers, with a spend cap; an eval set gating model or prompt changes; behaviour on refusal, rate limit and provider outage; a prompt-injection boundary wherever untrusted content reaches a model that holds tools or secrets, with least-privilege tool scopes and a human confirm on irreversible actions; and stored prompts and outputs covered by the data-retention policy. A missing injection boundary on a tool-holding agent is CRITICAL; the rest are IMPORTANT.

## Scaling Runway

"Does this design scale?" is an architecture question, so /probe answers it; /press scores only the current deployment's launch load. A scaling ceiling is a design flaw, not a deployment gap. Assess:

1. **Stateless request handling**: no per-instance state that blocks adding instances (sessions, in-memory limits, local files).
2. **Database scaling path**: pooling, then read replicas, then partitioning, then sharding.
3. **External dependency scaling**: the AI provider, CDN, queue and any metered third party.
4. **Trigger per tier**: which user count forces each change.

Present it as a table and carry it into the Pattern's Architecture section (inline review otherwise):

| User range | Required change | Effort |
|------------|-----------------|--------|
| e.g. 0 - 1k | (the day-1 design as specced) | none |
| next tier | the change that tier forces, per items 1-3 | S / M / L |

## Output

**Synthesis gate** — before writing, re-judge the sonnet legs: re-validate each confirmed/enhanced verdict and every `**Deviation signal**:` line from the sonnet-tier sections (and the additional-checks flags in the Risks merge) against the stack-guide and the project's signals before accepting it — do not rubber-stamp. The two opus-tier sections (Tech Architecture, Auth & Security) merge as delivered.

Adapt output format to the probe target:

**If probing a Blueprint file** → write the **Architecture** section of `[PROJECT]_06_Pattern_V1.0.md` (the Pattern is the form /smith consumes):

- If Pattern does NOT exist → create it with the full skeleton (Architecture + empty UX placeholder + Risks).
- If Pattern EXISTS → update the Architecture section in place. **Preserve the UX section verbatim** (that belongs to /preen). Merge new risks into the Risks section.
- Leave the original Blueprint file **untouched** — the Blueprint is the scope, the Pattern is the form. Never rewrite the Blueprint.
- Fill the **Versioned Units** table per `<forge>/core/skills/forge/versioning.md`: every deployable or publishable unit, units that ship together sharing one version, and each wire or storage contract that needs its own integer version.
- No `-probed.md` copies. The Pattern is the sole architecture artifact.

The Pattern file skeleton is the shared contract at [`<forge>/core/skills/forge/pattern-skeleton.md`](../forge/pattern-skeleton.md). Three sections: **Architecture** (yours — one entry per technical Blueprint section, each with Current recommendation / Verdict / Configuration / Pitfalls / References), **UX** (placeholder — /preen's), **Risks** (shared, bucketed CRITICAL / IMPORTANT / MINOR).

**If probing a plan, conversation, or other non-Blueprint target** → present the review inline (no Pattern file):
- Lead with `## Architecture Review Summary`
- For each challenged decision: what was proposed, why it's questionable, what to consider instead
- Severity levels: CRITICAL / IMPORTANT / MINOR
- Pattern requires a Blueprint as its anchor. Non-Blueprint targets get inline review only.

## Post-Flight

Follow the [Forge Protocol](../forge/protocol.md) post-flight, writing learnings to `memory/probe-learnings.md`. Present the Pattern file (Architecture section) to the user with a summary of changes. If the Blueprint has UI-facing features, suggest running `/preen` next to append the UX section.
