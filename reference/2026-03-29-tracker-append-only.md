# Why the Fold Tracker is Append-Only

**Date**: 2026-03-29
**Context**: After multiple incidents of duplicate learning re-absorption caused by purge removing tracker entries, the team settled on an append-only tracker design. This document captures the full reasoning so future sessions don't re-open the question.

---

## The Problem

The fold tracker (`learnings/.fold-tracker.json`) stores `processedEntries` — titles of learnings from `general.md` that fold has already triaged and absorbed into forge. Its purpose: prevent fold from re-absorbing the same learning twice.

Purge repeatedly caused duplicate re-absorption by removing "orphan" tracker entries — entries that existed in the tracker but didn't match any forge learning file title. The reasoning was: "if the learning isn't in forge, the tracker entry is stale — clean it up."

This reasoning was wrong.

## Why Removal Causes Duplicates

1. User A writes "Foo" to their `~/.claude/learnings/general.md` (auto-memory during a project session)
2. User A runs `/fold` → "Foo" absorbed into forge's `global-patterns.md`, title added to shared tracker
3. Someone removes "Foo" from tracker (purge "orphan cleanup", or any other removal)
4. User A still has "Foo" in their `general.md` — fold NEVER deletes source entries
5. User A (or any user with "Foo" in their `general.md`) runs `/fold` → "Foo" not in tracker → fold re-absorbs → **duplicate in forge**

The tracker entry is the only thing preventing step 5. Removing it is removing the immune system.

## Why "Orphan" Detection Was Wrong

The orphan scan checked: "is this tracker title in any `learnings/*.md` file?" If not, it labeled it "ORPHAN" and purge removed it. This failed for three reasons:

1. **Title mismatches**: "Test Factories Must Mirror DI Container" vs "Test Factories Must Mirror Production DI Container" — same learning, different title. Exact matching missed it.
2. **Wrong search scope**: Some learnings existed in `memory/*.md` or `purge-learnings.md`, not in `learnings/*.md`. The scan only checked learnings.
3. **Purged entries are valid residue**: A learning can be purged from forge (stale/consolidated) while the original entry remains in the user's `general.md`. The tracker entry must persist to prevent re-absorption.

## Why No Skill Can Safely Compact the Tracker

The tracker lives in forge (shared repo, committed to git). Each user's `general.md` lives on their local machine (private, per-user). The fundamental constraint:

**No single user — and no skill running from any single machine — can see all users' membranes.**

### Purge can't compact
Purge runs from forge. It can't see any user's membrane. It has zero information about which tracker entries are still needed.

### Fold can't compact
Fold runs from a user's machine. It can see THAT user's membrane. But removing a tracker entry based on one user's membrane state breaks every OTHER user who still has the entry in their `general.md`.

### Even a "smart" compaction ceremony fails
"Wait for all users to archive their `general.md`, then compact." But:
- Who defines "all users"? The set is open.
- A user returning after 6 months with a stale membrane would trigger re-absorption.
- The ceremony costs more human coordination effort than the ~10KB it saves.

## The Append-Only Design

**The tracker's `processedEntries` array only grows. It never shrinks. No exceptions.**

- A tracker entry without a matching forge file is **harmless residue** — fold sees it, skips it, zero cost.
- A tracker entry that IS removed causes **duplicate re-absorption** — fold sees the membrane entry as "new" and absorbs it again.

**Cost of keeping**: ~10 bytes per entry. 1000 entries ≈ 10KB. 10,000 entries ≈ 100KB. Fold builds a Set and does O(1) lookups. Performance impact: unmeasurable.

**Cost of removing**: Duplicate learnings in forge. User frustration. Time spent debugging why the same learning appeared again. Multiple incidents across multiple sessions.

The math is clear: keep everything, remove nothing.

## Growth Rate

- Users run `/fold` monthly (typical cadence)
- Each fold processes ~5-15 new entries from `general.md`
- At 12 folds/year × 10 entries × 3 users = ~360 entries/year
- After 5 years: ~1800 entries ≈ 18KB
- The tracker will never be a practical problem.

## The Rules (enforced in purge SKILL.md, fold SKILL.md, forge-status.sh)

1. **Purge**: HARD RULE — never touch the tracker. No orphan removal. No cleanup. No compaction.
2. **Fold**: HARD RULE — tracker is append-only. Only add entries, never remove.
3. **forge-status.sh**: Tracker entries without forge matches are labeled "residue (safe)" — not "ORPHAN". The label matters because it shapes what the agent does next.
4. **No skill, no user, no automation removes `processedEntries`.** The only valid removal is a deliberate manual operation where the operator understands the full consequence.

## Lessons

- **Cheap to keep, expensive to remove.** The asymmetry is extreme. Keeping a stale entry costs 10 bytes. Removing a needed entry costs hours of debugging and user trust.
- **Shared state protecting per-user state cannot be compacted by any single user.** This is an architectural invariant, not a policy choice.
- **Labels shape behavior.** Calling something "ORPHAN" implies it should be cleaned up. Calling it "residue (safe)" implies it should be left alone. The forge-status.sh label change was as important as the SKILL.md rule change.
- **The immune system metaphor holds.** The tracker is the immune memory. Removing an antibody because the pathogen isn't currently present doesn't make you healthier — it makes you vulnerable to re-infection.
