---
name: forge
description: The forge cycle — unified bidirectional sync between the forge repo and your membrane. Triages drift, presents a PLAN table, applies approved changes in both directions (incoming skills/learnings/memory, outgoing absorption), commits and pushes. `/forge --dry` for read-only inspection. `/forge on|off` toggles session skills. Replaces the retired /cast, /mark, /fold trio.
user-invocable: true
---
<!-- model: inherit | fan-out: 3c knowledge review → opus; 3f presentation refresh → sonnet | Phase 1 PLAN-table mechanics are script tier (forge-plan.sh) -->

# /forge — The Forge Cycle

> In the forge, we forge.

The single gate between your membrane (the harness's per-tool config directory — e.g., `~/.claude/` for Claude Code, `~/.bob/` for Bob, `~/.cursor/` for Cursor — referenced below as `<membrane>`) and the forge repo. One command, three motions, one decision point.

The command absorbs what used to be three separate skills:

| Old | New (internal phase) | Meaning |
|-----|----------------------|---------|
| `/mark` | **mark** — inspect drift | Classify everything without acting |
| `/cast` | **cast** — apply incoming | Pour forge → membrane |
| `/fold` | **fold** — absorb outgoing | Layer membrane → forge |

You no longer summon these individually. `/forge` runs them in order and presents a single PLAN table where you decide, per row, what flows and in which direction.

## HARD RULE — /forge is the ONLY gate
> No project, no skill, no manual edit moves knowledge between forge and membrane outside this command.
> Direct edits to forge repo files are only for skill development (editing source files in `core/skills/`).

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

**Invocable from any cwd.** `/forge` resolves the forge repo itself (Phase 0, the `forge-path:` line), so never tell a user to `cd` into the forge repo first. The "Only /forge Writes to Forge" rule restricts direct file edits from a project context, not invoking `/forge`, which is the sanctioned channel. `/purge` is the only skill bound to the forge repo's cwd.

If `$ARGUMENTS` is literally `on` or `off`, handle as session toggle (see [Session Toggle](#session-toggle) below) and exit. Otherwise proceed with the cycle.

## Session Toggle

When `$ARGUMENTS` is `on` or `off`, do NOT run the cycle. The toggle is session-scoped (each CLI / IDE instance is independent, no files written).

### `on`
Output exactly:
> **FORGE ENABLED** — all forge skills and art auto-invocation are active for this session.

### `off`
Output exactly:
> **FORGE DISABLED** — all forge skills are suspended for this session. Only `/forge` and `/purge` remain active. To re-enable: `/forge on`

When forge is disabled and the user invokes a disabled skill (e.g., `/poke`, `/wawa`), respond:
> Forge is disabled for this session. Run `/forge on` to re-enable.

The toggle output is immediate — do not wrap it in a multi-choice prompt.

---

## Cycle Flow

Below is the flow for `/forge`, `/forge <path>`, `/forge --dry`, `/forge --dry <path>`.

## Phase 0: Preflight

> Execute [Forge Preflight](preflight.md) in **pull** mode (or **fetch** mode if `--dry`).

Run `<forge>/core/scripts/forge-status.sh --pull` (or `--fetch` for `--dry`).

This resolves the forge path, syncs the remote (pull in active mode, fetch in dry mode), and produces the full drift report: Skill Drift, Learning Details, Memory Status, Classification Checks.

**Forge path management**: If the resolved forge path differs from the `forge-path:` line in the harness's global rules file (e.g., `~/.claude/CLAUDE.md` for Claude Code, `~/.bob/rules/00-forge.md` or AGENTS.md for Bob), update/add it. `/forge` owns `forge-path:` management. (Skip this write in `--dry` mode.)

## Phase 1: Mark — Build the PLAN Table

### Build the skeleton (script tier)

Run `bash <forge>/core/scripts/forge-plan.sh --pull` (or `--fetch` for `--dry`) — or, to avoid re-running the sync Phase 0 already did, pipe Phase 0's own `forge-status.sh` output into it instead: `bash <forge>/core/scripts/forge-status.sh --pull | bash <forge>/core/scripts/forge-plan.sh --stdin`.

This mechanically parses the Skill Drift Report, Learning Status, and Memory Status sections of the preflight output and emits the PLAN-table SKELETON: every non-`IDENTICAL` / non-in-sync item, pre-routed into ↓ INCOMING / ↑ OUTGOING / ⚠ CONFLICTS per the Direction routing rules below, numbered, with classification and item name filled in. Protected-skill exclusion (`forge`, `purge` never land as a plain outgoing row) is enforced mechanically inside the script — it forces them into ⚠ CONFLICTS with a "protected" note, same as the HARD RULE at the top of this doc requires.

The script does NOT fill judgment: essence lines it can't derive mechanically (a conflict's membrane-side description, a general.md entry's learning body, an unattributed contributor, …) are left as `_model fills_` placeholders. It also emits no config rows — `forge-status.sh` has no config-drift classification yet, so config rows are still built by hand per the Row content rules below.

### Model review (required every run)

Before presenting the skeleton to the user:
1. Replace every `_model fills_` placeholder — read the source file/diff it points at and write the real essence (the rule/principle that changed, not the commit message).
2. Add config rows by hand (see Row content rules) — the script can't see these yet.
3. Sanity-check the mechanical routing against the Direction routing table — the script should never get this wrong, but treat it as a second pair of eyes, not a rubber stamp.
4. Render the finished table exactly as the skeleton formats it (rows/sections/numbering already match the target format below) and proceed to the Selection UX.

If `forge-plan.sh` is unavailable (harness lacks bash, script missing, or its output looks wrong), fall back to building the table by hand using the rules in this section — they're the same rules the script encodes, just applied manually.

### PLAN table format (target — script skeleton already matches this)

Each row shows **the essence of what will change** — not the filename, but the rule, principle, or knowledge that will land.

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
  [ ] 4  config     <harness-rules-file>  DRIFT
         → Adding WebFetch domain: better-auth.com
  [ ] 5  learning   Prisma enum migration gotcha  (cygnum)
         → enum ALTER requires USING cast clause on Postgres

⚠ CONFLICTS (both changed) — Z items
  [ ] 6  skill      /press                CONFLICT
         → forge: added ops checklist  |  membrane: added obs section

  [a]ll  [N] toggle  [v N] view  [ENTER] apply  [q]uit
```

### Direction routing (fallback — forge-plan.sh applies this mechanically)

Use `forge-status.sh` classifications:

| Classification | Section |
|----------------|---------|
| `FORGE-UPDATED` / `ADDED` (forge-side) / `RETIRED` (memory file removed from forge) | ↓ INCOMING |
| `DEPLOYED-DIFFERS` / `REMOVED` (membrane-side) | ↑ OUTGOING |
| `CONFLICT` / `CONFLICT (no-baseline)` | ⚠ CONFLICTS |

### Row content rules (fallback — forge-plan.sh does the mechanical part; model review still applies the essence/attribution judgment either way)

Every change row must include a sub-row showing the **essence** of the change:

- **Skill row** → the specific rule, step, or behaviour that changed (not the commit message)
- **Learning row** → the `**Learning**:` body + `**Apply when**:` line
- **Memory row** → the key principle or convention the file encodes
- **Config row** → the specific rule or setting being merged (always manual — not covered by forge-plan.sh)

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

Present the rendered table as console text, then ask the user — using your harness's multi-choice prompt if available, otherwise inline — for the final apply decision with options: "Apply selected" / "Adjust" / "Cancel".

In `--dry` mode: skip the selection prompt. Print the table and exit.

## Phase 2: Cast — Apply Incoming (forge → membrane)

Skip this phase entirely if `--dry`. Run BEFORE outgoing absorption so the latest ruleset is in place when the absorption logic runs.

> **Transient — WA-001 retirement cleanup.** Before applying rows, run
> `bash <forge>/claude-helpers/retire-wa001.sh`. It removes the retired
> WA-001 OAuth-workaround artifacts (deployed token scripts + SessionStart hook)
> from this membrane. Idempotent and silent once clean. **Remove this step and
> the script once the team has migrated** — see AGENTS.md Outstanding.

For each approved incoming row (and each conflict row where user chose `[↓]`):

### Skills
- Run `bash <forge>/core/scripts/cast-deploy.sh skill1 skill2 ...` for approved `FORGE-UPDATED` / `ADDED`
- Run `rm -rf <membrane>/skills/<name>/` for approved `REMOVED`
- Verify: `bash <forge>/core/scripts/cast-deploy.sh --verify`
- **Never use `cp -r` directly.** Always go through `cast-deploy.sh`.

Fresh machine (no deployed skills): create `<membrane>/learnings/`, `<membrane>/memory/`, then deploy ALL with `cast-deploy.sh --all`.

### Global rules

Always run `bash <forge>/core/scripts/cast-deploy.sh --rules` (every cast, no PLAN row needed). This regenerates the forge-owned HARD RULES block (from `<forge>/core/rules/`) in the membrane global rules file, between `FORGE-RULES` markers — same forge-owned contract as the `forge-path:` line. Personal content outside the markers is never touched. This is how a HARD RULE authored in `core/rules/` reaches every teammate's membrane on their next `/forge`. Verify with `cast-deploy.sh --verify-rules`.

### Hooks

Always run `bash <forge>/core/scripts/cast-deploy.sh --hooks` (every cast, no PLAN row needed). This installs the hook bodies from `<forge>/core/hooks/` into `<membrane>/hooks/` **and wires them** into the membrane's `settings.json`, via an idempotent `jq` merge scoped to forge's own two entries — every other key, including hand-written hooks, is re-emitted verbatim. Verify with `cast-deploy.sh --verify-hooks`, which now fails on `UNWIRED` or `STALE-MATCHER` as well as body drift.

> The earlier rule — *settings wiring is per-user and is NEVER auto-edited by forge* — was **retired 2026-08-30**. It assumed a single-user membrane whose owner would act on a printed `not wired` nudge; on a shared box it became N manual steps nobody performed, and an audit found every human membrane carrying hook bodies with no registration at all. Bodies without nerves are worse than neither: the membrane reads as enforced and enforces nothing. See `<forge>/core/hooks/README.md`.

### Settings defaults

Always run `bash <forge>/core/scripts/cast-deploy.sh --settings` (every cast, no PLAN row needed). This applies forge-managed settings defaults to the membrane's `settings.json` with SET-IF-ABSENT semantics: if the key already exists (user's own choice), it is left untouched; otherwise the forge default is set. Currently sets `autoCompactWindow: 250000` to reduce cache-read costs on 1M-context models. Verify with `cast-deploy.sh --verify-settings`.

### Learnings
For each approved learning row: copy/patch `<forge>/learnings/<file>.md` entry into `<membrane>/learnings/<file>.md`.

### Memory
For each approved memory row: copy `<forge>/memory/<file>.md` into `<membrane>/memory/<file>.md`. A `RETIRED` row (file retired in forge) instead moves the membrane copy to `<membrane>/memory/archive/` — never delete.

### Record baseline
After all incoming is applied (before starting outgoing), write `<membrane>/.last-cast.json`:
```json
{ "lastCastCommit": "<git -C <forge> rev-parse HEAD>" }
```

> **Crash recovery**: If the session ends before this write completes, the next `/forge` run sees all differing skills as `CONFLICT (no-baseline)`. Fix: re-run `/forge`, choose `[↓] accept forge` on all items to re-establish the baseline.

## Phase 3: Fold — Absorb Outgoing (membrane → forge)

Skip this phase entirely if `--dry` or if no outgoing / `[↑]` conflict rows were approved.

Otherwise read `<forge>/core/skills/forge/fold-phase.md` and execute its steps 3a-3i in order: config sync, skill reverse-sync, knowledge review (triggers only), Forge-worthy promotion, learning absorption behind the purity gate, presentation refresh, memory absorption, staging archival, commit and push. The tracker is APPEND-ONLY and the purity gate is never bypassed.

## Phase 4: Project Scan & Divergence

Always runs (even for subsequent cycles) against the target project. Skips only when the target IS the forge repo itself.

### 4a: Read forge reference (parallel)

- The harness's rules reference (e.g., `<forge>/claude-helpers/refs/auto-allowed-bash.md` for Claude Code)
- `<forge>/core/skills/forge/stack-guide.md` — tech stack reference
- `<forge>/core/skills/forge/forge-conventions.md` — distilled conventions checklist

### 4b: Scan project (parallel)

- Check for BOTH `AGENTS.md` and `CLAUDE.md` at project root and read whichever exist; check blockers (including ancestor-directory `CLAUDE.md`/`CLAUDE.local.md`) and classify the rules-file state (procedure: forge-conventions §1; see Rules-file state below). On Claude Code, also run `claude --version` to get the installed version.
- Read harness-specific settings file (e.g., `.claude/settings.json`) if present
- Glob for `package.json`, `tsconfig*`, `pnpm-workspace.yaml`, `packages/`
- Check for `memory/`, `docs/`, `dev/restart.sh`, `dev/kill-zombies.sh`

### Rules-file state

The procedure — blockers, state table, stale-registry check, version gate, apply rules — lives in `<forge>/core/skills/forge/forge-conventions.md` §1 (already read in 4a). It is the single source, so it reaches every teammate on the same run it lands: follow it exactly.

### 4c: Divergence Report

```markdown
## Divergence Report — [PROJECT NAME]

| Aspect | Forge Convention | Current Project | Action |
|--------|-----------------|-----------------|--------|
| Project rules file | `AGENTS.md` required with standard sections | [OK/LINKED/SHIM/LEGACY/SHADOWED/MISSING/BLOCKED] | [none/unlink/remove shim/migrate/merge/create/replace stale registry/upgrade Claude Code first/resolve blocker] |
| Hard rules | Live in global rules file — do NOT duplicate | [global/missing] | Skip if global membrane exists |
| Harness settings | Only if project-specific overrides needed | [exists/missing/not needed] | [skip/create] |
| memory/ directory | Required | [exists/missing] | [create] |
| logs/ directory | Required (app projects with services only) | [exists/missing/N/A] | [create/skip] |
| Shorthand commands | Live in global rules file — do NOT duplicate | [global/duplicated] | Skip if global membrane exists; remove from project if duplicated |
| dev/restart.sh | Recommended (run /srs) | [exists/missing] | [suggest /srs] |
| dev/kill-zombies.sh | Recommended | [exists/missing] | [suggest /srs] |
| Documentation | `docs/` in-repo OR `## Documentation` section with `**Docs path:**` | [in-repo/external/missing] | [add section] |
| Logging setup | dev.log + browser forwarding | [present/missing] | [flag for /poke] |
```

Present as console markdown, then ask the user — using your harness's multi-choice prompt if available, otherwise inline: "Apply all / Skip some / Skip all".

### 4d: Apply (after confirmation)

**Project rules file** — apply the rules-file action per forge-conventions §1. The template below creates `AGENTS.md` in state `MISSING`, replaces a confirmed stale registry, or supplies missing standard sections for the existing rules file as §1 allows (which file, and when). Hard rules and shorthand commands live in the global rules file — do NOT duplicate. If the project already has a `## Shorthand Commands` section, remove it during this forge cycle.

```markdown
# [Project Name] — Project Rules

## Stack
[from project's package.json and tsconfig]

## Documentation
<!-- One of: `Docs are in the docs/ directory.` OR `**Docs path:** /absolute/path` -->

## Current Context
[branch, recent work, test status — filled by /wrap]
```

**Harness settings** — only if project-specific overrides needed. Global handles standard permissions.

**Directories** — create `memory/` if missing. Create `logs/` if missing (projects with running services only).

## Phase 5: DONE Report

Single unified receipt. Only include changed rows.

Every changed row must include a sub-row showing the **essence** of the change — not the filename or commit title, but the rule / principle / knowledge that now lives in its new home. A reader who never saw the PLAN table must understand *what shifted* from this report alone.

Format: heading `## Forge Cycle — /forge | YYYY-MM-DD | DONE`, then a table with columns `What | Direction | Result | Contributor` — one row per changed item (`↓ in` / `↑ out`), each followed by `→` sub-rows carrying the essence (for learnings: `→ Learning:` and `→ Apply when:`). Close with `Baseline: <sha>` and `Commit: <sha> — pushed to origin/main | kept local`.

**Result vocabulary** (past tense): `updated`, `created`, `synced`, `absorbed`, `merged`, `reconciled`, `skipped (reason)`, `description updated`, `trigger updated`.

If nothing changed in the cycle: `✓ Membrane synced.` and skip the report.

After the DONE report (and only when the target is a project, not the forge repo itself), output:
> **FORGE ENABLED** — all forge skills and art auto-invocation are active for this session.

Do NOT commit the project's own changes. Ask the user — using your harness's multi-choice prompt if available, otherwise inline — "Ready to wrap up?" with options "Yes, run /wrap" / "Not yet".

## No Project Names Rule

This rule governs every write to forge during the fold phase:

> Forge is a shared repo. NEVER include project-specific details in learnings, memory, commit messages, or any absorbed content.
> Strip all project names, specific file paths, domains, and business logic before writing.
> Learnings must read as universal principles. Commit messages must describe *what* was absorbed, not *where* it came from.

When in doubt, genericize. When a finding is too project-specific to genericize, don't absorb it.
