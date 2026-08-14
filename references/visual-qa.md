# Separate scientific, delivery, and visual QA

## Scientific integrity

Check:

- statistical unit and n;
- pairing/blocking;
- test-design consistency;
- multiplicity applicability, method, and hypothesis family;
- uncertainty and effect reporting;
- Source Data and provenance;
- unsupported causal or clinical language.

## Delivery QA

Check:

- the required deliverable for the selected authoring/journal profile exists;
- content was placed at the declared physical size and was not unintentionally stretched;
- output dimensions, cropping, and padding comply with the selected delivery profile;
- the selected font family is available, embedded or substituted according to the active profile, with any fallback recorded;
- vector text is editable where required;
- requested formats open successfully;
- raster resolution is recorded at final physical size;
- font and palette profile identifiers are in the manifest.

If `profiles/a4-working.yaml` is selected, additionally require its A4 proof and cropped delivery. Otherwise set the A4-proof check to `NOT_APPLICABLE`; absence of an A4 proof must not cause failure.

## Visual QA

Visual QA is performed on the rendered image, never only on code or manifest fields:

```text
render candidate
→ open full-size raster preview
→ inspect at intended physical/viewing size
→ inspect a 25–30% thumbnail
→ score visual domains
→ identify the three largest defects when REVISE
→ change composition, not only theme parameters
→ rerender and reinspect
```

Score each item `PASS`, `REVISE`, or `FAIL`:

| Domain | Question |
|---|---|
| Hero | Is the first visual focus the evidence that carries the claim? |
| Balance | Are panel areas proportional to evidence role and information density? |
| Reading path | Can a reader infer the intended order without a long explanation? |
| Typography | Is the hierarchy coherent, legible at the intended final viewing size, and compliant with the selected visual, authoring, and journal profiles? |
| Colour | Does the palette follow the selected visual/project profile, keep semantic mappings consistent, satisfy accessibility principles, and match scale type to data semantics? |
| Scale | Are sequential and diverging scales matched to the data? |
| Labels | Are direct labels useful rather than noisy? |
| Legends | Are legends compact, shared, or removed when redundant? |
| Whitespace | Is unused space functional, and was content left unstretched? |
| Crop | Does the cropped page fit the artwork without clipping or excess canvas? |
| Density | Is the figure informative without becoming a report wall? |
| Reference fidelity | If a reference was supplied, was its hierarchy adapted rather than copied? |
| Thumbnail hierarchy | At 25–30% size, does the eye still land on the intended anchor panels? |
| Profile fidelity | Does the output match the selected profile's area ratios, density, restraint, and rhythm rather than merely its colours? |

Scientific audit cannot award visual PASS. If any core visual item is `REVISE`, the final status is not `PUBLICATION_READY`.

For `high_impact_omics`, return `REVISE` when any of the following occur:

- all panels become equal-size boxes;
- the wide lower DotPlot becomes tall or visually dominant;
- legends become large detached blocks;
- embedding points merge into opaque masses;
- colours are saturated enough to compete with the evidence structure;
- plot titles fill the inter-panel whitespace;
- panel letters are placed inside dense data regions;
- bottom support panels compete with the two upper anchor panels.

## R4 global-coherence review

Visual QA is local-render quality; R4 additionally requires `global_coherence_qa.tsv` to verify that local repairs did not damage the entire figure.

Required global domains:

- scientific spine preserved;
- panel role consistency;
- reading order;
- geometry budget;
- canvas utilization;
- physical consistency of repeated marks (including comparable bar widths);
- chromatic coherence without grey dominance;
- typography consistency;
- assembly coherence (one figure, not a collage);
- all local-change impact loops closed.

When `visual.profile: potato-user-v1`, inspect against `references/potato-user-visual-profile.md`. The user-profile compactness targets are heuristics, not license to clip labels, hide outliers or shrink text below readable final size.
