# Forge — Project Rules

## Purpose
Forge is the shared tooling, conventions, and reference documentation repo used across all projects. Skills, stack guides, and workflow rules live here as a shared reference — but forge is NOT the source of truth. The user is the source of truth. Forge is a proposal, not an authority.

## Key Files & Directories
- `skills/` — Git-tracked shared reference for all global skills (self-contained packages)
- `learnings/` — Absorbed team wisdom (populated by `/forge`)
- `memory/` — Team identity & shared conventions (populated by `/forge`)
- `presentation/` — Canonical human-readable overview (`index.html`). Maintained per the HARD RULE in `skills/forge/claude-code-rules.md` whenever skills/arts change.
- `.claude/skills/forge/` — Thin bootstrap so `/forge` is discoverable on fresh clone
- `.claude/skills/purge/` — Sole location for `/purge`. Forge-internal maintainer art; deliberately NOT under `skills/` so the `/forge` cycle never deploys it to user membranes (containment — prevents projects from writing to forge by proxy).

## Core Loop — /forge
> In the forge, we forge.

One command, three internal motions. The old `/mark`, `/cast`, and `/fold` trio has been retired as top-level commands — their verbs now describe internal phases of a single bidirectional cycle.

| Motion | Phase | Analogy |
|--------|-------|---------|
| **mark** | Inspect drift and present the PLAN table | Hallmark — stamp quality |
| **cast** | Pour forge → membrane (incoming) | Pour molten metal into the mold |
| **fold** | Layer membrane → forge (outgoing) | Layer experience into the steel |

Invocation forms:

| Form | Purpose |
|------|---------|
| `/forge` | Run the full cycle against the current directory |
| `/forge <path>` | Run the cycle against a specific project |
| `/forge --dry` | Read-only inspection (replaces the old `/mark`) |
| `/forge on` / `/forge off` | Session toggle — enable/disable all forge skills |

## Arts (Nine P's deployed + /purge forge-internal)
Arts are skills that adopt a specialist persona and have a self-improving learning loop. Protocol: `skills/forge/protocol.md`.

