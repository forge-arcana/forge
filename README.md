# Forge

A shared tooling repo for AI-guided skills, conventions, and accumulated team wisdom. Forge classifies, deduplicates, and routes knowledge automatically. Users review and decide at the PLAN table. Together, both grow the knowledge base — forge brings the intelligence, users bring the wisdom.

---

## The Masters — Hearts of the Forge

At the center of the forge stand three masters. Distinct domains, complementary roles. The Smith builds the work. The Wedge gives it a face. The Warden tends the forge that does the building.

| Title | Command | Role |
|-------|---------|------|
| **The Smith** | `/smith` | Master builder — wields every art, summons apprentices, forges the product through iterative heats |
| **The Wedge** | `/wedge` | Master of aesthetic — drives a single decisive thrust that splits the project's identity from generic AI slop, crystallized into the Touchstone (an HTML masterpiece) |
| **The Warden** | `/purge` | Master tender — guards the forge itself against drift, staleness, contamination, and bloat |

### The Smith — Master Builder

`/smith` is the user's proxy for construction. Give it a probed blueprint (from `/prime` + `/probe`) plus a Touchstone (from `/wedge`) and it autonomously builds the product through iterative **heats** — cycles of plan, build, evaluate, fix. Each heat sharpens the blade. The smith never stops until zero critical and zero important findings remain.

A human smith works alone at the anvil. This smith summons **apprentices** — subagents that multiply throughput wherever the dependency graph allows. It looks ahead, detects idle capacity as waste, and starts work in anticipation of what comes next. Sequential execution of independent work is a failure of imagination.

The smith wields every art at the right moment:
- `/poke` after every heat (the workhorse)
- `/preen` when UI is involved (the design eye)
- `/press` at unit boundaries (readiness check)
- `/probe` at phase boundaries (architecture re-evaluation)
- `/temper` + `/pound` at the final gate — a **convergence loop** that repeats until the blade rings clean
- `/pry` when blocked (crack the wall)

Three layers of wisdom accumulate independently:
1. **Smith learnings** — how to orchestrate (build order, heat sizing, wrap timing)
2. **Art learnings** — how to evaluate (each art's self-improving loop, driven by smith's repeated use)
3. **Apprentice proficiency** — how to delegate (parallelization patterns, scope sizing)

When a Touchstone exists, every UI-facing apprentice receives the Touchstone's `:root` token block as part of its commission. Apprentices that introduce non-Touchstone fonts, colors, or motion are rejected and re-tasked. The Smith conforms; the Touchstone is the standard.

The more the smith works, the sharper everything gets. Never-ending mastery of its craft.

### The Wedge — Master of Aesthetic

`/wedge` is the user's proxy for visual identity. Reads the **Opus + Vow** — the manuscript of the idea and the pledge that grounds it — and forges from them a **Touchstone**: a single self-contained HTML masterpiece that defines the project's visual constitution.

A wedge has one edge. Driven once, driven hard, driven straight — it cannot hedge and remain a wedge. The Wedge's first HARD RULE is *commit to ONE direction*: no "modern but classic", no fused aesthetics, no purple-gradient-on-white safety. The wedge splits the project's identity from generic AI slop or it fails.

The Wedge channels the **council of master designers** plus the **conglomerate of human visual arts** — Rynzhuk, Korpai, Kuznetsov, MDS, Locomotive, Obys, Clay, Ramotion, plus Bauhaus, Swiss typography, brutalism, Memphis, *ma*, Art Deco, illuminated manuscripts, Damascene metalwork, Constructivist propaganda, mid-century modernism. Plural in voices, singular in conviction.

Six heats:
1. **Distillation** — read Opus + Vow, produce a Soul Brief (3–5 emotional keywords + tonal anchor + refused tones)
2. **Council fan-out** — three parallel design-apprentices, each channeling a distinct master archetype, return a Direction Card
3. **Council verdict** — user picks one direction (or hybridizes via Other; the Wedge synthesizes into ONE)
4. **Crystallization** — extends the touchstone-scaffold.html into the project's actual masterpiece (real Google Fonts, atmospheric backdrop, hero + primary task + moment of delight + token legend)
5. **Refinement** — auto-invokes `/preen` for usability check; locks
6. **Persist** — `[PROJECT]_Touchstone_V1.0.html` written; downstream conformance begins

