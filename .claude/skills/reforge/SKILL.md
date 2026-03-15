---
name: reforge
description: Feed everything back to forge. Syncs global config drift AND absorbs learnings from the user's global Claude space. Forge-project only.
user-invocable: true
---

# /reforge — Global Learning Absorber + Config Sync

## Resolve FORGE_HOME
Before starting, determine the forge directory:
1. If running from within the forge repo, `$FORGE_HOME` is the current repo root.
2. Check env var `$FORGE_HOME`
3. If not set, check `~/.claude/CLAUDE.md` for a `forge-home:` line
4. If not found, fall back to `/root/dev/forge`
5. If the resolved path doesn't exist, warn the user and stop

Single command to feed all knowledge back into the forge repo. Does three things:

1. **Config sync** — push current global config into forge reference
2. **Learning absorption** — merge global learnings/memories into forge's learning store
3. **Learning redistribution** — route general entries to the right skill files

---

## Part 1: Config Sync

### Step 1: Read current state
- Read `~/.claude/CLAUDE.md` (global rules)
- Read `~/.claude/settings.json` (tool permissions) — if it exists
- Read `$FORGE_HOME/code/claude-code-rules.md` (reference doc)

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

---

## Part 2: Learning Absorption

### Intake Sources (global Claude space ONLY)
`/reforge` does NOT scan project repos directly. It consumes from the user's global Claude space, where `/wrap` has already promoted and genericized learnings.

| Source | Location | What's there |
|--------|----------|-------------|
| **Global learnings** | `~/.claude/learnings/general.md` | Universal learnings promoted by `/wrap` (Tier 2) |
| **Global memory** | `~/.claude/memory/` | Universal memories promoted by `/wrap` |
| **Forge general** | `$FORGE_HOME/learnings/inbox.md` | Human-contributed insights added directly to forge |

### Step 1: Read intake sources
- Read `~/.claude/learnings/general.md`
- Scan `~/.claude/memory/` for all memory files
- Read `$FORGE_HOME/learnings/inbox.md`

### Step 2: Read existing knowledge base
Before evaluating new learnings, load everything we already know:
- Read ALL files in `$FORGE_HOME/learnings/` (arch, audit, quick, global-patterns)
- Read ALL global skill SKILL.md files in `~/.claude/skills/*/SKILL.md` (the skills themselves encode knowledge)
- Build a mental model of what's already known, already incorporated, or already addressed

### Step 3: Triage — SHOW BEFORE ABSORBING
For each candidate learning found in Step 1, classify it:

| Status | Meaning |
|--------|---------|
| **NEW** | Not covered anywhere in existing knowledge — should be absorbed |
| **DUPLICATE** | Already exists in a forge learning file — skip |
| **INCORPORATED** | Already baked into a skill's SKILL.md instructions — skip |
| **SUPERSEDED** | Contradicted or replaced by a newer learning — flag for review |
| **CROSS-CUTTING** | Applies to multiple skills — route to `global-patterns.md` AND each relevant skill file |

Present the full triage table to the user using AskUserQuestion:

```markdown
## Learning Triage Report

### Candidates for Absorption
| # | Source | Learning Summary | Category | Status | Target File |
|---|--------|-----------------|----------|--------|-------------|
| 1 | ~/.claude/learnings/general.md | [one-line summary] | arch | NEW | arch-learnings.md |
| 2 | ~/.claude/memory/some-pattern.md | [one-line summary] | quick | NEW | quick-learnings.md |
| 3 | forge/learnings/inbox.md | [one-line summary] | audit | DUPLICATE | — |

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
- Append to the appropriate file in `$FORGE_HOME/learnings/`:
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

**IMPORTANT**: Source entries in `~/.claude/learnings/` and `~/.claude/memory/` are NEVER deleted. They remain in the user's global space.

### Processing Tracker
To avoid re-evaluating every entry on each run, maintain a watermark file at `$FORGE_HOME/learnings/.reforge-tracker.json`:

```json
{
  "lastRun": "2026-03-15T16:00:00Z",
  "processedHashes": [
    "sha256-of-entry-content-1",
    "sha256-of-entry-content-2"
  ]
}
```

- Before triage, compute a content hash for each candidate entry
- Skip any entry whose hash is already in `processedHashes`
- After absorption, append new hashes and update `lastRun`
- On `/reforge review`, reset the tracker (force full re-evaluation)

### Step 5: Redistribute forge inbox.md
After absorption, process `$FORGE_HOME/learnings/inbox.md`:
- Any entry that was absorbed into a skill-specific file → remove from forge's inbox.md (this is forge-internal housekeeping, not the user's global space)
- Entries that don't map to any skill → keep in inbox.md
- Goal: forge's inbox.md should only contain unprocessed or truly general insights

### Step 6: Report
```markdown
## Absorption Complete

