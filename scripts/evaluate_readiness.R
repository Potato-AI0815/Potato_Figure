#!/usr/bin/env Rscript
# evaluate_readiness.R — Potato Figure Audit v0.4.1-alpha R2
# A9 修复：区分 AUDIT_COMPLETED / AUDIT_COVERAGE / PUBLICATION_READY。
#
# 关键规则：
#   - AUDIT_COMPLETED = TRUE 只要审计本身跑完（无论材料齐不齐）
#   - AUDIT_COVERAGE  = 各 publication-critical domain 的材料/证据覆盖
#   - PUBLICATION_READY = TRUE 仅当所有 publication-critical domains 均为 PASS
#     （允许少量 INFO/MINOR）；存在 FAIL/BLOCKER/unresolved MAJOR/
#     critical NOT_EVALUABLE → 不得 TRUE
#
# 用法: Rscript evaluate_readiness.R <figure_dir> [--json]

script_dir <- dirname(normalizePath(sub("^--file=", "",
  commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][1])))
source(file.path(script_dir, "lib", "qa_common.R"))
source(file.path(script_dir, "lib", "audit_core.R"))
source(file.path(script_dir, "lib", "color_integration.R"))

args <- commandArgs(trailingOnly = TRUE)
directory <- if (length(args) && !startsWith(args[1], "--")) args[1] else "."
as_json <- "--json" %in% args

## ---- 收集 findings（与 audit_figure.R 相同的 9 层逻辑的轻量版） ----
findings <- list()
contract_path <- file.path(directory, "figure_contract.yaml")
contract <- if (file.exists(contract_path)) tryCatch(read_flat_yaml(contract_path), error = function(e) list()) else list()
inventory <- inventory_inputs(directory, contract)

## 各 publication-critical domain 的输入覆盖
## SCIENTIFIC/STATISTICAL 需要 manifest（统计声明列已含 test/n/pairing，
## 不要求独立 statistical_metadata 文件——R1 兼容）；CLAIM_EVIDENCE 需要
## contract claim + manifest；VISUAL 需要真实视觉证据（A5）；
## DELIVERY 需要 manifest + metadata
domain_requires <- list(
  SCIENTIFIC = c("figure_manifest"),
  STATISTICAL = c("figure_manifest"),
  CLAIM_EVIDENCE = c("figure_manifest"),
  PANEL_ARCHITECTURE = c("figure_manifest"),
  GLOBAL_COHERENCE = c("figure_manifest"),
  VISUAL = c("final_figure"),
  COLOR = c("final_figure"),
  DELIVERY = c("figure_manifest")
)

## 判定各 domain 状态：真实运行审计（scientific/delivery/global 直接调用冻结层）
domain_status <- list()
source(file.path(script_dir, "lib", "scientific_audit_core.R"))
source(file.path(script_dir, "lib", "delivery_qa_core.R"))
source(file.path(script_dir, "lib", "global_coherence_core.R"))
sc_checks <- tryCatch(run_scientific_audit(directory), error = function(e) NULL)
if (!is.null(sc_checks)) {
  st <- unique(vapply(sc_checks, function(ch) ch$status, character(1)))
  domain_status[["SCIENTIFIC"]] <- if (any(st == "FAIL")) "FAIL"
    else if (any(st == "WARNING")) "REVISE" else "PASS"
}
del_checks <- tryCatch(run_delivery_qa(directory), error = function(e) NULL)
if (!is.null(del_checks)) {
  st <- unique(vapply(del_checks, function(ch) ch$status, character(1)))
  domain_status[["DELIVERY"]] <- if (any(st == "FAIL")) "FAIL"
    else if (any(st == "WARNING")) "REVISE" else "PASS"
}
gc_checks <- tryCatch(run_global_coherence_audit(directory, normalizePath(file.path(script_dir, ".."), mustWork = TRUE)),
                      error = function(e) NULL)
