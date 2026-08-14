#!/usr/bin/env Rscript
# run_r6_real_regression.R — R6 三版真实图回归（真实调用 audit_figure.R 主入口）
# 验证 spec 第五十一条预期矩阵:
#   A: QUICK_REVIEW, VISUAL/COLOR=REVISE, SCIENTIFIC=NE, PUBLICATION_READY=FALSE
#   C: SCIENTIFIC=FAIL, COLOR-13=REVISE/MAJOR, FI=FAIL, PKG=INCOMPLETE, READY=FALSE
#   B: SCIENTIFIC=PASS, COLOR-13=PASS, FI=PASS, PKG=INCOMPLETE, READY=FALSE

script_dir <- dirname(normalizePath(sub("^--file=", "",
  commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][1])))
repo_dir <- dirname(script_dir)   # tests/ 的上级 = skill 根
auditor <- file.path(repo_dir, "scripts", "audit_figure.R")
rscript <- file.path(R.home("bin"), "Rscript.exe")
if (!file.exists(rscript)) rscript <- "Rscript"

run_audit <- function(dir, mode = "") {
  if (!file.exists(auditor)) stop("auditor not found: ", auditor)
  cmd <- paste(shQuote(rscript), shQuote(auditor), shQuote(dir), "--json")
  if (nzchar(mode)) cmd <- paste(shQuote(rscript), shQuote(auditor), shQuote(dir), "--json", "--mode", shQuote(mode))
  out <- tryCatch(system(cmd, intern = TRUE), error = function(e) character())
  ## 删除旧 JSON, 确保结果是本次真实运行产生的
  json_path <- file.path(dir, "figure_audit.json")
  unlink(json_path)
  system(cmd, intern = FALSE)
  if (!file.exists(json_path)) return(NULL)
  tryCatch(jsonlite::fromJSON(json_path, simplifyVector = FALSE), error = function(e) NULL)
}

pass <- 0L; fail <- 0L; failures <- character()
check <- function(name, cond, detail = "") {
  if (isTRUE(cond)) { pass <<- pass + 1L; cat(sprintf("  [PASS] %s\n", name)) }
  else { fail <<- fail + 1L; failures <<- c(failures, sprintf("%s: %s", name, detail)); cat(sprintf("  [FAIL] %s  %s\n", name, detail)) }
}

base <- file.path(dirname(script_dir), "tests", "regression_three_tier")
## 允许通过命令行覆盖审计输入目录（本地开发时可指向其他 audit_inputs 目录）
args <- commandArgs(trailingOnly = TRUE)
if (length(args) && nzchar(args[1]) && dir.exists(args[1])) base <- args[1]
cat("=== REAL FIGURE REGRESSION (A/C/B) ===\n")

## ---- B: 完整 workflow ----
b <- run_audit(file.path(base, "B_workflow"))
if (!is.null(b)) {
  check("B: mode SCIENTIFIC_FIGURE_AUDIT", b$audit_mode == "SCIENTIFIC_FIGURE_AUDIT", b$audit_mode)
  sci_b <- any(vapply(b$findings, function(f) f$domain == "scientific" && f$status == "FAIL", logical(1)))
  check("B: no scientific FAIL", !sci_b)
  ## R6.1 tiered contract: figure_integrity / publication_package are nested {status: ...}
  fi_b  <- if (is.list(b$figure_integrity))     b$figure_integrity$status     else b$figure_integrity
  pkg_b <- if (is.list(b$publication_package))  b$publication_package$status  else b$publication_package
  check("B: tiered contract present", is.list(b$figure_integrity) && is.list(b$publication_package),
        sprintf("contract_version=%s", as.character(b$contract_version)))
  check("B: FIGURE_INTEGRITY PASS", identical(fi_b, "PASS"), fi_b)
  check("B: PUBLICATION_PACKAGE INCOMPLETE", identical(pkg_b, "INCOMPLETE"), pkg_b)
  check("B: PUBLICATION_READY FALSE", identical(b$publication_ready, FALSE), as.character(b$publication_ready))
  ar_b <- b$aggregated_rules
  if (is.list(ar_b) && length(ar_b)) {
    c13_b <- if ("COLOR-13" %in% names(ar_b)) ar_b[["COLOR-13"]]$final_status else NA_character_
    c14_b <- if ("COLOR-14" %in% names(ar_b)) ar_b[["COLOR-14"]]$final_status else NA_character_
    check("B: COLOR-13 PASS", identical(c13_b, "PASS"), c13_b)
    check("B: COLOR-14 PASS", identical(c14_b, "PASS"), c14_b)
  } else {
    check("B: COLOR-13 PASS (aggregated rules present)", FALSE, "no aggregated_rules")
  }
  rt_b <- b$repair_routes
  check("B: NEXT_ACTION COMPLETE_DELIVERY",
        is.list(rt_b) && identical(rt_b$NEXT_ACTION, "COMPLETE_DELIVERY"),
        if (is.list(rt_b)) rt_b$NEXT_ACTION else "NA")
} else {
  check("B: audit ran", FALSE, "no JSON")
}

