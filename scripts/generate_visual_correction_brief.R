#!/usr/bin/env Rscript
# generate_visual_correction_brief.R — Potato Figure Audit v0.4.1-alpha R2
# 生成 Visual Correction Brief：把"图不好看"转为结构化修正要求。
# 不重画图；产出修正要求 + preserve_constraints + global_recheck。
#
# 用法:
#   Rscript generate_visual_correction_brief.R <figure_dir> [--json]
#   Rscript generate_visual_correction_brief.R <figure_dir> --source RASTER_REVIEW
#   Rscript generate_visual_correction_brief.R <figure_dir> --input brief_input.yaml
#
# 输出: visual_correction_brief.yaml + visual_correction_brief.md

script_dir <- dirname(normalizePath(sub("^--file=", "",
  commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][1])))
source(file.path(script_dir, "lib", "qa_common.R"))
source(file.path(script_dir, "lib", "audit_core.R"))
source(file.path(script_dir, "lib", "color_integration.R"))

args <- commandArgs(trailingOnly = TRUE)
directory <- if (length(args) && !startsWith(args[1], "--")) args[1] else "."
as_json <- "--json" %in% args
src_idx <- grep("^--source", args)
evidence_source <- if (length(src_idx)) {
  v <- sub("^--source[= ]", "", args[src_idx[1]])
  if (nzchar(v) && !startsWith(v, "--")) toupper(v) else toupper(args[src_idx[1] + 1])
} else "METADATA_ONLY"
input_arg <- args[grep("^--input", args)]

## 读取用户/审计提供的视觉问题输入（如有）
issues <- list()
if (length(input_arg)) {
  inp <- sub("^--input[= ]", "", input_arg[1])
  if (file.exists(inp)) {
    raw <- readLines(inp, warn = FALSE, encoding = "UTF-8")
    ## 简单 yaml 风格解析 issue 列表（诊断可由人工/视觉模型填写）
    for (ln in raw) {
      if (grepl("^\\s*-\\s+diagnosis:", ln)) {
        issues[[length(issues) + 1]] <- list(diagnosis = sub("^\\s*-\\s+diagnosis:\\s*", "", ln))
      }
    }
  }
}

## 读取 contract 与 state
contract_path <- file.path(directory, "figure_contract.yaml")
contract <- if (file.exists(contract_path)) tryCatch(read_flat_yaml(contract_path), error = function(e) list()) else list()
state_file <- if (!is_blank(contract$global_state_file)) contract$global_state_file else "global_figure_state.yaml"
state <- if (file.exists(file.path(directory, state_file))) {
  tryCatch(read_flat_yaml(file.path(directory, state_file)), error = function(e) list())
} else list()

## 读取 manifest（panel 列表）
manifest <- NULL
manifest_path <- file.path(directory, "figure_manifest.tsv")
if (file.exists(manifest_path)) {
  manifest <- tryCatch(read_manifest(manifest_path), error = function(e) NULL)
}
panels <- if (!is.null(manifest) && "panel" %in% names(manifest)) unique(manifest$panel) else character()

## 视觉证据源判定（A5）：METADATA_ONLY 时 image review NOT_EVALUABLE
img_status <- image_review_status(evidence_source)
img_status_note <- switch(evidence_source,
  RASTER_REVIEW = "Raster preview reviewed at full size and thumbnail",
  VECTOR_REVIEW = "Vector output reviewed",
  VISION_MODEL_REVIEW = "Reviewed via vision model on the rendered image",
  MANUAL_REVIEW = "Reviewed manually",
  METADATA_ONLY = "Only metadata/contract declarations reviewed; no actual image inspection",
  NONE = "No visual evidence supplied")

