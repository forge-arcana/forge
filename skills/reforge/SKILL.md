---
name: reforge
description: Feed everything back to forge from any project. Syncs global config drift AND absorbs learnings and memories from the user's global Claude space into the forge repo.
user-invocable: true
---

# /reforge — Global Learning & Memory Absorber + Config Sync

## Forge Path
Resolve `<forge>` from `~/.claude/CLAUDE.md` `forge-path:` line (managed by `/forge`).

## HARD RULE — /reforge is the ONLY writer to forge
> **No project, no skill, no manual edit touches forge repo files directly.**
> `/reforge` is the gatekeeper. All knowledge flows through it.
> If you need to update forge learnings, memory, or config — run `/reforge`.
> Direct edits to the forge repo are only for skill development (editing SKILL.md files in `skills/`).

---

Single command to feed all knowledge back into the forge repo. Runnable from **any project**. One flow, six parts:

1. **Config & skill sync** — push current global config into forge reference + detect deployed skill drift
2. **Review & prune** — check existing forge knowledge for staleness (auto-triggers based on size)
3. **Learning absorption** — merge global learnings into forge's learning store
4. **Memory absorption** — merge global memories into forge's team memory store
5. **Staging archival** — archive fully-absorbed entries from `~/.claude/` staging area
6. **Report** — summary of all changes

All file paths below are relative to `<forge>` (the resolved forge repo path).

---

## Part 1: Config & Skill Sync

### Step 1a: Skill Reverse-Sync (deployed → forge source)

Compare deployed skills (`~/.claude/skills/`) against forge source (`<forge>/skills/`). For each skill:

1. Hash both the deployed and forge source directories (use path-relative hashing — see command below)
2. If they differ, the deployed copy has changes that haven't been absorbed into forge

**Hashing command** (paths must be relative to avoid mismatches between source/deployed locations):
```bash
find <dir> -type f | sort | while read f; do echo "$(realpath --relative-to=<dir> "$f")"; cat "$f"; done | sha256sum | awk '{print $1}'
```

Present the drift report:
```markdown
## Skill Reverse-Sync Report

| Skill | Status | Action |
|-------|--------|--------|
| wrap | DRIFTED | Deployed has changes — absorb into forge source |
| arch | IDENTICAL | — |
```

For each DRIFTED skill:
- Diff the deployed vs forge source to show exactly what changed
- After user confirms, **copy the deployed version into `<forge>/skills/<name>/`** (deployed is the newer truth)
- This is safe because `/forge` will re-deploy from forge source on next run

### Step 1b: Config Sync

Read current state:
- Read `~/.claude/CLAUDE.md` (global rules)
- Read `~/.claude/settings.json` (tool permissions) — if it exists
- Read `<forge>/skills/forge/claude-code-rules.md` (reference doc)

### Step 1c: Diff
Compare all three and identify:
- **Additions**: Rules/permissions in global config that aren't in the reference
- **Removals**: Rules/permissions in the reference that aren't in global config
- **Conflicts**: Same rule exists in both but differs

### Step 1d: Present deviations
```markdown
## Config Sync Report

| Aspect | Global Config | Forge Reference | Action |
|--------|--------------|-----------------|--------|
| [rule/permission] | [current value] | [reference value] | [add/remove/update] |
```

### Step 1e: Apply (after user confirms)
- Update `<forge>/skills/forge/claude-code-rules.md` to match current global config
- Follow sync rules from forge conventions:
  - CLAUDE.md "Bash Permissions" <-> reference auto-allowed table
  - settings.json `permissions.allow` <-> reference auto-allowed table
  - WebFetch domains must match exactly
  - Destructive commands NEVER in allow list
  - Hooks and additionalDirectories are machine-specific — never sync

---

## Part 2: Review & Prune Existing Knowledge

Before absorbing new knowledge, check if existing knowledge is still valid. This prevents piling new entries on top of stale ones.

### Triggers (skip if none fire)

| Trigger | What fires |
|---------|-----------|
| Any `<forge>/learnings/*.md` file > 50 entries | Learning review (2a) |
| `<forge>/memory/` has > 20 files | Memory review (2b) |

