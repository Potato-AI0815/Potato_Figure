# Potato User Visual Profile v1

Status: evidence-backed personal profile reconstructed from user-approved and user-rejected scientific figures across prior projects. This is **not** a universal journal standard.

## Visual intent

The preferred style is **dense, compact, information-rich and deliberately composed**. It is not minimalist whitespace-driven design and it is not grey-dominant styling.

## 1. Canvas utilization

Preferred heuristics for manuscript-style figures:

- target useful width occupancy: approximately **>=88%**;
- target useful height occupancy: approximately **>=82%**;
- avoid dominant blank regions; roughly **<12–15%** nonfunctional blank area is a useful warning heuristic;
- typical outer margins: **3–4 mm**;
- typical inter-panel gaps: **2.5–4 mm**.

These are user-profile heuristics, not universal publication rules. Never crop data or labels merely to hit them.

## 2. Typography

Default final-size target:

- ordinary scientific text: **8–12 pt**;
- axis/legend text usually **8–9 pt**;
- panel tags usually **10–12 pt bold**, lowercase in manuscript figures;
- avoid solving density problems by repeatedly shrinking text;
- below 8 pt is an exception requiring final-size inspection or explicit journal constraints.

Preferred families: Arial / Helvetica / Liberation Sans or a metrically stable equivalent.

## 3. Information density

- High information density is preferred when the evidence remains readable.
- Sparse panels should be reduced, merged or removed rather than enlarged to fill space.
- Every manuscript panel must answer a distinct scientific question.
- Compact annotations are preferred over detached explanatory text blocks.
- Hero/support hierarchy should be visible without a large title explaining it.

## 4. Physical consistency

Comparable quantitative panels should preserve:

- bar width;
- within-group spacing;
- point diameter;
- error-bar visual weight;
- comparable axis-label scale.

A two-group bar plot must not produce much wider bars than a four-group plot simply because its panel is wider. Resize the panel or geometry instead.

## 5. Layout

- Prefer asymmetric evidence-driven layouts over mechanical equal-cell grids.
- Hero evidence receives more area only when evidence density and importance justify it.
- Dense matrices/heatmaps may receive width/height according to rows/columns rather than panel count.
- The final figure must read as one assembled object.
- Similar panels should align on strong visual edges.

## 6. Colour

- White or near-white background.
- Restrained, low-to-mid chroma colours; avoid rainbow palettes.
- Grey/charcoal is primarily structural ink (axes, reference lines, minor connectors, secondary annotations), not the default colour for most meaningful data.
- A recurring accepted two-condition family is cool blue around `#5B8CCB` and coral around `#F47F68`; map these only when the biological contrast supports that semantic role.
- Signed effects may reuse coordinated cool/warm families with a light neutral midpoint.
- Panel-level palettes must belong to one figure-level colour architecture.

## 7. UMAP / t-SNE / embedding panels

Preferred starting points:

- square/equal-coordinate geometry;
- small dense points, commonly around 0.35–0.42 in prior R plotting contexts, adjusted for export size;
- direct labels when readable;
- modest outer expansion rather than large dead margins;
- no heavy boxed axes or unnecessary internal titles;
- soft component-wise background islands may be used when they clarify structure; avoid heavy hull outlines and diagonal bridging artefacts;
- compact/block-style legends or direct labels.

## 8. Heatmaps

- Compact, high-density heatmaps are preferred when the matrix carries unique evidence.
- Use biologically/statistically appropriate scale semantics.
- Avoid visually oversized heatmaps containing little information.
- Labels, bars and legends should not consume more area than the matrix itself.

## 9. Hard personal rejects

For this profile, mark at least `REVISE` when a final figure has:

- large nonfunctional whitespace;
- sparse panels enlarged to complete a grid;
- bar widths or repeated quantitative marks that visibly change size without justification;
- grey-dominant meaningful data despite available semantics;
- giant figure titles/subtitles;
- independent plot styling that makes the canvas look like a collage;
- repeated legends;
- automatic equal-cell patchwork composition;
- facet labels/axes that become unreadable at final size.
