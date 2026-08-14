# Potato Figure Audit — Product Boundary

## What Potato Figure Audit is

An **independent scientific figure audit and integrity layer** for
biomedical research:

> 闈㈠悜鍖诲涓庣敓鍛界瀛︾鐮?Figure 鐨勭嫭绔嬪鏍镐笌瀹屾暣鎬ф鏌ュ眰銆?
It audits figures that already exist (or are about to be finalised):

- Scientific Integrity
- Claim鈥揈vidence
- Statistical Consistency
- Global Coherence
- Visual QA
- Delivery / Reproducibility

## What Potato Figure Audit is NOT

| Not | Because |
|---|---|
| A figure generator | It never draws or renders; generator-agnostic |
| A plotting theme | ggplot2/Matplotlib/Prism/Illustrator remain upstream |
| A Nature-style template shop | It does not compete on "椤跺垔椋庢牸" |
| A statistical analysis engine | It checks declared statistics vs design; it does not choose "optimal" methods (nature-statistics' job) |
| An auto-repair tool | It recommends repairs with an upstream owner; it never silently modifies data or redraws |
| Paper-Spine | Whole-manuscript narrative/figure-to-text spine is paper-spine's job |

## Boundary with other skills

```
nature-statistics   鈫?statistical analysis and design
        鈫?nature-figure       鈫?figure generation / rendering / layout
        鈫?Potato Figure Audit 鈫?independent review of generated results
        鈫?paper-spine         鈫?whole-manuscript narrative / figure-to-text spine
```

Potato Figure Audit must also work **standalone** (no Nature dependency).

## Generator-agnostic guarantee

Input is a figure delivery directory plus whatever supporting evidence
exists. It does not matter which tool produced the figure: R, Python,
GraphPad Prism, Nature-Figure, Illustrator, or an AI tool. The audit reads
the manifest, contract, source data, metadata, and the rendered figure 鈥?not the generator.

## NOT_EVALUABLE discipline

- Missing material 鈫?`NOT_EVALUABLE`, never fabricated.
- Missing material is not automatically FAIL unless it is required for the
  user's stated publication-readiness claim.
- `NOT_EVALUABLE` is never disguised as PASS.

## Fail-closed publication readiness

`PUBLICATION_READY = FALSE` on any blocking FAIL; unresolved REVISE defaults
to FALSE. The gate reports per-domain status (SCIENTIFIC / STATISTICAL /
CLAIM_EVIDENCE / PANEL_ARCHITECTURE / GLOBAL_COHERENCE / VISUAL /
DELIVERY) instead of a single opaque PASS.

