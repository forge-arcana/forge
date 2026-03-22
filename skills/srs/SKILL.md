---
name: srs
description: Setup or update restart.sh to bring up the entire local dev stack. Proposes ports, kills zombies, checks DB, verifies port health. Use when user needs a local dev startup script.
user-invocable: true
---

# /srs — Setup Restart Script

Generate or update `restart.sh` and `kill-zombies.sh` in the **project root** (never in `scripts/` — these are dev-only utilities that must not pollute production directories or CI cron paths).

## Pre-Flight

1. **Check project readiness**: Verify `package.json` exists and dependencies are installed. If not, tell the user: "Project isn't ready to start. Run `pnpm install` first."
2. Read the project's `CLAUDE.md` and `package.json` to understand the stack
3. Read the stack guide: `<forge>/skills/forge/stack-guide.md` (resolve `<forge>` from `~/.claude/CLAUDE.md` `forge-path:` line, managed by `/cast`)
4. Scan for existing `restart.sh` — if found, read it and propose updates rather than overwriting
5. Read the `restart-template.sh` file in the same directory as this skill
6. Scan for `docker-compose.yml` or `compose.yml` to determine DB setup
7. Scan `packages/*/vite.config.ts` to identify Vite dev servers

## Step 1: Port Range Proposal

Propose ports based on project structure:

```
Proposed port layout:
  API server:    [BASE]     (e.g., 5000)
  Vite HMR #1:  [BASE+1]   (e.g., 5001) — [package name]
  Vite HMR #2:  [BASE+2]   (e.g., 5002) — [package name]
  ...
  PostgreSQL:    [BASE+N]   (e.g., 5005)
  E2E tests:    [BASE+100] (e.g., 5100)
```

- Check existing `.env`, `vite.config.ts`, and `docker-compose.yml` for already-defined ports
- If ports are already defined, use them. Only propose new ones for undefined services.
- **Ask the user** to confirm or change before generating the script

## Step 2: Generate restart.sh

Use the template from `restart-template.sh` (same directory as this skill) and customize for this project:

### Required sections (in order):

1. **Header**: Port layout documentation, usage instructions
2. **Port variables**: All ports as variables at the top for easy editing
3. **Process cleanup**: Kill processes on all project ports + orphaned node processes + stale Playwright browsers
4. **WSL2 port health check**: Python socket test to detect WFP blackholed ports
5. **DB readiness**: Docker compose up + pg_isready wait loop (skip if no Docker DB)
6. **Codegen**: Run any required codegen steps (paraglide, prisma generate, etc.)
7. **Start servers**: `pnpm dev` piped to `logs/dev.log`
8. **Startup summary**: Print which services are on which ports

### Process cleanup details:
- Kill by port using `fuser` (Linux) or `lsof` fallback
- Kill orphaned node processes: `node.*(vite|tsx|dev-server|playwright|vitest).*[PROJECT_NAME]`
- Kill stale Playwright browsers: `ms-playwright|playwright.*chromium|playwright.*firefox`
- Support `--dry-run` flag
- Support `--include-dev` flag to optionally kill the API port (safe-by-default: skip API)

### Vite HMR freshness:
- Never serve from `dist/` in dev — ensure no stale build artifacts interfere
- `mkdir -p logs` before starting to ensure log directory exists
- Pipe all output to `logs/dev.log` via `tee` for AI debugging access

### DB readiness:
```bash
if ! docker compose ps --status running 2>/dev/null | grep -q db; then
  docker compose up -d db
  until docker compose exec db pg_isready -U [user] -q 2>/dev/null; do
    sleep 1
  done
fi
```
- Timeout after 30s with error message
- Skip entirely if no `docker-compose.yml` or if using Neon/external DB

## Step 3: Also generate kill-zombies.sh

Use the template from `kill-zombies-template.sh` (same directory as this skill) and customize for this project.

A standalone cleanup script for use outside restart — dev servers (Vite, tsx, Playwright) sometimes leave orphan processes that hold ports open, causing "address already in use" on restart and flaky E2E tests:
- Kills all processes on project ports (skips API port by default for safety)
- Kills orphaned node processes matching project name
- Kills stale Playwright browsers
- `--dry-run` flag to preview without killing
- `--include-dev` flag to also kill the API server process
- Can be run independently (e.g., before E2E tests, or as part of CI pre-flight)

## Step 4: Verify

- Run `bash -n restart.sh` to syntax-check (project root)
- Run `bash -n kill-zombies.sh` to syntax-check (project root)
- Show the user the generated scripts and port layout
- Do NOT run the script automatically — let the user decide when to start
