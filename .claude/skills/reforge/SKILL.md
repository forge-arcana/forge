---
name: reforge
description: Feed everything back to forge. Syncs global config drift AND absorbs learnings from self-improving skills across all projects. Forge-project only.
allowed-tools: Read, Write, Edit, Bash(*), Glob, Grep
---

# /reforge — Global Learning Absorber + Config Sync

Single command to feed all knowledge back into the forge repo. Does two things:

1. **Config sync** (old upforge) — push current global config into forge reference
2. **Learning absorption** — merge project learnings into forge's global learning store

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
Scan all known project directories for learning files:
- Check `~/.claude/settings.json` for `additionalDirectories`
- Also check common locations: `/root/dev/*/memory/*-learnings.md`
- Look for: `memory/arch-learnings.md`, `memory/audit-learnings.md`, `memory/quick-learnings.md`

### Step 2: Read and categorize
For each found learning file:
- Read the contents
- Categorize: architecture, audit, quick-review, or cross-cutting
- Note the source project and date

### Step 3: Merge into forge learnings
- Read existing forge learnings from `/root/dev/forge/learnings/`
- Deduplicate — don't add learnings that already exist
- Merge new learnings into the appropriate file:
  - `learnings/arch-learnings.md` — architecture patterns
  - `learnings/audit-learnings.md` — go-live audit patterns
  - `learnings/quick-learnings.md` — tech debt patterns
  - `learnings/global-patterns.md` — cross-cutting patterns that span multiple categories

### Step 4: Report
```markdown
## Learning Absorption Report

### New Learnings Absorbed
| Source Project | Category | Learning | File |
|---------------|----------|----------|------|
| [project] | [arch/audit/quick] | [summary] | [target file] |

### Already Known (skipped)
| Source Project | Learning | Reason |
|---------------|----------|--------|
| [project] | [summary] | Duplicate of existing entry |

### Totals
- Scanned: X projects
- New learnings: X
- Duplicates skipped: X
```

### Step 5: Ask to commit
After presenting the report, ask: "Ready to wrap up? Run `/wrap` to commit with full context."
