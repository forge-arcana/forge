# Parse Learnings

> Triage and tiering wisdom for `/parse` — merged from project runs by the `/forge` cycle.

<!-- Add learnings below this line -->

## Headless Triage: an Unsettled Reading Is Not-Actionable, Never a Guess (2026-11-07)
**Learning**: When a headless triage run finds a task genuinely ambiguous (two readings that need different fixes), it must not take the recommended reading and build on it. It ends with tier `not-actionable`: no code change, plus a drafted question for the founder that names each reading and what it would change, written where the caller shows replies. The interactive path still asks. A headless guess produces a confident PR for the wrong reading, which costs a review and a revert; a question costs one reply. Founder ruling. Forge-worthy: yes (changes /parse's Announce step for headless mode, which today records the recommended reading in decisions.md).
**Apply when**: Any skill or writ running headless that resolves ambiguity by recording a recommended choice instead of asking.

## Triage Group Mode: One Plan for Many Related Tasks (2026-11-07)
**Learning**: A triage skill that sizes one task should also take a manifest of many tasks and return one grouping plan instead of acting on any. Input: a manifest file of items (id, title, body, links to existing work, any founder notes, which outrank the item text). Output: a plan file in the caller's schema naming duplicates (each with the item it duplicates), groups to fix together (two or more items, each with a size tier), singles, and unclear items (each with one question for the founder, per the headless rule above). Rules: every item appears exactly once; an item that fits two clusters is placed once, with the reason; an item already covered by open work is flagged, not hidden; nothing is fixed, posted or merged in this mode; the plan is judged by the caller's validator, not the skill's own check. When a group later runs, its tier picks the arts as for a single task (a standard group uses `/patch --brief-only`, which is built for a batch of findings). Founder ruling: a batch of QA findings filed at once must be grouped before any fix runs, so fixes for one root cause don't collide. Forge-worthy: yes (adds a group mode to /parse).
**Apply when**: A tester or user files many related issues at once, or an orchestrator hands triage a batch instead of one task.