if (!is.null(gc_checks)) {
  st <- unique(vapply(gc_checks, function(ch) ch$status, character(1)))
  ## 无 global_figure_state.yaml → 该审计会 FAIL "Missing global state"；
  ## 但 R1 纯科学场景不要求 global state（R4 才引入）→ 标记 NOT_APPLICABLE 不阻塞
  state_req <- file.path(directory, if (!is_blank(contract$global_state_file)) contract$global_state_file else "global_figure_state.yaml")
  if (!file.exists(state_req)) {
    domain_status[["GLOBAL_COHERENCE"]] <- "NOT_APPLICABLE"
  } else {
    domain_status[["GLOBAL_COHERENCE"]] <- if (any(st == "FAIL")) "FAIL"
      else if (any(st == "WARNING")) "REVISE" else "PASS"
  }
}
color_result <- run_color_audit_cli(directory, script_dir)
domain_status[["COLOR"]] <- color_readiness_status(color_result)
## figure_audit.json 补充其他 domain（若存在）
audit_json_path <- file.path(directory, "figure_audit.json")
if (file.exists(audit_json_path)) {
  j <- tryCatch(jsonlite::fromJSON(audit_json_path, simplifyVector = FALSE), error = function(e) NULL)
  if (!is.null(j) && !is.null(j$findings)) {
    for (f in j$findings) {
      d <- toupper(f$domain)
      st <- f$status
      if (is.null(domain_status[[d]]) || st == "FAIL") domain_status[[d]] <- st
    }
  }
}

## 每个 critical domain 的最终状态
critical_domains <- c("SCIENTIFIC", "STATISTICAL", "CLAIM_EVIDENCE",
                      "PANEL_ARCHITECTURE", "GLOBAL_COHERENCE", "VISUAL", "COLOR", "DELIVERY")
status_out <- character()
for (d in critical_domains) {
  ## 材料覆盖检查
  req <- domain_requires[[d]]
  covered <- all(vapply(req, function(item) isTRUE(inventory[[item]]$available), logical(1)))
  ## VISUAL 特殊：需要真实视觉证据（A5），仅 contract visual_status 不算；
  ## 兼容 R1：若存在 visual_qa.tsv 且内容完整（10 domains 全 PASS）则视为 RASTER/MANUAL 级证据
  if (d == "VISUAL") {
    vqa_path <- file.path(directory, "visual_qa.tsv")
    vqa_status <- NULL
    if (file.exists(vqa_path)) {
      vqa <- tryCatch(read.delim(vqa_path, stringsAsFactors = FALSE, check.names = FALSE), error = function(e) NULL)
      if (!is.null(vqa) && all(c("domain", "status") %in% names(vqa)) && nrow(vqa) >= 8) {
        dnames <- trimws(as.character(vqa$domain))
        ## 重复 domain / 缺必需域 → 结构不合法 → NOT_REVIEWED（R1 契约）
        if (anyDuplicated(dnames)) {
          vqa_status <- "NOT_REVIEWED"
        } else {
          sts <- toupper(trimws(vqa$status))
          vqa_status <- if (any(sts == "FAIL")) "FAIL"
                        else if (any(sts == "REVISE")) "REVISE"
                        else if (any(sts == "NOT_REVIEWED")) "NOT_REVIEWED"
                        else "PASS"
        }
      }
    }
    visual_evidence <- !is_blank(contract$visual_evidence_source) &&
      toupper(contract$visual_evidence_source) %in% c("RASTER_REVIEW", "VECTOR_REVIEW", "VISION_MODEL_REVIEW", "MANUAL_REVIEW")
    has_figure <- isTRUE(inventory$final_figure$available)
    if (has_figure && !is.null(vqa_status)) {
      ## 有真实图 + visual_qa.tsv → 采用实际状态（REVISE/FAIL 如实报告）
      status_out[[d]] <- vqa_status
      next
    } else if (has_figure && visual_evidence) {
      status_out[[d]] <- "PASS"
      next
    } else {
      ## 无真实看图证据 → NOT_EVALUABLE（A5 铁律）
      status_out[[d]] <- "NOT_EVALUABLE"
      next
    }
  }
  ## 真实审计结果优先（scientific/delivery/global 已跑）；否则按材料覆盖判定
  if (!is.null(domain_status[[d]])) {
    status_out[[d]] <- domain_status[[d]]
  } else {
    st <- if (!covered) "NOT_EVALUABLE" else "PASS"
    status_out[[d]] <- st
  }
}
## ---- 判定 ----
audit_completed <- TRUE  # 审计执行本身完成
## R6.1: WARNING 是 non-blocking（MINOR 不升级为 REVISE）;
## NOT_EVALUABLE/NOT_REVIEWED 仍保持 fail-closed（critical evidence 缺失不得放行）
coverage_ok <- all(status_out %in% c("PASS", "WARNING", "NOT_APPLICABLE")) &&
  !any(status_out %in% c("NOT_EVALUABLE", "NOT_REVIEWED"))
