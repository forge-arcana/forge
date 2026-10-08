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
5. Forge-internal skills under `.claude/skills/` (purge, forge bootstrap) — the easiest to forget because they are not deployed and not in `core/skills/`. The cleansing tool has carried a phantom reference in its own definition.
6. `core/scripts/forge-purge-scan.sh` — hardcodes the art roster in 3 places (two table loops + the `ARTS` count). An art omitted there is miscounted as a task skill and dropped from both fitness tables, so the audit that detects staleness is itself stale.
7. User-visible error messages in supporting scripts, learning-file headers ("Absorbed by /old-command" — one line repeated across ~10 files, batch them), settings allowlist paths, `.gitignore` comments and dead deploy-target patterns.
8. The plan doc that drove the change — once merged it is archaeology; move it from `memory/` to `archive/`.
**Rules**: (1) Run `/purge` immediately after any such change. (2) Never assume the skill that performed a removal swept its own references. (3) Fix error messages before commit — they reach users faster than docs. (4) Keep one explicit "replaces the old X" bridge line in the new command's docs; that is migration ergonomics, not a stale ref.
**Apply when**: A new art lands, a top-level command is retired, renamed or merged, a shared pre-flight step or cross-cutting capability is removed, or a branch carrying renamed top-level paths merges onto `main`.
**Forge-worthy**: yes — universal: a structural change to a documented system requires sweeping every consumer, including the tooling that performs the sweep.

## Promotion Leaves the Source Copy Behind — the Canonical Copy Wins (2026-03-19 → 2026-03-28)
**Learning**: When a learning is promoted — art-specific file → `global-patterns.md`, or `global-patterns.md` → the stack guide's "Key Learnings" — the source entry is rarely removed. Duplicates accumulate invisibly; the scan's duplicate-title detection catches them. The fix is always the same: the most-promoted location is canonical (stack guide > global-patterns > art-specific file) and the lower copy is removed. The promoted copy may be less complete than the source — compare before removing, and carry any missing detail up first.
**Apply when**: Running `/purge` Dimension 1c or the `/forge` 3c review — check each art-specific entry against `global-patterns.md`, and each `global-patterns.md` entry against `stack-guide.md`.
**Forge-worthy**: yes — universal pattern for any learning system where entries can be promoted to a shared store without removing them from the source.

