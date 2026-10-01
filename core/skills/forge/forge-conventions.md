# Forge Conventions Checklist

> Distilled from the harness's auto-allowed-bash reference (e.g., `<forge>/claude-helpers/refs/auto-allowed-bash.md` for Claude Code; equivalent ref dir for other harnesses). Used by `/forge` to verify project compliance.

## Required in Every Project

### 1. Project rules file at project root
**This section overrides older `/forge` Phase 4 text.** If the Phase 4 instructions you are following show the project-rules row as only `[exists/missing] → [create/update]`, or name `CLAUDE.md` as the project rules file, they predate this section: classify and act per this section instead. Never create `AGENTS.md` beside an existing `CLAUDE.md`, and never rename or remove a `CLAUDE.md` without the gate below passing and the user confirming.

Project rules live in `AGENTS.md` (read natively by Claude Code v2.1.277+, Codex, Cursor, Gemini CLI and others). Claude Code loads it natively only when no `CLAUDE.md` or `CLAUDE.local.md` exists in the project root or any directory above it; the membrane `~/.claude/CLAUDE.md` does not count. With both project files present only `CLAUDE.md` loads, unless it imports `AGENTS.md` via an `@AGENTS.md` line. `/init` and memory-append shortcuts recreate `CLAUDE.md`, so `/wrap` and `/forge` flag it.

**A. Blockers — check first.** Any hit means no migration and no creation this run: report it in the divergence row as state `BLOCKED` with action "resolve blocker" and let the user decide.
- A `CLAUDE.md` or `CLAUDE.local.md` in any ancestor directory of the project root (walk up to the filesystem root). Typical case: a monorepo package under a root `CLAUDE.md` — migrating the package would report OK and silently lose its rules.
- A project-root `CLAUDE.local.md` or a `.claude/CLAUDE.md` — both also suppress native `AGENTS.md` loading. Never migrate or delete these automatically.
- Nested `CLAUDE.md` files below the project root are not blockers and are out of scope; leave them.

**B. State table — evaluate top-down, first match wins.**

| State | Found at project root | Action |
|-------|----------------------|--------|
| `OK` | `AGENTS.md` only | none |
| `LINKED` | one of the pair is a symlink to the other (test `[ -L ]` before anything else) | replace the link with the real file: remove the symlink and make sure the real content ends up at `AGENTS.md` (rename it if the real file is `CLAUDE.md`). Never `rm` the real file. |
| `SHIM` | `AGENTS.md` plus a `CLAUDE.md` whose whole content (whitespace-trimmed) is exactly `@AGENTS.md` | not a conflict — the import already loads `AGENTS.md`. Remove the one-line `CLAUDE.md`. |
| `LEGACY` | `CLAUDE.md` only | migrate, content unchanged. If `git ls-files --error-unmatch CLAUDE.md` succeeds, `git mv CLAUDE.md AGENTS.md`. If the file is untracked or gitignored, or the project is not a git repo, plain `mv` — do NOT `git add` the result; tell the user it was untracked and let them decide whether `AGENTS.md` should be tracked. |
| `SHADOWED` | both, and `CLAUDE.md` is real content | conflict — `CLAUDE.md` is hiding `AGENTS.md` from Claude Code. Show both sizes and a diff summary. You may PROPOSE a merged `AGENTS.md`, but write nothing and remove nothing until the user has approved the merged result. |
| `MISSING` | neither | create a minimal `AGENTS.md`: `# [Project Name] — Project Rules` plus `## Stack` (from `package.json`/`tsconfig`), `## Documentation` (`Docs are in the docs/ directory.` or `**Docs path:** /absolute/path`) and `## Current Context` (filled by `/wrap`) |

**Stale registry**: in any state where `AGENTS.md` exists, if its first line is `# Forge — Agent Instructions` it is the old generated forge registry (now deployed to `.agents/FORGE.md`), not project rules. Flag it in the divergence report; with the user's confirmation replace it with the minimal `AGENTS.md` from the `MISSING` row. Never treat its content as project rules to merge.

