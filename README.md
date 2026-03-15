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
| `/wawa` | Outstanding work summary table |
| `/wrap` | Pre-commit ritual: learnings → context → docs → lint → compact → commit |

### Forge Maintenance (forge repo only)
| Skill | What it does |
|-------|-------------|
| `/reforge` | Sync config drift + absorb learnings from all projects into `learnings/` |

---

## Knowledge Flow

Learnings flow through three levels: project → global Claude space → forge.

```
/wrap in any project (two-stage):
  Stage 1: project memory/learnings.md + ~/.claude/projects/<project>/memory/
  Stage 2: promote generics → ~/.claude/learnings/ + ~/.claude/memory/

/reforge in forge (consumes global only):
  → reads ~/.claude/learnings/ + ~/.claude/memory/
  → triages, genericizes, deduplicates
  → writes to forge/learnings/{arch,audit,quick,global-patterns}.md
  → never deletes from user's global space

Self-improving skills (/arch, /audit, /quick):
  → read forge/learnings/ first → smarter decisions
  → write back to project memory/ → /wrap promotes → cycle continues
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
/wawa                → where am I?
/wrap               → commit with full context
```

**Before go-live?**
```
/audit              → readiness scorecard
/dive "auth flow"   → deep QA on specific area
```
