# Single-Cell Figure Grammar Adapter

This adapter refines the universal Figure Grammar Core for scRNA-seq/snRNA-seq. It is not the Potato_Figure core.

## Evidence roles

- UMAP/t-SNE/embedding → `CONTEXT_OR_LANDSCAPE` unless the claim itself concerns state architecture.
- Marker DotPlot / marker heatmap → `IDENTITY_OR_CHARACTERIZATION`.
- sample/patient composition or score → `SAMPLE_LEVEL_QUANTITATIVE`.
- pseudobulk/model effect → `INFERENTIAL`.

## Scientific safeguards

- cells are not automatically biological replicates;
- UMAP position alone does not prove lineage direction or group effect;
- cell-level descriptive panels cannot by themselves establish a patient-level inferential claim;
- stacked cell proportions are descriptive unless sample-level inference is provided;
- cell-level DE across multiple biological samples must not use cells as independent inferential replicates;
- marker DotPlots do not automatically prove group-level differential expression.

## Visual safeguards

- embedding point size should be tuned to final physical size and density;
- avoid rainbow category palettes;
- use direct state labels or compact legends when readable;
- do not automatically make UMAP the hero;
- do not generate two large redundant embeddings merely because both are available.
