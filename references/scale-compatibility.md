# Scale Compatibility (R3.3)

## Problem

When multiple features share one quantitative axis, their units and dynamic
ranges must be comparable.

Example (current benchmark issue):
```
raw CPM delta across genes
→ SCALE_COMPATIBILITY WARNING
```
Raw absolute delta is confounded by basal abundance: a gene with high basal
CPM can show large absolute delta without meaningful relative change, and
vice versa. Raw delta across genes is therefore not a comparable scale.

## Acceptable scales when the claim is cross-gene relative change

- paired delta on log2(CPM + justified pseudocount)
- paired log2FC
- pseudobulk / model coefficient
- standardized paired effect (e.g., Cohen's dz on patient-level paired deltas)

## Rules

1. Forbidden: automatic transformation for aesthetics alone.
2. Every transform must have:
   - scientific justification (state why the scale is comparable for the claim)
   - manifest declaration (transformation column)
   - source data retaining raw values
   - traceable Methods description
3. Raw absolute deltas across features with different basal abundances
   → WARNING unless justified.
4. If the claim is within-gene (e.g., one gene across time), raw delta may be
   acceptable with justification; the audit is claim-aware.

## Audit wiring

Add `scale_compatibility` check to Scientific/Visual joint audit:
- detect shared quantitative axis across features
- detect absolute-delta-style scale when features differ in basal level
- output WARNING with recommended scale + justification requirement
- never auto-convert; require explicit manifest declaration
