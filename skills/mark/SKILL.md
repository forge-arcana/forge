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

---

## Section 1: Skill Drift Report

Compare forge source (`<forge>/skills/`) against deployed membrane (`~/.claude/skills/`) using the manifest.

Read `~/.claude/skills/.forge-manifest.json`. For each skill:

1. Hash the forge source skill directory
2. Hash the deployed skill directory
3. Compare both against the manifest hash

**Hashing command** (use this exact pattern — paths must be relative to avoid mismatches):
```bash
find <dir> -type f | sort | while read f; do echo "$(realpath --relative-to=<dir> "$f")"; cat "$f"; done | sha256sum | awk '{print $1}'
```

4. Classify using three-way comparison:

| Forge vs Manifest | Deployed vs Manifest | Classification |
|-------------------|---------------------|----------------|
| Same | Same | `UNCHANGED` |
| Different | Same | `UPDATED` (forge is newer — `/cast` will deploy) |
| Same | Different | `REVERSE-DRIFT` (deployed is newer — `/fold` will absorb) |
| Different | Different | `CONFLICT` (both changed — manual review needed) |
| New skill | — | `ADDED` (forge has new skill — `/cast` will deploy) |
| Gone from forge | — | `REMOVED` (skill deleted from forge) |

Output:
```markdown
## Skill Status

| Skill | Forge | Deployed | Manifest | Status |
|-------|-------|----------|----------|--------|
| arch | abc123 | abc123 | abc123 | UNCHANGED |
| wrap | def456 | abc123 | abc123 | UPDATED — cast needed |
| qt | abc123 | ghi789 | abc123 | REVERSE-DRIFT — fold needed |

**Summary**: X unchanged, Y need cast, Z need fold, W conflicts
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

Check for other learning files (arch, audit, quick) and compare against forge copies:

```markdown
| File | User Copy | Forge Copy | Status |
|------|-----------|------------|--------|
| arch-learnings.md | 12 entries | 10 entries | 2 new in user — fold needed |
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
| Skills | Y need cast, Z need fold | Run `/cast` or `/fold` |
| Learnings | X unprocessed entries | Run `/fold` |
| Memory | Y new, Z updated | Run `/fold` |

**Recommended next step**: [/cast if forge has updates to push, /fold if membrane has accumulated knowledge, or "All in sync — nothing to do"]
```
