#!/usr/bin/env Rscript
# run_r6_tests.R — R6 Gate Semantics & Report Consolidation 行为测试
# 行为测试原则: 构造输入 → 运行真实审计入口 → 检查实际状态（禁止字符串 grep 伪测试）
# 用法: Rscript run_r6_tests.R

script_dir <- dirname(normalizePath(sub("^--file=", "",
  commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][1])))
lib_dir <- file.path(dirname(script_dir), "scripts", "lib")
source(file.path(lib_dir, "qa_common.R"))
source(file.path(lib_dir, "audit_core.R"))

pass <- 0L; fail <- 0L; failures <- character()
check <- function(name, cond, detail = "") {
  if (isTRUE(cond)) {
    pass <<- pass + 1L
    cat(sprintf("  [PASS] %s\n", name))
  } else {
    fail <<- fail + 1L
    failures <<- c(failures, sprintf("%s: %s", name, detail))
    cat(sprintf("  [FAIL] %s  %s\n", name, detail))
  }
}

mk_finding <- function(domain, status, issue = "test finding", owner = "ANALYSIS",
                       severity = "MAJOR", evidence = "unit-test", rule_id = "") {
  list(domain = domain, severity = severity, status = status,
       issue = issue, why = "", panels = "", action = "", owner = owner,
       evidence = evidence, rule_id = rule_id)
}

cat("=== R6 Gate Semantics Tests (8) ===\n")

## G1: 图内容全 PASS + 交付缺材料 → FI=PASS, PKG=INCOMPLETE, READY=FALSE
f1 <- list(
  mk_finding("scientific", "PASS", "sci ok"),
  mk_finding("visual", "PASS", "vis ok"),
  mk_finding("color", "PASS", "col ok"),
  mk_finding("panel_architecture", "PASS", "pan ok"),
  mk_finding("delivery", "FAIL", "Missing: figure.pdf", owner = "DELIVERY")
)
ds1 <- domain_status_from_findings(f1, c(FIGURE_INTEGRITY_DOMAINS, "DELIVERY"))
fi1 <- compute_figure_integrity(ds1)
pc1 <- classify_package_findings(f1)
pk1 <- compute_publication_package(ds1, pc1)
check("G1: figure integrity PASS", fi1 == "PASS", fi1)
check("G1: package INCOMPLETE (missing not error)", pk1 == "INCOMPLETE", pk1)
check("G1: publication_ready FALSE", !(fi1 == "PASS" && pk1 == "PASS"), paste(fi1, pk1))

## G2: 科学 BLOCKER → FI=FAIL（即使交付齐全）
f2 <- list(
  mk_finding("scientific", "FAIL", "Method missing for panel(s): a", owner = "STATISTICS"),
  mk_finding("delivery", "PASS", "del ok")
)
ds2 <- domain_status_from_findings(f2, c(FIGURE_INTEGRITY_DOMAINS, "DELIVERY"))
check("G2: scientific FAIL -> FI FAIL", compute_figure_integrity(ds2) == "FAIL", compute_figure_integrity(ds2))

## G3: 交付"声明但错误"（DPI 不符）→ PKG=FAIL（不是 INCOMPLETE）
f3 <- list(
  mk_finding("delivery", "FAIL", "Recorded output dimensions do not match the selected profile", owner = "DELIVERY")
)
pc3 <- classify_package_findings(f3)
pk3 <- compute_publication_package(list(DELIVERY = "FAIL", GLOBAL_COHERENCE = "PASS"), pc3)
check("G3: wrong-but-declared -> package FAIL", pk3 == "FAIL", pk3)

## G4: 只有图（无 manifest）→ QUICK_REVIEW 推断
dir_g4 <- tempfile("r6_g4"); dir.create(dir_g4)
file.create(file.path(dir_g4, "figure.png"))
check("G4: image-only infers QUICK_REVIEW",
      infer_audit_mode(dir_g4, list()) == "QUICK_REVIEW", infer_audit_mode(dir_g4, list()))

