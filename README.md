# Forge

A maker's forge. Pitch ideas, blueprint products, architect systems, and build — all through AI-guided skills.

---

## Skills

### Ideation
| Skill | What it does |
|-------|-------------|
| `/pitch` | Elevator pitch generator — 5-round AI interview → investor-ready pitch pack |
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
| `/forge` | Initialize or sync a project with forge conventions |
| `/qt` | Quick test — verify a fix works before manual testing |
| `/srs` | Setup `restart.sh` for local dev stack (ports, zombie cleanup, DB checks) |
| `/wow` | Outstanding work summary table |
| `/wrap` | Pre-commit ritual: learnings → context → docs → lint → compact → commit |

### Forge Maintenance (forge repo only)
| Skill | What it does |
|-------|-------------|
| `/reforge` | Sync config drift + absorb learnings from all projects into `learnings/` |

---

## Self-Improving Loop

Skills like `/arch`, `/audit`, and `/quick` write learnings to a project's `memory/*-learnings.md`. Run `/reforge` from this repo to absorb those learnings into `forge/learnings/`. Next time any self-improving skill runs, it reads the global learnings first.

```
/arch in project A → writes memory/arch-learnings.md
/audit in project B → writes memory/audit-learnings.md
/reforge in forge → absorbs all into forge/learnings/
/arch in project C → reads forge/learnings/ first → smarter decisions
```

---

## Project Structure

```
forge/
├── code/                  # Reference docs
│   ├── claude-code-rules.md   # Workflow rules
│   ├── stack-guide.md         # Tech stack decisions
│   └── qa-review-prompt.md    # QA personas framework
├── pitch/                 # Pitch & blueprint frameworks + samples
│   ├── pitch-forge.md        # Pitch interview framework
│   ├── product-blueprint.md  # Blueprint interview framework
│   └── <project>/            # Sample outputs per project
├── learnings/             # Global learning store
│   ├── arch-learnings.md
│   ├── audit-learnings.md
│   ├── quick-learnings.md
│   └── global-patterns.md
└── .claude/skills/        # Forge-local skills
    └── reforge/
```

---

## Quick Start

**New idea?**
```
/pitch MyProject    → pitch pack
/bluep MyProject    → product blueprint
/arch               → polished architecture
```

**New project?**
```
/forge              → apply forge conventions
/srs                → setup restart.sh
```

**During development?**
```
/qt                 → verify your fix
/quick              → tech debt scan
/wow                → where am I?
/wrap               → commit with full context
```

**Before go-live?**
```
/audit              → readiness scorecard
/dive "auth flow"   → deep QA on specific area
```
