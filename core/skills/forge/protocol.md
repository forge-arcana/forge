# Forge Protocol

> Reference document for all art-type skills. Arts are skills that adopt a specialist persona and have a self-improving learning loop. Each art's SKILL.md references this protocol for shared pre-flight and post-flight steps.
>
> Path conventions: `<forge>` = the forge repo path; `<membrane>` = the harness's per-tool config directory (`~/.claude/` for Claude Code, `~/.bob/` for Bob, etc.); `<rules-file>` = the harness's global rules file (`~/.claude/CLAUDE.md` for Claude Code, `AGENTS.md` for Bob).

## What Is an Art?

An art is a skill with a specialist persona. It differs from a task skill in two ways:

1. **Persona** — the agent adopts a specialist identity (originator, architect, staff engineer, QA adversary) that changes *how* it thinks, not just *what* it does
2. **Self-improving loop** — it captures learnings after each run, which feed back into future runs via the forge learning cycle

Arts live in `core/skills/` alongside task skills. They deploy via the same `/forge` cycle — no separate infrastructure.

## Convention

Arts use minimal skill frontmatter (`name`, `description`). Adapters add harness-specific frontmatter (e.g., `user-invocable` for Claude Code) at build time. The art identity is declared in the SKILL.md body:

```markdown
> **Art** (learnings: `<name>-learnings.md`) — follow the [Forge Protocol](../forge/protocol.md) for pre-flight and post-flight.
```

The learnings filename tells the protocol which file to read during pre-flight and write to during post-flight.

## Pre-Flight (every art runs these before starting)

0. **Token preflight (Claude Code only)** — workaround for the upstream Claude Code OAuth race (see [WORKAROUNDS.md](../../../WORKAROUNDS.md) WA-001):
   ```bash
   bash <forge>/core/scripts/agent-preflight.sh $$
   ```
   Idempotent. Refreshes the OAuth token if <30 min remaining and spawns a background keeper for this session if one isn't already running. Required on Claude Code before any subagent fan-out — otherwise multi-agent skills race on token refresh and crash with `invalid_grant`. The keeper auto-exits when the calling skill's process dies; no teardown needed. Skip this step on harnesses without OAuth race issues.

1. **Resolve forge path** from the harness's global rules file (e.g., `~/.claude/CLAUDE.md` `forge-path:` line for Claude Code, or the equivalent rules file for other harnesses, managed by `/forge`)
2. **Launch steps 2-6 in parallel** (all independent after forge path is resolved):
   - **Read accumulated learnings**: `<forge>/learnings/<learnings-file>` — skip if file doesn't exist yet (first run)
   - **Read project context**: the project's `CLAUDE.md`/`AGENTS.md` for stack, conventions, and current state
   - **Read stack guide**: `<forge>/core/skills/forge/stack-guide.md` for tech reference — pay special attention to the **Logging Convention** section; all evaluative arts should validate projects against it
   - **Scan project structure** to understand the codebase layout
   - **Load web research cache**: read `memory/.web-cache.json` if it exists — use cached results for queries within their TTL (see Web Research Cache below)

After pre-flight, proceed to the art's own `## Process` or `## Dimensions` section.

## Parallel Execution Principle

> **HARD RULE**: Independent work MUST run in parallel when the harness supports it. Never block on sequential execution when tasks have no dependencies and parallel sub-agent spawning is available.

- **Fan-out**: When multiple analyses, dimensions, sections, or web searches are independent, spawn them as parallel subagents or parallel tool calls in a single message. If your harness lacks parallel sub-agent spawning, walk them sequentially.
- **Sync point**: Only wait when a downstream step depends on upstream results. State the sync point explicitly: "After all parallel tasks complete, proceed to..."
- **Batch web searches**: When multiple web searches are needed (e.g., one per section/dimension), launch all uncached searches in a single parallel batch.
- **Evidence-then-fan-out pattern**: Many arts collect evidence once (script or reads), then analyze across multiple dimensions. The analysis phase is the parallelization target — spawn one subagent per dimension/section/persona.

This principle applies to ALL arts and skills. When in doubt, ask: "Does this step depend on the previous step's output?" If no, run them in parallel (when supported).

## Execution (art-specific)

Each art defines its own execution in its SKILL.md:

- **Evaluative arts** (probe, poke, preen, press, pound): adopt the persona, apply review framework/dimensions, web-search for current best practices, produce a structured report
- **Generative arts** (prime): adopt the persona, conduct a structured conversation/interview, produce a document
- **Investigative arts** (pry): decompose blockers, aggressively search for alternatives, challenge assumptions until a path forward emerges

## Web Research Cache

Evaluative arts search the web for current best practices. To avoid redundant queries across runs, arts use a project-level cache.

### Location

`memory/.web-cache.json` in the project directory.

### Format