blockers <- any(status_out == "FAIL")
unresolved_major <- any(status_out %in% c("REVISE"))
publication_ready <- !blockers && !unresolved_major && coverage_ok

## ---- R6: 分层状态 ----
fi_domains <- c("SCIENTIFIC", "STATISTICAL", "CLAIM_EVIDENCE",
                "PANEL_ARCHITECTURE", "VISUAL", "COLOR")
pkg_domains <- c("GLOBAL_COHERENCE", "DELIVERY")
fi_status <- if (any(status_out[fi_domains] == "FAIL")) "FAIL" else
  if (any(status_out[fi_domains] == "REVISE")) "REVISE" else
  if (any(status_out[fi_domains] %in% c("NOT_EVALUABLE", "NOT_REVIEWED"))) "PASS_WITH_LIMITED_EVIDENCE" else "PASS"
pkg_status <- if (any(status_out[pkg_domains] == "FAIL")) "FAIL" else
  if (any(status_out[pkg_domains] %in% c("NOT_EVALUABLE", "NOT_REVIEWED", "NOT_APPLICABLE"))) "INCOMPLETE" else "PASS"

## 输出
if (!as_json) {
  cat("=== Readiness Evaluation ===\n")
  for (d in critical_domains) cat(sprintf("%-22s %s\n", d, status_out[[d]]))
  cat(sprintf("%-22s %s\n", "AUDIT_COMPLETED", if (audit_completed) "TRUE" else "FALSE"))
  cat(sprintf("%-22s %s\n", "AUDIT_COVERAGE", if (coverage_ok) "COMPLETE" else "INCOMPLETE"))
  cat(sprintf("%-22s %s\n", "FIGURE_INTEGRITY", fi_status))
  cat(sprintf("%-22s %s\n", "PUBLICATION_PACKAGE", pkg_status))
  cat(sprintf("%-22s %s\n", "PUBLICATION_READY", if (publication_ready) "TRUE" else "FALSE"))
} else {
  domain_json <- paste(sprintf('"%s":"%s"', critical_domains, status_out[critical_domains]), collapse = ",")
  body <- c(
    sprintf('"AUDIT_COMPLETED":%s', if (audit_completed) "true" else "false"),
    sprintf('"AUDIT_COVERAGE":"%s"', if (coverage_ok) "COMPLETE" else "INCOMPLETE"),
    sprintf('"PUBLICATION_READY":%s', if (publication_ready) "true" else "false"),
    sprintf('"publication_ready":%s', if (publication_ready) "true" else "false"),
    sprintf('"figure_integrity":"%s"', fi_status),
    sprintf('"publication_package":"%s"', pkg_status),
    ## 兼容旧字段（R1/R4 测试契约）：
    sprintf('"global_coherence_status":"%s"', status_out[["GLOBAL_COHERENCE"]]),
    sprintf('"visual_status":"%s"', status_out[["VISUAL"]]),
    sprintf('"visual_qa_interface":"%s"', if (status_out[["VISUAL"]] %in% c("NOT_EVALUABLE", "NOT_REVIEWED")) "NOT_READY" else "READY"),
    sprintf('"domains":{%s}', domain_json)
  )
  cat("{", paste(body, collapse = ","), "}\n")
}

quit(status = if (publication_ready) 0 else 1)
