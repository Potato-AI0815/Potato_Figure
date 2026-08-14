# R6.1 Warning Semantics & Validation Evidence Hotfix Report

## BASE_PACKAGE

- `Potato_Figure_Audit_v0.4.1-alpha-R6.zip`

## OUTPUT_PACKAGE

- `Potato_Figure_Audit_v0.4.1-alpha-R6.1.zip`
- SHA256: computed at packaging time (see `.sha256` sidecar)

## ROOT_CAUSE

`WARNING_ESCALATED_TO_REVISE`

`color_readiness_status()` mapped `COLOR_AUDIT_STATUS = PASS_WITH_WARNINGS`
to domain `REVISE`, upgrading MINOR/WARNING color findings into a
publication blocker. Additionally `COLOR_SYSTEM_READY` was computed as
FALSE when any non-blocking rule (e.g. COLOR-14 symbol semantics without
vision observation) was NOT_EVALUABLE, and `evaluate_readiness.R`
`coverage_ok` did not admit `WARNING`.

## CODE_PATH_CHANGED

| File | Change |
|---|---|
| `scripts/lib/color_integration.R` | `color_readiness_status()`: severity-preserving mapping |
| `scripts/audit_color_system.R` | `COLOR_AUDIT_STATUS` / `COLOR_SYSTEM_READY` aggregation: non-blocking NE no longer forces FALSE; NE → `PASS_WITH_LIMITED_EVIDENCE` |
| `scripts/evaluate_readiness.R` | `coverage_ok` admits `WARNING` (still fail-closed on NOT_EVALUABLE/NOT_REVIEWED) |
| `scripts/lib/audit_core.R` | `domain_status_from_findings()`: evidence-missing WARNING does not override measured PASS |
| `tests/run_warning_semantics_tests.R` | new behavioral suite (W1-W8 + MONO + MAJOR + BLOCKER) |
| `tests/run_color_system_tests.R` | C14 expectation widened FAIL → (FAIL\|REVISE) — color still blocks readiness, status semantics updated (TEST_EXPECTATION_CHANGE_REASON below) |

## OLD_MAPPING

```r
PASS_WITH_WARNINGS  → REVISE           # escalation bug
COLOR_SYSTEM_READY  → FALSE on any NE  # non-blocking NE blocked readiness
coverage_ok         → PASS, NOT_APPLICABLE only
```

## NEW_MAPPING

```r
COLOR PASS  + READY        → PASS
COLOR PASS_WITH_WARNINGS  + READY → WARNING   # non-blocking
COLOR PASS_WITH_LIMITED_EVIDENCE / NOT_EVALUABLE → WARNING  # non-blocking evidence gap
COLOR REVISE              → REVISE   # blocks
COLOR FAIL                → FAIL     # blocks
coverage_ok = all(status ∈ {PASS, WARNING, NOT_APPLICABLE})  # NE/NOT_REVIEWED still fail-closed
```

## WARNING_SEMANTICS_TESTS

16/16 PASS (W1-W8, severity monotonicity, major propagation, blocker control)

## R1_BEFORE / R1_AFTER

- before: 12/16 (4 fixtures failed: valid_complete, prespecified_paired,
  non_A4_profile, valid_unpaired — all COLOR-warning escalation)
- after: **16/16 PASS**

## R4_BEFORE / R4_AFTER

- before: failed on same warning escalation (valid global-state fixture
  expected ready TRUE)
- after: **4/4 PASS**

## A_REGRESSION

QUICK_REVIEW = REVISE (unchanged) ✓

## B_REGRESSION

- SCIENTIFIC = PASS, COLOR-13 = PASS
- FIGURE_INTEGRITY = PASS (COLOR domain now PASS; not NOT_EVALUABLE)
- PUBLICATION_PACKAGE = INCOMPLETE
- PUBLICATION_READY = FALSE (package still incomplete — correct) ✓

## C_REGRESSION

- SCIENTIFIC = FAIL (multiplicity NONE), COLOR-13 = MAJOR/REVISE
- FIGURE_INTEGRITY = FAIL
- PUBLICATION_READY = FALSE ✓ (safety control preserved)

## AUDIT / VISUAL_CORRECTION / COLOR_SYSTEM

- AUDIT = 10/10
- VISUAL_CORRECTION = 10/10
- COLOR_SYSTEM = 14/14

## GATE_SEMANTICS / AUDIT_MODE / EVIDENCE_AGGREGATION / REAL_FIGURE

- GATE_SEMANTICS = 8/8
- AUDIT_MODE = 6/6
- EVIDENCE_AGGREGATION = 8/8
- REAL_FIGURE = 18/18

## PACKAGING

- PACKAGING_COMPLIANCE = PASS
- ZIP_STANDARD_PATHS = PASS
- single root `potato-figure-audit/`, forward slashes, no absolute paths

## VALIDATION_EVIDENCE_FILES_UPDATED

- `RUNTIME_VALIDATION_REPORT.md` — rewritten as R6.1 current truth
- `TEST_MATRIX.tsv` — R6.1 full matrix (real executions)
- `validation/PACKAGING_COMPLIANCE_REPORT.md` — R6.1 header
- `manifest.yaml` — added `packaging_revision: R6.1`
- `CHANGELOG.md` — R6.1 entry
- stale snapshots → `validation/history/` with HISTORICAL marker
  (R1_integration_report, R1.1, R4_local, MIGRATION_REPORT,
  COLOR_SYSTEM_PATCH_REPORT, LOCAL_VALIDATION, old RUNTIME/STATIC,
  old TEST_MATRIX)
- `R1_test_matrix.tsv` kept at repo root (test input; not evidence snapshot)

## STALE_EVIDENCE_COUNT

0 (current-release files consistent; historical files marked and moved)

## TEST_EXPECTATION_CHANGE_REASON

C14 (`run_color_system_tests.R`) previously asserted `"COLOR":"FAIL"` in
readiness JSON. Under R6.1 severity-preserving semantics the same blocking
color violation is reported as `REVISE` (still blocks readiness). The test's
intent — color findings propagate to readiness and block it — is unchanged;
expectation widened to `(FAIL|REVISE)`.
POLICY_REFERENCE: R6.1 spec §4-§5 (MAJOR/REVISE/FAIL block; severity
preserved during aggregation).
WHY_IMPLEMENTATION_WAS_NOT_THE_BUG: the implementation now correctly
preserves severity; the old literal "FAIL" string was a pre-R6.1 artifact.

## FUNCTIONAL_DRIFT

```
SCIENTIFIC_LOGIC_CHANGED = NO
COLOR_RULE_DEFINITIONS_CHANGED = NO
RASTER_LOGIC_CHANGED = NO
GFS_ARCHITECTURE_CHANGED = NO
AUDIT_MODES_CHANGED = NO
READINESS_STATUS_MAPPING_CHANGED = YES
REPORT_EVIDENCE_UPDATED = YES
```

## SHA256

See `Potato_Figure_Audit_v0.4.1-alpha-R6.1.zip.sha256` (computed at
packaging, not copied from any previous package).

## FINAL_STATUS

PASS