## ---- profile 检查（potato-user-v1, A4）----
profile_issues <- list()
profile <- tolower(trim_scalar(state$visual.profile))
if (profile == "potato-user-v1") {
  body <- suppressWarnings(as.numeric(trim_scalar(state$visual.body_pt)))
  axis <- suppressWarnings(as.numeric(trim_scalar(state$visual.axis_text_pt)))
  if (!is.na(body) && (body < 8 || body > 12)) {
    profile_issues[[length(profile_issues) + 1]] <- list(
      issue_id = "VIS-PROF-001", priority = "HIGH", severity = "MINOR",
      domain = "typography", affected_panels = "all",
      diagnosis = sprintf("Body text %.1f pt outside potato-user-v1 working range 8–12 pt", body),
      why_it_matters = "Personal profile preference; readability at intended size",
      recommended_action = "Set body text within 8–12 pt at final physical size",
      preserve_constraints = "scientific_content;source_data",
      global_recheck = "typography;thumbnail",
      upstream_owner = "FIGURE_GENERATOR", confidence = "HIGH",
      evaluation_source = "PROFILE")
  }
  if (!is.na(axis) && (axis < 8 || axis > 12)) {
    profile_issues[[length(profile_issues) + 1]] <- list(
      issue_id = "VIS-PROF-002", priority = "HIGH", severity = "MINOR",
      domain = "typography", affected_panels = "all",
      diagnosis = sprintf("Axis text %.1f pt outside potato-user-v1 working range 8–12 pt", axis),
      why_it_matters = "Personal profile preference",
      recommended_action = "Set axis text within 8–12 pt",
      preserve_constraints = "scientific_content",
      global_recheck = "typography;clipping",
      upstream_owner = "FIGURE_GENERATOR", confidence = "HIGH",
      evaluation_source = "PROFILE")
  }
  ## canvas occupancy
  occ_w <- suppressWarnings(as.numeric(trim_scalar(state$geometry.target_width_occupancy)))
  if (!is.na(occ_w) && occ_w < 0.7) {
    profile_issues[[length(profile_issues) + 1]] <- list(
      issue_id = "VIS-PROF-003", priority = "MEDIUM", severity = "MAJOR",
      domain = "canvas_utilization", affected_panels = "all",
      diagnosis = sprintf("Target width occupancy %.2f below potato-user-v1 compact target (~0.88)", occ_w),
      why_it_matters = "Low canvas utilization usually means large nonfunctional whitespace",
      recommended_action = "Increase content footprint; reduce outer margins/gutters",
      preserve_constraints = "comparable_font_size;hero_hierarchy",
      global_recheck = "canvas_utilization;panel_balance;whitespace",
      upstream_owner = "FIGURE_GENERATOR", confidence = "MEDIUM",
      evaluation_source = "PROFILE")
  }
}

## ---- metadata-derived 问题（不冒充像素测量）----
meta_issues <- list()
if (!is.null(manifest) && "panel" %in% names(manifest)) {
  ## panel 冗余提示（metadata 层）
  if (nrow(manifest) > 1 && length(unique(trimws(manifest$source_data))) == 1 &&
      length(unique(tolower(trimws(manifest$statistical_test)))) == 1) {
    meta_issues[[length(meta_issues) + 1]] <- list(
      issue_id = "VIS-META-001", priority = "MEDIUM", severity = "MAJOR",
      domain = "panel_redundancy", affected_panels = paste(manifest$panel, collapse = ","),
      diagnosis = "Multiple panels share identical source data and analysis; possible redundancy",
      why_it_matters = "Redundant panels waste area and dilute hierarchy",
      recommended_action = "Merge or remove redundant panels; keep one evidence role each",
      preserve_constraints = "claim_coverage;evidence_chain",
      global_recheck = "panel_architecture;reading_order;hero",
      upstream_owner = "FIGURE_GENERATOR", confidence = "MEDIUM",
      evaluation_source = "METADATA")
  }
  ## sparse panel over-allocation（metadata 层推断：panel 数 vs 证据角色）
  if ("panel" %in% names(manifest) && nrow(manifest) >= 3) {
    meta_issues[[length(meta_issues) + 1]] <- list(
      issue_id = "VIS-META-002", priority = "LOW", severity = "INFO",
      domain = "panel_area_proportionality", affected_panels = paste(manifest$panel, collapse = ","),
      diagnosis = "Panel-area proportionality should be verified against evidence density",
      why_it_matters = "Sparse panels over-allocated area reduce information density",
      recommended_action = "Verify area allocation matches evidence weight; compress sparse panels",
      preserve_constraints = "hero_hierarchy;shared_alignment",
      global_recheck = "panel_balance;canvas_utilization",
      upstream_owner = "FIGURE_GENERATOR", confidence = "LOW",
      evaluation_source = "METADATA")
  }
}

