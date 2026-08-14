#!/usr/bin/env Rscript
# audit_figure.R — Potato Figure Audit 主入口 (v0.4.3-alpha)
# 独立科研 Figure 审核与完整性检查层。
# generator-agnostic：不画图、不重画、不修改数据。
#
# 用法:
#   Rscript audit_figure.R <figure_dir> [--json] [--report <path>] [--mode <MODE>]
#   --json      输出 figure_audit.json
#   --report    指定 markdown 报告路径（默认 figure_audit_report.md）
#   --mode      QUICK_REVIEW | SCIENTIFIC_FIGURE_AUDIT | PUBLICATION_READY
#               默认自动推断（有 manifest → SCIENTIFIC_FIGURE_AUDIT; 只有图 → QUICK_REVIEW）
#
# v0.4.3-alpha 退出码契约（exit code contract）:
#   QUICK_REVIEW / SCIENTIFIC_FIGURE_AUDIT:
#     exit 0 = audit successfully executed（status 可以是 PASS/WARNING/REVISE/FAIL）
#   PUBLICATION_READY（显式 enforcement mode）:
#     exit 0 = publication gate passed (PUBLICATION_READY = TRUE)
#     exit 2 = audit completed, gate not satisfied
#   所有模式:
#     exit 3 = invalid input / contract error（目录不存在、--mode 非法等）
#     exit 4 = execution/internal error
#
# v0.4.3-alpha fail-closed 保证:
#   critical domain (SCIENTIFIC/STATISTICAL/CLAIM_EVIDENCE/PANEL_ARCHITECTURE/
#   VISUAL/COLOR/GLOBAL_COHERENCE/DELIVERY) 处于 NOT_EVALUABLE 时，
#   PUBLICATION_READY 永远不可能为 TRUE。

script_dir <- dirname(normalizePath(sub("^--file=", "",
  commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][1])))
source(file.path(script_dir, "lib", "qa_common.R"))
source(file.path(script_dir, "lib", "scientific_audit_core.R"))
source(file.path(script_dir, "lib", "delivery_qa_core.R"))
source(file.path(script_dir, "lib", "global_coherence_core.R"))
source(file.path(script_dir, "lib", "sha256.R"))
source(file.path(script_dir, "lib", "audit_core.R"))
source(file.path(script_dir, "lib", "color_system_core.R"))
source(file.path(script_dir, "lib", "color_integration.R"))

EXIT_OK <- 0L; EXIT_GATE_NOT_SATISFIED <- 2L; EXIT_INVALID_INPUT <- 3L; EXIT_INTERNAL <- 4L

args <- commandArgs(trailingOnly = TRUE)
directory <- if (length(args) && !startsWith(args[1], "--")) args[1] else "."
as_json <- "--json" %in% args
report_arg <- args[grep("^--report", args)]
report_path <- if (length(report_arg)) sub("^--report[= ]", "", report_arg[1]) else "figure_audit_report.md"
report_path <- file.path(directory, report_path)
repo_root <- normalizePath(file.path(script_dir, ".."), mustWork = TRUE)
mode_arg <- args[grep("^--mode[= ]", args)]
explicit_mode <- if (length(mode_arg)) sub("^--mode[= ]", "", mode_arg[1]) else ""
if (!nzchar(explicit_mode) && "--mode" %in% args) {
  idx <- which(args == "--mode")
  if (length(idx) && idx[1] < length(args)) explicit_mode <- args[idx[1] + 1]
}

## ---- v0.4.3-alpha: input validation (exit 3) ----
if (!dir.exists(directory)) {
  cat(sprintf("ERROR: figure directory does not exist: %s\n", directory), file = stderr())
  cat("USAGE: Rscript audit_figure.R <figure_dir> [--json] [--report <path>] [--mode <MODE>]\n", file = stderr())
  quit(status = EXIT_INVALID_INPUT)
}
if (nzchar(explicit_mode) && !toupper(trimws(explicit_mode)) %in% AUDIT_MODES) {
  cat(sprintf("ERROR: invalid --mode '%s'. Valid modes: %s\n",
              explicit_mode, paste(AUDIT_MODES, collapse = ", ")), file = stderr())
  quit(status = EXIT_INVALID_INPUT)
}

