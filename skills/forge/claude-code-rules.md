# Claude Code — Global Rules

These are the global instructions configured in `~/.claude/CLAUDE.md` that apply to **every project** Claude Code works on. They define workflow patterns, communication style, debugging discipline, and quality standards.

---

## HARD RULE — No Command Chaining in Bash — EVER

> **NEVER use `&&`, `;`, or `||` to chain commands in a single Bash tool call.**
> This applies to the main agent AND all subagents. Zero exceptions. Zero tolerance.

This is the **first rule** because Claude has repeatedly violated it. It must be internalized before any work begins.

- `git -C <path> <cmd>` for git commands in other directories
- Separate Bash tool calls for everything else
- When spawning subagents, copy this rule verbatim into the prompt

See [Bash Permissions](#bash-permissions--avoiding-prompts) for details and examples.

---

## HARD RULE — No Auto-Commit

> **NEVER commit automatically after completing any sprint, phase, or piece of work.**
> Always ask the user: "Ready to wrap up? Run `/wrap` to commit with full context."

This ensures the full pre-commit ritual (learnings, context, docs, lint, compact) always runs before any commit.

---

## Workflow Orchestration

### 1. Plan Mode Default

Claude enters **plan mode** for any non-trivial task (3+ steps or architectural decisions). This means it writes a detailed spec before touching code. If something goes wrong mid-task, it stops and re-plans rather than pushing forward blindly. Plan mode is also used for verification steps — not just building.

### 2. Subagent Strategy

Complex work is parallelized using **subagents** — lightweight child contexts that handle focused subtasks (research, exploration, analysis) without polluting the main conversation window. Each subagent gets one task. This keeps context clean and lets Claude throw more compute at hard problems.

### 3. Self-Improvement Loop

After any correction from the user, Claude **immediately updates its learnings** (in memory files or the project's `CLAUDE.md`). It writes rules for itself to prevent the same mistake from recurring. This creates a feedback loop where error rates drop over time as the rule set grows.

### 4. Verification Before Done

No task is marked complete without **proof it works** — tests pass, logs are clean, behavior is demonstrated. Claude diffs its changes against the main branch when relevant and asks itself: *"Would a staff engineer approve this?"*

Before pushing, think from a **CI perspective**: *"What does a fresh `git clone` + `install` look like?"* Generated/gitignored files (i18n, codegen, protobuf, GraphQL) that typecheck/build depend on need explicit compile steps in CI — local dev won't catch this because files already exist on disk.

**HARD RULE — Visual changes require Playwright screenshots**: For ANY visual change (layout, CSS, styling, colors, spacing, components), ALWAYS take a Playwright screenshot at the target viewport (e.g., iPhone SE 375x667) and verify it yourself BEFORE telling the user it's fixed. Use `colorScheme: 'dark'` if the project uses dark mode. NEVER say "it should work" — SHOW it works. If you can't screenshot, tell the user and ask them to verify.

### 5. Demand Elegance (Balanced)

For non-trivial changes, Claude pauses to consider whether there's a more elegant approach. If a fix feels hacky, it restarts with full context. However, this is balanced — simple, obvious fixes don't get over-engineered.

### 6. Autonomous Bug Fixing — Logs First, Always

A **hard rule** for debugging, with no exceptions:

1. **Logs first** — Read log files, error output, CI logs, Cloud Logging. If no log exists, add one and reproduce.
2. **Data second** — Check DB/state only after logs point to an inconsistency.
3. **Add logging** — If logs are insufficient, add targeted logging and reproduce. Never guess.
4. **Code last** — Only analyze source code after steps 1-3 provide evidence.

Claude never speculates about "what might have happened" by reading code paths. The phrase **"logs first"** is a hard stop — all speculation ceases and it goes to read actual output. Bug reports are handled autonomously with zero hand-holding from the user.

### 7. Documentation & Context Updates

Before committing, Claude follows a strict flow:
1. Confirm doc updates with the user
2. Update docs
3. Save context
4. Commit everything together

Code is never committed separately from its documentation. This applies to implementation plans, walkthroughs, architecture docs, and any files referencing the changed area.

---

## Task Management

1. **Plan First** — Use plan mode or todo lists for multi-step tasks
2. **Verify Plan** — Check in with the user before starting implementation
3. **Track Progress** — Mark items complete incrementally
4. **Explain Changes** — Provide a high-level summary at each step

---

## Context Persistence

Each project has **one `CLAUDE.md`** in its root containing rules, current state, and key learnings. When it grows too large (40k+ chars), detailed history overflows to memory files (`memory/`) while the root file stays under 20k chars.

The command **"save context"** triggers a full replacement of the Current Context section with a snapshot of the current state (branch, test count, completed phases, pending work).

No separate task/context/todo files are created in the repo — everything lives in `CLAUDE.md` or memory files.

---

## Shell & Platform

- Always uses **bash** (Unix shell syntax), never Windows cmd/PowerShell — even on Windows
- Forward slashes in paths, `/dev/null` not `NUL`, `rm -rf` not `rmdir /s /q`
- For `.cmd`/`.bat` tools (e.g., `gcloud.cmd`), uses Node/Python subprocess with explicit argument arrays to avoid Windows shell quoting issues

---

## Shorthand Commands

| Command | Meaning |
|---------|---------|
| **wawa** | "Where are we at?" — See details below |
| **wrap** | Full pre-commit ritual: update learnings, save context, update docs, lint, stage, commit, ask before push |
| **qt** | Quick test — verify a fix works before user tests manually. Followed by a description of what to test. |

### `wawa` — Where Are We At?

Outputs a structured status summary with **no prose preamble** — just data:

1. **Re-read first**: Always re-reads the project's `CLAUDE.md` Current Context section AND any active plan file before generating the table. Never relies on conversation memory — it goes stale. Cross-references completed items against plan items.
2. **Status line**: Branch, last commit, test counts (unit + E2E), type/lint errors.
3. **Outstanding work table**:

   | # | Category | Task | Priority | Status | Notes |
   |---|----------|------|----------|--------|-------|
   | 1 | Phase work | ... | High | ... | ... |
   | 2 | Deferred | ... | Low | ... | ... |
   | 3 | Tech debt | ... | Medium | ... | ... |

   Categories group rows into:
   - **Phase work** — active/next planned phases from the execution plan
   - **Deferred** — items explicitly deferred in the Current Context section
   - **Tech debt** — known divergences, migrations, or cleanup tasks

---

## Testing Strategy

- **E2E debugging**: Fix each failing test individually (single test runs), then re-run the full suite only after all individual fixes pass
- **E2E long runs**: Run full E2E suites in foreground with `timeout: 300000` (5 min). Config has `maxFailures: 1` so it stops on first failure. If running in background for any reason, check output at the 3-minute mark proactively.
- **E2E pre-flight**: Kill zombie processes, verify DB connectivity, sync schema if changed

---

## Bash Permissions — Avoiding Prompts

### HARD RULE: No Command Chaining — EVER

> **This is a non-negotiable rule. Claude has repeatedly violated it. Zero tolerance.**

Claude Code's permission system matches commands by their **first token**. Chaining with `&&`, `;`, or `||` means the first token is `cd` (or whatever comes first), not the actual command you want auto-allowed. This triggers unnecessary permission prompts and annoys the user.

```bash
# ❌ BAD — starts with `cd`, triggers permission prompt
cd packages/server && git commit -m "fix"
cd d:/dev/_git/forge && git status

# ✅ GOOD — separate Bash tool calls, each matches its own pattern
# Call 1: git -C d:/dev/_git/forge status
# Call 2: git -C d:/dev/_git/forge log --oneline -3

# ✅ GOOD — for non-git commands, use separate tool calls
# Call 1: cd packages/server
# Call 2: npm run build
```

**Rules**:
1. **NEVER chain commands with `&&`, `;`, or `||`** in Bash tool calls
2. **For git commands in other directories**: Use `git -C <path>` — single command, no chaining
3. **For non-git commands**: Use separate Bash tool calls, one command each
4. **Subagents must follow this too** — explicitly instruct them in the prompt

### Auto-Allowed Tools

These tools run without prompting:

| Tool | Purpose |
|------|---------|
| **Read** | Read file contents |
| **Write** | Create new files |
| **Edit** | Modify existing files |
| **Glob** | Find files by pattern |
| **Grep** | Search file contents |
| **Agent** | Launch subagents for parallel work |
| **TodoWrite** | Track task progress |
| **NotebookEdit** | Edit Jupyter notebooks |
| **WebSearch** | Search the web |

### Auto-Allowed Commands

These commands are harmless and should run without prompting:

| Category | Commands |
|----------|----------|
| **Shell basics** | `cd`, `ls`, `pwd`, `cat`, `head`, `tail`, `echo`, `printf`, `wc`, `sort`, `uniq`, `tr`, `cut`, `tee`, `test` |
| **File operations** | `mkdir`, `cp`, `mv`, `touch`, `chmod`, `basename`, `dirname`, `realpath` |
| **File inspection** | `file`, `stat`, `diff`, `which`, `where`, `whereis`, `type` |
| **Text processing** | `sed`, `awk`, `xargs` |
| **Search** | `find`, `grep`, `rg`, `ag` |
| **Node.js** | `node`, `npm`, `npx`, `pnpm`, `tsx`, `tsc` |
| **Build/test** | `vitest`, `playwright`, `eslint`, `prettier` |
| **Network** | `curl`, `wget`, `ping`, `ipconfig`, `ip`, `ss`, `netstat` |
| **Process** | `ps`, `kill`, `lsof`, `tasklist` |
| **WSL/Docker** | `wsl`, `docker`, `powershell`, `powershell.exe`, `cmd` |
| **Git (safe)** | `git status`, `git diff`, `git log`, `git add`, `git commit`, `git branch`, `git checkout`, `git switch`, `git stash`, `git fetch`, `git rebase`, `git merge`, `git cherry-pick`, `git show`, `git tag`, `git rm`, `git mv`, `git check-ignore`, `git config`, `git remote`, `git rev-parse`, `git ls-files`, `git blame`, `git shortlog`, `git describe`, `git -C` |
| **Other** | `gh`, `bc`, `python`, `python3`, `bash`, `source`, `timeout`, `for`, `du`, `start`, `pandoc` |
| **Env vars** | `DATABASE_URL=`, `PORT=`, `CI=`, `DEBUG=`, `NODE_OPTIONS=`, `TMPDIR=`, `E2E_DATABASE_URL=`, `set`, `export` |

### Commands That Prompt

The following are **excluded** from auto-allow because they are destructive or affect shared state:

| Command | Reason |
|---------|--------|
| `rm` | Deletes files permanently |
| `git push` | Triggers deploys, affects remote |
| `git reset` | Can discard commits/work |
| `git clean` | Deletes untracked files permanently |
| `git restore` | Can discard uncommitted changes |

### WebFetch Domains

Auto-allowed domains: `github.com`, `raw.githubusercontent.com`, `npmjs.com`, `prisma.io`, `xendit.co`, `neon.com`, `capacitorjs.com`, `ionic.io`, `capgo.app`, `localhost`, `better-auth.com`, `hono.dev`, `orm.drizzle.team`, `tanstack.com`, `inlang.com`, `vite.dev`

---

## Core Principles

| Principle | Description |
|-----------|-------------|
| **Simplicity First** | Every change should be as simple as possible, impacting minimal code |
| **No Laziness** | Find root causes. No temporary fixes. Senior developer standards. |
| **Minimal Impact** | Changes only touch what's necessary. Avoid introducing bugs. |
