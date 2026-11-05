# /purge Learnings

> Accumulated learnings from forge cleansing sessions. Absorbed by the `/forge` cycle.

<!-- Add learnings below this line -->

## A Structural Change Triggers a Whole-Repo Cross-Reference Sweep (2026-03-28 → 2026-06-13)
**Learning**: Adding an art, retiring or merging a command, removing a shared protocol step, or landing a pivot on `main` each radiate stale references far beyond the files the change touched. The skill files and `protocol.md` get updated in the same session; everything that *describes* the hierarchy lags. Observed four times (art addition, command consolidation, pivot merge, capability retirement) — the same sweep each time.
**Sweep surface** (grep the ENTIRE repo for the old token or count — scripts, HTML, JSON, not just markdown):
1. `AGENTS.md` — arts/skills tables, counts, and Current Context (Branch + Active work describe the pre-change state the moment the change merges).
2. `memory/identity.md` (hardcoded art counts in 5+ places, ethos prose, numbered roster, liturgical passages that name commands) and `memory/learnings.md` (roster + cadence note).
3. `README.md` and `presentation/index.html` — headers, cadence notes, dedicated slides. A slide restructure is a rewrite, not find-replace.
4. Reference docs citing old paths (`forge-conventions.md`, `protocol.md`) and every skill pre-flight step that reads them.
5. Forge-internal skills: `.claude/skills/purge/` and the cycle skill's bootstrap copy (source at `.agents/skills/forge/`, symlinked from `.claude/skills/forge`) — the easiest to forget because they are not deployed and not in `core/skills/`. The cleansing tool has carried a phantom reference in its own definition.
6. Hardcoded art rosters: the `ARTS` list in `core/scripts/forge-purge-scan.sh`'s skill-count block (an art missing there is counted as a task skill) and the routing list in `core/skills/forge/fold-phase.md` 3e. The scan's size and frontmatter tables discover skills and need no edit.
7. User-visible error messages in supporting scripts, learning-file headers ("Absorbed by /old-command" — one line repeated across ~10 files, batch them), settings allowlist paths, `.gitignore` comments and dead deploy-target patterns.
8. The plan doc that drove the change — once merged it is archaeology; move it from `plans/` to `archive/`.
**Rules**: (1) Run `/purge` immediately after any such change. (2) Never assume the skill that performed a removal swept its own references. (3) Fix error messages before commit — they reach users faster than docs. (4) Keep one explicit "replaces the old X" bridge line in the new command's docs; that is migration ergonomics, not a stale ref.
**Apply when**: A new art lands, a top-level command is retired, renamed or merged, a shared pre-flight step or cross-cutting capability is removed, or a branch carrying renamed top-level paths merges onto `main`.
**Forge-worthy**: yes — universal: a structural change to a documented system requires sweeping every consumer, including the tooling that performs the sweep.

## Promotion Leaves the Source Copy Behind — the Canonical Copy Wins (2026-03-19 → 2026-10-11)
**Learning**: When a learning is promoted — art-specific file → `global-patterns.md`, or `global-patterns.md` → the stack guide's "Key Learnings" — the source entry is rarely removed. Duplicates accumulate invisibly; the scan's duplicate-title detection catches them. The fix is always the same: the most-promoted location is canonical (stack guide > global-patterns > art-specific file) and the lower copy is removed. The promoted copy may be less complete than the source — compare before removing, and carry any missing detail up first. The same order applies inside a single fold: a same-day fold can write detail into the stack guide and also absorb art learnings that restate it. When an approved row lands in the stack guide, the matching art entry should be a short pointer carrying only the art-specific judgment, never a second copy.
**Apply when**: Running `/purge` Dimension 1c or the `/forge` 3c review — check each art-specific entry against `global-patterns.md`, and each `global-patterns.md` entry against `stack-guide.md`. Also apply when a fold or purge routes one source item to both a reference doc and a learnings file.
**Forge-worthy**: yes — universal pattern for any learning system where entries can be promoted to a shared store without removing them from the source.

## Art Roster Design: Scope Over Count, Trigger Decides Placement (2026-03-20 → 2026-03-22)
**Learning**: When two arts overlap >50% in findings, merge them: one wider-scope art beats two that produce duplicate findings. The evaluative trifecta (poke → press → pound) works because each has a distinct scope: code quality, operational readiness, adversarial QA. A new art's trigger decides its placement: one that escalates intensity on the same trigger joins the sequence; one with a different trigger (e.g. "on UI changes") is labelled "parallel" from the start, or it gets slotted into the sequence by default and breaks the naming (a "trifecta" of four).
**Apply when**: Proposing a new art, reviewing whether an art still earns its seat, or adding an evaluative skill next to an existing escalation sequence.

