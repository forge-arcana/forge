---
name: pare
description: "The Pruner — cuts code a scope no longer needs without changing what it does, and records numbers on every pass. Proven cuts (dead files, unused exports, unused packages) come from tools and are applied one per commit on a side branch; judgement cuts (over-built layers) are proposed for one founder approval. Self-improving. TRIGGER when: user asks to prune, trim, slim down or remove dead code, unused exports or unused dependencies, says the code is bloated or over-built, or smith's pare hook fires."
---
<!-- model: sonnet | tool runs, one-cut commits and measuring at sonnet; the judgement-cut proposals and the final verdict at opus; the review that follows (/poke) carries its own tier -->

# /pare — The Pruner

> **Art** (learnings: `pare-learnings.md`) — follow the [Forge Protocol](../forge/protocol.md) for pre-flight and post-flight.

> Code nobody uses still costs: tokens to read, packages to patch, tests to run. Pare cuts it, and counts what the cut was worth.

`/pare` removes code a scope no longer needs, without changing what it does. Every pass writes a run record, so the ledger shows over time whether paring pays.

## Arguments

`$ARGUMENTS` — optional, in any order:
- **Scope** — a module, folder or repo path. Default: the repo root.
- `--coverage-floor N` — minimum test coverage in percent for cutting. Default 60.
- `--headless` and `--out <absolute dir>` — see Mode.

## Mode

- **Headless** when env `FORGE_HEADLESS=1` or `--headless` is given. Follow Headless Mode in the [Forge Protocol](../forge/protocol.md): never ask, record decisions in `$FORGE_OUT/decisions.md`, no commit, no branch, no web. Pare reads and measures only. It writes the proposed cut list (proven and judgement, with evidence) to `$FORGE_OUT/pare-cuts.md` and applies nothing. If the output directory is missing, write nothing to the repo, print `pare: an output directory is required in headless mode (--out <abs dir> or FORGE_OUT)`, and stop.
- **Interactive** otherwise.

## What Pare Cuts

Two kinds of cut, counted separately in every record.

- **Proven cuts** — found by a tool, not by opinion: dead files, unused exports and types, unused packages. Applied automatically.
- **Judgement cuts** — over-built layers: needless wrappers, single-use interfaces, pass-through classes. Pare lists them as proposals with evidence (the call sites, the single use). They are never applied on pare's own say-so.

### Tools

| Language | Tools |
|----------|-------|
| JS / TS | `knip` |
| Python | `vulture`, `ruff` (F401 unused import, F841 unused variable), `deptry` |
| Anything else | None. The scope is report-only (no_tool) |

Pass `--version` of each tool used into the record's `tools`. A tool that is not installed is a gap, not a reason to guess: report it, and cut nothing that tool would have vouched for.

### Never cut

- Public exports of a published package
- Framework entry files (routes, pages, handlers, config files the framework loads)
- Anything loaded by name at runtime: reflection, plugin registries, string imports, dependency injection
- Generated code
- Test fixtures

If a tool flags one of these, leave it and list it under "left and why".

**Never edit a tool's config or ignore list to make a finding disappear.** That is the config_changed guard. If a finding is a false positive, leave the code and say so in the output.

## Phase 0: Pre-Flight

Follow the [Forge Protocol](../forge/protocol.md) pre-flight. In headless mode, learnings go to `$FORGE_OUT/learnings/pare-learnings.md`, and `$FORGE_OUT/decisions.md` is created as the protocol says.

Also set started_at (UTC) and note the commit you start from (commit_before).

## Phase 1: Gates

Decide whether this pass may cut. If any gate fails, the pass is **report-only**: run the tools, list what they find, cut nothing, and still write the run record with the reason.

0. **Clean tree, attached HEAD.** Run before the tests. If `git symbolic-ref -q HEAD` fails (detached HEAD), stop and say so; do not start. If `git status --porcelain` prints anything: report-only, `report_only_reason: dirty_tree`. Never start on a dirty tree.
1. **Tests green.** Run the project's test command. If red: `report_only_reason: tests_red`. Pare never prunes a red tree.
2. **Coverage.** Record coverage_pct from the project's coverage tool. Below the floor: low_coverage. A test suite that does not cover the code cannot vouch for a cut.
3. **A tool exists** for the scope's language. If none: no_tool.
4. **Commit authority.** Inside `/smith` it rides smith's authority. Standalone, ask once at the start with `AskUserQuestion`: "Let pare commit cuts on its own side branch for this pass?" with options Yes / Report only. Report only: the pass is report-only.

If coverage cannot be read, record `coverage_pct: null` and treat it as low_coverage.

## Phase 2: Measure Before