The Touchstone is **the standard**. Smith's apprentices inherit its tokens. The Pitch is rendered HTML through it. `/probe` and `/preen` load it for visual context. The wedge is driven once; what comes after conforms.

Universal aesthetic principles propagate to `<forge>/learnings/global-patterns.md` during fold; project-specific Touchstones stay in their projects.

### The Warden — Master Tender

`/purge` is the Warden — guardian of the forge itself. While the Smith forges products from blueprints, the Warden ensures the forge that does the forging stays sharp and pure. Stale knowledge dulls the blade. Drift contaminates the steel. Duplicates weigh down the anvil. Project names that leak in betray the forge's universality. The Warden burns it all away until only what matters remains.

Four dimensions, analyzed in parallel by independent subagents — Knowledge Purity (learnings), Memory Hygiene (memory), Skill Fitness (skill bloat and consistency), Reference Integrity (stack guide, rules, CLAUDE.md). The master consolidates findings, the user confirms, the Warden applies.

The Warden is summoned, never scheduled. Lives only at `.claude/skills/purge/` (never deployed to user membranes — the Warden writes to forge directly, so containment by location prevents projects from writing to forge by proxy).

---

## The Forge Cycle

> In the forge, we forge.

One command, three internal motions. `/forge` unifies what used to be three separate commands (`/mark`, `/cast`, `/fold`) into a single bidirectional cycle.

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

---

## Arts (the Nine P's)

Arts are specialist agent skills — they adopt a persona and have a self-improving learning loop. Protocol: `skills/forge/protocol.md`.

### Ideation
| Art | What it does |
|-----|-------------|
| `/prime` | The originator — takes raw ideas and gives them form, from spark to pitch/opus to full product blueprint |

### Architecture & Quality
| Art | What it does |
|-----|-------------|
| `/probe` | Challenge architecture decisions against current best practices — probes blueprints, plans, or conversations (self-improving) |
| `/poke` | Staff-engineer code review for tech debt and logging hygiene (self-improving) |
| `/preen` | UI/UX design evaluation — Don Norman's principles applied to interfaces (self-improving) |
| `/press` | Go-live readiness scorecard across 7 dimensions (self-improving) |
| `/pound` | Deep QA with 21 adversarial personas — generates tests, finds edge cases |

The evaluative trifecta — **poke → press → pound** — escalates in intensity. `/preen` runs parallel on UI changes. `/pitch` runs orthogonal — business model viability, before building and before ship. Cadence: poke often, preen on UI changes, pitch before build + before ship, press before milestones, pound before ship.

### Business Model
| Art | What it does |
|-----|-------------|
| `/pitch` | VC-style business model critique — market, value prop, revenue model, moat, GTM, kill conditions (self-improving) |

### When Blocked
| Art | What it does |
|-----|-------------|
| `/pry` | The Lever — relentless solution-finder that cracks "can't be done" claims (self-improving) |

> The Masters (`/smith`, `/wedge`, and `/purge`) are documented at the top of this README — they're not arts, they're the ones who wield (Smith), give visual form (Wedge), and tend (Warden) the forge itself.

## Task Skills

| Skill | What it does |
|-------|-------------|
| `/forge` | The forge cycle — bidirectional sync (triage + apply + absorb + commit). Also handles session toggle via `on`/`off`. |
| `/qt` | Quick test — verify a fix works before manual testing |
| `/srs` | Setup `restart.sh` for local dev stack (ports, zombie cleanup, DB checks) |
| `/wawa` | Outstanding work summary table |
| `/wrap` | Pre-commit ritual: lint → stage → context → docs → compact → commit |
| `/monci` | Monitor CI — watch GitHub Actions runs on current branch |
| `/ponci` | Push to remote and monitor CI |
| `/vsix` | Publish a VS Code extension |
| `/dig` | Think deeper — reframe agent as staff engineer for current discussion |
| `/temper` | Hardened evaluation — runs poke + press N times, consolidates with confidence scoring |
| `/cicd` | Local CI/CD pipeline — lint, typecheck, test, build, deploy. Auto-fixes failures |
| `/eli5` | Explain Like I'm 5 — distill current topic into simplest possible terms |

---

## Knowledge Flow

Learnings accumulate automatically during work sessions, then flow through three levels: project → global Claude space → forge. Everything moves through the `/forge` cycle.

