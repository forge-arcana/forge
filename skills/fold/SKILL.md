---
name: fold
description: Absorb knowledge back into forge from any project. Syncs global config drift AND absorbs learnings and memories from the user's global Claude space into the forge repo.
user-invocable: true
---

# /fold — Absorb Knowledge Into Forge

## HARD RULE — /fold is the ONLY writer to forge
> **No project, no skill, no manual edit touches forge repo files directly.**
> `/fold` is the gatekeeper. All knowledge flows through it.
> Direct edits to the forge repo are only for skill development (editing SKILL.md files in `skills/`).

## HARD RULE — Disk is truth, context is stale
> **NEVER use in-context memory of forge file contents to make absorption decisions.**
> Always `Read` files from disk or use script output (fold-evidence.sh, forge-status.sh).
> Your context window may contain skill definitions, learnings, or reference docs from before the last `/cast` — using them causes silent reverts and duplicate absorptions.
> This applies to ALL parts: skill sync, config sync, learning triage, memory triage, deduplication checks.

---

Single command to fold all knowledge back into the forge repo. Runnable from **any project**. One flow, six parts:

1. **Config & skill sync** — push current global config into forge reference + detect deployed skill drift
2. **Learning absorption** — merge global learnings into forge's learning store
3. **Memory absorption** — merge global memories into forge's team memory store
4. **Membrane compaction** — compact fully-absorbed learnings, archive synced memories
5. **Commit & push** — conflict gate, stage, context update, commit, push with user confirmation
6. **DONE Report** — receipt of what was executed

**Note**: Review & prune of existing forge knowledge (staleness audit) is `/purge`'s responsibility, not fold's. Fold absorbs new knowledge; purge audits existing knowledge.

---

## Step 0: Preflight

Run `<forge>/scripts/forge-status.sh --pull` to execute the preflight. Use the Skill Drift Report from its output for Part 1a below.

**This is critical** — without pulling first, /fold could overwrite newer forge changes with stale deployed copies.

---

## Part 1: Config & Skill Sync

### 1a: Skill Reverse-Sync (using preflight drift results)

| Classification | /fold Action |
|---------------|-------------|
| `IDENTICAL` | Skip |
| `DEPLOYED-DIFFERS` | `Read` deployed file from disk, diff against forge, show changes, absorb into forge after user confirms |
| `FORGE-UPDATED` | Skip — deploy on next `/cast` |
| `CONFLICT` | Show both diffs, ask user to reconcile |
| `ADDED` / `REMOVED` | Skip — handled by `/cast` |

### 1b: Config Sync

1:1 mapping — each membrane config file has a forge reference counterpart:
- `~/.claude/CLAUDE.md` ↔ `<forge>/skills/forge/claude-code-rules.md`
- `~/.claude/settings.json` ↔ `<forge>/skills/forge/claude-code-settings.json`

Read all four files in parallel. Diff and identify additions, removals, conflicts. Present a Config Sync Report table. After user confirms, update the forge reference files to match.

Sync rules: auto-allowed commands table, WebFetch domains must match exactly, destructive commands NEVER in allow list, hooks/additionalDirectories are machine-specific — never sync.

---

## Part 1b: Evidence Collection

Run `<forge>/scripts/fold-evidence.sh` to collect all forge learnings, forge memories, membrane learnings, membrane memories, and tracker state in one call. Use this output as evidence for Parts 2-3.

---

## Part 2: Learning Absorption

### Step 0: Promote Forge-worthy Learnings from Project Memories

Scan `~/.claude/projects/*/memory/*-learnings.md` for entries tagged `Forge-worthy: yes`. For each:
1. Skip if title already in `<forge>/learnings/.fold-tracker.json` `promotedEntries` or in `~/.claude/learnings/general.md`
2. Genericize (strip project names, paths, domains — see forge CLAUDE.md "No Project Names" rule)
3. Append to `~/.claude/learnings/general.md` with `<!-- promoted from project memory, YYYY-MM-DD -->` comment
4. Add title to tracker `promotedEntries`

Skip silently if no Forge-worthy entries exist.

### Steps 1-2: Read intake + existing knowledge

Use fold-evidence.sh output for membrane learnings (Section 3) and forge learnings (Section 1). Also read all `<forge>/skills/*/SKILL.md` in parallel to understand what's already incorporated.

### Step 3: PLAN Report — Decision Gate

Classify each candidate: **NEW** (absorb), **DUPLICATE** (skip), **INCORPORATED** (already in SKILL.md — skip), **SUPERSEDED** (flag), **CROSS-CUTTING** (route to global-patterns + relevant skill files), **TRACKED-ONLY** (in processedEntries but NOT in any forge file — was intentionally removed by /purge, skip).

Build a unified PLAN table from ALL parts (config sync, skills, learnings, memories) — one table, one decision point. Use contributor names from `git blame` on forge files and first-sentence summaries from the Learning Details in `forge-status.sh` output.

```markdown
## Forge Transfer — /fold | YYYY-MM-DD | PLAN

| What | Action | Contributor |
|------|--------|-------------|
| `/probe` skill | absorb (deployed-differs) | — |
| claude-code-rules.md (config) | merge | — |
| Integer Money Pattern | absorb → global-patterns.md | cygnum |
|   → Store all currency as smallest-unit integers (cents/centavos) in the database | | |
| Mobile Testing Progression | skip (duplicate) | cygnum |
|   → Already in global-patterns.md | | |
| deploy-practices.md (memory) | absorb | — |

3 skills identical, 2 learnings in forge — omitted.
```

