# Forge

A shared tooling repo for AI-guided skills, conventions, and accumulated team wisdom. Forge classifies, deduplicates, and routes knowledge automatically. Users review and decide at the PLAN table. Together, both grow the knowledge base — forge brings the intelligence, users bring the wisdom.

---

## The Forge Cycle

Three one-syllable commands drive the forge loop:

| Command | Action | Analogy |
|---------|--------|---------|
| `/mark` | Inspect membrane status (read-only) | Hallmark — inspect and stamp quality |
| `/cast` | Deploy forge → membrane → project | Pour molten metal into the mold |
| `/fold` | Absorb knowledge back into forge | Layer experience into the steel |

---

## Arts (the Eight P's)

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

The evaluative trifecta — **poke → press → pound** — escalates in intensity. `/preen` runs parallel on UI changes. Cadence: poke often, preen on UI changes, press before milestones, pound before ship.

### When Blocked
| Art | What it does |
|-----|-------------|
| `/pry` | The Lever — relentless solution-finder that cracks "can't be done" claims (self-improving) |

### Forge Hygiene
| Art | What it does |
|-----|-------------|
| `/purge` | The Purist — cleanses stale knowledge, deduplication, and drift across the forge (self-improving) |

## Task Skills

### Development
| Skill | What it does |
|-------|-------------|
| `/cast` | Deploy forge conventions into a project (membrane sync + divergence analysis) |
| `/qt` | Quick test — verify a fix works before manual testing |
| `/srs` | Setup `restart.sh` for local dev stack (ports, zombie cleanup, DB checks) |
| `/wawa` | Outstanding work summary table |
| `/wrap` | Pre-commit ritual: lint → stage → context → docs → compact → commit |
| `/monci` | Monitor CI — watch GitHub Actions runs on current branch |
| `/ponci` | Push to remote and monitor CI |
| `/vsix` | Publish a VS Code extension |
| `/dig` | Think deeper — reframe agent as staff engineer for current discussion |
| `/temper` | Hardened evaluation — runs poke + press N times, consolidates with confidence scoring |
| `/eli5` | Explain Like I'm 5 — distill current topic into simplest possible terms |

### Knowledge Management
| Skill | What it does |
|-------|-------------|
| `/mark` | Inspect membrane — skill drift, learnings, memory status report |
| `/fold` | Absorb knowledge back into forge — config sync, absorb learnings + memories, membrane compaction (runnable from any project) |

---

## Knowledge Flow

Learnings accumulate automatically during work sessions, then flow through three levels: project → global Claude space → forge.

```
During any work session (automatic):
  → Claude auto-memory writes to ~/.claude/projects/<project>/memory/
  → Learnings accumulate in ~/.claude/learnings/ + ~/.claude/memory/

/fold from any project (consumes global staging):
  → reads ~/.claude/learnings/ + ~/.claude/memory/
  → triages, genericizes, deduplicates
  → writes to forge/learnings/{probe,press,poke,preen,prime,pry,global-patterns}.md
  → never deletes from user's global space

Arts (/prime, /probe, /poke, /preen, /press, /pound, /pry, /purge):
  → read forge/learnings/ first → smarter decisions
  → write back to project memory/ → auto-accumulates → cycle continues
```

---

## Project Structure

```
forge/
├── skills/                # Git-tracked source of truth for all global skills
│   ├── prime/             # The originator — ideation to blueprint (art)
│   ├── probe/             # Architecture challenger (art, self-improving)
│   ├── cast/              # Deploy forge conventions into projects
│   ├── fold/              # Knowledge absorption loop (runnable from any project)
│   ├── forge/             # Reference docs (no SKILL.md — not a skill)
│   │   ├── claude-code-rules.md   # Workflow rules
│   │   ├── claude-code-settings.json  # Universal settings reference
│   │   ├── stack-guide.md         # Tech stack decisions
│   │   ├── forge-conventions.md   # Conventions checklist
│   │   └── protocol.md            # Shared art pre-flight/post-flight protocol
│   ├── mark/              # Membrane inspection (read-only status report)
│   ├── monci/             # Monitor CI
│   ├── poke/              # Tech debt code review (art, self-improving)
│   ├── ponci/             # Push and monitor CI
│   ├── preen/             # UI/UX design evaluation (art, self-improving)
│   ├── pound/             # Deep QA with 21 adversarial personas (art)
│   ├── press/             # Go-live readiness assessment (art, self-improving)
│   ├── qt/                # Quick test
│   ├── srs/               # Restart script setup
│   ├── vsix/              # VS Code extension publishing
│   ├── dig/               # Think deeper — staff engineer stance
│   ├── eli5/              # Explain Like I'm 5
│   ├── pry/               # The Lever — relentless solution-finder (art)
│   ├── temper/            # Hardened evaluation — repeated poke + press
│   ├── wawa/              # Outstanding work summary
│   └── wrap/              # Pre-commit ritual
├── learnings/             # Absorbed team wisdom (art-specific + global patterns)
├── memory/                # Team identity, shared conventions, purge learnings
├── .claude/skills/
│   ├── cast/              # Thin bootstrap (so /cast is discoverable on fresh clone)
│   └── purge/             # The Purist — forge hygiene (art, forge-only)
└── CLAUDE.md
```

---

## Quick Start

**New idea?**
```
/prime MyProject    → idea → pitch/opus → product blueprint
/probe              → polished architecture
```

**Fresh machine?**
```
git clone <forge-repo>
cd forge
/cast               → deploys all skills globally, sets up ~/.claude/
```

**New project?**
```
/cast               → apply forge conventions
/srs                → setup restart.sh
```

**During development?**
```
/cast               → sync latest conventions
/qt                 → verify your fix
/dig                → think deeper about this
/poke               → tech debt scan
/preen              → UI/UX design review
/wawa               → where am I?
/wrap               → commit with full context
/mark               → check membrane status
/fold               → feed learnings back to forge
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
