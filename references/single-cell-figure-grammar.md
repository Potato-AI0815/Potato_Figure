# Single-Cell Figure Grammar (R2.4)

Core rules for designing single-cell main figures. Applies to all scRNA-seq /
multi-modal single-cell figures in Potato_Figure.

## 1. Cell-level visualization ≠ biological inference

UMAP / FeaturePlot / cell-level violin / DotPlot are primarily
**descriptive / identity / landscape** evidence. They cannot automatically
serve as sample-level inferential evidence.

## 2. Cells are not biological n

The inferential statistical unit is patient / sample / animal / independent
experiment — unless the study design explicitly defines another independent
unit. Cell counts must never be used as n for biological inference.

## 3. UMAP is not the default hero

UMAP is hero ONLY when the central claim itself concerns:
- cellular landscape
- state architecture
- lineage / state organization

Otherwise reduce its area to a supporting role.

## 4. Marker DotPlot is identity/support evidence

A DotPlot must not automatically occupy the largest panel just because it
carries many rows. Its area follows its evidence role.

## 5. Cell-composition stacked bars are descriptive

Composition overview is descriptive. For inference, complement with
**sample/patient-level proportion analysis** (paired tests on per-patient
proportions).

## 6. Volcano plot is not the default hero

If the central claim is a sample-level differential effect, prefer
effect-size / pseudobulk summary over a volcano.

## 7. Four evidence classes

Every panel in a single-cell main figure must be classified:

| Class | Typical panels |
|---|---|
| `LANDSCAPE` | UMAP / embedding / state map |
| `PATIENT_OR_SAMPLE_LEVEL` | paired proportion, sample-level score, biological-replicate effect |
| `IDENTITY_PROGRAM` | marker/program DotPlot, heatmap, signature evidence |
| `INFERENCE` | pseudobulk DE, effect estimate, FDR, model result |

- A main figure need NOT contain all four classes.
- Each panel MUST belong to one class; panels are included because they carry
  an evidence role, not merely because the pipeline produced them.
- Patient-level effects must be visually distinguished from cell-level
  descriptive views (e.g., different mark shape/area, explicit "patient-level"
  axis labels).

## 8. Redundancy rule

If two panels display the same information (e.g., patient × program
paired-change heatmap AND a patient-level effect summary of the same deltas),
delete one. Never keep a panel merely to complete a layout.
