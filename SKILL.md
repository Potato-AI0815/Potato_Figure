---
name: potato-figure-audit
description: >
  Independent scientific, statistical, visual, and reproducibility audit for
  biomedical figures, with profile-driven visual correction briefs. Covers
  statistical-unit integrity, claim–evidence alignment, panel architecture,
  global coherence, evidence-disciplined color-system QA, visual QA, and
  reproducible delivery. Audit only —
  does not generate, render, or redraw figures. Works with any figure
  generator (R, Python, GraphPad Prism, Nature-Figure, Illustrator, AI).
  Triggers: review my figure, audit this figure, check scientific figure,
  figure QA, publication figure review, check statistics in figure,
  check panel logic, does this figure support the conclusion,
  投稿前检查图片, 审查科研图, 检查 Figure, 图有没有统计问题, panel 是否合理,
  这图为什么不好看, 怎么改这张图, visual correction.
license: MIT
---

# Potato Figure Audit

**Independent scientific, statistical, visual, and reproducibility audit
for biomedical figures, with profile-driven visual correction briefs.**

Potato Figure Audit does **not** replace Nature-Figure, ggplot2, matplotlib,
GraphPad Prism, Illustrator, or any other plotting tool. It audits figures
that already exist (or are about to be finalised) and, when a figure needs
visual work, it emits a **Visual Correction Brief** — structured "why it is
wrong, what to change, what must not break" instructions handed to the
upstream generator or a human.

## Runtime requirements

Requires R for the core audit scripts. Raster color measurement additionally
requires Python with Pillow and NumPy and the R `jsonlite` package.
If a Python interpreter is not on `PATH`, set `POTATO_PYTHON` to the Python
executable; if raster dependencies are unavailable, pixel-derived checks must
return NOT_EVALUABLE rather than silently PASS.

## Audit modes (R6)

Three audit modes decide how much evidence is required and what the verdict
means. The auditor auto-selects, and `--mode` overrides:

| Mode | When to use | What is evaluated | Missing material |
|---|---|---|---|
| `QUICK_REVIEW` | Only a figure image is available ("帮我看看这张图") | VISUAL, COLOR, PANEL_ARCHITECTURE (from the image itself) | SCIENTIFIC/STATISTICAL → NOT_EVALUABLE (never fabricated) |
| `SCIENTIFIC_FIGURE_AUDIT` (default) | figure + manifest + statistical metadata ("审查这张科研图统计和科学性") | SCIENTIFIC, STATISTICAL, CLAIM_EVIDENCE, PANEL_ARCHITECTURE, VISUAL, COLOR → **FIGURE_INTEGRITY** | GFS/delivery missing → NOT_EVALUABLE / INCOMPLETE, not a figure FAIL |
| `PUBLICATION_READY` | "能否投稿 / publication ready?" | all domains, fail-closed → **PUBLICATION_READY** | GFS/session/delivery missing → BLOCKER / INCOMPLETE → NOT READY |

Selection logic: image only → QUICK_REVIEW; manifest present →
SCIENTIFIC_FIGURE_AUDIT; explicit `--mode PUBLICATION_READY` or
`audit_mode:` in the contract → that mode.

**Gate semantics (R6).** The report separates two different questions:

- `FIGURE_INTEGRITY` — is this figure scientifically/statistically/visually
  sound? (SCIENTIFIC, STATISTICAL, CLAIM_EVIDENCE, PANEL_ARCHITECTURE,
  VISUAL, COLOR)
- `PUBLICATION_PACKAGE` — is the submission package complete?
  (GLOBAL_COHERENCE, DELIVERY, SOURCE_DATA, EXPORT_FORMATS,
  DELIVERY_METADATA, SESSION_METADATA, PROVENANCE, REPRODUCIBILITY)
- `PUBLICATION_READY` — both PASS (strictest, fail-closed).

Missing delivery material (PDF/SVG/TIFF, metadata) is **INCOMPLETE**, never
a claim that the figure is scientifically invalid. Declared-but-wrong
material (hash mismatch, DPI contradiction) is **FAIL**.

**Rule evidence aggregation.** A rule may receive evidence from multiple
sources (declarative/raster/vision). The report shows one final status per
rule: confirmed contradiction > missing evidence > supportive evidence.
Example: COLOR-03 declarative NOT_EVALUABLE + raster PASS →
`PASS_WITH_LIMITED_EVIDENCE`.

**Warning semantics (R6.1).** Non-blocking warnings do not automatically
make a figure unready. `PASS_WITH_WARNINGS`/`PASS_WITH_LIMITED_EVIDENCE`
map to a non-blocking `WARNING` at the domain/readiness level.
MAJOR/REVISE/FAIL and required critical NOT_EVALUABLE remain fail-closed.

