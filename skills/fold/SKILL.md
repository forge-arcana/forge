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

---

Single command to fold all knowledge back into the forge repo. Runnable from **any project**. One flow, seven parts:

1. **Config & skill sync** — push current global config into forge reference + detect deployed skill drift
2. **Review & prune** — check existing forge knowledge for staleness (auto-triggers based on size)
3. **Learning absorption** — merge global learnings into forge's learning store
4. **Memory absorption** — merge global memories into forge's team memory store
5. **Staging archival** — archive fully-absorbed entries from `~/.claude/` staging area
6. **Commit & push** — conflict gate, stage, context update, commit, push with user confirmation
7. **DONE Report** — receipt of what was executed

---

## Step 0: Preflight

Run `<forge>/scripts/forge-status.sh --pull` to execute the preflight. Use the Skill Drift Report from its output for Part 1a below.

**This is critical** — without pulling first, /fold could overwrite newer forge changes with stale deployed copies.

---

## Part 1: Config & Skill Sync

### 1a: Skill Reverse-Sync (using preflight drift results)

> **HARD RULE — fold and cast skills are never absorbed.**
> If `fold` or `cast` appear as `DEPLOYED-DIFFERS`, skip them unconditionally — do NOT absorb.
> Absorbing fold's own SKILL.md mid-execution would silently overwrite the rules currently running.
> Absorbing cast's SKILL.md could break the next deploy. Both are protected. Flag them as `CONFLICT` in the PLAN table and tell the user to reconcile manually after this run.

> **HARD RULE — No baseline = no absorb.**
> `forge-status.sh` uses a three-way comparison (forge vs baseline vs deployed) to determine direction.
> If no baseline exists (`.last-cast.json` missing or SHA unreachable), the script emits `CONFLICT (no-baseline)` for all differing skills — it does **not** attempt a two-way heuristic. Treat every `CONFLICT (no-baseline)` as unresolvable by fold. Tell the user to run `/cast` first to establish a baseline, then re-run `/fold`.

| Classification | /fold Action |
|---------------|-------------|
| `IDENTICAL` | Skip |
| `DEPLOYED-DIFFERS` (baseline valid, skill ≠ fold/cast) | Diff deployed vs forge, show changes in PLAN sub-row, absorb after user confirms |
| `DEPLOYED-DIFFERS` (no valid baseline) | Treat as `CONFLICT` — cannot determine direction safely |
| `DEPLOYED-DIFFERS` (skill = fold or cast) | Skip — flag as `CONFLICT` in PLAN, reconcile manually |
| `FORGE-UPDATED` | Skip — deploy on next `/cast` |
| `CONFLICT` | Show both diffs with full content in PLAN sub-rows, AskUserQuestion: keep forge / keep membrane / manual merge |
| `ADDED` / `REMOVED` | Skip — handled by `/cast` |

### 1b-1d: Config Sync

Read in parallel: `~/.claude/CLAUDE.md`, `~/.claude/settings.json`, `<forge>/skills/forge/claude-code-rules.md`.

Diff and identify additions, removals, conflicts between global config and forge reference. Present a Config Sync Report table. After user confirms, update `claude-code-rules.md` to match.

Sync rules: CLAUDE.md ↔ reference auto-allowed table, WebFetch domains must match exactly, destructive commands NEVER in allow list, hooks/additionalDirectories are machine-specific — never sync.

---

## Part 2: Review & Prune Existing Knowledge

### Triggers (skip if none fire)

| Trigger | What fires |
|---------|-----------|
| Any `<forge>/learnings/*.md` file > 50 entries | Learning review (2a) |
| `<forge>/memory/` has > 20 files | Memory review (2b) |

If no triggers fire, skip Part 2 entirely.

### Evidence Collection

Run `<forge>/scripts/fold-evidence.sh` to collect all forge learnings, forge memories, membrane learnings, membrane memories, and tracker state in one call. Use this output as evidence for Parts 2-4.

Launch Parts 2a and 2b in parallel (independent reviews):

### 2a: Forge Learning Review

Classify each entry: **CURRENT** (keep), **STALE** (remove — web-search to verify), **MERGED** (consolidate with duplicate), **EVOLVED** (rewrite with updated info). Present review table, apply after user confirms.

### 2b: Forge Memory Review

Classify each file: **CURRENT** (keep), **STALE** (remove), **MERGED** (consolidate), **EVOLVED** (rewrite), **PROMOTED** (already in SKILL.md — redundant). Present review table, apply after user confirms.

