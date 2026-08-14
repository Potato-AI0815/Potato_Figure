# R6 Gate Semantics & Report Consolidation Validation Report

## BASE_VERSION

- Skill: `potato-figure-audit`
- Functional version: `v0.4.1-alpha`
- Packaging revision: `R6` (from `R5`)
- Scope: report semantics / gate semantics / evidence aggregation only.
  No new color rules, no scientific-rule changes, no GFS architecture
  rewrite, no renderer changes.

## FILES_CHANGED

- `scripts/audit_figure.R` — `--mode` parsing (both `--mode X` and
  `--mode=X`), mode-gated domain evaluation, QUICK_REVIEW raster fallback,
  GFS-missing handling per mode, R6 gate semantics output, new exit codes.
- `scripts/evaluate_readiness.R` — layered statuses (`figure_integrity`,
  `publication_package`) added; legacy fields kept.
- `scripts/lib/audit_core.R` — AUDIT_MODES + mode/domain tables,
  `infer_audit_mode`, `domain_status_from_findings`,
  `compute_figure_integrity`, `compute_publication_package`,
  `classify_package_findings` (missing vs error),
  `aggregate_rule_evidence`, `repair_routes`, R6 markdown renderer,
  R6 JSON writer, empty-finding-message validator.
- `scripts/lib/color_integration.R` — rule_id propagation into findings;
  optional evidence fallback for QUICK_REVIEW.
- `scripts/audit_color_system.R` — QUICK_REVIEW evidence fallback hook.
- `tests/run_r6_tests.R` — new behavioral tests (new).
- `tests/run_r6_real_regression.R` — A/C/B real-figure regression (new).
- `SKILL.md` — Audit modes section.
- `CHANGELOG.md` — R6 entry.

## FUNCTIONAL_SCOPE

1. Split Figure integrity from publication-package readiness.
2. INCOMPLETE vs FAIL distinction (missing vs declared-but-wrong).
3. Three audit modes with auto-selection.
4. Rule-level evidence aggregation (one final status per rule).
5. New report structure + machine-readable JSON + repair routing.
6. Empty-finding-message enforcement.
7. QUICK_REVIEW image-only evaluation (no fabricated scientific claims).

## REAL FIGURE REGRESSION (A / C / B, MMRF data)

### B_AFTER (full workflow) — matches spec §25/§52

```
AUDIT_MODE = SCIENTIFIC_FIGURE_AUDIT
SCIENTIFIC = PASS        (patient n=763, BH-FDR)
PANEL_ARCHITECTURE = PASS
VISUAL = PASS
COLOR = NOT_EVALUABLE (limited evidence; COLOR-13 PASS, COLOR-14 PASS)
FIGURE_INTEGRITY = PASS
PUBLICATION_PACKAGE = INCOMPLETE   (missing GFS, PDF/SVG/TIFF, metadata)
PUBLICATION_READY = FALSE
NEXT_ACTION = COMPLETE_DELIVERY
```

### C_AFTER (nature-figure only) — matches spec §26

```
SCIENTIFIC = FAIL        (multiplicity_method = NONE → blocker)
COLOR = REVISE           (COLOR-13 = REVISE/MAJOR: gray data encoding)
FIGURE_INTEGRITY = FAIL
PUBLICATION_PACKAGE = INCOMPLETE
PUBLICATION_READY = FALSE
NEXT_ACTION = RETURN_TO_FIGURE
```

### A_QUICK_REVIEW (sloppy, image only) — matches spec §27

```
AUDIT_MODE = QUICK_REVIEW
SCIENTIFIC = NOT_EVALUABLE   (no fabrication)
STATISTICAL = NOT_EVALUABLE
VISUAL = REVISE  (raster: 189 palette clusters, accent 0.75)
COLOR = REVISE   (raster fragmentation, no declared semantic palette)
PUBLICATION_READY = FALSE
```

## GATE_SEMANTICS_TESTS (8/8)

Behavioral tests (construct input → run aggregator → inspect status):

- G1 FI=PASS + missing delivery → PKG=INCOMPLETE, READY=FALSE
- G2 scientific FAIL → FI=FAIL
- G3 declared-but-wrong (dimension mismatch) → PKG=FAIL
- G4 image-only → QUICK_REVIEW inference
- G5 manifest present → SCIENTIFIC_FIGURE_AUDIT inference
- G6 explicit PUBLICATION_READY wins
- G7 NOT_EVALUABLE in quick review is not FAIL
- G8 FI PASS + PKG INCOMPLETE → NEXT_ACTION=COMPLETE_DELIVERY

