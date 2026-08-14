# DATA_PROVENANCE.md — Potato Figure Audit v0.4.3-alpha

Status: PUBLIC RELEASE — this package ships **no real patient-level data**.

## Summary

Every data file in this package is either (a) a fully synthetic fixture generated
for testing, or (b) excluded from the public payload. No controlled-access,
patient-level, or personally identifiable research data is distributed.

## Regression fixtures: `tests/regression_three_tier/`

The three-tier regression (`A_sloppy`, `B_workflow`, `C_nature_only`) exercises the
audit pipeline end-to-end. The `B_workflow` and `C_nature_only` tiers use a shared
**synthetic** survival + gene-expression cohort that replaces an earlier real
multiple-myeloma dataset (MMRF CoMMpass, dbGaP phs000748 — controlled access).
The real data has been removed from the package; only synthetic equivalents remain.

Synthetic fixture construction (deterministic, reproducible):

- Generator: seeded R script (`set.seed(20260813)`), 763 synthetic patients, 773
  samples (10 patients contribute two samples to exercise pseudoreplication
  detection). Sample identifiers are `SYNTH_P###_S#` — they reference no real
  donor, patient, or study.
- Survival: `synthetic_survival.tsv` (`sample`, `OS`, `OS.time`) drawn from a
  risk-driven exponential model with administrative censoring.
- Expression: `synthetic_expression_targets.tsv` (`sample` + 12 genes) with a
  planted survival signal so the audit's statistical narrative stays meaningful:
  CD38, MKI67, DNTT are OS-associated (significant after BH-FDR); CD19 is
  nominally significant (raw P < 0.05) but NOT significant after BH-FDR
  (q ≈ 0.052) — this is the exact teaching case that distinguishes the
  workflow tier (B, applies FDR) from the naive tier (C, reports uncorrected).
- Figures: `figure.png` in each tier is re-rendered from the synthetic data by the
  tier's `render_*.R` script. Figures are regenerated derivatives of synthetic
  data and contain no real measurements.

The exact q/p values for the current synthetic seed are recorded in each tier's
`statistical_metadata.tsv`.

## Historical benchmarks: `benchmarks/`

`benchmarks/r2_r3_reference/` contains development-history artifacts from earlier
iteration rounds (R2/R3), including small tables derived from the **public** GEO
accession GSE241405 (publicly available, anonymized) and rendered example PNGs.
This directory is **not required at runtime** (no script, test, or contract
references it) and is **excluded from the public release payload**. It is retained
only in the development repository for internal reference.

## Validation reports

Legacy root-level validation reports from prior rounds (R0–R6.1) referenced the
original real dataset by name. They have been archived under `validation/history/`
and superseded by the machine-generated `validation/latest_validation.json`, which
is the single source of truth for release evidence.

## Reproducing the synthetic fixtures

Regenerate the fixtures with the seeded generator (kept in the development
repository, not shipped). Because the generator is seeded, the shipped fixtures and
any regenerated copy are byte-identical in structure and statistically equivalent.

If you adapt these fixtures for your own figures, replace the synthetic cohort with
your own data and re-run the tier render scripts; the audit contracts
(`figure_manifest.tsv`, `figure_contract.yaml`) describe the statistical design and
are what the audit actually evaluates.