If no triggers fire, skip Part 2 entirely and proceed to Part 3.

### 2a: Forge Learning Review

1. Read ALL learning files in `<forge>/learnings/`
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

### 2b: Forge Memory Review

1. Read ALL memory files in `<forge>/memory/`
2. For each file, evaluate:
   - **CURRENT** — still relevant to the team → keep
   - **STALE** — references outdated tools, people who left, retired conventions → flag for removal
   - **MERGED** — overlaps with another memory file → flag for consolidation
   - **EVOLVED** — partially valid but context has changed → flag for rewrite
   - **PROMOTED** — already absorbed into a skill's SKILL.md or CLAUDE.md rules → flag as redundant
3. Present the review table:
   ```markdown
   ## Memory Review

   | # | File | Type | Summary | Status | Recommendation |
   |---|------|------|---------|--------|----------------|
   | 1 | deploy-freeze.md | team-project | No deploys on Fridays | CURRENT | Keep |
   | 2 | old-ci-setup.md | team-reference | Jenkins pipeline URLs | STALE | Remove — migrated to GitHub Actions |
   | 3 | logging-style.md | team-feedback | Log human actions | PROMOTED | Already in /quick SKILL.md |
   ```
4. After user confirmation: remove, merge, or rewrite as classified

---

## Part 3: Learning Absorption

### Intake Sources (global Claude space ONLY)
`/reforge` does NOT scan project repos directly. It consumes from the user's global Claude space, where `/wrap` has already promoted and genericized learnings.

| Source | Location | What's there |
|--------|----------|-------------|
| **Global learnings** | `~/.claude/learnings/general.md` | Universal learnings promoted by `/wrap` (Tier 2) |

### Step 1: Read intake sources
- Read `~/.claude/learnings/general.md`

### Step 2: Read existing knowledge base
Before evaluating new learnings, load everything we already know:
- Read ALL files in `<forge>/learnings/` (arch, audit, quick, global-patterns)
- Read ALL skill SKILL.md files in `<forge>/skills/*/SKILL.md` (the skills themselves encode knowledge)
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

**IMPORTANT: Always output the full triage report as console text (markdown tables), NEVER via AskUserQuestion.** The compressed AskUserQuestion UI makes large tables unreadable. Output all tables directly, then use AskUserQuestion with a simple "Approve all / Adjust" prompt at the end.

Output the full triage as console text:

```markdown
## Learning Triage Report

### Candidates for Absorption
| # | Source | Learning Summary | Category | Status | Target File |
|---|--------|-----------------|----------|--------|-------------|
| 1 | ~/.claude/learnings/general.md | [one-line summary] | arch | NEW | arch-learnings.md |
| 2 | ~/.claude/learnings/general.md | [one-line summary] | audit | DUPLICATE | — |

### Already Known (auto-skipped)
| # | Learning | Reason |
|---|----------|--------|
| 1 | [summary] | Duplicate of [existing entry in file] |
| 2 | [summary] | Already incorporated in /arch SKILL.md step X |
```

Then use AskUserQuestion with a simple confirmation prompt (e.g., "Approve all X candidates?" with options like "Approve all", "Skip some", "Reject all").

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
- Append to the appropriate file in `<forge>/learnings/`:
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

**IMPORTANT**: Source entries in `~/.claude/learnings/` are NEVER deleted. They remain in the user's global space.

### Processing Tracker
To avoid re-evaluating every entry on each run, maintain a watermark file at `<forge>/learnings/.reforge-tracker.json`:

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
- If Part 2 review fires, reset the tracker before triage (force full re-evaluation of all entries)

---

## Part 4: Memory Absorption

### Intake Sources
| Source | Location | What's there |
|--------|----------|-------------|
| **Global memory** | `~/.claude/memory/` | Universal memories promoted by `/wrap` |

