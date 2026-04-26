---
name: forge
description: The forge cycle — unified bidirectional sync between the forge repo and your membrane. Triages drift, presents a PLAN table, applies approved changes in both directions (incoming skills/learnings/memory, outgoing absorption), commits and pushes. `/forge --dry` for read-only inspection. `/forge on|off` toggles session skills. Replaces the retired /cast, /mark, /fold trio.
user-invocable: true
---
<!-- model: sonnet | escalation: learning triage → spawn opus subagent -->

# /forge — The Forge Cycle

> In the forge, we forge.

The single gate between your membrane (`~/.claude/`) and the forge repo. One command, three motions, one decision point.

The command absorbs what used to be three separate skills:

| Old | New (internal phase) | Meaning |
|-----|----------------------|---------|
| `/mark` | **mark** — inspect drift | Classify everything without acting |
| `/cast` | **cast** — apply incoming | Pour forge → membrane |
| `/fold` | **fold** — absorb outgoing | Layer membrane → forge |

You no longer summon these individually. `/forge` runs them in order and presents a single PLAN table where you decide, per row, what flows and in which direction.

## HARD RULE — /forge is the ONLY gate
> No project, no skill, no manual edit moves knowledge between forge and membrane outside this command.
> Direct edits to forge repo files are only for skill development (editing `SKILL.md` files in `skills/`).

## HARD RULE — Protected skills are never absorbed outgoing
> `forge` and `purge` can never be absorbed from membrane → forge within this command.
> Absorbing `/forge` mid-execution would silently overwrite the rules currently running.
> Absorbing `/purge` could break the next cleanse. Both are excluded at PLAN table level.
> If either appears as `DEPLOYED-DIFFERS`, it is shown in the ⚠ CONFLICTS section with note "protected — reconcile manually." User may choose `[↓] accept forge` to overwrite local, but `[↑] keep membrane` is disabled.

## Arguments

First argument is inspected as a reserved keyword:

| Form | Meaning |
|------|---------|
| `/forge` | Run the cycle against the current working directory |
| `/forge <path>` | Run the cycle against a specified project path |
| `/forge --dry` | Read-only inspection (replaces old `/mark`). No writes, no commits, no pushes. |
| `/forge --dry <path>` | Inspection-only against specified path |
| `/forge on` | Session toggle — enable all forge skills and art auto-invocation |
| `/forge off` | Session toggle — disable all forge skills except `/forge` and `/purge` |

