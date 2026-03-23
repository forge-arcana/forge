---
name: mark
description: Inspect membrane status — reports skill drift, accumulated learnings, and memory state between forge and the deployed membrane. Read-only, no changes made.
user-invocable: true
---

# /mark — Membrane Inspection

Read-only inspection of the membrane (`~/.claude/`) against the forge source of truth. Reports what's drifted, what's accumulated, and what's ready for `/cast` or `/fold`.

**This skill makes NO changes.** It only reads and reports.

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

### 2a: Global Learnings (`~/.claude/learnings/`)

From the parallel reads, extract all `## Title` headings from `general.md`.
Compare against `processedEntries` titles from the tracker.

Output:
```markdown
## Learning Status

| Source | Total Entries | Processed | Unprocessed |
|--------|--------------|-----------|-------------|
| ~/.claude/learnings/general.md | X | Y | Z |

**Unprocessed entries** (ready for /fold):
1. [entry title/first line] (YYYY-MM-DD)
2. [entry title/first line] (YYYY-MM-DD)
...
```

### 2b: Skill-Specific Learnings (`~/.claude/learnings/`)

Check for other learning files and compare against forge copies:

```markdown
| File | User Copy | Forge Copy | Status |
|------|-----------|------------|--------|
| probe-learnings.md | 12 entries | 10 entries | 2 new in user — fold needed |
| press-learnings.md | 8 entries | 8 entries | In sync |
```

---

## Section 3: Memory Status

Use the memory files already read in the parallel batch above.

For each file in `~/.claude/memory/`:
- Check if it exists in `<forge>/memory/` → if yes, `diff --strip-trailing-cr` to check sync
- Check if it's in tracker's `skippedFiles` → if yes, mark as "Skipped (PERSONAL)"
- Otherwise → new, fold candidate

Output:
```markdown
## Memory Status

| File | In Membrane | In Forge | Status |
|------|-------------|----------|--------|
| deploy-practices.md | yes | yes | In sync |
| new-pattern.md | yes | no | New — fold candidate |
| team-convention.md | yes | yes (differs) | Updated — fold candidate |

**Forge-only memories** (in forge but not deployed — cast candidate):
| File | Summary |
|------|---------|
| old-convention.md | [description from frontmatter] |

**Summary**: X in sync, Y need fold, Z need cast
```

---

## Section 4: Combined Status

Output a final summary with recommended actions:

```markdown
## Membrane Status — Summary

| Area | Status | Action |
|------|--------|--------|
| Forge Remote | [up to date / X commits behind] | [Run /cast to pull] |
| Skills | Y need cast, Z need fold | Run `/cast` or `/fold` |
| Learnings | X unprocessed entries | Run `/fold` |
| Memory | Y new, Z updated | Run `/fold` |

**Recommended next step**: [/cast if forge has updates to pull, /fold if membrane has accumulated knowledge, or "All in sync — nothing to do"]
```
