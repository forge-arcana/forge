# Forge — Project Rules

## Purpose
Forge is the shared tooling, conventions, and reference documentation repo used across all projects. Skills, stack guides, and workflow rules live here as a shared reference — but forge is NOT the source of truth. The user is the source of truth. Forge is a proposal, not an authority.

## Key Files & Directories
- `skills/` — Git-tracked shared reference for all global skills (self-contained packages)
- `learnings/` — Absorbed team wisdom (populated by `/forge`)
- `memory/` — Team identity & shared conventions (populated by `/forge`)
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

## Arts (Ten P's)
Arts are skills that adopt a specialist persona and have a self-improving learning loop. Protocol: `skills/forge/protocol.md`.

| Art | Persona | Mode |
|-----|---------|------|
| `/prime` | The originator (ideation → blueprint) | Generative |
| `/probe` | Senior solutions architect | Evaluative |
| `/poke` | Staff engineer (code quality + tech debt) | Evaluative — light |
| `/preen` | UI/UX evaluator (Don Norman's design principles) | Evaluative — design |
| `/press` | Staff engineer (go-live readiness) | Evaluative — medium |
| `/pound` | 21 adversarial QA personas | Evaluative — heavy |
| `/pitch` | VC partner / business strategist | Evaluative — business |
| `/pry` | The Lever (relentless solution-finder) | Investigative |
| `/praise` | The Listener (user feedback → routed art) | Investigative — feedback |

**Evaluative trifecta** — poke often, press before milestones, pound before ship.
**When blocked** — `/pry` to crack the wall.
**For UI/UX** — `/preen` to evaluate interfaces through Don Norman's lens.
**For business model** — `/pitch` before committing build resources and before ship.
**After user feedback** — `/praise` to route feedback to the right arts and close the build-ship-learn loop.

*`/purge` is a forge-internal art for maintainers — cleanses stale knowledge and drift. Lives only at `.claude/skills/purge/` (never deployed to user membranes).*

## The Master
| Skill | Purpose |
|-------|---------|
| `/smith` | Master of the forge — the user's proxy. Consumes a probed blueprint and autonomously builds the product through iterative heats. Summons apprentices for parallel work, wields every art, converges on perfection. |

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
Arts (`/prime`, `/probe`, `/poke`, `/preen`, `/press`, `/pound`, `/pitch`, `/pry`, `/praise`) write learnings to project's `memory/*-learnings.md` with `Forge-worthy: yes/no` flags → `/forge` fold phase scans project memories for `Forge-worthy: yes` entries, genericizes, promotes to `~/.claude/learnings/general.md`, and absorbs into `<forge>/learnings/` → next art run reads global learnings in pre-flight.

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
- **Masters** (two — distinct domains, complementary roles):
  - `/smith` — **The Smith**. Master builder. The user's proxy, wields all arts, summons apprentices. Lives in `skills/smith/SKILL.md`. Three-layer learning membrane (orchestration, delegation, art proficiency).
  - `/purge` — **The Warden**. Master tender. Guards the forge itself against drift, staleness, contamination, and bloat. Four dimensions analyzed in parallel by independent subagents (Knowledge Purity, Memory Hygiene, Skill Fitness, Reference Integrity). Lives only in `.claude/skills/purge/` (forge-internal, never deployed to user membranes by design).
- **Arts**: prime, probe, poke, preen, press, pound, pitch, pry, purge, praise — shared protocol in `skills/forge/protocol.md`. Purge is forge-internal; praise closes the build-ship-learn loop.
- **Shared architecture**: `forge-status.sh` is the shared classification engine. `/forge` builds the PLAN table from its output — one table, three directional sections (incoming / outgoing / conflicts). One engine, one interpretation.
- **Shared references**: `skills/forge/protocol.md` (art pre/post-flight), `skills/forge/preflight.md` (universal classification system used by `/forge`)
- **Scripts**: `scripts/forge-status.sh` (shared classification engine), `scripts/cast-deploy.sh` (skill + runtime-script deployment called from cycle's cast phase; supports `--scripts` and `--verify-scripts` modes), `scripts/forge-scan.sh` (project evidence for /poke, /press), `scripts/forge-purge-scan.sh` (forge hygiene for /purge), `scripts/fold-evidence.sh` (learning/memory collection called from cycle's fold phase), `scripts/fold-purity-check.sh` (project-name/contributor/currency/schema leak gate — runs in fold phase 3e + commit gate 3i), `scripts/wawa-status.sh` (git state for /wawa), `scripts/gh-poll.sh` (CI polling for /monci, /ponci), `scripts/agent-token-warmup.sh` + `scripts/agent-token-scheduler.sh` + `scripts/agent-preflight.sh` + `scripts/user-agent-preflight.sh` + `scripts/install-token-hook.sh` + `scripts/sync-workaround-side-effects.sh` (two-layer OAuth race protection — Layer 1 forge-skill preflight, Layer 2 SessionStart hook with WSL2-gated user-scope scheduler — see WORKAROUNDS.md WA-001), `scripts/forge-workarounds-check.sh` (periodic upstream bug check, time-gated 7d, surfaced in /forge mark phase)
- **Trackers**: `learnings/.fold-tracker.json` (title-based: processedEntries + promotedEntries), `memory/.memory-tracker.json` (skippedFiles for PERSONAL memories, diff for sync)
- **Baseline**: `~/.claude/.last-cast.json` stores last-cast commit SHA for three-way drift detection (written by `/forge` after the cast phase, consumed by forge-status.sh)
- **Recent**: 2026-04-23 — unified `/mark` + `/cast` + `/fold` into single `/forge` cycle command. Retired three top-level commands in favour of one bidirectional negotiation. Motion names (mark / cast / fold) survive as internal phases. The command absorbs session toggle via `/forge on|off`. Liturgical framing: *in the forge, we forge.*
- **Recent**: 2026-04-24 — `/prime` lineage formalized as **Opus** (origin manuscript, continuous through Phases 1–2) → **Vow** (distilled pledge + viability thread, always) → **Pitch** (when external audience matters) → **Blueprint** (execution skeleton) → **Pattern** (architecture + UX decisions /smith consumes). *"My Magnum Opus"* is the sum of it all. Downstream alignment: `/probe` writes the Architecture section of Pattern (no more `-probed.md` copies), `/preen` appends the UX section to the same file. `/pitch` art's artifact name renamed `PitchForge` → `Pitch`. `/smith` preflight now reads Blueprint + Pattern together; Pattern gate auto-invokes `/probe` (and `/preen` if UI-facing) when missing.
- **Recent**: 2026-04-25 — `/prime` polished from team feedback. Three new HARD RULES: (1) **never infer founder identity** from IDE/extension/git/email metadata — privacy boundary; (2) **no human-scale dev estimates** — banned questions like "what's your timeline?" because /smith builds MVPs in hours, replaced with priority/scope/external-milestone questions; (3) **research before asking the founder to research** — Prime WebSearches market data, competitors, and regulations first, then presents a hypothesis for the founder to confirm. Reverses the "ask the founder" patterns in pitch-framework and blueprint-framework. The founder brings lived insight; Prime brings researched context.
- **Recent**: 2026-04-26 — `/smith` token-race workaround. Preflight token warmup + background keeper proactively refresh OAuth tokens to defeat Claude Code's documented refresh-token race (issues #43392, #24317). New infrastructure: `WORKAROUNDS.md` registry at forge root + `scripts/forge-workarounds-check.sh` (time-gated weekly upstream check), banner shown above /forge PLAN table on every cycle. Removes itself the moment Anthropic ships a fix — full removal procedure in WORKAROUNDS.md.
- **Recent**: 2026-04-26 — Token-race workaround **generalized to all subagent-spawning skills** after `/temper` hit the same bug. Promoted to forge protocol pre-flight — covers all 10 arts automatically. New `agent-preflight.sh` one-liner; smith/temper/forge-cycle/cicd call it explicitly. Idempotent (nested skills don't double-spawn keepers). Scripts renamed `smith-token-*` → `agent-token-*`. Learning moved from `smith-learnings.md` → `global-patterns.md` (universal pattern). Companion change: `/purge` elevated from "forge-internal aside" to **The Warden** — master tender of the forge, parallel to The Smith (master builder). README + protocol + CLAUDE.md restructured into "The Masters" sections. Purge's four dimensions also parallelized via subagent fan-out (evidence-then-fan-out pattern, matches /temper and /pound).
- **Recent**: 2026-04-26 — **Mechanical enforcement of "No Project Names in Forge"** after a fold-phase run leaked project name + contributor name + local currency + project schema names + competitor name into seven absorbed entries. Genericized the seven entries (Exhibit A in `learnings/global-patterns.md`). New `scripts/fold-purity-check.sh` scans staged forge content + commit messages for: currency-symbol prices, attribution lines, CamelCase project names, project-specific backticked identifiers, `Firstname Lastname` patterns. Wired into forge SKILL.md Phase 3e (per-learning gate) and Phase 3i (final commit gate, including commit-message check). Prose rules without enforcement get ignored mid-flow; the next layer is mechanical, not louder prose.
- **Recent**: 2026-04-26 — **Layer 2 OAuth race protection (user-level, WSL2)**. Forge-internal preflight only protected forge skills; parallel research agents spawned from regular Claude chats still raced. New SessionStart hook calls `~/.claude/scripts/user-agent-preflight.sh` on every Claude session, which ensures a single user-scope **scheduled-refresh** process is alive (sleeps until `expiresAt - 30min`, refreshes once, repeats — not polling). Shipped as a unified `scripts/agent-token-scheduler.sh` with two modes (`--user`, `--parent`), replacing the old polling keeper. Warmup retrofitted with `flock` to close a race we were re-creating ourselves under SessionStart bursts. WORKAROUNDS.md grows a `Side effects` block per WA entry — it IS the manifest now (no separate JSON). `/forge` cycle reads `sync-workaround-side-effects.sh` to surface install/uninstall rows in the PLAN table per WA. Hook only surfaced on WSL2; script side-gate stays for dotfile-clone defense. Failure-recovery sentinel: `~/.claude/.token-stale` printed loud by every preflight after 3 consecutive refresh failures.
- **Recent**: 2026-04-26 — **WA-001 forensic backing** added at `evidence.md`. Genericized timeline of the OAuth refresh-token race incident (origin host's project name, user, session UUIDs stripped; technical substance preserved): two Claude Code processes at slightly different patch versions sharing one `.credentials.json`, second process rotates refresh token mid-`/smith`, first 401s. Pairs with WORKAROUNDS.md WA-001 — deletes when Anthropic ships a fix.
