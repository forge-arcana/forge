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

Fold is a thin directional wrapper around the shared classification engine (`forge-status.sh`). It runs the same script as `/mark` and `/cast`, then absorbs everything in the **fold column** of the [universal classification table](../forge/preflight.md).

Single command, seven parts:

1. **Classification + config sync** — run shared script, absorb user config additions into forge
2. **Review & prune** — check existing forge knowledge for staleness (auto-triggers)
3. **Learning absorption** — promote forge-worthy entries, triage, genericize, absorb
4. **Memory absorption** — triage team-worthy vs personal, absorb
5. **Staging archival** — archive fully-absorbed entries from staging area
6. **Commit & push** — conflict gate, stage, commit, push with user confirmation
7. **Report** — summary of all changes

---

## Part 1: Classification + Config Sync

### Step 0: Preflight

> Execute [Forge Preflight](../forge/preflight.md) in **pull** mode.

Run `<forge>/scripts/forge-status.sh --pull` to pull the latest forge and produce the **full classification report** across all pillars (skills, learnings, memory). This single script call replaces ~30 sequential tool calls.

**Critical**: without pulling first, /fold could overwrite newer forge changes with stale deployed copies.

### Step 1a: Skill Reverse-Sync

For each classified skill in the script output, apply the **fold direction**:

| Classification | Fold Action |
|---------------|-------------|
| `IDENTICAL` | Skip |
| `DEPLOYED-DIFFERS` | Absorb deployed version into forge source (reverse-sync) |
| `FORGE-UPDATED` | Skip — forge has newer changes, deploy on next `/cast` |
| `CONFLICT` | Show both diffs, use `AskUserQuestion` to ask which version to keep |
| `ADDED` | Skip — new in forge, deploy on next `/cast` |
| `REMOVED` | Skip |

For each `DEPLOYED-DIFFERS` skill: show diff, confirm, then copy deployed version into `<forge>/skills/<name>/`.

### Step 1b: Config Sync (user → forge)

Read `~/.claude/CLAUDE.md` and `<forge>/skills/forge/claude-code-rules.md` in parallel. Apply **fold direction**:
- **User-only rules** → absorb into forge reference
- **Forge-only rules** → **DO NOT remove**. Flag as "run `/cast` to install"
- **Conflicts** → present both, user decides

**IMPORTANT**: `/fold` only flows user → forge. Never remove forge-only rules.

**Sync rules:**
- HARD RULES, workflow orchestration, testing strategy, shorthand commands → sync
- Bash permissions, auto-allowed commands, WebFetch domains → sync
- Hooks, additionalDirectories, machine-specific paths → **never sync**

---

## Part 2: Review & Prune Existing Knowledge

Before absorbing new knowledge, check if existing knowledge is still valid.

### Triggers (skip if none fire)

| Trigger | What fires |
|---------|-----------|
| Any `<forge>/learnings/*.md` file > 50 entries | Learning review (2a) |
| `<forge>/memory/` has > 20 files | Memory review (2b) |

### Evidence Collection

Run `<forge>/scripts/fold-evidence.sh` to collect all forge learnings, forge memories, membrane learnings, membrane memories, and tracker state. Use the output for Parts 2-4.

### 2a: Forge Learning Review

Classify each existing entry: **CURRENT** (keep), **STALE** (remove), **MERGED** (consolidate), **EVOLVED** (rewrite). Web-search to confirm STALE/EVOLVED. Present table, apply after user confirms.

### 2b: Forge Memory Review

Classify each existing file: **CURRENT**, **STALE**, **MERGED**, **EVOLVED**, **PROMOTED** (already in SKILL.md — redundant). Present table, apply after user confirms.

---

## Part 3: Learning Absorption

### Step 0: Promote Forge-worthy Learnings from Project Memories

Scan `~/.claude/projects/*/memory/*-learnings.md` for entries tagged `Forge-worthy: yes`.

1. **Dedup**: Skip if title is in `<forge>/learnings/.reforge-tracker.json` `promotedEntries` or already in `~/.claude/learnings/general.md`
2. **Genericize**: Strip all project-specific details (see genericization rules in Step 4)
3. **Promote**: Append to `~/.claude/learnings/general.md` with `<!-- promoted from project memory, YYYY-MM-DD -->`
4. **Report**: Promotion summary table

### Intake + Triage

Use fold-evidence.sh output. For each entry in `~/.claude/learnings/general.md`, classify using the **fold direction** from the universal table, plus fold-specific sub-classifications:

| Universal Class | Fold Sub-Class | Meaning |
|----------------|----------------|---------|
| `REMOVED` (membrane-only) | **NEW** | Not in forge — absorb candidate |
| `REMOVED` (membrane-only) | **CROSS-CUTTING** | Applies to multiple skills — route to `global-patterns.md` |
| `IDENTICAL` | **DUPLICATE** | Already in forge — skip |
| `IDENTICAL` | **INCORPORATED** | Already baked into a SKILL.md — skip |
| `DEPLOYED-DIFFERS` | **SUPERSEDED** | Contradicted by newer forge entry — flag for review |

