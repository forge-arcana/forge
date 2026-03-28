# Progress Tracking — Ledger & Human-Readable State

> Referenced by [SKILL.md](SKILL.md) — defines the persistence format for session resume and rollback.

## Machine State: `memory/smith-ledger.json`

```json
{
  "version": 1,
  "blueprint": { "file": "...-probed.md", "hash": "<sha256>", "phase": "MVP" },
  "plan": {
    "units": [{
      "name": "Foundation",
      "status": "complete|in-progress|pending",
      "heats": [{
        "number": 1, "title": "...", "blueprintSections": [13, 16],
        "dependencies": [], "status": "complete|in-progress|pending|blocked",
        "evaluations": [{ "art": "poke", "criticals": 0, "importants": 2, "fixCycles": 1, "clean": true }],
        "decisions": [{ "what": "chose WebSocket over SSE", "why": "blueprint Section 14 specifies bidirectional", "heat": 5 }],
        "checkpointSha": "abc1234",
        "apprentice": false, "startedAt": "...", "completedAt": "..."
      }]
    }]
  },
  "currentHeat": 4,
  "totalHeatsEstimate": 15,
  "blockers": [],
  "deferredFindings": [{ "heat": 2, "art": "poke", "severity": "MINOR", "title": "..." }],
  "phaseGates": {
    "foundation": { "arts": ["probe"], "status": "passed", "checkpointSha": "def5678" },
    "core": { "arts": ["probe", "press"], "status": "pending" }
  },
  "finalGate": {
    "convergenceCycles": 0, "status": "pending",
    "cycleHistory": [{ "cycle": 1, "criticals": 2, "importants": 5, "trend": "improving" }]
  },
  "learningsWritten": { "layer1": 3, "layer3": 1 },
  "lastUpdated": "..."
}
```

### Key Fields

- **`decisions`** — per-heat decision rationale. Survives context compaction. "Heat 5: chose WebSocket over SSE because blueprint Section 14 specifies bidirectional."
- **`checkpointSha`** — git commit SHA at each heat completion. Phase gates also snapshot the full ledger to `memory/smith-ledger-checkpoint-<gate>.json`.
- **`cycleHistory`** — final gate convergence tracking. Used for stall detection: if findings don't decrease for 2 consecutive cycles, smith triggers user review.
- **`deferredFindings`** — MINOR findings accepted as-is, carried forward for future cleanup.

## Human-Readable: `memory/smith-progress.md`

```markdown
# Smith Progress — [Project Name]

## Current State
- **Phase**: MVP
- **Heat**: 4 of ~15
- **Unit**: Core Workflow (heat 1 of 5)
- **Status**: Building user registration flow

## Completed
| # | Unit | Heat | Arts | Cycles | Result |
|---|------|------|------|--------|--------|
| 1 | Foundation | Scaffolding + schema | poke | 1 | Clean |
| 2 | Foundation | Auth system | poke | 2 | Clean |
| 3 | Foundation | Dev tooling | — | 0 | Clean |
| — | **Gate** | Foundation | probe | — | **Passed** |

## Deferred Findings
- [MINOR] Consider extracting auth middleware (Heat 2, /poke)

## Apprentice Activity
- Heat 3 ran as apprentice parallel to Heat 2 (success, no merge conflicts)

## Blockers
None
```
