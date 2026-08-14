# Global Figure State (R4)

## Purpose

`global_figure_state.yaml` is the persistent figure-level state that prevents a local repair from silently damaging the rest of a scientific figure. It is not a replacement for `figure_manifest.tsv` or `figure_contract.yaml`.

- `figure_manifest.tsv` records panel-level provenance and statistics.
- `figure_contract.yaml` freezes the figure-level claim/design/delivery contract.
- `global_figure_state.yaml` records the current whole-figure scientific, narrative, geometric and visual state during iterative design.

The R4 rule is simple:

> Read global state before a local edit; register the change; compute its impact radius; rerender affected components; then revalidate the whole figure.

## Required top-level state domains

The shipped R parser uses flat YAML keys with dot notation. Required keys for R4 mode are:

```yaml
state_version: 1.0
figure_id: Figure_1
modality: generic
assembly_mode: publication
scientific.central_claim: ...
scientific.statistical_unit: patient
narrative.reading_order: a,b,c
narrative.hero_panel: a
narrative.panel_tags: a,b,c
visual.profile: potato-user-v1
visual.body_pt: 9
visual.axis_text_pt: 8.5
visual.panel_tag_pt: 11
geometry.target_width_occupancy: 0.88
geometry.target_height_occupancy: 0.82
geometry.outer_margin_mm: 3.5
geometry.panel_gap_mm: 3
assembly.final_canvas: one_figure
repair.change_log_file: local_change_log.tsv
```

Panel-specific keys can be added without changing the core schema:

```yaml
panel.a.question: What cellular landscape is present?
panel.a.role: context
panel.a.evidence_class: CONTEXT_OR_LANDSCAPE
panel.a.unique_information: cell-state architecture
panel.b.question: How does the biological unit change?
panel.b.role: hero
panel.b.evidence_class: SAMPLE_LEVEL_QUANTITATIVE
```

## State invariants

R4 must preserve these invariants across local edits:

1. **Scientific spine** — central claim, statistical unit, primary contrast and evidence level do not drift silently.
2. **Narrative spine** — every panel has one question and a non-redundant role; the hero remains identifiable.
3. **Geometry spine** — panel area follows evidence importance and information density, not automatic grid cells.
4. **Visual spine** — typography, colour architecture, whitespace budget and physical consistency remain coherent across panels.
5. **Assembly spine** — the final deliverable reads as one manuscript figure, not several independent plots sharing a canvas.
6. **Integrity spine** — unresolved local changes block `PUBLICATION_READY`.

## Lifecycle

### Before the first render

1. Freeze the scientific contract.
2. Create `global_figure_state.yaml`.
3. Assign panel questions/evidence classes.
4. Load the visual profile.
5. Allocate geometry and colour budgets.

### Before every local modification

Append a row to `local_change_log.tsv` with `closed=no`, then run:

```bash
Rscript scripts/check_change_impact.R /path/to/figure_dir
```

The impact audit determines which domains must be rechecked.

### After the local modification

1. Update the state fields actually changed.
2. Rerender the affected panel(s) and final assembly.
3. Recheck the required impacted domains.
4. Mark the change `closed=yes`, `global_state_updated=yes`, `recheck_status=PASS` only after completion.
5. Run global coherence audit again.

## Fail-closed rule

An open change, missing impact scope, missing global-state update or failed global recheck prevents R4 global coherence from passing. The system must not assume that fixing one panel improved the whole figure.
