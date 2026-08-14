#!/usr/bin/env Rscript
script_dir <- dirname(normalizePath(sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][1])))
source(file.path(script_dir, "lib", "qa_common.R"))
source(file.path(script_dir, "lib", "scientific_audit_core.R"))
args <- commandArgs(trailingOnly = TRUE)
directory <- if (length(args) && !startsWith(args[1], "--")) args[1] else "."
as_json <- "--json" %in% args
checks <- run_scientific_audit(directory)
if (as_json) {
  cat(checks_to_json("scientific_audit", checks), "\n", sep = "")
} else {
  print_human_report("Potato_Figure Scientific Audit", directory, checks)
}
quit(status = if (overall_status(checks) == "FAIL") 1 else 0)
