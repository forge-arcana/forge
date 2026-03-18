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

## Foundries

Foundries are specialist agent skills — they adopt a persona and have a self-improving learning loop. Protocol: `skills/forge/foundry-protocol.md`.

### Ideation
| Foundry | What it does |
|---------|-------------|
| `/pitch` | Elevator pitch generator — 6-round AI interview → investor-ready pitch pack |
| `/bluep` | Product blueprint generator — 7-round interview → 22-section buildable spec |

### Architecture & Quality
| Foundry | What it does |
|---------|-------------|
| `/arch` | Polish blueprint architecture against current best practices (self-improving) |
| `/poke` | Staff-engineer code review for tech debt and logging hygiene (self-improving) |
| `/press` | Go-live readiness scorecard across 7 dimensions (self-improving) |
| `/pound` | Deep QA with 21 adversarial personas — generates tests, finds edge cases |

The evaluative trio — **poke → press → pound** — escalates in intensity.

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
  → writes to forge/learnings/{arch,press,poke,global-patterns}.md
  → never deletes from user's global space

Foundries (/arch, /poke, /press, /pound, /pitch, /bluep):
  → read forge/learnings/ first → smarter decisions
  → write back to project memory/ → auto-accumulates → cycle continues
```

---

## Project Structure

```
forge/
├── skills/                # Git-tracked source of truth for all global skills
│   ├── arch/              # Architecture polisher (foundry, self-improving)
│   ├── bluep/             # Product blueprint generator (foundry)
│   ├── cast/              # Deploy forge conventions into projects
│   ├── fold/              # Knowledge absorption loop (runnable from any project)
│   ├── forge/             # Reference docs (no SKILL.md — not a skill)
│   │   ├── claude-code-rules.md   # Workflow rules
│   │   ├── stack-guide.md         # Tech stack decisions
│   │   ├── forge-conventions.md   # Conventions checklist
│   │   └── foundry-protocol.md    # Shared foundry pre-flight/post-flight protocol
│   ├── mark/              # Membrane inspection (read-only status report)
│   ├── monci/             # Monitor CI
│   ├── pitch/             # Elevator pitch generator (foundry)
│   ├── poke/              # Tech debt code review (foundry, self-improving)
│   ├── ponci/             # Push and monitor CI
│   ├── pound/             # Deep QA with 21 adversarial personas (foundry)
│   ├── press/             # Go-live readiness assessment (foundry, self-improving)
│   ├── qt/                # Quick test
│   ├── srs/               # Restart script setup
│   ├── vsix/              # VS Code extension publishing
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
/poke               → tech debt scan
/wawa               → where am I?
/wrap               → commit with full context
/mark               → check membrane status
/fold               → feed learnings back to forge
```

**Before go-live?**
```
/press              → readiness scorecard
/pound "auth flow"  → deep QA on specific area
```
