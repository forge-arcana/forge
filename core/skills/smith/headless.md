# Smith — Headless Branch

> Applies when `FORGE_HEADLESS=1`. Follows the Headless Mode section of the [Forge Protocol](../forge/protocol.md). Interactive behaviour in `SKILL.md` is unchanged when the variable is unset.

A headless caller already tiered the work and chose smith. Nobody can answer questions, and the product repo's `memory/` is not smith's to write.

1. **Never resume.** Do NOT read or resume an existing `memory/smith-ledger.json` or `memory/smith-workspec.md` in the repo, even when present. Skip Session Resume and start fresh.
2. **State lives at `$FORGE_OUT/smith/`.** Keep the ledger (`smith-ledger.json`), workspec (`smith-workspec.md`) and progress file (`smith-progress.md`) there. Wherever `SKILL.md` says `memory/smith-*`, read and write `$FORGE_OUT/smith/smith-*`. Layer 1 and Layer 3 learnings go to `$FORGE_OUT/learnings/` per the protocol.
3. **Step 0.5 Scope Gate: skip the interactive advice.** The caller already tiered the work. Still build the work spec (to `$FORGE_OUT/smith/smith-workspec.md`) and continue to Step 1.
4. **No checkpoints, commits or rollback.** Skip `smith-checkpoint.sh`, phase-gate commits (and any `/wrap`), `smith-rollback.sh` and the push. Leave all changes in the working tree. Heat order and the evaluative gates are unchanged.
5. **Every prompt resolves to its recommended option** (Touchstone gate, Pitch gate, Atlas offer, circuit-breaker conflicts) and is appended to `$FORGE_OUT/decisions.md`.
6. **No web.** Claims that would need it are marked "unverified (no web)".
