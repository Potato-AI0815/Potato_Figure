#!/usr/bin/env Rscript
# run_release_validation.R — potato-figure-audit 发布验证单一机器事实源
# 运行全部回归测试套件 + 静态包验证器, 将结果写入 validation/latest_validation.json。
# 发布证据只认这一份 JSON; RUNTIME_VALIDATION_REPORT.md / TEST_MATRIX.tsv 由
# scripts/generate_validation_report.R 从该 JSON 自动生成, 不得手工编辑。
#
# 用法: Rscript scripts/run_release_validation.R [repo_root]
# 退出码: 0 = overall PASS; 1 = 有套件/验证器 FAIL; 3 = 非法输入; 4 = 内部错误。

args <- commandArgs(trailingOnly = TRUE)
repo <- tryCatch(normalizePath(if (length(args)) args[1] else ".", mustWork = TRUE),
                 error = function(e) "")
if (!nzchar(repo) || !dir.exists(repo)) {
  cat(sprintf("ERROR: repo root does not exist: %s\n",
              if (length(args)) args[1] else "."), file = stderr())
  quit(status = 3)
}
if (!file.exists(file.path(repo, "SKILL.md")) ||
    !file.exists(file.path(repo, "scripts", "audit_figure.R"))) {
  cat("ERROR: repo root does not look like potato-figure-audit (missing SKILL.md or scripts/audit_figure.R)\n",
      file = stderr())
  quit(status = 3)
}

rscript_bin <- file.path(R.home("bin"), "Rscript")
if (!file.exists(rscript_bin)) rscript_bin <- "Rscript"

suites <- list(
  list(name = "r1_regression",        script = "tests/run_tests.R",                 args = "REPO"),
  list(name = "r4_local",             script = "tests/run_r4_tests.R",              args = "REPO"),
  list(name = "audit_core",           script = "tests/run_audit_tests.R",           args = "REPO"),
  list(name = "color_system",         script = "tests/run_color_system_tests.R",    args = "REPO"),
  list(name = "r6_gate_semantics",    script = "tests/run_r6_tests.R",              args = "REPO"),
  ## run_r6_real_regression.R 的 argv[1] 是审计输入目录覆盖项（非仓库根）→ 不带参数运行
  list(name = "r6_real_regression",   script = "tests/run_r6_real_regression.R",    args = "NONE"),
  list(name = "warning_semantics",    script = "tests/run_warning_semantics_tests.R", args = "REPO"),
  list(name = "raster_security",      script = "tests/run_raster_security_tests.R", args = "REPO"),
  list(name = "main_entry",           script = "tests/run_main_entry_tests.R",      args = "REPO"),
  list(name = "visual_correction",    script = "tests/run_visual_correction_tests.R", args = "REPO"),
  list(name = "binding_serializer",   script = "tests/run_binding_serializer_tests.R", args = "REPO")
)

## 日志持久化到 validation/run_logs（R 退出时会删除 session tempdir）。
## .log 后缀不在验证器的文本扫描列表中, 不会触发绝对路径误报。
log_dir <- file.path(repo, "validation", "run_logs")
unlink(log_dir, recursive = TRUE)
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)

