# Forge Preflight

> Shared pre-flight and classification system for all forge-cycle skills (/mark, /cast, /fold). Each skill references this document and specifies its **mode** (`fetch` or `pull`).
>
> This is the shared heart of the forge cycle. Mark inspects. Cast and fold act — in opposite directions, using the same classifications.

## Step 1: Resolve Forge Path

1. Check `~/.claude/CLAUDE.md` for a `forge-path:` line
2. If not found, error: "forge-path not found in ~/.claude/CLAUDE.md. Run /cast to configure."
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

## Step 4: Entry-Level Classification (all pillars)

The same six classifications from Step 3 apply to **every pillar** — not just skills. For learnings, memory, and config, the unit of comparison is an **entry** (a `## ` heading block in a markdown file) rather than a directory.

### Universal Classification Table

| Classification | Meaning | /mark | /cast (forge → user) | /fold (user → forge) |
|----------------|---------|-------|---------------------|---------------------|
| `IDENTICAL` | Both sides, same content | Report: in sync | Skip | Skip |
| `FORGE-UPDATED` | Both sides, forge is newer | Report: forge has update | Deploy forge version | Skip (next cast) |
| `DEPLOYED-DIFFERS` | Both sides, membrane is newer | Report: membrane has update | Skip (next fold) | Absorb candidate |
| `CONFLICT` | Both changed since baseline | Report: conflict | User decides | User decides |
| `ADDED` | Exists only in forge | Report: new in forge | Deploy | Skip |
| `REMOVED` | Exists only in membrane | Report: new in membrane | Skip | Absorb candidate |

**This is one vocabulary, three interpretations.** Mark observes. Cast deploys rightward. Fold absorbs leftward. The user decides at every step via `AskUserQuestion`.

### Applying to Each Pillar

**Skills** (Step 3): Unit = skill directory. Compared via `diff -rq`. Already covered above.

**Learnings**: Unit = `## ` heading block within each `.md` file in `learnings/`. Parse both sides, match entries by title, classify each.
- Compare `<forge>/learnings/*.md` entries against `~/.claude/learnings/*.md` entries
- Skip `.json` tracker files

**Memory**: Unit = whole file for single-entry files, `## ` heading block for multi-entry files.
- Compare `<forge>/memory/*.md` against `~/.claude/memory/*.md`
- Skip `.json` tracker files and `MEMORY.md` index

**Config**: Unit = rule/section within `~/.claude/CLAUDE.md` vs `<forge>/skills/forge/claude-code-rules.md`.
- Match by HARD RULE titles, section headings, and permission entries
- Machine-specific content (hooks, additionalDirectories, forge-path) is **never classified** — always skipped

### Baseline for Entries

For skills, the baseline is the last-cast SHA. For entries within files, use **title matching**:
- Entry title exists in both → compare content (IDENTICAL / FORGE-UPDATED / DEPLOYED-DIFFERS / CONFLICT)
- Entry title exists only on one side → ADDED or REMOVED

When baseline SHA is available, use `git show <baseline>:<file>` to determine which side changed. Without a baseline, fall back to two-way comparison (treat any difference as CONFLICT for safety).

### Triage Ceremony (shared across all three skills)

All three skills follow the same ceremony per pillar:

1. **Classify** every entry using the universal table above
2. **Present** a triage report as console text (markdown table — never via AskUserQuestion, which compresses large tables)
3. **Confirm** via `AskUserQuestion` with simple options (mark skips this — read-only)
4. **Act** on confirmed entries only (mark skips this — read-only)

The report format is the same in every skill — only the action column changes based on direction.
