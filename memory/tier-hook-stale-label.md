---
name: tier-hook-stale-label
description: FIXED — tier-routing hook now explicitly labels Haiku sessions
metadata:
  type: feedback
---

**Status: FIXED (2026-09-27)**

**What was wrong:** Tier-routing.sh had no case for Haiku, so it exited silently and the system reminder carried stale "Opus" text.

**Fix applied:** tier-routing.sh now has explicit case for `*haiku*` models (line 47-52), which injects:
```
You are running on ${model} — a cheap-tier model. Writes are allowed. No delegation required.
```

This replaces the silent treatment with explicit labeling that cheap-tier models can write directly.

**Verification:** tier-guard.sh was already correct (lines 139-146 allow cheap tiers, deny only top-tier). No changes needed there.

**Result:** Haiku 4.5 sessions now show accurate tier labels and guidance, confirming the session is not top-tier.
