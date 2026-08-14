# Color-System Integration Patch Report — v0.4.1-alpha

Date: 2026-08-11
Base: Potato Figure Audit v0.4.1-alpha
Scope: connect the existing Color System to the product runtime and replace
structural-only checks with behavioral/runtime validation (no new rules)

## What was added

1. **12 formal color rules** (COLOR-01 … COLOR-12) in
   `scripts/lib/color_system_core.R`, each with rule_id / domain / layer /
   description / applies_when / pass / warning / major / not_evaluable /
   evidence / repair.
2. **Three-layer system**:
   - LAYER A UNIVERSAL_COLOR_INTEGRITY (can block PUBLICATION_READY)
   - LAYER B PUBLICATION_COLOR_COHERENCE (WARNING/MAJOR)
   - LAYER C PROFILE_COLOR_PREFERENCES (potato-user-v1, not universal law)
3. **COLOR_SYSTEM_READY vs PROFILE_COLOR_READY separated** — a figure can be
   scientifically color-correct while failing the personal profile, and vice
   versa. This prevents personal aesthetics being packaged as a universal
   journal standard.
4. **Raster color metrics** (only on RASTER_REVIEW): neutral/chromatic ink
   fractions, accent area, mean and per-panel saturation, palette cluster
   count, and panel-palette similarity — with white background excluded
   (INK PIXELS = non-white). Measured values carry
   measurement_method / thresholds / resolution.
5. **Vision-model qualitative guard**: VISION_MODEL_REVIEW may output
   qualitative judgments (gray dominance, palette fragmentation) but never
   invented pixel percentages; only real raster analysis may report numbers.
6. **Metadata-only fail-closed**: COLOR-04/05/09/10/11 → NOT_EVALUABLE
   without image evidence (never image-color PASS from metadata).
7. **GFS color_state** schema: semantic_palette / continuous_palettes /
   categorical_palettes / neutral_roles / hero_accent / panel_palette_map /
   consistency / accessibility / evidence_source. Local color edits trigger
   global recheck (COLOR-01/03/05/11 + GLOBAL_COHERENCE).
8. **potato-user-v1 color_profile**: white background, blue/coral semantic
   pair, gray roles limited to structure, `max_neutral_ink_fraction: 0.70`
   explicitly marked PROFILE_HEURISTIC (not universal threshold).

## Validation

| Suite | Result |
|---|---|
| Static (clean release tree) | 83/83 PASS |
| R1 regression | 16/16 PASS |
| R4 regression | 4/4 PASS |
| Audit regression | 10/10 PASS |
| Visual correction regression | 10/10 PASS |
| **Color behavioral/runtime tests (C1–C14)** | **14/14 PASS** |

C1–C14 execute real fixture inputs and assert emitted findings/statuses. They
cover semantic consistency and drift, gray dominance, accent hierarchy,
diverging scales, colorblindness, grayscale fail-closed behavior, text
contrast, saturation, hero salience, rejection of invented Vision fractions,
Raster cross-panel measurements, and propagation through the main Audit,
Readiness, and Visual Correction Brief.

## Evidence correction in the frozen v0.4.1-alpha baseline

R2 no longer treats missing `neutral_roles` metadata as proof that an image is
gray-dominant. `COLOR-04 MAJOR` now requires either an explicit structured
Vision/Manual observation or Raster measurement. Missing observations remain
`NOT_EVALUABLE`.

## Readiness semantics

- Universal color integrity (A): BLOCKER/MAJOR can block PUBLICATION_READY
  (e.g., COLOR-02 false meaning, COLOR-06 wrong signed scale).
- Publication coherence (B): severe MAJOR can block; mild WARNING does not.
- Profile preference (C): never blocks scientific readiness; reported as
  PROFILE_COLOR_READY separately.

## No-regression

NO_REGRESSION = TRUE (all prior suites pass unchanged; no expected results
were altered).

## Files changed/added

- scripts/lib/color_system_core.R (new)
- scripts/audit_color_system.R (new)
- tests/run_color_system_tests.R (new, 14 cases)
- profiles/potato-user-v1.yaml (color_profile added)
- schemas/color_state.schema.md (new)
- CHANGELOG.md / README.md / SKILL.md / RUNTIME_VALIDATION_REPORT.md
