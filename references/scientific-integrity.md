# Scientific integrity contract

Before drawing, record at minimum:

```text
central_claim
figure_role
statistical_unit
n_definition
pairing_or_blocking
statistical_test
multiplicity_applicable
multiplicity_method
hypothesis_family
source_data_path
transformation
missing_data_policy
```

## Biological-unit rules

- Patient, animal, donor, or independent experiment is normally the inferential unit.
- Cells, fields, ROIs, technical wells, images, and sections do not automatically create independent biological replication.
- Preserve pairing visually and statistically when the design is paired.
- If replication is inadequate, report `NOT_EVALUABLE`; do not substitute cell-level P values.

## Multiplicity rules

- Do not infer multiplicity solely from the name of a test.
- If `multiplicity_applicable = yes`, require a method and hypothesis family.
- If applicability is missing in genome-wide or explicit multi-comparison contexts, return a warning and request confirmation.
- A pre-specified single comparison can legitimately declare `multiplicity_applicable = no`.

## Evidence completeness

- Keep negative, null, reverse, and heterogeneous findings in the audit trail.
- Move evidence to supplementary or internal QA because of its role, not because it weakens the preferred story.
- Never convert an exploratory model output into causal or clinical evidence through visual emphasis.

