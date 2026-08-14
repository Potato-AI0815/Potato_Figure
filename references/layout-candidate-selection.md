# Layout Candidate Selection (R3.6, R3.10, R3.11)

## Candidate generation

For publication/high_impact target, generate ≥2–3 candidates:

| Candidate | Geometry | Rationale |
|---|---|---|
| A | hero-left | paired trajectories dominate left, support/inference right + bottom |
| B | hero-top | trajectories span top width, compact support below |
| C | asymmetric balanced | hero largest area, supports sized to content (rows/cols), no auto full-row |

All candidates: same predeclared feature set, same analysis, no hidden
outliers, no result-driven aesthetic selection, no deliberately bad comparator.

## Evaluation dimensions (per candidate)

- hero clarity
- panel occupancy (content vs area)
- data occupancy (central 80–90% of data vs axis span)
- text collision
- facet readability
- whitespace (layout vs data-space)
- legend footprint
- thumbnail hierarchy
- colour cohesion

Record in `R3_candidate_layouts.tsv`:
```
candidate  geometry  hero_clarity  panel_occupancy  data_occupancy
text_collision  facet_readability  whitespace  legend_footprint
thumbnail  colour_cohesion  defects  status  selected  selection_reason
```

## Anti-redundancy / orthogonality (R3.10)

Every panel must answer a different question. Fields:

```
panel_question
evidence_variable
unique_information
```

If two panels are the same data in different chart types and one is
recoverable from the other → REDUNDANCY REVISE.

Current A/B/C all derive from the same gene × patient diagnosis/relapse
matrix — re-evaluate orthogonality:
- A (paired trajectories): within-gene, patient-level, direction+shape
- B (0-centred change heatmap): per-gene × per-patient delta matrix
- C (effect summary): per-gene summary + inference

If B and C are judged redundant (C recoverable from B), drop one or change
its question (e.g., C becomes a model-based effect with CI, not a re-plot
of the same deltas).

## Feature selection provenance (R3.9)

```
feature_selection_mode:
- prespecified
- biology_driven
- external_signature
- full_set
- result_ranked_exploratory
```

`result_ranked_exploratory` + main-figure claim panel → WARNING.
Must declare: selection rule, number selected / total tested, exploratory status.
Never present a result-ranked subset as a predefined core marker set.

Current benchmark `top8 <- order(BH_FDR_q)` is result-ranked → declare as
`result_ranked_exploratory` + WARNING, or switch to prespecified marker list.

## Scale compatibility (R3.3 wiring)

Shared quantitative axis across features with different basal abundance
(raw CPM delta) → SCALE_COMPATIBILITY WARNING.
Use paired log2FC / log2(CPM+pseudocount) delta / standardized paired effect;
justify, declare in manifest, keep raw source data.
