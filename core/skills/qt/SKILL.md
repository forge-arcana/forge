---
name: qt
description: Quick Test — verify a fix actually works before the user manually tests. Use when user says "qt" or wants to verify a fix.
---
<!-- model: sonnet | evidence-backed verdicts; no fan-out -->

# /qt — Quick Test

You just told the user something is fixed. Now prove it: show evidence, not "it should work".

## Arguments
`$ARGUMENTS` — description of what to test (e.g., `/qt "login form validation"`, `/qt "API returns 200"`)

## Step 0: Logs First

Apply the Logs First rule to the fix itself: reproduce, read the newest log output (dev.log, console, Cloud Logging, CI logs; filter by PID or timestamp), and if it shows errors (stack traces, failed assertions, unexpected status codes, constraint violations) report FAIL with that evidence. Clean logs mean proceed to Step 1 for final proof. This holds for your own fix, a user's bug report, or someone else's claim that it's fixed.

## Step 1: Determine Verification Method

Based on the type of change, pick the right approach:

| Change Type | Verification Method |
|-------------|-------------------|
| **UI/visual change** | Playwright screenshot per the Visual Changes rule; compare against the expected layout. |
| **API change** | `curl` or `fetch` the endpoint. Verify status code, response shape, and key values. |
| **Script/CLI change** | Run the script with test inputs. Verify stdout/stderr and exit code. |
| **Code logic change** | Write and execute a quick inline test (Node.js script or vitest inline). Verify the logic produces expected output. |
| **Database change** | Query the database directly. Verify schema/data matches expectations. |

## Step 2: Execute the Verification

- For Playwright: write a quick script, run it, capture screenshot
- For curl: execute the request, show the response
- For scripts: run with representative input
- For code: write a small test file, execute it, show output

## Step 3: Report Result

**PASS**: Show the evidence (screenshot path, response body, test output).
```
PASS — [what was verified]
Evidence: [screenshot/output/response]
```

**FAIL**: Show what went wrong and what you see.
```
FAIL — [what was expected vs what happened]
Evidence: [actual output]
Next step: [what to investigate]
```

**Evidence contract (hard)**: no PASS without the raw artifact embedded in the report — the screenshot path, command output, or response body itself. Absence of evidence = automatic FAIL. The full report, evidence included, goes straight to the user — their read of the evidence is the review gate; a verdict takes effect only after they've seen the proof.

## Step 4: Restart Advisory

End every `/qt` response with a clear restart advisory:

```
Restart required: YES / NO
   Process: [which — API server, Vite dev, both, none]
   Reason: [why — e.g., "env var change requires full restart" / "HMR will pick up component changes" / "server-side code changed, need to restart API"]
```

Rules for restart determination:
- **No restart**: CSS-only changes, React component changes (HMR), static asset changes
- **Vite restart**: vite.config.ts changes, new dependencies added, plugin changes
- **API restart**: server-side route/middleware changes, env var changes, database schema changes
- **Both**: shared package changes, monorepo dependency changes, TypeScript config changes
