---
name: mark
description: Inspect membrane status — reports skill drift, accumulated learnings, and memory state between forge and the deployed membrane. Read-only, no changes made.
user-invocable: true
---

# /mark — Membrane Inspection

Read-only inspection of the membrane (`~/.claude/`) against the forge source of truth. Reports what's drifted, what's accumulated, and what's ready for `/cast` or `/fold`.

Uses the **universal classification system** from [preflight.md Step 4](../forge/preflight.md#step-4-entry-level-classification-all-pillars) across ALL pillars (skills, learnings, memory, config). Mark is the bridge between cast and fold — it observes the same state that cast deploys and fold absorbs.

**This skill makes NO changes.** It only reads, classifies, and reports.

## Step 0: Preflight

> Execute [Forge Preflight](../forge/preflight.md) in **fetch** mode.

This resolves the forge path, fetches the latest remote state (without pulling), and produces the **Skill Drift Report** with directional classifications (IDENTICAL, FORGE-UPDATED, DEPLOYED-DIFFERS, ADDED, REMOVED).

Run `<forge>/scripts/forge-status.sh --fetch` and use its output for Sections 1-3 below. This single command replaces ~30 sequential tool calls with one.

Output the drift report as **Section 1: Skill Status**.

---

## Sections 2-3: Learning & Memory Status (parallel evidence collection)

Launch **all of these reads in parallel** before processing (all independent):
- Read `~/.claude/learnings/general.md`
- Read `<forge>/learnings/.reforge-tracker.json`
- Glob and read all `~/.claude/learnings/*.md` files
- Glob and read all `<forge>/learnings/*.md` files
- Glob and read all `~/.claude/memory/*.md` files (exclude MEMORY.md)
- Glob and read all `<forge>/memory/*.md` files (exclude MEMORY.md)
- Read `<forge>/memory/.memory-tracker.json` (if it exists)

Then process the results into Sections 2 and 3 below.

### 2a: Learning Status

For each `.md` file in both `<forge>/learnings/` and `~/.claude/learnings/` (skip `.json` trackers), parse entries by `## ` headings and classify each using the universal system (preflight.md Step 4):

```markdown
## Learning Status

| File | Entry | Classification | Direction |
|------|-------|---------------|-----------|
| global-patterns.md | WSL Path Compatibility | IDENTICAL | — |
| global-patterns.md | Integer Money Pattern | ADDED (forge-only) | cast needed |
| global-patterns.md | New User Discovery | REMOVED (membrane-only) | fold needed |
| poke-learnings.md | Band-Aid Detection | DEPLOYED-DIFFERS | fold needed |

**Summary**: X identical, Y cast needed, Z fold needed
```

---

## Section 3: Memory Status

For each `.md` file in both `<forge>/memory/` and `~/.claude/memory/` (skip `.json` trackers, skip `MEMORY.md`), classify using the universal system:

```markdown
## Memory Status

| File | Classification | Direction |
|------|---------------|-----------|
| identity.md | IDENTICAL | — |
| new-pattern.md | REMOVED (membrane-only) | fold needed |
| team-convention.md | DEPLOYED-DIFFERS | fold needed |
| old-convention.md | ADDED (forge-only) | cast needed |

**Summary**: X identical, Y cast needed, Z fold needed
```

---

## Section 4: Config Status

Compare `~/.claude/CLAUDE.md` against `<forge>/skills/forge/claude-code-rules.md` using the universal classification:

```markdown
## Config Status

| Rule/Section | Classification | Direction |
|-------------|---------------|-----------|
| No Command Chaining | IDENTICAL | — |
| AskUserQuestion HARD RULE | ADDED (forge-only) | cast needed |
| Custom project shorthand | REMOVED (membrane-only) | fold needed |

**Summary**: X identical, Y cast needed, Z fold needed
```

Skip machine-specific content (hooks, additionalDirectories, forge-path).

---

## Section 5: Combined Status

Output a final summary with recommended actions:

```markdown
## Membrane Status — Summary

| Pillar | Identical | Cast Needed | Fold Needed | Conflicts |
|--------|-----------|-------------|-------------|-----------|
| Skills | X | Y | Z | 0 |
| Learnings | X | Y | Z | 0 |
| Memory | X | Y | Z | 0 |
| Config | X | Y | Z | 0 |

**Recommended next step**: [/cast if forge has updates to deploy, /fold if membrane has accumulated knowledge, or "All in sync — nothing to do"]
```
