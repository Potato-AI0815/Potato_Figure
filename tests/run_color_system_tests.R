# run_color_system_tests.R — Potato Figure Audit v0.4.1 R2 behavioral/runtime tests
# Usage: Rscript tests/run_color_system_tests.R <repo_root>

args <- commandArgs(trailingOnly = TRUE)
root <- normalizePath(if (length(args)) args[1] else ".", mustWork = TRUE)
script_dir <- file.path(root, "scripts")
source(file.path(script_dir, "lib", "qa_common.R"))
source(file.path(script_dir, "lib", "audit_core.R"))
source(file.path(script_dir, "lib", "color_system_core.R"))
source(file.path(script_dir, "lib", "color_integration.R"))
rscript <- Sys.which("Rscript")
if (!nzchar(rscript)) {
  candidates <- c(file.path(R.home("bin"), "Rscript.exe"), file.path(R.home("bin"), "x64", "Rscript.exe"))
  rscript <- candidates[file.exists(candidates)][1]
}

pass <- 0L; fail <- 0L
check <- function(name, ok, detail = "") {
  if (isTRUE(ok)) { pass <<- pass + 1L; cat(sprintf("PASS %-55s %s\n", name, detail)) }
  else { fail <<- fail + 1L; cat(sprintf("FAIL %-55s %s\n", name, detail)) }
}

fixture <- tempfile("color_behavior_")
dir.create(fixture, recursive = TRUE)
on.exit(unlink(fixture, recursive = TRUE), add = TRUE)
writeLines(c("panel\tsource_data\tstatistical_test\tstatistical_unit\tpairing",
             "A\tsource_data.tsv\tdescriptive\tsample\tunpaired"), file.path(fixture, "figure_manifest.tsv"))
writeLines("x\n1", file.path(fixture, "source_data.tsv"))
writeLines(c("figure_id: color-test", "narrative.hero_panel: A",
             "color_state.semantic_palette: D=blue;R=coral",
             "color_state.continuous_palettes: diverging blue-white-red midpoint=0",
             "color_state.panel_palette_map: A=blue;B=coral",
             "color_state.neutral_roles: background;reference"), file.path(fixture, "global_figure_state.yaml"))

grDevices::png(file.path(fixture, "figure.png"), width = 120, height = 60, bg = "white")
graphics::par(mar = c(0, 0, 0, 0)); graphics::plot.new()
graphics::rect(0.05, 0.08, 0.46, 0.92, col = "#4678C8", border = NA)
graphics::rect(0.54, 0.08, 0.95, 0.92, col = "#DC645A", border = NA)
grDevices::dev.off()

write_contract <- function(extra = character(), source = "VISION_MODEL_REVIEW") {
  writeLines(c("final_figure_file: figure.png", sprintf("visual_evidence_source: %s", source),
               "figure_legend: D blue; R coral", "global_state_file: global_figure_state.yaml", extra),
             file.path(fixture, "figure_contract.yaml"))
}
run_payload <- function() {
  z <- run_color_audit_cli(fixture, script_dir)
  if (!isTRUE(z$ok)) stop(z$error)
  z$payload
}
rule_findings <- function(payload, id) payload$findings[vapply(payload$findings, function(f) identical(f$rule_id, id), logical(1))]
has_status <- function(payload, id, status) any(vapply(rule_findings(payload, id), function(f) identical(toupper(f$status), status), logical(1)))

write_contract(c("color_review.primary_evidence_gray_dominant: false",
                 "color_review.semantic_contrast_exists: true",
                 "color_review.accent_hierarchy: good",
                 "color_review.text_background_contrast: pass",
                 "color_review.saturation_balance: balanced",
                 "color_review.hero_salience: high", "color_review.confidence: high"))
p <- run_payload()
check("C1 semantic palette input produces COLOR-01 PASS", has_status(p, "COLOR-01", "PASS"))

state <- readLines(file.path(fixture, "global_figure_state.yaml"), warn = FALSE)
writeLines(state[!grepl("semantic_palette", state)], file.path(fixture, "global_figure_state.yaml"))
p <- run_payload()
check("C2 missing figure palette produces COLOR-01 WARNING", has_status(p, "COLOR-01", "WARNING"))
writeLines(state, file.path(fixture, "global_figure_state.yaml"))

p <- run_payload()
check("C3 explicit non-gray image observation produces COLOR-04 PASS", has_status(p, "COLOR-04", "PASS"))
write_contract(c("color_review.primary_evidence_gray_dominant: true", "color_review.semantic_contrast_exists: true", "color_review.confidence: high"))
p <- run_payload()
check("C4 explicit gray-dominance observation produces COLOR-04 MAJOR", has_status(p, "COLOR-04", "MAJOR"))

