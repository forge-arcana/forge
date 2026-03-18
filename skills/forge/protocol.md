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
2. **Read accumulated learnings**: `<forge>/learnings/<learnings-file>` — skip if file doesn't exist yet (first run)
3. **Read project context**: the project's `CLAUDE.md` for stack, conventions, and current state
4. **Read stack guide**: `<forge>/skills/forge/stack-guide.md` for tech reference
5. **Scan project structure** to understand the codebase layout

After pre-flight, proceed to the art's own `## Process` or `## Dimensions` section.

## Execution (art-specific)

Each art defines its own execution in its SKILL.md:

- **Evaluative arts** (probe, poke, press, pound): adopt the persona, apply review framework/dimensions, web-search for current best practices, produce a structured report
- **Generative arts** (prime): adopt the persona, conduct a structured conversation/interview, produce a document

## Post-Flight (every art runs these after producing output)

1. **Write learnings** to the project's `memory/<learnings-file>`:
   ```markdown
   ## [Date] — [Short Title]
   - **Learning**: [context and evidence — universal principle, no project names/paths]
   - **Forge-worthy**: [yes/no] — [reason: "universal pattern" or "project-specific"]
   ```
2. Learnings marked `Forge-worthy: yes` will be auto-promoted by `/wrap` Stage 2 — no manual intervention needed
3. **Present results** to the user
4. **Suggest next steps**: fix findings (evaluative), run a complementary art, or `/fold` to absorb learnings into forge

## The Five Arts

| Art | Persona | Mode | Intensity |
|-----|---------|------|-----------|
| `/prime` | The originator (ideation → blueprint) | Generative | — |
| `/probe` | Senior solutions architect | Evaluative | — |
| `/poke` | Staff engineer (tech debt) | Evaluative | Light |
| `/press` | Staff engineer (go-live readiness) | Evaluative | Medium |
| `/pound` | 21 adversarial QA personas | Evaluative | Heavy |

The evaluative trio — **poke → press → pound** — escalates in intensity: poking for soft spots, pressing for structural readiness, pounding from every angle.

## Learning Cycle

```
Art runs → writes to project's memory/<learnings-file>
→ /wrap auto-promotes Forge-worthy items
→ accumulates in ~/.claude/learnings/
→ /fold absorbs into <forge>/learnings/
→ next art run reads global learnings in pre-flight
```