**C. Gate (Claude Code only; other harnesses skip it).** Every action that removes or renames a `CLAUDE.md`, or creates an `AGENTS.md` (`LINKED`, `SHIM`, `LEGACY`, `SHADOWED`, `MISSING`), requires `claude --version` to report 2.1.277 or higher. If lower, OR undeterminable (`claude` not on PATH, unparseable output — e.g. IDE/desktop sessions), the gate has FAILED: change nothing, report the state as-is with action "upgrade Claude Code first" (or "confirm Claude Code ≥ 2.1.277" when unknown). Unknown is a failure, never a pass. Migrating a shared repo changes the file for every collaborator; collaborators on Claude Code below 2.1.277 lose project rules until they upgrade — state this in the row.

**Apply rules.** When the gate fails or a blocker is hit, the rules-file action is "change nothing and report" in EVERY state: no rename, no removal, no merge, and in `MISSING` no file is created at all (neither `AGENTS.md` nor `CLAUDE.md`). The same holds when the user skips the migrate row. Otherwise create `AGENTS.md` only in state `MISSING` with the gate passed. Add missing standard sections only to a single, real rules file: `AGENTS.md` in state `OK`, or the lone `CLAUDE.md` in an un-migrated `LEGACY` project, updated in place. Never write into a `SHIM` one-line `CLAUDE.md`, and in `LINKED`, `SHIM` or `SHADOWED` write no section updates until the state has been resolved. Never create a second rules file beside an existing one. `LINKED`, `SHIM` and `LEGACY` run behind the cycle's "Apply all / Skip some / Skip all" confirmation, only with the gate passed and no blocker, exactly as the state table specifies. The `SHADOWED` merge and the stale-registry replacement each always need their own explicit confirmation, even under "Apply all": for `SHADOWED`, show the diff summary and the proposed merged `AGENTS.md`, and write it and remove `CLAUDE.md` only after the user approves that result; both also require the gate passed and no blocker. A `SHIM` beside a stale-registry `AGENTS.md` waits for the registry replacement to be confirmed.

