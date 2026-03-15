---
name: reforge
description: Feed everything back to forge. Syncs global config drift AND absorbs learnings from self-improving skills across all projects. Forge-project only.
user-invocable: true
---

# /reforge — Global Learning Absorber + Config Sync

Single command to feed all knowledge back into the forge repo. Does three things:

1. **Config sync** (old upforge) — push current global config into forge reference
2. **Learning absorption** — merge project learnings into forge's global learning store
3. **Learning redistribution** — route general/ad-hoc learnings to the right skill files

## Part 1: Config Sync

### Step 1: Read current state
- Read `~/.claude/CLAUDE.md` (global rules)
- Read `~/.claude/settings.json` (tool permissions) — if it exists
- Read `/root/dev/forge/code/claude-code-rules.md` (reference doc)

### Step 2: Diff
Compare all three and identify:
- **Additions**: Rules/permissions in global config that aren't in the reference
- **Removals**: Rules/permissions in the reference that aren't in global config
- **Conflicts**: Same rule exists in both but differs

### Step 3: Present deviations
```markdown
## Config Sync Report

| Aspect | Global Config | Forge Reference | Action |
|--------|--------------|-----------------|--------|
| [rule/permission] | [current value] | [reference value] | [add/remove/update] |
```

### Step 4: Apply (after user confirms)
- Update `code/claude-code-rules.md` to match current global config
- Follow sync rules from forge conventions:
  - CLAUDE.md "Bash Permissions" ↔ reference auto-allowed table
  - settings.json `permissions.allow` ↔ reference auto-allowed table
  - WebFetch domains must match exactly
  - Destructive commands NEVER in allow list
  - Hooks and additionalDirectories are machine-specific — never sync

## Part 2: Learning Absorption

### Step 1: Scan for learnings
Scan ALL available sources for learning files:

**Project learnings** (from self-improving skills):
- Check `~/.claude/settings.json` for `additionalDirectories`
- Scan `/root/dev/*/memory/*-learnings.md`
- Look for: `memory/arch-learnings.md`, `memory/audit-learnings.md`, `memory/quick-learnings.md`

**General learnings** (human-contributed):
- Read `/root/dev/forge/learnings/general.md` — ad-hoc insights added manually by the user
- These need to be **redistributed** to the right skill-specific learning files

**Claude Code memory** (auto-memory system):
- Scan `/root/.claude/projects/*/memory/` for feedback/project type memories that contain reusable patterns

### Step 2: Read existing knowledge base
Before evaluating new learnings, load everything we already know:
- Read ALL files in `/root/dev/forge/learnings/` (arch, audit, quick, global-patterns)
- Read ALL global skill SKILL.md files in `~/.claude/skills/*/SKILL.md` (the skills themselves encode knowledge)
- Build a mental model of what's already known, already incorporated, or already addressed

### Step 3: Triage — SHOW BEFORE ABSORBING
For each candidate learning found in Step 1, classify it:

| Status | Meaning |
|--------|---------|
| **NEW** | Not covered anywhere in existing knowledge — should be absorbed |
| **DUPLICATE** | Already exists in a learning file — skip |
| **INCORPORATED** | Already baked into a skill's SKILL.md instructions — skip |
| **SUPERSEDED** | Contradicted or replaced by a newer learning — flag for review |
| **CROSS-CUTTING** | Applies to multiple skills — route to `global-patterns.md` AND each relevant skill file |

Present the full triage table to the user using AskUserQuestion:

```markdown
## Learning Triage Report

### Candidates for Absorption
| # | Source | Learning Summary | Category | Status | Target File |
|---|--------|-----------------|----------|--------|-------------|
| 1 | jeepi/memory/arch-learnings.md | [one-line summary] | arch | NEW | arch-learnings.md |
| 2 | forge/learnings/general.md | [one-line summary] | quick | NEW | quick-learnings.md |
| 3 | hoa/memory/audit-learnings.md | [one-line summary] | audit | DUPLICATE | — |
| 4 | forge/learnings/general.md | [one-line summary] | arch+quick | CROSS-CUTTING | global-patterns.md + arch + quick |

### Already Known (auto-skipped)
| Source | Learning | Reason |
|--------|----------|--------|
| [source] | [summary] | Duplicate of [existing entry in file] |
| [source] | [summary] | Already incorporated in /arch SKILL.md step X |
```

**Wait for user confirmation before proceeding.** User can:
- Approve all NEW items
- Reject specific items
- Reclassify items (e.g., "actually #3 is new, the existing one is different")

### Step 4: Genericize & Absorb confirmed learnings

**CRITICAL: No project-specific details in forge learnings.** Before writing any learning to forge, strip ALL project-specific references:

| Strip | Replace with |
|-------|-------------|
| Project names (e.g., "Jeepi", "Hoa", "Sookie") | "the project" or omit |
| Specific file paths (e.g., `src/routes/hoa/auth.ts`) | Generic path pattern (e.g., "auth route handler") |
| Specific API keys, URLs, domains | "[API endpoint]", "[domain]" |
| Specific user/team names | "the team" or omit |
| Specific database names, table names | Generic description (e.g., "the user table") |
| Business logic details unique to one product | The general pattern it exemplifies |

The goal: every learning in forge should read as a **universal principle** that applies to any project using the same tech stack. If someone reads `arch-learnings.md` with zero context about any specific project, every entry should still make complete sense.

For each confirmed learning:
- **Genericize first** — rewrite the learning as a universal pattern
- Append to the appropriate file in `/root/dev/forge/learnings/`:
  - `arch-learnings.md` — architecture patterns and decisions
  - `audit-learnings.md` — go-live readiness patterns
  - `quick-learnings.md` — tech debt and logging patterns
  - `global-patterns.md` — cross-cutting patterns that span multiple categories
- Format each entry as:
  ```markdown
  ## [Short Title] (YYYY-MM-DD)
  **Learning**: [the genericized insight — no project names, no specific paths]
  **Apply when**: [context for when this learning is relevant]
  ```

### Step 5: Redistribute general.md
After absorption, process `learnings/general.md`:
- Any entry that was absorbed into a skill-specific file → remove from general.md
- Entries that don't map to any skill → keep in general.md
- Goal: general.md should only contain unprocessed or truly general insights

### Step 6: Report
```markdown
## Absorption Complete

### Summary
- Projects scanned: X
- Candidates found: X
- New learnings absorbed: X
- Duplicates skipped: X
- Incorporated (already in skills): X
- Redistributed from general.md: X

### Files Updated
| File | Entries Added |
|------|--------------|
| arch-learnings.md | X |
| audit-learnings.md | X |
| quick-learnings.md | X |
| global-patterns.md | X |
```

### Step 7: Ask to commit
After presenting the report, ask: "Ready to wrap up? Run `/wrap` to commit with full context."

## Part 3: Learning Redistribution (general.md → skill files)

This runs as part of Step 5 above, but can also be triggered independently when the user says they've added something to `learnings/general.md`.

### How redistribution works:
1. Read each entry in `general.md`
2. Classify by category based on content:
   - **Architecture decisions, tech choices, infrastructure** → `arch-learnings.md`
   - **Security, scalability, compliance, deployment** → `audit-learnings.md`
   - **Code patterns, tech debt, logging, testing** → `quick-learnings.md`
   - **Workflow, process, multi-category** → `global-patterns.md`
3. If an entry spans multiple categories → write to `global-patterns.md` AND add a one-line reference in each relevant skill file
4. Remove redistributed entries from `general.md`
5. Show what was moved where
