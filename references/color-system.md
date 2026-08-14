# Profile-driven colour system

## Mandatory principles versus palette values

The following are mandatory across profiles:

- colour has a declared meaning;
- the same meaning remains stable across a project;
- rainbow/jet is forbidden;
- red versus green is not the only encoding;
- non-negative data use sequential scales;
- signed data use diverging scales only when a real centre exists;
- critical distinctions remain interpretable through labels, shape, line type, or keylines.

Exact hex values are selected by the visual profile. They are not universal product branding.

## Generic accessible fallback

Nature, Cell, and Science do not share one universal official house palette for scientific data. When no user-approved or project-specific visual profile exists, Potato Figure uses Nature's official colour-blind-accessible example as a safe fallback. It must be described as **top-journal-informed**, not as a universal official Nature/Cell/Science palette.

Nature's official figure guide recommends accessible colours, avoiding red–green combinations and rainbow scales, and publishes the following example palette:

| Name | Hex |
|---|---|
| Black | `#000000` |
| Orange | `#E69F00` |
| Sky blue | `#56B4E9` |
| Bluish green | `#009E73` |
| Yellow | `#F0E442` |
| Blue | `#0072B2` |
| Vermillion | `#D55E00` |
| Reddish purple | `#CC79A7` |

Source: [Nature Research Figure Guide—Building and exporting figure panels](https://research-figure-guide.nature.com/figures/building-and-exporting-figure-panels/).

Cell Press separately recommends using colour to direct attention and avoiding heavily saturated primary colours in graphical abstracts. Source: [Cell Press Graphical Abstract Guidelines](https://crosstalk.cell.com/hubfs/Files/GA_guide.pdf).

## Fallback categorical order

Use this order for unordered categories unless the project already has a frozen semantic dictionary:

```text
#0072B2  blue
#D55E00  vermillion
#009E73  bluish green
#CC79A7  reddish purple
#E69F00  orange
#56B4E9  sky blue
#000000  black
#F0E442  yellow
```

Do not use yellow for text, thin lines, or small points on white. Use it only for sufficiently large filled marks with a dark outline or on a dark background.

## Fallback semantic mapping

| Meaning | Colour |
|---|---|
| Text / axes | `#202020` |
| Control / reference | `#7A7A7A` |
| Treatment / primary group | `#0072B2` |
| Secondary contrast | `#D55E00` |
| Positive / retained / recovered | `#009E73` |
| Highlight | `#E69F00` |
| Auxiliary category | `#CC79A7` |
| Down / negative direction | `#0072B2` |
| Up / positive direction | `#D55E00` |
| Non-significant / background | `#C8C8C8` |
| Missing | `#E6E6E6` |

The same biological meaning must keep the same colour across a project. If a user-approved profile or discipline-specific meaning conflicts with this fallback table, freeze that profile before drawing.

## User-approved high-impact omics palette

The approved reference uses softened category colours, a quiet grey scaffold, a restrained blue–salmon contrast, and a purple sequential DotPlot. Freeze the following palette for the `high_impact_omics` profile:

| Role | Hex |
|---|---|
| Lavender category | `#B8A6D9` |
| Warm yellow category | `#E6C76A` |
| Soft teal category | `#55B8B2` |
| Powder blue category | `#8FB6D8` |
| Soft salmon category | `#E49A8F` |
| Mist grey / background cells | `#D5D8DC` |
| Deep blue line | `#4F719D` |
| Salmon line | `#D97B6D` |
| Neutral dark line | `#4D5663` |
| DotPlot pale | `#F2EDF7` |
| DotPlot mid | `#B891D0` |
| DotPlot deep | `#6A1B9A` |

These are reference-derived Potato colours, not an official journal palette. Use them with the geometry and hierarchy in `profiles/high-impact-omics.yaml`; palette alone will not reproduce the approved visual standard.

## Continuous scales

- Non-negative expression, density, probability, abundance, or intensity: use a sequential scale.
- Signed effect, centred z-score, correlation, NES, or paired change: use a diverging scale with a real zero or named centre.
- Never use a diverging scale merely because it looks more dramatic.
- Never use rainbow or jet.

Fixed Potato scales:

```text
sequential_blue:
  #F7FBFF → #DDEAF4 → #9CC7E5 → #4A98C9 → #08519C

diverging_effect:
  #0072B2 → #56B4E9 → #F7F7F7 → #E69F00 → #D55E00
```

These two ramps are Potato-derived display scales anchored to the accessible blue/vermillion system; they are not claimed as official journal palettes.

## Accessibility rules

- Encode critical groups with shape, line type, direct labels, or keylines when colour alone is fragile.
- Prefer black or white text with adequate contrast; avoid coloured prose labels.
- Simulate common colour-vision deficiencies before final approval.
- Review RGB files and a print/greyscale proof.
