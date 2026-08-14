#!/usr/bin/env Rscript
# run_main_entry_tests.R — v0.4.3-alpha 主入口契约测试（真实 subprocess 调用）
# 验证对象: scripts/audit_figure.R 作为独立进程的行为 ——
#   1) 退出码契约:
#      QUICK_REVIEW / SCIENTIFIC_FIGURE_AUDIT: exit 0 = 审计执行成功
#      PUBLICATION_READY: exit 0 = gate 通过; exit 2 = gate 未满足
#      所有模式: exit 3 = 非法输入; exit 4 = 内部错误
#   2) R6.1 分层 JSON 契约: figure_integrity.status / publication_package.status /
#      publication_ready / repair_routes.NEXT_ACTION / contract_version / version
#   3) fail-closed: critical 域 NOT_EVALUABLE 时 publication_ready 必为 false
#   4) PASS_WITH_WARNINGS 仍可 READY (non-blocking warnings)
#   5) 敌对路径（空格/引号/分号/unicode）下主入口仍正常工作
# 原则: 行为测试 —— 真实运行主入口, 检查真实输出（禁止字符串 grep 伪测试）

script_dir <- dirname(normalizePath(sub("^--file=", "",
  commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][1])))
repo_dir <- dirname(script_dir)
auditor <- file.path(repo_dir, "scripts", "audit_figure.R")
rscript <- file.path(R.home("bin"), "Rscript.exe")
if (!file.exists(rscript)) rscript <- "Rscript"

NEXT_ACTION_VOCAB <- c("COMPLETE_DELIVERY", "REVISE_FIGURE", "RETURN_TO_STATISTICS",
                       "RETURN_TO_CLAIM_EVIDENCE", "FIX_DELIVERY",
                       "HUMAN_REVIEW_REQUIRED", "NONE")

run_entry <- function(dir, mode = "") {
  ## 先删除旧 JSON, 确保读到的是本次运行的产物
  json_path <- file.path(dir, "figure_audit.json")
  unlink(json_path)
  args <- c("--vanilla", shQuote(auditor), shQuote(dir), "--json")
  if (nzchar(mode)) args <- c(args, "--mode", shQuote(mode))
  rc <- suppressWarnings(system2(rscript, args, stdout = FALSE, stderr = FALSE))
  payload <- NULL
  if (file.exists(json_path)) {
    payload <- tryCatch(jsonlite::fromJSON(json_path, simplifyVector = FALSE),
                        error = function(e) NULL)
  }
  list(exit = rc, json = payload)
}

tier <- function(payload, key) {
  ## 读取分层契约字段; 兼容旧扁平字符串
  v <- payload[[key]]
  if (is.list(v)) v$status else v
}

pass <- 0L; fail <- 0L; failures <- character()
check <- function(name, cond, detail = "") {
  if (isTRUE(cond)) { pass <<- pass + 1L; cat(sprintf("  [PASS] %s\n", name)) }
  else { fail <<- fail + 1L; failures <<- c(failures, sprintf("%s: %s", name, detail))
         cat(sprintf("  [FAIL] %s  %s\n", name, detail)) }
}

fixtures <- file.path(script_dir, "main_entry_fixtures")
ready_dir <- file.path(fixtures, "ready_case")
warn_dir  <- file.path(fixtures, "warnings_case")
three_tier <- file.path(script_dir, "regression_three_tier")
audit_fix  <- file.path(script_dir, "audit_fixtures")

cat("=== MAIN ENTRY CONTRACT TESTS (v0.4.3-alpha) ===\n")

## ---- M1: READY case → PUBLICATION_READY 模式 exit 0, ready TRUE ----
m1 <- run_entry(ready_dir, "PUBLICATION_READY")
check("M1: exit 0 (gate passed)", m1$exit == 0L, sprintf("exit=%s", m1$exit))
check("M1: JSON written", !is.null(m1$json))
if (!is.null(m1$json)) {
  check("M1: publication_ready TRUE", identical(m1$json$publication_ready, TRUE),
        as.character(m1$json$publication_ready))
  check("M1: figure_integrity.status PASS", identical(tier(m1$json, "figure_integrity"), "PASS"),
        as.character(tier(m1$json, "figure_integrity")))
  check("M1: publication_package.status PASS", identical(tier(m1$json, "publication_package"), "PASS"),
        as.character(tier(m1$json, "publication_package")))
  check("M1: contract_version R6.1", identical(m1$json$contract_version, "R6.1"),
        as.character(m1$json$contract_version))
  check("M1: version 0.4.3-alpha", identical(m1$json$version, "0.4.3-alpha"),
        as.character(m1$json$version))
  na <- m1$json$repair_routes$NEXT_ACTION
  check("M1: NEXT_ACTION in vocabulary", na %in% NEXT_ACTION_VOCAB, as.character(na))
}

