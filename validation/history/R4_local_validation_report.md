# Historical R4 Local Validation Report (not v0.4.1 R2 release evidence)

Date: 2026-08-09
Validator: independent local run (DeepSeek)

## Environment

| Item | Value |
|---|---|
| OS | Microsoft Windows NT 10.0.26200.0 |
| R | 4.6.1 (2026-06-24 ucrt) |
| Python | 3.12.10 |
| git | 2.55.0.windows.3 |
| Working directory | `<workspace>/Potato_Figure_R4_local_validation/potato-figure-v0.2-R4-global-coherence` |

## Integrity

- ZIP: `potato-figure-v0.2-R4-global-coherence.zip` (1,441,427 bytes)
- **SHA256: `55737F8409837571BEBFE4AF43310B9BD869DAE3EE08333444AFC0E7B1153EA4`**
- No companion `.sha256` file shipped → comparison not applicable; hash recorded for provenance.

## Static validation (independent)

```
STATIC_VALIDATION passes=85 warnings=0 errors=0
STATIC_VALIDATION: PASS
```
(package's own R4_static_validation_report.md used as reference only; this run is independent)

## R1 regression

`Rscript tests/run_tests.R .` → **16/16 PASS**
Coverage confirmed intact: pseudoreplication, multiplicity, pairing consistency
(paired rank-sum / unpaired signed-rank mismatch), missing source data,
incomplete exports, A4 conditional logic, delivery metadata row, visual
PASS/REVISE/FAIL interface, duplicate visual domain conflict.

## R4 regression

`Rscript tests/run_r4_tests.R .` → **4/4 PASS**
1. valid global state → PASS
2. open local change → fail-closed / NOT_READY
3. visual profile violation → REVISE
4. hero/panel-graph inconsistency → FAIL

## Global Figure State — PASS

`audit_global_coherence.R` on r4_valid_global → **14/14 PASS**:
required fields, panel tags unique, reading order valid, hero in panel graph,
single-canvas assembly, potato-user-v1 typography/occupancy/gap/margin budgets,
local change closure, global manual QA interface.

State is NOT a documentation-only artefact: it is parsed and enforced by
`global_coherence_core.R` (required_global_state_fields, global_qa_domains,
run_impact_audit, read_global_manual_qa).

## Dependency propagation — PASS (5 live cases, each both directions)

| Case | Change | Required rechecks enforced | Result |
|---|---|---|---|
| A | Panel C height (geometry) | geometry;assembly;reading_order;thumbnail;canvas_occupancy | correct→PASS; missing any→**FAIL** |
| B | Panel B colour scale | colour_architecture;legend;accessibility;thumbnail | correct→PASS; missing→**FAIL** |
| C | statistical unit cell→patient | scientific_integrity;claim_evidence;annotations;source_data | correct→PASS; missing source_data→**FAIL** |
| D | remove redundant panel (panel_role) | panel_roles;reading_order;hero;geometry;assembly | PASS |
| E | add UMAP panel (unknown) | full_global_recheck + closure required | open→**FAIL** |

Impact mechanism is dependency-map-driven (`impact_dependency_map.tsv`, 13
change types, unknown → full_global_recheck), NOT "rerun everything" and NOT
"check only the edited panel".

## Fail-closed — PASS

- `closed=no` → FAIL (CASE E)
- `recheck_status=NOT_REVIEWED` + `global_state_updated=no` even with
  `closed=yes` → **FAIL** (dedicated case)
- No path found where an unresolved local change yields publication-ready.

## potato-user-v1 — PASS

- Profile independently defined (`profiles/potato-user-v1.yaml`), not baked
  into universal core: dense-but-readable, low whitespace, matched
  quantitative geometry, 8–12 pt body, compact gaps, hero/support area by
  evidence weight, restrained-but-alive colour, one-figure assembly.
- Typography outside 8–12 pt → `potato_profile_typography` WARNING (REVISE).

## Single-cell real regression — PASS

GSE130116-style 4-panel benchmark state (a UMAP landscape / b paired
trajectories hero / c change heatmap / d inference) with the real issue
"panel d whitespace too large, compress it":
- Old behaviour would compress panel d only.
- R4: change registered as geometry; requires rechecks of
  geometry/assembly/reading_order/thumbnail/canvas_occupancy; `closed=no`
  → **FAIL** (CHG_D_height unresolved). The system knows editing panel d
  means editing the whole figure.

## Non-single-cell smoke test — PASS

Synthetic clinical figure (treatment response, patient unit, DESCRIPTIVE /
SAMPLE_LEVEL_QUANTITATIVE / INFERENTIAL evidence classes) ran through
audit_global_coherence.R → **11 PASS + 1 WARNING** (global QA table not yet
filled, expected for synthetic). No single-cell assumption leaked into the
core: UMAP/DotPlot/pseudobulk are not required anywhere in the universal path.

## Core + Adapter boundary — PASS

- SKILL.md L43: core modality-agnostic; L242 §7 "Single-cell adapter boundary";
  L246 "must not be injected into unrelated"; L315 "Do not treat a single-cell
  grammar as the universal core".
- `references/figure-grammar-core.md` + `references/grammars/single-cell.md`
  implement the adapter pattern; other grammar slots reserved.

## Regressions found

None blocking. Observed notes (not failures):
- `grammars/` contains only single-cell.md (others are placeholders by design).
- Clinical smoke test global-QA WARNING is expected (no render performed).
- `impact_dependency_map.tsv` treats novel change types as full_global_recheck
  (conservative, intended).

## Files changed

None. This was a read-only validation; no fixes were required.

## Final verdict

**R4_LOCAL_VALIDATION = PASS**

Gate summary:

```
STATIC = PASS
R1_TESTS = 16/16
R4_TESTS = 4/4
GLOBAL_STATE = PASS
IMPACT_PROPAGATION = PASS
FAIL_CLOSED = PASS
UNIVERSAL_SMOKE = PASS
VISUAL_PROFILE = PASS
R4_LOCAL_VALIDATION = PASS
```

The central question is answered affirmatively: **when R4 edits Panel C (or
any panel), it knows it is editing the whole figure** — dependency-map-driven
repair radius, enforced global rechecks, and fail-closed closure semantics are
implemented and verified live, not merely documented.