### Step 1: Read intake sources
- Read all `.md` files in `~/.claude/memory/`
- Read all `.md` files in `<forge>/memory/` (forge's team memory)

### Step 2: Triage memories
For each memory file in `~/.claude/memory/`, classify:

| Status | Meaning |
|--------|---------|
| **TEAM-WORTHY** | Applies to the whole team, not just this user — absorb into `<forge>/memory/` |
| **PERSONAL** | User-specific preference or context — skip |
| **DUPLICATE** | Already exists in `<forge>/memory/` — skip |
| **UPDATE** | Exists in `<forge>/memory/` but user's version is newer/better — flag for merge |

**Classification rules:**
- `type: user` memories are ALWAYS personal — skip
- `type: feedback` — team-worthy if it's about code/process (not personal style)
- `type: reference` — team-worthy if it points to shared resources
- `type: team-project` / `type: team-feedback` / `type: team-reference` — always team-worthy

Present triage table:
```markdown
## Memory Triage Report

| # | File | Type | Summary | Status | Action |
|---|------|------|---------|--------|--------|
| 1 | deploy-practices.md | feedback | No deploys on Fridays | TEAM-WORTHY | Copy to memory/ |
| 2 | user-role.md | user | User is a data scientist | PERSONAL | Skip |
| 3 | linear-project.md | reference | Bugs in Linear INGEST | TEAM-WORTHY | Copy to memory/ |
```

### Step 3: Absorb confirmed memories
After user confirmation:
- Copy TEAM-WORTHY memories to `<forge>/memory/`
- Strip any personal details (user name, specific machine paths)
- Add `<!-- source: team-member, YYYY-MM-DD -->` comment
- For UPDATE entries: merge the newer content into the existing file

**IMPORTANT**: Source entries in `~/.claude/memory/` are NEVER deleted.

---

## Part 5: Staging Archival

The user's `~/.claude/learnings/` and `~/.claude/memory/` grow forever by design (nothing is ever deleted during `/wrap`). This step offers to archive entries that have been fully absorbed into forge.

### Trigger (skip if none fire)

| Trigger | What fires |
|---------|-----------|
| `~/.claude/learnings/general.md` > 100 entries | Learning archival |
| `~/.claude/memory/` has > 30 files | Memory archival |

If no triggers fire, skip Part 5 entirely.

### Learning Archival

1. Read `~/.claude/learnings/general.md`
2. Cross-reference each entry against:
   - `<forge>/learnings/.reforge-tracker.json` `processedHashes` — was it already absorbed?
   - `<forge>/learnings/*.md` — does the genericized version exist in forge?
3. For entries that are BOTH processed AND present in forge:
   - Classify as **ARCHIVABLE** — safe to move out of active staging
4. Present the archival table:
   ```markdown
   ## Staging Archival

   | # | Entry | Absorbed Into | Action |
   |---|-------|--------------|--------|
   | 1 | "Self-Contained Skill Packages" | global-patterns.md | Archive |
   | 2 | "WSL Path Compatibility" | arch-learnings.md | Archive |
   | 3 | "New unprocessed entry" | — | Keep (not yet absorbed) |
   ```
5. After user confirmation:
   - Move archived entries from `~/.claude/learnings/general.md` to `~/.claude/learnings/archive/general.md`
   - Create `archive/` directory if it doesn't exist
   - **Never delete** — archival is a move, not a removal
   - Update the tracker to reflect the archival

### Memory Archival

- Memory files that exist in both `~/.claude/memory/` and `<forge>/memory/` with identical content → offer to move to `~/.claude/memory/archive/`
- Same confirmation flow as learning archival

---

## Part 6: Report

```markdown
## Reforge Complete

### Summary
- Config sync: [X changes applied / no changes]
- Review: [X kept, X removed, X merged, X rewritten / skipped — below thresholds]
- Learning candidates: X found, Y absorbed, Z skipped
- Memory candidates: X found, Y absorbed as team memory, Z skipped (personal)
- Staging archival: [X archived / skipped — below thresholds]

### Files Updated
| File | Type | Changes |
|------|------|---------|
| learnings/arch-learnings.md | learning | +X entries |
| learnings/global-patterns.md | learning | +X entries |
| memory/deploy-practices.md | team memory | NEW |
| skills/forge/claude-code-rules.md | config | updated |
```

Ask: "Ready to wrap up? Run `/wrap` to commit with full context."
