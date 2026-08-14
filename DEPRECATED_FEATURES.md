# Deprecated / Legacy Features (v0.3.0 Audit Pivot)

This document records everything that was **removed from the product
positioning** or **demoted to legacy/optional helper** when Potato_Figure
pivoted from "figure generation + audit" to "Potato Figure Audit —
independent audit / integrity layer".

## 1. Removed from product positioning

The following concepts are no longer part of the product:

| Concept | Status | Notes |
|---|---|---|
| figure generator | REMOVED | Potato Figure Audit does not generate figures |
| automatic figure generation | REMOVED | — |
| publication figure compiler | REMOVED | SKILL description no longer uses "compiler" |
| rendering system | REMOVED | rendering is upstream, not part of the audit |
| art-direction engine | DEMOTED | legacy reference only |
| universal plotting system | REMOVED | — |
| Nature-style figure generator | REMOVED | we audit what Nature-Figure (or any tool) produces |
| automatic multipanel generation | REMOVED | panel architecture is *audited*, not auto-built |
| automatic hero generation | REMOVED | hero clarity is *reviewed* |
| plotting atlas as core selling point | DEMOTED | not a product claim |

## 2. Demoted to legacy / optional helper

These files remain in the repository for reference, examples, and backward
compatibility, but are **not** part of the audit core and must not be
advertised as the product:

- `themes/potato_theme_v02.R` — rendering theme helper (legacy)
- `references/visual-art-direction.md` — art-direction guidance (legacy)
- `references/layout-candidate-selection.md` — layout competition (legacy)
- `references/global-colour-architecture.md` — colour architecture (legacy)
- `references/visual-geometry-contract.md` — geometry contract (legacy, kept
  as input for Visual Integrity audit guidance)
- `references/a4-layout-and-export.md` — A4 authoring (legacy)
- `references/three-source-synthesis.md` — design synthesis (legacy)
- `references/user-approved-benchmark-01.md` — visual benchmark (legacy)
- `profiles/a4-working.yaml`, `profiles/high-impact-omics.yaml`,
  `profiles/journal-final.yaml` — rendering/authoring profiles (legacy;
  `potato-user-v1.yaml` remains as the personal visual QA profile)
- `benchmarks/r2_r3_reference/` — historical R2/R3 audit package
  (reference only)

## 3. What remains core (frozen, do not weaken)

1. Scientific Integrity Audit
2. Claim–Evidence Audit
3. Statistical-unit consistency
4. Pairing consistency
5. Multiplicity declaration
6. Source Data integrity
7. Global Figure State
8. Local Change Impact
9. Global Coherence
10. Visual QA
11. Delivery / Reproducibility QA
12. Fail-closed publication readiness

## 4. Why

The product difference is no longer:

> "I draw more beautifully than Nature-Figure."

It is:

> "After Nature-Figure (or any tool) has drawn it, I can tell you whether
> the figure actually holds up."