---

Launch Parts 3 and 4 in parallel (independent absorptions):

## Part 3: Learning Absorption

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

Classify each candidate: **NEW** (absorb), **DUPLICATE** (skip), **INCORPORATED** (already in SKILL.md — skip), **SUPERSEDED** (flag), **CROSS-CUTTING** (route to global-patterns + relevant skill files).

Build a unified PLAN table from ALL parts (config sync, skills, learnings, memories) — one table, one decision point. Use contributor names from `git blame` on forge files and full learning bodies from the Learning Details in `forge-status.sh` output.

**Every row that represents a change must include a sub-row showing the essence of the change** — not the filename or commit title, but the rule, principle, or knowledge that will land in forge. The user must be able to judge each item before approving.

- **Skill row** → the specific rule, step, or behaviour being absorbed (not the commit message)
- **Learning row** → the full `**Learning**:` body + `**Apply when**:` line
- **Config row** → the specific rule or setting being merged
- **Memory row** → the key principle or convention the file encodes

```markdown
## Forge Transfer — /fold | YYYY-MM-DD | PLAN

| What | Action | Contributor |
|------|--------|-------------|
| `/probe` skill | absorb (deployed-differs) | — |
|   → Added: check for circular dependency risks when evaluating service boundaries. Flag any design where service A calls B and B calls A synchronously. | | |
| claude-code-rules.md (config) | merge | — |
|   → Adding WebFetch domain: `better-auth.com`. Adding `tsx` to auto-allowed commands. | | |
| Integer Money Pattern | absorb → global-patterns.md | cygnum |
|   → Learning: Store all currency as smallest-unit integers (cents/centavos) in the database. Convert at boundaries: input → `toSmallest()`, payment provider → `fromSmallest()`, display → `format()`. Eliminates floating-point drift. `numeric`/`decimal` DB types map to strings in most ORMs, causing scattered cast bugs. | | |
|   → Apply when: any feature that stores, calculates, or displays monetary values | | |
| Mobile Testing Progression | skip (duplicate) | cygnum |
|   → Already in global-patterns.md | | |
| deploy-practices.md (memory) | absorb | — |
|   → Convention: gate all deploy scripts behind environment checks; never run destructive ops without explicit env confirmation | | |

3 skills identical, 2 learnings in forge — omitted.
```

**Action vocabulary**: `absorb` (new learning/memory → forge), `merge` (config drift), `skip (duplicate)`, `skip (personal)`, `skip (superseded)`, `skip (incorporated)`, `conflict` (both changed)

If everything is in sync: skip the table, say "Everything in sync." and proceed to Part 6.

**Output the PLAN table as console text (markdown), NEVER via AskUserQuestion** — compressed UI makes tables unreadable. Then use AskUserQuestion with "Apply all / Adjust / Skip" prompt.

### Step 4: Genericize & Absorb

**No project-specific details in forge** — strip all project names, paths, domains, business logic. See forge CLAUDE.md "No Project Names" rule for the full list.

> **HARD RULE — Write to forge, NOT the membrane.**
> Append absorbed entries to `<forge>/learnings/<file>.md` (e.g., `/root/dev/forge/learnings/global-patterns.md`).
> **NEVER write to `~/.claude/learnings/<file>.md`** — that is the membrane (deployed copy), NOT the source of truth.
> Forge is the source. `/cast` deploys forge → membrane afterward. Writing to membrane silently skips forge, creating a permanent gap that every future `/mark` will flag as "fold needed" — and `/fold` won't fix it because the tracker already marked the entries as processed.

Target files in `<forge>/learnings/`:
- `probe-learnings.md` — architecture | `press-learnings.md` — go-live readiness
- `poke-learnings.md` — tech debt/logging | `prime-learnings.md` — ideation/blueprint
- `global-patterns.md` — cross-cutting

Format: `## [Title] (YYYY-MM-DD)` + `**Learning**:` + `**Apply when**:`

Source entries in `~/.claude/learnings/` are NEVER deleted.

### Processing Tracker

Maintain `<forge>/learnings/.fold-tracker.json` with `lastRun`, `processedEntries` (triaged titles from general.md), `promotedEntries` (promoted Forge-worthy titles). Skip entries whose title is already tracked.