## ---- M2: READY case 默认模式 = SCIENTIFIC_FIGURE_AUDIT → exit 0 ----
m2 <- run_entry(ready_dir)
check("M2: default mode exit 0 (audit executed)", m2$exit == 0L, sprintf("exit=%s", m2$exit))
if (!is.null(m2$json)) {
  check("M2: default mode SCIENTIFIC_FIGURE_AUDIT",
        identical(m2$json$audit_mode, "SCIENTIFIC_FIGURE_AUDIT"),
        as.character(m2$json$audit_mode))
}

## ---- M3: fail-closed —— critical NOT_EVALUABLE 时 ready 必为 FALSE ----
## case10_all_pass: 声明层全部 PASS, 但 figure.png 为文本占位 → VISUAL/COLOR 无法实测
## → critical 域 NOT_EVALUABLE → fail-closed → exit 2
m3 <- run_entry(file.path(audit_fix, "case10_all_pass"), "PUBLICATION_READY")
check("M3: exit 2 (gate not satisfied)", m3$exit == 2L, sprintf("exit=%s", m3$exit))
if (!is.null(m3$json)) {
  check("M3: publication_ready FALSE", identical(m3$json$publication_ready, FALSE))
  ds3 <- m3$json$domain_status
  ne_critical <- c("VISUAL", "COLOR")
  got_ne <- all(vapply(ne_critical, function(d) identical(ds3[[d]], "NOT_EVALUABLE"), logical(1)))
  check("M3: VISUAL/COLOR NOT_EVALUABLE recorded", got_ne,
        paste(names(ds3), unlist(ds3), collapse = ", "))
}

## ---- M4: QUICK_REVIEW fixture + PUBLICATION_READY → fail-closed exit 2 ----
m4 <- run_entry(file.path(three_tier, "A_sloppy"), "PUBLICATION_READY")
check("M4: exit 2 (not ready)", m4$exit == 2L, sprintf("exit=%s", m4$exit))
if (!is.null(m4$json)) {
  check("M4: publication_ready FALSE", identical(m4$json$publication_ready, FALSE))
  check("M4: SCIENTIFIC never fabricated (FAIL or NOT_EVALUABLE)",
        m4$json$domain_status$SCIENTIFIC %in% c("FAIL", "NOT_EVALUABLE"),
        as.character(m4$json$domain_status$SCIENTIFIC))
}

## ---- M5: PASS_WITH_WARNINGS 不阻止 READY ----
m5 <- run_entry(warn_dir, "PUBLICATION_READY")
check("M5: exit 0 (warnings non-blocking)", m5$exit == 0L, sprintf("exit=%s", m5$exit))
if (!is.null(m5$json)) {
  fi5 <- tier(m5$json, "figure_integrity")
  check("M5: figure_integrity PASS_WITH_WARNINGS", fi5 %in% c("PASS_WITH_WARNINGS", "PASS"),
        as.character(fi5))
  check("M5: publication_ready TRUE despite warnings",
        identical(m5$json$publication_ready, TRUE),
        as.character(m5$json$publication_ready))
}

## ---- M6: 非法输入 → exit 3 ----
m6a <- run_entry(file.path(tempdir(), "definitely_not_a_directory_xyz"))
check("M6a: missing directory exit 3", m6a$exit == 3L, sprintf("exit=%s", m6a$exit))
m6b <- run_entry(ready_dir, "BOGUS_MODE")
check("M6b: invalid --mode exit 3", m6b$exit == 3L, sprintf("exit=%s", m6b$exit))

## ---- M7: 敌对路径 ----
## M7a: ASCII 敌对目录名（空格/单引号/分号/&/括号）—— 直接子进程启动
hostile_root <- file.path(tempdir(), "main entry 'hostile; & (dir)")
unlink(hostile_root, recursive = TRUE)
dir.create(hostile_root, recursive = TRUE, showWarnings = FALSE)
hostile_ok <- file.copy(ready_dir, hostile_root, recursive = TRUE)
hostile_dir <- file.path(hostile_root, "ready_case")
if (hostile_ok && dir.exists(hostile_dir)) {
  m7 <- run_entry(hostile_dir, "PUBLICATION_READY")
  check("M7a: ASCII-hostile dir exit 0", m7$exit == 0L, sprintf("exit=%s", m7$exit))
  check("M7a: ASCII-hostile dir ready TRUE",
        !is.null(m7$json) && identical(m7$json$publication_ready, TRUE))
} else {
  check("M7a: hostile fixture setup", FALSE, "copy failed")
}
unlink(hostile_root, recursive = TRUE)