run_suite <- function(s) {
  out_log <- file.path(log_dir, paste0(s$name, ".stdout.log"))
  err_log <- file.path(log_dir, paste0(s$name, ".stderr.log"))
  sa <- if (identical(s$args, "NONE")) character() else shQuote(repo)
  t0 <- Sys.time()
  rc <- tryCatch(
    suppressWarnings(system2(rscript_bin,
      c("--vanilla", shQuote(file.path(repo, s$script)), sa),
      stdout = out_log, stderr = err_log)),
    error = function(e) 4L)
  rc <- if (is.null(rc)) 0L else as.integer(rc)
  txt <- tryCatch(paste(readLines(out_log, warn = FALSE, encoding = "UTF-8"),
                        collapse = "\n"), error = function(e) "")
  ## 三种汇总行格式: "N/M PASS" | "PASS: N/M" | "PASS: N  FAIL: M"
  np <- NA_integer_; nt <- NA_integer_; summary_line <- ""
  last_match <- function(pattern) {
    mm <- regmatches(txt, gregexpr(pattern, txt))[[1]]
    if (!length(mm)) return(NULL)
    mm[length(mm)]
  }
  m1 <- last_match("([0-9]+)/([0-9]+) PASS")
  m2 <- last_match("PASS: ([0-9]+)/([0-9]+)")
  m3 <- last_match("PASS: ([0-9]+)[[:space:]]+FAIL: ([0-9]+)")
  if (!is.null(m1)) {
    summary_line <- m1
    p <- regmatches(m1, regexec("([0-9]+)/([0-9]+) PASS", m1))[[1]]
    np <- as.integer(p[2]); nt <- as.integer(p[3])
  } else if (!is.null(m2)) {
    summary_line <- m2
    p <- regmatches(m2, regexec("PASS: ([0-9]+)/([0-9]+)", m2))[[1]]
    np <- as.integer(p[2]); nt <- as.integer(p[3])
  } else if (!is.null(m3)) {
    summary_line <- m3
    p <- regmatches(m3, regexec("PASS: ([0-9]+)[[:space:]]+FAIL: ([0-9]+)", m3))[[1]]
    np <- as.integer(p[2]); nt <- np + as.integer(p[3])
  }
  list(name = s$name, script = s$script, exit_code = rc,
       checks_pass = np, checks_total = nt, summary_line = summary_line,
       status = if (rc == 0L) "PASS" else "FAIL",
       seconds = round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1))
}

cat("=== Potato Figure Audit — release validation ===\n")
results <- lapply(suites, function(s) {
  cat(sprintf("running %-22s ... ", s$name)); flush(stdout())
  r <- run_suite(s)
  cat(sprintf("%s (exit=%d, %s/%s, %.1fs)\n", r$status, r$exit_code,
              if (is.na(r$checks_pass)) "?" else r$checks_pass,
              if (is.na(r$checks_total)) "?" else r$checks_total, r$seconds))
  flush(stdout())
  r
})

## ---- 清理测试运行再生成的产物（含绝对路径; 均可由测试重新生成）----
cleanup_patterns <- c(
  file.path(repo, "tests", "regression_three_tier", "*", "figure_audit.json"),
  file.path(repo, "tests", "regression_three_tier", "*", "figure_audit_report.md"),
  file.path(repo, "tests", "main_entry_fixtures", "*", "figure_audit.json"),
  file.path(repo, "tests", "main_entry_fixtures", "*", "figure_audit_report.md"),
  file.path(repo, "tests", "audit_fixtures", "*", "figure_audit.json"),
  file.path(repo, "tests", "audit_fixtures", "*", "figure_audit_report.md"),
  file.path(repo, "tests", "results", "*"),
  file.path(repo, "tests", "results_r4", "*"),
  file.path(repo, "scripts", "__pycache__")
)
removed <- 0L
for (p in cleanup_patterns) {
  for (h in Sys.glob(p)) {
    ok <- if (dir.exists(h)) unlink(h, recursive = TRUE) == 0L
          else unlink(h) == 0L
    if (ok) removed <- removed + 1L
  }
}
cat(sprintf("cleaned %d regenerable artifacts before packaging validation\n", removed))

## ---- 静态包验证器（Python）----
find_python <- function() {
  cand <- c(Sys.getenv("POTATO_PYTHON", ""), "python", "python3", "py")
  for (p in cand) {
    if (!nzchar(p)) next
    probe <- suppressWarnings(tryCatch(
      system2(p, c("--version"), stdout = TRUE, stderr = TRUE),
      error = function(e) NULL))
    if (!is.null(probe) && any(grepl("Python [0-9]", probe))) return(p)
  }
  ""
}
py <- find_python()
validator <- list(tool = "scripts/validate_skill_package.py",
                  python = if (nzchar(py)) basename(py) else "",
                  exit_code = NA_integer_, status = "NOT_EVALUABLE",
                  detail = "")
