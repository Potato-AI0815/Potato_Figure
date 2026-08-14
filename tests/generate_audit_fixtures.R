# generate_audit_fixtures.R — Potato Figure Audit v0.3.0 测试 fixtures
# 生成 10 个审计场景（见任务书第十七节）。输出到 <dir>/audit_fixtures/<case>
args <- commandArgs(trailingOnly = TRUE)
out_root <- if (length(args)) args[1] else "audit_fixtures"
dir.create(out_root, showWarnings = FALSE, recursive = TRUE)

write_file <- function(dir, name, content) {
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  writeLines(content, file.path(dir, name))
}

## ---- CASE 1: scientifically valid figure → PASS ----
d1 <- file.path(out_root, "case1_valid")
write_file(d1, "figure_contract.yaml", c(
  'central_claim: "Treatment changes response at patient level"',
  'hero_evidence: "Panel A"',
  'supporting_evidence: "none"',
  'figure_grammar: "paired effect plot"',
  'visual_profile: potato-user-v1',
  'authoring_profile: not_selected',
  'target_journal: unspecified',
  'reference_figure: none',
  'reading_order: a,b',
  'scientific_status: PASS',
  'delivery_status: PASS',
  'global_state_file: global_figure_state.yaml',
  'visual_status: PASS',
  'requested_formats: png',
  'final_width_mm: 183',
  'final_height_mm: 120',
  'raster_dpi: 300',
  'delivery_metadata_file: delivery_metadata.tsv',
  'session_metadata: session_info.txt'))
write_file(d1, "figure_manifest.tsv", c(
  "panel\tscript\tsource_data\tstatistical_unit\tn\tpairing\ttransformation\tstatistical_test\tmultiplicity_applicable\tmultiplicity_method\thypothesis_family\toutput_file",
  "A\ta.R\tsource_data.tsv\tpatient\t10\tpaired\traw\tWilcoxon signed-rank\tyes\tBH-FDR\tall_genes\tfigure.png",
  "B\ta.R\tsource_data.tsv\tpatient\t10\tpaired\traw\tdescriptive_only\tno\tNA\tsingle_panel\tfigure.png"))
write_file(d1, "source_data.tsv", c("x\ty", "1\t2", "2\t3"))
write_file(d1, "figure.png", "PNG placeholder")
write_file(d1, "a.R", "# placeholder script")
write_file(d1, "delivery_metadata.tsv", c(
  "output_file\tformat\twidth_mm\theight_mm\tdpi",
  "figure.png\tpng\t183\t120\t300"))
write_file(d1, "session_info.txt", "R version 4.4.3")
write_file(d1, "global_figure_state.yaml", c(
  "state_version: 1.0", "figure_id: F1", "modality: generic", "assembly_mode: publication",
  "scientific.central_claim: claim", "scientific.statistical_unit: patient",
  "narrative.reading_order: a,b", "narrative.hero_panel: a", "narrative.panel_tags: a,b",
  "visual.profile: potato-user-v1", "visual.body_pt: 9", "visual.axis_text_pt: 8.5", "visual.panel_tag_pt: 11",
  "geometry.target_width_occupancy: 0.88", "geometry.target_height_occupancy: 0.82",
  "geometry.outer_margin_mm: 3.5", "geometry.panel_gap_mm: 3",
  "assembly.final_canvas: one_figure", "repair.change_log_file: local_change_log.tsv", "repair.last_change_id: none"))

## ---- CASE 2: cell-level pseudoreplication → BLOCKER ----
d2 <- file.path(out_root, "case2_pseudoreplication")
write_file(d2, "figure_contract.yaml", c(
  'central_claim: "Disease changes gene expression between groups"',
  'visual_status: PASS'))
write_file(d2, "figure_manifest.tsv", c(
  "panel\tscript\tsource_data\tstatistical_unit\tn\tpairing\ttransformation\tstatistical_test\tmultiplicity_applicable\tmultiplicity_method\thypothesis_family\toutput_file",
  "A\ta.R\tsource_data.tsv\tcell\t30000\tunpaired\traw\tWilcoxon rank-sum\tyes\tBH-FDR\tall_cells\tfigure.png"))
write_file(d2, "source_data.tsv", c("x\ty", "1\t2"))

## ---- CASE 3: paired data + unpaired test → FAIL ----
d3 <- file.path(out_root, "case3_paired_unpaired")
write_file(d3, "figure_contract.yaml", c(
  'central_claim: "Paired response differs"',
  'visual_status: PASS'))
write_file(d3, "figure_manifest.tsv", c(
  "panel\tscript\tsource_data\tstatistical_unit\tn\tpairing\ttransformation\tstatistical_test\tmultiplicity_applicable\tmultiplicity_method\thypothesis_family\toutput_file",
  "A\ta.R\tsource_data.tsv\tpatient\t10\tpaired\traw\tWilcoxon rank-sum\tyes\tBH-FDR\tall_genes\tfigure.png"))
write_file(d3, "source_data.tsv", c("x\ty", "1\t2"))