```json
{
  "queries": {
    "drizzle-orm-best-practices": {
      "query": "Drizzle ORM best practices 2025",
      "summary": "Key findings summarized in 2-3 sentences...",
      "sources": ["https://...", "https://..."],
      "cached_at": "2026-03-19T00:00:00Z",
      "ttl_days": 30
    }
  }
}
```

### Workflow

1. **Before web search**: normalize the query to a key (lowercase, strip year, hyphenate). Check if a matching entry exists in cache with `cached_at + ttl_days > today`. If yes, use the cached summary instead of searching.
2. **After web search**: write the result to cache — summary of findings, source URLs, timestamp, and TTL (default 30 days).
3. **Expired entries**: if an entry exists but is past TTL, re-search and overwrite.

### Key Normalization

Strip the year, lowercase, replace spaces with hyphens:
- `"Drizzle ORM best practices 2025"` → `drizzle-orm-best-practices`
- `"Hono middleware patterns 2026"` → `hono-middleware-patterns`

This ensures the same topic maps to one cache key regardless of when the search runs.

## Post-Flight (every art runs these after producing output)

1. **Write learnings** to the project's `memory/<learnings-file>`:
   ```markdown
   ## [Date] — [Short Title]
   - **Learning**: [context and evidence — universal principle, no project names/paths]
   - **Forge-worthy**: [yes/no] — [reason: "universal pattern" or "project-specific"]
   ```
2. Learnings marked `Forge-worthy: yes` will be promoted by `/forge`'s fold phase (3d) — scans project memories, genericizes, and promotes to the membrane's `learnings/general.md`
3. **Present results** to the user
4. **Suggest next steps**: fix findings (evaluative), run a complementary art, or `/forge` to absorb learnings

## The Masters

Above the arts stand three masters — distinct domains, complementary roles. The Smith builds the work; the Wedge gives it a face; the Warden tends the forge that does the building.

### The Smith — Master Builder

`/smith` is the user's proxy for construction. Smith is not an art. It is the one who wields them all.

Smith consumes a probed Blueprint + Pattern (from `/prime` + `/probe` + `/preen`) plus a Touchstone (from `/wedge`) and autonomously forges the product through iterative **heats** — cycles of plan, build, evaluate, fix. It summons **apprentices** (subagents) for parallel work, selects arts by escalation ladder, and converges on perfection through a relentless final gate. The arts sharpen themselves through smith's repeated use. The more the smith works, the sharper everything gets.

When a Touchstone exists, Smith reads `[PROJECT]_03e_Touchstone_V1.0.md` for the typed token contract (YAML frontmatter — colors, typography, spacing, components — plus Do's-and-Don'ts) and binds every UI-facing apprentice to those tokens AND the project-specific Do's/Don'ts. The HTML is consulted for visual reference. Apprentices that introduce non-Touchstone fonts, colors, motion, or violate a Do/Don't are rejected and re-tasked.

Smith has its own learning membrane (three layers: orchestration, delegation, art proficiency) and invokes `/wrap` at milestones autonomously. See `core/skills/smith/SKILL.md` for the full architecture.

### The Wedge — Master of Aesthetic

`/wedge` is the user's proxy for visual identity. Wedge is not an art. It is the master that drives a single decisive thrust which separates the project's identity from generic AI slop.

Wedge reads the **Opus + Vow** — the manuscript and the pledge — and from them produces a prose **Soul Brief**: what the product IS (sensorial), what it ISN'T (anti-aesthetic), examples from life (non-design references — songs, buildings, moments in nature, tools from other eras), forbidden defaults (project-specific gravity wells the model would reach for unconsciously), and three derived **essence-lenses** tuned to this product (e.g., `instrument / archive / dwelling`). The lens — not Family × Tone — is the apprentice commission. The Family × Tone library survives as an optional vocabulary shelf an apprentice MAY draw from, MAY invent against, or MAY ignore; when it was the commission grammar, three apprentices reading the same Opus and the same shelf converged to the same three slots across projects, and the shelf's agency-portfolio gravity flattened product-soul into shelf-fits. Three parallel design-apprentices, one lens each, each return a Direction Card (markdown spec citing examples-from-life that shaped the choices) and a scoped HTML fragment (rendered vision). An anti-convergence audit inspects the three fragments for visual rhyme — hero structure, atmospheric backdrop, color temperature, vocabulary collapse, Forbidden / Banned Defaults violations — and respawns offending apprentices with the rhyme called out. The Wedge then mechanically assembles the cleared fragments into a single `[PROJECT]_03c_PreviewTouchstone_V1.0.html` with a tab selector at the top. The user opens that one file, clicks through the directions side-by-side, and picks one (or hybridizes via Other; the Wedge synthesizes into ONE — no two-aesthetics-fused), or asks the Wedge to regenerate the council with feedback if none of the three lands the soul (the Wedge revises the Soul Brief, re-derives the lens trio, re-runs the council; capped at two regenerate cycles per /wedge run, after which the Wedge halts and recommends a /prime revisit). Visual decisions need visual artifacts. Later heats then build the Touchstone in two paired forms: `[PROJECT]_03e_Touchstone_V1.0.html` (the *vision* — a self-contained masterpiece) and `[PROJECT]_03e_Touchstone_V1.0.md` (the *contract* — DESIGN.md format with typed YAML tokens + project-specific Do's/Don'ts). Together they persist as the visual constitution; downstream skills consume the MD programmatically and reference the HTML for soul.

