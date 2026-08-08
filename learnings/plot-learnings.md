# /plot Learnings

> Accumulated learnings from Atlas casts (production-landscape mapping).
> Absorbed by the `/forge` cycle.

<!-- Add learnings below this line -->

## First As-Built Cast: Synthesis Owns the Cross-Facet States (2026-08-05)
**Learning**: The sharpest drift class was neither Added nor Removed but a *topology state* no single facet owns — two production runtimes running the same code in parallel, coupled only by a policy rule. Facet scans each reported their half correctly; only the synthesis step could name the composition as the landscape's load-bearing ambiguity. Budget synthesis time for cross-facet states, not just node merging.
**Apply when**: Any dual-runtime migration or parallel-deploy topology — "both halves live, policy is the only fence" is a recurring go-live risk the drift ledger should always probe.

## Commission Facet Scans to Flag the Structurally Surprising (2026-08-05)
**Learning**: Facet agents volunteering "notable structural facts" beyond their normalized node/edge lists carried half the drift ledger. The normalized list alone under-reports; an explicit "flag anything structurally surprising" clause in the commission is what surfaces the shadowed code paths, missing counterparts, and boundary-bypassing routes.
**Apply when**: Commissioning any facet/area scan for an architecture map.

## Diff the Premises of a Baseline's Verdicts, Not Just Its Components (2026-08-05)
**Learning**: An architecture baseline's *verdicts* ("single pinned instance ⇒ in-memory limiter correct") drift silently when a later amendment changes the deploy target — the ledger caught two baseline premises that had died while the named components still existed. When diffing against a design baseline, diff what its conclusions ASSUME, not just what it names.
**Apply when**: Comparing as-built state against any design document with reasoned verdicts.

## The Atlas Diagram Must Be Verified Visually, Not "Renders Without Error" (2026-08-05)
**Learning**: A technically-perfect render (SVG present, no overflow) was practically useless: flowchart fan-out edges (`A & B & C --> X`) plus a flat 12-node external subgraph produced a 6500px-wide graph that default `useMaxWidth:true` squeezed to illegible. Two fixes together: `useMaxWidth:false` with natural size inside an `overflow-x:auto` frame, AND restructure the source — group externals into themed subgraphs, replace per-runtime fan-outs with single edges into a subgraph (width 6519px → 1923px). Screenshot the map every time; wide fan-out edges are the width killer in flowchart.
**Apply when**: Authoring any mermaid/diagram deliverable — verification means looking at the rendered image.

## Grammar Fit: Boundary Subgraphs Beat C4 for Dual-Runtime Shapes (2026-08-05)
**Learning**: `flowchart` with boundary subgraphs beat `C4Container` for a same-code-deployed-twice shape (two subgraphs holding sibling nodes; C4's container semantics fight that). Env-gated-dormant nodes render well as `stroke-dasharray` classDefs; flagged ambiguities as thick borders — a reusable Atlas idiom.
**Apply when**: Choosing a diagram grammar for a landscape with dual runtimes or dormant components.
