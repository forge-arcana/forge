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

- **Fan-out**: When multiple analyses, dimensions, sections, or web searches are independent, spawn them as parallel subagents or parallel tool calls in a single message. If your harness lacks parallel sub-agent spawning or per-spawn model selection, walk them sequentially at your session model.
- **Sync point**: Only wait when a downstream step depends on upstream results. State the sync point explicitly: "After all parallel tasks complete, proceed to..."
- **Batch web searches**: When multiple web searches are needed (e.g., one per section/dimension), launch all uncached searches in a single parallel batch.
- **Evidence-then-fan-out pattern**: Many arts collect evidence once (script or reads), then analyze across multiple dimensions. The analysis phase is the parallelization target — spawn one subagent per dimension/section/persona.

This principle applies to ALL arts and skills. When in doubt, ask: "Does this step depend on the previous step's output?" If no, run them in parallel (when supported).

## Model Tiers

Fan-out is not just *where* work splits — it's *what strength of model* each leg runs on. The tier names `opus`, `sonnet`, `haiku`, and `script` are the neutral vocabulary: flow text says "spawn each dimension as a sonnet-tier subagent" or "run the merge at opus tier", and each harness maps tiers to its own models.

### Tier semantics

| Tier | Work class |
|------|-----------|
| `opus` | High-judgment work — orchestration decisions, creative generation, synthesis, final verdicts, reviewing sonnet output |
| `sonnet` | Implementation-to-spec and structured rubric-evaluation legwork |
| `haiku` | Mechanical LLM work — collation, formatting, template filling |
| `script` | Deterministic work that leaves the LLM entirely — a shell/CLI step, not a model |

### Class → tier map

- **Evaluative legwork** (dimensions, personas, passes) → sonnet, with security carve-outs at opus and the merge/verdict step wired at opus
- **Merge / consolidation / final verdict** → opus
- **Creative generation** (ideation, identity, synthesis) → opus
- **Implementation-to-spec** → sonnet, with a named opus review gate
- **Mechanical** → haiku
- **Deterministic** → script

### Rules

1. **Every fan-out instruction names the tier per spawned agent**, in tool-neutral wording ("sonnet-tier subagent", "at opus tier"). A tier that isn't named in the flow text at the spawn step doesn't bind.
2. **Every sonnet leg names its review gate.** Three gate classes qualify:
   - (a) an **opus merge/consolidation step** that dedups, challenges unevidenced findings, and owns the final verdict
   - (b) an **existing evaluative art pass** that covers the leg's output
   - (c) a **user-review gate** — only for low-stakes, fully-user-visible output, and only when the flow keeps that output fully visible to the user before it takes effect
3. **Sequential fallback**: every fan-out skill carries this sentence — "If your harness lacks parallel subagent spawning or per-spawn model selection, run these steps sequentially at your session model."
4. **Defer, don't downgrade**: when a conditional opus gate (a review that only fires sometimes) can't run at opus tier, defer the gated action and surface it to the user — never run the gate at a weaker tier and proceed.

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

Cache bookkeeping is script-tier work — `<forge>/core/scripts/web-cache.sh` implements this contract; call it instead of re-deriving keys or TTL arithmetic in-context:

1. **Before web search**: `web-cache.sh get "<raw query>"` — on HIT it prints the cached entry (use the summary instead of searching); on `MISS`/`EXPIRED` (exit 1), search.
2. **After web search**: `web-cache.sh put "<raw query>" --summary "<2-3 sentence findings>" --source <url> [--source <url>...]` — TTL defaults to 30 days (`--ttl` to override). Expired entries are overwritten by the same call.
3. Both subcommands take `--project <path>` when running outside the project root. Fan-out legs call the script directly — do not re-implement the lookup in spawn prompts.

**Fallback** (harness without the script): apply the same contract manually — normalize the query to a key (lowercase, strip year, hyphenate: `"Drizzle ORM best practices 2025"` → `drizzle-orm-best-practices`), use a cached entry only while `cached_at + ttl_days > today`, and write summary + sources + timestamp + TTL after each search. The normalization ensures the same topic maps to one cache key regardless of when the search runs.

## Post-Flight (every art runs these after producing output)

1. **Write learnings** to the project's `memory/<learnings-file>`:
   > **Path resolution (HARD):** `memory/` is the *project's* memory directory — the project root's `memory/` when running inside a repo, or the harness project-memory store otherwise (`~/.claude/projects/<project-slug>/memory/` for Claude Code). NEVER resolve `memory/` against the skill's own base directory (e.g. `~/.claude/skills/<art>/memory/`) — that orphans the learning inside the skill package and is invisible to `/forge`. When an art runs **outside any project** (e.g. a standalone `/pry`), write to the harness project-memory store, never the skill folder.
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
| `/pitch` | The founder's other voice (VC partner on `--critique`) | Generative | Synthesis |
| `/pry` | The Lever (relentless solution-finder) | Investigative | — |
| `/praise` | The feedback router (closes the build-ship-learn loop) | Orchestrative | — |

(`/purge` is documented above under "The Warden — Master Tender" — it is a Master, not an art. It uses the same protocol but lives at `.claude/skills/purge/` and is forge-internal.)

### The Evaluative Trifecta — poke → press → pound

The trifecta escalates in intensity and broadens in scope:

- **`/poke`** — code quality + tech debt. Run frequently (every sprint, every major PR). Covers Uncle Bob's tenets (SOLID, Clean Code, Clean Architecture), band-aids, framework misuse, and logging hygiene. The workhorse.
- **`/press`** — go-live readiness. Run before launches, major releases, or environment promotions. Covers security, scalability, operations, compliance, observability, deployment, documentation.
- **`/pound`** — full adversarial assault. Run before critical launches or after major changes. 21 personas hammer from every angle.

**`/preen`** runs parallel to the trifecta — UI/UX design quality, triggered by interface changes rather than intensity escalation. Covers affordances, feedback, mapping, accessibility, platform conventions. The design eye.

**`/pitch`** runs orthogonal to the trifecta — synthesis-and-alignment in the founder's voice, invocable at any lifecycle stage. Fuses Opus + Vow + Touchstone into the seven-section Pitch that aligns founder, cofounder, and investor. Run after a Touchstone is forged (before /probe, /preen, /smith); `--critique` adds the VC-partner review pass when external persuasion needs stress-testing.

**`/praise`** closes the loop — takes real-world feedback (users, QA, testing) and routes it through the right arts. Routes UX issues to `/preen`, architecture concerns to `/probe`, code bugs to `/poke`, ops concerns to `/press`. Produces a blueprint delta and a change brief for `/smith`. Run after every feedback cycle.

**Cadence**: poke often, preen on UI changes, pitch before building and before shipping, press before milestones, pound before ship, praise after every feedback cycle. `/purge` stands apart — it tends the forge itself, not projects.

## Learning Cycle

```
Art runs → writes to project's memory/<learnings-file>
→ /forge fold phase (3d) promotes Forge-worthy items to <membrane>/learnings/general.md
→ /forge fold phases (3e, 3g) triage, genericize, and absorb into <forge>/learnings/ and <forge>/memory/
→ next art run reads global learnings in pre-flight
```
