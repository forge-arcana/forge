# /purge Learnings

> Accumulated learnings from forge cleansing sessions. Absorbed by `/fold`.

<!-- Add learnings below this line -->

## Promoted Learnings Create Triple Duplication (2026-03-19)
**Learning**: When a learning is absorbed into the stack guide's "Key Learnings" section, it becomes the canonical location. The same entry in `global-patterns.md` AND `~/.claude/CLAUDE.md` Code Quality Patterns creates triple maintenance burden. Rule: once a learning is in the stack guide, remove it from `global-patterns.md`. The CLAUDE.md copy is managed separately by the user.
**Apply when**: Running /purge or /fold — check if any global-patterns entry already exists in stack-guide.md.
**Forge-worthy**: yes — universal knowledge management pattern

## Entity Names Are Project Leaks (2026-03-19)
**Learning**: Domain-specific entity variable names (`tripId`, `seatId`, `employerUserId`) in examples reveal the source project even without the project name. Use generic entity names (`orderId`, `itemId`, `targetUserId`) in all forge examples and learnings.
**Apply when**: Writing or reviewing any forge content that includes code examples with entity names.
**Forge-worthy**: yes — forge purity pattern