**Machine contract (R6.1).** `figure_audit.json` is the single machine
source of truth. Downstream consumers MUST read the tiered contract, not
the legacy flat verdict:

```
figure_integrity.status          PASS | PASS_WITH_WARNINGS | REVISE |
                                 FAIL | NOT_EVALUABLE
publication_package.status       PASS | INCOMPLETE | FAIL | NOT_EVALUABLE
publication_ready                true | false   (fail-closed)
repair_routes.NEXT_ACTION        COMPLETE_DELIVERY | REVISE_FIGURE |
                                 RETURN_TO_STATISTICS | RETURN_TO_CLAIM_EVIDENCE |
                                 FIX_DELIVERY | HUMAN_REVIEW_REQUIRED | NONE
audited_artifacts                freshness binding: {"rel/path": {"sha256", "bytes"}}
                                 for every audited input file (audit outputs
                                 excluded); consumers MUST recompute and treat
                                 any mismatch/missing file as AUDIT_STALE
contract_version                 "R6.1"
version                          skill version, e.g. "0.4.3-alpha"
```

Legacy flat fields (`verdict`, `figure_integrity_legacy`,
`publication_package_legacy`, `domain_status`) are still emitted for
backward compatibility only; new consumers must not depend on them.

## Pipeline position

```
UPSTREAM
data analysis / statistics
        ↓
any Figure generator
(R / Python / Prism / Illustrator / AI / Nature-Figure)
        ↓
Potato Figure Audit   ← generator-agnostic, audit only
        ↓
PASS / REVISE / FAIL
        ↓
Visual Correction Brief (when REVISE)
        ↓
generator / human revision
        ↓
re-audit
```

## Boundaries

- **Nature-Statistics**: statistical analysis and design itself.
- **Nature-Figure**: figure generation / rendering / layout.
- **Potato Figure Audit**: independent review of generated results.
- **Paper-Spine**: whole-manuscript narrative / figure-to-text spine.

Potato Figure Audit must also work standalone. It must not require the
Nature suite.

## Core principle

> **Your figure is finished. Is it actually defensible?**

The product difference is not "we draw more beautifully than Nature-Figure".
It is:

> **After Nature-Figure (or any tool) has drawn it, we tell you whether
> the figure actually holds up.**

## Audit layers

The audit core is **modality-agnostic**. Single-cell, bulk-omics, clinical,
survival, IHC, WB, and imaging figures are all audited by the same universal
rules; modality-specific checklists (e.g., the single-cell adapter:
cells ≠ biological n, UMAP is context evidence) are applied as adapters on
top of the universal core, never instead of it.

1. **Input Audit** — inventory supplied materials (final figure, panels,
   legend, Results text, source data, statistical metadata, sample metadata,
   manifest, before/after pair, journal requirements). Missing material is
   reported as `NOT_EVALUABLE`, never fabricated, never auto-FAIL unless the
   claim is publication-ready without it.
2. **Scientific Integrity Audit** — statistical unit, biological vs
   technical replicate, cell ≠ biological sample, ROI ≠ patient,
   field ≠ animal, pseudoreplication, pairing, sample size, effect
   direction, denominator, group identity, descriptive vs inferential.
3. **Statistical Consistency Audit** — declared statistics vs design/metadata:
   paired design with unpaired test; n vs Source Data; P/q/FDR labelling;
   multiplicity applicability; CI/effect/test mismatch; inferential unit vs
   plot point unit. Does **not** choose "optimal" statistical methods;
   `NOT_EVALUABLE`/`REVIEW_REQUIRED` when uncertain.
4. **Claim–Evidence Audit** — per panel: claim, evidence_role, evidence_type,
   statistical_unit, source_data, supports_claim, overclaim_risk, redundancy.
   UMAP/descriptive views are context evidence; they cannot by themselves
   support "significantly reversed" claims.
5. **Panel Architecture Audit** — figure-level: panel independence,
   redundancy, hero clarity, supporting role, narrative order A→B→C→D,
   evidence hierarchy. Outputs recommendations (KEEP/MERGE/REMOVE/REORDER/
   RESIZE/REVISE) — recommendations only, never auto-redraw.
6. **Global Coherence Audit** — R4 Global Figure State, Local Change Log,
   Impact Dependency Map, fail-closed rule: **local fix ≠ global
   improvement**; every local change is checked for global impact
   (area budget, hero/support hierarchy, alignment, reading order, canvas,
   shared scale, legend, typography, colour). Before/after pairs trigger a
   CHANGE IMPACT AUDIT.
