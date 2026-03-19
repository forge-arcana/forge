# Forge Conventions Checklist

> Distilled from `skills/forge/claude-code-rules.md`. Used by `/cast` to verify project compliance.

## Required in Every Project

### 1. CLAUDE.md at Project Root
- [ ] Exists
- [ ] Hard rules live in global `~/.claude/CLAUDE.md` — do NOT duplicate in project CLAUDE.md
- [ ] Has Stack section (frameworks, DB, hosting)
- [ ] Has Shorthand Commands section (wawa → /wawa, wrap → /wrap)
- [ ] Has Current Context section (updated by /wrap)
- [ ] Under 20k chars (compacted by /wrap)

### 2. .claude/settings.json (only if project-specific overrides needed)
- [ ] Global `~/.claude/settings.json` handles all standard permissions — no per-project file needed by default
- [ ] If project needs extra env var prefixes, hooks, or domain restrictions: create per-project file with overrides only
- [ ] Destructive commands NOT in allow list (rm, git push, git reset, git clean, git restore)

### 3. Directory Structure
- [ ] `memory/` directory exists (for learnings, context overflow)
- [ ] `logs/` directory exists (if project has running services — for dev.log, browser console forwarding)
- [ ] `docs/` directory exists (if project has documentation)

### 4. Workflow Rules
- [ ] Plan mode for non-trivial tasks (3+ steps or architectural decisions)
- [ ] Subagent usage for research and parallel analysis
- [ ] Self-improvement loop (corrections → update learnings)
- [ ] Verification before done (tests, logs, demonstrate correctness)
- [ ] Logs-first debugging (never speculate from code alone)

### 5. Testing
- [ ] E2E pre-flight: kill zombies → check DB → fresh state
- [ ] E2E debugging: fix individual tests before re-running full suite
- [ ] Visual changes require Playwright screenshots

### 6. Logging
- [ ] Human-initiated actions logged with context
- [ ] Pre-action intent logged
- [ ] No pulsing/repeated action logs
- [ ] No sensitive data in logs
- [ ] Dev: verbose, Production: sparse
- [ ] Browser console → logs/dev.log (dev only)

### 7. Dev Stack
- [ ] restart.sh exists (or suggest /srs)
- [ ] kill-zombies.sh exists (or suggest /srs)
- [ ] Port layout documented
