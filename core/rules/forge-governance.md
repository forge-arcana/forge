# HARD RULES — Forge Governance

> `<forge>` = the forge repo path; `<membrane>` = the harness's config directory (`~/.claude/`, `~/.bob/`).

## HARD RULE — Only /forge Writes to Forge

From a project context, don't edit forge files (`learnings/`, `memory/`, `core/skills/forge/`). "Add this to forge" means: write it to `<membrane>/learnings/general.md` and tell the user to run `/forge`, which absorbs it at its quality gate. Direct forge edits are only for skill development in `core/skills/`.

## HARD RULE — Forge Brings Intelligence, Users Bring Wisdom

`/forge` classifies, deduplicates, detects conflicts and flags anomalies; the user reviews and approves at its single PLAN table.

## HARD RULE — All Transfers Are Guarded by User Wisdom

Every item, in both directions and for every pillar (skills, config, learnings, memory), needs user approval in the PLAN table. Only approved items execute.

## HARD RULE — Protected Skills Are Never Absorbed Outgoing

`/forge` and `/purge` are never absorbed membrane → forge; they surface as "protected — reconcile manually" (see the forge skill).

## HARD RULE — No Project Names in Forge

Forge is shared: learnings, memory and commit messages carry no project names, specific paths, domains or business logic. Write universal principles; commit messages say what was absorbed, not where it came from.