```
During any work session (automatic):
  → Claude auto-memory writes to ~/.claude/projects/<project>/memory/
  → Learnings accumulate in ~/.claude/learnings/ + ~/.claude/memory/

/forge from any project (one bidirectional cycle):
  ↓ incoming: forge/skills + forge/learnings + forge/memory → user's ~/.claude/
  ↑ outgoing: user's ~/.claude/ accumulations → forge/learnings + forge/memory
  ⚠ conflicts: user picks a side per row

  Fold phase triages, genericizes, deduplicates before writing to forge.
  Cast phase deploys forge updates before the fold phase runs.
  Never deletes from user's global space.

Arts (/prime, /probe, /poke, /preen, /press, /pound, /pitch, /pry, /praise):
  → read forge/learnings/ first → smarter decisions
  → write back to project memory/ → auto-accumulates → next /forge absorbs
```

---

## Project Structure

```
forge/
├── skills/                # Git-tracked source of truth for all global skills
│   ├── prime/             # The originator — ideation to blueprint (art)
│   ├── probe/             # Architecture challenger (art, self-improving)
│   ├── poke/              # Tech debt code review (art, self-improving)
│   ├── preen/             # UI/UX design evaluation (art, self-improving)
│   ├── press/             # Go-live readiness assessment (art, self-improving)
│   ├── pound/             # Deep QA with 21 adversarial personas (art)
│   ├── pitch/             # VC-style business model critique (art)
│   ├── pry/               # The Lever — relentless solution-finder (art)
│   ├── praise/            # Feedback router — closes the build-ship-learn loop (art)
│   ├── smith/             # The Master Builder — autonomous product forging
│   ├── wedge/             # The Master of Aesthetic — Touchstone (HTML masterpiece)
│   ├── forge/             # The forge cycle SKILL.md + reference docs
│   │   ├── SKILL.md               # /forge command
│   │   ├── claude-code-rules.md   # Workflow rules
│   │   ├── claude-code-settings.json  # Universal settings reference
│   │   ├── stack-guide.md         # Tech stack decisions
│   │   ├── forge-conventions.md   # Conventions checklist
│   │   ├── preflight.md           # Shared drift classification
│   │   └── protocol.md            # Shared art pre-flight/post-flight protocol
│   ├── monci/             # Monitor CI
│   ├── ponci/             # Push and monitor CI
│   ├── qt/                # Quick test
│   ├── srs/               # Restart script setup
│   ├── vsix/              # VS Code extension publishing
│   ├── dig/               # Think deeper — staff engineer stance
│   ├── eli5/              # Explain Like I'm 5
│   ├── cicd/              # Local CI/CD pipeline
│   ├── temper/            # Hardened evaluation — repeated poke + press
│   ├── wawa/              # Outstanding work summary
│   └── wrap/              # Pre-commit ritual
├── learnings/             # Absorbed team wisdom (art-specific + global patterns)
├── memory/                # Team identity & shared conventions
├── .claude/skills/
│   ├── forge/             # Bootstrap (so /forge is discoverable on fresh clone)
│   └── purge/             # The Warden — master tender (forge-internal, never deployed)
└── CLAUDE.md
```

---

## Quick Start

**New idea?**
```
/prime MyProject    → Opus → Vow → Touchstone (auto /wedge) → Pitch (HTML, if external) → Blueprint → Pattern
/wedge              → drive the wedge into Touchstone (auto-invoked from /prime; explicit also)
/probe              → polished Pattern (architecture)
/smith              → Pattern + Touchstone → running product (the full forge)
```

**Fresh machine?**
```
git clone <forge-repo>
cd forge
/forge              → deploys all skills globally, sets up ~/.claude/
```

**New project?**
```
/forge              → apply forge conventions + sync membrane
/srs                → setup restart.sh
```

**During development?**
```
/forge              → run the cycle (incoming + outgoing in one pass)
/forge --dry        → inspect without applying
/qt                 → verify your fix
/dig                → think deeper about this
/poke               → tech debt scan
/preen              → UI/UX design review
/wawa               → where am I?
/wrap               → commit with full context
```

**Stuck on something "impossible"?**
```
/pry                → crack the blocker
```

**Before go-live?**
```
/temper             → hardened evaluation (poke + press × 3)
/press              → readiness scorecard
/pound "auth flow"  → deep QA on specific area
```
