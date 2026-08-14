# `figure_manifest.tsv` schema

`figure_manifest.tsv` is the machine-auditable, panel-level scientific/provenance record. It does not store visual-art-direction judgments.

| Field | Required | Contract |
|---|---:|---|
| `panel` | yes | Stable unique panel identifier. |
| `script` | yes | Relative path to the script that generated the panel. |
| `source_data` | yes | One or more relative Source Data paths, separated by `;`. |
| `statistical_unit` | yes | Independent biological unit used for inference, such as patient, animal, donor, or independent experiment. |
| `n` | yes | Positive number of independent statistical units represented by the panel. |
| `pairing` | yes | `paired`, `unpaired`, or `not_applicable`. |
| `transformation` | yes | Transformation or scale used; use `none` when none was applied. |
| `statistical_test` | yes | Test/model or `descriptive_only`; include paired/unpaired design where relevant. |
| `multiplicity_applicable` | yes | `yes` or `no`, based on the declared hypothesis family rather than the test name. |
| `multiplicity_method` | yes | Adjustment method when applicable; `NA` is permitted only when applicability is `no`. |
| `hypothesis_family` | yes | Prespecified family over which multiplicity was considered, including a single primary comparison. |
| `output_file` | yes | Relative path to the primary rendered output for that panel. Several rows may intentionally share one figure-level output. |

Scientific Audit checks schema, statistical unit, `n`, pairing, test and multiplicity declarations, Source Data, script provenance, and panel/output mapping. Requested formats, physical dimensions, resolution, A4 proof, and session metadata belong to Delivery QA.

Visual judgments such as hero clarity, balance, whitespace, colour, and typography are prohibited in this table.
