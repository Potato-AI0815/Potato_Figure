# Visual Target Contract (R2.1–R2.3)

## R2.1 — Visual target levels

Every figure declares exactly one `visual_target`:

| Level | Requirement | Allowed profiles |
|---|---|---|
| `baseline` | Clean, readable, scientifically correct; internal analysis/report use | any |
| `publication` | Clear hierarchy, no overlap/clipping, sound typography, colour, density; regular journal figure | any |
| `high_impact` | All of publication, PLUS: identifiable hero evidence, non-mechanical asymmetric layout, strong evidence hierarchy, thumbnail reading path, reference/profile fidelity, high information density | **user-approved visual profile** or **explicit reference-first art direction** only |

Rules:
- `generic-accessible` supports `baseline` and `publication` ONLY.
- A `generic-accessible` Visual QA PASS must NEVER be claimed as high-impact visual validation.
- `high_impact` must cite either a user-approved profile id or a reference-first art-direction statement. "Nature style" may not be invented ad hoc.

## R2.2 — Visual hard-failure / revise rules

Inspection evidence fields (record in `visual_qa.tsv` as `domain` rows with `status`):

| Evidence field | yes → status |
|---|---|
| `text_clipping` | **FAIL** |
| `text_overlap` | **REVISE** (minimum) |
| `axis_label_collision` | **REVISE** |
| `facet_overcrowding` | **REVISE** |
| `legend_collision` | **REVISE** |
| `dominant_empty_space` | **REVISE** |
| `panel_area_evidence_mismatch` | **REVISE** |
| `hero_identifiable` (no) | **REVISE** |
| `thumbnail_readable` (no) | **REVISE** |
| `repeated_redundant_panels` (yes) | **REVISE** |

Hard prohibitions (Visual PASS is forbidden when any holds):
- labels visibly overlap
- labels are clipped
- panel text unreadable at intended size
- one panel contains large unused area without evidence role
- multiple tiny facets unreadable
- title/subtitle visually dominates evidence
- no identifiable hero panel under `publication`/`high_impact` target

Inspection must record **evidence**, not just conclusions: for each non-PASS
domain, state what was observed (e.g., "facet strip label 'CD79A' clipped at
right edge", "Panel C occupies 40% but carries no independent evidence").

## R2.3 — Render-based Visual QA

Visual QA happens ONLY on the rendered raster preview. Workflow:

```
render
→ open raster preview
→ inspect at full intended size
→ inspect at 25–30% thumbnail
→ record hard visual defects
→ score visual domains
→ derive VISUAL_STATUS
```

Required record block (in `figure_contract.yaml` under `visual_review`):

```yaml
visual_review:
  render_file: <path>
  reviewed_full_size: yes/no
  reviewed_thumbnail: yes/no
  reviewer: <name/agent>
  defects: <list>
  revision_count: <int>
```

If full-size + thumbnail review did not both happen:
`VISUAL_STATUS = NOT_REVIEWED` (never PASS).

## R2.3b — Typography / density checks (R2.9)

Automatic/human checks:
- no axis text collision
- no clipped statistics
- no facet strip dominating data region
- minimum effective plot area per facet
- no unreadable multi-facet arrangement

When facets crowd: prefer reduce panels / change grammar / reshape layout /
direct labels / move full set to supplement. **First response must NOT be
repeatedly shrinking fonts.**

## R2.8 — Effect panel colour semantics

- individual patient observations: neutral/light grey OR stable patient identity colours
- summary/effect marker: direction-aware profile colour; positive and negative MUST have defined semantics
- nonsignificance ≠ "grey out the whole panel"
- significance is a statistical annotation; effect direction is visual semantics — do not conflate
- if all q > 0.05: still show true effect direction, annotate q/FDR status, never imply significance by colour
