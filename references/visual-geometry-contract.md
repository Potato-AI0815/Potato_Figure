# Visual Geometry Contract (R3.1, R3.2, R3.4)

## 1. Panel geometry declaration

Every panel in a publication/high_impact figure declares `panel_geometry`:

```yaml
panel_geometry:
  - panel: A
    role: hero
    content_rows: 8          # e.g., 8 genes
    content_cols: 2          # e.g., 2 timepoints
    preferred_aspect: 1.6
    min_width_mm: 70
    min_height_mm: 55
    max_width_fraction: 0.65 # of figure width
    legend_requirement: shared
    direct_label_possible: true
```

Forbidden: setting width ratios from hero/support/inference labels alone.
Layout must jointly consider:
- evidence importance
- information density (content_rows × content_cols)
- number of rows/columns
- label length
- facet count
- legend footprint
- intended final physical size

## 2. Two kinds of whitespace (separated in Visual QA)

### A. layout_whitespace
- outer margins, inter-panel gaps, legend gaps, title/subtitle footprint.
- A `layout_whitespace` defect = structural whitespace that could be
  re-allocated to evidence.

### B. data_space_under_occupancy
- displayed axis range largely empty of data
- a single outlier dominates the axis
- summary effects compressed into a local region

New evidence fields (profile-dependent heuristics, never universal thresholds):

| Field | Meaning | Trigger |
|---|---|---|
| `central_data_occupancy` | fraction of displayed axis span occupied by central 80–90% of data | if very small → REVISE |
| `outlier_axis_domination` | one point forces axis range | → REVISE |
| `summary_effect_occupancy` | summary/effect estimates squeezed into a local region | → REVISE |

Forbidden fixes: deleting outliers, cropping real data.

Fix priority (strict order):
1. assess scale compatibility (see scale-compatibility.md)
2. choose scientifically justified transformation
3. change plot grammar
4. use small multiples if appropriate
5. only then adjust axis presentation (e.g., breaks, log scale)

## 3. Panel area budgeting

Forbidden default: `(A | B) / C` where C auto-fills a full row.

Estimate area from panel content:
- a compact effect plot with only 8 rows must NOT receive ~half the figure
  area unless it is the hero/inference anchor and needs it.

Two separate checks:

| Check | Meaning |
|---|---|
| `panel_area_evidence_mismatch` | scientific importance does not match area |
| `panel_area_content_mismatch` | information quantity insufficient for allocated area |

## 4. Explicit asymmetric layout engine

For publication/high_impact, prefer explicit layout design:
- R: `patchwork::area()`, `plot_layout(design=...)`, nested layouts,
  `guide_area()`, ComplexHeatmap for matrix-driven figures
- Python: GridSpec, subplot_mosaic, subfigures, constrained layout

Forbidden: complex figures going straight to final QA after operator-only
`(A | B) / C` composition.

## 5. Layout candidate competition (R3.6)

For publication/high_impact, generate 2–3 candidate geometries:

- Candidate A: hero-left
- Candidate B: hero-top
- Candidate C: asymmetric balanced

All rendered, all evaluated on:
hero clarity, panel occupancy, data occupancy, text collision,
facet readability, whitespace, legend footprint, thumbnail hierarchy,
colour cohesion.

The first generated layout is NOT the default answer. Select the best
visual score, then refine. Record `layout_candidates.tsv`:

```
candidate  geometry  visual_defects  status  selected  selection_reason
```

## 6. Publication title budget (R3.8)

For publication/high_impact final figure:
- no large demonstration titles/subtitles ("AFTER: ...", "HERO A | SUPPORT B | ...")
- these belong in benchmark caption / audit report / manuscript legend
- final figure: lowercase panel labels + concise axis/panel labels

Fields: `title_area_budget`, `subtitle_area_budget`.
Demo mode is the only exception.
