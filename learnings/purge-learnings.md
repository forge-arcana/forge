# /purge Learnings

> Accumulated learnings from forge cleansing sessions. Absorbed by `/fold`.

<!-- Add learnings below this line -->

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

## Output Format Templates Are Low-Value Bloat (2026-03-21)
**Learning**: Example output tables with placeholder values (X, ..., [repeat for each]) consume 30-70 lines per skill but add near-zero value — the LLM can infer table structure from column headers alone. Replace verbose markdown template blocks with a compact 3-5 line format description listing section names and column headers. Applied across 6 skills for a 38% total reduction (1,350 → 833 lines) with no behavior loss. The trim test still applies: "Would the LLM produce worse output if this section were half the length?"
**Apply when**: Running /purge Dimension 3 (Skill Fitness) — flag any Output Format section >15 lines as a trim candidate.