write_contract("color_review.accent_hierarchy: weak")
p <- run_payload()
check("C5 weak accent hierarchy produces COLOR-05 MAJOR", has_status(p, "COLOR-05", "MAJOR"))
check("C6 declared diverging scale produces COLOR-06 PASS", has_status(p, "COLOR-06", "PASS"))

red_green <- sub("D=blue;R=coral", "D=red;R=green", state, fixed = TRUE)
writeLines(red_green, file.path(fixture, "global_figure_state.yaml"))
p <- run_payload()
check("C7 red-green-only palette produces COLOR-07 WARNING", has_status(p, "COLOR-07", "WARNING"))
writeLines(state, file.path(fixture, "global_figure_state.yaml"))

write_contract(source = "METADATA_ONLY")
p <- run_payload()
image_rules <- c("COLOR-04", "COLOR-05", "COLOR-09", "COLOR-10", "COLOR-11")
check("C8 metadata-only keeps image rules NOT_EVALUABLE",
      all(vapply(image_rules, function(id) has_status(p, id, "NOT_EVALUABLE"), logical(1))))

write_contract("color_review.text_background_contrast: fail")
p <- run_payload()
check("C9 poor text contrast produces COLOR-09 MAJOR", has_status(p, "COLOR-09", "MAJOR"))
write_contract("color_review.saturation_balance: over")
p <- run_payload()
check("C10 over-saturation produces COLOR-10 MAJOR", has_status(p, "COLOR-10", "MAJOR"))
write_contract("color_review.hero_salience: low")
p <- run_payload()
check("C11 weak hero salience produces COLOR-11 MAJOR", has_status(p, "COLOR-11", "MAJOR"))

guard <- validate_color_evidence("VISION_MODEL_REVIEW", list(neutral_ink_fraction = 0.75))
check("C12 vision numeric fractions are rejected", !isTRUE(guard$valid), guard$reason)

write_contract(source = "RASTER_REVIEW")
p <- run_payload()
m <- p$raster_metrics
required_metrics <- c("neutral_ink_fraction", "chromatic_ink_fraction", "accent_area_fraction", "mean_saturation",
                      "panel_mean_saturation", "palette_cluster_count", "panel_palette_similarity")
check("C13 raster emits cross-panel palette metrics",
      !is.null(m) && all(required_metrics %in% names(m)), paste(names(m), collapse = ","))

write_contract(c("color_review.primary_evidence_gray_dominant: true", "color_review.semantic_contrast_exists: true"))
main_out <- suppressWarnings(system2(rscript, shQuote(c(file.path(script_dir, "audit_figure.R"), fixture, "--json")), stdout = TRUE, stderr = TRUE))
brief_out <- suppressWarnings(system2(rscript, shQuote(c(file.path(script_dir, "generate_visual_correction_brief.R"), fixture, "--source", "VISION_MODEL_REVIEW")), stdout = TRUE, stderr = TRUE))
ready_out <- suppressWarnings(system2(rscript, shQuote(c(file.path(script_dir, "evaluate_readiness.R"), fixture, "--json")), stdout = TRUE, stderr = TRUE))
audit_json <- if (file.exists(file.path(fixture, "figure_audit.json"))) paste(readLines(file.path(fixture, "figure_audit.json"), warn = FALSE), collapse = "") else ""
brief_text <- if (file.exists(file.path(fixture, "visual_correction_brief.yaml"))) paste(readLines(file.path(fixture, "visual_correction_brief.yaml"), warn = FALSE), collapse = "\n") else ""
check("C14 color findings propagate to audit/readiness/correction", grepl('"domain":"color"', audit_json, fixed = TRUE) &&
        grepl("COLOR-04", brief_text, fixed = TRUE) && any(grepl('"COLOR":"(FAIL|REVISE)"', ready_out)),
      sprintf("audit=%s brief=%s readiness=%s main_status=%s brief_status=%s",
              grepl('"domain":"color"', audit_json, fixed = TRUE), grepl("COLOR-04", brief_text, fixed = TRUE),
              any(grepl('"COLOR":"(FAIL|REVISE)"', ready_out)),
              if (is.null(attr(main_out, "status"))) 0 else attr(main_out, "status"),
              paste(ready_out, collapse = " | ")))

cat(sprintf("\nCOLOR SYSTEM BEHAVIORAL TESTS: %d/%d PASS\n", pass, pass + fail))
quit(status = if (fail == 0L) 0 else 1L)