> **HARD RULE — Tracker is APPEND-ONLY. No exceptions.**
> Never remove entries from `processedEntries`. The tracker lives in the forge repo (shared across all users). Each user has their own membrane. Removing a tracker entry based on one user's membrane state causes every OTHER user's fold to re-absorb that entry — creating duplicates across the team. No single user can see all membranes, so no single user can safely compact the tracker.
> Residue entries (tracked but no matching forge file) are harmless — fold just skips them. A tracker with 1000 entries is ~10KB. Let it grow.

> **One-time migration**: If `<forge>/learnings/.reforge-tracker.json` exists, copy its `processedEntries` and `promotedEntries` into `.fold-tracker.json` before proceeding, then delete `.reforge-tracker.json`. The old name is dead — any entries tracked there must be preserved or every fold run will re-triage the entire history.

---

## Part 4: Memory Absorption

### Memory Tracker

Maintain `<forge>/memory/.memory-tracker.json` with `lastRun` and `skippedFiles` (PERSONAL memories intentionally not absorbed). A file needs triage only if it's in membrane but NOT in forge AND NOT in `skippedFiles`. Tracker is append-only — never remove skippedFiles entries.

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

## Part 5: Staging Archival

### Triggers (skip if none fire)

| Trigger | What fires |
|---------|-----------|
| `~/.claude/learnings/general.md` > 100 entries | Learning archival |
| `~/.claude/memory/` has > 30 files | Memory archival |

For **learning archival**: cross-reference entries against tracker `processedEntries` AND forge learnings files. Entries that are BOTH processed AND present in forge → offer to move to `~/.claude/learnings/archive/general.md`.

For **memory archival**: files identical in both membrane and forge → offer to move to `~/.claude/memory/archive/`.

Never delete — archival is a move.

**Note**: Archiving entries from `general.md` does NOT allow tracker compaction. The tracker is shared across all forge users. Archiving from ONE user's membrane doesn't mean other users have archived too — their fold would re-absorb the entry if the tracker entry was removed. The tracker is truly append-only.

---

## Part 6: Commit & Push

`/fold` owns its own commit flow — no `/wrap` needed.

1. **Conflict check**: `git -C <forge> diff --name-only --diff-filter=U`. If conflicts exist, STOP.
2. **Stage** changed files with `git add <file>` (never `git add -A`)
3. **Update context** in `<forge>/CLAUDE.md` Current Context section
4. **Compact check**: If CLAUDE.md > ~20k chars, overflow to `memory/`
5. **Commit**: descriptive message (what was absorbed, not where from — no project names) with `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>`
6. **Push decision**: AskUserQuestion — "Yes, push" / "No, keep local"

## Part 7: DONE Report

Present the receipt of what was actually executed. Only include rows for items that changed — no "in sync" rows.

**Every changed row must include a sub-row showing the essence of the change** — not the filename or commit title, but the rule, principle, or knowledge that now lives in forge. A reader who never saw the PLAN table must understand *what shifted* from this report alone.

- **Skill row** → the specific rule, step, or behaviour that was absorbed (not the commit message)
- **Learning row** → the full `**Learning**:` body + `**Apply when**:` line
- **Config row** → the specific rule or setting that was merged
- **Memory row** → the key principle or convention the file encodes

```markdown
## Forge Transfer — /fold | YYYY-MM-DD | DONE

| What | Result | Contributor |
|------|--------|-------------|
| `/probe` skill | absorbed | — |
|   → Added: check for circular dependency risks when evaluating service boundaries. Flag any design where service A calls B and B calls A synchronously. | | |
| claude-code-rules.md (config) | merged | — |
|   → Added WebFetch domain: `better-auth.com`. Added `tsx` to auto-allowed commands. | | |
| Integer Money Pattern | absorbed → global-patterns.md | cygnum |
|   → Learning: Store all currency as smallest-unit integers (cents/centavos) in the database. Convert at boundaries: input → `toSmallest()`, payment provider → `fromSmallest()`, display → `format()`. Eliminates floating-point drift. `numeric`/`decimal` DB types map to strings in most ORMs, causing scattered cast bugs. | | |
|   → Apply when: any feature that stores, calculates, or displays monetary values | | |
| Mobile Testing Progression | skipped (duplicate) | cygnum |
| deploy-practices.md (memory) | absorbed | — |
|   → Convention: gate all deploy scripts behind environment checks; never run destructive ops without explicit env confirmation | | |

Commit: `abc1234` — pushed to origin/main
```

**Result vocabulary** (past tense of PLAN actions): `absorbed`, `merged`, `skipped (reason)`, `reconciled`

If nothing changed: "Everything in sync." — skip both PLAN and DONE reports.

After the table: commit hash + push status.