## Single-Pass Purge Is Legitimate When the Forge Is Already Clean (2026-05-10)
**Learning**: The skill prescribes parallel four-dimension subagent fan-out (Knowledge Purity / Memory Hygiene / Skill Fitness / Reference Integrity). When the scan output is mostly clean (no project leaks, no learning duplication, no critical bloat) and the actionable findings cluster in *one* dimension (post-pivot Reference Integrity drift), spawning four subagents that each re-verify the scan output is wasteful — most return "minor things" the master already saw. In that case, master-side consolidation with all evidence read in pre-flight is sufficient and faster. The four-dimension fan-out earns its keep when the forge is genuinely heavy (≥ one trigger threshold breached, or evidence of contamination in multiple dimensions). When the scan comes back light, a single-pass purge respects the user's token budget without compromising the user-gate ceremony.
**Forge-worthy**: no — purge-internal pacing decision; lives in `purge-learnings.md` only.
**Apply when**: Running `/purge`. After the scan returns, look at the findings: if they cluster in ≤2 dimensions and total < ~10 items, do single-pass consolidation. If the scan flags a trigger threshold (learnings > 50, memory > 20 files) OR reveals contamination patterns across multiple dimensions, fan out four subagents per the skill's standard methodology.

## Unpromoted Forge-worthy Entries in memory/ Are a Manual Fold, Not a Misplacement (2026-06-13)
**Learning**: `memory/<art>-learnings.md` is an art's raw forge-self-review output (where the art writes during post-flight, per its SKILL.md); `learnings/<art>-learnings.md` is the promoted/absorbed store. Entries flagged `Forge-worthy: yes` that linger in `memory/` with no `learnings/` counterpart were simply never folded. The right cleanse is to promote them (append to `learnings/<art>-learnings.md`, dedup by title) — exactly what `/forge` fold would do — and let the raw `memory/` file regenerate on the next self-review run. Don't mislabel the `memory/` file as a "pillar-placement error"; it's the designated raw output. (Dedup-by-title on the next fold makes the manual promotion idempotent against the regenerated raw file.)
**Forge-worthy**: no — purge-internal procedure for handling unpromoted self-review learnings.

## Purge Logs Must Describe the Leak's Class, Never the Leaked Token — and the Purity Gate's File-Type Coverage Is Part of Its Contract (2026-08-15)
**Learning**: A purge/session log that reports "leak X scrubbed from file Y" by writing the actual leaked value into the log has not fixed the leak — it has re-published it, in the very sentence claiming removal. Observed twice in consecutive cycles: a purge log recorded "project codename X scrubbed from `<file>`; `<city>/<vertical>` genericized" — restating the exact identifiers being removed — and that same log, one clause earlier, described fixing that identical re-leak from a PRIOR purge. The log itself was the recurring leak vector.
**Rule**: When logging any purge, name the CLASS of what was removed ("a project codename was scrubbed", "a city/vertical pairing was genericized"), never the literal value. This applies to session logs, commit messages, and `recent-history.md`-style archives — anywhere a "before" value might get quoted as evidence of cleanup.
**Second discovery, same session**: the purity gate never read the JSON trackers. Its staged and diff modes scope by directory (`learnings/`, `memory/`, root `AGENTS.md`) and skip dotfiles, so `.fold-tracker.json` and `.memory-tracker.json` (both git-tracked) are outside it; one carried a project filename and a person's name for ~5 months. Root cause: trackers moved from opaque hashes to readable filenames on 2026-03-19 for portability, a readability-for-privacy trade nobody priced. A gate's coverage (directories, file types, dotfiles) is part of its contract: a gate that skips a file is untested there, not clean there. Closed 2026-11-05: the gate now allow-lists both trackers by exact path and reads their string values (every title is capitalised word by word, which makes the personal-name check unusable there, so names in tracker titles still need a hand read). Re-check the filter whenever the repo layout changes.
**Red-green proof rule**: Verify a newly-widened gate with a red-green proof: confirm it FLAGS the known breach before the fix, and passes clean after. A gate that has only ever been observed passing has not been shown to work.
**Apply when**: Writing any purge/audit log entry that reports a leak was fixed — describe the class, not the value. When reviewing or extending a purity/leak-scanning gate, audit its file-type glob against every file type the repo actually writes (JSON trackers, YAML config, HTML artifacts), not just the primary content format. Whenever a gate is widened, prove it with a red-green cycle rather than trusting the first clean run.
**Forge-worthy**: yes — universal: (1) a leak-remediation log that quotes the leaked value is not a fix, it's a second leak; (2) any scanning gate's file-type coverage is a first-class part of what "the gate checks" means — silently scoped-down coverage produces false-clean audits; (3) an unproven gate widening is indistinguishable from a no-op.

