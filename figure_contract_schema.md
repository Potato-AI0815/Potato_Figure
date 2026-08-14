# `figure_contract.yaml` schema

`figure_contract.yaml` is the figure-level design and status contract. It is deliberately separate from the panel-level scientific manifest.

The R1 parser accepts a flat YAML mapping. Required frozen fields are:

| Field | Meaning |
|---|---|
| `central_claim` | The single figure-level scientific claim. |
| `hero_evidence` | Panel/evidence carrying the claim. |
| `supporting_evidence` | Supporting evidence identifiers or description. |
| `figure_grammar` | Selected figure grammar. |
| `visual_profile` | Selected visual profile identifier. |
| `authoring_profile` | Authoring profile, including `a4-working` only when intentionally selected. |
| `target_journal` | Target journal or `unspecified`. |
| `reference_figure` | Reference identifier/path or `none`. |
| `reading_order` | Intended reading path. |
| `scientific_status` | `PASS`, `WARNING`, `FAIL`, or `NOT_EVALUABLE`. |
| `delivery_status` | `PASS`, `WARNING`, or `FAIL`. |
| `visual_status` | `PASS`, `REVISE`, `FAIL`, or `NOT_REVIEWED`. |

R1 delivery extensions:

| Field | Meaning |
|---|---|
| `requested_formats` | Comma-separated formats required by the selected profile. |
| `final_width_mm` / `final_height_mm` | Expected cropped delivery dimensions. |
| `raster_dpi` | Minimum raster DPI, when raster formats are requested. |
| `delivery_metadata_file` | Relative path to measured delivery metadata. |
| `session_metadata` | Relative path to session/reproducibility metadata, when available. |
| `a4_proof_file` | Required only when `authoring_profile: a4-working`; otherwise `NA`. |
| `visual_qa_file` | Relative path to the human visual-review record. |

## Publication readiness

`PUBLICATION_READY` is true only when:

```text
Scientific Audit = PASS
Delivery QA       = PASS
Visual status     = PASS
Visual interface  = READY
```

`Scientific = PASS`, `Delivery = PASS`, and `Visual = REVISE` therefore yields `PUBLICATION_READY = FALSE`.

The contract records visual status but does not automate aesthetic scoring. Visual review occurs only after render.

## R4 global-coherence extensions

R4 is backward-compatible with the R1 contract. A figure enters R4 global-state mode when either of these is declared:

```text
coherence_mode: global_state
```

or

```text
global_state_file: global_figure_state.yaml
```

Recommended R4 fields:

| Field | Meaning |
|---|---|
| `coherence_mode` | `global_state` for persistent whole-figure state. |
| `global_state_file` | Relative path to `global_figure_state.yaml`. |
| `global_coherence_qa_file` | Relative path to post-render whole-figure review. |
| `global_coherence_status` | Contract state: `PASS`, `REVISE`, `FAIL`, or `NOT_REVIEWED`. |
| `modality_adapter` | Optional adapter identifier, e.g. `single-cell`; never a replacement for the universal core. |

In R4 mode, `PUBLICATION_READY` additionally requires derived Global Coherence = PASS and consistency between the contract and derived global status.
