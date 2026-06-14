---
name: pound
description: "Deep QA analysis using 21 adversarial personas. Generates tests, finds edge cases, audits security/accessibility/compliance. Self-improving. TRIGGER when: user wants thorough QA, comprehensive testing, edge case analysis, or 'break this.'"
---
<!-- model: sonnet | escalation: 21-persona fan-out → opus subagents -->

# /pound — Deep Testing & Analysis

> **Art** (learnings: `pound-learnings.md`) — follow the [Forge Protocol](../forge/protocol.md) for pre-flight and post-flight.

## Persona
You are pounding this project on the anvil — running a comprehensive QA and adversarial review using 21 specialized personas. Every hammer blow from a different angle.

## Arguments
`$ARGUMENTS` — scope of the review (e.g., `/pound "user registration flow"`, `/pound "payment system"`). If not provided, scan the project to determine scope.

## Process

1. **Pre-flight** — parallel reads: `qa-framework.md` in this skill's directory + Forge Protocol pre-flight (learnings, stack guide, project rules file). If no `$ARGUMENTS`, also run `git log --oneline -10` for scope.

2. **Scope detection** — `$ARGUMENTS` if provided, else git log + project rules file. Identify `[PRODUCT_NAME]`, `[TECH_STACK]`, `[FEATURE_SCOPE]`, `[JURISDICTION]` (ask user for jurisdiction if not obvious) and fill them into the framework.

3. **Execute the framework's three parts**:
   - **Part 1**: Practical QA review — runs first to establish baseline context.
   - **After Part 1, launch Parts 2 + 3 in parallel** as parallel subagents (or sequentially if your harness lacks parallel sub-agent spawning):
     - **Part 2**: Persona-based simulation — spawn parallel subagents across the 21 personas defined in `qa-framework.md`. Each persona's review is independent.
     - **Part 3**: Adversarial input generation — craft malicious/edge-case inputs.

4. **Output findings** grouped by severity:

```markdown
# QA Deep Dive — [FEATURE_SCOPE]
**Date**: [date] | **Product**: [PRODUCT_NAME]

## Summary
| Severity | Count |
|----------|-------|
| CRITICAL | X |
| IMPORTANT | X |
| MINOR | X |

## Findings

### [CRITICAL-001] Title
- **Persona**: [which persona found this]
- **Location**: `file:line`
- **Current behavior**: What happens now
- **Expected behavior**: What should happen
- **Steps to reproduce**: 1, 2, 3
- **Suggested fix**: Brief description

[repeat for each finding]
```

6. **Optionally generate test files** for critical findings — ask the user if they want test code generated.

## Post-Flight

Follow the Forge Protocol post-flight (`<forge>/core/skills/forge/protocol.md`), writing learnings to `memory/pound-learnings.md`.
