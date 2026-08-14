#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
repo <- normalizePath(if (length(args)) args[1] else ".", mustWork = TRUE)
generated <- file.path(repo, "tests", "generated")
results <- file.path(repo, "tests", "results_r4")
dir.create(results, recursive = TRUE, showWarnings = FALSE)

if (!dir.exists(file.path(generated, "valid_complete"))) {
  status <- system2("Rscript", c(file.path(repo, "tests", "generate_fixtures.R"), generated))
  if (!is.null(status) && status != 0) stop("Could not generate R1 fixtures")
}

copy_fixture <- function(name) {
  src <- file.path(generated, "valid_complete")
  dst <- file.path(generated, name)
  unlink(dst, recursive = TRUE, force = TRUE)
  dir.create(dst, recursive = TRUE, showWarnings = FALSE)
  files <- list.files(src, full.names = TRUE, all.files = TRUE, no.. = TRUE)
  ok <- file.copy(files, dst, recursive = TRUE)
  if (!all(ok)) stop("Could not copy fixture ", name)
  dst
}

append_contract_r4 <- function(dir, status = "PASS") {
  cat(c(
    "coherence_mode: global_state",
    "global_state_file: global_figure_state.yaml",
    "global_coherence_qa_file: global_coherence_qa.tsv",
    paste0("global_coherence_status: ", status),
    "modality_adapter: generic"
  ), file = file.path(dir, "figure_contract.yaml"), append = TRUE, sep = "\n")
}

write_state <- function(dir, body_pt = 9, hero = "a", last_change = "CHG001") {
  lines <- c(
    "state_version: 1.0",
    "figure_id: Figure_1",
    "modality: generic",
    "assembly_mode: publication",
    "scientific.central_claim: Synthetic patient-level effect",
    "scientific.statistical_unit: patient",
    "scientific.primary_contrast: B_vs_A",
    "narrative.reading_order: a,b,c",
    paste0("narrative.hero_panel: ", hero),
    "narrative.panel_tags: a,b,c",
    "visual.profile: potato-user-v1",
    paste0("visual.body_pt: ", body_pt),
    "visual.axis_text_pt: 8.5",
    "visual.panel_tag_pt: 11",
    "visual.colour_architecture: coordinated_cool_warm_plus_structural_ink",
    "geometry.target_width_occupancy: 0.88",
    "geometry.target_height_occupancy: 0.82",
    "geometry.outer_margin_mm: 3.5",
    "geometry.panel_gap_mm: 3",
    "assembly.final_canvas: one_figure",
    "repair.change_log_file: local_change_log.tsv",
    paste0("repair.last_change_id: ", last_change)
  )
  writeLines(lines, file.path(dir, "global_figure_state.yaml"))
}

write_global_qa <- function(dir, overall = "PASS") {
  domains <- c("scientific_spine_preserved", "panel_role_consistency", "reading_order",
               "geometry_budget", "canvas_utilization", "physical_consistency",
               "chromatic_coherence", "typography_consistency", "assembly_coherence",
               "local_change_impact_closed")
  status <- rep("PASS", length(domains))
  if (overall == "REVISE") status[domains == "canvas_utilization"] <- "REVISE"
  if (overall == "FAIL") status[domains == "assembly_coherence"] <- "FAIL"
  out <- data.frame(domain = domains, status = status, notes = "Synthetic R4 review", stringsAsFactors = FALSE)
  write.table(out, file.path(dir, "global_coherence_qa.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
}

write_change <- function(dir, closed = "yes", recheck = "PASS", updated = "yes",
                         change_type = "geometry", required = "geometry;assembly;reading_order;thumbnail;canvas_occupancy") {
  out <- data.frame(
    change_id = "CHG001", timestamp = "2026-08-09T16:00:00+08:00",
    change_type = change_type, target_key = "panel.c.height", reason = "Synthetic R4 repair",
    impact_scope = "panel_c;assembly;thumbnail", required_rechecks = required,
    recheck_status = recheck, global_state_updated = updated, closed = closed,
    notes = "Synthetic", stringsAsFactors = FALSE
  )
  write.table(out, file.path(dir, "local_change_log.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
}

run_json <- function(script, dir, output) {
  err <- paste0(output, ".stderr")
  status <- suppressWarnings(system2("Rscript", c(script, dir, "--json"), stdout = output, stderr = err))
  if (is.null(status)) status <- 0L
  as.integer(status)
}

extract_string <- function(path, field) {
  text <- paste(readLines(path, warn = FALSE), collapse = "")
  m <- regexec(paste0('"', field, '":"([^"]+)"'), text)
  p <- regmatches(text, m)[[1]]
  if (length(p) < 2) stop("Missing field ", field, " in ", path)
  p[2]
}
extract_bool <- function(path, field) {
  text <- paste(readLines(path, warn = FALSE), collapse = "")
  m <- regexec(paste0('"', field, '":(true|false)'), text)
  p <- regmatches(text, m)[[1]]
  if (length(p) < 2) stop("Missing field ", field, " in ", path)
  identical(p[2], "true")
}

## 1. valid R4 fixture
valid <- copy_fixture("r4_valid_global")
append_contract_r4(valid, "PASS"); write_state(valid); write_global_qa(valid); write_change(valid)
out <- file.path(results, "r4_valid_global.json")
exit <- run_json(file.path(repo, "scripts", "evaluate_readiness.R"), valid, out)
stopifnot(exit == 0L, extract_string(out, "global_coherence_status") == "PASS", extract_bool(out, "publication_ready"))
cat("R4 valid global-state fixture: PASS\n")

## 2. open local change must fail closed
open <- copy_fixture("r4_open_local_change")
append_contract_r4(open, "PASS"); write_state(open); write_global_qa(open); write_change(open, closed = "no", recheck = "NOT_REVIEWED", updated = "no")
out <- file.path(results, "r4_open_local_change.json")
exit <- run_json(file.path(repo, "scripts", "evaluate_readiness.R"), open, out)
stopifnot(exit == 1L, extract_string(out, "global_coherence_status") == "FAIL", !extract_bool(out, "publication_ready"))
cat("R4 unresolved local-change fail-closed regression: PASS\n")

## 3. personal profile violation must block readiness as REVISE
profile <- copy_fixture("r4_profile_typography_revise")
append_contract_r4(profile, "PASS"); write_state(profile, body_pt = 14); write_global_qa(profile); write_change(profile)
out <- file.path(results, "r4_profile_typography_revise.json")
exit <- run_json(file.path(repo, "scripts", "evaluate_readiness.R"), profile, out)
stopifnot(exit == 1L, extract_string(out, "global_coherence_status") == "REVISE", !extract_bool(out, "publication_ready"))
cat("R4 personal-profile coherence regression: PASS\n")

## 4. hero must belong to panel graph
hero <- copy_fixture("r4_invalid_hero")
append_contract_r4(hero, "PASS"); write_state(hero, hero = "z"); write_global_qa(hero); write_change(hero)
out <- file.path(results, "r4_invalid_hero.json")
exit <- run_json(file.path(repo, "scripts", "evaluate_readiness.R"), hero, out)
stopifnot(exit == 1L, extract_string(out, "global_coherence_status") == "FAIL", !extract_bool(out, "publication_ready"))
cat("R4 panel-graph regression: PASS\n")

cat("R4 TESTS PASS: 4/4 fixtures\n")