## ---- C: nature-figure only ----
c1 <- run_audit(file.path(base, "C_nature_only"))
if (!is.null(c1)) {
  sci_c <- any(vapply(c1$findings, function(f) f$domain == "scientific" && f$status == "FAIL", logical(1)))
  check("C: SCIENTIFIC FAIL", sci_c)
  fi_c  <- if (is.list(c1$figure_integrity))    c1$figure_integrity$status    else c1$figure_integrity
  pkg_c <- if (is.list(c1$publication_package)) c1$publication_package$status else c1$publication_package
  check("C: FIGURE_INTEGRITY FAIL", identical(fi_c, "FAIL"), fi_c)
  check("C: PUBLICATION_PACKAGE INCOMPLETE", identical(pkg_c, "INCOMPLETE"), pkg_c)
  check("C: PUBLICATION_READY FALSE", identical(c1$publication_ready, FALSE))
  ar_c <- c1$aggregated_rules
  if (is.list(ar_c) && length(ar_c) && "COLOR-13" %in% names(ar_c)) {
    c13_c <- ar_c[["COLOR-13"]]$final_status
    check("C: COLOR-13 REVISE/MAJOR", c13_c %in% c("REVISE", "MAJOR", "FAIL"), c13_c)
  } else {
    check("C: COLOR-13 present", FALSE, "no COLOR-13 in aggregated rules")
  }
} else {
  check("C: audit ran", FALSE, "no JSON")
}

## ---- A: 随手画（只有图, QUICK_REVIEW）----
a1 <- run_audit(file.path(base, "A_sloppy"))
if (!is.null(a1)) {
  check("A: mode QUICK_REVIEW", a1$audit_mode == "QUICK_REVIEW", a1$audit_mode)
  check("A: SCIENTIFIC NOT_EVALUABLE",
        any(vapply(a1$findings, function(f) f$domain == "scientific" && f$status == "NOT_EVALUABLE", logical(1))))
  ## 从 findings 聚合 VISUAL/COLOR
  vis_fail <- any(vapply(a1$findings, function(f) f$domain == "visual" && f$status %in% c("FAIL", "REVISE"), logical(1)))
  col_fail <- any(vapply(a1$findings, function(f) f$domain == "color" && f$status %in% c("FAIL", "REVISE"), logical(1)))
  check("A: VISUAL REVISE (raster flags)", vis_fail)
  check("A: COLOR REVISE (fragmentation)", col_fail)
  check("A: PUBLICATION_READY FALSE", identical(a1$publication_ready, FALSE))
} else {
  check("A: audit ran", FALSE, "no JSON")
}

cat("\n=== RESULTS ===\n")
cat(sprintf("PASS: %d  FAIL: %d\n", pass, fail))
if (length(failures)) { cat("FAILURES:\n"); for (x in failures) cat(" -", x, "\n") }
quit(status = if (fail == 0L) 0 else 1)