## ---- Color Audit findings → correction requirements ----
color_issues <- list()
color_result <- run_color_audit_cli(directory, script_dir)
if (!isTRUE(color_result$ok)) {
  color_issues[[1]] <- list(
    issue_id = "COLOR-INTEGRATION", priority = "CRITICAL", severity = "BLOCKER",
    domain = "color", affected_panels = "all",
    diagnosis = sprintf("Color audit integration failed: %s", color_result$error),
    why_it_matters = "A correction brief without the Color System findings is incomplete",
    recommended_action = "Repair and rerun scripts/audit_color_system.R",
    preserve_constraints = "scientific_content;source_data",
    global_recheck = "COLOR-01;COLOR-03;COLOR-05;COLOR-11;GLOBAL_COHERENCE",
    upstream_owner = "ANALYSIS", confidence = "HIGH", evaluation_source = "RUNTIME")
} else {
  actionable <- color_result$payload$findings[vapply(color_result$payload$findings, function(f) {
    toupper(trim_scalar(f$status)) %in% c("WARNING", "MAJOR", "FAIL", "NOT_EVALUABLE")
  }, logical(1))]
  color_issues <- lapply(actionable, function(f) list(
    issue_id = trim_scalar(f$rule_id),
    priority = if (toupper(trim_scalar(f$status)) %in% c("MAJOR", "FAIL")) "HIGH" else "MEDIUM",
    severity = if (toupper(trim_scalar(f$status)) == "MAJOR") "MAJOR" else trim_scalar(f$severity),
    domain = "color", affected_panels = if (nzchar(trim_scalar(f$panels))) trim_scalar(f$panels) else "all",
    diagnosis = trim_scalar(f$issue),
    why_it_matters = if (nzchar(trim_scalar(f$why))) trim_scalar(f$why) else "Color evidence is incomplete or requires correction",
    recommended_action = if (nzchar(trim_scalar(f$action))) trim_scalar(f$action) else "Supply the missing structured color-review evidence",
    preserve_constraints = "scientific_content;semantic_mapping;source_data",
    global_recheck = sprintf("%s;COLOR-01;COLOR-03;COLOR-05;COLOR-11;GLOBAL_COHERENCE", trim_scalar(f$rule_id)),
    upstream_owner = "FIGURE_GENERATOR", confidence = trim_scalar(f$confidence),
    evaluation_source = trim_scalar(f$evaluation_source)
  ))
}

## ---- 汇总 ----
all_issues <- c(issues, profile_issues, meta_issues, color_issues)
overall <- if (img_status == "PASS") "REVIEWED" else "METADATA_ONLY"
if (length(all_issues) == 0 && img_status == "PASS") overall <- "OK"
if (length(all_issues) > 0) overall <- "REVISE_REQUIRED"

## 输出 brief
brief <- list(
  brief_version = "1.0",
  figure_id = trim_scalar(state$figure_id),
  generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
  visual_evidence_source = evidence_source,
  image_review_status = img_status,
  image_review_note = img_status_note,
  overall_status = overall,
  top_issues = all_issues
)

yaml_out <- c(
  sprintf("brief_version: %s", brief$brief_version),
  sprintf("figure_id: %s", brief$figure_id),
  sprintf("generated_at: %s", brief$generated_at),
  sprintf("visual_evidence_source: %s", evidence_source),
  sprintf("image_review_status: %s", img_status),
  sprintf("image_review_note: \"%s\"", img_status_note),
  sprintf("overall_status: %s", overall),
  "top_issues:"
)
if (!length(all_issues)) {
  yaml_out <- c(yaml_out, "  []")
} else {
  for (iss in all_issues) {
    yaml_out <- c(yaml_out, "  -")
    for (nm in names(iss)) {
      yaml_out <- c(yaml_out, sprintf("    %s: \"%s\"", nm, iss[[nm]]))
    }
  }
}
writeLines(yaml_out, file.path(directory, "visual_correction_brief.yaml"))

## markdown 版
md <- c("# Visual Correction Brief", "",
        sprintf("**Figure:** %s", brief$figure_id),
        sprintf("**Evidence source:** %s — %s", evidence_source, img_status_note),
        sprintf("**Image review status:** %s", img_status),
        sprintf("**Overall:** %s", overall), "")
if (length(all_issues)) {
  md <- c(md, "## Issues", "")
  for (iss in all_issues) {
    md <- c(md,
            sprintf("### %s [%s/%s] %s", iss$issue_id, iss$priority, iss$severity, iss$domain),
            sprintf("- Panels: %s", iss$affected_panels),
            sprintf("- Diagnosis: %s", iss$diagnosis),
            sprintf("- Why: %s", iss$why_it_matters),
            sprintf("- Action (%s): %s", iss$upstream_owner, iss$recommended_action),
            sprintf("- Preserve: %s", iss$preserve_constraints),
            sprintf("- Global recheck: %s", iss$global_recheck),
            sprintf("- Confidence: %s | Source: %s", iss$confidence, iss$evaluation_source), "")
  }
} else {
  md <- c(md, "No correction issues identified at the evaluated evidence level.", "")
}
writeLines(md, file.path(directory, "visual_correction_brief.md"))

cat(sprintf("Brief written: %s\n", file.path(directory, "visual_correction_brief.yaml")))
cat(sprintf("Markdown: %s\n", file.path(directory, "visual_correction_brief.md")))
cat(sprintf("IMAGE_REVIEW_STATUS: %s | OVERALL: %s\n", img_status, overall))
