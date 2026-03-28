# /purge Learnings

> Accumulated learnings from forge cleansing sessions. Absorbed by `/fold`.

<!-- Add learnings below this line -->

## New Art Addition Triggers Cross-Reference Sweep (2026-03-28)
- **Learning**: Adding a new art creates stale references in README.md, CLAUDE.md (learning cycle arts list), memory/identity.md (counts, ethos prose, arts list + persona), and memory/learnings.md (arts list + cadence note). The art-specific file (SKILL.md) and protocol.md get updated in the same session, but identity/learnings docs lag. Run /purge immediately after any new art addition to catch the stragglers. Specifically: identity.md has 5+ locations with hardcoded art counts; learnings.md has 2; CLAUDE.md learning cycle has 1; README.md has 1 header + 1 section + 1 cadence note.
- **Forge-worthy**: yes — universal pattern: new art addition → immediate /purge to sweep stale cross-references

## Promoted-Duplicate Detection Is Underused (2026-03-28)
- **Learning**: When learnings are promoted from art-specific files (poke-learnings.md, etc.) to global-patterns.md, the source entry is rarely removed. Over time, art-specific files accumulate entries that are exact duplicates of global-patterns.md — invisible to humans, caught by the scan's duplicate title detection. The fix is always the same: global copy wins, source entry removed. Note: the global copy may be less complete than the source — always compare before removing.
- **Forge-worthy**: yes — universal pattern for any learning system where entries can be promoted to a shared store without removing from the source

## New Skill Introduction Requires Full Cross-Reference Sweep (2026-03-27)
**Learning**: When a new skill is created that changes the forge hierarchy (e.g., a new category like "master" above existing arts), ALL cross-references must be updated in the same session — identity docs, protocol, CLAUDE.md, README, memory/learnings, and any skill descriptions that reference the old hierarchy. A purge immediately after creation catches the stragglers that the creator missed.
**Forge-worthy**: yes — universal pattern for any system with distributed references that change when a new top-level concept is introduced.

## Promoted Learnings Create Triple Duplication (2026-03-19)
**Learning**: When a learning is absorbed into the stack guide's "Key Learnings" section, it becomes the canonical location. The same entry in `global-patterns.md` AND `~/.claude/CLAUDE.md` Code Quality Patterns creates triple maintenance burden. Rule: once a learning is in the stack guide, remove it from `global-patterns.md`. The CLAUDE.md copy is managed separately by the user.
**Apply when**: Running /purge or /fold — check if any global-patterns entry already exists in stack-guide.md.

## Entity Names Are Project Leaks (2026-03-19)
**Learning**: Domain-specific entity variable names (`tripId`, `seatId`, `employerUserId`) in examples reveal the source project even without the project name. Use generic entity names (`orderId`, `itemId`, `targetUserId`) in all forge examples and learnings.
**Apply when**: Writing or reviewing any forge content that includes code examples with entity names.

## SKILL.md Bloat From Absorbed Learnings (2026-03-20)
**Learning**: When learnings get promoted into a SKILL.md (e.g., detection heuristics, grep patterns, detailed rules), they bloat the skill over time. Inline grep patterns belong in `forge-scan.sh`, logging rules belong in `forge-conventions.md`. The trim test: "Would the LLM produce worse output if this section were half the length?" If not, reference the source doc instead of restating.
**Apply when**: Running /purge Dimension 3 (Skill Fitness) — check for sections >30% of file that restate content from reference docs or scan scripts.

## Inline Questions Are Invisible to Users (2026-03-21)
**Learning**: Decision-point questions embedded as inline text output get buried and missed by users. The `AskUserQuestion` tool creates a visible, blocking prompt that the user must respond to. Every skill and every general conversation question that requires a user decision before proceeding must use `AskUserQuestion`, never inline text. This was observed repeatedly across both forge skills (13 inline question points across 11 skills) and general Claude conversation flow.
**Apply when**: Writing or reviewing any skill that asks the user to make a choice, confirm an action, or clarify scope. Also applies as a global rule for all Claude interactions.

## Art Consolidation: Scope Over Count (2026-03-20)
**Learning**: When two arts overlap >50% in findings, merge them. A wider-scope art with more dimensions is better than two overlapping arts that produce duplicate findings. The evaluative trifecta (poke → press → pound) works because each has a distinct scope: code quality, operational readiness, adversarial QA. Adding a fourth art for "universal principles" created redundancy with poke's existing tech debt dimensions.
**Apply when**: Proposing new arts or reviewing whether existing arts still earn their seat.

## Bidirectional Sync Race Condition on Direct Source Edits (2026-03-22)
**Learning**: When source-of-truth files are edited directly, deployed copies in the sync target become stale instantly. If the absorption command runs from another session before the deployment command updates the target, it sees DIFFERS and absorbs the stale deployed version — silently reverting the source edit. Prevention: always run the deployment command immediately after direct source edits.
**Apply when**: Operating any bidirectional sync system (deploy + absorb) where source files are edited directly.

## Parallel Arts Need Explicit "Parallel" Label (2026-03-22)
**Learning**: When adding a new evaluative art that runs on a different trigger (e.g., "on UI changes") rather than escalating intensity, explicitly label it as "parallel" from the start. Without the label, it gets inserted into existing sequences by default, creating naming inconsistencies (e.g., "trifecta" with 4 items). The trigger determines placement: same trigger escalation = sequential, different trigger = parallel.
**Apply when**: Adding new arts or evaluative skills to an existing escalation sequence.

## Output Format Templates Are Low-Value Bloat (2026-03-21)
**Learning**: Example output tables with placeholder values (X, ..., [repeat for each]) consume 30-70 lines per skill but add near-zero value — the LLM can infer table structure from column headers alone. Replace verbose markdown template blocks with a compact 3-5 line format description listing section names and column headers. Applied across 6 skills for a 38% total reduction (1,350 → 833 lines) with no behavior loss. The trim test still applies: "Would the LLM produce worse output if this section were half the length?"
**Apply when**: Running /purge Dimension 3 (Skill Fitness) — flag any Output Format section >15 lines as a trim candidate.

## All Transfers Are Guarded by User Wisdom (2026-03-22)
**Learning**: ALL pillars (skills, config, learnings, memory) require user review in BOTH directions. Deploy and absorb operations both present a PLAN table where the user approves/rejects individual items. Nothing transfers without user judgment — no pillar gets a mechanical bypass. A skill can have a bad update, a config can have stale rules, a learning can be wrong. The source of truth for structure is the repo; the source of truth for judgment is the user.
**Apply when**: Designing or reviewing any transfer mechanism between a source repo and deployed copies. Any time you're tempted to say a transfer is "mechanical" or "automatic" — the user reviews every item.
