#!/usr/bin/env Rscript
# run_warning_semantics_tests.R — R6.1 Warning Semantics 行为测试
# 核心: MINOR/WARNING 不得升级为 REVISE; MAJOR/REVISE/FAIL 仍阻断 readiness
# 行为测试: 构造输入 → 执行真实函数 → 检查实际输出（禁止字符串 grep 伪测试）

script_dir <- dirname(normalizePath(sub("^--file=", "",
  commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][1])))
repo_dir <- dirname(script_dir)
lib_dir <- file.path(repo_dir, "scripts", "lib")
source(file.path(lib_dir, "qa_common.R"))
source(file.path(lib_dir, "audit_core.R"))

pass <- 0L; fail <- 0L; failures <- character()
check <- function(name, cond, detail = "") {
  if (isTRUE(cond)) { pass <<- pass + 1L; cat(sprintf("  [PASS] %s\n", name)) }
  else { fail <<- fail + 1L; failures <<- c(failures, sprintf("%s: %s", name, detail)); cat(sprintf("  [FAIL] %s  %s\n", name, detail)) }
}

mk_finding <- function(domain, status, issue = "test finding", owner = "ANALYSIS",
                       severity = "MINOR", evidence = "unit-test", rule_id = "") {
  list(domain = domain, severity = severity, status = status,
       issue = issue, why = "", panels = "", action = "", owner = owner,
       evidence = evidence, rule_id = rule_id)
}

## ---- color_readiness_status 测试（真实函数） ----
source(file.path(lib_dir, "color_integration.R"))
mk_color_result <- function(audit_status, ready) {
  list(ok = TRUE, payload = list(COLOR_AUDIT_STATUS = audit_status,
                                 COLOR_SYSTEM_READY = ready))
}

cat("=== W1-W2: color domain mapping ===\n")
## W1: PASS + READY → PASS
check("W1: COLOR PASS+READY -> PASS",
      color_readiness_status(mk_color_result("PASS", TRUE)) == "PASS")
## W2: PASS_WITH_WARNINGS + READY → WARNING（不是 REVISE）
w2 <- color_readiness_status(mk_color_result("PASS_WITH_WARNINGS", TRUE))
check("W2: COLOR PASS_WITH_WARNINGS+READY -> WARNING", w2 == "WARNING", w2)

cat("=== W3-W6: publication readiness 边界 ===\n")
## W3: 只有 MINOR/WARNING + 所有 package gate PASS → PUBLICATION_READY=TRUE
f_w3 <- list(
  mk_finding("color", "WARNING", "COLOR-07: red/green-only without redundancy", rule_id = "COLOR-07"),
  mk_finding("delivery", "PASS", "delivery ok", owner = "DELIVERY"),
  mk_finding("scientific", "PASS", "sci ok", owner = "STATISTICS")
)
ds_w3 <- domain_status_from_findings(f_w3, c(FIGURE_INTEGRITY_DOMAINS, "DELIVERY"))
fi_w3 <- compute_figure_integrity(ds_w3)
pc_w3 <- classify_package_findings(f_w3)
pk_w3 <- compute_publication_package(ds_w3, pc_w3)
check("W3: warning only -> FI PASS_WITH_WARNINGS", fi_w3 == "PASS_WITH_WARNINGS", fi_w3)
check("W3: warning only + package PASS -> READY TRUE",
      fi_w3 %in% c("PASS", "PASS_WITH_WARNINGS") && pk_w3 == "PASS", paste(fi_w3, pk_w3))

## W4: MAJOR/REVISE → PUBLICATION_READY=FALSE
f_w4 <- list(mk_finding("color", "REVISE", "COLOR-13: gray data encoding", severity = "MAJOR", rule_id = "COLOR-13"))
ds_w4 <- domain_status_from_findings(f_w4, c(FIGURE_INTEGRITY_DOMAINS, "DELIVERY"))
fi_w4 <- compute_figure_integrity(ds_w4)
check("W4: MAJOR/REVISE -> FI REVISE/FAIL", fi_w4 %in% c("REVISE", "FAIL"), fi_w4)
check("W4: MAJOR blocks readiness", !(fi_w4 %in% c("PASS", "PASS_WITH_WARNINGS") && TRUE), fi_w4)

## W5: FAIL/BLOCKER → PUBLICATION_READY=FALSE
f_w5 <- list(mk_finding("scientific", "FAIL", "multiplicity method missing", severity = "BLOCKER", owner = "STATISTICS"))
ds_w5 <- domain_status_from_findings(f_w5, c(FIGURE_INTEGRITY_DOMAINS, "DELIVERY"))
check("W5: FAIL -> FI FAIL", compute_figure_integrity(ds_w5) == "FAIL", compute_figure_integrity(ds_w5))

