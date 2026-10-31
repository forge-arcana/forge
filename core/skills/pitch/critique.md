# /pitch --critique

Loaded by `/pitch --critique`. The review is feedback on the existing Pitch, not a second pitch.

### Process

**Spawn parallel subagents** — one per dimension, each at **sonnet tier**, except **Execution Risk** and **Revenue Model**, which spawn at **opus tier** (or walk dimensions sequentially at your session model if your harness lacks parallel sub-agent spawning or per-spawn model selection). Each subagent independently:

1. **Analyzes** the corresponding section of the Pitch through its dimension's lens
2. **Searches the web** for market benchmarks and current best practices — check the web research cache first per [Forge Protocol](../forge/protocol.md#web-research-cache). **Batch all uncached web searches in parallel.**
3. **Challenges** the assumption:
   - What evidence supports this?
   - What would have to be true for this to work?
   - What kill condition does this expose that The Stake missed?
4. **Scores** the dimension 1–5 with specific findings

**After all parallel dimension subagents complete, the merge runs at opus tier as an authoritative review, not a collation: validate each dimension's findings, re-score any dimension whose evidence does not support its score, add kill conditions the dimension legs missed, and compute the verdict from the opus-revised scores.**

### Dimensions (7 total — one per Pitch section)

| Dimension | Reviews Section | Key questions |
|-----------|----------------|---------------|
| Problem & Market | The Wound | Real and painful, or manufactured? Right timing? Vitamin or painkiller? |
| Value Proposition | The Inversion | 10× better than alternatives or marginal? Unique insight? Switching cost? Durable or copyable in 12 months? |
| Field Economics | The Field | First-100 numbers credible? Compounding lever real? Market-in-our-terms grounded? Switching gain real? |
| Revenue Model | The Field + The Signal | Pricing aligned with value? Unit economics (CAC, LTV, gross margin, payback)? Path to profitability? Hidden risks? |
| Competitive Moat | The Inversion | What stops a well-funded incumbent? Network effects, switching costs, proprietary data, regulatory, brand? Growing or eroding? |
| Go-to-Market | The Field | First customer credibly acquired? GTM matched to buyer type? Loop compounds or stays linear? Distribution advantages vs. incumbents? |
| Execution Risk | The Stake + The Signal | Kill conditions complete? Capital exposure honest? Cheapest test of riskiest assumption? Stop-the-bet metric falsifiable? |

### Output Format

Report headed `# Pitch Review — [PROJECT]` with a date / review-by / source line, then:

- **Scorecard** — one row per dimension from the table above, columns `Dimension | Reviews | Score (1-5) | Key Finding | Signal`, closing with a bolded **Overall** row out of 35.
- **Verdict** — FUNDABLE / WORTH BUILDING / NEEDS RETHINK / KILL.
- **Kill Conditions Missing from The Stake** — each with assumption, what would invalidate it, and which Stake bullet should carry it.
- **Important Concerns** — significant risks the Pitch acknowledges but understates.
- **Strengthen the Pitch** — specific edits to surface in `/pitch --refine`.
- **The One Question** — the single question this pitch must answer, phrased so the founder knows whether to refine, revisit `/prime`, or proceed.

Scoring: 1 = broken/absent, 2 = weak, 3 = adequate, 4 = strong, 5 = exceptional. Signal: red = 1–2, yellow = 3, green = 4–5. Verdict thresholds: FUNDABLE = 28–35, WORTH BUILDING = 21–27, NEEDS RETHINK = 14–20, KILL = ≤13.

### Marker Integration

After the critique runs, mark the verdict at the top of `<body>` in `[PROJECT]_04_Pitch_V1.0.html` as an HTML comment:

```
<!-- PITCHED: [VERDICT] — [date] -->
```

This marker is read by `/smith` during Step 0 preflight. A `KILL` or `NEEDS RETHINK` verdict surfaces to the user before build resources are committed.

When `--critique` is *not* run, no PITCHED marker is written — the absence tells `/smith` only that *"a Pitch exists, no review pass was requested,"* and `/smith` proceeds normally. Absence is not a defect.

## Post-Flight (after a --critique run)

- **Critique verdict KILL or NEEDS RETHINK** → revisit `/prime` to revise the Vow's viability thread and the Opus's "Why us" before any build resources are committed.
- **Critique verdict WORTH BUILDING or FUNDABLE** → proceed to `/probe` then `/smith` with conviction.