The Wedge enforces HARD RULES mechanically: soul before vocabulary (Soul Brief drives, Family × Tone is reference shelf), banned defaults (no Inter/Roboto/Space Grotesk, no purple-on-white), required substance (lens-conditional — restraint counts as substance), commit to ONE direction (no hedging), vary across projects (never converge on a house style), aesthetic serves the project, intentionality over intensity (hedging in the middle is the failure mode, not picking the wrong end), implementation matches vision (code density tracks the lens's demands).

See `core/skills/wedge/SKILL.md` for the full eight-heat process.

### The Warden — Master Tender

`/purge` is the Warden — guardian of the forge itself. While the Smith forges products from blueprints, the Warden ensures the forge that does the forging stays sharp and pure. Stale knowledge dulls the blade. Drift contaminates the steel. Duplicates weigh down the anvil. The Warden cleanses, consolidates, and prunes across four dimensions in parallel — Knowledge Purity, Memory Hygiene, Skill Fitness, Reference Integrity — then consolidates findings for user approval before applying.

The Warden lives only at `.claude/skills/purge/` (never deployed to user membranes — the Warden writes to forge directly, so confining the skill to the forge repo by construction prevents projects from writing to forge by proxy). It remains in the Claude-Code-specific bootstrap location by design; forge maintainers using a different harness invoke its logic via the same prose, manually.

### The forge cycle itself

`/forge` is not an art and not a master — it's a task skill with no persona and no learning loop. It is the gate through which arts and all other knowledge flow between forge and membrane. The Masters use the cycle; the cycle does not act on its own behalf.

## The Nine Arts

| Art | Persona | Mode | Intensity |
|-----|---------|------|-----------|
| `/prime` | The originator (ideation → blueprint) | Generative | — |
| `/probe` | Senior solutions architect | Evaluative | — |
| `/poke` | Staff engineer (code quality + tech debt) | Evaluative | Light |
| `/preen` | UI/UX evaluator (Don Norman's design principles) | Evaluative | Design |
| `/press` | Staff engineer (go-live readiness) | Evaluative | Medium |
| `/pound` | 21 adversarial QA personas | Evaluative | Heavy |
| `/pitch` | VC partner / business strategist | Evaluative | Business |
| `/pry` | The Lever (relentless solution-finder) | Investigative | — |
| `/praise` | The feedback router (closes the build-ship-learn loop) | Orchestrative | — |

(`/purge` is documented above under "The Warden — Master Tender" — it is a Master, not an art. It uses the same protocol but lives at `.claude/skills/purge/` and is forge-internal.)

### The Evaluative Trifecta — poke → press → pound

The trifecta escalates in intensity and broadens in scope:

- **`/poke`** — code quality + tech debt. Run frequently (every sprint, every major PR). Covers Uncle Bob's tenets (SOLID, Clean Code, Clean Architecture), band-aids, framework misuse, and logging hygiene. The workhorse.
- **`/press`** — go-live readiness. Run before launches, major releases, or environment promotions. Covers security, scalability, operations, compliance, observability, deployment, documentation.
- **`/pound`** — full adversarial assault. Run before critical launches or after major changes. 21 personas hammer from every angle.

**`/preen`** runs parallel to the trifecta — UI/UX design quality, triggered by interface changes rather than intensity escalation. Covers affordances, feedback, mapping, accessibility, platform conventions. The design eye.

**`/pitch`** runs orthogonal to the trifecta — business model viability, invocable at any lifecycle stage. Validate the business model before committing build resources (pre-build gate), and re-validate before ship (final gate) when the product has monetization. The investor's eye.

**`/praise`** closes the loop — takes real-world feedback (users, QA, testing) and routes it through the right arts. Routes UX issues to `/preen`, architecture concerns to `/probe`, code bugs to `/poke`, ops concerns to `/press`. Produces a blueprint delta and a change brief for `/smith`. Run after every feedback cycle.

**Cadence**: poke often, preen on UI changes, pitch before building and before shipping, press before milestones, pound before ship, praise after every feedback cycle. `/purge` stands apart — it tends the forge itself, not projects.

## Learning Cycle

```
Art runs → writes to project's memory/<learnings-file>
→ /forge fold phase (3d) promotes Forge-worthy items to <membrane>/learnings/general.md
→ /forge fold phases (3e, 3g) triage, genericize, and absorb into <forge>/learnings/ and <forge>/memory/
→ next art run reads global learnings in pre-flight
```
