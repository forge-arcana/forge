---
name: pound
description: "Deep QA analysis using 21 adversarial personas. Generates tests, finds edge cases, audits security/accessibility/compliance. Self-improving. TRIGGER when: user wants thorough QA, comprehensive testing, edge case analysis, or 'break this.'"
user-invocable: true
---

# /pound — Deep Testing & Analysis

> **Art** (learnings: `pound-learnings.md`) — follow the [Forge Protocol](../forge/protocol.md) for pre-flight and post-flight.

## Persona
You are pounding this project on the anvil — running a comprehensive QA and adversarial review using 21 specialized personas. Every hammer blow from a different angle.

## Arguments
`$ARGUMENTS` — scope of the review (e.g., `/pound "user registration flow"`, `/pound "payment system"`). If not provided, scan the project to determine scope.

## Process

1. **Pre-flight** — launch these reads **in parallel** (all independent):
   - Read the `qa-framework.md` file in the same directory as this skill
   - Follow the Forge Protocol pre-flight (learnings, stack guide, project CLAUDE.md)
   - If no `$ARGUMENTS`, run `git log --oneline -10` to determine scope

2. **Gather scope context** from the parallel reads:
   - If `$ARGUMENTS` provided, focus on that scope
   - If no arguments, use git changes and CLAUDE.md to determine scope
   - Identify: `[PRODUCT_NAME]`, `[TECH_STACK]`, `[FEATURE_SCOPE]`, `[JURISDICTION]`

3. **Fill context variables** in the framework:
   - `[PRODUCT_NAME]` — from CLAUDE.md or argument
   - `[TECH_STACK]` — from project's stack or stack-guide.md
   - `[FEATURE_SCOPE]` — from `$ARGUMENTS` or auto-detected
   - `[JURISDICTION]` — ask user if not obvious from project context

4. **Execute the review** (all 3 parts from the framework):
   - **Part 1**: Practical QA review — systematic testing of the scoped feature (runs first to establish baseline context)
   - **After Part 1 completes, launch Parts 2 and 3 in parallel:**
     - **Part 2**: Persona-based simulation — **spawn parallel subagents in batches** across the 21 personas (confused user, clipboard paster, mobile user, power user, lawyer, security expert, spammer, fraudster, accessibility auditor, competitor, international user, support staff, offline user, returning user, multi-device user, elite developer, alien, radical inclusion auditor, testing strategist, growth/business strategist). Each persona's review is independent.
     - **Part 3**: Adversarial input generation — craft malicious/edge-case inputs (runs as parallel subagent alongside Part 2)

5. **Output findings** grouped by severity:

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

Follow the Forge Protocol post-flight (`<forge>/skills/forge/protocol.md`), writing learnings to `memory/pound-learnings.md`.
