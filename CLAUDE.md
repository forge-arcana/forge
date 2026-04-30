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
| `/pitch` | VC partner / business strategist | Evaluative — business |
| `/pry` | The Lever (relentless solution-finder) | Investigative |
| `/praise` | The Listener (user feedback → routed art) | Investigative — feedback |

**Evaluative trifecta** — poke often, press before milestones, pound before ship.
**When blocked** — `/pry` to crack the wall.
**For UI/UX** — `/preen` to evaluate interfaces through Don Norman's lens.
**For business model** — `/pitch` before committing build resources and before ship.
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
- **Earlier history** (2026-04-23 → 2026-04-26): see `memory/recent-history.md`. 8 entries archived during the 2026-04-27 wrap to keep CLAUDE.md under the compact threshold.
- **Recent**: 2026-04-27 — `/purge` (The Warden) full cleanse pass. ~38 of 42 findings applied across all four dimensions. **Knowledge Purity**: 5 project-name leaks scrubbed from prime/probe-learnings (Philippine-specific framing, lawyer/IBP/Neypes references, "$7-10/month", competitor names); 3 entries removed from global-patterns.md (Integer Money, Barrel Imports Break Vite, Error Handler Environment Check) because they were already baked into the user's global CLAUDE.md; 3 evolving-pattern fragmentations consolidated (Bidirectional Sync Discipline merging three drift entries; TTS Economics merging cost+persistence+streaming; Skills Own Their Dependencies and Discovery merging Self-Contained + Thin Bootstrap); 2 staleness-prone Cloudflare-bypass entries rewritten to remove tool names that decay rapidly (Flaresolverr/Patchright/camoufox no longer named); Bot/Crawler Protection trimmed 13 → 4 lines; Proactive OAuth Refresh trimmed 22 → 7 lines (defers to WORKAROUNDS.md). **Memory Hygiene**: identity.md restructured for three Masters (was single Smith) and ten arts/Nine P's framing corrected; learnings.md updated with Masters trio + cycle phase names (mark/cast/fold). **Skill Fitness**: prime SKILL.md ~37 lines extracted to `prime/opus-scaffold.md`; probe SKILL.md ~33 lines extracted to `probe/test-architecture-rubric.md`; forge SKILL.md Phase 3 fold consolidated (Strip/Keep table that itself leaked example project names removed; two stacked HARD RULE blockquotes merged with the script-as-mechanical-gate); wawa Steps section trimmed (placeholder template rows removed); preen description trimmed; pry placeholder Decomposition table removed; poke protocol restatement replaced with reference; press bot-protection duplication collapsed; wedge apprentice prompt now references HARD RULE section. **Reference Integrity**: CLAUDE.md "Arts (Ten P's)" → "Arts (Nine P's deployed + /purge forge-internal)"; protocol.md "The Ten Arts" table dropped /purge row (it's a Master, not an art) → "The Nine Arts"; scripts/forge-purge-scan.sh skill-classification fixed (was missing /pitch+/praise from loops, MASTER=1 became MASTERS=2, "Art Fitness" → "Skill Fitness"); README.md added /praise as a Feedback Loop Art and Quick Start lineage corrected; forge-conventions.md added Touchstone slot; presentation/ directory documented in CLAUDE.md and README.md tree. **Deferred**: C8 (user's global `~/.claude/CLAUDE.md` references retired `/cast`/`/mark`/`/fold` and is missing `/praise`/`/smith`/`/wedge`) — surface as CONFLICT in next `/forge` cycle. **Skipped (noted)**: I16 temper subagent-template parameterization (low risk), I17 pound under-specification (needs generative work, not trim), M11 seed entries for empty learning files (process-fitness observation).
- **Recent**: 2026-04-27 — Absorbed universal prose learning into `global-patterns.md`: avoid em-dashes and "No X. No Y. (Just Z.)" tricolon negation cadence in user-facing copy, both now read as obviously AI-generated tells. Companion fix to `scripts/fold-purity-check.sh`: skip dotfiles (e.g. `.fold-tracker.json`) under `learnings/` and `memory/` since trackers contain only already-vetted titles and trip the personal-name heuristic on legitimate Title-Case learning headings.
- **Recent**: 2026-04-27 — **The Wedge added as third Master** (`/wedge` — Master of Aesthetic). Closes the gap between functional MVP (Smith's domain) and aesthetic soul. The Wedge reads Opus + Vow, runs a council of three parallel design-apprentices (each channeling distinct master-designer archetypes from the conglomerate of human visual arts), the user picks one direction, the Wedge crystallizes it into the **Touchstone** — a single self-contained HTML masterpiece (real Google Fonts, atmospheric backdrop, orchestrated motion, hero + primary task + moment-of-delight + token legend). The Touchstone persists as the project's visual constitution: every screen Smith builds inherits its `:root` tokens; the Pitch is rendered HTML through it. Position in lineage: **Opus → Vow → Touchstone (via /wedge) → Pitch (HTML) → Blueprint → Pattern → Smith**. HARD RULES baked into the skill: banned defaults (no Inter/Roboto/Space Grotesk, no purple-on-white), required substance (distinctive font pairing, dominant + sharp accent, atmospheric background, intentional motion), commit to ONE direction (no hedging), vary across projects (never converge on a house style), soul before style (aesthetic serves the magnum opus, not the inverse). Cascade: `/pitch` artifact transforms `.md → .html` rendered through Touchstone tokens; `/smith` pre-flight reads Pattern + Touchstone and rejects apprentice work that introduces non-Touchstone fonts/colors/motion; `/probe` and `/preen` load the Touchstone for visual context during architecture and UX review. Self-improvement loop via `wedge-learnings.md`; universal aesthetic principles propagate to `<forge>/learnings/global-patterns.md` during fold.
- **Recent**: 2026-04-27 (afternoon) — **Wedge digest of Claude `frontend-design` skill + Google `DESIGN.md` spec**. Touchstone bifurcated into two paired artifacts: `Touchstone.html` (the *vision* — soul-bearing rendered masterpiece) AND `Touchstone.md` (the *contract* — DESIGN.md format with YAML typed tokens + 8 prose sections including project-specific Do's/Don'ts; normative for tokens). Council apprentices now receive a **two-axis Family × Tone commission** (e.g., *brutally-minimal Liquid*, *playful Brutalist*) — tense pairings unlock distinctive directions single-axis suppresses. **Required Substance** is now tone-conditional (3 tiers — maximalist / minimal / atmospheric) — refined-minimal is a first-class commit; restraint counts as substance. New **Memorable Signature** field in WedgeBrief (the one thing a user will remember). HARD RULES collapsed 7 → 4 (Commit-to-ONE absorbs Intentionality-Over-Intensity; Required-Substance absorbs Implementation-Matches-Vision; Vary-Across-Projects + Soul-Before-Style merge as Aesthetic-Serves-the-Project). New Heat 5 (Codification) inserted; Wedge has 7 heats now. Brief renamed `SoulBrief` → `WedgeBrief`. Cascade: smith/pitch/probe/preen now read MD's YAML frontmatter as the typed token contract (no more grepping `:root` from HTML); HTML retained for visual reference. Wedge SKILL.md trimmed 523 → 324 lines via two extractions: `wedge/touchstone-md-scaffold.md` (DESIGN.md template + generation rules) and `wedge/family-tone-archetypes.md` (7 families × 11 tones).
- **Recent**: 2026-04-27 (afternoon, /purge) — second cleanse pass. **Skill Fitness**: wedge bloat trim above; `press` Dimensions section trimmed (49% → ~25%, generic OWASP-style bullets removed, project-specific scoring lenses kept); `temper` two near-identical poke/press prompt templates collapsed into one shared template with variant-slot table; `pound` Process section trimmed, defers 21-persona list to qa-framework.md. **Knowledge Purity**: prime-learnings — 2 protocol-baked entries removed (Generated-Documents-in-docs, /prime-Auto-Invokes-/probe-/preen) + 3 founder-recognition entries consolidated into "Recognize What The Founder Already Brings"; probe-learnings — 3 Drizzle entries consolidated into "Drizzle Migration Operations Across Fresh and Existing DBs", TTS entry rewritten to drop decaying tool name (same precedent as morning pass), auth-flat-user-models entry cross-linked to global-patterns; poke-learnings — Schema-Defaults-Must-Match-Code-Defaults removed (already in user's global CLAUDE.md); global-patterns — 4 forge-internal sync entries (Self-Flagging, Tracker, Bidirectional Sync Discipline, Forward-Sync Don't Duplicate) consolidated into one 6-rule "Bidirectional Sync System Design"; 6 Cloudflare/anti-bot entries (Reframe, Diagnose-by-IP, Parallel-Probe-WordPress, cf-mitigated-Header, Bypass-Tooling-Decays, Verify-Bypass-Tools) consolidated into one numbered "Cloudflare / Anti-Bot Investigation Playbook"; 2 auth entries (No-Duplicate-User-Tables, Mock-Auth-Real-Library) merged into "Auth Library Territory: Don't Recreate, Don't Bypass". **Memory Hygiene**: identity.md Wedge prose updated for two-artifact Touchstone + new HARD RULES (intentionality + implementation-matches-vision); learnings.md Wedge entry similar. **Reference Integrity**: README "Six heats" → "Seven heats" + Codification heat inserted + Wedge prose two-artifact + Masters table + Quick Start lineage; forge-conventions.md Touchstone slot requires both .html AND .md (partial Touchstone is a defect); protocol.md "six-heat process" → "seven-heat" + new HARD RULES summary; user's global `~/.claude/CLAUDE.md` C3 fix (deferred from morning) — Masters/Arts/Task-skills lists corrected, retired `/cast`/`/mark`/`/fold` dropped, `/smith`/`/wedge`/`/praise` added, forge-disabled exception list corrected to `/forge` + `/purge` only.
- **Recent**: 2026-04-30 (/purge, scoped) — `presentation/index.html` Wedge gap audit, full sweep across 9 Reference Integrity findings. **Wedge presence added** (F1) — new dedicated slide between Smith and Task Skills covering Council of Three, Family × Tone commission, paired Touchstone artifacts (HTML vision + MD typed contract), HARD RULE callout, lineage footer. **Smith reframed** (F2) — slide title "Master Builder" → "First of Three Masters" with Smith/Wedge/Warden ribbon under intro. **Build chain updated** (F3) — slide 19 Quick Reference inserts `/wedge` between `/prime` and `/probe`. **Lifecycle map** (F4) — new STAGE 1½ "Aesthetic / Touchstone" inserted between Idea and Blueprint Review. **Frequency cheatsheet** (F5) — `/wedge project soul` added to ONCE EVER row. **Closing stats** (F6) — "10 Expert Arts" / "25 Total Skills" → "3 Masters" + "9 Expert Arts" + "24 Total Skills". **/purge reclassified as Master throughout** (F7, F8) — slide 9 retitled "Nine Arts" with /purge card removed, slide 12 retitled "Pry & Praise" (was "Pry, Purge & Praise") with /purge card removed; both slides carry a small italic note explaining /purge's promotion to Warden. **Counter placeholder** (F9) — "1 / 20" → "1 / 23" matching new slide count. Total slides 22 → 23.
