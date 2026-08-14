# Local Change Impact and Dependency-Aware Repair (R4)

## Why this exists

AI figure editing commonly optimizes the visible local defect while forgetting the whole figure. R4 treats every local modification as a state transition with dependencies.

## Change classes

`schemas/impact_dependency_map.tsv` defines the minimum rechecks for these classes:

- `geometry`
- `layout`
- `assembly`
- `colour`
- `typography`
- `legend`
- `scale`
- `data`
- `statistics`
- `claim`
- `panel_role`
- `source_data`
- `unknown`

Unknown changes default to a full global recheck.

## Repair radius

A local change may have a larger repair radius than the target panel.

Examples:

- Change panel C height → recheck panel-area budget, gutters, reading path, hero dominance, thumbnail hierarchy and final canvas occupancy.
- Change a signed colour scale in panel B → recheck figure-level colour architecture, shared legends, panel C direction colours and accessibility.
- Change the statistical unit → recheck scientific audit, claim-evidence logic, affected statistics, source data, annotations and manuscript-facing statements.
- Change one bar chart width → recheck physical consistency with every comparable bar/quantification panel.

## Required log fields

`local_change_log.tsv` uses:

```text
change_id	timestamp	change_type	target_key	reason	impact_scope	required_rechecks	recheck_status	global_state_updated	closed	notes
```

A change is closed only when:

- its `change_type` is recognized or explicitly escalated to full recheck;
- required rechecks cover the dependency map;
- the global state has been updated;
- rerender/review is complete;
- `recheck_status=PASS`;
- `closed=yes`.

## Constraint-preserving repair order

When a local defect is found:

1. diagnose whether the problem is scientific, scale, geometry, colour, typography, assembly or delivery;
2. enumerate at least two plausible repairs for publication/high-impact mode when the first repair could alter global structure;
3. reject repairs that hide data, change statistical meaning, or violate the figure claim;
4. estimate the impact radius;
5. apply the least disruptive repair that improves global coherence;
6. rerender the final assembly, not only the local panel;
7. inspect at intended size and thumbnail size;
8. close the change only after the whole-figure state is consistent.

## Do not overbuild the mechanism

R4 is intentionally a rule-based dependency layer, not a universal optimization solver. It should fail closed on uncertainty instead of inventing a complete dependency graph from pixels alone.
