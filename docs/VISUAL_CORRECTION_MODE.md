# Potato Visual Correction Mode (v0.4)

## Purpose

Not redrawing. Converting "this figure looks bad" into:

> why it is wrong + where it is wrong + how to change it + what must not break.

## Pipeline

```
Figure Generator
        ↓
Potato Figure Audit
        ↓
PASS / REVISE / FAIL
        ↓
Visual Correction Brief   ← this mode
        ↓
Generator / Human Revision
        ↓
Re-audit
```

## Outputs

- `visual_correction_brief.yaml` — machine-readable
- `visual_correction_brief.md` — human-readable

## Issue schema

```yaml
issue_id: VIS-001
priority: HIGH|MEDIUM|LOW
severity: BLOCKER|MAJOR|MINOR|INFO
domain: canvas_utilization|typography|colour_semantics|panel_redundancy|...
affected_panels: [a, b, c]
diagnosis: "<why it is wrong>"
why_it_matters: "<impact on communication>"
recommended_action: "<what to change>"
preserve_constraints: "<what must not break>"
global_recheck: "<which global properties to re-verify>"
upstream_owner: FIGURE_GENERATOR|STATISTICS|ANALYSIS|MANUSCRIPT|MANUAL_REVIEW
confidence: HIGH|MEDIUM|LOW
evaluation_source: IMAGE_REVIEW|METADATA|PROFILE|MANUAL|NOT_EVALUABLE
```

## evaluation_source semantics

| Source | Meaning |
|---|---|
| IMAGE_REVIEW | based on actual raster/vector inspection (incl. vision model) |
| METADATA | derived from manifest/contract/metadata (not pixels) |
| PROFILE | from potato-user-v1 (or other) profile rules |
| MANUAL | from human review notes |
| NOT_EVALUABLE | cannot be assessed with available evidence |

## Example

```
issue_id: VIS-001
severity: MAJOR
domain: canvas_utilization
affected_panels: [c]
diagnosis: Panel C occupies excessive physical area relative to its evidence density.
recommended_action: Reduce Panel C vertical allocation by ~1 layout unit and
                    redistribute recovered space to the hero evidence panel.
preserve_constraints: shared_alignment; comparable_font_size; hero_hierarchy; matched_bar_width
global_recheck: reading_order; total_canvas_utilization; panel_balance; typography; legend
upstream_owner: FIGURE_GENERATOR
```

## Local fix ≠ global improvement

Every correction declares `repair_radius` / `affected_nodes` /
`global_recheck`. Changing Panel C height requires re-verifying: adjacent
panels, hero hierarchy, canvas, alignment, reading order, legend, total
density — never only panel C.

## Generator-agnostic

The brief is a contract for any upstream tool (R, Python, Prism,
Illustrator, Nature-Figure, AI). Potato Figure Audit never draws.