## G5: manifest 存在 → SCIENTIFIC_FIGURE_AUDIT 推断
dir_g5 <- tempfile("r6_g5"); dir.create(dir_g5)
file.create(file.path(dir_g5, "figure.png"))
file.create(file.path(dir_g5, "figure_manifest.tsv"))
check("G5: manifest infers SCIENTIFIC_FIGURE_AUDIT",
      infer_audit_mode(dir_g5, list()) == "SCIENTIFIC_FIGURE_AUDIT", infer_audit_mode(dir_g5, list()))

## G6: 显式 PUBLICATION_READY 优先
check("G6: explicit PUBLICATION_READY wins",
      infer_audit_mode(dir_g5, list(), "PUBLICATION_READY") == "PUBLICATION_READY")

## G7: QUICK_REVIEW 下 SCIENTIFIC 不判 FAIL（材料缺失 → NE）
f7 <- list(mk_finding("scientific", "NOT_EVALUABLE", "no manifest"))
ds7 <- domain_status_from_findings(f7, FIGURE_INTEGRITY_DOMAINS)
check("G7: NE in quick review is not FAIL", ds7[["SCIENTIFIC"]] == "NOT_EVALUABLE", ds7[["SCIENTIFIC"]])

## G8: NEXT_ACTION 路由 — FI PASS + PKG INCOMPLETE → COMPLETE_DELIVERY
routes8 <- repair_routes(f1, "PASS", "INCOMPLETE")
check("G8: NEXT_ACTION COMPLETE_DELIVERY", identical(routes8$NEXT_ACTION, "COMPLETE_DELIVERY"), routes8$NEXT_ACTION)

cat("=== R6 Audit Mode Tests (6) ===\n")

## M1: QUICK_REVIEW 域集不含 SCIENTIFIC/STATISTICAL
check("M1: quick mode domains exclude scientific",
      !"SCIENTIFIC" %in% AUDIT_MODE_DOMAINS$QUICK_REVIEW)

## M2: SCIENTIFIC_FIGURE_AUDIT 含 6 个 integrity 域
check("M2: scientific mode domains",
      all(c("SCIENTIFIC", "STATISTICAL", "CLAIM_EVIDENCE", "PANEL_ARCHITECTURE", "VISUAL", "COLOR") %in%
          AUDIT_MODE_DOMAINS$SCIENTIFIC_FIGURE_AUDIT))

## M3: PUBLICATION_READY 含全部 8 域
check("M3: publication mode includes delivery/global",
      all(c("DELIVERY", "GLOBAL_COHERENCE") %in% AUDIT_MODE_DOMAINS$PUBLICATION_READY))

## M4: FIGURE_INTEGRITY 域不含 DELIVERY
check("M4: FI excludes DELIVERY", !"DELIVERY" %in% FIGURE_INTEGRITY_DOMAINS)

## M5: PUBLICATION_PACKAGE 域含 DELIVERY
check("M5: package includes DELIVERY", "DELIVERY" %in% PUBLICATION_PACKAGE_DOMAINS)

## M6: FI + WARNING → PASS_WITH_WARNINGS; FI + FAIL → FAIL
f6 <- list(mk_finding("color", "WARNING", "real warning"))
ds6 <- domain_status_from_findings(f6, FIGURE_INTEGRITY_DOMAINS)
check("M6: warning -> PASS_WITH_WARNINGS",
      compute_figure_integrity(ds6) == "PASS_WITH_WARNINGS", compute_figure_integrity(ds6))

cat("=== R6 Evidence Aggregation Tests (8) ===\n")

