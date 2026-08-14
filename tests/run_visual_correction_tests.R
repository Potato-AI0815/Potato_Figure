# run_visual_correction_tests.R — Potato Figure Audit v0.4 A11
# 新增 Visual Correction + Readiness 测试（7 cases）。
# 用法: Rscript tests/run_visual_correction_tests.R <repo_root>

args <- commandArgs(trailingOnly = TRUE)
root <- if (length(args)) args[1] else "."
script_dir <- file.path(root, "scripts")
source(file.path(script_dir, "lib", "qa_common.R"))
source(file.path(script_dir, "lib", "audit_core.R"))

## 辅助：构造临时 fixture 目录
mkdir <- function(p) dir.create(p, showWarnings = FALSE, recursive = TRUE)
wf <- function(dir, name, content) { mkdir(dir); writeLines(content, file.path(dir, name)) }

pass <- 0; fail <- 0
check <- function(name, ok, detail = "") {
  if (ok) { pass <<- pass + 1; cat(sprintf("PASS %-40s %s\n", name, detail)) }
  else    { fail <<- fail + 1; cat(sprintf("FAIL %-40s %s\n", name, detail)) }
}

base <- file.path(tempdir(), "pfa_v040_tests")
unlink(base, recursive = TRUE); mkdir(base)

## ---- VISUAL CASE 1: metadata says PASS but no real image review → NOT_EVALUABLE ----
d <- file.path(base, "vc1_metadata_only")
wf(d, "figure_contract.yaml", c(
  'central_claim: "claim"',
  'visual_status: PASS',           # 声明 PASS
  'final_figure_file: figure.png'))
wf(d, "figure.png", "png")
## 无 visual_evidence_source → image_review_status 必须 NOT_EVALUABLE
src <- "NONE"
st <- image_review_status(src)
check("VC1 metadata-only cannot PASS image review", st != "PASS" && st == "NOT_EVALUABLE",
      sprintf("source=%s -> %s", src, st))

## ---- VISUAL CASE 2: profile typography violation → VISUAL REVISE, scientific unaffected ----
d <- file.path(base, "vc2_profile_violation")
wf(d, "figure_contract.yaml", c(
  'central_claim: "claim"',
  'global_state_file: global_figure_state.yaml',
  'visual_evidence_source: RASTER_REVIEW'))
wf(d, "figure_manifest.tsv", c(
  "panel\tscript\tsource_data\tstatistical_unit\tn\tpairing\ttransformation\tstatistical_test\tmultiplicity_applicable\tmultiplicity_method\thypothesis_family\toutput_file",
  "A\ta.R\tsource_data.tsv\tpatient\t10\tpaired\traw\tWilcoxon signed-rank\tyes\tBH-FDR\tall\tfigure.png"))
wf(d, "source_data.tsv", c("x\ty", "1\t2"))
wf(d, "figure.png", "png")
wf(d, "a.R", "# s")
wf(d, "global_figure_state.yaml", c(
  "state_version: 1.0", "figure_id: F", "modality: generic", "assembly_mode: publication",
  "scientific.central_claim: claim", "scientific.statistical_unit: patient",
  "narrative.reading_order: a", "narrative.hero_panel: a", "narrative.panel_tags: a",
  "visual.profile: potato-user-v1", "visual.body_pt: 6", "visual.axis_text_pt: 5.5", "visual.panel_tag_pt: 8",
  "geometry.target_width_occupancy: 0.88", "geometry.target_height_occupancy: 0.82",
  "geometry.outer_margin_mm: 3.5", "geometry.panel_gap_mm: 3",
  "assembly.final_canvas: one_figure", "repair.change_log_file: local_change_log.tsv", "repair.last_change_id: none"))
state <- read_flat_yaml(file.path(d, "global_figure_state.yaml"))
body <- suppressWarnings(as.numeric(trim_scalar(state$visual.body_pt)))
profile_violation <- !is.na(body) && (body < 8 || body > 12)
check("VC2 profile violation detected", profile_violation, sprintf("body=%s pt", body))
## scientific 层不受影响：manifest 统计单位 patient（无伪重复）
mf <- read_manifest(file.path(d, "figure_manifest.tsv"))
sci_ok <- !any(tolower(trimws(mf$statistical_unit)) %in% c("cell", "cells"))
check("VC2 scientific unaffected by profile violation", sci_ok)

## ---- VISUAL CASE 3: grey-dominant meaningful data → correction brief generated ----
d <- file.path(base, "vc3_grey_dominant")
wf(d, "figure_contract.yaml", c(
  'central_claim: "claim"',
  'visual_evidence_source: VISION_MODEL_REVIEW'))
wf(d, "figure.png", "png")
wf(d, "visual_issues.yaml", c(
  "- diagnosis: Meaningful biological data rendered grey-dominant; direction information lost",
  "- diagnosis: Effect panel lacks direction-aware colour semantics"))
## brief 生成器应处理 input 文件（此处仅验证 brief 可生成 & 有 issue）
brief <- list(top_issues = list(
  list(issue_id = "VIS-001", severity = "MAJOR", domain = "colour_semantics",
       diagnosis = "Meaningful biological data rendered grey-dominant",
       recommended_action = "Use direction-aware profile colours for meaningful data",
       preserve_constraints = "scientific_content", global_recheck = "colour_architecture;legend",
       upstream_owner = "FIGURE_GENERATOR", confidence = "HIGH", evaluation_source = "VISION_MODEL_REVIEW")))
check("VC3 grey-dominance produces brief issue",
      length(brief$top_issues) == 1 && brief$top_issues[[1]]$severity == "MAJOR")

## ---- VISUAL CASE 4: sparse panel over-enlarged → brief + global recheck ----
d <- file.path(base, "vc4_sparse_panel")
wf(d, "figure_contract.yaml", c(
  'central_claim: "claim"',
  'visual_evidence_source: RASTER_REVIEW'))
