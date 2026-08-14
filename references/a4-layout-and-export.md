# A4 authoring profile and cropped export

This is an authoring/export profile, not the design core. Evidence architecture and the selected visual profile determine the content footprint before it is placed on A4.

## Working canvas

The default authoring canvas is A4:

- portrait: 210 × 297 mm;
- landscape: 297 × 210 mm;
- default safe page margin: 15 mm;
- default content padding in cropped delivery: 2.5 mm;
- default font: Arial;
- ordinary labels: approximately 12 pt.

A4 is a planning board and review proof. It is not an instruction to enlarge the figure until the page is full.

## Typography hierarchy

Default A4 working sizes:

| Role | Size |
|---|---:|
| Figure or section heading, when needed | 15–16 pt |
| Panel label | 14 pt bold |
| Axis title / direct label / body label | 12 pt |
| Axis tick / legend | 10.5–11 pt |
| Footnote or secondary annotation | 9.5–10 pt |

Avoid using a title inside the artwork when the manuscript legend already supplies it. The sizes above are working defaults, not target-journal final specifications.

## Layout and crop contract

1. Declare the intended content width and height before render.
2. Place that content on A4 at 1:1 physical size; do not stretch it.
3. Review balance, hierarchy, and readability on the A4 proof.
4. Export a second delivery set with page bounds equal to:

```text
content width  + 2 × safety padding
content height + 2 × safety padding
```

5. Cropping must change canvas bounds, not resize text, points, lines, or images.
6. Record the A4 proof size, content size, cropped page size, and padding in the manifest.

The R helper uses `svglite` when available and falls back to the base R SVG device when it is absent. Record the device in the manifest because text and font embedding can differ between devices.

## Journal-final conversion

If a target journal is specified, verify its current official requirements and create a final profile. For Nature, current official guidance lists 89 mm and 183 mm print widths, maximum figure height 170 mm, Arial/Helvetica, and generally 5–7 pt figure text. This differs from the A4/12 pt authoring profile.

Sources:

- Nature Research Figure Guide, [Building and exporting figure panels](https://research-figure-guide.nature.com/figures/building-and-exporting-figure-panels/)
- Nature Research Figure Guide, [Preparing figures—our specifications](https://research-figure-guide.nature.com/figures/preparing-figures-our-specifications/)
- Cell Press, [Graphical Abstract Guidelines](https://crosstalk.cell.com/hubfs/Files/GA_guide.pdf) — Arial 12–16 pt applies to Cell Press graphical abstracts, not all manuscript data figures.