## Entity Names Are Project Leaks (2026-03-19)
**Learning**: Domain-specific entity identifiers in code examples (an ID field named after a product's core noun, a role-specific user ID) reveal the source project even when the project name is absent. Use neutral commerce-style names (`orderId`, `itemId`, `targetUserId`) in all forge examples and learnings. When recording this kind of leak, describe the class — never quote the leaked identifier as the "bad example".
**Apply when**: Writing or reviewing any forge content that includes code examples with entity names.

## Art Consolidation: Scope Over Count (2026-03-20)
**Learning**: When two arts overlap >50% in findings, merge them. A wider-scope art with more dimensions is better than two overlapping arts that produce duplicate findings. The evaluative trifecta (poke → press → pound) works because each has a distinct scope: code quality, operational readiness, adversarial QA. Adding a fourth art for "universal principles" created redundancy with poke's existing tech debt dimensions.
**Apply when**: Proposing new arts or reviewing whether existing arts still earn their seat.

## Parallel Arts Need Explicit "Parallel" Label (2026-03-22)
**Learning**: When adding a new evaluative art that runs on a different trigger (e.g., "on UI changes") rather than escalating intensity, explicitly label it as "parallel" from the start. Without the label, it gets inserted into existing sequences by default, creating naming inconsistencies (e.g., "trifecta" with 4 items). The trigger determines placement: same trigger escalation = sequential, different trigger = parallel.
**Apply when**: Adding new arts or evaluative skills to an existing escalation sequence.

## Tracker "Orphans" Are Not Orphans — the Re-Absorption Incident (2026-03-29)
**Learning**: A purge orphan scan classified fold-tracker entries with no matching `learnings/*.md` title as removable. Some existed under slightly different titles (fuzzy mismatch); others lived in `memory/*.md` (wrong search scope). Removing them told the next fold they were unprocessed — re-absorption and duplicates in `global-patterns.md`. Purge silently poisoned the tracker, and fold faithfully executed the poison.
**Rule**: Superseded by the stronger rule now in `purge/SKILL.md` — the tracker is APPEND-ONLY. No verification makes removal safe, because no single user can see every membrane. This entry is the incident record behind that rule (see `reference/2026-03-29-tracker-append-only.md`).
**Forge-worthy**: yes — universal: a processing tracker that gates idempotent operations must never be pruned on a "no matching output" heuristic.

## Single-Pass Purge Is Legitimate When the Forge Is Already Clean (2026-05-10)
**Learning**: The skill prescribes parallel four-dimension subagent fan-out (Knowledge Purity / Memory Hygiene / Skill Fitness / Reference Integrity). When the scan output is mostly clean (no project leaks, no learning duplication, no critical bloat) and the actionable findings cluster in *one* dimension (post-pivot Reference Integrity drift), spawning four subagents that each re-verify the scan output is wasteful — most return "minor things" the master already saw. In that case, master-side consolidation with all evidence read in pre-flight is sufficient and faster. The four-dimension fan-out earns its keep when the forge is genuinely heavy (≥ one trigger threshold breached, or evidence of contamination in multiple dimensions). When the scan comes back light, a single-pass purge respects the user's token budget without compromising the user-gate ceremony.
**Forge-worthy**: no — purge-internal pacing decision; lives in `purge-learnings.md` only.
**Apply when**: Running `/purge`. After the scan returns, look at the findings: if they cluster in ≤2 dimensions and total < ~10 items, do single-pass consolidation. If the scan flags a trigger threshold (learnings > 50, memory > 20 files) OR reveals contamination patterns across multiple dimensions, fan out four subagents per the skill's standard methodology.

## Unpromoted Forge-worthy Entries in memory/ Are a Manual Fold, Not a Misplacement (2026-06-13)
**Learning**: `memory/<art>-learnings.md` is an art's raw forge-self-review output (where the art writes during post-flight, per its SKILL.md); `learnings/<art>-learnings.md` is the promoted/absorbed store. Entries flagged `Forge-worthy: yes` that linger in `memory/` with no `learnings/` counterpart were simply never folded. The right cleanse is to promote them (append to `learnings/<art>-learnings.md`, dedup by title) — exactly what `/forge` fold would do — and let the raw `memory/` file regenerate on the next self-review run. Don't mislabel the `memory/` file as a "pillar-placement error"; it's the designated raw output. (Dedup-by-title on the next fold makes the manual promotion idempotent against the regenerated raw file.)
**Forge-worthy**: no — purge-internal procedure for handling unpromoted self-review learnings.

## The Evidence Script That Powers the Audit Can Itself Be Silently Broken (2026-06-20)
**Learning**: `/purge` depends on `forge-purge-scan.sh` for mechanical evidence, but the script runs under `set -euo pipefail` — so any `grep -c PATTERN | head -1` where PATTERN matches zero lines makes `grep` exit 1, `pipefail` propagates it, and `set -e` aborts the WHOLE script mid-stream. The failure is invisible: earlier dimensions print fine, the script just stops, and the missing dimension reads as "nothing to report" rather than "never ran." Here the frontmatter check grepped `^user-invocable:` (a Claude-deploy-only field never present in neutral source) and killed the scan before Dimension 4 (Reference Integrity) on EVERY run since the check landed. Two compounding smells: (1) a zero-match `grep -c` under pipefail is a latent abort, not a safe "count = 0"; guard with `|| true` (grep still prints "0", so the count survives) or `${var:-0}`. (2) the check tested a field that the source store is *designed* never to carry — a guaranteed-MISSING column is noise even once it stops crashing. When an audit dimension comes back empty, verify the evidence tool actually REACHED it before concluding the subject is clean.
**Apply when**: Any `/purge` (or any script-driven audit) where a whole dimension/section returns no findings. Confirm the evidence script exited 0 and printed its final marker; a truncated-but-exit-1 run masquerades as a clean bill of health. Audit shared evidence scripts for `grep -c … | head` / `grep -q` patterns under `pipefail` that can abort on legitimate zero-match cases.
**Forge-worthy**: yes — universal: an audit's evidence-gathering tool failing silently produces false "all clear" verdicts; zero-match greps under pipefail are a recurring latent-abort class.

## Reference-Doc Audits Must Separate "Stale" From "Wrong-From-Birth" — Version Checks Miss Security Advice (2026-06-20)
**Learning**: A reference/stack guide accumulates two distinct defect classes, and a currency audit that only asks "is this version current?" catches just one. (1) **Staleness** — a once-correct claim that drifted (a config key removed in a new major: `adjustMarginsForEdgeToEdge` gone in Capacitor 8; `onlyBuiltDependencies` removed in pnpm 11). (2) **Wrong-from-birth** — a recommendation that was never correct and no version bump will fix: the guide advised `@capacitor/preferences` for "secure token storage," but that store is plaintext SharedPreferences/UserDefaults on every version it ever shipped. The second class is more dangerous (it's a security-correctness bug, not drift) and is invisible to "check the latest version" — you only catch it by verifying the *claim's substance* against primary docs. So a reference audit must web-verify load-bearing security/correctness claims on their merits, not just diff version numbers. Process that worked: fan out one subagent per concern (reference currency / skill-bloat trim / learnings consolidation), each required to cite sources and emit apply-ready proposals (old/new blocks, merged-entry text), master spot-verifies the highest-blast-radius claim independently before applying. The reference-doc currency check is read-heavy + web-heavy — ideal to delegate — but the master must re-verify anything that would write a removed config key or an insecure pattern into the canonical guide.
**Apply when**: Auditing any stack guide / reference doc for currency (Dimension 4). Classify each finding as stale-vs-wrong-from-birth; treat security/correctness claims as needing substance-verification regardless of version recency. When fanning out the audit, independently re-verify the single highest-impact claim before committing it to the shared doc.
**Forge-worthy**: yes — universal: "is the version current?" is necessary but not sufficient for reference-doc audits; security advice that was wrong on day one passes every version check.

## Purge Logs Must Describe the Leak's Class, Never the Leaked Token — and the Purity Gate's File-Type Coverage Is Part of Its Contract (2026-08-15)
**Learning**: A purge/session log that reports "leak X scrubbed from file Y" by writing the actual leaked value into the log has not fixed the leak — it has re-published it, in the very sentence claiming removal. Observed twice in consecutive cycles: a purge log recorded "project codename X scrubbed from `<file>`; `<city>/<vertical>` genericized" — restating the exact identifiers being removed — and that same log, one clause earlier, described fixing that identical re-leak from a PRIOR purge. The log itself was the recurring leak vector.
**Rule**: When logging any purge, name the CLASS of what was removed ("a project codename was scrubbed", "a city/vertical pairing was genericized"), never the literal value. This applies to session logs, commit messages, and `recent-history.md`-style archives — anywhere a "before" value might get quoted as evidence of cleanup.
**Second discovery, same session**: the fold purity gate (`fold-purity-check.sh`) scans markdown only. A leak sitting in a JSON tracker (`.memory-tracker.json` carried a project filename and a person's name for ~5 months) passes every check silently — not because the value was hard to detect, but because the gate never looked at the file type it was in. A purity gate's file-type coverage is part of its contract, not an implementation detail; a gate that only checks `.md` is not "clean elsewhere," it's untested elsewhere. Root cause of the JSON leak: trackers moved from opaque hashes to human-readable filenames on 2026-03-19 for portability — a readability-for-privacy trade nobody priced at the time. When a rule applies to "all shared content," the scanner's file filter must enumerate every directory that holds shared content, and that filter must be re-checked whenever the repo layout changes.
**Red-green proof rule**: Verify a newly-widened gate with a red-green proof: confirm it FLAGS the known breach before the fix, and passes clean after. A gate that has only ever been observed passing has not been shown to work.
**Apply when**: Writing any purge/audit log entry that reports a leak was fixed — describe the class, not the value. When reviewing or extending a purity/leak-scanning gate, audit its file-type glob against every file type the repo actually writes (JSON trackers, YAML config, HTML artifacts), not just the primary content format. Whenever a gate is widened, prove it with a red-green cycle rather than trusting the first clean run.
**Forge-worthy**: yes — universal: (1) a leak-remediation log that quotes the leaked value is not a fix, it's a second leak; (2) any scanning gate's file-type coverage is a first-class part of what "the gate checks" means — silently scoped-down coverage produces false-clean audits; (3) an unproven gate widening is indistinguishable from a no-op.

## A Recorded Full-Verification Is a Partial Warrant — and Evidence Tools Need Their Own Verification (2026-08-15)

**Learning**: Two trust failures surfaced in one pass, both about believing the instruments. (1) A prior session's record of a "full web-grounded re-verification of all N claims" caused this cycle to narrow its review to a spot-check — which then found five pre-existing errors the recorded pass had missed. A completeness claim with no per-claim evidence is a mirror of verification state, and it decays like any other mirror. When recording a verification pass, record what it MISSED and the blind-spot categories (cost multiples, version-pinned competitor comparisons, package-name references), not just the count corrected — future cycles scope themselves on the strength of that record. (2) The purge's own evidence scanner parsed markdown headings without tracking code fences, inventing a 150-line "section" from a template field label inside a fenced block, and flagging tiny single-purpose files on percentage thresholds — bad evidence that would have had the Warden trimming healthy skills. A dimension reviewer caught it only because it verified the evidence against the file instead of acting on the scan. Rule: evidence-collection scripts are part of the trusted base and get verified like any other claim; when a scan finding drives a destructive edit, open the file first.

**Apply when**: Scoping any review against a prior pass's coverage record; acting on any mechanical scan finding that would remove or trim content.

## A Reviewer Can Report Its Own Tool's Artifact as a Defect in the Thing Reviewed (2026-08-23)

**Learning**: A dimension reviewer reported several knowledge entries as truncated mid-sentence, citing exact line numbers. The entries were intact; the reviewer's file reader had truncated the long single-line bodies for display, and it mistook that for the file's content. Had the finding been applied, an implementer would have "repaired" finished sentences by inventing endings — corrupting the knowledge base in the name of cleaning it.

**Rule**: Any finding that claims content damage (truncation, corruption, missing text) must be verified against the raw bytes by the orchestrator before it reaches an applier, because its remedy is generative and therefore destructive when wrong. This is the same failure class the reviewed entry itself often describes: mistaking a proxy for the property.

**Apply when**: Any audit or review finding alleges truncation, corruption, or missing content in a source file — verify with a raw byte/line-length read before routing the finding to an applier.

**Forge-worthy**: yes — universal: a tool's own display truncation can masquerade as a defect in the reviewed content; content-damage claims need raw-file verification before acting.

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

## A Name-Based Leak Gate Misses Four Surfaces a Content Sweep Must Read by Hand (2026-10-08)

**Learning**: A gate that matches known names passes content that still identifies its source. Four surfaces escape it. (1) The gate's own comments and example identifiers, copied from the incident that motivated the rule. (2) Example rows in skill templates, which carry the author's handle. (3) Example vendor or provider lists: when every example comes from one country, the list reveals a single market. (4) Anonymised anecdotes, which pass every name check but still describe one product. Tells for (4): "Evidence:", "Field-observed", "at one gate", exact counts and durations beside product nouns, quoted project rules. Rewrite to the mechanism in the present tense and drop the count. Also verify the gate itself ran: a staged-mode check that resolves paths against the wrong root skips every file and reports success.

**Apply when**: Running a content-leak sweep, or after changing a purity gate. Read these four surfaces manually and confirm the gate's output shows files examined.

**Forge-worthy**: yes — universal: name matching is necessary but not sufficient for leak detection, and a gate that scans nothing reports the same success as one that found nothing.