7. **Visual Integrity Audit** — two tracks:
   - *Universal*: clipping, unreadable labels, overlap, inconsistent
     typography, distorted aspect, inappropriate scale, legend ambiguity,
     excessive unexplained whitespace, inaccessible colour distinction,
     panel alignment, export resolution, raster/vector suitability.
   - *User profile* (`potato-user-v1`): personal preferences (density,
     whitespace, composition, 8–12 pt, bar widths, palette). A profile
     violation is a REVISE, not a scientific FAIL.
8. **Color System Audit** — execute `COLOR-01`–`COLOR-12` inside the main
   audit. Separate universal, publication, and profile layers. Treat Color as
   a publication-critical readiness gate and propagate actionable findings to
   the Visual Correction Brief. Panel-level raster measurement
   (`raster_panel_metrics`, grid "2x2"/bbox/auto) detects **locally
   gray-dominant panels** even when the full-figure average is within
   heuristic — a panel with neutral_fraction > 0.80 and sufficient ink
   triggers COLOR-04 MAJOR (average can mask local gray). Declare
   `color_state.panel_grid` (e.g., "2x2") or `color_state.panel_bboxes` in
   GFS for accurate panel partitioning.
9. **Delivery & Reproducibility Audit** — panel source data, manifest,
   statistical metadata, n, plotting parameters, dimensions, formats,
   resolution, provenance, version, session info, source-data linkage.
10. **Publication Readiness Gate** — reports at least: SCIENTIFIC,
   STATISTICAL, CLAIM_EVIDENCE, PANEL_ARCHITECTURE, GLOBAL_COHERENCE,
   VISUAL, COLOR, DELIVERY. `PUBLICATION_READY = FALSE` on any blocking FAIL;
   unresolved REVISE defaults to FALSE; NOT_EVALUABLE is never disguised as
   PASS.

## Severity

Every finding carries: **BLOCKER / MAJOR / MINOR / INFO**

- BLOCKER: pseudoreplication, overclaim, paired/unpaired contradiction
- MAJOR: claim exceeds evidence, unpaired statistics on paired design
- MINOR: legend dispersion, readability nudge
- INFO: suggestion (e.g., reduce panel gap)

Reports prioritise **Top Blockers** and **Top Major Issues** — never a
flat 50-line checklist.

## Repair recommendations, not auto-repair

Each issue reports: issue / why_it_matters / affected_panels / severity /
recommended_action / upstream_owner (STATISTICS | ANALYSIS |
FIGURE_GENERATOR | MANUSCRIPT | MANUAL_REVIEW).

Potato Figure Audit never silently modifies data or redraws figures.

## Potato Visual Correction Mode (v0.4)