## ---- v0.4.3-alpha: internal errors surface as exit 4 (never masquerade as FAIL) ----
run_audit <- function() {

findings <- list()

## ---- 1. Input Audit ----
contract_path <- file.path(directory, "figure_contract.yaml")
contract <- if (file.exists(contract_path)) {
  tryCatch(read_flat_yaml(contract_path), error = function(e) list())
} else list()
inventory <- inventory_inputs(directory, contract)
audit_mode <- infer_audit_mode(directory, contract, explicit_mode)
## QUICK_REVIEW 模式: 只评估能从图本身判断的域
mode_domains <- AUDIT_MODE_DOMAINS[[audit_mode]]
if (is.null(mode_domains)) mode_domains <- AUDIT_MODE_DOMAINS[[AUDIT_MODE_DEFAULT]]

missing_req <- names(inventory)[!vapply(inventory, function(x) isTRUE(x$available), logical(1))]
for (nm in missing_req) {
  findings[[length(findings) + 1]] <- new_finding(
    "input", "INFO", "NOT_EVALUABLE",
    sprintf("Input not supplied: %s", nm),
    why = "Audit cannot evaluate domains depending on this material; missing input is reported, not fabricated",
    evidence = "input inventory")
}
if (isTRUE(inventory$figure_manifest$available)) {
  findings[[length(findings) + 1]] <- new_finding("input", "INFO", "PASS", "figure_manifest.tsv available")
} else {
  findings[[length(findings) + 1]] <- new_finding(
    "input", "MINOR", "NOT_EVALUABLE", "figure_manifest.tsv missing",
    why = "Panel-level provenance cannot be verified without the manifest",
    action = "Provide figure_manifest.tsv (see manifest_schema.md)", owner = "ANALYSIS")
}

## ---- 2. Scientific Integrity Audit（复用 R4 冻结层）----
## QUICK_REVIEW: 无统计元数据 → SCIENTIFIC 不得声称 PASS/FAIL, 只能 NOT_EVALUABLE
if ("SCIENTIFIC" %in% mode_domains) {
sc_checks <- tryCatch(run_scientific_audit(directory), error = function(e) NULL)
if (!is.null(sc_checks)) {
  for (ch in sc_checks) {
    sev <- if (ch$status == "FAIL") "BLOCKER" else if (ch$status == "WARNING") "MINOR" else "INFO"
    findings[[length(findings) + 1]] <- new_finding(
      "scientific", sev, ch$status, ch$detail,
      why = "Scientific integrity of the figure (statistical units, pairing, multiplicity, source data)",
      action = ch$advice, owner = "STATISTICS", evidence = "scientific_audit")
  }
}
} else if (isTRUE(inventory$figure_manifest$available)) {
  ## 有 manifest 但模式限定（QUICK_REVIEW）: 不做科学判定
  findings[[length(findings) + 1]] <- new_finding(
    "scientific", "MINOR", "NOT_EVALUABLE",
    "SCIENTIFIC not evaluated in QUICK_REVIEW mode (statistical metadata not required for image review)",
    why = "QUICK_REVIEW answers image-level questions only; scientific claims need manifest + statistical metadata",
    owner = "ANALYSIS", evidence = sprintf("audit_mode=%s", audit_mode))
} else {
  findings[[length(findings) + 1]] <- new_finding(
    "scientific", "MINOR", "NOT_EVALUABLE",
    "SCIENTIFIC not evaluable: figure_manifest.tsv missing",
    why = "Statistical units, pairing and multiplicity cannot be verified without the manifest",
    action = "Provide figure_manifest.tsv (see manifest_schema.md)", owner = "ANALYSIS")
}

## ---- 3. Statistical Consistency Audit ----
## v0.4.3-alpha: 材料不足 → 显式 NOT_EVALUABLE finding（fail-closed，不留"静默略过"盲区）
if ("STATISTICAL" %in% mode_domains) {
  stat_evaluated <- FALSE
  if (isTRUE(inventory$figure_manifest$available)) {
    mf <- tryCatch(read_manifest(file.path(directory, "figure_manifest.tsv")), error = function(e) NULL)
    if (!is.null(mf) && "pairing" %in% names(mf) && "statistical_test" %in% names(mf)) {
      stat_evaluated <- TRUE
      n_contra <- 0L
      for (i in seq_len(nrow(mf))) {
        pair <- tolower(trimws(mf$pairing[i]))
        test <- tolower(mf$statistical_test[i])
        if (pair == "paired" && grepl("rank[ -]?sum|mann[ -]?whitney|welch|unpaired|independent", test)) {
          n_contra <- n_contra + 1L
          findings[[length(findings) + 1]] <- new_finding(
            "statistical", "MAJOR", "FAIL",
            sprintf("Paired design but unpaired test (%s)", mf$statistical_test[i]),
            why = "Paired data analysed with unpaired statistics loses pairing information and can mis-estimate the effect",
            panels = mf$panel[i], action = "Use a paired test (e.g., Wilcoxon signed-rank)",
            owner = "STATISTICS", evidence = sprintf("manifest row %d", i))
        }
        if (pair == "unpaired" && grepl("signed[ -]?rank|paired[ -]?t", test)) {
          n_contra <- n_contra + 1L
          findings[[length(findings) + 1]] <- new_finding(
            "statistical", "MAJOR", "FAIL",
            sprintf("Unpaired design but paired test (%s)", mf$statistical_test[i]),
            why = "Paired test assumes matched observations that do not exist in an unpaired design",
            panels = mf$panel[i], action = "Use an unpaired test",
            owner = "STATISTICS", evidence = sprintf("manifest row %d", i))
        }
      }
      if (n_contra == 0L) {
        findings[[length(findings) + 1]] <- new_finding(
          "statistical", "INFO", "PASS",
          sprintf("No paired/unpaired versus test contradiction across %d panel row(s)", nrow(mf)),
          evidence = "statistical consistency check")
      }
    }
  }
  if (!stat_evaluated) {
    findings[[length(findings) + 1]] <- new_finding(
      "statistical", "MINOR", "NOT_EVALUABLE",
      "STATISTICAL not evaluable: manifest missing or lacks pairing/statistical_test columns",
      why = "Design-versus-test consistency cannot be verified without pairing and statistical_test declarations",
      action = "Provide figure_manifest.tsv with pairing and statistical_test columns",
      owner = "STATISTICS", evidence = "input inventory")
  }
}

## ---- 4. Claim–Evidence Audit ----
## claim_evidence_audit.R 是独立入口（R2.12 冻结层），主流程不重复执行。
## 这里在 figure_contract 层面做 claim-aware 的轻量一致性提示。
## v0.4.3-alpha: 无 claim/manifest 时显式 NOT_EVALUABLE（不留静默盲区）
claim_text <- tolower(trim_scalar(contract$central_claim))
claim_evaluated <- FALSE
if (nzchar(claim_text)) {
  patient_claim <- grepl("patient|sample|between|across|group|effect|increase|decrease|differ|significant|revers", claim_text)
  if (isTRUE(inventory$figure_manifest$available)) {
    mf_ce <- tryCatch(read_manifest(file.path(directory, "figure_manifest.tsv")), error = function(e) NULL)
    if (!is.null(mf_ce) && all(c("statistical_test", "statistical_unit") %in% names(mf_ce))) {
      claim_evaluated <- TRUE
      cell_level_descriptive <- any(grepl("umap|featureplot|violin|dotplot", tolower(mf_ce$statistical_test), ignore.case = TRUE)) &&
        any(tolower(trimws(mf_ce$statistical_unit)) %in% c("cell", "cells"))
      if (patient_claim && cell_level_descriptive) {
        findings[[length(findings) + 1]] <- new_finding(
          "claim_evidence", "BLOCKER", "FAIL",
          "Patient/sample-level claim supported only by cell-level descriptive evidence (overclaim)",
          why = "Cell-level descriptive views (UMAP/FeaturePlot/violin/DotPlot) cannot alone support patient-level inferential claims",
          panels = paste(mf_ce$panel[grepl("umap|featureplot|violin|dotplot", tolower(mf_ce$statistical_test), ignore.case = TRUE)], collapse = ","),
          action = "Add patient/sample-level evidence (paired proportion, pseudobulk effect, model result) or soften the claim",
          owner = "STATISTICS", evidence = "figure_contract.yaml + figure_manifest.tsv")
      } else {
        findings[[length(findings) + 1]] <- new_finding(
          "claim_evidence", "INFO", "PASS",
          "No claim-evidence contradiction detected at contract level",
          evidence = "figure_contract.yaml + figure_manifest.tsv")
      }
    }
  }
}
if (!claim_evaluated && audit_mode %in% c("SCIENTIFIC_FIGURE_AUDIT", "PUBLICATION_READY")) {
  findings[[length(findings) + 1]] <- new_finding(
    "claim_evidence", "MINOR", "NOT_EVALUABLE",
    "CLAIM_EVIDENCE not evaluable: central_claim missing in contract or manifest unavailable/incomplete",
    why = "Claim-evidence alignment cannot be verified without a declared central claim and panel manifest",
    action = "Declare central_claim in figure_contract.yaml and provide figure_manifest.tsv with statistical_test/statistical_unit columns",
    owner = "ANALYSIS", evidence = "input inventory")
}

## ---- 5. Panel Architecture Audit（轻量：panel 唯一性/冗余提示）----
if (isTRUE(inventory$figure_manifest$available)) {
  mf <- tryCatch(read_manifest(file.path(directory, "figure_manifest.tsv")), error = function(e) NULL)
  if (!is.null(mf) && "panel" %in% names(mf)) {
    dups <- mf$panel[duplicated(mf$panel)]
    if (length(dups)) {
      findings[[length(findings) + 1]] <- new_finding(
        "panel_architecture", "BLOCKER", "FAIL",
        sprintf("Duplicate panel identifiers: %s", paste(unique(dups), collapse = ", ")),
        why = "Panel identity must be unique for claim–evidence tracking",
        action = "Assign unique panel ids", owner = "ANALYSIS", evidence = "manifest")
    } else {
      findings[[length(findings) + 1]] <- new_finding(
        "panel_architecture", "INFO", "PASS",
        sprintf("Panel ids unique (%d panels)", nrow(mf)), evidence = "manifest")
    }
  }
}

## ---- 6. Global Coherence Audit（复用 R4）----
## R6: 区分"coherence evidence missing"与"coherence violation"
##   PUBLICATION_READY 模式: GFS 缺失 → FAIL（fail-closed, 进 PUBLICATION_PACKAGE）
##   其他模式:            GFS 缺失 → NOT_EVALUABLE（不把"没材料"当"图不对"）
state_file_name <- if (!is_blank(contract$global_state_file)) contract$global_state_file else "global_figure_state.yaml"
state_exists <- file.exists(file.path(directory, state_file_name))
if (!state_exists && audit_mode != "PUBLICATION_READY") {
  findings[[length(findings) + 1]] <- new_finding(
    "global_coherence", "MINOR", "NOT_EVALUABLE",
    sprintf("Global Figure State (%s) not supplied; coherence evidence missing (not a violation)", state_file_name),
    why = "Without the global state we cannot verify cross-panel coherence; absence of evidence is not evidence of a coherence violation",
    action = "Provide global_figure_state.yaml for PUBLICATION_READY mode or if cross-panel coherence must be verified",
    owner = "FIGURE_GENERATOR", evidence = "input inventory")
} else {
gc_checks <- tryCatch(run_global_coherence_audit(directory, repo_root), error = function(e) NULL)
if (!is.null(gc_checks)) {
  for (ch in gc_checks) {
    sev <- if (ch$status == "FAIL") "BLOCKER" else if (ch$status == "WARNING") "MAJOR" else "INFO"
    findings[[length(findings) + 1]] <- new_finding(
      "global_coherence", sev, ch$status, ch$detail,
      why = "Global figure coherence (state, dependency, fail-closed)",
      action = ch$advice, owner = "FIGURE_GENERATOR", evidence = "global_coherence_audit")
  }
}
}

## ---- 7. Visual Integrity Audit（A5: 区分"看图"与"读 metadata"）----
## visual_evidence_source: RASTER_REVIEW|VECTOR_REVIEW|VISION_MODEL_REVIEW|
##                         MANUAL_REVIEW|METADATA_ONLY|NONE
## QUICK_REVIEW 模式: 只有图也必须能看图 → 默认 RASTER_REVIEW 证据
visual_evidence <- toupper(trim_scalar(contract$visual_evidence_source))
if (audit_mode == "QUICK_REVIEW" && !nzchar(visual_evidence) && isTRUE(inventory$final_figure$available)) {
  visual_evidence <- "RASTER_REVIEW"
}
if (nzchar(visual_evidence) && visual_evidence %in% VISUAL_EVIDENCE_SOURCES) {
  img_status <- image_review_status(visual_evidence)
  if (img_status == "PASS") {
    ## QUICK_REVIEW 无声明式 visual QA 时, 用 raster 实测做初步判断
    if (audit_mode == "QUICK_REVIEW" && is.null(contract$visual_status)) {
      qr_metrics <- tryCatch(raster_color_metrics(
        file.path(directory, if (!is_blank(contract$final_figure_file)) contract$final_figure_file else "figure.png"),
        panel_count = 1L, script_dir = script_dir), error = function(e) NULL)
      if (!is.null(qr_metrics) && !is.null(qr_metrics$palette_cluster_count)) {
        nclust <- qr_metrics$palette_cluster_count
        accent <- if (is.null(qr_metrics$accent_area_fraction)) NA_real_ else qr_metrics$accent_area_fraction
        issues <- character()
        if (!is.na(nclust) && nclust > 80) issues <- c(issues, sprintf("palette fragmentation (%d distinct quantized colors)", nclust))
        if (!is.na(accent) && accent > 0.6) issues <- c(issues, sprintf("over-saturated accents (accent area %.2f)", accent))
        if (length(issues)) {
          findings[[length(findings) + 1]] <- new_finding(
            "visual", "MAJOR", "REVISE",
            sprintf("QUICK_REVIEW visual raster flags: %s", paste(issues, collapse = "; ")),
            why = "Raster measurement suggests visual noise/fragmentation without declared visual QA",
            action = "Run full SCIENTIFIC_FIGURE_AUDIT with manifest, or perform manual/vision visual review",
            owner = "MANUAL_REVIEW", evidence = "raster metrics (QUICK_REVIEW)")
        } else {
          findings[[length(findings) + 1]] <- new_finding(
            "visual", "INFO", "PASS",
            sprintf("QUICK_REVIEW raster baseline OK (palette clusters=%s)", nclust),
            evidence = "raster metrics (QUICK_REVIEW)")
        }
      } else {
        findings[[length(findings) + 1]] <- new_finding(
          "visual", "MINOR", "NOT_EVALUABLE",
          "QUICK_REVIEW could not measure the raster (no image or raster backend)",
          owner = "MANUAL_REVIEW", evidence = "raster metrics (QUICK_REVIEW)")
      }
    } else {
      ## 真实看图：采纳声明状态（若同时有 visual_status）
      vs <- toupper(trim_scalar(contract$visual_status))
      st <- if (vs %in% c("PASS", "REVISE", "FAIL")) vs else "PASS"
      sev <- if (st == "FAIL") "BLOCKER" else if (st == "REVISE") "MAJOR" else "INFO"
      findings[[length(findings) + 1]] <- new_finding(
        "visual", sev, st,
        sprintf("Visual image review (%s): %s", visual_evidence, st),
        why = "Visual QA based on actual image inspection",
        action = if (st == "PASS") "" else "Re-render and re-review",
        owner = "FIGURE_GENERATOR", evidence = sprintf("visual_evidence_source=%s", visual_evidence))
    }
  } else {
    findings[[length(findings) + 1]] <- new_finding(
      "visual", "MAJOR", "NOT_EVALUABLE",
      sprintf("Visual image review NOT_EVALUABLE (evidence source: %s)", visual_evidence),
      why = "Only metadata/contract declarations were reviewed; no actual image inspection. METADATA_ONLY cannot yield VISUAL_IMAGE_REVIEW=PASS",
      action = "Perform real raster/vector review (full size + thumbnail) and declare visual_evidence_source as a review type",
      owner = "MANUAL_REVIEW", evidence = sprintf("visual_evidence_source=%s", visual_evidence))
  }
} else if (isTRUE(inventory$final_figure$available)) {
  findings[[length(findings) + 1]] <- new_finding(
    "visual", "MAJOR", "NOT_EVALUABLE", "Visual image review NOT_EVALUABLE",
    why = "Raster exists but no visual_evidence_source declared; metadata-only PASS is not accepted (A5)",
    action = "Declare visual_evidence_source (RASTER_REVIEW / VISION_MODEL_REVIEW / MANUAL_REVIEW) after inspecting the rendered figure",
    owner = "MANUAL_REVIEW", evidence = "input inventory")
} else {
  findings[[length(findings) + 1]] <- new_finding(
    "visual", "MINOR", "NOT_EVALUABLE", "No final figure supplied",
    why = "Cannot perform visual review without a figure",
    owner = "MANUAL_REVIEW", evidence = "input inventory")
}

## ---- 8. Color System Audit（12 rules; shared standalone runtime）----
color_evidence_fallback <- if (audit_mode == "QUICK_REVIEW" && isTRUE(inventory$final_figure$available)) "RASTER_REVIEW" else ""
color_result <- run_color_audit_cli(directory, script_dir, default_evidence = color_evidence_fallback)
findings <- c(findings, color_findings_for_main_audit(color_result))
## QUICK_REVIEW 解释层: 无 contract 声明时, raster 实测的 palette 碎片化
## 直接映射为 COLOR 域 REVISE（不修改 COLOR 规则, 仅 QUICK_REVIEW 下报告解释）
if (audit_mode == "QUICK_REVIEW" && isTRUE(inventory$final_figure$available) && !nzchar(trim_scalar(contract$color_state.semantic_palette))) {
  qr_col <- tryCatch(raster_color_metrics(
    file.path(directory, if (!is_blank(contract$final_figure_file)) contract$final_figure_file else "figure.png"),
    panel_count = 1L, script_dir = script_dir), error = function(e) NULL)
  if (!is.null(qr_col) && !is.null(qr_col$palette_cluster_count) && qr_col$palette_cluster_count > 80) {
    findings[[length(findings) + 1]] <- new_finding(
      "color", "MAJOR", "REVISE",
      sprintf("QUICK_REVIEW color raster flags palette fragmentation (%d quantized colors, no declared semantic palette)",
              qr_col$palette_cluster_count),
      why = "High palette fragmentation without a declared semantic palette suggests rainbow/random coloring",
      action = "Declare a semantic palette or run full COLOR audit with contract metadata",
      owner = "FIGURE_GENERATOR", evidence = "raster metrics (QUICK_REVIEW)",
      rule_id = "QUICK_REVIEW-COLOR")
  }
}

## ---- 9. Delivery & Reproducibility Audit（复用 R4）----
del_checks <- tryCatch(run_delivery_qa(directory), error = function(e) NULL)
if (!is.null(del_checks)) {
  for (ch in del_checks) {
    sev <- if (ch$status == "FAIL") "BLOCKER" else if (ch$status == "WARNING") "MAJOR" else "INFO"
    findings[[length(findings) + 1]] <- new_finding(
      "delivery", sev, ch$status, ch$detail,
      why = "Delivery & reproducibility (source data, exports, metadata, provenance)",
      action = ch$advice, owner = "DELIVERY", evidence = "delivery_qa")
  }
}

## ---- 10. Gate Semantics: Figure Integrity / Publication Package / Readiness ----
## v0.4.3-alpha: readiness 由唯一函数 compute_publication_ready() fail-closed 计算,
## 报告 / JSON / 终端摘要 / 退出码四处共享同一结果。
verdict <- compute_verdict(findings)

## domain 状态（全 findings 计算, 供分层使用）
all_domains <- c("SCIENTIFIC", "STATISTICAL", "CLAIM_EVIDENCE", "PANEL_ARCHITECTURE",
                 "GLOBAL_COHERENCE", "VISUAL", "COLOR", "DELIVERY")
status_by_domain <- domain_status_from_findings(findings, all_domains)

## FIGURE_INTEGRITY: 只含"图本身对不对"的域
fi_status <- compute_figure_integrity(status_by_domain)

## PUBLICATION_PACKAGE: 只含"交付材料齐不齐"的域
## GLOBAL_COHERENCE 在缺 GFS 时（其他模式）为 NOT_EVALUABLE → 包层 INCOMPLETE
package_class <- classify_package_findings(findings)
package_status <- compute_publication_package(status_by_domain, package_class)

## 最终 PUBLICATION_READY（fail-closed, 唯一计算点）:
##   critical NOT_EVALUABLE → 永远 FALSE
##   PASS_WITH_WARNINGS 不阻止（non-blocking warnings）
##   REVISE/FAIL/INCOMPLETE 阻止
final_ready <- compute_publication_ready(fi_status, package_status,
                                         status_by_domain, audit_mode)

## Rule evidence 聚合（同一 rule 多 evidence 源合并）
aggregated_rules <- aggregate_rule_evidence(findings)

## repair routes（orchestrator 路由; domain-aware NEXT_ACTION）
routes <- repair_routes(findings, fi_status, package_status, status_by_domain)

## ---- 渲染（R6 报告结构）----
md <- render_audit_markdown(verdict, findings, inventory, directory,
                            audit_mode = audit_mode,
                            figure_integrity = fi_status,
                            package_status = package_status,
                            package_class = package_class,
                            aggregated_rules = aggregated_rules,
                            domain_status = status_by_domain,
                            publication_ready = final_ready)
md <- c(md, "| Gate | Status |", "|---|---|")
for (i in seq_along(all_domains)) {
  md <- c(md, sprintf("| %s | %s |", all_domains[i], status_by_domain[i]))
}
md <- c(md, "",
        sprintf("FIGURE_INTEGRITY = %s", fi_status),
        sprintf("PUBLICATION_PACKAGE = %s", package_status),
        sprintf("PUBLICATION_READY = %s", if (final_ready) "TRUE" else "FALSE"),
        sprintf("NEXT_ACTION = %s", routes$NEXT_ACTION),
        sprintf("AUDIT_VERSION = %s (contract %s)", SKILL_VERSION, AUDIT_CONTRACT_VERSION))
writeLines(md, report_path)
cat(sprintf("Audit report written: %s\n", report_path))

if (as_json) {
  json_path <- file.path(directory, "figure_audit.json")
  ## v0.4.3-alpha 新鲜度绑定: 记录所有被审计输入的 SHA-256（审计输出除外）。
  ## 编排器消费前重算; 文件被改动/删除 → AUDIT_STALE, 必须重审。
  audited <- tryCatch(
    compute_audited_artifacts(directory,
                              extra_exclude_basenames = basename(report_path)),
    error = function(e) {
      cat(sprintf("WARNING: audited_artifacts binding unavailable: %s\n",
                  conditionMessage(e)), file = stderr())
      list()
    })
  write_audit_json(verdict, findings, inventory, json_path,
                   audit_mode = audit_mode,
                   figure_integrity = fi_status,
                   package_status = package_status,
                   aggregated_rules = aggregated_rules,
                   routes = routes,
                   publication_ready = final_ready,
                   domain_status = status_by_domain,
                   audited_artifacts = audited)
  cat(sprintf("Audit JSON written: %s\n", json_path))
}

## 终端摘要
cat("\n--- Potato Figure Audit Summary ---\n")
cat(sprintf("%-26s %s\n", "AUDIT_MODE", audit_mode))
for (i in seq_along(all_domains)) {
  cat(sprintf("%-26s %s\n", all_domains[i], status_by_domain[i]))
}
cat(sprintf("%-26s %s\n", "FIGURE_INTEGRITY", fi_status))
cat(sprintf("%-26s %s\n", "PUBLICATION_PACKAGE", package_status))
cat(sprintf("%-26s %s\n", "PUBLICATION_READY", if (final_ready) "TRUE" else "FALSE"))
cat(sprintf("%-26s %s\n", "NEXT_ACTION", routes$NEXT_ACTION))

## ---- v0.4.3-alpha 退出码 ----
## PUBLICATION_READY（enforcement mode）: 0 = gate passed; 2 = gate not satisfied
## 其他模式: 0 = audit successfully executed（verdict 不影响退出码）
if (audit_mode == "PUBLICATION_READY" && !isTRUE(final_ready)) EXIT_GATE_NOT_SATISFIED else EXIT_OK
}

exit_code <- tryCatch(run_audit(), error = function(e) {
  cat(sprintf("INTERNAL ERROR: %s\n", conditionMessage(e)), file = stderr())
  EXIT_INTERNAL
})
quit(status = exit_code)
