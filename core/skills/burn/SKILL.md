---
name: burn
description: 'Token Burn — per-session token + cost report read from the harness''s own transcripts. Use when the user types "burn", asks "how many tokens did this cost?", or wants to measure token spend before/after an optimization.'
---
<!-- model: haiku | burn-status.sh does the work; no fan-out -->

# /burn — Token Burn

Per-session token-and-cost report, read straight from the harness's on-disk session transcripts. Zero external deps — no OTEL backend, no API key, no third-party binary. This is the **measurement instrument**: run it before and after any token-saving change to prove the delta is real (vendor "60-90%" claims are self-measured; this measures *your* sessions).

No prose preamble — just run the script and present the table.

## Steps

1. **Run the engine.** Invoke `<forge>/core/scripts/burn-status.sh` against the target:
   - `burn-status.sh <project-path>` — all sessions for one project (default: cwd)
   - `burn-status.sh <project-path> --today` — only today's sessions
   - `burn-status.sh <project-path> --session latest` — the current/most-recent session
   - `burn-status.sh --all` — every project under the membrane

2. **Present the table verbatim** — including its `**Profile**:` line. The script computes the dominant-cost-column read (Output- / Cache-Write- / Cache-Read-dominated) and the matching lever itself; do not re-derive or re-compare the numbers, just relay it.

3. **If the user is comparing before/after** an optimization (Path B lean scripts, Tier-1 `lean.sh`, etc.): run `burn-status.sh <project-path> --compare <before-session> <after-session>` (session = uuid prefix or `latest`) and present its delta table verbatim — the arithmetic is script tier. Output tokens are the honest spend signal; cache-read deltas flatter the numbers.

## Notes & Caveats

- **Cost is an estimate.** The price table lives in `price_for` inside `burn-status.sh`; unknown models fall back to the Opus tier (conservative-high). Correct it when Claude pricing changes.
- **Coupling.** The script reads Claude Code's transcript layout (`~/.claude/projects/<encoded-path>/<uuid>.jsonl`). On other harnesses it degrades to "no transcripts found" rather than erroring. If forge later validates another harness's transcript format, abstract the locate + jq step rather than forking the skill.
- **The biggest burn forge can't see here is the fan-out multiplier.** `/burn` measures whole sessions; it does not attribute spend to individual subagents spawned by `/poke`, `/pound`, `/smith`. When a fan-out art runs, expect Output + Cache-Write to spike — that's the multiplier the lean-evidence work (Path B) targets.

## Post-Flight

This is a task skill, not an art — no learning loop. If a run surfaces a reusable insight about *where* burn concentrates, write it to the membrane for `/forge` to absorb (per the HARD RULE), don't edit forge directly from a project context.