if (nzchar(py)) {
  vout <- file.path(log_dir, "validate_skill_package.stdout.log")
  verr <- file.path(log_dir, "validate_skill_package.stderr.log")
  vrc <- suppressWarnings(system2(py,
    c(shQuote(file.path(repo, "scripts", "validate_skill_package.py")),
      shQuote(repo)), stdout = vout, stderr = verr))
  vrc <- if (is.null(vrc)) 0L else as.integer(vrc)
  vtxt <- tryCatch(paste(readLines(vout, warn = FALSE, encoding = "UTF-8"),
                         collapse = " "), error = function(e) "")
  ## 脱敏: 去掉可能出现的绝对路径, 避免污染单一事实源 JSON
  vtxt <- gsub("[A-Za-z]:[\\\\/][^ \"]*", "<path>", vtxt)
  validator$exit_code <- vrc
  validator$status <- if (vrc == 0L) "PASS" else "FAIL"
  validator$detail <- substr(vtxt, 1, 200)
  cat(sprintf("validator               %s (exit=%d)\n", validator$status, vrc))
} else {
  validator$detail <- "no usable Python interpreter found (set POTATO_PYTHON)"
  cat("validator               NOT_EVALUABLE (no Python)\n")
}

## ---- 汇总 ----
suites_pass <- sum(vapply(results, function(r) r$status == "PASS", logical(1)))
checks_pass <- sum(vapply(results, function(r)
  if (is.na(r$checks_pass)) 0L else r$checks_pass, integer(1)))
checks_total <- sum(vapply(results, function(r)
  if (is.na(r$checks_total)) 0L else r$checks_total, integer(1)))
overall <- if (suites_pass == length(results) && validator$status == "PASS")
  "PASS" else "FAIL"

## ---- 版本 ----
skill_lines <- readLines(file.path(repo, "SKILL.md"), warn = FALSE, encoding = "UTF-8")
ver <- "unknown"
for (ln in skill_lines) {
  if (grepl("^version:", ln)) { ver <- trimws(sub("^version:\\s*", "", ln)); break }
}
man_lines <- tryCatch(readLines(file.path(repo, "manifest.yaml"), warn = FALSE,
                                encoding = "UTF-8"), error = function(e) character())
for (ln in man_lines) if (grepl("^version:", ln)) ver <- trimws(sub("^version:\\s*", "", ln))

payload <- list(
  schema_version = "V1",
  skill = "potato-figure-audit",
  version = ver,
  generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
  machine = paste(Sys.info()[["sysname"]], Sys.info()[["release"]],
                  Sys.info()[["machine"]]),
  r_version = paste(R.version$major, R.version$minor, sep = "."),
  suites = results,
  validator = validator,
  totals = list(suites = length(results), suites_pass = suites_pass,
                checks_pass = checks_pass, checks_total = checks_total),
  overall = overall
)

if (!requireNamespace("jsonlite", quietly = TRUE)) {
  cat("ERROR: jsonlite unavailable; cannot write latest_validation.json\n",
      file = stderr())
  quit(status = 4)
}
val_dir <- file.path(repo, "validation")
dir.create(val_dir, recursive = TRUE, showWarnings = FALSE)
json_path <- file.path(val_dir, "latest_validation.json")
writeLines(as.character(jsonlite::toJSON(payload, auto_unbox = TRUE, pretty = TRUE)),
           json_path)
cat(sprintf("\noverall=%s  suites=%d/%d  checks=%d/%d  validator=%s\n",
            overall, suites_pass, length(results), checks_pass, checks_total,
            validator$status))
cat(sprintf("single source of truth: %s\n", json_path))
cat("regenerate reports:     Rscript scripts/generate_validation_report.R\n")
quit(status = if (overall == "PASS") 0L else 1L)