## ---- CASE 4: UMAP supports causal claim → CLAIM_EVIDENCE FAIL ----
d4 <- file.path(out_root, "case4_umap_overclaim")
write_file(d4, "figure_contract.yaml", c(
  'central_claim: "Treatment significantly reversed disease state"',
  'visual_status: PASS'))
write_file(d4, "figure_manifest.tsv", c(
  "panel\tscript\tsource_data\tstatistical_unit\tn\tpairing\ttransformation\tstatistical_test\tmultiplicity_applicable\tmultiplicity_method\thypothesis_family\toutput_file",
  "A\ta.R\tsource_data.tsv\tcell\t5000\tnot_applicable\traw\tUMAP (descriptive)\tno\tNA\tlandscape\tfigure.png"))
write_file(d4, "source_data.tsv", c("x\ty", "1\t2"))

## ---- CASE 5: redundant panels → PANEL_ARCHITECTURE REVISE ----
d5 <- file.path(out_root, "case5_redundant")
write_file(d5, "figure_contract.yaml", c(
  'central_claim: "Marker expression distinguishes types"',
  'visual_status: PASS'))
write_file(d5, "figure_manifest.tsv", c(
  "panel\tscript\tsource_data\tstatistical_unit\tn\tpairing\ttransformation\tstatistical_test\tmultiplicity_applicable\tmultiplicity_method\thypothesis_family\toutput_file",
  "A\ta.R\tsource_data.tsv\tpatient\t10\tunpaired\traw\tdescriptive_only\tno\tNA\tsingle\tfigure.png",
  "B\ta.R\tsource_data.tsv\tpatient\t10\tunpaired\traw\tdescriptive_only\tno\tNA\tsingle\tfigure.png"))
write_file(d5, "source_data.tsv", c("x\ty", "1\t2"))
write_file(d5, "figure_manifest.notes", "A and B identical data, different chart type")

## ---- CASE 6: local fix breaks hierarchy → GLOBAL_COHERENCE FAIL ----
d6 <- file.path(out_root, "case6_local_fix_global")
write_file(d6, "figure_contract.yaml", c(
  'central_claim: "claim"',
  'global_state_file: global_figure_state.yaml',
  'visual_status: PASS'))
write_file(d6, "figure_manifest.tsv", c(
  "panel\tscript\tsource_data\tstatistical_unit\tn\tpairing\ttransformation\tstatistical_test\tmultiplicity_applicable\tmultiplicity_method\thypothesis_family\toutput_file",
  "A\ta.R\tsource_data.tsv\tpatient\t10\tpaired\traw\tWilcoxon signed-rank\tyes\tBH-FDR\tall\tfigure.png"))
write_file(d6, "source_data.tsv", c("x\ty", "1\t2"))
write_file(d6, "global_figure_state.yaml", c(
  "state_version: 1.0", "figure_id: F6", "modality: generic", "assembly_mode: publication",
  "scientific.central_claim: claim", "scientific.statistical_unit: patient",
  "narrative.reading_order: a,b", "narrative.hero_panel: a", "narrative.panel_tags: a,b",
  "visual.profile: potato-user-v1", "visual.body_pt: 9", "visual.axis_text_pt: 8.5", "visual.panel_tag_pt: 11",
  "geometry.target_width_occupancy: 0.88", "geometry.target_height_occupancy: 0.82",
  "geometry.outer_margin_mm: 3.5", "geometry.panel_gap_mm: 3",
  "assembly.final_canvas: one_figure", "repair.change_log_file: local_change_log.tsv",
  "repair.last_change_id: CHG1"))
write_file(d6, "local_change_log.tsv", c(
  "change_id\ttimestamp\tchange_type\ttarget_key\treason\timpact_scope\trequired_rechecks\trecheck_status\tglobal_state_updated\tclosed\tnotes",
  "CHG1\t2026-08-09T10:00:00+08:00\tgeometry\tpanel.a.height\tCompress panel a\tpanel_a\tgeometry\trecheck_status\tno\tno\tLocal fix not globally reviewed"))

## ---- CASE 7: beautiful figure missing Source Data → DELIVERY REVISE, not Scientific FAIL ----
d7 <- file.path(out_root, "case7_missing_source_data")
write_file(d7, "figure_contract.yaml", c(
  'central_claim: "claim"',
  'visual_status: PASS'))
write_file(d7, "figure_manifest.tsv", c(
  "panel\tscript\tsource_data\tstatistical_unit\tn\tpairing\ttransformation\tstatistical_test\tmultiplicity_applicable\tmultiplicity_method\thypothesis_family\toutput_file",
  "A\ta.R\tmissing.tsv\tpatient\t10\tpaired\traw\tWilcoxon signed-rank\tyes\tBH-FDR\tall\tfigure.png"))
write_file(d7, "figure.png", "PNG placeholder")

## ---- CASE 8: only PNG → visual evaluable, statistics NOT_EVALUABLE ----
d8 <- file.path(out_root, "case8_only_png")
write_file(d8, "figure_contract.yaml", c(
  'central_claim: "claim"',
  'visual_status: PASS'))
