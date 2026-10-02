# /forge Phase 3 — Fold (Absorb Outgoing, membrane → forge)

> Loaded by [`SKILL.md`](SKILL.md) Phase 3. Execute steps 3a-3i in order. The "No Project Names Rule" referenced below lives at the end of `SKILL.md`.

### 3a: Config sync (harness-specific rules file)

For approved config rows: merge selected changes into the harness's rules reference — for Claude Code that lives at `<forge>/claude-helpers/refs/auto-allowed-bash.md`; other harnesses bind their own ref file. Sync rules:
- Global rules file (e.g., `~/.claude/CLAUDE.md`) ↔ the reference's harness sections (shorthand commands, auto-invocation, model recommendations)
- Permissions: the reference documents the blanket-allow template as shipped. A membrane's own `permissions.ask` / `permissions.deny` entries are personal — never sync
- HARD RULES never sync through this file — they deploy from `<forge>/core/rules/`
- Hooks, additional working directories, `forge-path` are machine-specific — never sync

### 3b: Skill reverse-sync

For approved `DEPLOYED-DIFFERS` rows (and conflict rows where user chose `[↑]`): diff deployed vs forge, apply membrane version to forge source (`<forge>/core/skills/<name>/`).

Protected skills (`forge`, `purge`) are already excluded at PLAN table level — no need to re-guard here.

### 3c: Review & prune existing forge knowledge (triggers only)

