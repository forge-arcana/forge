# Forge

A maker's forge. Pitch ideas, blueprint products, architect systems, and build — all through AI-guided skills.

---

## The Forge Cycle

Three one-syllable commands drive the forge loop:

| Command | Action | Analogy |
|---------|--------|---------|
| `/mark` | Inspect membrane status (read-only) | Hallmark — inspect and stamp quality |
| `/cast` | Deploy forge → membrane → project | Pour molten metal into the mold |
| `/fold` | Absorb knowledge back into forge | Layer experience into the steel |

---

## Skills

### Ideation
| Skill | What it does |
|-------|-------------|
| `/pitch` | Elevator pitch generator — 6-round AI interview → investor-ready pitch pack |
| `/bluep` | Product blueprint generator — 7-round interview → 22-section buildable spec |

### Architecture & Quality
| Skill | What it does |
|-------|-------------|
| `/arch` | Polish blueprint architecture against current best practices (self-improving) |
| `/audit` | Go-live readiness scorecard across 7 dimensions (self-improving) |
| `/dive` | Deep QA with 19 adversarial personas — generates tests, finds edge cases |
| `/quick` | Staff-engineer code review for tech debt and logging hygiene (self-improving) |

### Development
| Skill | What it does |
|-------|-------------|
| `/cast` | Deploy forge conventions into a project (membrane sync + divergence analysis) |
| `/qt` | Quick test — verify a fix works before manual testing |
| `/srs` | Setup `restart.sh` for local dev stack (ports, zombie cleanup, DB checks) |
| `/wawa` | Outstanding work summary table |
| `/wrap` | Pre-commit ritual: lint → stage → context → docs → compact → commit |

### Knowledge Management
| Skill | What it does |
|-------|-------------|
| `/mark` | Inspect membrane — skill drift, learnings, memory status report |
| `/fold` | Absorb knowledge back into forge — config sync, review & prune, absorb learnings + memories, archive staging (runnable from any project) |

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
  → writes to forge/learnings/{arch,audit,quick,global-patterns}.md
  → never deletes from user's global space

Self-improving skills (/arch, /audit, /quick):
  → read forge/learnings/ first → smarter decisions
  → write back to project memory/ → auto-accumulates → cycle continues
```

---

## Project Structure

```
forge/
├── skills/                # Git-tracked source of truth for all global skills
│   ├── arch/              # Architecture polisher (self-improving)
│   ├── audit/             # Go-live readiness assessment (self-improving)
│   ├── bluep/             # Product blueprint generator
│   ├── cast/              # Deploy forge conventions into projects
│   ├── dive/              # Deep QA with 19+ adversarial personas
│   ├── fold/              # Knowledge absorption loop (runnable from any project)
│   ├── forge/             # Reference docs (no SKILL.md — not a skill)
│   │   ├── claude-code-rules.md   # Workflow rules
│   │   ├── stack-guide.md         # Tech stack decisions
│   │   └── forge-conventions.md   # Conventions checklist
│   ├── mark/              # Membrane inspection (read-only status report)
│   ├── pitch/             # Elevator pitch generator
│   ├── qt/                # Quick test
│   ├── quick/             # Tech debt code review (self-improving)
│   ├── srs/               # Restart script setup
│   ├── wawa/              # Outstanding work summary
│   └── wrap/              # Pre-commit ritual
├── learnings/             # Absorbed team wisdom
├── memory/                # Team identity & shared conventions
├── .claude/skills/
│   └── cast/              # Thin bootstrap (so /cast is discoverable on fresh clone)
└── CLAUDE.md
```

---

## Quick Start

**New idea?**
```
/pitch MyProject    → pitch pack
/bluep MyProject    → product blueprint
/arch               → polished architecture
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
/quick              → tech debt scan
/wawa               → where am I?
/wrap               → commit with full context
/mark               → check membrane status
/fold               → feed learnings back to forge
```

**Before go-live?**
```
/audit              → readiness scorecard
/dive "auth flow"   → deep QA on specific area
```
