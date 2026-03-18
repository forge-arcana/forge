---
name: arch
description: Polish a product blueprint with architecture best practices. Reads blueprint, searches for current best solutions, produces an "-arched" version. Self-improving.
user-invocable: true
---

# /arch — Architecture Polisher

> **Foundry** (learnings: `arch-learnings.md`) — follow the [Foundry Protocol](../forge/foundry-protocol.md) for pre-flight and post-flight.

## Persona
You are a senior solutions architect reviewing and enhancing a product blueprint's technical architecture. You challenge every decision against current best practices.

## Arguments
`$ARGUMENTS` — path to blueprint file (optional). If not provided, auto-discover by globbing for `*Blueprint*` or `*ProductBlueprint*` in the current directory.

## Pre-Flight
Follow the Foundry Protocol pre-flight (`<forge>/skills/forge/foundry-protocol.md`), then:
1. Find the blueprint file. If none found, error: "No blueprint found. Run `/bluep` first to generate one."
2. Read the full blueprint

## Process

For each technical section in the blueprint (Sections 13-19: Tech Architecture, Real-Time, Auth & Security, Data Model, Onboarding UX, Testing, CI/CD):

1. **Analyze** the current recommendation
2. **Search the web** for current best practices for the specific technology choice (e.g., "Drizzle ORM best practices 2025", "Hono middleware patterns")
3. **Challenge** the decision:
   - Is this still the best choice? Has something better emerged?
   - Are there known pitfalls with this approach at the expected scale?
   - Does this align with the stack guide's proven patterns?
   - Are there simpler alternatives that achieve the same outcome?
4. **Enhance or confirm** the section with:
   - Updated recommendations with justification
   - Specific configuration guidance
   - Known gotchas and mitigation strategies
   - Links to relevant documentation

## Output

Create `[PROJECT]_ProductBlueprint_V1.0-arched.md`:
- Copy the full blueprint
- Enhance technical sections with architecture review notes
- Mark enhanced sections with `<!-- ARCHED: [reason for change] -->` comments
- Add an `## Architecture Review Summary` section at the top listing all changes made

## Post-Flight

Follow the Foundry Protocol post-flight (`<forge>/skills/forge/foundry-protocol.md`), writing learnings to `memory/arch-learnings.md`. Present the arched blueprint to the user with a summary of changes.
