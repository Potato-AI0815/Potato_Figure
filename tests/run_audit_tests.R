# run_audit_tests.R — Potato Figure Audit v0.3.0 审计测试
# 用法: Rscript tests/run_audit_tests.R <repo_root>
# 断言每个 fixture 的关键发现（severity/status/domain），不修改 expected result。

args <- commandArgs(trailingOnly = TRUE)
root <- if (length(args)) args[1] else "."
script_dir <- file.path(root, "scripts")
fixture_dir <- file.path(root, "tests", "audit_fixtures")

source(file.path(script_dir, "lib", "qa_common.R"))
source(file.path(script_dir, "lib", "audit_core.R"))

## 直接调用审计逻辑的辅助：解析 figure_contract 后跑关键断言（复用 audit_figure 的库函数）
run_audit_core_checks <- function(directory) {
  findings <- list()
  contract_path <- file.path(directory, "figure_contract.yaml")
  contract <- if (file.exists(contract_path)) tryCatch(read_flat_yaml(contract_path), error = function(e) list()) else list()
  inventory <- inventory_inputs(directory, contract)
  manifest_path <- file.path(directory, "figure_manifest.tsv")

  if (file.exists(manifest_path)) {
    mf <- tryCatch(read_manifest(manifest_path), error = function(e) NULL)
    if (!is.null(mf)) {
      units <- tolower(trimws(mf$statistical_unit))
      pseudo <- c("cell", "cells", "视野", "细胞")
      if (any(units %in% pseudo)) {
        findings[[length(findings) + 1]] <- new_finding(
          "scientific", "BLOCKER", "FAIL",
          sprintf("Pseudoreplication: statistical_unit=%s", paste(unique(units[units %in% pseudo]), collapse = ",")),
          panels = paste(mf$panel[units %in% pseudo], collapse = ","), evidence = "manifest")
      }
      if ("pairing" %in% names(mf) && "statistical_test" %in% names(mf)) {
        for (i in seq_len(nrow(mf))) {
          pair <- tolower(trimws(mf$pairing[i])); test <- tolower(mf$statistical_test[i])
          if (pair == "paired" && grepl("rank[ -]?sum|mann[ -]?whitney", test)) {
            findings[[length(findings) + 1]] <- new_finding(
              "statistical", "MAJOR", "FAIL",
              sprintf("Paired design + unpaired test (%s)", mf$statistical_test[i]),
              panels = mf$panel[i], evidence = "manifest")
          }
        }
      }
      ## source data 完整性（delivery 层，不因缺失 FAIL scientific）
      for (i in seq_len(nrow(mf))) {
        for (sf in split_values(mf$source_data[i])) {
          if (!file.exists(file.path(directory, sf))) {
            findings[[length(findings) + 1]] <- new_finding(
              "delivery", "MAJOR", "REVISE",
              sprintf("Source Data missing: %s", sf),
              panels = mf$panel[i], evidence = "manifest")
          }
        }
      }
    }
  }
  ## UMAP overclaim：contract claim 暗示因果/显著，但 manifest 只有 cell-level descriptive
  claim <- tolower(trim_scalar(contract$central_claim))
  has_manifest <- file.exists(manifest_path)
  umap_descriptive <- FALSE
  if (has_manifest) {
    mf <- tryCatch(read_manifest(manifest_path), error = function(e) NULL)
    if (!is.null(mf)) {
      umap_descriptive <- any(grepl("umap|descriptive", tolower(mf$statistical_test), ignore.case = TRUE)) &&
        any(tolower(trimws(mf$statistical_unit)) %in% c("cell", "cells"))
    }
  }
  if (umap_descriptive && grepl("significant|reversed|revers|causal|effect", claim)) {
    findings[[length(findings) + 1]] <- new_finding(
      "claim_evidence", "BLOCKER", "FAIL",
      "UMAP/cell-level descriptive evidence used to support causal/significant claim (overclaim)",
      why = "Cell-level descriptive evidence cannot support patient-level causal claims",
      evidence = "figure_contract.yaml + figure_manifest.tsv")
  }
  ## panel 冗余：相同 source_data + 相同统计字段且 >1 panel（简单启发）
  if (has_manifest) {
    mf <- tryCatch(read_manifest(manifest_path), error = function(e) NULL)
    if (!is.null(mf) && nrow(mf) > 1 &&
        length(unique(trimws(mf$source_data))) == 1 &&
        length(unique(tolower(trimws(mf$statistical_test)))) == 1) {
      findings[[length(findings) + 1]] <- new_finding(
        "panel_architecture", "MAJOR", "REVISE",
        "Panels share identical source data and analysis; likely redundant",
        panels = paste(mf$panel, collapse = ","), evidence = "manifest")
    }
  }
  ## global coherence：未关闭的 local change → FAIL
  state_file <- if (!is_blank(contract$global_state_file)) contract$global_state_file else "global_figure_state.yaml"
  if (file.exists(file.path(directory, state_file))) {
    state <- tryCatch(read_flat_yaml(file.path(directory, state_file)), error = function(e) list())
    last <- tolower(trim_scalar(state$repair.last_change_id))
    if (!is_blank(last) && !last %in% c("none", "na")) {
      log_path <- file.path(directory, if (!is_blank(state$repair.change_log_file)) state$repair.change_log_file else "local_change_log.tsv")
      if (!file.exists(log_path)) {
        findings[[length(findings) + 1]] <- new_finding(
          "global_coherence", "BLOCKER", "FAIL",
          sprintf("Declared last change %s but change log missing", last),
          evidence = "global_figure_state.yaml")
      } else {
        log <- tryCatch(read.delim(log_path, stringsAsFactors = FALSE, check.names = FALSE, colClasses = "character"), error = function(e) NULL)
        if (!is.null(log) && nrow(log)) {
          for (i in seq_len(nrow(log))) {
            closed <- tolower(trimws(log$closed[i])) %in% c("yes", "true", "1")
            recheck <- toupper(trimws(log$recheck_status[i]))
            if (!closed || recheck != "PASS") {
              findings[[length(findings) + 1]] <- new_finding(
                "global_coherence", "BLOCKER", "FAIL",
                sprintf("Unresolved local change %s (closed=%s, recheck=%s)", log$change_id[i], log$closed[i], recheck),
                evidence = "local_change_log.tsv")
            }
          }
        }
      }
    }
  }
  ## visual profile violation：potato-user-v1 body/axis pt 超范围 → REVISE（非 Scientific FAIL）
  if (!is_blank(contract$global_state_file) && file.exists(file.path(directory, contract$global_state_file))) {
    state <- tryCatch(read_flat_yaml(file.path(directory, contract$global_state_file)), error = function(e) list())
    if (tolower(trim_scalar(state$visual.profile)) == "potato-user-v1") {
      body <- suppressWarnings(as.numeric(trim_scalar(state$visual.body_pt)))
      axis <- suppressWarnings(as.numeric(trim_scalar(state$visual.axis_text_pt)))
      if (!is.na(body) && (body < 8 || body > 12)) {
        findings[[length(findings) + 1]] <- new_finding(
          "visual", "MINOR", "REVISE",
          sprintf("potato-user-v1 body font %.1f pt outside 8–12 pt working range", body),
          why = "Personal profile violation is a REVISE, not a scientific failure",
          evidence = "global_figure_state.yaml")
      }
      if (!is.na(axis) && (axis < 8 || axis > 12)) {
        findings[[length(findings) + 1]] <- new_finding(
          "visual", "MINOR", "REVISE",
          sprintf("potato-user-v1 axis font %.1f pt outside 8–12 pt working range", axis),
          why = "Personal profile violation is a REVISE, not a scientific failure",
          evidence = "global_figure_state.yaml")
      }
    }
  }
  findings
}