write_file(d8, "figure.png", "PNG placeholder")

## ---- CASE 9: potato-user-v1 whitespace violation → VISUAL REVISE (not Scientific FAIL) ----
d9 <- file.path(out_root, "case9_profile_violation")
write_file(d9, "figure_contract.yaml", c(
  'central_claim: "claim"',
  'global_state_file: global_figure_state.yaml',
  'visual_status: PASS'))
write_file(d9, "figure_manifest.tsv", c(
  "panel\tscript\tsource_data\tstatistical_unit\tn\tpairing\ttransformation\tstatistical_test\tmultiplicity_applicable\tmultiplicity_method\thypothesis_family\toutput_file",
  "A\ta.R\tsource_data.tsv\tpatient\t10\tpaired\traw\tWilcoxon signed-rank\tyes\tBH-FDR\tall\tfigure.png"))
write_file(d9, "source_data.tsv", c("x\ty", "1\t2"))
write_file(d9, "global_figure_state.yaml", c(
  "state_version: 1.0", "figure_id: F9", "modality: generic", "assembly_mode: publication",
  "scientific.central_claim: claim", "scientific.statistical_unit: patient",
  "narrative.reading_order: a,b", "narrative.hero_panel: a", "narrative.panel_tags: a,b",
  "visual.profile: potato-user-v1", "visual.body_pt: 6", "visual.axis_text_pt: 5", "visual.panel_tag_pt: 8",
  "geometry.target_width_occupancy: 0.88", "geometry.target_height_occupancy: 0.82",
  "geometry.outer_margin_mm: 3.5", "geometry.panel_gap_mm: 3",
  "assembly.final_canvas: one_figure", "repair.change_log_file: local_change_log.tsv", "repair.last_change_id: none"))

## ---- CASE 10: all gates satisfied → PUBLICATION_READY TRUE ----
d10 <- file.path(out_root, "case10_all_pass")
write_file(d10, "figure_contract.yaml", c(
  'central_claim: "Treatment changes response at patient level"',
  'hero_evidence: "Panel A paired patient-level response"',
  'supporting_evidence: "none"',
  'figure_grammar: "paired effect plot"',
  'visual_profile: potato-user-v1',
  'authoring_profile: not_selected',
  'target_journal: unspecified',
  'reference_figure: none',
  'reading_order: a',
  'scientific_status: PASS',
  'delivery_status: PASS',
  'global_state_file: global_figure_state.yaml',
  'visual_status: PASS',
  'requested_formats: png',
  'final_width_mm: 183',
  'final_height_mm: 120',
  'raster_dpi: 300',
  'delivery_metadata_file: delivery_metadata.tsv',
  'session_metadata: session_info.txt'))
write_file(d10, "figure_manifest.tsv", c(
  "panel\tscript\tsource_data\tstatistical_unit\tn\tpairing\ttransformation\tstatistical_test\tmultiplicity_applicable\tmultiplicity_method\thypothesis_family\toutput_file",
  "A\ta.R\tsource_data.tsv\tpatient\t10\tpaired\traw\tWilcoxon signed-rank\tyes\tBH-FDR\tall_genes\tfigure.png"))
write_file(d10, "source_data.tsv", c("x\ty", "1\t2"))
write_file(d10, "figure.png", "PNG placeholder")
write_file(d10, "a.R", "# placeholder script")
write_file(d10, "delivery_metadata.tsv", c(
  "output_file\tformat\twidth_mm\theight_mm\tdpi",
  "figure.png\tpng\t183\t120\t300"))
write_file(d10, "session_info.txt", "R version 4.4.3")
write_file(d10, "global_figure_state.yaml", c(
  "state_version: 1.0", "figure_id: F10", "modality: generic", "assembly_mode: publication",
  "scientific.central_claim: claim", "scientific.statistical_unit: patient",
  "narrative.reading_order: a,b", "narrative.hero_panel: a", "narrative.panel_tags: a,b",
  "visual.profile: potato-user-v1", "visual.body_pt: 9", "visual.axis_text_pt: 8.5", "visual.panel_tag_pt: 11",
  "geometry.target_width_occupancy: 0.88", "geometry.target_height_occupancy: 0.82",
  "geometry.outer_margin_mm: 3.5", "geometry.panel_gap_mm: 3",
  "assembly.final_canvas: one_figure", "repair.change_log_file: local_change_log.tsv", "repair.last_change_id: none"))
write_file(d10, "global_coherence_qa.tsv", c(
  "domain\tstatus\tnotes",
  "scientific_spine_preserved\tPASS\tok",
  "panel_role_consistency\tPASS\tok",
  "reading_order\tPASS\tok",
  "geometry_budget\tPASS\tok",
  "canvas_utilization\tPASS\tok",
  "physical_consistency\tPASS\tok",
  "chromatic_coherence\tPASS\tok",
  "typography_consistency\tPASS\tok",
  "assembly_coherence\tPASS\tok",
  "local_change_impact_closed\tPASS\tok"))

cat(sprintf("Generated %d audit fixtures in %s\n", 10, out_root))
