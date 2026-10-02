# The Learning Membrane

> Referenced by [SKILL.md](SKILL.md) — what each layer captures, with examples.

Three layers of wisdom accumulate independently. Each feeds back into the next run.

### Layer 1: Smith Learnings (`memory/smith-learnings.md`)

The master's own wisdom about *how to forge* — orchestration, not code quality:

- Build order optimizations (e.g., "scaffold logging before auth — auth errors need log context")
- Heat decomposition insights (e.g., "payment heats are 2x larger than estimated — split into sub-heats")
- Art combination effectiveness (e.g., "poke + preen parallel on UI heats catches 30% more issues than sequential")
- Circuit breaker calibration (e.g., "3 cycles too few for payment logic, 5 needed")
- Wrap timing patterns (e.g., "wrap after Foundation unit, not after each Foundation heat")

**Format** (follows forge protocol):
```markdown
## [Date] — [Short Title]
- **Learning**: [universal principle, no project names/paths]
- **Forge-worthy**: [yes/no] — [reason]
```

### Layer 2: Art Learnings (existing files)

Each art writes to its own `memory/<art>-learnings.md` via the forge protocol post-flight. Smith does not touch these. The arts evolve independently — smith is the engine that drives their repetition.

The more smith works, the more each art runs, the sharper each art gets.

### Layer 3: Apprentice Proficiency (`memory/smith-apprentice-log.md`)

Smith learning how to best deploy apprentices:

- Which task types benefit from parallelization vs. which cause merge conflicts
- Optimal apprentice scope sizing (too broad = context overflow, too narrow = overhead waste)
- Fan-out patterns that worked vs. patterns that needed manual merge resolution
- Evidence sharing strategies (shared collection vs. per-apprentice collection)

**Format**: Same as Layer 1.

### Preflight Reading

Smith reads all three layers during Step 0. Layer 1 shapes the build plan and heat cycle strategy. Layer 3 shapes apprentice allocation decisions. Layer 2 is read by each art in its own preflight — smith doesn't interfere with art wisdom.

### Post-Heat Capture

After each heat's evaluate-fix cycle:
- Write to Layer 1 if smith learned something about orchestration
- Write to Layer 3 if smith learned something about apprentice effectiveness
- Arts write to Layer 2 via their own post-flight (automatic, no smith intervention)

Three independent streams, one forge.

### Forge-Worthy Promotion

Learnings marked `Forge-worthy: yes` in any layer get promoted to the membrane's `learnings/general.md` by the `/forge` cycle's fold phase, same as art learnings. Universal orchestration patterns flow back into the forge for all future smith runs across all projects.
