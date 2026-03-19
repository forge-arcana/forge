# Forge

A maker's forge. Five arts to shape ideas, challenge architecture, review code, and stress-test — all through AI-guided skills.

---

## The Forge Cycle

Three one-syllable commands drive the forge loop:

| Command | Action | Analogy |
|---------|--------|---------|
| `/mark` | Inspect membrane status (read-only) | Hallmark — inspect and stamp quality |
| `/cast` | Deploy forge → membrane → project | Pour molten metal into the mold |
| `/fold` | Absorb knowledge back into forge | Layer experience into the steel |

---

## Arts (the Five P's)

Arts are specialist agent skills — they adopt a persona and have a self-improving learning loop. Protocol: `skills/forge/protocol.md`.

### Ideation
| Art | What it does |
|-----|-------------|
| `/prime` | The originator — takes raw ideas and gives them form, from spark to pitch/opus to full product blueprint |

### Architecture & Quality
| Art | What it does |
|-----|-------------|
| `/probe` | Challenge blueprint architecture against current best practices (self-improving) |
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
| `/dig` | Think deeper — reframe agent as staff engineer for current discussion |

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
  → writes to forge/learnings/{probe,press,poke,prime,global-patterns}.md
  → never deletes from user's global space

Arts (/prime, /probe, /poke, /press, /pound):
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
│   │   ├── stack-guide.md         # Tech stack decisions
│   │   ├── forge-conventions.md   # Conventions checklist
│   │   └── protocol.md            # Shared art pre-flight/post-flight protocol
│   ├── mark/              # Membrane inspection (read-only status report)
│   ├── monci/             # Monitor CI
│   ├── poke/              # Tech debt code review (art, self-improving)
│   ├── ponci/             # Push and monitor CI
│   ├── pound/             # Deep QA with 21 adversarial personas (art)
│   ├── press/             # Go-live readiness assessment (art, self-improving)
│   ├── qt/                # Quick test
│   ├── srs/               # Restart script setup
│   ├── vsix/              # VS Code extension publishing
│   ├── dig/               # Think deeper — staff engineer stance
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
