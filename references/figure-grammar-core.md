# Figure Grammar Core

Potato_Figure is a general scientific figure system. The core reasons about evidence; modality adapters provide domain-specific plot grammar and error rules.

## Universal evidence classes

- `CONTEXT_OR_LANDSCAPE`
- `DESCRIPTIVE`
- `IDENTITY_OR_CHARACTERIZATION`
- `SAMPLE_LEVEL_QUANTITATIVE`
- `INFERENTIAL`
- `IMAGE_EVIDENCE`
- `MECHANISTIC`
- `VALIDATION`
- `OTHER`

The central claim determines what evidence level is required. A descriptive panel must not silently satisfy an inferential claim.

## Core routing

1. identify modality;
2. identify central claim and statistical unit;
3. classify available evidence;
4. choose a modality grammar;
5. assign each panel one question, one role and unique information;
6. assemble panels under the Global Figure State;
7. run modality-specific scientific checks in addition to universal audits.

## Adapter boundary

Single-cell, IHC, western blot, clinical, survival, animal imaging and generic quantitative figures are adapters. Their plot types must not become mandatory rules in the universal core.
