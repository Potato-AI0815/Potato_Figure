# Potato_Figure

A publication-grade scientific figure skill that merges three proven rule sets:

![CI](https://img.shields.io/github/actions/workflow/status/Potato-AI0815/Potato_Figure/r-smoke-test.yml)
![License](https://img.shields.io/github/license/Potato-AI0815/Potato_Figure)
![Release](https://img.shields.io/github/v/release/Potato-AI0815/Potato_Figure?include_prereleases)

> **Potato_Figure is not just a plotting theme.**
> It turns scientific evidence into publication-ready, traceable figure deliverables.
>
> **The scariest thing about AI-generated figures is not that they are ugly —
> it is that they make errors look beautiful.** Potato_Figure does not merely
> "beautify" plots; it turns scientific evidence into a submittable, traceable,
> auditable figure deliverable.

> ⚠️ **v0.1.1-alpha (Pre-release)**
> - R backend: supported (worked example verified end-to-end)
> - Python: experimental (policy-level rules only; no Python assets yet)
> - Journal-specific sizes: verify the target journal's official guide before submission
> - Current QA is a static preflight of PNG physical size / four-format completeness;
>   it is **not** a full audit of PDF/SVG/TIFF internal metadata
>   (font embedding, effective raster DPI, etc.)
> - This skill does not replace statistical or domain-expert review

1. **Journal-level figures**: five-element Figure Contract, exclusive backend, archetype classification, unified R/Python quick-start.
2. **Manuscript main-figure rules**: compress invalid whitespace, unified bar grammar, evidence-driven narrative, design–data adjacency.
3. **Dissertation-grade unified rules**: semantic color contract, physical size/font/linewidth contract, quantitative figure grammar, IHC/IVIS/WB special rules, dual-track admission vs. internal audit.

> Core stance: **the chart serves the scientific logic**; aesthetics are subordinate to conclusions that are clear, defensible, and reviewable.

## Features

- **Figure Contract first**: write core conclusion, evidence chain, archetype, backend, and export contract before any code.
- **Semantic color contract**: generic semantic colors (CONTROL/TREATMENT, UP/DOWN, HIGHLIGHT, GROUP_1-3) are frozen and never change across figures; project-specific colors go through `profiles/`.
- **Physical size & font contract**: two-column 183 mm, single-column 89 mm; panel letters 9–10 pt; 5 pt minimum for journals, 7 pt for dissertations.
- **Unified R theme & export**: `potato_theme.R` loads the theme in one call; `save_fig()` exports PDF / editable-text SVG / 600-dpi LZW TIFF / 300-dpi PNG.
- **Quantitative grammar**: forest, heatmap, paired dot-slope, box/violin + raw points selected by scenario; bars are faint mean backgrounds that always retain all independent points; per-panel statistical contract (n, test, FDR) is traceable.
- **Image panel rules**: IHC (patient as unit), IVIS (anatomical-proxy boundary), WB (full membrane/exposure/replicate provenance).
- **Data-integrity red lines**: retain all negative results; forbid pseudo-replication, cross-platform raw-expression merging, outcome-driven cutoff swapping, and mock data placeholders.
- **Two QA scripts**: `validate_figure.R` (manifest / source-data / four-format preflight) and `qa_physical_size.R` (measured physical size).

## Installation

Clone into any agent's skills directory (opencode example):

```bash
git clone https://github.com/Potato-AI0815/Potato_Figure.git \
  ~/.config/opencode/skills/Potato_Figure
```

Restart the agent and invoke the skill by name `Potato_Figure`. R dependencies: `ggplot2`, `patchwork`, `svglite`, `ragg`, `png` (ComplexHeatmap/ggrepel optional).

## Quick start

```r
source("examples/potato_theme.R")   # theme + color contract + save_fig() + qa_physical_size()
p <- ggplot(...) + potato_theme()   # local theme; or set_potato_theme() for global
save_fig(p, "output/my_figure", 183, 120)   # PDF/SVG/TIFF/PNG
Rscript scripts/qa_physical_size.R output    # size QA
```

See `examples/example_usage.R` for a complete worked example (forest + heatmap + faceted panel + source data + manifest).

## Layout

```text
Potato_Figure/
├── SKILL.md                  # main skill file (full spec + install/usage)
├── README.md                 # this file (Chinese)
├── README_EN.md              # English
├── LICENSE                   # MIT
├── CHANGELOG.md
├── manifest.yaml             # skill metadata
├── examples/
│   ├── potato_theme.R        # unified theme, colors, export, size QA
│   └── example_usage.R       # complete worked example
└── scripts/
    ├── validate_figure.R     # static preflight before delivery
    └── qa_physical_size.R    # measured PNG physical size
```

## Usage tips

1. Write the Figure Contract (SKILL.md §0) before any code.
2. Call colors/sizes/fonts only from `potato_theme.R`; never hard-code inside panels.
3. Run both QA scripts after export; deliver only on PASS.
4. Negative, contrary, and uncertain results must remain in source data or internal audit.

## License

MIT — free to use, modify, and distribute (see LICENSE).