If `$ARGUMENTS` is literally `on` or `off`, handle as session toggle (see [Session Toggle](#session-toggle) below) and exit. Otherwise proceed with the cycle.

## Session Toggle

When `$ARGUMENTS` is `on` or `off`, do NOT run the cycle. The toggle is session-scoped (each CLI / VS Code instance is independent, no files written).

### `on`
Output exactly:
> **FORGE ENABLED** — all forge skills and art auto-invocation are active for this session.

### `off`
Output exactly:
> **FORGE DISABLED** — all forge skills are suspended for this session. Only `/forge` and `/purge` remain active. To re-enable: `/forge on`

When forge is disabled and the user invokes a disabled skill (e.g., `/poke`, `/wawa`), respond:
> Forge is disabled for this session. Run `/forge on` to re-enable.

Do not use `AskUserQuestion` for toggle output — it is immediate.

---

## Cycle Flow

Below is the flow for `/forge`, `/forge <path>`, `/forge --dry`, `/forge --dry <path>`.

## Phase 0: Preflight

0. **Token preflight** (workaround for OAuth race — `/forge` spawns subagents in 3f. See [WORKAROUNDS.md](../../WORKAROUNDS.md) WA-001):
   ```bash
   bash <forge>/scripts/agent-preflight.sh $$
   ```

> Execute [Forge Preflight](preflight.md) in **pull** mode (or **fetch** mode if `--dry`).

Run `<forge>/scripts/forge-status.sh --pull` (or `--fetch` for `--dry`).

This resolves the forge path, syncs the remote (pull in active mode, fetch in dry mode), and produces the full drift report: Skill Drift, Learning Details, Memory Status, Classification Checks.

**Forge path management**: If the resolved forge path differs from the `forge-path:` line in `~/.claude/CLAUDE.md` (or the line doesn't exist), update/add it. `/forge` owns `forge-path:` management. (Skip this write in `--dry` mode.)

## Phase 1: Mark — Build the PLAN Table

### 1a. Workaround status banner (always shown)

Run `bash <forge>/scripts/forge-workarounds-check.sh` before rendering the PLAN table. It emits one status line per active workaround listed in `<forge>/WORKAROUNDS.md`. The actual GitHub API check is time-gated to once per 7 days per workaround; cached status is used otherwise.

Print the output verbatim as a banner above the PLAN table. It always appears — healthy or alerting — so the workaround state stays visible on every cycle.

If any line contains "READY FOR REMOVAL", surface it prominently (the script formats those lines to stand out) and remind the user: "Workaround can be retired — see `WORKAROUNDS.md` removal procedure."

If the script has no output (no WORKAROUNDS.md or empty file), print nothing.

### 1b. Workaround side-effect sync (rows in INCOMING section)

Run `bash <forge>/scripts/sync-workaround-side-effects.sh`. It parses each WA's `Side effects` block in `WORKAROUNDS.md` and emits one line per declared artifact:

```
ACTION  TYPE     WA-ID   SOURCE                                  TARGET                                          PLATFORM
INSTALL script   WA-001  /forge/scripts/agent-token-warmup.sh    /home/user/.claude/scripts/agent-token-warmup.sh -
UPDATE  script   WA-001  /forge/scripts/agent-token-scheduler.sh /home/user/.claude/scripts/agent-token-scheduler.sh -
INSTALL hook     WA-001  -                                       $HOME/.claude/scripts/user-agent-preflight.sh   WSL2
OK      script   WA-001  ...                                     ...                                              -
SKIP    hook     WA-001  -                                       ...                                              WSL2 (not on WSL2)
```

Add INSTALL / UPDATE rows (anything not `OK` or `SKIP`) to the **INCOMING** section of the PLAN table as `side-effect` typed rows:

```
  [ ] 7  side-effect  WA-001 script: agent-token-warmup.sh    INSTALL
         → Refresh action with flock; called by both Layer 1 and Layer 2 schedulers
  [ ] 8  side-effect  WA-001 hook: SessionStart → user-agent-preflight.sh  INSTALL
         → Layer 2 OAuth race protection (WSL2 only)
```

**Platform gate**: lines tagged `SKIP ... (not on WSL2)` are not surfaced as rows on non-WSL2 machines. Keeps Mac/Linux-native users' PLAN tables clean.

### 1c. PLAN table

From the preflight output, build a single triage table with three sections. Each row shows **the essence of what will change** — not the filename, but the rule, principle, or knowledge that will land.

```
forge @ <sha> ⇄ membrane @ <last-cast-sha>                     N items

↓ INCOMING (forge → you) — X items
  [ ] 1  skill      /poke                 FORGE-UPDATED
         → Added band-aid detection to Step 3
  [ ] 2  learning   Tailwind v4 class scanning  (cygnum)
         → @source directive required for pnpm workspace symlinks
  [ ] 3  memory     deploy-practices.md   NEW
         → Gate deploy scripts behind env checks

↑ OUTGOING (you → forge) — Y items
  [ ] 4  config     claude-code-rules.md  DRIFT
         → Adding WebFetch domain: better-auth.com
  [ ] 5  learning   Prisma enum migration gotcha  (cygnum)
         → enum ALTER requires USING cast clause on Postgres

⚠ CONFLICTS (both changed) — Z items
  [ ] 6  skill      /press                CONFLICT
         → forge: added ops checklist  |  membrane: added obs section

  [a]ll  [N] toggle  [v N] view  [ENTER] apply  [q]uit
```

### Direction routing

Use `forge-status.sh` classifications:

| Classification | Section |
|----------------|---------|
| `FORGE-UPDATED` / `ADDED` (forge-side) | ↓ INCOMING |
| `DEPLOYED-DIFFERS` / `REMOVED` (membrane-side) | ↑ OUTGOING |
| `CONFLICT` / `CONFLICT (no-baseline)` | ⚠ CONFLICTS |

### Row content rules

Every change row must include a sub-row showing the **essence** of the change:

- **Skill row** → the specific rule, step, or behaviour that changed (not the commit message)
- **Learning row** → the `**Learning**:` body + `**Apply when**:` line
- **Memory row** → the key principle or convention the file encodes
- **Config row** → the specific rule or setting being merged

Use contributor names from `git blame` on forge files, or the Change Details section of `forge-status.sh` output for skills (format: `hash message (Author Name)`). Never assume a default contributor.

### Empty sections

Hide any section that has zero rows. Don't print an empty `↓ INCOMING` header.

### Empty state

If all three sections are empty: print a single line — `✓ Membrane synced.` — and exit. No table, no DONE report.

### Selection UX

- Defaults to all-unchecked. Opt-in by design — nothing mutates without an explicit selection.
- `[a]` toggles ALL items.
- `[N]` toggles item N. For regular rows: two states (`[ ]` / `[x]`). For conflict rows: three states cycling (`[ ]` skip → `[↓]` accept forge → `[↑]` keep membrane → `[ ]`).
- `[v N]` shows the full diff / learning body for N.
- `[ENTER]` applies selected.
- `[q]` quits. If any rows are toggled, soft-confirm: "discard selections? [y/N]".

Present the rendered table as console text, then use `AskUserQuestion` for the final apply decision with options: "Apply selected" / "Adjust" / "Cancel".

In `--dry` mode: skip the selection prompt. Print the table and exit.

## Phase 2: Cast — Apply Incoming (forge → membrane)

Skip this phase entirely if `--dry`. Run BEFORE outgoing absorption so the latest ruleset is in place when the absorption logic runs.

For each approved incoming row (and each conflict row where user chose `[↓]`):

### Skills
- Run `bash <forge>/scripts/cast-deploy.sh skill1 skill2 ...` for approved `FORGE-UPDATED` / `ADDED`
- Run `rm -rf ~/.claude/skills/<name>/` for approved `REMOVED`
- Verify: `bash <forge>/scripts/cast-deploy.sh --verify`
- **Never use `cp -r` directly.** Always go through `cast-deploy.sh`.

Fresh machine (no deployed skills): create `~/.claude/learnings/`, `~/.claude/memory/`, then deploy ALL with `cast-deploy.sh --all`.

### Learnings
For each approved learning row: copy/patch `<forge>/learnings/<file>.md` entry into `~/.claude/learnings/<file>.md`.

### Memory
For each approved memory row: copy `<forge>/memory/<file>.md` into `~/.claude/memory/<file>.md`.

### Workaround side-effects
For each approved `side-effect` row from Phase 1b:

- **script INSTALL or UPDATE**: copy the source script to the target (use `cast-deploy.sh --scripts` for whole-manifest deploys, or per-file `cp` + `chmod +x` for one-offs).
- **hook INSTALL**: invoke `bash <forge>/scripts/install-token-hook.sh` (idempotent, flocks `~/.claude/.settings.lock`).
- **script REMOVE** (workaround retirement): `rm -f <target>`.
- **hook REMOVE** (workaround retirement): `bash <forge>/scripts/install-token-hook.sh --uninstall`.

After applying, verify: `bash <forge>/scripts/cast-deploy.sh --verify-scripts`.

### Record baseline
After all incoming is applied (before starting outgoing), write `~/.claude/.last-cast.json`:
```json
{ "lastCastCommit": "<git -C <forge> rev-parse HEAD>" }
```

> **Crash recovery**: If the session ends before this write completes, the next `/forge` run sees all differing skills as `CONFLICT (no-baseline)`. Fix: re-run `/forge`, choose `[↓] accept forge` on all items to re-establish the baseline.

## Phase 3: Fold — Absorb Outgoing (membrane → forge)

Skip this phase entirely if `--dry` or if no outgoing / `[↑]` conflict rows were approved.

### 3a: Config sync (claude-code-rules.md)

For approved config rows: merge selected changes into `<forge>/skills/forge/claude-code-rules.md`. Sync rules:
- CLAUDE.md ↔ reference auto-allowed table
- WebFetch domains must match exactly
- Destructive commands NEVER in allow list
- Hooks, `additionalDirectories`, `forge-path` are machine-specific — never sync

### 3b: Skill reverse-sync

For approved `DEPLOYED-DIFFERS` rows (and conflict rows where user chose `[↑]`): diff deployed vs forge, apply membrane version to forge.

Protected skills (`forge`, `purge`) are already excluded at PLAN table level — no need to re-guard here.

### 3c: Review & prune existing forge knowledge (triggers only)

| Trigger | What fires |
|---------|-----------|
| Any `<forge>/learnings/*.md` > 50 entries | Learning review |
| `<forge>/memory/` has > 20 files | Memory review |

Run `<forge>/scripts/fold-evidence.sh` to collect evidence. Classify each entry: **CURRENT** / **STALE** / **MERGED** / **EVOLVED** / **PROMOTED**. Present review sub-table, apply after user confirms.

If no triggers fire, skip entirely.

### 3d: Promote Forge-worthy learnings from project memories

Scan `~/.claude/projects/*/memory/*-learnings.md` for entries tagged `Forge-worthy: yes`. For each:
1. Skip if title already in `<forge>/learnings/.fold-tracker.json` `promotedEntries` or in `~/.claude/learnings/general.md`
2. Genericize (strip project names, paths, domains — see "No Project Names" rule below)
3. Append to `~/.claude/learnings/general.md` with `<!-- promoted from project memory, YYYY-MM-DD -->` comment
4. Add title to tracker `promotedEntries`

Skip silently if no Forge-worthy entries exist.

### 3e: Learning absorption

For approved outgoing learning rows:

**Genericize first**, then write to forge. Genericize means strip all project names, contributor names, currency/prices, project schema/field names, competitor names, and region-specific framing — keep the universal principle. Attribution lives in the PLAN/DONE table only, never in the learning body (`Forge-worthy: yes` is a flag, not a citation slot). Write to `<forge>/learnings/<file>.md`, NEVER to `~/.claude/learnings/` — that's the deployed copy; writing there silently skips forge and the tracker marks the entries processed so no future fold can heal the gap. The next purity-check step (3e) is the mechanical gate that enforces all of this — if the script blocks, fix the content; do not bypass.

#### Purity gate (mandatory before each absorbed learning is written)

After staging absorbed entries (and BEFORE finalizing them), run:
```bash
git -C <forge> add learnings/<file>.md
bash <forge>/scripts/fold-purity-check.sh --staged
```

If the script exits non-zero, it lists the violations. Fix every one:
- Re-genericize the flagged content
- Add legitimate universal terms to the script's `ALLOWLIST_TERMS` if a flagged term is genuinely a well-known reference (e.g., a major framework, a standard API)

Re-run until exit 0. **Do not unstage and commit anyway.** The script is the gate; bypassing it re-creates exactly the leak that prompted its existence (see `learnings/global-patterns.md` Exhibit A: "How a Project-Name Leak Happens, 2026-04-25").

Target files in `<forge>/learnings/`:
- `probe-learnings.md` — architecture
- `press-learnings.md` — go-live readiness
- `poke-learnings.md` — tech debt / logging
- `prime-learnings.md` — ideation / blueprint
- `praise-learnings.md` — feedback routing
- `global-patterns.md` — cross-cutting

Format: `## [Title] (YYYY-MM-DD)` + `**Learning**:` + `**Apply when**:`

Source entries in `~/.claude/learnings/` are NEVER deleted.

**Tracker**: maintain `<forge>/learnings/.fold-tracker.json` with `lastRun`, `processedEntries`, `promotedEntries`. Append title on each absorb.

> **HARD RULE — Tracker is APPEND-ONLY.** Never remove entries. Tracker lives in forge repo (shared across users). Each user has their own membrane. Removing a tracker entry based on one user's state causes every other user's forge cycle to re-absorb that entry — creating duplicates across the team. Residue entries (tracked but no matching forge file) are harmless — the fold phase just skips them. A tracker with 1000 entries is ~10KB. Let it grow.

> **One-time migration**: if `<forge>/learnings/.reforge-tracker.json` exists, copy its `processedEntries` and `promotedEntries` into `.fold-tracker.json` before proceeding, then delete `.reforge-tracker.json`.

### 3f: Skill presentation refresh

Runs after 3e if at least one skill learning file was modified. For each modified `<forge>/learnings/<art>-learnings.md` → corresponding `<forge>/skills/<art>/SKILL.md`:

Skills describe themselves in two places: the `description:` frontmatter and the `TRIGGER when:` line. As learnings accumulate, these can drift — a skill that has learned to handle edge cases it didn't originally anticipate, or that now covers more triggers than it declared.

Launch one subagent per skill (in parallel):

```
You are reviewing whether the description and trigger conditions for /<skill>
still accurately reflect what the skill does, given its latest learnings.

CURRENT DESCRIPTION: [paste description: field]
CURRENT TRIGGER: [paste TRIGGER when: line]
NEW LEARNINGS: [paste entries absorbed in 3e]

Answer ONLY:
1. Description update? (one line, <200 chars, no quotes, or "NO CHANGE")
2. TRIGGER update? (<150 chars, or "NO CHANGE")
3. If no changes needed, say "NO CHANGE" for both.

Rules:
- Never expand descriptions to cover unrelated capabilities
- Never remove existing trigger conditions — only add or refine
- Only propose a change if new learnings genuinely expand or clarify scope
```

**Protected skills — skip unconditionally**: `forge`, `purge`.

Add presentation changes as rows in the DONE report. If no changes needed: omit presentation rows (no noise).

For each approved change:
1. Update `description:` in `<forge>/skills/<skill>/SKILL.md`
2. Update `TRIGGER when:` line (if changed)
3. Also update deployed copy at `~/.claude/skills/<skill>/SKILL.md` — presentation takes effect immediately

> **HARD RULE**: Only update `description:` frontmatter and `TRIGGER when:` lines. Never rewrite skill logic, process steps, or examples. Presentation only.

### 3g: Memory absorption

For approved outgoing memory rows. Classify each:

| Status | Meaning |
|--------|---------|
| **TEAM-WORTHY** | Absorb into `<forge>/memory/` (strip personal details) |
| **PERSONAL** | Skip, add to `skippedFiles` |
| **DUPLICATE** | Skip, add to `skippedFiles` |
| **UPDATE** | Merge newer content into existing forge file |

Classification rules:
- `type: user` → always PERSONAL
- `type: feedback` → team-worthy if about code/process
- `type: team-*` → always team-worthy

Tracker: `<forge>/memory/.memory-tracker.json` with `lastRun` and `skippedFiles`. Append-only.

Source entries in `~/.claude/memory/` are NEVER deleted.

### 3h: Staging archival (triggers only)

| Trigger | What fires |
|---------|-----------|
| `~/.claude/learnings/general.md` > 100 entries | Learning archival |
| `~/.claude/memory/` > 30 files | Memory archival |

**Learning archival**: cross-reference entries against tracker `processedEntries` AND forge learning files. Entries that are BOTH processed AND present in forge → offer to move to `~/.claude/learnings/archive/general.md`.

**Memory archival**: files identical in both membrane and forge → offer to move to `~/.claude/memory/archive/`.

Never delete — archival is a move.

> **Note**: Archiving entries from `general.md` does NOT allow tracker compaction. The tracker is shared across all forge users. The tracker is truly append-only.

### 3i: Commit & push forge

1. **Conflict check**: `git -C <forge> diff --name-only --diff-filter=U`. If unresolved conflicts, STOP.
2. **Stage** specific files with `git add <file>` (never `git add -A`).
3. **Final purity gate** (catches anything 3e missed and any new content added in 3f/3g):
   ```bash
   bash <forge>/scripts/fold-purity-check.sh --staged
   ```
   If non-zero, do NOT proceed. Unstage offending content, re-genericize, restage, re-run until clean. This is a HARD gate.
4. **Commit message purity check** — before invoking `git commit`, run:
   ```bash
   bash <forge>/scripts/fold-purity-check.sh --commit-msg "<message>"
   ```
   Commit messages have leaked project names and contributor names in the past. The check catches `Absorb 7 learnings from <Person> (<Project> session, ...)` patterns and similar. If non-zero, rewrite the message until clean.
5. **Update context** in `<forge>/CLAUDE.md` Current Context section.
6. **Compact check**: if CLAUDE.md > ~20k chars, overflow to `memory/`.
7. **Commit**: descriptive message (what was absorbed, no project names, no contributor names). **No `Co-Authored-By: Claude` lines.**
8. **Push decision**: `AskUserQuestion` — options: "Push to origin" / "Keep local".

## Phase 4: Project Scan & Divergence

Always runs (even for subsequent cycles) against the target project. Skips only when the target IS the forge repo itself.

### 4a: Read forge reference (parallel)

- `<forge>/skills/forge/claude-code-rules.md` — workflow rules
- `<forge>/skills/forge/stack-guide.md` — tech stack reference
- `<forge>/skills/forge/forge-conventions.md` — distilled conventions checklist

### 4b: Scan project (parallel)

- Read `CLAUDE.md` (if exists)
- Read `.claude/settings.json` (if exists)
- Glob for `package.json`, `tsconfig*`, `pnpm-workspace.yaml`, `packages/`
- Check for `memory/`, `docs/`, `dev/restart.sh`, `dev/kill-zombies.sh`

### 4c: Divergence Report

```markdown
## Divergence Report — [PROJECT NAME]

| Aspect | Forge Convention | Current Project | Action |
|--------|-----------------|-----------------|--------|
| CLAUDE.md | Required with standard sections | [exists/missing] | [create/update] |
| Hard rules | Live in global `~/.claude/CLAUDE.md` — do NOT duplicate | [global/missing] | Skip if global membrane exists |
| .claude/settings.json | Only if project-specific overrides needed | [exists/missing/not needed] | [skip/create] |
| memory/ directory | Required | [exists/missing] | [create] |
| logs/ directory | Required (app projects with services only) | [exists/missing/N/A] | [create/skip] |
| Shorthand commands | Live in global `~/.claude/CLAUDE.md` — do NOT duplicate | [global/duplicated] | Skip if global membrane exists; remove from project if duplicated |
| dev/restart.sh | Recommended (run /srs) | [exists/missing] | [suggest /srs] |
| dev/kill-zombies.sh | Recommended | [exists/missing] | [suggest /srs] |
| Documentation | `docs/` in-repo OR `## Documentation` section with `**Docs path:**` | [in-repo/external/missing] | [add section] |
| Logging setup | dev.log + browser forwarding | [present/missing] | [flag for /poke] |
```

Present as console markdown, then `AskUserQuestion`: "Apply all / Skip some / Skip all".

### 4d: Apply (after confirmation)

**CLAUDE.md** (create or update) — standard sections. Hard rules and shorthand commands live in the global `~/.claude/CLAUDE.md` — do NOT duplicate. If the project already has a `## Shorthand Commands` section, remove it during this forge cycle.

```markdown
# [Project Name] — Project Rules

## Stack
[from project's package.json and tsconfig]

## Documentation
<!-- One of: `Docs are in the docs/ directory.` OR `**Docs path:** /absolute/path` -->

## Current Context
[branch, recent work, test status — filled by /wrap]
```

**.claude/settings.json** — only if project-specific overrides needed. Global handles standard permissions.

**Directories** — create `memory/` if missing. Create `logs/` if missing (projects with running services only).

## Phase 5: DONE Report

Single unified receipt. Only include changed rows.

Every changed row must include a sub-row showing the **essence** of the change — not the filename or commit title, but the rule / principle / knowledge that now lives in its new home. A reader who never saw the PLAN table must understand *what shifted* from this report alone.

```markdown
## Forge Cycle — /forge | YYYY-MM-DD | DONE

| What | Direction | Result | Contributor |
|------|-----------|--------|-------------|
| `/poke` skill | ↓ in  | updated | — |
|   → Added band-aid detection to Step 3 | | | |
| Tailwind v4 class scanning | ↓ in  | synced → global-patterns.md | cygnum |
|   → Learning: @source directive required for pnpm workspace symlinks. | | | |
|   → Apply when: Tailwind v4 + pnpm monorepo + shared UI package | | | |
| claude-code-rules.md | ↑ out | merged | — |
|   → Added WebFetch domain: better-auth.com | | | |
| Prisma enum migration gotcha | ↑ out | absorbed → poke-learnings.md | cygnum |
|   → Learning: enum ALTER requires USING cast clause on Postgres. | | | |
|   → Apply when: adding value to existing enum column | | | |

Baseline: abc1234
Commit:   def5678 — pushed to origin/main
```

**Result vocabulary** (past tense): `updated`, `created`, `synced`, `absorbed`, `merged`, `reconciled`, `skipped (reason)`, `description updated`, `trigger updated`.

If nothing changed in the cycle: `✓ Membrane synced.` and skip the report.

After the DONE report (and only when the target is a project, not the forge repo itself), output:
> **FORGE ENABLED** — all forge skills and art auto-invocation are active for this session.

Do NOT commit the project's own changes. Use `AskUserQuestion` to prompt: "Ready to wrap up?" with options "Yes, run /wrap" / "Not yet".

## No Project Names Rule

This rule governs every write to forge during the fold phase:

> Forge is a shared repo. NEVER include project-specific details in learnings, memory, commit messages, or any absorbed content.
> Strip all project names, specific file paths, domains, and business logic before writing.
> Learnings must read as universal principles. Commit messages must describe *what* was absorbed, not *where* it came from.

When in doubt, genericize. When a finding is too project-specific to genericize, don't absorb it.
