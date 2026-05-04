# Forge Conventions Checklist

> Distilled from `skills/forge/claude-code-rules.md`. Used by `/forge` to verify project compliance.

## Required in Every Project

### 1. CLAUDE.md at Project Root
- [ ] Exists
- [ ] Hard rules live in global `~/.claude/CLAUDE.md` — do NOT duplicate in project CLAUDE.md
- [ ] Has Stack section (frameworks, DB, hosting)
- [ ] Shorthand commands live in global `~/.claude/CLAUDE.md` — do NOT duplicate in project CLAUDE.md
- [ ] Has Current Context section (updated by /wrap)
- [ ] Under 20k chars (compacted by /wrap)

### 2. .claude/settings.json (only if project-specific overrides needed)
- [ ] Global `~/.claude/settings.json` handles all standard permissions — no per-project file needed by default
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

**Convention rules**:
- Indices are stable: once assigned, never renumber. Future lineage additions get new indices (e.g., a hypothetical post-Pattern artifact would be `07_X`), not insertions that shift existing numbers.
- Versioning sits inside the index slot: `_V1.0`, `_V1.1`, `_V2.0` all live under the same index (e.g., `[PROJECT]_03c_PreviewTouchstone_V1.1.html` for a regenerated preview).
- Skill globs for discovery use the artifact name not the index (`*Opus*`, `*Touchstone*`, `*Pitch*` etc.) — this matches both indexed and legacy un-indexed filenames, so the convention is backward-compatible. New projects emit indexed names; existing projects keep their un-indexed names as historical record.
- Wedge intermediates are sub-indexed (`03a` → `03e`) because they are heat-ordered sub-artifacts of step 03 (the Touchstone forging). The user only needs to read `03e_Touchstone` to use the Touchstone; the earlier sub-indices are scaffolding preserved for traceability.

### 4. Workflow Rules
- [ ] Plan mode for non-trivial tasks (3+ steps or architectural decisions)
- [ ] Subagent usage for research and parallel analysis
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

### 8. VS Code Settings (global — `%APPDATA%/Code/User/settings.json`)
- [ ] `terminal.integrated.defaultProfile.windows`: `"Git Bash"`
- [ ] `terminal.external.windowsExec`: `"c:\\Program Files\\git\\bin\\bash.exe"`
- [ ] `window.openFoldersInNewWindow`: `"on"`

### 9. Capacitor (if applicable)
- [ ] `scripts/build-mobile.sh` exists (builds SPAs → merges into `www/`)
- [ ] `scripts/release-apk.sh` exists (builds APK + uploads to distribution host)
- [ ] `www/` and `*.apk` in `.gitignore`
- [ ] `envDir: path.resolve(__dirname, "../..")` in all SPA vite configs (monorepo env var loading)
