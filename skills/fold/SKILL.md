---
name: fold
description: Absorb knowledge back into forge from any project. Syncs global config drift AND absorbs learnings and memories from the user's global Claude space into the forge repo.
user-invocable: true
---

# /fold — Absorb Knowledge Into Forge

## HARD RULE — /fold is the ONLY writer to forge
> **No project, no skill, no manual edit touches forge repo files directly.**
> `/fold` is the gatekeeper. All knowledge flows through it.
> If you need to update forge learnings, memory, or config — run `/fold`.
> Direct edits to the forge repo are only for skill development (editing SKILL.md files in `skills/`).

---

Single command to fold all knowledge back into the forge repo. Runnable from **any project**. One flow, six parts:

1. **Config & skill sync** — push current global config into forge reference + detect deployed skill drift
2. **Review & prune** — check existing forge knowledge for staleness (auto-triggers based on size)
3. **Learning absorption** — merge global learnings into forge's learning store
4. **Memory absorption** — merge global memories into forge's team memory store
5. **Staging archival** — archive fully-absorbed entries from `~/.claude/` staging area
6. **Report** — summary of all changes

All file paths below are relative to `<forge>` (the resolved forge repo path).

---

## Step 0: Preflight

> Execute [Forge Preflight](../forge/preflight.md) in **pull** mode.

Run `<forge>/scripts/forge-status.sh --pull` to execute the preflight. Use the Skill Drift Report from its output for Part 1a below.

This resolves the forge path, pulls the latest forge (aborting if diverged), and produces the **Skill Drift Report** with directional classifications.

**This is critical** — without pulling first, /fold could overwrite newer forge changes with stale deployed copies.

---

## Part 1: Config & Skill Sync

### Step 1a: Skill Reverse-Sync (using preflight drift results)

Use the drift classifications from the preflight Skill Drift Report:

| Classification | /fold Action |
|---------------|-------------|
| `IDENTICAL` | Skip |
| `DEPLOYED-DIFFERS` | Deployed copy was modified — absorb into forge source (reverse-sync) |
| `FORGE-UPDATED` | Skip — forge has newer changes, these will deploy on next `/cast` |
| `ADDED` | Skip — new skill in forge, will deploy on next `/cast` |
| `REMOVED` | Skip — skill removed from forge |

