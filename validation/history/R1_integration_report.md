# R1 execution-layer integration report

## Scope

R1 selectively migrated the validated execution ideas from Potato_Figure `v0.1.5-alpha` into the frozen v0.2 architecture. The design kernel, visual profiles, art-direction hierarchy, and A4 conditionality were not redesigned.

The legacy tag audited for inventory was GitHub `v0.1.5-alpha` at commit `2aed5d3d4dbc51cd3bd5beb0e5c62825d1d995b7`.

## Integration decisions

- Scientific Audit is now `scripts/audit_scientific.R` plus a reusable core library.
- Delivery QA is now `scripts/qa_delivery.R` plus a reusable core library.
- `scripts/evaluate_readiness.R` combines computed scientific/delivery outcomes with the post-render human visual status without scoring aesthetics.
- The panel-level `figure_manifest.tsv` and figure-level `figure_contract.yaml` are separate contracts.
- JSON generation is dependency-free and preserves a nonzero exit code for FAIL.
- Requested formats, dimensions, raster resolution, and A4 proof are selected-profile checks rather than universal assumptions.
- A4 proof is `NOT_APPLICABLE` unless `authoring_profile: a4-working`.
- Visual QA records ten post-render domains and explicitly permits `REVISE` while science and delivery pass.

## Legacy behavior deliberately not migrated

- fixed theme and fixed palette assumptions;
- fixed 89/110/183 mm physical-size logic;
- universal four-format/A4 assumptions outside the active profile;
- old gallery demos and equal patchwork layout;
- v0.1.x art-direction logic.

## Automated validation

The R1 baseline fixture set was expanded by the R1.1 integrity regression patch to sixteen synthetic fixtures. They are generated deterministically by `tests/generate_fixtures.R`. `tests/run_tests.R` asserts:

- expected PASS cases return exit code 0;
- expected Scientific/Delivery failures return exit code 1;
- all JSON outputs contain the expected top-level state;
- A4 applicability is explicitly checked, including the `not_applicable` scope;
- `visual_status: REVISE` always produces `PUBLICATION_READY: FALSE`;
- a domain-level `REVISE` or `FAIL` overrides an optimistic contract `visual_status: PASS`;
- explicit paired/rank-sum and unpaired/signed-rank contradictions fail;
- valid unpaired t-test, Welch t-test, and paired t-test terminology passes;
- duplicate visual domains make the Visual QA interface not ready;
- every requested output format has exactly one delivery metadata row.

Local R execution result on 2026-08-08:

```text
Scientific Audit: PASS
Delivery QA: PASS
JSON: PASS (all generated JSON parsed)
Tests: 16/16 PASS
Pairing regression: PASS
Visual-domain uniqueness: PASS
CI workflow: PASS under local-equivalent execution; GitHub-hosted run pending repository publication
Visual QA interface: READY
```

## R1 stop-condition invariants

```text
universal_theme = FALSE
universal_palette = FALSE
universal_A4 = FALSE
scientific_visual_QA_separated = TRUE
```

## R1.1 integrity regression patch

The patch keeps the R1 architecture unchanged and closes two release blockers plus two hardening gaps:

1. `evaluate_readiness.R` derives visual status from the ten `visual_qa.tsv` domain rows. The contract value is retained for consistency reporting but is not trusted as the final visual result.
2. Scientific Audit now fails only explicit, high-confidence pairing/test contradictions: paired with rank-sum/Mann–Whitney/Welch/independent tests, or unpaired with signed-rank/paired tests. Complex models remain human-review items.
3. Delivery QA requires exactly one metadata row for each primary output × requested format.
4. CI runs when `schemas/**` and `profiles/**` change.

New regression cases are `valid_unpaired_t_test`, `visual_contract_PASS_but_domain_REVISE`, `visual_contract_PASS_but_domain_FAIL`, `paired_rank_sum_mismatch`, `unpaired_signed_rank_mismatch`, `missing_delivery_metadata_row`, and `duplicate_visual_domain_conflict`.

## Known boundary

R1 verifies declared delivery metadata; it does not yet inspect PDF/SVG/TIFF internals to independently measure page boxes, embedded fonts, colour spaces, or effective raster DPI. That future artifact-inspector work is outside R1. Visual QA remains a human post-render interface and CI does not score aesthetics.
