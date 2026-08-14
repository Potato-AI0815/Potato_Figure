# User-approved visual benchmark 01: high-impact omics

## Evidence status

```text
approval: USER_EXPLICITLY_APPROVED
confidence: HIGH
reference_text_status: REMOVED_BY_USER
reference_asset_redistribution: FORBIDDEN_UNLESS_PERMISSION_CONFIRMED
```

The user-approved image is treated as a visual benchmark only. Its missing titles, biological labels, panel descriptions, and legends must never be guessed or reconstructed from appearance.

## Visual signature

### Composition

- Wide white figure with no global title inside the artwork.
- Two large embedding panels dominate the upper half and form the first visual anchors.
- A medium embedding occupies the lower-left.
- Compact violin and trend/trajectory panels occupy the lower middle and right.
- A wide, shallow DotPlot closes the lower-right area.
- Panels are asymmetric in size but aligned through shared edges and consistent gutters.
- Whitespace separates evidence blocks; it does not indicate missing content and does not need to be filled.

### Approximate normalized layout

Coordinates are fractions of the cropped content footprint, with origin at the upper-left:

| Slot | x | y | width | height | Intended role |
|---|---:|---:|---:|---:|---|
| `anchor_left` | 0.03 | 0.01 | 0.45 | 0.49 | primary embedding/landscape |
| `anchor_right` | 0.54 | 0.01 | 0.43 | 0.49 | trajectory or continuous-state embedding |
| `support_left` | 0.00 | 0.53 | 0.34 | 0.42 | grouped embedding or validation landscape |
| `support_middle` | 0.38 | 0.54 | 0.25 | 0.22 | compact violin/distribution |
| `support_right` | 0.66 | 0.54 | 0.31 | 0.22 | compact trend/module curve |
| `closure_wide` | 0.39 | 0.79 | 0.58 | 0.16 | wide, shallow marker DotPlot |

These ratios are a design starting point, not a mandatory six-panel count. Preserve the hierarchy when a panel is added or removed.

### Typography

- Arial throughout.
- Approximately 12 pt for ordinary labels on the A4 working proof.
- Panel letters 15–16 pt, black, bold, placed in whitespace just outside the data area.
- Axis/legend text 10.5–11.5 pt.
- No large decorative titles inside panels.
- Labels are concise and black; colour is carried by marks, not prose.

### Embeddings

- Points are extremely small and individually legible at 100% view.
- Use rasterized point layers for large cell counts while keeping labels, trajectories, and legends vector.
- Background/reference cells are pale grey with low alpha.
- Foreground categories use softened pastel hues with moderate alpha.
- No point outlines for dense cell clouds.
- Use a small corner-axis glyph or very restrained axes rather than a boxed coordinate system.
- Trajectory nodes are hollow; direction lines/arrows are thin black overlays and only appear when derived from a fitted model.

Suggested R ranges at A4 working size:

```text
embedding point size: 0.20–0.42 mm
background alpha:     0.18–0.32
foreground alpha:     0.55–0.78
trajectory stroke:    0.55–0.80 pt
node diameter:        2.0–3.2 mm
```

### Supporting panels

- Violin: narrow violins, thin outlines, internal box summary, no large legend.
- Trend: thin restrained lines, subtle uncertainty if supported, quiet reference line, no heavy grid.
- DotPlot: wide and shallow; colour represents average expression and size represents percent expressed; legend remains compact and subordinate.
- Continuous colourbars are short and placed close to the relevant panel.

### Colour behaviour

- Use the fixed `POTATO_HIGH_IMPACT_OMICS` palette.
- Prefer softened fills and points; reserve deeper colours for trend lines, focal nodes, or high-value DotPlot marks.
- Pale grey carries context and prevents every cell from competing for attention.
- Purple is a sequential DotPlot scale, not a general significance colour.

## What this benchmark is not

- It is not a universal layout for clinical, imaging, mechanism, or sparse two-group figures.
- It is not permission to copy an article figure pixel-for-pixel.
- It is not evidence that any particular biological label or trajectory direction is correct.
- It is not reproduced inside the public Skill package because provenance and redistribution permission are not established.

## Acceptance test

At 25–30% thumbnail size:

1. the two upper embeddings should remain the first visual anchors;
2. the lower-left embedding should read as secondary, not equal;
3. the bottom DotPlot should form a horizontal closing rhythm rather than a new hero;
4. legends should not dominate;
5. the figure should feel light, spacious, and information-rich rather than empty or report-like.