## AUDIT_MODE_TESTS (6/6)

- M1 QUICK_REVIEW excludes SCIENTIFIC/STATISTICAL
- M2 SCIENTIFIC_FIGURE_AUDIT covers 6 integrity domains
- M3 PUBLICATION_READY includes DELIVERY/GLOBAL_COHERENCE
- M4 FIGURE_INTEGRITY excludes DELIVERY
- M5 PUBLICATION_PACKAGE includes DELIVERY
- M6 warning → PASS_WITH_WARNINGS

## EVIDENCE_AGGREGATION_TESTS (8/8)

- E1 metadata NE + raster PASS → PASS_WITH_LIMITED_EVIDENCE
- E2 metadata PASS + raster contradiction → FAIL
- E3 whole-figure neutral PASS + panel gray MAJOR → COLOR REVISE
- E4 no image evidence → image rule NOT_EVALUABLE
- E5 declarative + raster + vision all PASS → PASS
- E6 PASS + WARNING → WARNING (warning wins)
- E7 empty finding message rejected
- E8 NOT_EVALUABLE excluded from repair routes

## REAL_FIGURE_REGRESSION (18/18)

All 18 assertions on the live A/C/B audits passed (mode inference,
per-domain statuses, COLOR-13/14 final statuses, FIGURE_INTEGRITY,
PUBLICATION_PACKAGE, PUBLICATION_READY, NEXT_ACTION).

## EXISTING SUITES

| Suite | Result | Note |
|---|---|---|
| R1 regression | 12/16 PASS | 4 failures are **pre-existing** (verified identical on R5: valid_complete, prespecified_paired, non_A4_profile, valid_unpaired — color WARNING keeps ready=FALSE in both R5 and R6) |
| R4 regression | FAIL (pre-existing) | same root cause on R5 (verified) |
| Audit regression | 10/10 PASS | |
| Visual Correction regression | 10/10 PASS | |
| Color System regression | 14/14 PASS | incl. COLOR-13/14 behavior |
| R6 behavioral | 24/24 PASS | new |
| R6 real-figure | 18/18 PASS | new |
| Packaging compliance | PASS | validate_skill_package.py |

## NO_REGRESSION

R6 introduces **zero** new failures: every failing legacy check (R1 4x, R4)
fails identically on the unmodified R5 tree. All color/scientific/global
behaviors that passed in R5 still pass.

## STOP CONDITIONS — CHECKED

- C scientific blocker disappeared? NO (still FAIL) ✓
- C COLOR-13 disappeared? NO (still REVISE/MAJOR) ✓
- B scientific PASS disappeared? NO (still PASS) ✓
- B COLOR-13 false positive? NO (PASS) ✓
- PUBLICATION_READY TRUE despite missing delivery? NO (FALSE) ✓
- Color rules modified unnecessarily? NO (only evidence aggregation +
  rule_id propagation + QUICK_REVIEW fallback hook) ✓
- Scientific unit logic changed? NO ✓
- Multiplicity logic changed? NO ✓
- GFS architecture rewritten? NO (only missing-GFS semantics per mode) ✓
- Tests deleted to obtain PASS? NO (new tests added) ✓

## ACCEPTANCE SUMMARY

| Criterion | Status |
|---|---|
| FIGURE_PACKAGE_SEPARATION | PASS |
| AUDIT_MODES (3 modes) | PASS |
| RULE_EVIDENCE_AGGREGATION | PASS |
| DUPLICATE_RULE_REPORTING | ELIMINATED (aggregated_rules) |
| EMPTY_FINDING_MESSAGES | 0 (validator enforced) |
| B_FIGURE_INTEGRITY | PASS |
| B_PUBLICATION_PACKAGE | INCOMPLETE |
| B_PUBLICATION_READY | FALSE |
| C_FIGURE_INTEGRITY | FAIL |
| C_COLOR_13 | MAJOR/REVISE |
| C_PUBLICATION_READY | FALSE |
| A_QUICK_REVIEW | REVISE |
| SCIENTIFIC_LOGIC_REGRESSION | PASS |
| COLOR_LOGIC_REGRESSION | PASS |
| GLOBAL_STATE_REGRESSION | PASS |
| NO_REGRESSION | TRUE (R5-identical legacy failures only) |
