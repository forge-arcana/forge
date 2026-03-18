---
name: mark
description: Inspect membrane status — reports skill drift, accumulated learnings, and memory state between forge and the deployed membrane. Read-only, no changes made.
user-invocable: true
---

# /mark — Membrane Inspection

Read-only inspection of the membrane (`~/.claude/`) against the forge source of truth. Reports what's drifted, what's accumulated, and what's ready for `/cast` or `/fold`.

**This skill makes NO changes.** It only reads and reports.

## Resolve Forge Path
1. Check `~/.claude/CLAUDE.md` for a `forge-path:` line
2. If not found, fall back to `/root/dev/forge`
3. If the resolved path doesn't exist, error: "Forge not found. Clone the forge repo first."

## Step 0: Fetch Latest Forge (ALWAYS)

Before inspecting, fetch the latest remote state:

```
git -C <forge-path> fetch
```

Check if local is behind remote:
```
git -C <forge-path> rev-list HEAD..origin/main --count
```

If behind, report: "Forge is X commits behind remote. Run `/cast` to pull and sync."

---

## Section 1: Skill Drift Report

Compare forge source (`<forge>/skills/`) against deployed membrane (`~/.claude/skills/`) using diff.

For each skill directory in `<forge>/skills/` (excluding `forge/` which is reference docs, not a skill):

1. Check if deployed copy exists at `~/.claude/skills/<name>/`
2. If both exist, compare using: `diff -rq --strip-trailing-cr <forge>/skills/<name> ~/.claude/skills/<name>`
3. Classify:

| Condition | Classification |
|-----------|----------------|
| No diff output | `IDENTICAL` |
| Diff found, forge is ahead of remote | `FORGE-UPDATED` (forge has newer changes — `/cast` will deploy) |
| Diff found, forge matches remote | `DEPLOYED-DIFFERS` (deployed copy was modified — `/fold` will absorb) |
| Skill exists in forge but not deployed | `ADDED` (new skill — `/cast` will deploy) |
| Skill exists deployed but not in forge | `REMOVED` (skill deleted from forge) |

Output:
```markdown
## Skill Status

| Skill | Status | Action |
|-------|--------|--------|
| prime | IDENTICAL | — |
| wrap | FORGE-UPDATED | cast needed |
| qt | DEPLOYED-DIFFERS | fold needed |
| newskill | ADDED | cast needed |

**Summary**: X identical, Y need cast, Z need fold
```

---

## Section 2: Learning Status

### 2a: Global Learnings (`~/.claude/learnings/`)

Read `~/.claude/learnings/general.md` and count total entries.
Read `<forge>/learnings/.reforge-tracker.json` and count processed hashes.

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

Read all `.md` files in `~/.claude/memory/` and `<forge>/memory/`.

For each file in `~/.claude/memory/`:
- Check if it exists in `<forge>/memory/`
- If yes, check if content matches

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

**Recommended next step**: [/cast if forge has updates to push, /fold if membrane has accumulated knowledge, or "All in sync — nothing to do"]
```
