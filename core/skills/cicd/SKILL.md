---
name: cicd
description: "Local CI/CD pipeline — lint, typecheck, test, build, deploy. Auto-fixes failures, escalates to /pry if stuck. No GitHub Actions needed for solo dev. TRIGGER when: user wants to run tests and deploy, or asks 'is this ready to deploy?'"
---
<!-- model: sonnet | escalate: stuck failures → /pry at opus; pre-deploy auto-fix review → opus -->

# /cicd — Local CI/CD Pipeline

Run the full CI/CD pipeline locally. No GitHub Actions runners, no YAML, no waiting. Failures get auto-fixed in real-time.

## Arguments

`$ARGUMENTS` — optional flags:
- `--ci` — CI only (lint → typecheck → test → build). No deploy.
- `--cd` — Deploy only. Skips CI — trusts the last successful run.
- `--env <name>` — Target environment (default: `staging`). Production requires explicit `--env production`.

No flags = full pipeline (CI then CD if CI passes).

## Step 0: Detect Project Pipeline

Auto-detect from `package.json` scripts and project structure:

| Detection | Source | CI Step |
|-----------|--------|---------|
| Linter | `lint` script in package.json | `npm run lint` / `pnpm lint` |
| Type checker | `tsconfig.json` exists | `tsc --noEmit` (or `typecheck` script) |
| Unit tests | `test` script, vitest/jest config | `npm test` / `pnpm test` |
| E2E tests | `playwright.config.*`, `e2e/` dir | `npx playwright test` |
| Build | `build` script in package.json | `npm run build` / `pnpm build` |
| Monorepo | `pnpm-workspace.yaml` | Run steps per package in dependency order |

For monorepos, detect package dependency order and run CI bottom-up: shared → database → server → web/client apps.

## Step 1: Pre-Flight

Before running the pipeline:

1. **Kill zombies**: Run `dev/kill-zombies.sh` if it exists (or kill processes on known ports)
2. **Check DB**: If project has a database package, verify DB is reachable
3. **Fresh state**: If schema changed since last build, rebuild/push schema first
4. **Environment check**: Verify deploy credentials exist for the target environment (don't run 10 minutes of CI only to fail at deploy)

If `--cd` flag: skip to Step 3 (Deploy).

## Step 2: CI Pipeline

Run each step sequentially. Stop on first failure.

```
lint → typecheck → unit tests → E2E tests → build
```

### On Failure: Auto-Fix Loop

When a step fails:

1. **Auto-fix attempt**: Fix the issue directly.
   - Lint errors: run `lint --fix`, fix remaining manually
   - Type errors: read the error, fix the type issue
   - Test failures: read the failure output, fix the test or the code
   - Build errors: read the error, fix the issue
2. **Re-run the failed step only** (not the entire pipeline)
3. **If still failing**: invoke `/pry` on the specific failure via an opus-tier subagent — a blocker that survived a fix attempt needs the stronger tier
   - `/pry` decomposes the blocker, searches for alternatives, reframes the problem
   - If `/pry` resolves it: re-run the **entire pipeline from Step 1** (full CI — a fix may break earlier steps)
4. **If `/pry` can't resolve**: stop and report to user with full context

### CI Report

After CI completes (pass or fail), output:

```
## CI Report — [PROJECT NAME]

| Step | Result | Duration |
|------|--------|----------|
| Lint | pass | 2s |
| Typecheck | pass | 4s |
| Unit tests | pass (47/47) | 8s |
| E2E tests | pass (12/12) | 45s |
| Build | pass | 12s |

**CI Status**: PASS — ready to deploy
```

If `--ci` flag: stop here. Do not deploy.

## Step 3: Deploy

### Auto-Fix Review Gate

If the auto-fix loop changed any code, spawn an opus-tier subagent to review the accumulated auto-fix diff before deploying — the deterministic re-run proves the steps pass, not that each fix is legitimate (a weakened test assertion passes silently). If your harness can't spawn a subagent at a chosen tier, present the accumulated diff to the user for approval before deploying — defer the review, don't downgrade it.

### Environment Gate

**HARD RULE**: Production deploys require explicit `--env production`. Never default to production.

Before deploying, confirm the target:

- `staging` (default): deploy without confirmation
- `production`: ask the user — using your harness's multi-choice prompt if available, otherwise inline — "Deploying to PRODUCTION. Confirm?" with options "Yes, deploy" / "Abort"

### Auto-Detect Deploy Target

Scan for deploy configuration (container-first — Cloud Run and Cloudflare Containers are co-equal defaults; match by whichever signals are present, don't privilege the first row):

| Signal | Platform | Deploy Command |
|--------|----------|----------------|
| `Dockerfile` + `deploy.yml` with Cloud Run | GCP Cloud Run | `gcloud run deploy` |
| `Dockerfile` (standalone) | Docker-based (ask user) | `docker build && docker push` |
| `vercel.json` or `.vercel/` | Vercel | `vercel deploy` / `vercel --prod` |
| `netlify.toml` or `.netlify/` | Netlify | `netlify deploy` / `netlify deploy --prod` |
| `fly.toml` | Fly.io | `fly deploy` |
| `wrangler.toml` / `wrangler.jsonc` | Cloudflare (Workers / Containers) | `wrangler deploy` |
| `railway.json` / `railway.toml` | Railway | `railway up` (or git push) |
| `config/deploy.yml` + `.kamal/` | Kamal self-host (e.g. Hetzner) | `kamal deploy` |
| `render.yaml` | Render | `render deploy` (or git push) |
| `appspec.yml` | AWS | Platform-specific |
| `firebase.json` | Firebase | `firebase deploy` |
| None found | — | Ask user for deploy instructions |

On first run, confirm the detected platform with the user. If multiple signals detected, ask which to use.

### Non-Production Bot Protection

For staging/preview deploys, verify bot protection is in place:
- GCP Cloud Run: `--no-allow-unauthenticated` flag
- Other platforms: check for equivalent access controls
- Warn if deploying to non-production without bot protection

### Deploy Execution

1. Run the platform-specific deploy command
2. Wait for deployment to complete
3. Run a smoke test if a health check URL is known (curl the endpoint)
4. Report result

### CD Report

```
## CD Report — [PROJECT NAME]

| Aspect | Detail |
|--------|--------|
| Platform | Cloud Run |
| Environment | staging |
| URL | https://myapp-staging-abc123.run.app |
| Status | LIVE |
| Smoke test | pass (200 OK in 340ms) |
| Bot protection | --no-allow-unauthenticated |

**Deploy Status**: SUCCESS
```

## Step 4: Summary

Output the combined CI/CD result:

```
## CI/CD Complete — [PROJECT NAME] | YYYY-MM-DD

CI: PASS (5/5 steps, 0 auto-fixes)
CD: DEPLOYED to staging
URL: https://...

Auto-fixes applied: 0
/pry escalations: 0
```
