# Runtime Validation Report

> AUTO-GENERATED from `validation/latest_validation.json` by
> `scripts/generate_validation_report.R`. Do not edit by hand.

- skill: potato-figure-audit v0.4.3-alpha
- generated: 2026-08-14T13:17:48+0800
- machine: Windows 10 x64 x86-64
- R: 4.6.1
- **overall: PASS**

Totals: 11/11 suites PASS; 177/177 checks PASS; validator PASS.

## Test suites

| suite | script | exit | checks | status | seconds |
|---|---|---|---|---|---|
| r1_regression | `tests/run_tests.R` | 0 | 16/16 | PASS | 43.7 |
| r4_local | `tests/run_r4_tests.R` | 0 | 4/4 | PASS | 6.7 |
| audit_core | `tests/run_audit_tests.R` | 0 | 10/10 | PASS | 0.6 |
| color_system | `tests/run_color_system_tests.R` | 0 | 14/14 | PASS | 13.8 |
| r6_gate_semantics | `tests/run_r6_tests.R` | 0 | 24/24 | PASS | 0.4 |
| r6_real_regression | `tests/run_r6_real_regression.R` | 0 | 19/19 | PASS | 49.6 |
| warning_semantics | `tests/run_warning_semantics_tests.R` | 0 | 16/16 | PASS | 0.4 |
| raster_security | `tests/run_raster_security_tests.R` | 0 | 7/7 | PASS | 7.6 |
| main_entry | `tests/run_main_entry_tests.R` | 0 | 34/34 | PASS | 53.1 |
| visual_correction | `tests/run_visual_correction_tests.R` | 0 | 10/10 | PASS | 0.4 |
| binding_serializer | `tests/run_binding_serializer_tests.R` | 0 | 23/23 | PASS | 19.6 |

## Static package validator

- tool: `scripts/validate_skill_package.py`
- python: python
- exit code: 0
- status: PASS
- detail: SKILL_ROOT = potato-figure-audit SKILL_NAME_DIRECTORY_MATCH = PASS PACKAGE_COMPLIANCE = PASS ZIP_PATH_SCAN = NOT_EVALUATED (no archive supplied) PACKAGE_COMPLIANCE: PASS

## Evidence policy

- Single machine source of truth: `validation/latest_validation.json`.
- This report and `TEST_MATRIX.tsv` are regenerated from that JSON;
  manual edits are invalid.
- Reproduce: `Rscript scripts/run_release_validation.R` then
  `Rscript scripts/generate_validation_report.R`.
- Fixtures are synthetic; see `DATA_PROVENANCE.md` (no real patient data).