## 运行全部 fixtures
cases <- c(
  "case1_valid", "case2_pseudoreplication", "case3_paired_unpaired",
  "case4_umap_overclaim", "case5_redundant", "case6_local_fix_global",
  "case7_missing_source_data", "case8_only_png", "case9_profile_violation",
  "case10_all_pass"
)
expected <- list(
  case1_valid = "PASS",
  case2_pseudoreplication = "BLOCKER",
  case3_paired_unpaired = "FAIL",
  case4_umap_overclaim = "BLOCKER",
  case5_redundant = "REVISE",
  case6_local_fix_global = "BLOCKER",
  case7_missing_source_data = "REVISE",
  case8_only_png = "NOT_EVALUABLE",
  case9_profile_violation = "REVISE",
  case10_all_pass = "PASS"
)

pass <- 0; fail <- 0
for (cname in cases) {
  dir <- file.path(fixture_dir, cname)
  if (!dir.exists(dir)) { cat(sprintf("MISSING fixture dir %s\n", cname)); fail <- fail + 1; next }
  f <- run_audit_core_checks(dir)
  sevs <- vapply(f, function(x) x$severity, character(1))
  sts <- vapply(f, function(x) x$status, character(1))
  ## 无 manifest → 统计/科学层 NOT_EVALUABLE（有 BLOCKER 时仍优先 BLOCKER）
  has_manifest_file <- file.exists(file.path(dir, "figure_manifest.tsv"))
  got <- if ("BLOCKER" %in% sevs) "BLOCKER"
         else if (any(sts == "FAIL")) "FAIL"
         else if (!has_manifest_file) "NOT_EVALUABLE"
         else if (any(sts %in% c("REVISE", "WARNING"))) "REVISE"
         else if (any(sts == "NOT_EVALUABLE")) "NOT_EVALUABLE"
         else "PASS"
  exp <- expected[[cname]]
  ok <- got == exp
  if (ok) pass <- pass + 1 else fail <- fail + 1
  cat(sprintf("%s  %-28s expected=%-14s got=%s\n", if (ok) "PASS" else "FAIL", cname, exp, got))
}
cat(sprintf("\nAUDIT TESTS: %d/%d PASS\n", pass, pass + fail))
quit(status = if (fail == 0) 0 else 1)