**Action vocabulary**: `absorb` (new learning/memory → forge), `merge` (config drift), `skip (duplicate)`, `skip (personal)`, `skip (superseded)`, `skip (incorporated)`, `skip (purged)` (TRACKED-ONLY — removed by /purge), `conflict` (both changed)

If everything is in sync: skip the table, say "Everything in sync." and proceed to Part 5.

**Output the PLAN table as console text (markdown), NEVER via AskUserQuestion** — compressed UI makes tables unreadable. Then use AskUserQuestion with "Apply all / Adjust / Skip" prompt.

User reviews → approves/rejects individual items → only approved items execute in Steps 4 and Part 3.

### Step 4: Genericize & Absorb

**No project-specific details in forge** — strip all project names, paths, domains, business logic. See forge CLAUDE.md "No Project Names" rule for the full list.

Append to the appropriate `<forge>/learnings/` file:
- `probe-learnings.md` — architecture | `press-learnings.md` — go-live readiness
- `poke-learnings.md` — tech debt/logging | `prime-learnings.md` — ideation/blueprint
- `global-patterns.md` — cross-cutting

Format: `## [Title] (YYYY-MM-DD)` + `**Learning**:` + `**Apply when**:`

Source entries in `~/.claude/learnings/` are NEVER deleted.

### Processing Tracker

Maintain `<forge>/learnings/.fold-tracker.json` with `lastRun`, `processedEntries` (triaged titles from general.md), `promotedEntries` (promoted Forge-worthy titles). Skip entries whose title is already tracked.

---

## Part 3: Memory Absorption

### Memory Tracker

Maintain `<forge>/memory/.memory-tracker.json` with `lastRun` and `skippedFiles` (PERSONAL memories intentionally not absorbed). A file needs triage only if it's in membrane but NOT in forge AND NOT in `skippedFiles`.

### Triage (unprocessed files only)

- File in both → `diff --strip-trailing-cr`. Identical = skip. Different = UPDATE.
- File in membrane only + in `skippedFiles` → skip.
- File in membrane only + NOT in `skippedFiles` → triage as:

| Status | Meaning |
|--------|---------|
| **TEAM-WORTHY** | Absorb into `<forge>/memory/` (strip personal details) |
| **PERSONAL** | Skip, add to `skippedFiles` |
| **DUPLICATE** | Skip, add to `skippedFiles` |
| **UPDATE** | Merge newer content into existing forge file |

Classification rules: `type: user` = always PERSONAL. `type: feedback` = team-worthy if about code/process. `type: team-*` = always team-worthy.

Source entries in `~/.claude/memory/` are NEVER deleted.

---

## Part 4: Membrane Compaction

### Triggers (skip if none fire)

| Trigger | What fires |
|---------|-----------|
| `~/.claude/learnings/general.md` > 30 entries | Learning compaction |
| `~/.claude/memory/` has > 30 files | Memory archival |

### Learning compaction

Cross-reference every entry in `general.md` against:
1. Tracker `processedEntries` — was it triaged by /fold?
2. Forge learnings files (`<forge>/learnings/*.md`) — is the content present in forge?

Entries that are BOTH processed AND present in forge are **fully absorbed** — they've completed the journey from membrane into the source of truth. Replace each fully-absorbed entry with a one-line stub:

```markdown
## [Original Title] (YYYY-MM-DD)
<!-- Absorbed into forge/learnings/[file].md -->
```

This preserves the title (so the tracker doesn't re-process it) while shrinking the file. Present the compaction list for user confirmation before applying.

Entries NOT yet in forge (unprocessed, or processed but not yet absorbed) remain untouched.

### Memory archival

Files identical in both membrane and forge → offer to move to `~/.claude/memory/archive/`.

Never delete — archival is a move.

---

## Part 5: Commit & Push

`/fold` owns its own commit flow — no `/wrap` needed.

1. **Conflict check**: `git -C <forge> diff --name-only --diff-filter=U`. If conflicts exist, STOP.
2. **Stage** changed files with `git add <file>` (never `git add -A`)
3. **Update context** in `<forge>/CLAUDE.md` Current Context section
4. **Compact check**: If CLAUDE.md > ~20k chars, overflow to `memory/`
5. **Commit**: descriptive message (what was absorbed, not where from — no project names) with `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>`
6. **Push decision**: AskUserQuestion — "Yes, push" / "No, keep local"

## Part 6: DONE Report

Present the receipt of what was actually executed. Only include rows for items that changed — no "in sync" rows.

```markdown
## Forge Transfer — /fold | YYYY-MM-DD | DONE

| What | Result | Contributor |
|------|--------|-------------|
| `/probe` skill | absorbed | — |
| claude-code-rules.md (config) | merged | — |
| Integer Money Pattern | absorbed → global-patterns.md | cygnum |
| Mobile Testing Progression | skipped (duplicate) | cygnum |
| deploy-practices.md (memory) | absorbed | — |

Commit: `abc1234` — pushed to origin/main
```

**Result vocabulary** (past tense of PLAN actions): `absorbed`, `merged`, `skipped (reason)`, `reconciled`

If nothing changed: "Everything in sync." — skip both PLAN and DONE reports.

After the table: commit hash + push status.
