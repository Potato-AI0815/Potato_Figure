#!/usr/bin/env Rscript
script_dir <- dirname(normalizePath(sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][1])))
source(file.path(script_dir, "lib", "qa_common.R"))
source(file.path(script_dir, "lib", "global_coherence_core.R"))
args <- commandArgs(trailingOnly = TRUE)
directory <- if (length(args) && !startsWith(args[1], "--")) args[1] else "."
as_json <- "--json" %in% args
repo_root <- normalizePath(file.path(script_dir, ".."), mustWork = TRUE)
checks <- run_impact_audit(directory, repo_root)
if (as_json) {
  cat(checks_to_json("local_change_impact_audit", checks), "\n", sep = "")
} else {
  print_human_report("Potato_Figure Local Change Impact Audit (R4)", directory, checks)
}
quit(status = if (overall_status(checks) == "PASS") 0 else 1)
