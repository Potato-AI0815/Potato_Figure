#!/usr/bin/env Rscript
# generate_validation_report.R — 从 validation/latest_validation.json 自动生成
# TEST_MATRIX.tsv 与 RUNTIME_VALIDATION_REPORT.md（仓库根目录）。
# 原则: 发布证据的唯一机器事实源是 validation/latest_validation.json;
#       本报告文件只是它的可读渲染, 一律自动生成, 禁止手工编辑。
#
# 用法: Rscript scripts/generate_validation_report.R [repo_root]
# 退出码: 0 = 生成成功; 3 = 非法输入/缺少 latest_validation.json; 4 = 内部错误。

args <- commandArgs(trailingOnly = TRUE)
repo <- tryCatch(normalizePath(if (length(args)) args[1] else ".", mustWork = TRUE),
                 error = function(e) "")
if (!nzchar(repo) || !dir.exists(repo)) {
  cat(sprintf("ERROR: repo root does not exist: %s\n",
              if (length(args)) args[1] else "."), file = stderr())
  quit(status = 3)
}
json_path <- file.path(repo, "validation", "latest_validation.json")
if (!file.exists(json_path)) {
  cat(sprintf(paste0("ERROR: %s not found. Run first:\n",
                     "  Rscript scripts/run_release_validation.R %s\n"),
              json_path, shQuote(repo)), file = stderr())
  quit(status = 3)
}
if (!requireNamespace("jsonlite", quietly = TRUE)) {
  cat("ERROR: jsonlite unavailable; cannot read latest_validation.json\n",
      file = stderr())
  quit(status = 4)
}
v <- tryCatch(jsonlite::fromJSON(json_path, simplifyVector = FALSE),
              error = function(e) {
                cat(sprintf("ERROR: latest_validation.json is not valid JSON: %s\n",
                            conditionMessage(e)), file = stderr())
                NULL
              })
if (is.null(v)) quit(status = 3)

num <- function(x) if (is.null(x) || is.na(x)) NA_integer_ else as.integer(x)
`%||%` <- function(a, b) if (is.null(a)) b else a

## ---------- TEST_MATRIX.tsv ----------
tm <- file.path(repo, "TEST_MATRIX.tsv")
rows <- c("suite\tscript\texit_code\tchecks_pass\tchecks_total\tstatus\tseconds")
for (s in v$suites) {
  rows <- c(rows, sprintf("%s\t%s\t%s\t%s\t%s\t%s\t%s",
    s$name, s$script, num(s$exit_code),
    if (is.null(s$checks_pass) || is.na(s$checks_pass)) "NA" else s$checks_pass,
    if (is.null(s$checks_total) || is.na(s$checks_total)) "NA" else s$checks_total,
    s$status, if (is.null(s$seconds)) "NA" else s$seconds))
}
rows <- c(rows, sprintf("validator\t%s\t%s\tNA\tNA\t%s\tNA",
  v$validator$tool,
  if (is.null(v$validator$exit_code) || is.na(v$validator$exit_code)) "NA"
    else num(v$validator$exit_code),
  v$validator$status))
writeLines(rows, tm)

## ---------- RUNTIME_VALIDATION_REPORT.md ----------
rp <- file.path(repo, "RUNTIME_VALIDATION_REPORT.md")
md <- c(
  "# Runtime Validation Report",
  "",
  "> AUTO-GENERATED from `validation/latest_validation.json` by",
  "> `scripts/generate_validation_report.R`. Do not edit by hand.",
  "",
  sprintf("- skill: %s v%s", v$skill, v$version),
  sprintf("- generated: %s", v$generated_at),
  sprintf("- machine: %s", v$machine),
  sprintf("- R: %s", v$r_version),
  sprintf("- **overall: %s**", v$overall),
  "",
  sprintf("Totals: %d/%d suites PASS; %d/%d checks PASS; validator %s.",
          v$totals$suites_pass, v$totals$suites,
          v$totals$checks_pass, v$totals$checks_total,
          v$validator$status),
  "",
  "## Test suites",
  "",
  "| suite | script | exit | checks | status | seconds |",
  "|---|---|---|---|---|---|")
for (s in v$suites) {
  md <- c(md, sprintf("| %s | `%s` | %s | %s/%s | %s | %s |",
    s$name, s$script, num(s$exit_code),
    if (is.null(s$checks_pass) || is.na(s$checks_pass)) "?" else s$checks_pass,
    if (is.null(s$checks_total) || is.na(s$checks_total)) "?" else s$checks_total,
    s$status, if (is.null(s$seconds)) "NA" else s$seconds))
}
md <- c(md, "",
  "## Static package validator",
  "",
  sprintf("- tool: `%s`", v$validator$tool),
  sprintf("- python: %s",
          if (nzchar(v$validator$python)) v$validator$python else "(none found)"),
  sprintf("- exit code: %s",
          if (is.null(v$validator$exit_code) || is.na(v$validator$exit_code)) "NA"
            else num(v$validator$exit_code)),
  sprintf("- status: %s", v$validator$status),
  if (nzchar(v$validator$detail %||% "")) sprintf("- detail: %s", v$validator$detail) else NULL,
  "",
  "## Evidence policy",
  "",
  "- Single machine source of truth: `validation/latest_validation.json`.",
  "- This report and `TEST_MATRIX.tsv` are regenerated from that JSON;",
  "  manual edits are invalid.",
  "- Reproduce: `Rscript scripts/run_release_validation.R` then",
  "  `Rscript scripts/generate_validation_report.R`.",
  "- Fixtures are synthetic; see `DATA_PROVENANCE.md` (no real patient data).",
  "")
writeLines(md, rp)

cat(sprintf("wrote %s\nwrote %s\n", tm, rp))
quit(status = 0)
