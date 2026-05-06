#!/usr/bin/env bash
# gh-poll.sh — CI polling for /monci, /ponci
# Usage: gh-poll.sh [--branch <branch>] [--workflow <name>] [--run <id>] [--timeout <seconds>]
# Polls GitHub Actions until complete, outputs structured markdown
set -euo pipefail

BRANCH=""
WORKFLOW=""
RUN_ID=""
TIMEOUT=600
INTERVAL=60

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch) BRANCH="$2"; shift 2 ;;
    --workflow) WORKFLOW="$2"; shift 2 ;;
    --run) RUN_ID="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# Default to current branch
if [[ -z "$BRANCH" ]]; then
  BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
fi

# Check gh is authenticated
if ! gh auth status &>/dev/null; then
  echo "ERROR: gh is not authenticated. Run \`gh auth login\` first."
  exit 1
fi

REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || echo "unknown")

echo "## CI Monitor"
echo "**Repo**: $REPO | **Branch**: $BRANCH"
echo ""

# Build gh run list command
GH_CMD="gh run list --branch $BRANCH --limit 5 --json databaseId,displayTitle,status,conclusion,headBranch,workflowName,createdAt,url"
if [[ -n "$WORKFLOW" ]]; then
  GH_CMD="gh run list --workflow $WORKFLOW --branch $BRANCH --limit 5 --json databaseId,displayTitle,status,conclusion,headBranch,workflowName,createdAt,url"
fi

# If specific run ID, just watch that
if [[ -n "$RUN_ID" ]]; then
  GH_CMD="gh run view $RUN_ID --json databaseId,displayTitle,status,conclusion,headBranch,workflowName,createdAt,url,jobs"
fi

# Wait for runs to appear (poll up to 30s)
WAIT_ELAPSED=0
while [[ $WAIT_ELAPSED -lt 30 ]]; do
  RUNS=$(eval "$GH_CMD" 2>/dev/null || echo "[]")
  RUN_COUNT=$(echo "$RUNS" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d) if isinstance(d,list) else 1)" 2>/dev/null || echo "0")

  if [[ "$RUN_COUNT" -gt 0 ]]; then
    break
  fi

  sleep 10
  WAIT_ELAPSED=$((WAIT_ELAPSED + 10))
done

if [[ "$RUN_COUNT" -eq 0 ]]; then
  echo "No CI runs found for branch \`$BRANCH\` after 30s."
  exit 0
fi

# Poll loop
ELAPSED=0
while [[ $ELAPSED -lt $TIMEOUT ]]; do
  RUNS=$(eval "$GH_CMD" 2>/dev/null || echo "[]")

  # Format as table
  echo "| # | Workflow | Status | Conclusion | Title | Run ID |"
  echo "|---|----------|--------|------------|-------|--------|"

  python3 -c "
import json, sys
data = json.load(sys.stdin)
if not isinstance(data, list):
    data = [data]
icons = {'success': 'pass', 'failure': 'FAIL', 'cancelled': 'cancelled', 'skipped': 'skipped', 'in_progress': 'running', 'queued': 'queued', 'waiting': 'waiting', '': 'running'}
for i, run in enumerate(data, 1):
    status = run.get('status', '')
    conclusion = run.get('conclusion', '') or ''
    icon = icons.get(conclusion, icons.get(status, '?'))
    wf = run.get('workflowName', '?')
    title = run.get('displayTitle', '?')[:40]
    rid = run.get('databaseId', '?')
    print(f'| {i} | {wf} | {status} | {icon} | {title} | {rid} |')
" <<< "$RUNS" 2>/dev/null || echo "| ? | Error parsing runs | | | | |"

  echo ""

  # Check if all complete
  ALL_DONE=$(python3 -c "
import json, sys
data = json.load(sys.stdin)
if not isinstance(data, list):
    data = [data]
active = [r for r in data if r.get('status') in ('in_progress', 'queued', 'waiting')]
print('yes' if len(active) == 0 else 'no')
" <<< "$RUNS" 2>/dev/null || echo "no")

  if [[ "$ALL_DONE" == "yes" ]]; then
    break
  fi

  echo "CI running -- checking again in ${INTERVAL}s..."
  echo ""
  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
done

# Check for failures and auto-drill
FAILURES=$(python3 -c "
import json, sys
data = json.load(sys.stdin)
if not isinstance(data, list):
    data = [data]
for run in data:
    if run.get('conclusion') == 'failure':
        print(run.get('databaseId', ''))
" <<< "$RUNS" 2>/dev/null || true)

if [[ -n "$FAILURES" ]]; then
  echo "## Failed Runs"
  echo ""
  for run_id in $FAILURES; do
    echo "### Run #$run_id"
    echo ""

    # Get failed jobs
    echo "**Failed jobs:**"
    echo '```'
    gh run view "$run_id" --json jobs --jq '.jobs[] | select(.conclusion == "failure") | {name, conclusion, steps: [.steps[] | select(.conclusion == "failure") | {name, conclusion}]}' 2>/dev/null || echo "(could not fetch job details)"
    echo '```'
    echo ""

    # Get failed logs
    echo "**Failed step logs (last 40 lines):**"
    echo '```'
    gh run view "$run_id" --log-failed 2>&1 | tail -40 || echo "(could not fetch logs)"
    echo '```'
    echo ""
  done
fi

# Summary
echo "## Result"
HAS_FAIL=$(python3 -c "
import json, sys
data = json.load(sys.stdin)
if not isinstance(data, list):
    data = [data]
fails = [r for r in data if r.get('conclusion') == 'failure']
passes = [r for r in data if r.get('conclusion') == 'success']
active = [r for r in data if r.get('status') in ('in_progress', 'queued', 'waiting')]
if active:
    print('RUNNING')
elif fails:
    print('FAILED')
else:
    print('PASSED')
" <<< "$RUNS" 2>/dev/null || echo "UNKNOWN")

case "$HAS_FAIL" in
  PASSED) echo "All CI checks passing." ;;
  FAILED) echo "CI has failures. See details above." ;;
  RUNNING) echo "CI still running after ${TIMEOUT}s timeout. Run \`/monci\` to check again." ;;
  *) echo "Could not determine CI status." ;;
esac
