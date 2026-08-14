# Migration Report — R4 → Potato Figure Audit v0.3.0-alpha

Date: 2026-08-10
Scope: product repositioning from "figure generation + audit" to
       "independent figure audit / integrity layer"

## Summary of changes

| Area | R4 (before) | v0.3.0 (after) |
|---|---|---|
| Product identity | figure compiler + integrity system | independent figure **audit** / integrity layer |
| SKILL name | potato-figure | **potato-figure-audit** |
| SKILL description | "General biomedical scientific Figure compiler and integrity system" | "Independent scientific figure auditing for biomedical research…" |
| Main entry | per-layer scripts | **`scripts/audit_figure.R`** (orchestrates 9 layers, severity, report+JSON) |
| Rendering | themes + layout candidates were product claims | demoted to **legacy optional helpers** (`themes/`, art-direction references) |
| Generator | R-only rendering assumption | **generator-agnostic** (R/Python/Prism/Illustrator/AI/Nature-Figure) |
| Output | per-layer reports | `figure_audit_report.md` + `figure_audit.json` + optional TSVs, with **severity** (BLOCKER/MAJOR/MINOR/INFO) |
| Readiness | single PASS/FAIL | **per-domain gate** (SCIENTIFIC/STATISTICAL/CLAIM_EVIDENCE/PANEL_ARCHITECTURE/GLOBAL_COHERENCE/VISUAL/DELIVERY) + fail-closed |
| NOT_EVALUABLE | partial | disciplined: missing input → NOT_EVALUABLE, never fabricated, never disguised as PASS |
| Repair | implied | explicit recommendations with **upstream_owner** (STATISTICS/ANALYSIS/FIGURE_GENERATOR/MANUSCRIPT/MANUAL_REVIEW); no auto-modify |
| Tests | R1 16 + R4 4 | R1 16 + R4 4 + **AUDIT 10** (new) |

## What was preserved (frozen, not weakened)

- Scientific Integrity Audit (R1 core)
- Claim–Evidence Audit (R2.12)
- Statistical-unit / pairing / multiplicity / Source Data rules (R1)
- Global Figure State + Local Change Impact + Impact Dependency Map +
  fail-closed (R4)
- Global Coherence Audit (R4)
- Delivery & Reproducibility QA (R1)
- Visual QA interface (R2) + potato-user-v1 profile (R4)

## What was removed / demoted

See `DEPRECATED_FEATURES.md` for the full list. Highlights:

- "figure generator / compiler / rendering system / art-direction engine /
  Nature-style generator / automatic multipanel generation" removed from
  product positioning.
- `themes/`, `profiles/a4-working|high-impact-omics|journal-final`,
  art-direction references demoted to legacy helpers.

## Boundary changes

- Explicit boundaries with nature-statistics / nature-figure / paper-spine
  documented in `PRODUCT_BOUNDARY.md`.
- Potato Figure Audit works standalone (no Nature dependency).

## Test compatibility

- R1 regression (16/16) unchanged — frozen layer untouched.
- R4 regression (4/4) unchanged — global coherence machinery untouched.
- New AUDIT regression (10/10) added:
  1. valid figure → PASS
  2. cell-level pseudoreplication → BLOCKER/FAIL
  3. paired data + unpaired test → FAIL
  4. UMAP supports causal claim → CLAIM_EVIDENCE FAIL
  5. redundant panels → PANEL_ARCHITECTURE REVISE
  6. local fix breaks hierarchy → GLOBAL_COHERENCE FAIL
  7. beautiful figure missing Source Data → DELIVERY REVISE (not Scientific FAIL)
  8. only PNG → visual evaluable, statistics NOT_EVALUABLE
  9. potato-user-v1 whitespace violation → VISUAL REVISE (not Scientific FAIL)
  10. all gates satisfied → PUBLICATION_READY TRUE

No expected results were altered to make tests pass; where a fixture was
incomplete (case 1/10), the fixture itself was completed to represent a
genuinely valid figure.
