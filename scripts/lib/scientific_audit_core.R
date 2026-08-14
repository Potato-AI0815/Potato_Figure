run_scientific_audit <- function(directory) {
  checks <- list()
  add <- function(...) checks[[length(checks) + 1]] <<- new_check(...)
  manifest_path <- file.path(directory, "figure_manifest.tsv")
  required <- c(
    "panel", "script", "source_data", "statistical_unit", "n", "pairing",
    "transformation", "statistical_test", "multiplicity_applicable",
    "multiplicity_method", "hypothesis_family", "output_file"
  )

  if (!file.exists(manifest_path)) {
    add("manifest_existence", "FAIL", "figure_manifest.tsv is missing",
        "Create the panel-level manifest before scientific audit.")
    return(checks)
  }

  manifest <- tryCatch(read_manifest(manifest_path), error = function(e) e)
  if (inherits(manifest, "error")) {
    add("manifest_schema", "FAIL", paste("Cannot read manifest:", manifest$message))
    return(checks)
  }
  missing_columns <- setdiff(required, names(manifest))
  if (length(missing_columns)) {
    add("manifest_schema", "FAIL",
        paste("Missing columns:", paste(missing_columns, collapse = ", ")))
    return(checks)
  }
  if (!nrow(manifest)) {
    add("manifest_schema", "FAIL", "Manifest has no panel rows")
    return(checks)
  }
  add("manifest_schema", "PASS", sprintf("Schema complete for %d panel row(s)", nrow(manifest)))

  panels <- trimws(manifest$panel)
  if (any(!nzchar(panels)) || anyDuplicated(panels)) {
    add("panel_identity", "FAIL", "Panel identifiers are blank or duplicated",
        "Use one stable, unique panel identifier per row.")
  } else {
    add("panel_identity", "PASS", "Panel identifiers are present and unique")
  }

  pseudo_exact <- c("cell", "cells", "roi", "rois", "field", "fields", "view", "views",
                    "image", "images", "section", "sections", "视野", "细胞", "切片")
  units <- tolower(trimws(manifest$statistical_unit))
  bad <- unique(units[units %in% pseudo_exact])
  if (length(bad)) {
    add("statistical_unit", "FAIL",
        paste("Pseudoreplication-prone inferential unit:", paste(bad, collapse = ", ")),
        "Use the independent biological unit (for example patient, animal, donor, or experiment).")
  } else if (any(!nzchar(units))) {
    add("statistical_unit", "FAIL", "One or more panels lack a statistical unit")
  } else {
    add("statistical_unit", "PASS", paste("Declared:", paste(unique(manifest$statistical_unit), collapse = ", ")))
  }

  n_values <- suppressWarnings(as.numeric(manifest$n))
  if (any(is.na(n_values) | n_values <= 0)) {
    add("n", "FAIL", "Every panel must declare a positive independent-sample n",
        "Do not use cell counts or placeholders as biological n.")
  } else {
    add("n", "PASS", "All panels declare a positive independent-sample n")
  }

  pairing <- tolower(trimws(manifest$pairing))
  valid_pairing <- c("paired", "unpaired", "not_applicable")
  if (any(!pairing %in% valid_pairing)) {
    add("pairing", "FAIL", "pairing must be paired, unpaired, or not_applicable")
  } else {
    add("pairing", "PASS", paste("Declared:", paste(unique(pairing), collapse = ", ")))
  }

  test_names <- trimws(manifest$statistical_test)
  if (any(!nzchar(test_names) | toupper(test_names) == "NA")) {
    add("statistical_test", "FAIL", "One or more panels lack a statistical-test declaration")
  } else {
    add("statistical_test", "PASS", "All panels declare the statistical test or descriptive status")
  }

  ## Explicit design contradictions are audited; complex models remain human-review items.
  mismatch <- character()
  for (i in seq_len(nrow(manifest))) {
    pair <- pairing[i]
    test <- tolower(test_names[i])
    explicit_unpaired <- grepl("(^|[^[:alpha:]])unpaired([^[:alpha:]]|$)", test) ||
      grepl("(^|[^[:alpha:]])independent([^[:alpha:]]|$)", test)
    explicit_paired_test <- grepl("(^|[^[:alpha:]])paired[ -]?t([ -]?test)?([^[:alpha:]]|$)", test) ||
      grepl("(^|[^[:alpha:]])paired[ -]?test([^[:alpha:]]|$)", test)
    if (pair == "paired" && (grepl("rank[ -]?sum|mann[ -]?whitney|welch", test) || explicit_unpaired)) {
      mismatch <- c(mismatch, paste0(panels[i], ": paired + ", manifest$statistical_test[i]))
    }
    if (pair == "unpaired" && (grepl("signed[ -]?rank", test) || explicit_paired_test)) {
      mismatch <- c(mismatch, paste0(panels[i], ": unpaired + ", manifest$statistical_test[i]))
    }
  }
  if (length(mismatch)) {
    add("pairing_test_consistency", "FAIL",
        paste("Explicit pairing/test contradiction:", paste(mismatch, collapse = "; ")),
        "Align the statistical test with the declared paired or unpaired design.")
  } else {
    add("pairing_test_consistency", "PASS",
        "No explicit paired/unpaired versus test contradiction detected")
  }

  multiplicity <- tolower(trimws(manifest$multiplicity_applicable))
  if (any(!multiplicity %in% c("yes", "no"))) {
    add("multiplicity_applicable", "FAIL", "multiplicity_applicable must be yes or no")
  } else {
    add("multiplicity_applicable", "PASS", "Multiplicity applicability is explicitly declared")
  }
  requires_method <- multiplicity == "yes"
  methods <- trimws(manifest$multiplicity_method)
  missing_method <- requires_method & (!nzchar(methods) | toupper(methods) %in% c("NA", "NONE"))
  if (any(missing_method)) {
    add("multiplicity_method", "FAIL",
        paste("Method missing for panel(s):", paste(panels[missing_method], collapse = ", ")),
        "Declare the prespecified adjustment method for the stated hypothesis family.")
  } else {
    add("multiplicity_method", "PASS", "Multiplicity method is present wherever applicable")
  }
  families <- trimws(manifest$hypothesis_family)
  if (any(!nzchar(families) | toupper(families) == "NA")) {
    add("hypothesis_family", "FAIL", "Every panel must identify its hypothesis family")
  } else {
    add("hypothesis_family", "PASS", "Hypothesis families are declared")
  }

  missing_sources <- character()
  for (i in seq_len(nrow(manifest))) {
    files <- split_values(manifest$source_data[i])
    if (!length(files)) missing_sources <- c(missing_sources, paste0(panels[i], ":<blank>"))
    for (file in files) {
      if (!file.exists(file.path(directory, file))) missing_sources <- c(missing_sources, paste0(panels[i], ":", file))
    }
  }
  if (length(missing_sources)) {
    add("source_data", "FAIL", paste("Missing:", paste(unique(missing_sources), collapse = ", ")),
        "Provide panel-level Source Data using stable relative paths.")
  } else {
    add("source_data", "PASS", "All declared Source Data files exist")
  }

  missing_scripts <- character()
  for (i in seq_len(nrow(manifest))) {
    script <- trimws(manifest$script[i])
    if (!nzchar(script) || !file.exists(file.path(directory, script))) missing_scripts <- c(missing_scripts, panels[i])
  }
  if (length(missing_scripts)) {
    add("script_provenance", "FAIL", paste("Missing script for panel(s):", paste(missing_scripts, collapse = ", ")))
  } else {
    add("script_provenance", "PASS", "All panel scripts exist")
  }

  outputs <- trimws(manifest$output_file)
  missing_output <- !nzchar(outputs) | !file.exists(file.path(directory, outputs))
  if (any(missing_output)) {
    add("output_file", "FAIL", paste("Primary output missing for panel(s):", paste(panels[missing_output], collapse = ", ")))
  } else {
    add("output_file", "PASS", "Every panel maps to an existing primary output")
  }
  duplicate_map <- table(outputs)
  partially_shared <- length(duplicate_map) > 1 && any(duplicate_map > 1)
  if (partially_shared) {
    add("panel_output_relationship", "WARNING",
        "Only a subset of panels shares an output file; confirm this is intentional")
  } else if (length(duplicate_map) == 1 && nrow(manifest) > 1) {
    add("panel_output_relationship", "PASS", "All panels intentionally map to one figure-level output")
  } else {
    add("panel_output_relationship", "PASS", "Panels map to distinct outputs")
  }
  checks
}
