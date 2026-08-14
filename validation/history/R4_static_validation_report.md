# Historical R4 Static Validation Report (not v0.4.1 R2 release evidence)

Date: 2026-08-09
Status: **STATIC PASS / RUNTIME PENDING LOCAL R**

## Scope

This patch is intentionally structural and limited. It does not rewrite the frozen R1 scientific/delivery audit layer.

Added:

1. persistent `Global Figure State` contract;
2. dependency-aware local-change impact/closure layer;
3. figure-assembly contract;
4. evidence-backed `potato-user-v1` visual profile;
5. modality-agnostic Figure Grammar Core + single-cell adapter boundary;
6. R4 global-coherence audit and readiness gate;
7. R4 regression tests;
8. Python static package validator.

R2/R3 scientific/visual references and single-cell/claim-evidence audit scripts are preserved in the full package. The historical R2/R3 audit package is retained under `benchmarks/r2_r3_reference/` for regression/reference only.

## Static validation performed

Command:

```bash
python scripts/static_validate.py .
```

Result:

```text
STATIC_VALIDATION passes=85 warnings=0 errors=0
STATIC_VALIDATION: PASS
```

The static validator checked:

- required R4 files exist;
- YAML examples/profiles pass basic key/indentation sanity checks;
- TSV headers match their contracts;
- repository-relative paths referenced by `SKILL.md` resolve;
- required Global Figure State fields are present in the example;
- `potato-user-v1` contains the intended compactness/typography/bar-consistency/no-grey-default rules;
- R scripts/tests pass a delimiter-balance and source sanity scan;
- the universal-core / modality-adapter boundary is explicitly present;
- the Global Figure State + local-impact mechanism is explicitly present.

## Important runtime limitation

The current build environment does **not** contain `R`/`Rscript`, so R execution tests could not be run here. Therefore this report does not claim runtime PASS.

The package includes:

- frozen R1 16-fixture regression suite (`tests/run_tests.R`);
- new R4 4-fixture regression suite (`tests/run_r4_tests.R`);
- GitHub Actions workflow configured to run both when pushed.

Local runtime acceptance requires both suites to pass.

## R4 expected regression behaviour

The R4 test suite asserts:

1. valid Global Figure State + closed local change + PASS whole-figure review → `GLOBAL_COHERENCE=PASS`, publication-ready allowed if other R1 gates pass;
2. open/unreviewed local repair → fail closed (`GLOBAL_COHERENCE=FAIL`);
3. personal-profile typography outside preferred range → `GLOBAL_COHERENCE=REVISE`, not publication-ready;
4. hero panel absent from the declared manuscript panel graph → `GLOBAL_COHERENCE=FAIL`.

## No-release status

No GitHub Release was created. This package is for local R4 validation only.