```
python3 -I <forge>/core/scripts/pare-measure.py --repo <abs repo> --scope <rel scope> [--build CMD] [--test CMD] [--typecheck CMD] [--test-count CMD] [--bundle <rel build output>]
```

Pass the project's real build, test, type-check and test-count commands. The `--test-count` command must print only the count (e.g. `pytest --collect-only -q | grep -c '::'`). It prints `{"metrics": {...}, "advisory_ids": [...], "tools": {...}, "missing": [...]}`: repomix source tokens, direct package count, osv-scanner advisories, hyperfine medians of 3, the test count and the bundle size, all inside `metrics`. A measure it cannot read is `null`, never 0. Keep the whole object as `before`; `missing` lists tools it could not run.

## Phase 3: Find

Run the language's tools over the scope. Sort every finding into one of three piles:

1. **Proven** — a tool flagged it and it is not on the never-cut list. Counts toward `cuts.proven.candidates`.
2. **Judgement** — an over-built layer you can show with evidence. Counts toward `cuts.judgement.candidates`.
3. **Left** — flagged but protected, or a false positive. Keep the reason for each.

## Phase 4: Cut Proven (side branch)

Skip in headless and report-only passes.

1. Create the side branch `pare/<YYYY-MM-DD>-<n>`, where n = 1 + the count of existing `pare/<YYYY-MM-DD>-*` branches (`git branch --list 'pare/<date>-*'`). Create it with `git switch -c <name>`; if that fails, stop. Never cut on the main branch.
2. For each proven cut, in order:
   - Check you are on the side branch (`git branch --show-current` equals the name) before every commit. If not, stop.
   - Make **one cut per commit**. A source edit touches **at most one source file**. A file deletion is also **one file per commit**: the commit gate (`core/hooks/arts-gate.sh`) does not count deletions, so this rule is what keeps them reviewable. A package removal touches manifests only.
   - Stage with `git add -- <the cut's own paths>` only. Never `git add -A`, `-a` or `.`.
   - Commit it with a message that says what was removed and the evidence ("unused export `x` in `mod`, knip").
   - Run tests, type-check and build.
   - On any failure: `git revert --no-edit <sha>` of the failing cut only, count it as reverted, move on.
3. Commit authority comes from Gate 4 (smith's authority, or the founder's yes). Pare commits only on its own side branch and nowhere else.

## Phase 5: Propose Judgement Cuts

List every judgement cut as a numbered proposal: what it is, the evidence, the lines it removes, the risk. Put them in **one batch** for the pass and ask once with `AskUserQuestion` (multi-select, recommended items first). Headless: list them in `$FORGE_OUT/pare-cuts.md`, apply none.

Apply each approved one as **one commit** spanning the wrapper and all its call sites, staged with `git add -- <those paths>`. That exceeds the one-source-file gate, so commit it with `FORGE_ARTS_SKIP='pare judgement cut <n>, founder-approved; /poke reviews in Phase 7'` set for that commit, and tell the user the skip in the output. Same rule as a proven cut: check the branch first, then tests, type-check and build, and `git revert --no-edit <sha>` of that cut on failure. Count `proposed`, `approved`, `kept`, `reverted`.

## Phase 6: Measure After and Guard

Run `pare-measure.py` again with the same arguments. Keep the object as `after`. Then set the guards:

- tests_green_after — tests, type-check and build all pass on the final branch tip.
- test_count_drop — the test count after is lower than before. Pare cuts code, not tests. A drop means a cut took a test with it: look before going on.
- config_changed — compute it, do not judge it. Run `git diff --name-only <commit_before> <branch tip> -- 'knip.json' 'knip.jsonc' '.knip*' 'knip.config.*' '.vulture*' 'whitelist*.py' 'ruff.toml' '.ruff.toml' 'deptry*'`, and compare the `[tool.ruff]`, `[tool.vulture]` and `[tool.deptry]` tables in `pyproject.toml` and the `"knip"` key in `package.json` between the two commits. Any change: true. It must be false.

A red guard is reported loudly in the output and left in the record.

## Phase 7: Review and Merge

`/pare` is not an evaluative art and does **not** call `forge-art-record.sh`. After the pass, run `/poke` scoped to the pared diff (poke records its own run), fix what it finds, then propose `/wrap`. The side branch merges only through `/wrap` with the founder's yes, and is deleted after the merge with `git branch -d` (never `-D`). If the founder declines the merge, first list in the output the commits that will be lost (`git log --oneline <main>..<branch>`), then delete with `git branch -D`. Headless: no review, no merge; go straight to Phase 8.

## Phase 8: Record

Write the record once the merge is resolved, so it can carry the merge commit. Never skip it: if the session is about to end before `/wrap` resolves, write the record anyway with commit_after null, then stop.

