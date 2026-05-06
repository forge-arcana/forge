# HARD RULES — Forge Governance

> Rules that govern how the forge repo and the user's membrane interact. These apply
> regardless of which harness (Claude Code, Bob, Cursor, etc.) is in use.
>
> Path conventions: `<forge>` = the forge repo path; `<membrane>` = the harness's
> per-tool config directory (`~/.claude/`, `~/.bob/`, etc.).

## HARD RULE — Only /forge Writes to Forge

> **No project, no skill, no manual edit touches forge repo files directly.**
> `/forge` is the gatekeeper for learnings, memory, config sync, and skill reverse-sync.
> Direct edits to forge are only for skill development (editing source files in `core/skills/`).
>
> **When a user says "add this to forge" from a project context**, they mean:
> 1. Write the learning to `<membrane>/learnings/general.md`
> 2. Tell the user to run `/forge` to absorb it through the fold phase
>
> **NEVER** open the forge repo and edit `learnings/`, `memory/`, or `core/skills/forge/` files from a project context.
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
> Absorbing `/forge` mid-run would silently overwrite the rules currently running.
> Absorbing `/purge` could break the next cleanse.
> If either appears as `DEPLOYED-DIFFERS`, it surfaces in the ⚠ CONFLICTS section with
> note "protected — reconcile manually." The user may choose `[↓] accept forge`
> (overwrite local), but `[↑] keep membrane` is disabled.

## HARD RULE — No Project Names in Forge

> **Forge is a shared repo. NEVER include project-specific details in learnings, memory, or commit messages.**
> Strip all project names, specific file paths, domains, and business logic before writing.
> Learnings must read as universal principles. Commit messages must describe *what* was absorbed,
> not *where* it came from.
