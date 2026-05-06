# Forge Preflight

> Shared preflight and classification system for the `/forge` cycle. The cycle invokes this preflight in one of two modes — **fetch** (dry-run inspection) or **pull** (before writing changes).
>
> This is the shared heart of the forge cycle. Mark inspects. Cast deploys. Fold absorbs. One vocabulary, three motions, one PLAN table.
>
> Path conventions: `<forge>` = the forge repo path; `<membrane>` = the harness's per-tool config directory (`~/.claude/` for Claude Code, `~/.bob/` for Bob, `~/.cursor/` for Cursor, etc.); `<rules-file>` = the harness's global rules file (`~/.claude/CLAUDE.md` for Claude Code, `~/.bob/rules/00-forge.md` or `AGENTS.md` for Bob).

## Step 1: Resolve Forge Path

1. Check `<rules-file>` for a `forge-path:` line
2. If not found, error: "forge-path not found in <rules-file>. Run /forge to configure."
3. If the resolved path doesn't exist, error: "Forge not found. Clone the forge repo first."

## Step 2: Remote Sync

The cycle declares its mode based on whether the user passed `--dry`:

| Mode | Command | When used |
|------|---------|-----------|
| **fetch** | `git -C <forge> fetch` | `/forge --dry` — read-only inspection |
| **pull** | `git -C <forge> pull --ff-only` | `/forge` — cycle is about to write |

After the sync command:

- **pull mode**: If the pull fails (diverged, conflicts), warn the user: "Forge repo has diverged. Run `git -C <forge> status` to investigate." Do NOT proceed with stale forge data.
- **fetch mode**: Check if local is behind remote: `git -C <forge> rev-list HEAD..origin/main --count`. If behind, report: "Forge is X commits behind remote. Run `/forge` (not `--dry`) to pull and sync."
- If up to date: proceed.

## Step 3: Skill Drift Scan

Compare forge source (`<forge>/core/skills/`) against deployed membrane (`<membrane>/skills/`) using diff.

For each skill directory in `<forge>/core/skills/` (excluding `forge/` which is reference docs, not a deployable skill):

1. Check if deployed copy exists at `<membrane>/skills/<name>/`
2. If both exist, compare using: `diff -rq --strip-trailing-cr <forge>/core/skills/<name> <membrane>/skills/<name>`
3. Classify:

| Condition | Classification | Meaning |
|-----------|----------------|---------|
| No diff output | `IDENTICAL` | In sync — no action needed |
| Diff found, forge changed since baseline, deployed unchanged | `FORGE-UPDATED` | Forge has newer changes — incoming row |
| Diff found, forge unchanged since baseline, deployed changed | `DEPLOYED-DIFFERS` | Deployed copy was modified — outgoing row |
| Diff found, both changed since baseline | `CONFLICT` | Both sides changed — user must reconcile |
| Skill exists in forge but not deployed | `ADDED` | New skill — incoming row |
| Skill exists deployed but not in forge | `REMOVED` | Skill deleted from forge or membrane-local addition |

**Baseline**: The last-cast commit SHA stored in `<membrane>/.last-cast.json` (written by `/forge` after each cast phase). If no baseline exists (first cycle, or SHA unreachable after force push), falls back to a two-way heuristic (`git diff HEAD origin/main`).

Also check the reverse — skills that exist in `<membrane>/skills/` but NOT in `<forge>/core/skills/` (excluding `forge/`). These are `REMOVED` from forge's perspective or user-local additions.

Output the standard drift table:

```markdown
## Skill Drift Report

| Skill | Status | Action |
|-------|--------|--------|
| prime | IDENTICAL | — |
| wrap | FORGE-UPDATED | incoming |
| qt | DEPLOYED-DIFFERS | outgoing |
| newskill | ADDED | incoming |

**Summary**: X identical, Y incoming, Z outgoing
```

The cycle uses these classifications to route each row into the PLAN table:
- `FORGE-UPDATED` / `ADDED` → ↓ INCOMING section
- `DEPLOYED-DIFFERS` / `REMOVED` → ↑ OUTGOING section
- `CONFLICT` / `CONFLICT (no-baseline)` → ⚠ CONFLICTS section

In `--dry` mode the PLAN table is rendered read-only — no selection prompt.

**Protected skills — never absorb outgoing**: `forge`, `purge`. If either appears as `DEPLOYED-DIFFERS`, it is routed to the ⚠ CONFLICTS section with note "protected — reconcile manually."

## Step 4: Entry-Level Classification (all pillars)

The same six classifications from Step 3 apply to **every pillar** — not just skills. For learnings, memory, and config, the unit of comparison is an **entry** (a `## ` heading block in a markdown file) rather than a directory.

### Universal Classification Table

| Classification | Meaning | /forge action |
|----------------|---------|---------------|
| `IDENTICAL` | Both sides, same content | Not listed in PLAN |
| `FORGE-UPDATED` | Both sides, forge is newer | ↓ INCOMING row |
| `DEPLOYED-DIFFERS` | Both sides, membrane is newer | ↑ OUTGOING row |
| `CONFLICT` | Both changed since baseline | ⚠ CONFLICTS row |
| `ADDED` | Exists only in forge | ↓ INCOMING row |
| `REMOVED` | Exists only in membrane | ↑ OUTGOING row |

**One vocabulary, one PLAN table, per-row direction**. The user decides at every row via the table's selection UX.

### Applying to Each Pillar

**Skills** (Step 3): Unit = skill directory. Compared via `diff -rq`. Already covered above.

**Learnings**: Unit = `## ` heading block within each `.md` file in `learnings/`. Parse both sides, match entries by title, classify each.
- Compare `<forge>/learnings/*.md` entries against `<membrane>/learnings/*.md` entries
- Skip `.json` tracker files

**Memory**: Unit = whole file for single-entry files, `## ` heading block for multi-entry files.
- Compare `<forge>/memory/*.md` against `<membrane>/memory/*.md`
- Skip `.json` tracker files and `MEMORY.md` index

**Config**: Unit = rule/section within `<rules-file>` vs the active adapter's rules reference (e.g., `<forge>/adapters/claude-code/refs/claude-code-rules.md` for Claude Code).
- Match by HARD RULE titles, section headings, and permission entries
- Machine-specific content (hooks, additional working directories, forge-path) is **never classified** — always skipped

### Baseline for Entries

For skills, the baseline is the last-cast SHA. For entries within files, use **title matching**:
- Entry title exists in both → compare content (IDENTICAL / FORGE-UPDATED / DEPLOYED-DIFFERS / CONFLICT)
- Entry title exists only on one side → ADDED or REMOVED

When baseline SHA is available, use `git show <baseline>:<file>` to determine which side changed. Without a baseline, fall back to two-way comparison (treat any difference as CONFLICT for safety).

### Triage Ceremony (single ceremony, shared across all pillars)

`/forge` runs one ceremony per cycle:

1. **Classify** every entry using the universal table above
2. **Present** a unified PLAN table as console text (markdown — never via a multi-choice prompt, which compresses large tables)
3. **Confirm** via your harness's multi-choice prompt (or inline if unavailable) with simple options: "Apply selected" / "Adjust" / "Cancel" (skipped in `--dry`)
4. **Act** on confirmed entries only — cast phase (incoming) first, fold phase (outgoing) second (skipped in `--dry`)

The report format is the same regardless of pillar — only the sub-row content (the "essence") changes based on what's being transferred.
