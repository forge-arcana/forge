---
name: eval-harness-rename-leak
description: FIXED — run_clean_eval.py now handles git renames and copies correctly
metadata:
  type: reference
---

**Status: FIXED (2026-09-27)**

**What was wrong:** Lines 283–307 split diff-tree output on first whitespace only, so rename/copy lines like `R100\told\tnew` were parsed as status="R100", filepath="old\tnew" (with literal tab). Git checkout with that invalid path failed silently, leaving renamed files unreverting.

**Fix applied:** Refactored diff parsing (lines 283–318) to:
1. Split on tabs (not space) to handle all git diff-tree formats
2. Extract status letter (first char) separately from status number
3. For renames (R) and copies (C), extract both old and new paths
4. For other statuses, extract the single path
5. Revert each path individually, handling all cases (A/M/D/R/C)

**Result:** Renamed and copied files now revert correctly. Baseline task eval continues to work; future tasks with renames will be handled properly.

**Edge cases handled:**
- Pure renames: both old and new paths reverted
- Rename+edit combo: both paths processed
- Copies: both source and target handled
- Adds/deletes: single-path logic unchanged
