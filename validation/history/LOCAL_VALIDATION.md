# Local validation — Potato_Figure R4

## A. Fast static check

From the package root:

```bash
python scripts/static_validate.py .
```

Expected:

```text
STATIC_VALIDATION: PASS
```

## B. Frozen R1 regression suite

```bash
Rscript tests/generate_fixtures.R tests/generated
Rscript tests/run_tests.R .
```

Expected final lines include:

```text
Pairing regression: PASS
Visual-domain uniqueness: PASS
TESTS PASS: 16/16 fixtures
```

## C. R4 global-coherence regression suite

```bash
Rscript tests/run_r4_tests.R .
```

Expected:

```text
R4 valid global-state fixture: PASS
R4 unresolved local-change fail-closed regression: PASS
R4 personal-profile coherence regression: PASS
R4 panel-graph regression: PASS
R4 TESTS PASS: 4/4 fixtures
```

## D. Real local figure workflow

For one real figure directory:

1. keep/create `figure_contract.yaml` and add:

```yaml
coherence_mode: global_state
global_state_file: global_figure_state.yaml
global_coherence_qa_file: global_coherence_qa.tsv
global_coherence_status: NOT_REVIEWED
```

2. copy and edit:

```text
schemas/global_figure_state.example.yaml → global_figure_state.yaml
schemas/local_change_log.example.tsv → local_change_log.tsv
schemas/global_coherence_qa_template.tsv → global_coherence_qa.tsv
```

3. before a local repair, append a new change row with `closed=no` and run:

```bash
Rscript scripts/check_change_impact.R /path/to/figure_dir
```

4. after repair, rerender the final assembled figure, update Global Figure State, complete required rechecks, set the change to `closed=yes`, then complete `global_coherence_qa.tsv`.

5. run:

```bash
Rscript scripts/audit_scientific.R /path/to/figure_dir
Rscript scripts/claim_evidence_audit.R /path/to/figure_dir
Rscript scripts/audit_global_coherence.R /path/to/figure_dir
Rscript scripts/qa_delivery.R /path/to/figure_dir
Rscript scripts/evaluate_readiness.R /path/to/figure_dir
```

For single-cell figures also run:

```bash
Rscript scripts/single_cell_audit.R /path/to/figure_dir
```

## E. What to inspect manually

For the first real R4 test, specifically verify that:

- fixing one panel forces whole-figure rereview rather than local-only PASS;
- large nonfunctional whitespace is caught;
- comparable bar/quantification panels keep physically similar mark sizes;
- final-size text is predominantly 8–12 pt under `potato-user-v1`;
- meaningful data do not become grey-dominant by default;
- panel gaps/margins are compact;
- the result reads as one assembled manuscript figure at both full size and 25–30% thumbnail.
