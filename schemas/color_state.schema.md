# color_state (Global Figure State extension, v0.4.1)

Add to global_figure_state.yaml:

```yaml
color_state:
  semantic_palette: "D=blue #5B8CCB; R=coral #F47F68"   # figure-level semantic mapping
  continuous_palettes: "diverging blue-white-red, midpoint 0 (log2FC)"
  categorical_palettes: "condition: D=blue, R=coral"
  neutral_roles: "background;reference;connective;secondary"
  hero_accent: "coral endpoints on hero panel b"
  panel_palette_map: "a=neutral;b=blue-coral;c=same-blue-coral"
  palette_consistency_status: PASS | WARNING | REVISE
  accessibility_status: PASS | WARNING | NOT_EVALUABLE
  evidence_source: METADATA_ONLY | VISION_MODEL_REVIEW | RASTER_REVIEW | MANUAL_REVIEW | NONE
```

## Consumption

- COLOR-01 reads `semantic_palette`
- COLOR-03 / COLOR-12 read `panel_palette_map`
- COLOR-04 / COLOR-05 / COLOR-10 / COLOR-11 require image evidence
  (RASTER/VISION/MANUAL); METADATA_ONLY → NOT_EVALUABLE
- COLOR-06 reads `continuous_palettes`
- COLOR-02 / COLOR-07 read `semantic_palette` + legend

## Local-change impact

Editing any color field in color_state triggers global recheck:
COLOR-01, COLOR-03, COLOR-05, COLOR-11, GLOBAL_COHERENCE
(plus legend mapping if legends are shared).