Fold adds sub-classifications because it's the quality gate INTO the source of truth. Cast doesn't need them — it deploys FROM the source of truth.

**Output the full triage as console text** (markdown tables), NEVER via AskUserQuestion. Then use AskUserQuestion with "Approve all / Adjust" prompt.

### Genericize & Absorb

**CRITICAL: No project-specific details in forge.** Before writing any learning:

| Strip | Replace with |
|-------|-------------|
| Project names | "the project" or omit |
| Specific file paths | Generic path pattern |
| URLs, domains, API endpoints | "[API endpoint]", "[domain]" |
| User/team names | "the team" or omit |
| Database/table names | Generic description |
| Business logic unique to one product | The general pattern it exemplifies |

Append each confirmed learning to the appropriate file in `<forge>/learnings/` (`probe-learnings.md`, `poke-learnings.md`, `press-learnings.md`, `prime-learnings.md`, `global-patterns.md`).

Format:
```markdown
## [Short Title] (YYYY-MM-DD)
**Learning**: [genericized insight]
**Apply when**: [context for relevance]
```

**Source entries in `~/.claude/learnings/` are NEVER deleted.**

### Processing Tracker

Maintain `<forge>/learnings/.reforge-tracker.json` with `processedEntries` (triaged titles) and `promotedEntries` (forge-worthy titles). Update after absorption.

---

## Part 4: Memory Absorption

### Intake + Triage

Use fold-evidence.sh output. Classify each membrane memory file using the fold direction, plus fold-specific sub-classifications:

| Universal Class | Fold Sub-Class | Meaning |
|----------------|----------------|---------|
| `REMOVED` (membrane-only) | **TEAM-WORTHY** | Shared resource — absorb |
| `REMOVED` (membrane-only) | **PERSONAL** | User-specific — skip (record in tracker) |
| `IDENTICAL` | **DUPLICATE** | Already in forge — skip |
| `DEPLOYED-DIFFERS` | **UPDATE** | User's version is newer — merge |

**Classification rules:**
- `type: user` → ALWAYS personal
- `type: feedback` → team-worthy if about code/process
- `type: reference` → team-worthy if pointing to shared resources
- `type: team-*` → always team-worthy

Present triage table, then `AskUserQuestion` to confirm.

### Absorb

Copy TEAM-WORTHY to `<forge>/memory/`, strip personal details, add `<!-- source: team-member, YYYY-MM-DD -->`. For UPDATE: merge newer content. Update `<forge>/memory/.memory-tracker.json` `skippedFiles` for PERSONAL entries.

**Source entries in `~/.claude/memory/` are NEVER deleted.**

---

## Part 5: Staging Archival

### Trigger (skip if none fire)

| Trigger | What fires |
|---------|-----------|
| `~/.claude/learnings/general.md` > 100 entries | Learning archival |
| `~/.claude/memory/` has > 30 files | Memory archival |

For entries that are BOTH processed AND present in forge: offer to move to `~/.claude/learnings/archive/` or `~/.claude/memory/archive/`. **Never delete** — archival is a move.

---

## Part 6: Commit & Push

`/fold` owns its own commit flow — no `/wrap` needed.

1. **Conflict check**: `git -C <forge> diff --name-only --diff-filter=U`. If conflicts exist, **STOP** and list them.
2. **Stage** changed files with `git add <file>` (never `git add -A`)
3. **Update context** in `<forge>/CLAUDE.md` Current Context section
4. **Compact check**: If `<forge>/CLAUDE.md` exceeds ~20k chars, move verbose content to `memory/`
5. **Commit**: descriptive message (what was absorbed, never where from — no project names)
6. **Push**: Use `AskUserQuestion` — "Yes, push" / "No, keep local"

## Part 7: Report

Present a **Forge Transfer** table summarizing what changed:

```markdown
## Forge Transfer — /fold | [DATE]

| Direction | What |
|-----------|------|
| ⬆ SENT | 3 poke learnings — schema defaults, confidence scoring, client identity |
| ⬆ SENT | Identity update — seven arts, /pry added |
| — SKIPPED | 2 personal memories — not forge-worthy |
```

- **⬆ SENT** — learnings and memories absorbed into forge
- **— SKIPPED** — items explicitly skipped (personal memories, below-threshold reviews)
- If forge-only rules were detected: note "X forge-only rules not installed — run `/cast`"
- If nothing changed: just say "Everything in sync."

After the table:
> **Commit**: `[hash]` (or: no changes to commit)
> **Push**: pushed to remote / user declined / blocked by conflicts
