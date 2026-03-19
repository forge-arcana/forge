# Forge Preflight

> Shared pre-flight steps for all forge-cycle skills (/mark, /cast, /fold). Each skill references this document and specifies its **mode** (`fetch` or `pull`).

## Step 1: Resolve Forge Path

1. Check `~/.claude/CLAUDE.md` for a `forge-path:` line
2. If not found, fall back to `/root/dev/forge`
3. If the resolved path doesn't exist, error: "Forge not found. Clone the forge repo first."

## Step 2: Remote Sync

The calling skill declares its mode:

| Mode | Command | When to use |
|------|---------|-------------|
| **fetch** | `git -C <forge> fetch` | Read-only inspection (/mark) |
| **pull** | `git -C <forge> pull --ff-only` | Before writing changes (/cast, /fold) |

After the sync command:

- **pull mode**: If the pull fails (diverged, conflicts), warn the user: "Forge repo has diverged. Run `git -C <forge> status` to investigate." Do NOT proceed with stale forge data.
- **fetch mode**: Check if local is behind remote: `git -C <forge> rev-list HEAD..origin/main --count`. If behind, report: "Forge is X commits behind remote. Run `/cast` to pull and sync."
- If up to date: proceed.

## Step 3: Skill Drift Scan

Compare forge source (`<forge>/skills/`) against deployed membrane (`~/.claude/skills/`) using diff.

For each skill directory in `<forge>/skills/` (excluding `forge/` which is reference docs, not a deployable skill):

1. Check if deployed copy exists at `~/.claude/skills/<name>/`
2. If both exist, compare using: `diff -rq --strip-trailing-cr <forge>/skills/<name> ~/.claude/skills/<name>`
3. Classify:

| Condition | Classification | Meaning |
|-----------|----------------|---------|
| No diff output | `IDENTICAL` | In sync — no action needed |
| Diff found, forge changed since baseline, deployed unchanged | `FORGE-UPDATED` | Forge has newer changes — `/cast` will deploy |
| Diff found, forge unchanged since baseline, deployed changed | `DEPLOYED-DIFFERS` | Deployed copy was modified — `/fold` will absorb |
| Diff found, both changed since baseline | `CONFLICT` | Both sides changed — user must reconcile |
| Skill exists in forge but not deployed | `ADDED` | New skill — `/cast` will deploy |
| Skill exists deployed but not in forge | `REMOVED` | Skill deleted from forge |

**Baseline**: The last-cast commit SHA stored in `~/.claude/.last-cast.json` (written by `/cast` after each deploy). If no baseline exists (first cast, or SHA unreachable after force push), falls back to a two-way heuristic (`git diff HEAD origin/main`).

Also check the reverse — skills that exist in `~/.claude/skills/` but NOT in `<forge>/skills/` (excluding `forge/`). These are `REMOVED` from forge's perspective or user-local additions.

Output the standard drift table:

```markdown
## Skill Drift Report

| Skill | Status | Action |
|-------|--------|--------|
| prime | IDENTICAL | — |
| wrap | FORGE-UPDATED | cast needed |
| qt | DEPLOYED-DIFFERS | fold needed |
| newskill | ADDED | cast needed |

**Summary**: X identical, Y need cast, Z need fold
```

The calling skill uses these classifications to decide its next steps:
- **/mark**: reports the table as-is (read-only)
- **/cast**: acts on FORGE-UPDATED, ADDED, and REMOVED (deploy forge → membrane)
- **/fold**: acts on DEPLOYED-DIFFERS only (absorb membrane → forge). Skips FORGE-UPDATED with a note: "forge has newer changes — these will deploy on next /cast"
