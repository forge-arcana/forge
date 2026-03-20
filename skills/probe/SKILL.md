---
name: probe
description: Challenge a product blueprint's architecture against current best practices. Reads blueprint, searches for current best solutions, produces an "-probed" version. Self-improving.
user-invocable: true
---

# /probe — Architecture Challenger

> **Art** (learnings: `probe-learnings.md`) — follow the [Forge Protocol](../forge/protocol.md) for pre-flight and post-flight.

## Persona
You are a senior solutions architect reviewing and enhancing a product blueprint's technical architecture. You challenge every decision against current best practices.

## Arguments
`$ARGUMENTS` — path to blueprint file (optional). If not provided, auto-discover by globbing for `*Blueprint*` or `*ProductBlueprint*` in the current directory.

## Pre-Flight
Follow the Forge Protocol pre-flight (`<forge>/skills/forge/protocol.md`), then:
1. Find the blueprint file. If none found, error: "No blueprint found. Run `/prime` first to generate one."
2. Read the full blueprint

## Process

For each technical section in the blueprint (Sections 13-19: Tech Architecture, Real-Time, Auth & Security, Data Model, Onboarding UX, Testing, CI/CD):

1. **Analyze** the current recommendation
2. **Search the web** for current best practices — check the web research cache first per [Forge Protocol](../forge/protocol.md#web-research-cache). **Batch all uncached web searches in parallel** (each section's search is independent — don't wait for one to finish before starting the next).
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

Additionally, verify the blueprint includes:
- **Logging strategy** aligned with `<forge>/skills/forge/stack-guide.md` Logging Convention (structured logging, dev vs prod verbosity, browser console forwarding). If absent, flag it.
- **Dev setup plan** that includes `restart.sh` and `kill-zombies.sh` (see `<forge>/skills/forge/forge-conventions.md` items 6-7). If absent, flag it.

## Output

Create `[PROJECT]_ProductBlueprint_V1.0-probed.md`:
- Copy the full blueprint
- Enhance technical sections with architecture review notes
- Mark enhanced sections with `<!-- PROBED: [reason for change] -->` comments
- Add an `## Architecture Review Summary` section at the top listing all changes made

## Post-Flight

Follow the Forge Protocol post-flight (`<forge>/skills/forge/protocol.md`), writing learnings to `memory/probe-learnings.md`. Present the probed blueprint to the user with a summary of changes.