When the audit result is REVISE (or the user asks "why is this figure ugly /
how should I fix it"), generate a **Visual Correction Brief**:

- `visual_correction_brief.yaml` (machine-readable)
- `visual_correction_brief.md` (human-readable)

Every brief issue carries:

```
issue_id, priority, severity, domain, affected_panels,
diagnosis, why_it_matters, recommended_action,
preserve_constraints, global_recheck, upstream_owner,
confidence, evaluation_source
```

`evaluation_source` ∈ {IMAGE_REVIEW, METADATA, PROFILE, MANUAL,
NOT_EVALUABLE}. `upstream_owner` routes the fix to the right place
(FIGURE_GENERATOR / STATISTICS / ANALYSIS / MANUSCRIPT / MANUAL_REVIEW).

**Local fix ≠ global improvement (R4 rule preserved):** every correction
must declare `global_recheck` (reading order, canvas utilization, panel
balance, typography, legend, colour).

```bash
Rscript scripts/generate_visual_correction_brief.R <figure_dir> --source RASTER_REVIEW
Rscript scripts/generate_visual_correction_brief.R <figure_dir> --source VISION_MODEL_REVIEW
```

## Visual evidence discipline (v0.4, A5)

`visual_evidence_source` ∈ {RASTER_REVIEW, VECTOR_REVIEW,
VISION_MODEL_REVIEW, MANUAL_REVIEW, METADATA_ONLY, NONE}.

- METADATA_ONLY / NONE → `VISUAL_IMAGE_REVIEW = NOT_EVALUABLE` — never PASS.
- A `visual_qa.tsv` claiming PASS without actual image inspection is not
  accepted as image review.
- Qualitative vision review ≠ measured geometry: never report pixel-exact
  numbers (e.g., "blank fraction = 13.24%") unless a real pixel measurement
  was performed.

For `VISION_MODEL_REVIEW` or `MANUAL_REVIEW`, record only structured
qualitative observations in `figure_contract.yaml`:

```yaml
color_review.primary_evidence_gray_dominant: true|false
color_review.semantic_contrast_exists: true|false
color_review.accent_hierarchy: good|weak
color_review.grayscale_redundancy: pass|fail
color_review.text_background_contrast: pass|fail
color_review.saturation_balance: balanced|over|under
color_review.hero_salience: high|low
color_review.confidence: high|medium|low
```

Do not infer gray dominance from a missing `neutral_roles` declaration. Do not
accept numerical fractions from Vision/Manual review. Only `RASTER_REVIEW` may
emit measured neutral/chromatic/accent fractions, mean saturation, palette
cluster count, per-panel saturation, and panel-palette similarity.
Raster measurement requires Python with Pillow and NumPy plus the R `jsonlite`
package. If `python` is not on `PATH`, set `POTATO_PYTHON` to the Python
executable; otherwise keep pixel-derived rules `NOT_EVALUABLE`.

## Readiness discipline (v0.4, A9)

Three separate states:

- `AUDIT_COMPLETED` — the audit itself ran (always true when the tool runs).
- `AUDIT_COVERAGE` — whether all publication-critical domains had enough
  material/evidence to evaluate (COMPLETE / INCOMPLETE).
- `PUBLICATION_READY` — TRUE only when every publication-critical domain is
  PASS (INFO/MINOR allowed). Any FAIL, BLOCKER, unresolved MAJOR/REVISE, or
  critical NOT_EVALUABLE → not TRUE.

```bash
Rscript scripts/evaluate_readiness.R <figure_dir> [--json]
```

## Usage

```bash
# audit a figure delivery directory
Rscript scripts/audit_figure.R <figure_dir>

# machine-readable output
Rscript scripts/audit_figure.R <figure_dir> --json

# custom report path
Rscript scripts/audit_figure.R <figure_dir> --report my_audit.md
```

Outputs: `figure_audit_report.md` (human), `figure_audit.json` (machine).
The main entrypoint automatically runs the Color System auditor; do not require
users to invoke `audit_color_system.R` separately.
Optional per-layer TSVs: panel_audit / claim_evidence_matrix /
statistical_consistency / global_coherence_audit / delivery_audit /
change_impact.

Exit code contract (v0.4.3-alpha):

- `QUICK_REVIEW` / `SCIENTIFIC_FIGURE_AUDIT`: exit 0 = audit executed
  successfully (the verdict itself — PASS/WARNING/REVISE/FAIL — does not
  change the exit code; read `figure_audit.json`).
- `PUBLICATION_READY`: exit 0 = gate passed (`publication_ready = true`);
  exit 2 = audit completed but the gate is not satisfied.
- All modes: exit 3 = invalid input or contract error (directory missing,
  illegal `--mode`); exit 4 = internal execution error.

## Frozen audit capabilities (preserved from R4)

Scientific Integrity · Claim–Evidence · Statistical-unit consistency ·
Pairing consistency · Multiplicity declaration · Source Data integrity ·
Global Figure State · Local Change Impact · Global Coherence · Visual QA ·
Delivery/Reproducibility QA · Fail-closed publication readiness.

Regression suites: `tests/run_tests.R` (R1, 16 fixtures),
`tests/run_r4_tests.R` (R4, 4 fixtures),
`tests/run_audit_tests.R` (v0.3 audit, 10 fixtures),
`tests/run_color_system_tests.R` (v0.4.1-alpha, 14 behavioral/runtime cases),
`tests/run_r6_tests.R` (R6 gate semantics and report consolidation),
`tests/run_r6_real_regression.R` (R6 three-tier semantics on synthetic data),
`tests/run_warning_semantics_tests.R` (R6.1 warning semantics + fail-closed blocking),
`tests/run_raster_security_tests.R` (raster path-injection security, 7 cases),
`tests/run_main_entry_tests.R` (v0.4.3-alpha main-entry exit codes + JSON contract),
`tests/run_binding_serializer_tests.R` (SHA-256 vectors, serializer escaping,
audited_artifacts freshness binding, 23 checks),
`tests/run_visual_correction_tests.R` (visual correction brief contract).

Release validation: `scripts/run_release_validation.R` runs all suites plus
the packaging validator and writes `validation/latest_validation.json` —
the single machine source of release evidence. `TEST_MATRIX.tsv` and
`RUNTIME_VALIDATION_REPORT.md` are auto-generated from that JSON by
`scripts/generate_validation_report.R`; hand edits are invalid.

## Legacy helpers

Themes/rendering helpers under `themes/` and older references
(`visual-art-direction.md`, `layout-candidate-selection.md`,
`global-colour-architecture.md`) are retained as **legacy optional
helpers / examples**. They are not part of the audit core and must not be
advertised as the product.
