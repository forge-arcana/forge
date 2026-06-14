---
name: ponci
description: Push to remote and monitor CI — pushes current branch, then invokes /monci to watch GitHub Actions. Use when user says "ponci" or wants to push and watch CI.
---
<!-- model: haiku -->

# /ponci — Push & Monitor CI

Push to remote, then hand off to `/monci` for monitoring. No prose — just push + status.

## Arguments
`$ARGUMENTS` — optional filters passed through to `/monci` (e.g., `/ponci deploy`, `/ponci e2e`)

## Step 1: Push to Remote

1. Confirm which branch we're on and show the commits that will be pushed:
   ```
   git log origin/<branch>..HEAD --oneline
   ```
2. Push:
   ```
   git push origin <branch>
   ```
3. If there are multiple repos with staged commits (e.g., a docs repo), push those too.
4. If push fails, report the error and stop.

## Step 2: Invoke /monci

After a successful push, invoke the `/monci` skill with the same `$ARGUMENTS` to monitor CI.

`/monci` will handle waiting for runs to appear, displaying the status table, monitoring in-progress runs, and drilling into failures.