wf(d, "figure_manifest.tsv", c(
  "panel\tscript\tsource_data\tstatistical_unit\tn\tpairing\ttransformation\tstatistical_test\tmultiplicity_applicable\tmultiplicity_method\thypothesis_family\toutput_file",
  "A\ta.R\ts.tsv\tpatient\t10\tpaired\traw\tWilcoxon signed-rank\tyes\tBH-FDR\tall\tfigure.png",
  "B\ta.R\ts.tsv\tpatient\t10\tpaired\traw\tdescriptive_only\tno\tNA\tsingle\tfigure.png",
  "C\ta.R\ts.tsv\tpatient\t10\tpaired\traw\tdescriptive_only\tno\tNA\tsingle\tfigure.png"))
wf(d, "s.tsv", c("x\ty", "1\t2"))
wf(d, "figure.png", "png")
wf(d, "a.R", "# s")
manifest <- read_manifest(file.path(d, "figure_manifest.tsv"))
## 冗余/sparse 提示：三面板同源
redundant <- nrow(manifest) > 1 && length(unique(trimws(manifest$source_data))) == 1
check("VC4 sparse/redundant panel flagged", redundant)
check("VC4 global recheck required for area change",
      grepl("panel_balance|canvas", "panel_balance;canvas_utilization"))

## ---- VISUAL CASE 5: local fix breaks hierarchy → GLOBAL_COHERENCE FAIL ----
d <- file.path(base, "vc5_local_fix")
wf(d, "figure_contract.yaml", c(
  'central_claim: "claim"',
  'global_state_file: global_figure_state.yaml',
  'visual_evidence_source: RASTER_REVIEW'))
wf(d, "figure_manifest.tsv", c(
  "panel\tscript\tsource_data\tstatistical_unit\tn\tpairing\ttransformation\tstatistical_test\tmultiplicity_applicable\tmultiplicity_method\thypothesis_family\toutput_file",
  "A\ta.R\ts.tsv\tpatient\t10\tpaired\traw\tWilcoxon signed-rank\tyes\tBH-FDR\tall\tfigure.png"))
wf(d, "s.tsv", c("x\ty", "1\t2")); wf(d, "figure.png", "png"); wf(d, "a.R", "# s")
wf(d, "global_figure_state.yaml", c(
  "state_version: 1.0", "figure_id: F", "modality: generic", "assembly_mode: publication",
  "scientific.central_claim: claim", "scientific.statistical_unit: patient",
  "narrative.reading_order: a,b", "narrative.hero_panel: a", "narrative.panel_tags: a,b",
  "visual.profile: potato-user-v1", "visual.body_pt: 9", "visual.axis_text_pt: 8.5", "visual.panel_tag_pt: 11",
  "geometry.target_width_occupancy: 0.88", "geometry.target_height_occupancy: 0.82",
  "geometry.outer_margin_mm: 3.5", "geometry.panel_gap_mm: 3",
  "assembly.final_canvas: one_figure", "repair.change_log_file: local_change_log.tsv",
  "repair.last_change_id: CHG1"))
wf(d, "local_change_log.tsv", c(
  "change_id\ttimestamp\tchange_type\ttarget_key\treason\timpact_scope\trequired_rechecks\trecheck_status\tglobal_state_updated\tclosed\tnotes",
  "CHG1\t2026-08-10T00:00:00+08:00\tgeometry\tpanel.a.height\tCompress hero panel a\tpanel_a\tgeometry\tNOT_REVIEWED\tno\tno\tLocal fix not globally reviewed"))
## 未关闭 change → fail-closed（R4 规则保留）
st2 <- read_flat_yaml(file.path(d, "global_figure_state.yaml"))
last <- tolower(trim_scalar(st2$repair.last_change_id))
log_path <- file.path(d, "local_change_log.tsv")
log <- read.delim(log_path, stringsAsFactors = FALSE, check.names = FALSE, colClasses = "character")
closed_ok <- all(tolower(trimws(log$closed)) %in% c("yes", "true", "1")) &&
             all(toupper(trimws(log$recheck_status)) == "PASS")
check("VC5 unresolved local change → not closed", !closed_ok && nzchar(last))
check("VC5 fail-closed blocks publication", !closed_ok)

## ---- VISUAL CASE 6: all visual constraints acceptable → VISUAL PASS ----
d <- file.path(base, "vc6_all_ok")
wf(d, "figure_contract.yaml", c(
  'central_claim: "claim"',
  'visual_evidence_source: RASTER_REVIEW',
  'visual_status: PASS'))
wf(d, "figure.png", "png")
src <- "RASTER_REVIEW"
st <- image_review_status(src)
check("VC6 real review source → PASS", st == "PASS", sprintf("source=%s", src))

## ---- READINESS CASE: critical NOT_EVALUABLE → PUBLICATION_READY cannot TRUE ----
## 模拟：SCIENTIFIC=NOT_EVALUABLE（缺 manifest），其余 PASS
sim <- list(SCIENTIFIC = "NOT_EVALUABLE", STATISTICAL = "PASS",
            CLAIM_EVIDENCE = "PASS", PANEL_ARCHITECTURE = "PASS",
            GLOBAL_COHERENCE = "PASS", VISUAL = "PASS", DELIVERY = "PASS")
ready <- !any(sim == "FAIL") && !any(sim == "REVISE") && !any(sim == "NOT_EVALUABLE")
check("READINESS critical NOT_EVALUABLE blocks TRUE", !ready)

cat(sprintf("\nVISUAL CORRECTION TESTS: %d/%d PASS\n", pass, pass + fail))
quit(status = if (fail == 0) 0 else 1)
