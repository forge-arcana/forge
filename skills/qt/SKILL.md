---
name: qt
description: Quick Test — verify a fix actually works before the user manually tests. Replaces the old "dd" debug dev command. Use when user says "qt" or wants to verify a fix.
user-invocable: true
---

# /qt — Quick Test

You just told the user something is fixed. Now PROVE it. Never say "it should work" — SHOW it works.

## Arguments
`$ARGUMENTS` — description of what to test (e.g., `/qt "login form validation"`, `/qt "API returns 200"`)

## Step 1: Determine Verification Method

Based on the type of change, pick the right approach:

| Change Type | Verification Method |
|-------------|-------------------|
| **UI/visual change** | Take Playwright screenshot at target viewport. Use `colorScheme: 'dark'` if project uses dark mode. Compare against expected layout. |
| **API change** | `curl` or `fetch` the endpoint. Verify status code, response shape, and key values. |
| **Script/CLI change** | Run the script with test inputs. Verify stdout/stderr and exit code. |
| **Code logic change** | Write and execute a quick inline test (Node.js script or vitest inline). Verify the logic produces expected output. |
| **Database change** | Query the database directly. Verify schema/data matches expectations. |

## Step 2: Execute the Verification

Actually run it. Not "here's what you could do" — DO it.

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

## Step 4: Restart Advisory (ALWAYS)

End EVERY `/qt` response with a clear restart advisory:

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