## E1: metadata NE + raster PASS → PASS_WITH_LIMITED_EVIDENCE
f_e1 <- list(
  mk_finding("color", "NOT_EVALUABLE", "COLOR-03: No panel palette map", rule_id = "COLOR-03"),
  mk_finding("color", "PASS", "COLOR-03: Measured clusters=62", rule_id = "COLOR-03")
)
ag_e1 <- aggregate_rule_evidence(f_e1)
check("E1: NE+PASS -> PASS_WITH_LIMITED_EVIDENCE",
      ag_e1[[1]]$final_status == "PASS_WITH_LIMITED_EVIDENCE",
      ag_e1[[1]]$final_status)

## E2: metadata PASS + raster contradiction → FAIL
f_e2 <- list(
  mk_finding("color", "PASS", "COLOR-01: declared mapping ok", rule_id = "COLOR-01"),
  mk_finding("color", "FAIL", "COLOR-01: raster shows swapped hues", rule_id = "COLOR-01")
)
ag_e2 <- aggregate_rule_evidence(f_e2)
check("E2: contradiction -> FAIL", ag_e2[[1]]$final_status == "FAIL", ag_e2[[1]]$final_status)

## E3: 全图 neutral PASS + 面板 gray MAJOR → 最终非 PASS（REVISE）
f_e3 <- list(
  mk_finding("color", "PASS", "COLOR-04: neutral 0.37", rule_id = "COLOR-04"),
  mk_finding("color", "REVISE", "COLOR-13: gray data encoding", rule_id = "COLOR-13")
)
ds_e3 <- domain_status_from_findings(f_e3, "COLOR")
check("E3: panel gray -> COLOR REVISE", ds_e3[["COLOR"]] == "REVISE", ds_e3[["COLOR"]])

## E4: 无图证据 → 图像依赖规则 NOT_EVALUABLE
f_e4 <- list(mk_finding("color", "NOT_EVALUABLE", "COLOR-04: no image", rule_id = "COLOR-04"))
check("E4: no image -> NOT_EVALUABLE",
      aggregate_rule_evidence(f_e4)[[1]]$final_status == "NOT_EVALUABLE")

## E5: declarative + raster + vision 全 PASS → PASS
f_e5 <- list(
  mk_finding("color", "PASS", "COLOR-14: censoring only (declared)", rule_id = "COLOR-14"),
  mk_finding("color", "PASS", "COLOR-14: raster ok", rule_id = "COLOR-14")
)
check("E5: all PASS -> PASS",
      aggregate_rule_evidence(f_e5)[[1]]$final_status == "PASS")

## E6: PASS + WARNING 并存 → WARNING（warning 为准, 不丢）
f_e6 <- list(
  mk_finding("color", "PASS", "COLOR-02: legend ok", rule_id = "COLOR-02"),
  mk_finding("color", "WARNING", "COLOR-02: partial legend", rule_id = "COLOR-02")
)
check("E6: PASS+WARNING -> WARNING",
      aggregate_rule_evidence(f_e6)[[1]]$final_status == "WARNING")

## E7: 空 issue 校验 — new_finding 拒绝空消息
empty_rejected <- tryCatch({ new_finding("color", "INFO", "PASS", "   "); FALSE },
                            error = function(e) TRUE)
check("E7: empty finding message rejected", empty_rejected)

## E8: repair_routes 只收 FAIL/REVISE（NE 不入路由）
f_e8 <- list(
  mk_finding("delivery", "FAIL", "Missing pdf", owner = "DELIVERY"),
  mk_finding("color", "NOT_EVALUABLE", "no palette")
)
r8 <- repair_routes(f_e8, "PASS", "INCOMPLETE")
check("E8: NE excluded from routes", length(r8$DELIVERY) == 1 && length(r8$FIGURE_GENERATOR) == 0,
      paste(length(r8$DELIVERY), length(r8$FIGURE_GENERATOR)))

cat("\n=== RESULTS ===\n")
cat(sprintf("PASS: %d  FAIL: %d\n", pass, fail))
if (length(failures)) {
  cat("FAILURES:\n")
  for (x in failures) cat(" -", x, "\n")
}
quit(status = if (fail == 0L) 0 else 1)