## A Recorded Full-Verification Is a Partial Warrant (2026-08-15)
**Learning**: A prior session's record of a "full web-grounded re-verification of all N claims" led the next cycle to narrow its review to a spot-check, which then found five errors the recorded pass had missed. A completeness claim with no per-claim evidence is a mirror of verification state, and it decays like any other mirror. When recording a verification pass, record what it missed and its blind-spot categories (cost multiples, version-pinned competitor comparisons, package-name references), not just the count corrected; future cycles scope themselves on that record.
**Apply when**: Scoping any review against a prior pass's coverage record, or writing one.

## An Automated Safety Warning Can Conflate Two Same-Named Files in Different Directories (2026-08-23)

**Learning**: A warning flagged the deletion of a dead one-line stub as the destruction of a much larger file, attributing the size of a same-named file in a sibling directory to the deleted one. The stub's very existence — shadowing a real store of the same name in an adjacent pillar — was the documented reason for removing it, so the warning reproduced the exact confusion the deletion was meant to prevent.

**Rule**: Verify the specific claim (the object's real size, path, and recoverability) before either acting on such a warning or dismissing it. Note that a staged deletion of a tracked file is always recoverable from history, so "irreversible" rarely holds before a commit.

**Apply when**: A safety/deletion warning names a file size, path, or "irreversible" consequence — confirm the claim against the actual object (not a same-named neighbor) before acting on or dismissing it.

**Forge-worthy**: yes — universal: same-named files across directories are a recurring source of misattributed warnings; verify path identity, not just name, before trusting a deletion warning.

## A Proposal Invents Its Own Provenance (2026-08-30)

**Learning**: An agent proposing a new skill cited three forge learnings by slug — an "existing law", a named grading rule, and a named prototype rule — to position its proposal as consolidating wisdom the forge already held. None of the three existed anywhere in `learnings/`, `memory/`, or `core/skills/`. The citations were load-bearing: they are what made the notes read as *absorption* rather than *invention*, and they made the proposal feel pre-validated by work nobody had done. This is the "plausible name hardens into a premise" pattern, applied inward — the fabricated authority was the forge's own.

The tell is that the invented laws were *good*. They deserved to exist, which is exactly why nobody would think to check them. Plausibility is what makes a phantom citation survive review.

**Rule**: Every named learning slug, rule, or "existing law" a proposal cites must grep to a real file before the proposal is weighed on its merits. Run the grep first — a proposal resting on three phantom citations is arguing from a different evidence base than it claims, and its conclusions must be re-derived from what actually exists. When the invented law turns out to be sound, write it as a real learning; do not let a good idea launder itself into the knowledge base as an established one.

**Apply when**: Any proposal, assessment, or hand-off written by another agent that cites forge-internal knowledge by name — especially one arguing for a new skill, art, or doctrine change.

**Forge-worthy**: yes — universal: an agent's citation of prior art in a shared knowledge base is a claim to verify, not a premise to accept, and the most convincing fabrications are the ones worth believing.

## Same-File Findings From Two Reviewers Must Be Merged, Not Queued (2026-10-02)

**Learning**: Two reviewers can each propose a correct fix to the same file that fails when both land — one relocated a generated script, the other added logic that derived a path from the script's own location. Consolidation checks every file touched by more than one dimension for combined effect and writes one merged instruction before any editor starts.

**Apply when**: Consolidating findings from parallel dimension reviewers, before any editor is briefed.

**Forge-worthy**: no — forge-internal

## A Purge Leaves the Membrane Stale — Cast Right After the Commit (2026-10-02)

**Learning**: The maintainer's membrane still holds the pre-purge learnings files, so the next cycle reads every retired title as new outgoing work and can undo the purge. Put the membrane cast in the cleansing plan as its own row, and before overwriting each membrane file confirm it equals the pre-purge committed version.

**Apply when**: Planning the cleansing steps of any purge that edits learnings or memory files.
**Forge-worthy**: no — forge-internal

## Extracting a Section to a Sibling File Breaks Copies That Have No Siblings (2026-10-02)

**Learning**: A skill mirrored into a directory that carries only its SKILL.md cannot follow a relative link to an extracted sibling. Point extraction pointers at the full `<forge>/core/skills/<name>/` path, and after any extraction check every mirror of the skill.

**Apply when**: Extracting a section of a skill into a sibling file to bring it under a size ceiling.

**Forge-worthy**: no — forge-internal

## A Line Ceiling in an Editor Brief Invites Unlisted Cuts (2026-10-02)

**Learning**: Told to bring a skill under a ceiling, an editor that falls short after the approved extractions will trim text no finding named. The brief must say: apply the findings, report the remaining gap, cut nothing else.

**Apply when**: Briefing an editor subagent on a skill that must meet a line ceiling.

**Forge-worthy**: no — forge-internal

## Count Findings by Grep, Not From Hand-Backs (2026-10-02)

**Learning**: Interim per-dimension counts relayed from reviewer summaries were wrong in three of five dimensions. Count FINDING_START and SEVERITY lines in the saved reports before quoting any total.

**Apply when**: Quoting finding totals in a purge plan, report, or log entry.

**Forge-worthy**: no — forge-internal

## A Name-Based Leak Gate Misses Five Surfaces a Content Sweep Must Read by Hand (2026-03-19 → 2026-10-08)

**Learning**: A gate that matches known names passes content that still identifies its source. Five surfaces escape it. (1) The gate's own comments and example identifiers, copied from the incident that motivated the rule. (2) Example rows in skill templates, which carry the author's handle. (3) Example vendor or provider lists: when every example comes from one country, the list reveals a single market. (4) Anonymised anecdotes, which pass every name check but still describe one product. Tells for (4): "Evidence:", "Field-observed", "at one gate", exact counts and durations beside product nouns, quoted project rules. Rewrite to the mechanism in the present tense and drop the count. (5) Domain entity identifiers in code examples (an ID field named after a product's core noun). The gate strips fenced code before its name checks, so these are never read; use neutral commerce-style names such as an order or item ID. When recording any of these, describe the class and never quote the leaked identifier as the bad example.

**Apply when**: Running a content-leak sweep, writing forge content with code examples, or after changing a purity gate. Read these five surfaces by hand, and check the gate's `purity: scanned N file(s)` line shows N > 0.

**Forge-worthy**: yes — universal: name matching is necessary but not sufficient for leak detection, and a gate that scans nothing reports the same success as one that found nothing.

## A Threshold Breach Is a Routing Check Before a Currency Check (2026-10-11)

**Learning**: A cross-cutting learnings file sat over its entry threshold, and a currency review the day before had found nothing stale, so the open question had become whether to raise the threshold or split the file. The cause was routing. Seventeen of fifty-nine entries sharpened a single art and belonged in that art's file. Asking of each entry which art reads it took the file to forty with no entry lost.

**Apply when**: A learnings file is over its threshold and a staleness review returns nothing to prune. Check each entry against the routing rule before changing the threshold or splitting the file.

**Forge-worthy**: no — forge-internal

## Moved Text Re-Enters the Leak Gate as New Text (2026-10-11)

**Learning**: Relocating or archiving committed text between scanned files makes the staged gate read every moved line as an addition, so content that predates a pattern, or came from an unscanned file, is flagged for the first time. The flags are real work. Reword plain cases in place, and allowlist only web-standard names and the forge's own terms. Read `fold-purity-check.sh` before briefing the fix, because the check on backticked identifiers has its own exclusion list, separate from the main term list.

**Apply when**: A purge plans relocations, or archives a rules-file section into a scanned directory. Budget a gate pass before the commit and expect it to fail the first time.

**Forge-worthy**: no — forge-internal

## A Scan Script Can Abort Silently and Read as Clean — Run It to Completion (2026-06-20 → 2026-10-31)
**Learning**: The purge evidence scripts run under `set -euo pipefail`. A `grep -c` that matches zero lines exits 1, pipefail propagates it, and errexit aborts the script with no error message: earlier sections print, later ones are missing, and a missing section reads as "nothing to report". It has happened twice: a frontmatter check for a field the neutral source never carries aborted every scan before Dimension 4, and a move from a hardcoded skill list to directory discovery reached zero-match inputs by a new path. `bash -n` passes because the fault is at runtime. A check on a field the source is designed never to carry is noise even once it stops crashing. Evidence scripts are part of the trusted base and get verified like any other claim; a scanner has also invented sections from headings inside code fences.
**Rule**: After editing any scan script, run it to completion and confirm it exits 0 and prints its final marker. Guard zero-match counts with `|| true` or `${var:-0}`. When a scan finding would remove or trim content, open the file first.
**Purity check on purge diffs**: judge a purge's own changes with `fold-purity-check.sh --staged` or `--diff <base> <head>`, which scan only added lines. Passing file paths scans whole files, so old unrelated content is flagged; treat that as a separate backlog.
**Apply when**: Editing any `set -e` or `pipefail` script or changing its inputs from fixed to discovered; any audit section that comes back empty; acting on a scan finding that removes content; reading purity output for a purge.
**Forge-worthy**: yes — universal: a syntax check does not prove a script runs, a truncated run masquerades as a clean bill of health, and a whole-file gate is not a measure of one change's cleanliness.
