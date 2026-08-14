# color_integration.R — shared adapter for the standalone Color System auditor.

run_color_audit_cli <- function(directory, script_dir, default_evidence = "") {
  rscript <- Sys.which("Rscript")
  if (!nzchar(rscript)) {
    candidates <- c(file.path(R.home("bin"), "Rscript.exe"),
                    file.path(R.home("bin"), "x64", "Rscript.exe"),
                    file.path(R.home("bin"), "Rscript"))
    rscript <- candidates[file.exists(candidates)][1]
  }
  if (!nzchar(rscript)) return(list(ok = FALSE, error = "Rscript not found"))
  auditor <- file.path(script_dir, "audit_color_system.R")
  err_file <- tempfile(fileext = ".log")
  on.exit(unlink(err_file), add = TRUE)
  ## QUICK_REVIEW 下未声明 evidence source 时, 注入默认 RASTER_REVIEW
  ## （通过临时环境变量, 不写用户目录）
  if (nzchar(default_evidence)) {
    Sys.setenv(POTATO_COLOR_EVIDENCE_FALLBACK = default_evidence)
    on.exit(Sys.unsetenv("POTATO_COLOR_EVIDENCE_FALLBACK"), add = TRUE)
  }
  out <- tryCatch(
    suppressWarnings(system2(rscript, shQuote(c(auditor, directory, "--json")),
                             stdout = TRUE, stderr = err_file)),
    error = function(e) structure(character(), error = conditionMessage(e))
  )
  json_line <- out[grepl("^\\s*\\{", out)]
  if (!length(json_line)) {
    err <- c(attr(out, "error"), if (file.exists(err_file)) readLines(err_file, warn = FALSE) else character())
    return(list(ok = FALSE, error = paste(err[nzchar(err)], collapse = " | ")))
  }
  if (!requireNamespace("jsonlite", quietly = TRUE)) return(list(ok = FALSE, error = "jsonlite is required"))
  payload <- tryCatch(jsonlite::fromJSON(paste(json_line, collapse = ""), simplifyVector = FALSE),
                      error = function(e) NULL)
  if (is.null(payload)) return(list(ok = FALSE, error = "Color auditor returned invalid JSON"))
  list(ok = TRUE, payload = payload, exit_status = attr(out, "status"))
}

color_findings_for_main_audit <- function(result) {
  if (!isTRUE(result$ok)) {
    return(list(new_finding("color", "BLOCKER", "FAIL",
                            sprintf("Color audit integration failed: %s", result$error),
                            action = "Run scripts/audit_color_system.R directly and repair the runtime error",
                            owner = "ANALYSIS", evidence = "color auditor subprocess")))
  }
  lapply(result$payload$findings, function(f) {
    raw_status <- toupper(trim_scalar(f$status))
    layer <- toupper(trim_scalar(f$layer))
    status <- if (raw_status == "MAJOR" && layer == "A") "FAIL"
              else if (raw_status == "MAJOR") "REVISE"
              else if (raw_status == "INFO") "PASS" else raw_status
    severity <- if (status == "FAIL") "BLOCKER"
                else if (status == "REVISE") "MAJOR"
                else if (status == "WARNING") "MINOR"
                else toupper(trim_scalar(f$severity))
    if (!severity %in% SEVERITY_ORDER) severity <- "INFO"
    new_finding("color", severity, status,
                sprintf("%s: %s", trim_scalar(f$rule_id), trim_scalar(f$issue)),
                why = trim_scalar(f$why), panels = trim_scalar(f$panels),
                action = trim_scalar(f$action), owner = "FIGURE_GENERATOR",
                evidence = sprintf("color audit layer %s; %s/%s", layer,
                                   trim_scalar(f$measurement_type), trim_scalar(f$evaluation_source)),
                rule_id = trim_scalar(f$rule_id))
  })
}

## R6.1: severity-preserving readiness mapping.
## PASS_WITH_WARNINGS + COLOR_SYSTEM_READY=TRUE  → WARNING (non-blocking)
## PASS_WITH_LIMITED_EVIDENCE                     → WARNING (证据不足但无阻断性问题,
##   视为 non-blocking 提示; 不阻止 PUBLICATION_READY)
## MAJOR/REVISE/FAIL 仍严格阻断
color_readiness_status <- function(result) {
  if (!isTRUE(result$ok)) return("FAIL")
  audit_status <- result$payload$COLOR_AUDIT_STATUS
  system_ready <- isTRUE(result$payload$COLOR_SYSTEM_READY)
  if (identical(audit_status, "FAIL")) return("FAIL")
  if (identical(audit_status, "REVISE")) return("REVISE")
  if (identical(audit_status, "PASS_WITH_WARNINGS")) {
    if (system_ready) return("WARNING")
    return("REVISE")   # PASS_WITH_WARNINGS + not ready → publication MAJOR 存在
  }
  if (identical(audit_status, "PASS") && system_ready) return("PASS")
  if (identical(audit_status, "PASS_WITH_LIMITED_EVIDENCE") ||
      identical(audit_status, "NOT_EVALUABLE")) {
    ## 非阻断性证据不足（如 COLOR-14 无 vision 观察）→ WARNING 提示, 不阻止 ready
    return("WARNING")
  }
  "WARNING"
}