Build one JSON run record (schema v1; the field list is in the docstring of `core/scripts/pare-ledger.py`) and pipe it in:

```
python3 -I <forge>/core/scripts/pare-ledger.py run
```

Fill it so it can be checked:
- `trigger`: `smith`, `patch` or `standalone`
- `ts`: the moment the record is written. The pass's cost window is started_at to ts, so it includes the review.
- commit_after: the merge commit on the main branch; `null` when the founder declined, when nothing was cut, or when the session ends before `/wrap`. Inside `/smith`, write the record after smith's hardening `/wrap` commit, with commit_after = that commit. The 30-day regret check needs this merge commit on main.
- removed_items: names only — removed file paths, export names with their module, package names. Never contents.
- `repo`: the repo's realpath (`realpath <repo>`); it must equal the allow-list key exactly
- `scope`: repo-relative
- `session`: the harness session id (Claude Code: env `CLAUDE_CODE_SESSION_ID`)
- `before` / `after`: copy `metrics` from each measure output. Merge each output's `tools` into the record's `tools`.
- `advisory_ids_removed` = sorted(set(before `advisory_ids`) − set(after `advisory_ids`))
- `pass_seconds` = ts − started_at
- `config_changed`: the value computed in Phase 6
- `report_only` and `report_only_reason` (null if and only if the pass could cut). `report_only == (outcome == report_only)`. Report-only passes have kept = 0. The reason is one of: low_coverage, no_tool, tests_red, dirty_tree.
- `outcome`: `completed`, `report_only`, `aborted` or `failed`
- Removed counts equal the lengths of the `removed_items` lists.

The ledger lives outside the repo, `${FORGE_PARE_LEDGER:-$XDG_STATE_HOME/forge/pare/runs.jsonl}`. If the writer exits non-zero, show its message and fix the record. Never write the file by hand. Headless: validate the record first with `FORGE_PARE_LEDGER=off python3 -I <forge>/core/scripts/pare-ledger.py run < record`, then write the same record to `$FORGE_OUT/pare-run.json` with commit_after null. Do not write to the real ledger.

## Benchmark (monthly, separate from a pass)

Token counts show size. They do not show whether an agent works better on the pared code. Once a month, measure that:

```
python3 -I <forge>/core/scripts/pare-bench.py --repo <abs repo> --tasks <tasks.json> --pre <sha> --post <sha> --pass-ts <ts>
```

It runs 3 to 5 fixed read-only agent tasks on the code before the pass, after it, and before again (the noise floor), 3 or more runs each, and records the tokens to the bench ledger. `--pass-ts` is the `ts` of the credited run record. The agent runs confined: read-only built-in tools, no MCP servers, no hooks, no saved session.

Tasks file format, 3 to 5 tasks:

```
{"tasks": [{"id": "<slug>", "prompt": "<str>", "check": "<bash cmd or null>"}]}
```

Rules for the tasks:
- Choose them **before** the pass, so the pass cannot be tuned to them.
- Each touches the pared scope.
- The task file lives on the box, outside the forge and outside the repo.
- A `check` reads the agent's answer on stdin, runs in an empty temp dir, and must not touch git or the repo. `null` means no check.

## Feed

`core/scripts/pare-scan.py` derives a daily snapshot from the two ledgers: months, measures, bench and passes tables. It reports integers and project slugs from a box-local allow-list at `${XDG_CONFIG_HOME}/forge/pare/projects.json`. The dashboard computes the verdict; the box sends facts only. Lines removed is context, never the verdict.

## Prior Art

Tools, not hand-rolled counters: knip (JS/TS), vulture, ruff and deptry (Python), osv-scanner (advisories), repomix (tokens), hyperfine (timings). The method follows automated deletion with human review at scale: Google's Sensenmann and Meta's SCARF.

## Output

Report, interactive or in the headless result:
- **Removed** — by kind (proven files, exports, packages; judgement cuts approved and kept), with counts
- **Left, and why** — protected, false positive, or tool gap
- **Reverted** — each reverted cut and what broke
- **Guards** — tests_green_after, test_count_drop, config_changed
- **Before / after** — tokens, packages, advisories, build, test and type-check times, test count
- **Report-only** — the reason, when the pass could not cut
- **Review** — `/poke` result on the pared diff, and whether `/wrap` merged it
- **Ledger written** — yes or no (and why not)

## Post-Flight

Follow the [Forge Protocol](../forge/protocol.md) post-flight, writing learnings to `memory/pare-learnings.md` (headless: `$FORGE_OUT/learnings/pare-learnings.md`). Capture:
- False positives per tool and the pattern that caused them (so the never-cut list grows)
- Cuts that passed their tests but broke at runtime
- Scopes where coverage or tool gaps made the pass report-only
- Judgement proposals the founder declined, and why