### Summary
- Sources scanned: ~/.claude/learnings/, ~/.claude/memory/, forge/learnings/inbox.md
- Candidates found: X
- New learnings absorbed: X
- Duplicates skipped: X
- Incorporated (already in skills): X
- Redistributed from forge inbox.md: X

### Files Updated
| File | Entries Added |
|------|--------------|
| arch-learnings.md | X |
| audit-learnings.md | X |
| quick-learnings.md | X |
| global-patterns.md | X |
```

### Step 7: Sync Skill Sibling Files
Ensure the framework/reference files deployed in `~/.claude/skills/` are up-to-date with forge source:

| Skill | Sibling File | Forge Source |
|-------|-------------|--------------|
| `/pitch` | `~/.claude/skills/pitch/pitch-framework.md` | `$FORGE_HOME/pitch/pitch-forge.md` |
| `/bluep` | `~/.claude/skills/bluep/blueprint-framework.md` | `$FORGE_HOME/pitch/product-blueprint.md` |
| `/dive` | `~/.claude/skills/dive/qa-framework.md` | `$FORGE_HOME/code/qa-review-prompt.md` |
| `/forge` | `~/.claude/skills/forge/forge-conventions.md` | `$FORGE_HOME/code/claude-code-rules.md` |

For each pair:
1. Diff the sibling file against the forge source
2. If they differ, show the diff summary to the user
3. After confirmation, overwrite the sibling with the forge source
4. If they match, report "in sync" and skip

### Step 8: Ask to commit
After presenting the report, ask: "Ready to wrap up? Run `/wrap` to commit with full context."

---

## Part 3: Learning Redistribution (inbox.md → skill files)

This runs as part of Step 5 above, but can also be triggered independently when the user says they've added something to `learnings/inbox.md`.

### How redistribution works:
1. Read each entry in forge's `inbox.md`
2. Classify by category based on content:
   - **Architecture decisions, tech choices, infrastructure** → `arch-learnings.md`
   - **Security, scalability, compliance, deployment** → `audit-learnings.md`
   - **Code patterns, tech debt, logging, testing** → `quick-learnings.md`
   - **Workflow, process, multi-category** → `global-patterns.md`
3. If an entry spans multiple categories → write to `global-patterns.md` AND add a one-line reference in each relevant skill file
4. Remove redistributed entries from forge's `inbox.md`
5. Show what was moved where

---

## Part 4: Learning Review & Expiry

Run this when `/reforge review` is invoked, or automatically when any learning file exceeds 50 entries.

### Purpose
Learnings accumulate over time and can become stale — a pattern valid for React 18 may not apply to React 19, a framework gotcha may have been fixed in a newer version.

### How it works:
1. Read ALL learning files in `$FORGE_HOME/learnings/`
2. For each entry, evaluate:
   - **CURRENT** — still valid and applicable → keep as-is
   - **STALE** — references outdated versions, deprecated APIs, or patterns superseded by newer approaches → flag for removal
   - **MERGED** — duplicate or subset of another entry → flag for consolidation
   - **EVOLVED** — partially valid but needs updating (e.g., "use X" → "use X v2 which changed the API") → flag for rewrite
3. Search the web for current best practices on any entry marked STALE or EVOLVED to confirm
4. Present the review table:
   ```markdown
   ## Learning Review

   | # | File | Entry | Status | Recommendation |
   |---|------|-------|--------|----------------|
   | 1 | arch-learnings.md | [title] | CURRENT | Keep |
   | 2 | arch-learnings.md | [title] | STALE | Remove — API deprecated in v4 |
   | 3 | quick-learnings.md | [title] | MERGED | Consolidate with entry #7 |
   | 4 | audit-learnings.md | [title] | EVOLVED | Rewrite — new compliance rules |
   ```
5. After user confirmation:
   - Remove STALE entries
   - Merge MERGED entries (keep the more comprehensive one, delete the other)
   - Rewrite EVOLVED entries with updated information
   - Report total: kept X, removed X, merged X, rewritten X