| Trigger | What fires |
|---------|-----------|
| Any `<forge>/learnings/*.md` > 50 entries | Learning review |
| Any `<forge>/memory/*-learnings.md` > 20 entries | Learning review (art-learnings files that live in `memory/` by design, e.g. `/purge`'s, are reviewed on entry count like any other learnings file) |
| `<forge>/memory/` has > 20 files | Memory review |

Run `<forge>/core/scripts/fold-evidence.sh` to collect evidence, then hand the evidence to an opus-tier subagent to classify each entry: **CURRENT** / **STALE** / **MERGED** / **EVOLVED** / **PROMOTED** — curation verdicts over the shared knowledge base need the strongest judgment, and the subagent keeps the bulky evidence dump out of the main context. Present its review sub-table, apply after user confirms — the user's confirmation is the gate for every prune or merge. If your harness lacks subagent spawning or per-spawn model selection, run the classification inline at your session model.

If no triggers fire, skip entirely.

### 3d: Promote Forge-worthy learnings from project memories

Scan project memory directories (e.g., `~/.claude/projects/*/memory/*-learnings.md` for Claude Code; the equivalent location for the active harness) for entries tagged `Forge-worthy: yes`. For each:
1. Skip if title already in `<forge>/learnings/.fold-tracker.json` `promotedEntries` or in `<membrane>/learnings/general.md`
2. Genericize (strip project names, paths, domains — see "No Project Names" rule below)
3. Append to `<membrane>/learnings/general.md` with `<!-- promoted from project memory, YYYY-MM-DD -->` comment
4. Add title to tracker `promotedEntries`

Skip silently if no Forge-worthy entries exist.

### 3e: Learning absorption

For approved outgoing learning rows:

**Genericize first**, then write to forge. Genericize means strip all project names, contributor names, currency/prices, project schema/field names, competitor names, and region-specific framing — keep the universal principle. Attribution lives in the PLAN/DONE table only, never in the learning body (`Forge-worthy: yes` is a flag, not a citation slot). Write to `<forge>/learnings/<file>.md`, NEVER to `<membrane>/learnings/` — that's the deployed copy; writing there silently skips forge and the tracker marks the entries processed so no future fold can heal the gap. The next purity-check step is the mechanical gate that enforces all of this — if the script blocks, fix the content; do not bypass.

#### Purity gate (mandatory before each absorbed learning is written)

After staging absorbed entries (and BEFORE finalizing them), run:
```bash
git -C <forge> add learnings/<file>.md
bash <forge>/core/scripts/fold-purity-check.sh --staged
```

If the script exits non-zero, it lists the violations. Fix every one:
- Re-genericize the flagged content
- Add legitimate universal terms to the script's `ALLOWLIST_TERMS` if a flagged term is genuinely a well-known reference (e.g., a major framework, a standard API)

Re-run until exit 0. **Do not unstage and commit anyway.** The script is the gate; bypassing it re-creates exactly the leak that prompted its existence (see `learnings/global-patterns.md` Exhibit A: "How a Project-Name Leak Happens, 2026-04-25").

Target files in `<forge>/learnings/`: route each entry to the learnings file of the art or master it sharpens — `<name>-learnings.md` for prime, probe, poke, preen, press, pound, pitch, plot, pry, praise, smith, wedge — and to `global-patterns.md` only when it is cross-cutting.

Format: `## [Title] (YYYY-MM-DD)` + `**Learning**:` + `**Apply when**:`

Source entries in `<membrane>/learnings/` are NEVER deleted.

**Tracker**: maintain `<forge>/learnings/.fold-tracker.json` with `lastRun`, `processedEntries`, `promotedEntries`. Append title on each absorb.

> **HARD RULE — Tracker is APPEND-ONLY.** Never remove entries. Tracker lives in forge repo (shared across users). Each user has their own membrane. Removing a tracker entry based on one user's state causes every other user's forge cycle to re-absorb that entry — creating duplicates across the team. Residue entries (tracked but no matching forge file) are harmless — the fold phase just skips them. A tracker with 1000 entries is ~10KB. Let it grow.

### 3f: Skill presentation refresh

Runs after 3e if at least one skill learning file was modified. For each modified `<forge>/learnings/<art>-learnings.md` → corresponding `<forge>/core/skills/<art>/SKILL.md`:

Skills describe themselves in two places: the `description:` frontmatter and the `TRIGGER when:` line. As learnings accumulate, these can drift — a skill that has learned to handle edge cases it didn't originally anticipate, or that now covers more triggers than it declared.

Launch one sonnet-tier subagent per skill (in parallel — or sequentially at your session model if your harness lacks parallel sub-agent spawning or per-spawn model selection):

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

Review each subagent proposal against the presentation-only HARD RULE below, then add presentation changes as rows in the DONE report — nothing is applied until the user approves those rows. If no changes needed: omit presentation rows (no noise).

For each approved change:
1. Update `description:` in `<forge>/core/skills/<skill>/SKILL.md`
2. Update `TRIGGER when:` line (if changed)
3. Also update deployed copy at `<membrane>/skills/<skill>/SKILL.md` — presentation takes effect immediately

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

Source entries in `<membrane>/memory/` are NEVER deleted.

### 3h: Staging archival (triggers only)

| Trigger | What fires |
|---------|-----------|
| `<membrane>/learnings/general.md` > 100 entries | Learning archival |
| `<membrane>/memory/` > 30 files | Memory archival |

**Learning archival**: cross-reference entries against tracker `processedEntries` AND forge learning files. Entries that are BOTH processed AND present in forge → offer to move to `<membrane>/learnings/archive/general.md`.

**Memory archival**: files identical in both membrane and forge → offer to move to `<membrane>/memory/archive/`.

Never delete — archival is a move.

> **Note**: Archiving entries from `general.md` does NOT allow tracker compaction. The tracker is shared across all forge users. The tracker is truly append-only.

### 3i: Commit & push forge

1. **Conflict check**: `git -C <forge> diff --name-only --diff-filter=U`. If unresolved conflicts, STOP.
2. **Stage** specific files with `git add <file>` (never `git add -A`).
3. **Final purity gate** (catches anything 3e missed and any new content added in 3f/3g):
   ```bash
   bash <forge>/core/scripts/fold-purity-check.sh --staged
   ```
   If non-zero, do NOT proceed. Unstage offending content, re-genericize, restage, re-run until clean. This is a HARD gate.
4. **Commit message purity check** — before invoking `git commit`, run:
   ```bash
   bash <forge>/core/scripts/fold-purity-check.sh --commit-msg "<message>"
   ```
   Commit messages have leaked project names and contributor names in the past. The check catches `Absorb 7 learnings from <Person> (<Project> session, ...)` patterns and similar. If non-zero, rewrite the message until clean.
5. **Update context** in `<forge>/AGENTS.md` Current Context section.
6. **Compact check**: if AGENTS.md > ~20k chars, overflow to `memory/`.
7. **Commit**: descriptive message (what was absorbed, no project names, no contributor names). **No AI/agent attribution metadata (no `Co-Authored-By` lines).**
8. **Push decision**: ask the user — using your harness's multi-choice prompt if available, otherwise inline — options: "Push to origin" / "Keep local".
