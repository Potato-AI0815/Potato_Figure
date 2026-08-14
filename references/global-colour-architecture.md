# Global Colour Architecture (R4)

## Core principle

Figure-level colour cohesion is not the same as greying most data. R4 separates structural ink from meaningful data ink.

## Three visual layers

### Structural ink
Use charcoal/light neutral for:
- axes;
- reference lines;
- secondary text;
- quiet connectors;
- non-data framing.

### Primary data ink
Meaningful observations should retain biologically interpretable low/mid-chroma colour when a stable semantic mapping exists. Do not default all patient trajectories, bar fills or raw observations to grey merely to reduce palette count.

### Effect/direction ink
Use coordinated cool/warm accents only when sign/direction has scientific meaning. Significance and direction are separate semantics; non-significant does not automatically mean grey.

## Figure-level contract

A figure should declare:

```text
structural_ink
primary_family
secondary_family
signed_positive
signed_negative
categorical_strategy
identity_strategy
accent_budget
background
```

Panel-specific scales must be compatible with this shared architecture unless a distinct variable requires an intentionally separate legend.

## Personal profile default

For `potato-user-v1`, a recurring two-condition starting family is:

- cool primary: `#5B8CCB`
- warm secondary: `#F47F68`
- structural charcoal: `#3F4650`
- light structural neutral: `#D9DEE3`
- signed midpoint: `#F7F5F2`

These values are not universal biological meanings. Map them according to the actual contrast.

## Neutral-data-ink audit

Under publication/high-impact targets, return at least `REVISE` when most meaningful marks are neutral grey despite available condition/direction semantics and the result looks visually dead or obscures the evidence hierarchy.

Grey remains appropriate for quiet connectors, secondary observations, uncertainty/background layers and reference structure.
