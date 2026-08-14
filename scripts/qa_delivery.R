#!/usr/bin/env Rscript
script_dir <- dirname(normalizePath(sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][1])))
source(file.path(script_dir, "lib", "qa_common.R"))
source(file.path(script_dir, "lib", "delivery_qa_core.R"))
args <- commandArgs(trailingOnly = TRUE)
directory <- if (length(args) && !startsWith(args[1], "--")) args[1] else "."
as_json <- "--json" %in% args
checks <- run_delivery_qa(directory)
if (as_json) {
  cat(checks_to_json("delivery_qa", checks), "\n", sep = "")
} else {
  print_human_report("Potato_Figure Delivery QA", directory, checks)
}
quit(status = if (overall_status(checks) == "FAIL") 1 else 0)