## M7u: unicode 目录名 —— 经 8.3 短路径别名启动。
## 背景: Windows + 非 UTF-8 locale 下 R 无法构造含非 ASCII 字符的子进程命令行
## （system2 native-encoding 转换失败）; unicode 图像路径本身由
## run_raster_security_tests.R 的显式 unicode 路径用例覆盖。
uni_root <- file.path(tempdir(), paste0("main entry 'hostile; dir_", intToUtf8(c(0x4E2D, 0x6587))))
unlink(uni_root, recursive = TRUE)
dir.create(uni_root, recursive = TRUE, showWarnings = FALSE)
uni_ok <- file.copy(ready_dir, uni_root, recursive = TRUE)
uni_dir <- file.path(uni_root, "ready_case")
if (uni_ok && dir.exists(uni_dir)) {
  launch <- tryCatch(shortPathName(uni_dir), error = function(e) "")
  if (nzchar(launch) && dir.exists(launch)) {
    m7u <- run_entry(launch, "PUBLICATION_READY")
    check("M7u: unicode dir (via 8.3 alias) exit 0", m7u$exit == 0L, sprintf("exit=%s", m7u$exit))
    check("M7u: unicode dir ready TRUE",
          !is.null(m7u$json) && identical(m7u$json$publication_ready, TRUE))
  } else {
    check("M7u: 8.3 alias available", FALSE, "shortPathName unavailable on this volume")
  }
} else {
  check("M7u: unicode fixture setup", FALSE, "copy failed")
}
unlink(uni_root, recursive = TRUE)

## ---- M8: INCOMPLETE package → COMPLETE_DELIVERY 路由 + exit 2 ----
m8 <- run_entry(file.path(three_tier, "B_workflow"), "PUBLICATION_READY")
check("M8: exit 2 (package incomplete)", m8$exit == 2L, sprintf("exit=%s", m8$exit))
if (!is.null(m8$json)) {
  check("M8: publication_package INCOMPLETE",
        identical(tier(m8$json, "publication_package"), "INCOMPLETE"),
        as.character(tier(m8$json, "publication_package")))
  check("M8: NEXT_ACTION COMPLETE_DELIVERY",
        identical(m8$json$repair_routes$NEXT_ACTION, "COMPLETE_DELIVERY"),
        as.character(m8$json$repair_routes$NEXT_ACTION))
}

## ---- M9: SCIENTIFIC FAIL + COLOR REVISE → 多修复目标 → HUMAN_REVIEW_REQUIRED ----
m9 <- run_entry(file.path(three_tier, "C_nature_only"), "PUBLICATION_READY")
check("M9: exit 2", m9$exit == 2L, sprintf("exit=%s", m9$exit))
if (!is.null(m9$json)) {
  check("M9: figure_integrity FAIL",
        identical(tier(m9$json, "figure_integrity"), "FAIL"),
        as.character(tier(m9$json, "figure_integrity")))
  check("M9: multiple targets → HUMAN_REVIEW_REQUIRED",
        identical(m9$json$repair_routes$NEXT_ACTION, "HUMAN_REVIEW_REQUIRED"),
        as.character(m9$json$repair_routes$NEXT_ACTION))
}

## ---- M10: 单一统计目标 → RETURN_TO_STATISTICS ----
## stat_fail_case = ready_case + 伪重复统计单元（cells）; 图本身干净
m10 <- run_entry(file.path(fixtures, "stat_fail_case"), "PUBLICATION_READY")
check("M10: exit 2", m10$exit == 2L, sprintf("exit=%s", m10$exit))
if (!is.null(m10$json)) {
  check("M10: SCIENTIFIC FAIL",
        identical(m10$json$domain_status$SCIENTIFIC, "FAIL"),
        as.character(m10$json$domain_status$SCIENTIFIC))
  check("M10: NEXT_ACTION RETURN_TO_STATISTICS",
        identical(m10$json$repair_routes$NEXT_ACTION, "RETURN_TO_STATISTICS"),
        as.character(m10$json$repair_routes$NEXT_ACTION))
}

cat("\n=== RESULTS ===\n")
cat(sprintf("PASS: %d  FAIL: %d\n", pass, fail))
if (length(failures)) { cat("FAILURES:\n"); for (x in failures) cat(" -", x, "\n") }
quit(status = if (fail == 0L) 0 else 1)
