#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
repo <- normalizePath(if (length(args)) args[1] else ".", mustWork = TRUE)
generated <- file.path(repo, "tests", "generated")
results_dir <- file.path(repo, "tests", "results")
dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)
rscript_bin <- file.path(R.home("bin"), "Rscript")
invisible(system2(rscript_bin, c(file.path(repo, "tests", "generate_fixtures.R"), generated),
                  stdout = FALSE, stderr = FALSE))

matrix <- read.delim(file.path(repo, "R1_test_matrix.tsv"), stringsAsFactors = FALSE,
                     colClasses = "character", check.names = FALSE,
                     fileEncoding = "UTF-8-BOM")

run_json <- function(script, directory, output) {
  error_output <- paste0(output, ".stderr")
  status <- suppressWarnings(system2(rscript_bin, c(script, directory, "--json"),
                                     stdout = output, stderr = error_output))
  if (is.null(status)) status <- 0L
  as.integer(status)
}

extract_string <- function(path, field) {
  text <- paste(readLines(path, warn = FALSE), collapse = "")
  match <- regexec(paste0('"', field, '":"([^"]+)"'), text)
  parts <- regmatches(text, match)[[1]]
  if (length(parts) < 2) stop("Missing JSON field ", field, " in ", path)
  parts[2]
}

extract_bool <- function(path, field) {
  text <- paste(readLines(path, warn = FALSE), collapse = "")
  match <- regexec(paste0('"', field, '":(true|false)'), text)
  parts <- regmatches(text, match)[[1]]
  if (length(parts) < 2) stop("Missing JSON field ", field, " in ", path)
  identical(parts[2], "true")
}

extract_check <- function(path, rule, field) {
  text <- paste(readLines(path, warn = FALSE), collapse = "")
  pattern <- paste0('\\{\\"rule\\":\\"', rule,
                    '\\",\\"status\\":\\"([^\\"]+)\\",.*?\\"scope\\":\\"([^\\"]+)\\"\\}')
  match <- regexec(pattern, text)
  parts <- regmatches(text, match)[[1]]
  if (length(parts) < 3) stop("Missing JSON check ", rule, " in ", path)
  if (field == "status") parts[2] else parts[3]
}

failures <- character()
for (i in seq_len(nrow(matrix))) {
  fixture <- matrix$fixture[i]
  directory <- file.path(generated, fixture)
  sci_json <- file.path(results_dir, paste0(fixture, "_scientific.json"))
  del_json <- file.path(results_dir, paste0(fixture, "_delivery.json"))
  ready_json <- file.path(results_dir, paste0(fixture, "_readiness.json"))
  sci_exit <- run_json(file.path(repo, "scripts", "audit_scientific.R"), directory, sci_json)
  del_exit <- run_json(file.path(repo, "scripts", "qa_delivery.R"), directory, del_json)
  ready_exit <- run_json(file.path(repo, "scripts", "evaluate_readiness.R"), directory, ready_json)
  sci <- extract_string(sci_json, "overall_status")
  delivery <- extract_string(del_json, "overall_status")
  visual <- extract_string(ready_json, "visual_status")
  visual_interface <- extract_string(ready_json, "visual_qa_interface")
  ready <- extract_bool(ready_json, "publication_ready")
  a4_status <- extract_check(del_json, "a4_proof", "status")
  a4_scope <- extract_check(del_json, "a4_proof", "scope")
  expected_ready <- identical(toupper(matrix$publication_ready_expected[i]), "TRUE")
  expected_a4 <- matrix$a4_expected[i]
  a4_ok <- if (expected_a4 == "NOT_APPLICABLE") {
    a4_status == "PASS" && a4_scope == "not_applicable"
  } else {
    a4_status == expected_a4 && a4_scope == "figure"
  }

  expected_sci_exit <- if (matrix$scientific_expected[i] == "FAIL") 1L else 0L
  expected_del_exit <- if (matrix$delivery_expected[i] == "FAIL") 1L else 0L
  expected_ready_exit <- if (expected_ready) 0L else 1L
  conditions <- c(
    sci == matrix$scientific_expected[i],
    delivery == matrix$delivery_expected[i],
    visual == matrix$visual_expected[i],
    visual_interface == matrix$visual_interface_expected[i],
    identical(ready, expected_ready),
    a4_ok,
    identical(sci_exit, expected_sci_exit),
    identical(del_exit, expected_del_exit),
    identical(ready_exit, expected_ready_exit)
  )
  if (!all(conditions)) {
    failures <- c(failures, sprintf(
      "%s: sci=%s/%s exit=%d; delivery=%s/%s exit=%d; visual=%s/%s interface=%s/%s; ready=%s/%s exit=%d",
      fixture, sci, matrix$scientific_expected[i], sci_exit,
      delivery, matrix$delivery_expected[i], del_exit,
      visual, matrix$visual_expected[i], visual_interface,
      matrix$visual_interface_expected[i], ready, expected_ready, ready_exit
    ))
  } else {
    cat(sprintf("PASS %-42s scientific=%s delivery=%s A4=%s visual=%s interface=%s ready=%s\n",
                fixture, sci, delivery, expected_a4, visual, visual_interface, ready))
  }
}

if (length(failures)) {
  cat("\nR1 TEST FAILURES\n", paste0(" - ", failures, collapse = "\n"), "\n")
  quit(status = 1)
}

## Pairing edge-case assertions: exact terminology only; no bare `paired` substring.
source(file.path(repo, "scripts", "lib", "qa_common.R"))
source(file.path(repo, "scripts", "lib", "scientific_audit_core.R"))
pairing_fixture <- file.path(generated, "valid_unpaired_t_test")
pairing_manifest_path <- file.path(pairing_fixture, "figure_manifest.tsv")
pairing_original <- read_manifest(pairing_manifest_path)
pairing_assert <- function(pair, test) {
  candidate <- pairing_original
  candidate$pairing <- pair
  candidate$statistical_test <- test
  write.table(candidate, pairing_manifest_path, sep = "\t", quote = FALSE, row.names = FALSE)
  overall_status(run_scientific_audit(pairing_fixture))
}
pairing_results <- c(
  unpaired_t_test = pairing_assert("unpaired", "unpaired t-test"),
  unpaired_welch_t_test = pairing_assert("unpaired", "Welch t-test"),
  paired_t_test = pairing_assert("paired", "paired t-test")
)
write.table(pairing_original, pairing_manifest_path, sep = "\t", quote = FALSE, row.names = FALSE)
if (!all(pairing_results == "PASS")) {
  stop("Pairing regression failed: ", paste(names(pairing_results), pairing_results, collapse = "; "))
}
cat("Pairing regression: PASS (unpaired t-test, Welch t-test, paired t-test)\n")

duplicate_readiness <- file.path(results_dir, "duplicate_visual_domain_conflict_readiness.json")
duplicate_interface <- extract_string(duplicate_readiness, "visual_qa_interface")
duplicate_ready <- extract_bool(duplicate_readiness, "publication_ready")
if (duplicate_interface != "NOT_READY" || duplicate_ready) {
  stop("Visual-domain uniqueness regression failed")
}
cat("Visual-domain uniqueness: PASS (duplicate required domain → NOT_READY and publication false)\n")
cat(sprintf("\nTESTS PASS: %d/%d fixtures\n", nrow(matrix), nrow(matrix)))
