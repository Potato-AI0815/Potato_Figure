# Migration — v0.3.0 → v0.4.0 (Audit + Visual Correction)

Date: 2026-08-10

## What changed

| Area | v0.3 | v0.4 |
|---|---|---|
| Product | independent audit layer | audit layer + **Potato Visual Correction Mode** |
| New script | — | `scripts/generate_visual_correction_brief.R` |
| New output | — | `visual_correction_brief.yaml` + `.md` |
| Visual evidence | `visual_status` declaration | **`visual_evidence_source`** (RASTER/VECTOR/VISION/MANUAL/METADATA_ONLY/NONE) |
| Readiness | single PASS/FAIL | **AUDIT_COMPLETED / AUDIT_COVERAGE / PUBLICATION_READY** (A9) |
| Visual QA | profile rules implicit | profile rules formalized; **profile violation = REVISE, never Scientific FAIL** |
| Severity | BLOCKER/MAJOR/MINOR/INFO | kept; brief issues carry priority + confidence + evaluation_source |
| New tests | — | `tests/run_visual_correction_tests.R` (10 cases) |

## Frozen (unchanged, still passing)

- Scientific Integrity / Statistical-unit / Pairing / Multiplicity / Source
  Data rules (R1)
- Claim–Evidence (R2.12)
- Global Figure State / Local Change Impact / Global Coherence / Fail-closed
  (R4)
- Delivery / Reproducibility QA (R1)
- `potato-user-v1` profile (R4) — now explicitly a USER VISUAL PROFILE, not
  scientific law

## Compatibility

- R1 regression 16/16 — kept; `evaluate_readiness.R` JSON regained legacy
  fields (`visual_status`, `visual_qa_interface`, `publication_ready`,
  `global_coherence_status`) alongside new A9 fields.
- R4 regression 4/4 — global coherence audit still invoked from readiness.
- Audit regression 10/10.
- New Visual Correction regression 10/10.

## Behavioral notes

- `evaluate_readiness.R --json` now emits BOTH legacy and new fields so old
  test contracts and new consumers both work.
- `GLOBAL_COHERENCE` is NOT_APPLICABLE when no global_figure_state.yaml
  exists (R1-era scientific-only figures remain evaluable without it).
- A figure with only a PNG cannot reach PUBLICATION_READY (A9 + A5).
