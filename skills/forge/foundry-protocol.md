# Foundry Protocol

> Reference document for all foundry-type skills. Foundries are skills that adopt a specialist persona and have a self-improving learning loop. Each foundry's SKILL.md references this protocol for shared pre-flight and post-flight steps.

## What Is a Foundry?

A foundry is a skill with `type: foundry` in its frontmatter. It differs from a task skill in two ways:

1. **Persona** — the agent adopts a specialist identity (architect, staff engineer, QA adversary, pitch coach, product strategist) that changes *how* it thinks, not just *what* it does
2. **Self-improving loop** — it captures learnings after each run, which feed back into future runs via the forge learning cycle

Foundries live in `skills/` alongside task skills. They deploy via the same cast/fold/mark pipeline — no separate infrastructure.

## Convention

Foundries use standard skill frontmatter (`name`, `description`, `user-invocable`). The foundry identity is declared in the SKILL.md body:

```markdown
> **Foundry** (learnings: `<name>-learnings.md`) — follow the [Foundry Protocol](../forge/foundry-protocol.md) for pre-flight and post-flight.
```

The learnings filename tells the protocol which file to read during pre-flight and write to during post-flight.

## Pre-Flight (every foundry runs these before starting)

1. **Resolve forge path** from `~/.claude/CLAUDE.md` `forge-path:` line (managed by `/cast`)
2. **Read accumulated learnings**: `<forge>/learnings/<learnings-file>` — skip if file doesn't exist yet (first run)
3. **Read project context**: the project's `CLAUDE.md` for stack, conventions, and current state
4. **Read stack guide**: `<forge>/skills/forge/stack-guide.md` for tech reference
5. **Scan project structure** to understand the codebase layout

After pre-flight, proceed to the foundry's own `## Process` or `## Dimensions` section.

## Execution (foundry-specific)

Each foundry defines its own execution in its SKILL.md:

- **Evaluative foundries** (arch, poke, press, pound): adopt the persona, apply review framework/dimensions, web-search for current best practices, produce a structured report
- **Generative foundries** (pitch, bluep): adopt the persona, conduct a structured interview, produce a document

## Post-Flight (every foundry runs these after producing output)

1. **Write learnings** to the project's `memory/<learnings-file>`:
   ```markdown
   ## [Date] — [Short Title]
   - **Learning**: [context and evidence — universal principle, no project names/paths]
   - **Forge-worthy**: [yes/no] — [reason: "universal pattern" or "project-specific"]
   ```
2. Learnings marked `Forge-worthy: yes` will be auto-promoted by `/wrap` Stage 2 — no manual intervention needed
3. **Present results** to the user
4. **Suggest next steps**: fix findings (evaluative), run a complementary foundry, or `/fold` to absorb learnings into forge

## The Six Foundries

| Foundry | Persona | Mode | Intensity |
|---------|---------|------|-----------|
| `/arch` | Senior solutions architect | Evaluative | — |
| `/poke` | Staff engineer (tech debt) | Evaluative | Light |
| `/press` | Staff engineer (go-live readiness) | Evaluative | Medium |
| `/pound` | 21 adversarial QA personas | Evaluative | Heavy |
| `/pitch` | Investor advisor / storyteller | Generative | — |
| `/bluep` | Product strategist | Generative | — |

The evaluative trio — **poke → press → pound** — escalates in intensity: poking for soft spots, pressing for structural readiness, pounding from every angle.

## Learning Cycle

```
Foundry runs → writes to project's memory/<learnings-file>
→ /wrap auto-promotes Forge-worthy items
→ accumulates in ~/.claude/learnings/
→ /fold absorbs into <forge>/learnings/
→ next foundry run reads global learnings in pre-flight
```
