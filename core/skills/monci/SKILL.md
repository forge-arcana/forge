---
name: monci
description: Monitor CI — watches GitHub Actions runs on the current branch until complete. Use when user says "monci" or wants to watch CI without pushing.
---
<!-- model: haiku | polling via gh-poll.sh; no fan-out -->

# /monci — Monitor CI

Watch GitHub Actions runs on the current branch until all complete. No push — just observe.

## Arguments
`$ARGUMENTS` — optional filters (e.g., `/monci deploy`, `/monci e2e`)

## Primary Path: Automated Polling

Run `<forge>/core/scripts/gh-poll.sh --branch <branch>`, appending the scope flags from Step 1 (`--workflow <name>` to filter to one workflow, `--run <id>` to watch a specific run). The script waits for runs (30s timeout), polls every 60s (10min timeout), auto-drills into failures with logs, and outputs a structured markdown report. Use its output directly.

## Step 1: Determine Scope

| Argument | Action |
|----------|--------|
| *(none)* | No extra flags — latest runs across all workflows |
| `e2e` / `ci` / `deploy` | Pass `--workflow <name>` to filter to that workflow |
| A number (e.g., `12345`) | Pass `--run <id>` to drill into that specific run |
| A branch name | Pass `--branch <branch>` to filter runs to that branch |

## Manual Fallback

Only use if gh-poll.sh is missing or cannot run — scope filtering goes through the script's flags, not this path.

1. **Wait for runs** — Poll `gh run list --branch <branch> --limit 3 --json databaseId,status,conclusion,workflowName,createdAt` every 10s up to 30s. Stop if none found.
2. **Fetch runs** — `gh run list --limit 10 --json databaseId,displayTitle,status,conclusion,headBranch,workflowName,createdAt,url` (add `--workflow <name>.yml` or `--branch <branch>` to filter).
3. **Display summary** — Table with columns: Workflow, Branch, Status, Duration, Commit, Link. Status icons: ✅ success/skipped, ❌ failure, 🔄 in_progress/queued/waiting, ⚠️ cancelled/timed_out.
4. **Poll in-progress** — Re-fetch every 60s until all complete or 10min elapses.
5. **Drill into failures** — `gh run view <id> --json jobs --jq '.jobs[] | select(.conclusion == "failure")'` then `gh run view <id> --log-failed 2>&1 | tail -40`.
6. **Next steps** — All green: "All CI checks passing." Failure: describe what failed + local repro command. Timeout: "Run /monci to check again." Deploy fail: check secrets/permissions.

## Rules
- Never use `--json` fields that don't exist — stick to documented fields
- Always `gh run list` first, then `gh run view` for details — never skip to view
- Show relative timestamps (e.g., "3 min ago") when possible
- If `gh` is not authenticated, tell the user to run `gh auth login`