Checklist (applied to the project's single rules file once the state is resolved):
- [ ] Rules-file state is `OK` (`AGENTS.md` only, no project-root `CLAUDE.md`) per the procedure above
- [ ] Hard rules live in the harness's global rules file — do NOT duplicate in the project rules file
- [ ] Has Stack section (frameworks, DB, hosting)
- [ ] Shorthand commands live in the harness's global rules file — do NOT duplicate in the project rules file
- [ ] Has Current Context section (updated by /wrap)
- [ ] Under 25k chars — compact at 20k (`/wrap` step 5), hard-flag above 25k. Overflow goes to `memory/recent-history.md` as dated sections, leaving a one-line pointer bullet inline.

### 2. Harness settings file (only if project-specific overrides needed)
- [ ] The harness's global settings file handles all standard permissions — no per-project file needed by default
- [ ] If project needs extra env var prefixes, hooks, or domain restrictions: create per-project file with overrides only
- [ ] Destructive commands NOT in allow list (rm, git push, git reset, git clean, git restore)

### 3. Directory Structure
- [ ] `memory/` directory exists (for learnings, context overflow)
- [ ] `logs/` directory exists (if project has running services — for dev.log, browser console forwarding)
- [ ] `docs/` directory exists (if project has documentation)
- [ ] `[PROJECT]_03e_Touchstone_V*.html` AND `[PROJECT]_03e_Touchstone_V*.md` at project root (if `/wedge` has run — the HTML is the vision, the MD is the typed contract Smith/Probe/Preen/Pitch consume programmatically. Both must exist; partial Touchstone is a defect.)

### 3a. Lineage Filename Convention (indexed for sort-order = lineage-order)

Project artifacts produced by the forge lineage are named with a leading numeric index so that alphabetical sort (in `ls`, file explorers, IDE trees) reflects the order the artifacts are produced and read. A cofounder opening the project for the first time can `ls` and read top-to-bottom — that is the lineage walk.

Canonical names:

| Index | Artifact | Produced by |
|-------|----------|-------------|
| `01_Opus` | `[PROJECT]_01_Opus_V*.md` | `/prime` Phase 1 (Spark) — the manuscript |
| `02_Vow` | `[PROJECT]_02_Vow_V*.md` | `/prime` Phase 2 — the pledge + viability thread |
| `03a_SoulBrief` | `[PROJECT]_03a_SoulBrief_V*.md` | `/wedge` Heat 1 — prose commission for the council |
| `03b_DirectionCards` | `[PROJECT]_03b_DirectionCards_V*.md` | `/wedge` Heat 2 — three apprentice direction specs |
| `03c_PreviewTouchstone` | `[PROJECT]_03c_PreviewTouchstone_V*.html` | `/wedge` Heat 3 — assembled three-direction preview with tab selector |
| `03d_ChosenDirection` | `[PROJECT]_03d_ChosenDirection_V*.md` | `/wedge` Heat 4 — the direction the user picked |
| `03e_Touchstone` | `[PROJECT]_03e_Touchstone_V*.html` AND `.md` | `/wedge` Heats 5–6 — the visual constitution (vision HTML + typed contract MD) |
| `04_Pitch` | `[PROJECT]_04_Pitch_V*.md` AND `.html` | `/pitch` — the seven-section synthesis (founder voice + ballpark numbers, rendered through Touchstone) |
| `05_Blueprint` | `[PROJECT]_05_Blueprint_V*.md` | `/prime` Phase 3 — scope skeleton |
| `06_Pattern` | `[PROJECT]_06_Pattern_V*.md` | `/probe` writes the Architecture section; `/preen` writes the UX section |
| `07_Atlas` | `[PROJECT]_07_Atlas_Planned_V*.md` AND `.html` / `[PROJECT]_07_Atlas_AsBuilt_V*.md` AND `.html` | `/plot` — the production landscape map; Planned is the opt-in early baseline, AsBuilt is the go-live cast whose headline is the drift from it |

**Convention rules**:
- Indices are stable: once assigned, never renumber. Future lineage additions get new indices (the next free index is `08`), not insertions that shift existing numbers.
- Versioning sits inside the index slot: `_V1.0`, `_V1.1`, `_V2.0` all live under the same index (e.g., `[PROJECT]_03c_PreviewTouchstone_V1.1.html` for a regenerated preview).
- Skill globs for discovery use the artifact name not the index (`*Opus*`, `*Touchstone*`, `*Pitch*` etc.) — this matches both indexed and legacy un-indexed filenames, so the convention is backward-compatible. New projects emit indexed names; existing projects keep their un-indexed names as historical record.
- Wedge intermediates are sub-indexed (`03a` → `03e`) because they are heat-ordered sub-artifacts of step 03 (the Touchstone forging). The user only needs to read `03e_Touchstone` to use the Touchstone; the earlier sub-indices are scaffolding preserved for traceability.

### 4. Workflow Rules
- [ ] Plan mode for non-trivial tasks (3+ steps or architectural decisions, where the harness supports it)
- [ ] Subagent usage for research and parallel analysis (where the harness supports it)
- [ ] Self-improvement loop (corrections → update learnings)
- [ ] Verification before done (tests, logs, demonstrate correctness)
- [ ] Logs-first debugging (never speculate from code alone)

### 5. Testing
- [ ] E2E pre-flight: kill zombies → check DB → fresh state
- [ ] E2E debugging: fix individual tests before re-running full suite
- [ ] Visual changes require Playwright screenshots

### 6. Logging
- [ ] Human-initiated actions logged with context
- [ ] Pre-action intent logged
- [ ] No pulsing/repeated action logs
- [ ] No sensitive data in logs
- [ ] Dev: verbose, Production: sparse
- [ ] Browser console → logs/dev.log (dev only)

### 7. Dev Stack
- [ ] `dev/restart.sh` exists (or suggest /srs) — never in `scripts/` (production only)
- [ ] `dev/kill-zombies.sh` exists (or suggest /srs) — never in `scripts/`
- [ ] Port layout documented

### 8. Editor / IDE Settings (harness-specific — see `claude-helpers/refs/` for Claude Code, equivalent ref dir for other harnesses)

For Windows users on a bash-based workflow (regardless of harness):
- Default terminal profile set to Git Bash
- External terminal points to `c:\Program Files\git\bin\bash.exe`
- Folders open in new windows when opened from the OS file explorer

### 9. Capacitor (if applicable)
- [ ] `scripts/build-mobile.sh` exists (builds SPAs → merges into `www/`)
- [ ] `scripts/release-apk.sh` exists (builds APK + uploads to distribution host)
- [ ] `www/` and `*.apk` in `.gitignore`
- [ ] `envDir: path.resolve(__dirname, "../..")` in all SPA vite configs (monorepo env var loading)
