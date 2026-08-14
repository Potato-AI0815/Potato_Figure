# Readiness Policy (v0.4.3-alpha, A9)

## Three distinct states

| State | Meaning | Example |
|---|---|---|
| `AUDIT_COMPLETED` | The audit tool ran to completion | always TRUE when the tool exits |
| `AUDIT_COVERAGE` | Every publication-critical domain had sufficient material/evidence to evaluate | COMPLETE / INCOMPLETE |
| `PUBLICATION_READY` | The figure may be submitted | TRUE / FALSE |

## Coverage rule

Publication-critical domains: SCIENTIFIC, STATISTICAL, CLAIM_EVIDENCE,
PANEL_ARCHITECTURE, GLOBAL_COHERENCE, VISUAL, COLOR, DELIVERY.

- Missing material → domain `NOT_EVALUABLE`, never fabricated.
- Missing material is not automatically FAIL unless required for the stated
  publication-readiness claim.
- `NOT_EVALUABLE` is never disguised as PASS.

## Readiness rule

```
PUBLICATION_READY = TRUE
  only if ALL publication-critical domains are PASS
  (INFO/MINOR findings allowed)

any FAIL / BLOCKER
any unresolved MAJOR / REVISE
any critical NOT_EVALUABLE
→ PUBLICATION_READY != TRUE
```

## Worked examples

Only PNG supplied:

```
VISUAL             = NOT_EVALUABLE (no image review evidence, A5)
SCIENTIFIC         = NOT_EVALUABLE
STATISTICAL        = NOT_EVALUABLE
CLAIM_EVIDENCE     = NOT_EVALUABLE
COLOR              = NOT_EVALUABLE
AUDIT_COMPLETED    = TRUE
AUDIT_COVERAGE     = INCOMPLETE
PUBLICATION_READY  = FALSE
```

Full delivery with visual_qa.tsv all PASS + real review source:

```
all domains        = PASS
AUDIT_COMPLETED    = TRUE
AUDIT_COVERAGE     = COMPLETE
PUBLICATION_READY  = TRUE
```

## Visual evidence gate (A5)

`visual_evidence_source` must be a real review type
(RASTER_REVIEW / VECTOR_REVIEW / VISION_MODEL_REVIEW / MANUAL_REVIEW).
METADATA_ONLY / NONE → `VISUAL_IMAGE_REVIEW = NOT_EVALUABLE` — a
`visual_qa.tsv` that claims PASS without actual inspection is not accepted.

## Exit codes

`Rscript scripts/evaluate_readiness.R <dir> [--json]`
- 0 = PUBLICATION_READY TRUE
- 1 = not ready