For each `DEPLOYED-DIFFERS` skill:
- Diff the deployed vs forge source to show exactly what changed
- After user confirms, **copy the deployed version into `<forge>/skills/<name>/`** (deployed is the newer truth)
- This is safe because `/cast` will re-deploy from forge source on next run

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
   | 1 | probe-learnings.md | [title] | CURRENT | Keep |
   | 2 | probe-learnings.md | [title] | STALE | Remove — API deprecated in v4 |
   | 3 | poke-learnings.md | [title] | MERGED | Consolidate with entry #7 |
   | 4 | press-learnings.md | [title] | EVOLVED | Rewrite — new compliance rules |
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
   | 3 | logging-style.md | team-feedback | Log human actions | PROMOTED | Already in /poke SKILL.md |
   ```
4. After user confirmation: remove, merge, or rewrite as classified

---

## Part 3: Learning Absorption

### Step 0: Promote Forge-worthy Learnings from Project Memories

Before reading the global intake sources, scan all project memory directories for art learnings flagged as Forge-worthy.

1. **Scan**: Glob `~/.claude/projects/*/memory/*-learnings.md` for all art learning files across all projects
2. **Parse**: For each file, extract entries tagged `Forge-worthy: yes`
3. **Dedup**: Extract the `## Title` heading from each candidate entry. Skip if title is already in `<forge>/learnings/.reforge-tracker.json` `promotedEntries` array (already promoted in a prior run). Also skip if a `## Title` with the same heading already exists in `~/.claude/learnings/general.md`.
4. **Genericize**: Strip all project-specific details (project names, specific file paths, domains, business logic) — rewrite as universal principles. Use the same genericization rules as Step 4 below.
5. **Promote**: Append each genericized entry to `~/.claude/learnings/general.md` with a source comment:
   ```markdown
   <!-- promoted from project memory, YYYY-MM-DD -->
   ## [Short Title]
   [genericized learning content]
   ```
6. **Report**: Output a promotion summary:
   ```markdown
   ## Forge-worthy Promotion Report

   | # | Source File | Learning | Action |
   |---|-----------|----------|--------|
   | 1 | *-learnings.md | [title] | Promoted to general.md |
   | 2 | *-learnings.md | [title] | Skipped — already promoted |
   ```

If no `*-learnings.md` files exist or no entries are tagged `Forge-worthy: yes`, skip this step silently.

**IMPORTANT**: Project-specific learnings (`Forge-worthy: no` or untagged) are NEVER promoted. Only `Forge-worthy: yes` entries cross the membrane boundary.

### Intake Sources (global Claude space)

After promotion, `/fold` consumes from the user's global Claude space. Forge-worthy entries promoted in Step 0 are now included here.

| Source | Location | What's there |
|--------|----------|-------------|
| **Global learnings** | `~/.claude/learnings/general.md` | Universal learnings accumulated during sessions (including promoted Forge-worthy entries) |

### Step 1: Read intake sources
- Read `~/.claude/learnings/general.md`

### Step 2: Read existing knowledge base
Before evaluating new learnings, load everything we already know:
- Read ALL files in `<forge>/learnings/` (probe, poke, press, pound, prime, global-patterns)
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
| 1 | ~/.claude/learnings/general.md | [one-line summary] | probe | NEW | probe-learnings.md |
| 2 | ~/.claude/learnings/general.md | [one-line summary] | poke | DUPLICATE | — |

### Already Known (auto-skipped)
| # | Learning | Reason |
|---|----------|--------|
| 1 | [summary] | Duplicate of [existing entry in file] |
| 2 | [summary] | Already incorporated in /probe SKILL.md step X |
```

Then use AskUserQuestion with a simple confirmation prompt (e.g., "Approve all X candidates?" with options like "Approve all", "Skip some", "Reject all").

**Wait for user confirmation before proceeding.** User can:
- Approve all NEW items
- Reject specific items
- Reclassify items (e.g., "actually #3 is new, the existing one is different")

### Step 4: Genericize & Absorb confirmed learnings

**CRITICAL: No project-specific details in forge — learnings, memory, OR commit messages.** Before writing any learning to forge, strip ALL project-specific references. Commit messages must describe *what* was absorbed (topics, patterns), never *where* it came from (project names).

| Strip | Replace with |
|-------|-------------|
| Project names | "the project" or omit |
| Specific file paths (e.g., `src/routes/myapp/auth.ts`) | Generic path pattern (e.g., "auth route handler") |
| Specific API keys, URLs, domains | "[API endpoint]", "[domain]" |
| Specific user/team names | "the team" or omit |
| Specific database names, table names | Generic description (e.g., "the user table") |
| Business logic details unique to one product | The general pattern it exemplifies |

The goal: every learning in forge should read as a **universal principle** that applies to any project using the same tech stack. If someone reads `probe-learnings.md` with zero context about any specific project, every entry should still make complete sense.

For each confirmed learning:
- **Genericize first** — rewrite the learning as a universal pattern
- Append to the appropriate file in `<forge>/learnings/`:
  - `probe-learnings.md` — architecture patterns and decisions
  - `press-learnings.md` — go-live readiness patterns
  - `poke-learnings.md` — tech debt and logging patterns
  - `prime-learnings.md` — ideation, pitch, and blueprint patterns
  - `global-patterns.md` — cross-cutting patterns that span multiple categories
- Format each entry as:
  ```markdown
  ## [Short Title] (YYYY-MM-DD)
  **Learning**: [the genericized insight — no project names, no specific paths]
  **Apply when**: [context for when this learning is relevant]
  ```

**IMPORTANT**: Source entries in `~/.claude/learnings/` are NEVER deleted. They remain in the user's global space.

### Processing Tracker
To avoid re-evaluating every entry on each run, maintain a tracker at `<forge>/learnings/.reforge-tracker.json`:

```json
{
  "lastRun": "2026-03-15T16:00:00Z",
  "processedEntries": [
    "Self-Contained Skill Packages",
    "WSL Path Compatibility"
  ],
  "promotedEntries": [
    "Barrel Import Browser Builds"
  ]
}
```

- **processedEntries**: `## Title` headings from `general.md` entries that have been triaged (Part 3 Steps 1-4)
- **promotedEntries**: `## Title` headings from Forge-worthy project memory entries that have been promoted to `general.md` (Part 3 Step 0)
- Before triage, extract `## Title` headings from candidate entries
- Skip any entry whose title is already in the relevant array
- After absorption/promotion, append new titles and update `lastRun`
- If Part 2 review fires, reset the tracker (force full re-evaluation of all entries)

---

## Part 4: Memory Absorption

### Intake Sources
| Source | Location | What's there |
|--------|----------|-------------|
| **Global memory** | `~/.claude/memory/` | Universal memories accumulated during sessions |

### Memory Tracker
Maintain a tracker at `<forge>/memory/.memory-tracker.json`:

```json
{
  "lastRun": "2026-03-15T16:00:00Z",
  "skippedFiles": ["user-role.md", "personal-preference.md"]
}
```

- **skippedFiles**: membrane memory files that were triaged and intentionally not absorbed (PERSONAL)
- A memory file needs triage only if it exists in membrane but NOT in forge AND NOT in `skippedFiles`
- Files that exist in both membrane and forge: use `diff --strip-trailing-cr` to check sync (no tracker needed)
- If Part 2 memory review fires, reset the tracker (force full re-evaluation)

### Step 1: Read intake sources
- Read all `.md` files in `~/.claude/memory/` (exclude MEMORY.md index)
- Read all `.md` files in `<forge>/memory/` (exclude MEMORY.md index)
- Read `<forge>/memory/.memory-tracker.json` if it exists

### Step 2: Triage memories (unprocessed files only)

Determine which files need triage:
- File in membrane AND in forge → use `diff --strip-trailing-cr` to check sync. If identical, skip. If different, classify as UPDATE.
- File in membrane only AND in `skippedFiles` → already decided, skip
- File in membrane only AND NOT in `skippedFiles` → **new, needs triage**

For each **new** memory file, classify:

| Status | Meaning |
|--------|---------|
| **TEAM-WORTHY** | Applies to the whole team, not just this user — absorb into `<forge>/memory/` |
| **PERSONAL** | User-specific preference or context — skip (but record decision in tracker) |
| **DUPLICATE** | Already exists in `<forge>/memory/` — skip (record in tracker) |
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
- **Update tracker**: add PERSONAL files to `skippedFiles` so they aren't re-triaged next run. TEAM-WORTHY files don't need tracking — they'll exist in forge, so `diff` handles them.

**IMPORTANT**: Source entries in `~/.claude/memory/` are NEVER deleted.

---

## Part 5: Staging Archival

The user's `~/.claude/learnings/` and `~/.claude/memory/` grow forever by design (nothing is ever deleted during work sessions). This step offers to archive entries that have been fully absorbed into forge.

### Trigger (skip if none fire)

| Trigger | What fires |
|---------|-----------|
| `~/.claude/learnings/general.md` > 100 entries | Learning archival |
| `~/.claude/memory/` has > 30 files | Memory archival |

If no triggers fire, skip Part 5 entirely.

### Learning Archival

1. Read `~/.claude/learnings/general.md`
2. Cross-reference each entry against:
   - `<forge>/learnings/.reforge-tracker.json` `processedEntries` — was its title already processed?
   - `<forge>/learnings/*.md` — does the genericized version exist in forge?
3. For entries that are BOTH processed AND present in forge:
   - Classify as **ARCHIVABLE** — safe to move out of active staging
4. Present the archival table:
   ```markdown
   ## Staging Archival

   | # | Entry | Absorbed Into | Action |
   |---|-------|--------------|--------|
   | 1 | "Self-Contained Skill Packages" | global-patterns.md | Archive |
   | 2 | "WSL Path Compatibility" | probe-learnings.md | Archive |
   | 3 | "New unprocessed entry" | — | Keep (not yet absorbed) |
   ```
5. After user confirmation:
   - Move archived entries from `~/.claude/learnings/general.md` to `~/.claude/learnings/archive/general.md`
   - Create `archive/` directory if it doesn't exist
   - **Never delete** — archival is a move, not a removal
   - Update the tracker to reflect the archival

### Memory Archival

- Memory files that exist in both `~/.claude/memory/` and `<forge>/memory/` with identical content (via `diff --strip-trailing-cr`) → offer to move to `~/.claude/memory/archive/`
- Same confirmation flow as learning archival

---

## Part 6: Commit & Push

`/fold` owns the full cycle — absorb, commit, push. No `/wrap` needed for forge.

1. **Stage** all changed files in `<forge>` with `git add <file>` (never `git add -A`)
2. **Update context** in `<forge>/CLAUDE.md` Current Context section
3. **Commit** with a descriptive message (what was absorbed, not where it came from — no project names):
   ```
   git commit -m "Absorb N learnings: [topic summaries]

   Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
   ```
   If no changes were made (nothing absorbed, no config drift), skip the commit.
4. **Push** to remote: `git push`

## Part 7: Report

```markdown
## Fold Complete

### Summary
- Config sync: [X changes applied / no changes]
- Forge-worthy promotion: [X promoted / none found]
- Review: [X kept, X removed, X merged, X rewritten / skipped — below thresholds]
- Learning candidates: X found, Y absorbed, Z skipped
- Memory candidates: X found, Y absorbed as team memory, Z skipped (personal)
- Staging archival: [X archived / skipped — below thresholds]
- Commit: [hash — pushed to remote / no changes to commit]

### Files Updated
| File | Type | Changes |
|------|------|---------|
| learnings/probe-learnings.md | learning | +X entries |
| learnings/global-patterns.md | learning | +X entries |
| memory/deploy-practices.md | team memory | NEW |
| skills/forge/claude-code-rules.md | config | updated |
```
