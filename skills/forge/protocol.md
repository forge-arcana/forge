# Forge Protocol

> Reference document for all art-type skills. Arts are skills that adopt a specialist persona and have a self-improving learning loop. Each art's SKILL.md references this protocol for shared pre-flight and post-flight steps.

## What Is an Art?

An art is a skill with a specialist persona. It differs from a task skill in two ways:

1. **Persona** — the agent adopts a specialist identity (originator, architect, staff engineer, QA adversary) that changes *how* it thinks, not just *what* it does
2. **Self-improving loop** — it captures learnings after each run, which feed back into future runs via the forge learning cycle

Arts live in `skills/` alongside task skills. They deploy via the same cast/fold/mark pipeline — no separate infrastructure.

## Convention

Arts use standard skill frontmatter (`name`, `description`, `user-invocable`). The art identity is declared in the SKILL.md body:

```markdown
> **Art** (learnings: `<name>-learnings.md`) — follow the [Forge Protocol](../forge/protocol.md) for pre-flight and post-flight.
```

The learnings filename tells the protocol which file to read during pre-flight and write to during post-flight.

## Pre-Flight (every art runs these before starting)

1. **Resolve forge path** from `~/.claude/CLAUDE.md` `forge-path:` line (managed by `/cast`)
2. **Launch steps 2-6 in parallel** (all independent after forge path is resolved):
   - **Read accumulated learnings**: `<forge>/learnings/<learnings-file>` — skip if file doesn't exist yet (first run)
   - **Read project context**: the project's `CLAUDE.md` for stack, conventions, and current state
   - **Read stack guide**: `<forge>/skills/forge/stack-guide.md` for tech reference — pay special attention to the **Logging Convention** section; all evaluative arts should validate projects against it
   - **Scan project structure** to understand the codebase layout
   - **Load web research cache**: read `memory/.web-cache.json` if it exists — use cached results for queries within their TTL (see Web Research Cache below)

After pre-flight, proceed to the art's own `## Process` or `## Dimensions` section.

## Parallel Execution Principle

> **HARD RULE**: Independent work MUST run in parallel. Never block on sequential execution when tasks have no dependencies.

- **Fan-out**: When multiple analyses, dimensions, sections, or web searches are independent, spawn them as parallel subagents or parallel tool calls in a single message.
- **Sync point**: Only wait when a downstream step depends on upstream results. State the sync point explicitly: "After all parallel tasks complete, proceed to..."
- **Batch web searches**: When multiple web searches are needed (e.g., one per section/dimension), launch all uncached searches in a single parallel batch.
- **Evidence-then-fan-out pattern**: Many arts collect evidence once (script or reads), then analyze across multiple dimensions. The analysis phase is the parallelization target — spawn one subagent per dimension/section/persona.

This principle applies to ALL arts and skills. When in doubt, ask: "Does this step depend on the previous step's output?" If no, run them in parallel.

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

1. **Before WebSearch**: normalize the query to a key (lowercase, strip year, hyphenate). Check if a matching entry exists in cache with `cached_at + ttl_days > today`. If yes, use the cached summary instead of searching.
2. **After WebSearch**: write the result to cache — summary of findings, source URLs, timestamp, and TTL (default 30 days).
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
2. Learnings marked `Forge-worthy: yes` will be promoted by `/fold` Part 3 Step 0 — scans project memories, genericizes, and promotes to `~/.claude/learnings/general.md`
3. **Present results** to the user
4. **Suggest next steps**: fix findings (evaluative), run a complementary art, or `/fold` to absorb learnings into forge

## The Smith — Master of the Forge

Above the arts stands `/smith` — the master builder, the user's proxy. Smith is not an art. It is the one who wields them all.

Smith consumes a probed blueprint (from `/prime` + `/probe`) and autonomously forges the product through iterative **heats** — cycles of plan, build, evaluate, fix. It summons **apprentices** (subagents) for parallel work, selects arts by escalation ladder, and converges on perfection through a relentless final gate. The arts sharpen themselves through smith's repeated use. The more the smith works, the sharper everything gets.

Smith has its own learning membrane (three layers: orchestration, delegation, art proficiency) and invokes `/wrap` at milestones autonomously. See `skills/smith/SKILL.md` for the full architecture.

## The Eight Arts

| Art | Persona | Mode | Intensity |
|-----|---------|------|-----------|
| `/prime` | The originator (ideation → blueprint) | Generative | — |
| `/probe` | Senior solutions architect | Evaluative | — |
| `/poke` | Staff engineer (code quality + tech debt) | Evaluative | Light |
| `/preen` | UI/UX evaluator (Don Norman's design principles) | Evaluative | Design |
| `/press` | Staff engineer (go-live readiness) | Evaluative | Medium |
| `/pound` | 21 adversarial QA personas | Evaluative | Heavy |
| `/pry` | The Lever (relentless solution-finder) | Investigative | — |
| `/purge` | The Purist (cleanser of the forge) | Cleansing | — |

### The Evaluative Trifecta — poke → press → pound

The trifecta escalates in intensity and broadens in scope:

- **`/poke`** — code quality + tech debt. Run frequently (every sprint, every major PR). Covers Uncle Bob's tenets (SOLID, Clean Code, Clean Architecture), band-aids, framework misuse, and logging hygiene. The workhorse.
- **`/press`** — go-live readiness. Run before launches, major releases, or environment promotions. Covers security, scalability, operations, compliance, observability, deployment, documentation.
- **`/pound`** — full adversarial assault. Run before critical launches or after major changes. 21 personas hammer from every angle.

**`/preen`** runs parallel to the trifecta — UI/UX design quality, triggered by interface changes rather than intensity escalation. Covers affordances, feedback, mapping, accessibility, platform conventions. The design eye.

**Cadence**: poke often, preen on UI changes, press before milestones, pound before ship. `/purge` stands apart — it tends the forge itself, not projects.

## Learning Cycle

```
Art runs → writes to project's memory/<learnings-file>
→ /fold Step 0 promotes Forge-worthy items to ~/.claude/learnings/general.md
→ /fold Steps 1-4 triage, genericize, and absorb into <forge>/learnings/
→ next art run reads global learnings in pre-flight
```
