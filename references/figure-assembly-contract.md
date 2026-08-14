# Figure Assembly Contract (R4)

## Core distinction

A multi-panel manuscript figure is one designed object. Several ggplots placed on one canvas are not automatically a coherent figure.

The hierarchy is:

```text
FIGURE
  panel a
    optional internal components
  panel b
  panel c
```

Patchwork/GridSpec layout IDs are implementation details and must not be confused with manuscript panel identities.

## Required assembly decisions

For publication/high-impact output, freeze:

- final panel count;
- lowercase panel tags;
- reading order;
- hero/support/validation roles;
- panel bounding-box plan;
- shared axes where meaningful;
- shared legends/colour scales;
- outer margins and gutters;
- final physical canvas;
- which components are internal facets versus manuscript panels.

## Global assembly rules

1. Final output must read as **one figure** at full size and 25–30% thumbnail.
2. Similar quantitative panels must use physically consistent mark geometry; do not stretch sparse panels merely to fill a grid cell.
3. Equal-sized panel grids are forbidden when evidence roles or information density are unequal.
4. Large demonstration titles/subtitles are excluded from publication/high-impact final canvases.
5. Internal facets must not visually overpower manuscript panel structure.
6. Shared legends should be consolidated when this reduces redundancy; direct labels are preferred when they remain readable.
7. Removing a redundant panel is preferred to enlarging weak evidence to complete a rectangle.
8. Geometry changes require whole-figure rerender and global-coherence recheck.

## Physical consistency rule

Comparable bars, dots, error bars and repeated quantitative grammars should have stable physical dimensions across panels. Panel size should adapt to category count and evidence density rather than allowing the same bar to become visually wider simply because a panel has fewer groups.