| Art | Persona | Mode |
|-----|---------|------|
| `/prime` | The originator (ideation → blueprint) | Generative |
| `/probe` | Senior solutions architect | Evaluative |
| `/poke` | Staff engineer (code quality + tech debt) | Evaluative — light |
| `/preen` | UI/UX evaluator (Don Norman's design principles) | Evaluative — design |
| `/press` | Staff engineer (go-live readiness) | Evaluative — medium |
| `/pound` | 21 adversarial QA personas | Evaluative — heavy |
| `/pitch` | The founder's other voice (and a VC partner on `--critique`) | Generative — synthesis (with optional review pass) |
| `/pry` | The Lever (relentless solution-finder) | Investigative |
| `/praise` | The Listener (user feedback → routed art) | Investigative — feedback |

**Evaluative trifecta** — poke often, press before milestones, pound before ship.
**When blocked** — `/pry` to crack the wall.
**For UI/UX** — `/preen` to evaluate interfaces through Don Norman's lens.
**For alignment + business model** — `/pitch` is mandatory after Touchstone (generates the seven-section Pitch — Bet / Wound / Inversion / Field / Stake / Signal / Stand — in the founder's voice with ballpark numbers, rendered through Touchstone). Same Pitch serves founder, cofounder, and investor; what differs is the room. Run `/pitch --critique` for the seven-dimension VC review pass when external persuasion needs stress-testing.
**After user feedback** — `/praise` to route feedback to the right arts and close the build-ship-learn loop.

*`/purge` is a forge-internal art for maintainers — cleanses stale knowledge and drift. Lives only at `.claude/skills/purge/` (never deployed to user membranes).*

## The Masters
Three Masters of the forge — distinct domains, complementary roles. Two deploy to user membranes (`/smith`, `/wedge`); one is forge-internal (`/purge` / The Warden, lives only at `.claude/skills/purge/`).

| Skill | Title | Purpose |
|-------|-------|---------|
| `/smith` | The Smith — Master Builder | The user's proxy for construction. Consumes Blueprint + Pattern + Touchstone and autonomously builds the MVP through iterative heats. Summons apprentices for parallel work, wields every art, converges on perfection. |
| `/wedge` | The Wedge — Master of Aesthetic | The user's proxy for visual identity. Reads Opus + Vow, summons a council of master designers, presents three aesthetic directions for the user to pick, and crystallizes the chosen direction into the **Touchstone** — a single HTML masterpiece that persists as the visual constitution every downstream artifact (Pitch HTML, Smith-built screens) conforms to. |
| `/purge` | The Warden — Master Tender | The forge's own keeper. Cleanses stale knowledge, deduplication, and drift across all learnings, memory, skills, and reference docs. Forge-internal — never deployed to user membranes. |

## Task Skills
| Skill | Purpose |
|-------|---------|
| `/forge` | The forge cycle — unified bidirectional sync (triage + apply + absorb + commit). Also handles session toggle via `on`/`off`. |
| `/wawa` | "Where Are We At?" — outstanding work summary table |
| `/wrap` | Pre-commit ritual (lint → stage → context → docs → compact → commit) |
| `/qt` | Quick test — verify fixes before user tests manually |
| `/srs` | Setup run scripts (restart + kill-zombies) for local dev |
| `/monci` | Monitor CI — watch GitHub Actions runs on current branch |
| `/ponci` | Push to remote and monitor CI |
| `/vsix` | Publish a VS Code extension |
| `/dig` | Think deeper — reframe agent as staff engineer for current discussion |
| `/temper` | Hardened evaluation — runs poke + press N times, consolidates with confidence scoring |
| `/cicd` | Local CI/CD pipeline — lint, typecheck, test, build, deploy. Auto-fixes failures, escalates to /pry |
| `/eli5` | Explain Like I'm 5 — distill current topic into simplest possible terms |

## Three Pillars (all bidirectional via /forge)
| Pillar | DOWN (forge → user) | UP (user → forge) |
|--------|--------------------|--------------------|
| `skills/` | Incoming section of PLAN table — deploys to `~/.claude/skills/` | Outgoing section of PLAN table — edits absorbed from deployed copy |
| `learnings/` | Incoming section — syncs to `~/.claude/learnings/` | Outgoing section — auto-accumulates in membrane, absorbed on approval |
| `memory/` | Incoming section — syncs to `~/.claude/memory/` | Outgoing section — auto-accumulates in membrane, absorbed on approval |

Every transfer (either direction) runs through `/forge`'s single PLAN table. No back doors.

## Self-Improving Loop
Arts (`/prime`, `/probe`, `/poke`, `/preen`, `/press`, `/pound`, `/pitch`, `/pry`, `/praise`) and Masters (`/smith`, `/wedge`) write learnings to project's `memory/*-learnings.md` with `Forge-worthy: yes/no` flags → `/forge` fold phase scans project memories for `Forge-worthy: yes` entries, genericizes, promotes to `~/.claude/learnings/general.md`, and absorbs into `<forge>/learnings/` → next art/master run reads global learnings in pre-flight.

## HARD RULE — Only /forge Writes to Forge
> **No project, no skill, no manual edit touches forge repo files directly.**
> `/forge` is the gatekeeper for learnings, memory, config sync, and skill reverse-sync.
> Direct edits to forge are only for skill development (editing `SKILL.md` files in `skills/`).
>
> **When a user says "add this to forge" from a project context**, they mean:
> 1. Write the learning to `~/.claude/learnings/general.md` (the membrane)
> 2. Tell the user to run `/forge` to absorb it through the fold phase
>
> **NEVER** open the forge repo and edit `learnings/`, `memory/`, or `skills/forge/` files from a project context.
> The membrane is the inbox. `/forge` is the quality gate. No shortcuts.

## HARD RULE — Forge Brings Intelligence, Users Bring Wisdom
> **Forge classifies, deduplicates, detects conflicts, routes knowledge, and flags anomalies.**
> **Users review, approve, reject, and reconcile at the PLAN table.**
> `/forge` presents a single PLAN table where forge's classification meets the user's judgment. Together, both grow the knowledge base.
>
> **Corollary**: One direction or both, same quality gate. Every transfer goes through the PLAN table.

## HARD RULE — All Transfers Are Guarded by User Wisdom
> **ALL pillars (skills, config, learnings, memory) require user review in BOTH directions.**
> `/forge` presents one PLAN table. Every item requires user approval. Only approved items execute.
> Nothing transfers without the user's judgment.
> A skill can have a bad update. A config can have stale rules. A learning can be wrong.
> The user reviews every item — no pillar gets a mechanical bypass.

## HARD RULE — Protected Skills Are Never Absorbed Outgoing
> `/forge` and `/purge` can never be absorbed membrane → forge within the cycle.
> Absorbing `/forge` mid-run would silently overwrite the rules currently running. Absorbing `/purge` could break the next cleanse.
> If either appears as `DEPLOYED-DIFFERS`, it surfaces in the ⚠ CONFLICTS section with note "protected — reconcile manually." The user may choose `[↓] accept forge` (overwrite local), but `[↑] keep membrane` is disabled.

## HARD RULE — No Project Names in Forge
> **Forge is a shared repo. NEVER include project-specific details in learnings, memory, or commit messages.**
> Strip all project names, specific file paths, domains, and business logic before writing.
> Learnings must read as universal principles. Commit messages must describe *what* was absorbed, not *where* it came from.

## HARD RULE — No Auto-Commit
> **NEVER commit automatically after completing any sprint, phase, or piece of work.**
> Use `AskUserQuestion` to prompt: "Ready to wrap up?" with options "Yes, run /wrap" / "Not yet".

## HARD RULE — No Command Chaining in Bash — EVER
> **NEVER use `&&`, `;`, or `||` to chain commands in a single Bash tool call.**
> This applies to the main agent AND all subagents. Zero exceptions. Zero tolerance.

## Documentation
No docs/ directory — forge is a tooling repo. Skill documentation lives inside each skill's directory (`skills/<name>/SKILL.md`).

## Current Context
- **Branch**: main
- **Completed**: Three-pillar architecture, git-based drift detection, unified `/forge` cycle (replacing retired `/cast`, `/mark`, `/fold`), forge protocol formalization, Forge Arcana identity + ethos, project name sanitization, shared preflight extraction, hash-free trackers, evaluative trifecta (poke → press → pound), art auto-invocation with TRIGGER conditions, `/forge on|off` session toggle folded into cycle command, SKILL.md-based deploy detection, `/praise` wired as 10th art (feedback routing → build-ship-learn loop closure), `/prime` privacy + research-first + no-dev-cycle-estimates HARD RULES, two-layer OAuth-token-race workaround (Layer 1 forge preflight + Layer 2 SessionStart hook with WSL2-gated user-scope scheduler) + workaround tracking + side-effect lifecycle management via WORKAROUNDS.md as manifest
- **Masters** (three — distinct domains, complementary roles):
  - `/smith` — **The Smith**. Master builder. The user's proxy for construction, wields all arts, summons apprentices. Lives in `skills/smith/SKILL.md`. Three-layer learning membrane (orchestration, delegation, art proficiency). Reads Pattern + Touchstone in pre-flight.
  - `/wedge` — **The Wedge**. Master of aesthetic. The user's proxy for visual identity. Reads Opus + Vow, summons a council of master designers (3 parallel apprentices), the user picks one direction, the Wedge crystallizes the chosen direction into the **Touchstone** — a single HTML masterpiece that persists as the visual constitution every downstream artifact (Pitch HTML, Smith-built screens) conforms to. Lives in `skills/wedge/SKILL.md`. Embodies HARD RULE — *commit to ONE direction, no hedging.* Drives the wedge clean.
  - `/purge` — **The Warden**. Master tender. Guards the forge itself against drift, staleness, contamination, and bloat. Four dimensions analyzed in parallel by independent subagents (Knowledge Purity, Memory Hygiene, Skill Fitness, Reference Integrity). Lives only in `.claude/skills/purge/` (forge-internal, never deployed to user membranes by design).
- **Arts**: prime, probe, poke, preen, press, pound, pitch, pry, purge, praise — shared protocol in `skills/forge/protocol.md`. Purge is forge-internal; praise closes the build-ship-learn loop.
- **Shared architecture**: `forge-status.sh` is the shared classification engine. `/forge` builds the PLAN table from its output — one table, three directional sections (incoming / outgoing / conflicts). One engine, one interpretation.
- **Shared references**: `skills/forge/protocol.md` (art pre/post-flight), `skills/forge/preflight.md` (universal classification system used by `/forge`)
- **Scripts**: `scripts/forge-status.sh` (shared classification engine), `scripts/cast-deploy.sh` (skill + runtime-script deployment called from cycle's cast phase; supports `--scripts` and `--verify-scripts` modes), `scripts/forge-scan.sh` (project evidence for /poke, /press), `scripts/forge-purge-scan.sh` (forge hygiene for /purge), `scripts/fold-evidence.sh` (learning/memory collection called from cycle's fold phase), `scripts/fold-purity-check.sh` (project-name/contributor/currency/schema leak gate — runs in fold phase 3e + commit gate 3i), `scripts/wawa-status.sh` (git state for /wawa), `scripts/gh-poll.sh` (CI polling for /monci, /ponci), `scripts/agent-token-warmup.sh` + `scripts/agent-token-scheduler.sh` + `scripts/agent-preflight.sh` + `scripts/user-agent-preflight.sh` + `scripts/install-token-hook.sh` + `scripts/sync-workaround-side-effects.sh` (two-layer OAuth race protection — Layer 1 forge-skill preflight, Layer 2 SessionStart hook with WSL2-gated user-scope scheduler — see WORKAROUNDS.md WA-001), `scripts/forge-workarounds-check.sh` (periodic upstream bug check, time-gated 7d, surfaced in /forge mark phase)
- **Trackers**: `learnings/.fold-tracker.json` (title-based: processedEntries + promotedEntries), `memory/.memory-tracker.json` (skippedFiles for PERSONAL memories, diff for sync)
- **Baseline**: `~/.claude/.last-cast.json` stores last-cast commit SHA for three-way drift detection (written by `/forge` after the cast phase, consumed by forge-status.sh)
- **Earlier history** (2026-04-23 → 2026-05-04): see `memory/recent-history.md`. 8 entries archived during the 2026-04-27 wrap, 5 more during 2026-04-30, 3 more during the first 2026-05-04 wrap, 1 more during the second, 1 more during the third, and 2 more (Pitch refactor + lineage indexing) during the fourth 2026-05-04 wrap (probe/prime stack-anchoring).
- **Recent**: 2026-05-04 — **Probe + Prime stack-anchoring: stop the Vercel/Neon drift**. User flagged that `/probe` had started recommending Vercel + Neon as the architecture combo. Root cause: `/probe`'s subagents do open web searches for "current best practices" but only referenced `<forge>/skills/forge/stack-guide.md` for the *logging* convention — the stack table itself was never an anchor. Web results surface trendy combos (Vercel + Neon, Next.js, Supabase) and the subagents treated them as peer alternatives to the prescribed forge stack (Cloud Run + Cloud SQL/Neon + Hono + Drizzle + React/Vite + TanStack + Better Auth + Pino/Sentry). Compounding this: `/prime`'s blueprint-framework.md Q33 listed "GCP/AWS/Azure", "Vercel/Netlify + managed DB", and "Railway/Render/Fly.io" as three peer hosting options — seeding the same drift upstream of probe. Fix: (1) `/probe` pre-flight now requires reading the stack-guide as the **default baseline**; subagents anchor to the stack-guide row first, then use web research for *deviation analysis* only. New **Deviation rule (HARD)**: stack-guide choices may only be swapped when a concrete project signal demands it — data residency, scale/latency requirement, workload mismatch, founder-explicit. Trend/popularity is not a signal. Pattern entries deviating from stack-guide must include a `**Deviation signal**:` line citing the project signal. (2) `/prime` Q33 rewritten to **lead with the forge default** (Cloud Run + Cloud SQL + Neon dev/staging) and present alternatives only when a concrete signal demands it — not as peer options. Files touched: `skills/probe/SKILL.md`, `skills/prime/blueprint-framework.md`. No new learning yet; if the pattern recurs across other arts (e.g., /preen drifting on web-trendy UI libs over shadcn), promote to forge-worthy: *Arts must anchor to forge prescriptions before consulting the open web.*
