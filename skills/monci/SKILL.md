---
name: monci
description: Monitor CI — watches GitHub Actions runs on the current branch until complete. Use when user says "monci" or wants to watch CI without pushing.
user-invocable: true
---

# /monci — Monitor CI

Watch GitHub Actions runs on the current branch until all complete. No push — just observe.

## Arguments
`$ARGUMENTS` — optional filters (e.g., `/monci deploy`, `/monci e2e`)

## Step 1: Determine Scope

| Argument | Action |
|----------|--------|
| *(none)* | Show latest runs across all workflows |
| `e2e` / `ci` / `deploy` | Filter to that workflow only |
| A number (e.g., `12345`) | Drill into that specific run ID |
| A branch name | Filter runs to that branch |

## Step 2: Wait for Runs

If no recent runs exist on the current branch, poll up to 30 seconds (every 10s):
```
gh run list --branch <branch> --limit 3 --json databaseId,status,conclusion,workflowName,createdAt
```
Once at least one run appears, proceed. If none after 30s, report "No CI runs found" and stop.

## Step 3: Fetch Runs

Use `gh` CLI to query GitHub Actions:

- **List recent runs** (default: last 5 per workflow):
  ```
  gh run list --limit 10 --json databaseId,displayTitle,status,conclusion,headBranch,workflowName,createdAt,url
  ```
- **Filter by workflow**:
  ```
  gh run list --workflow <workflow>.yml --limit 5 --json databaseId,displayTitle,status,conclusion,headBranch,createdAt,url
  ```
- **Filter by branch**:
  ```
  gh run list --branch <branch> --limit 5 --json databaseId,displayTitle,status,conclusion,headBranch,workflowName,createdAt,url
  ```

## Step 4: Display Summary

Format as a clean table:

```
**Repo**: <owner/repo> | **Branch**: <branch>
```

| # | Workflow | Branch | Status | Duration | Commit | Link |
|---|----------|--------|--------|----------|--------|------|
| 1 | CI | master | ✅ pass | 2m 31s | `abc1234` Fix typo | [view](url) |
| 2 | E2E | master | ❌ fail | 8m 12s | `def5678` Add feature | [view](url) |
| 3 | Deploy | master | 🔄 running | 1m 05s | `abc1234` Fix typo | [view](url) |

Status icons:
- ✅ `success` / `skipped`
- ❌ `failure`
- 🔄 `in_progress` / `queued` / `waiting`
- ⚠️ `cancelled` / `timed_out`

## Step 5: Monitor In-Progress Runs

If ANY run is still `in_progress` or `queued`:
1. Tell the user: `CI running — will check again in 60s.`
2. Wait 60 seconds, then re-fetch and update the table.
3. Repeat until all runs complete or 10 minutes elapse (then stop and report current state).

## Step 6: Auto-Drill into Failures

If ANY run has `conclusion: failure`, automatically drill into it:

```
gh run view <run-id> --json jobs --jq '.jobs[] | select(.conclusion == "failure") | {name, conclusion, steps: [.steps[] | select(.conclusion == "failure") | {name, conclusion}]}'
```

Then show:

```
### ❌ Failed: <Workflow> — Run #<id>
**Job**: <job name>
**Failed step**: <step name>

<Fetch and show the last 40 lines of the failed step log>
```

Use this to fetch failed step logs:
```
gh run view <run-id> --log-failed 2>&1 | tail -40
```

## Step 7: Actionable Next Steps

End with a brief recommendation based on what you see:

- If **all green**: `All CI checks passing.`
- If **failure**: `Fix needed: <brief description of what failed>. Run locally: <relevant command>`
- If **still running after timeout**: `CI still running — run /monci to check again.`
- If **deploy failed**: `Deploy failed at <step>. Check secrets/permissions.`

## Rules
- Never run `gh` commands with `--json` fields that don't exist — stick to documented fields
- Always use `gh run list` first, then `gh run view` for details — never skip to view
- Show relative timestamps (e.g., "3 min ago", "2h ago") when possible
- If `gh` is not authenticated, tell the user to run `gh auth login`