## W6: required critical NOT_EVALUABLE → fail-closed（PUBLICATION_READY=FALSE）
f_w6 <- list(
  mk_finding("scientific", "NOT_EVALUABLE", "no manifest"),
  mk_finding("delivery", "PASS", "del ok")
)
ds_w6 <- domain_status_from_findings(f_w6, c(FIGURE_INTEGRITY_DOMAINS, "DELIVERY"))
fi_w6 <- compute_figure_integrity(ds_w6)
check("W6: critical NE -> FI NOT_EVALUABLE", fi_w6 == "NOT_EVALUABLE", fi_w6)
## PUBLICATION_READY 模式: critical NE 必须阻止
critical_ne_blocks <- !(fi_w6 %in% c("PASS", "PASS_WITH_WARNINGS") && TRUE)
check("W6: critical NE fail-closed", critical_ne_blocks)

cat("=== W7-W8: figure integrity warning semantics ===\n")
## W7: 只有 warning → FI=PASS_WITH_WARNINGS（不是 REVISE）
f_w7 <- list(mk_finding("color", "WARNING", "COLOR-07: red/green-only", severity = "MINOR", rule_id = "COLOR-07"))
ds_w7 <- domain_status_from_findings(f_w7, FIGURE_INTEGRITY_DOMAINS)
check("W7: warning -> PASS_WITH_WARNINGS", compute_figure_integrity(ds_w7) == "PASS_WITH_WARNINGS",
      compute_figure_integrity(ds_w7))

## W8: C 版 COLOR-13 MAJOR → FI=FAIL（不能被 warning policy 降级）
f_w8 <- list(
  mk_finding("scientific", "FAIL", "multiplicity NONE", severity = "BLOCKER", owner = "STATISTICS"),
  mk_finding("color", "REVISE", "COLOR-13: gray data encoding", severity = "MAJOR", rule_id = "COLOR-13")
)
ds_w8 <- domain_status_from_findings(f_w8, FIGURE_INTEGRITY_DOMAINS)
check("W8: COLOR-13 MAJOR + sci FAIL -> FI FAIL", compute_figure_integrity(ds_w8) == "FAIL",
      compute_figure_integrity(ds_w8))

cat("=== Severity monotonicity ===\n")
## aggregation 不得把 MINOR/WARNING 升级为 MAJOR/REVISE
f_mono <- list(
  mk_finding("color", "WARNING", "COLOR-07: red/green-only", severity = "MINOR", rule_id = "COLOR-07"),
  mk_finding("delivery", "PASS", "del ok")
)
ds_mono <- domain_status_from_findings(f_mono, c(FIGURE_INTEGRITY_DOMAINS, "DELIVERY"))
fi_mono <- compute_figure_integrity(ds_mono)
check("MONO: MINOR/WARNING not escalated to REVISE", fi_mono == "PASS_WITH_WARNINGS", fi_mono)
## 单独 rule aggregation 也不得升级
ag_mono <- aggregate_rule_evidence(f_mono)
check("MONO: rule aggregation preserves WARNING",
      any(vapply(ag_mono, function(x) x$final_status == "WARNING", logical(1))),
      paste(names(ag_mono), collapse = ","))

cat("=== Major propagation control ===\n")
f_major <- list(
  mk_finding("color", "REVISE", "COLOR-13: gray data encoding", severity = "MAJOR", rule_id = "COLOR-13"),
  mk_finding("delivery", "PASS", "del ok")
)
ds_major <- domain_status_from_findings(f_major, c(FIGURE_INTEGRITY_DOMAINS, "DELIVERY"))
fi_major <- compute_figure_integrity(ds_major)
check("MAJOR: REVISE -> FI REVISE", fi_major == "REVISE", fi_major)
check("MAJOR: blocks readiness", !(fi_major %in% c("PASS", "PASS_WITH_WARNINGS")), fi_major)

cat("=== Blocker control ===\n")
f_block <- list(mk_finding("scientific", "FAIL", "pseudoreplication", severity = "BLOCKER", owner = "STATISTICS"))
ds_block <- domain_status_from_findings(f_block, FIGURE_INTEGRITY_DOMAINS)
check("BLOCKER: FAIL -> FI FAIL", compute_figure_integrity(ds_block) == "FAIL")

cat("\n=== RESULTS ===\n")
cat(sprintf("PASS: %d  FAIL: %d\n", pass, fail))
if (length(failures)) { cat("FAILURES:\n"); for (x in failures) cat(" -", x, "\n") }
quit(status = if (fail == 0L) 0 else 1)
