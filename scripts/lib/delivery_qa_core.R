run_delivery_qa <- function(directory) {
  checks <- list()
  add <- function(...) checks[[length(checks) + 1]] <<- new_check(...)
  contract_path <- file.path(directory, "figure_contract.yaml")
  manifest_path <- file.path(directory, "figure_manifest.tsv")

  if (!file.exists(contract_path)) {
    add("figure_contract", "FAIL", "figure_contract.yaml is missing")
    return(checks)
  }
  contract <- tryCatch(read_flat_yaml(contract_path), error = function(e) e)
  if (inherits(contract, "error")) {
    add("figure_contract", "FAIL", paste("Cannot read contract:", contract$message))
    return(checks)
  }
  required_contract <- c(
    "central_claim", "hero_evidence", "supporting_evidence", "figure_grammar",
    "visual_profile", "authoring_profile", "target_journal", "reference_figure",
    "reading_order", "scientific_status", "delivery_status", "visual_status"
  )
  missing_contract <- required_contract[vapply(required_contract, function(x) is.null(contract[[x]]), logical(1))]
  if (length(missing_contract)) {
    add("figure_contract", "FAIL", paste("Missing contract fields:", paste(missing_contract, collapse = ", ")))
    return(checks)
  }
  add("figure_contract", "PASS", "Figure-level design contract is present and schema-complete")

  if (!file.exists(manifest_path)) {
    add("manifest", "FAIL", "figure_manifest.tsv is missing")
    return(checks)
  }
  manifest <- tryCatch(read_manifest(manifest_path), error = function(e) e)
  if (inherits(manifest, "error") || !"output_file" %in% names(manifest)) {
    add("manifest", "FAIL", "Manifest cannot be read or lacks output_file")
    return(checks)
  }
  add("manifest", "PASS", "Panel-level manifest is present")

  requested <- tolower(split_values(contract$requested_formats))
  if (!length(requested)) {
    add("requested_exports", "FAIL", "requested_formats is missing or empty")
  } else {
    add("requested_exports", "PASS", paste("Requested:", paste(requested, collapse = ", ")))
  }
  primary_outputs <- unique(trimws(manifest$output_file))
  missing_exports <- character()
  for (primary in primary_outputs) {
    stem <- sub("\\.[^.]+$", "", primary)
    for (format in requested) {
      candidate <- paste0(stem, ".", format)
      if (!file.exists(file.path(directory, candidate))) missing_exports <- c(missing_exports, candidate)
    }
  }
  if (length(missing_exports)) {
    add("export_completeness", "FAIL", paste("Missing:", paste(unique(missing_exports), collapse = ", ")))
  } else {
    add("export_completeness", "PASS", "All profile-requested export formats exist")
  }

  metadata_name <- if (is_blank(contract$delivery_metadata_file)) "delivery_metadata.tsv" else contract$delivery_metadata_file
  metadata_path <- file.path(directory, metadata_name)
  metadata <- NULL
  required_metadata <- c("output_file", "format", "width_mm", "height_mm", "dpi")
  if (!file.exists(metadata_path)) {
    add("delivery_metadata", "FAIL", paste("Missing:", metadata_name))
  } else {
    metadata <- tryCatch(read.delim(metadata_path, check.names = FALSE, stringsAsFactors = FALSE), error = function(e) e)
    if (inherits(metadata, "error") || length(setdiff(required_metadata, names(metadata)))) {
      add("delivery_metadata", "FAIL", "delivery_metadata.tsv is unreadable or schema-incomplete")
      metadata <- NULL
    } else {
      add("delivery_metadata", "PASS", "Physical delivery metadata is present")
    }
  }

  if (is.null(metadata) || !length(requested)) {
    add("delivery_metadata_coverage", "FAIL", "Cannot verify one metadata row per requested output")
  } else {
    expected_pairs <- unlist(lapply(primary_outputs, function(primary) {
      stem <- sub("\\.[^.]+$", "", primary)
      candidates <- paste0(stem, ".", requested)
      paste(candidates, requested, sep = "::")
    }))
    observed_pairs <- paste(trimws(metadata$output_file), tolower(trimws(metadata$format)), sep = "::")
    observed_tab <- table(observed_pairs)
    missing_pairs <- setdiff(expected_pairs, names(observed_tab))
    duplicate_pairs <- names(observed_tab)[observed_tab > 1 & names(observed_tab) %in% expected_pairs]
    if (length(missing_pairs) || length(duplicate_pairs)) {
      detail <- character()
      if (length(missing_pairs)) detail <- c(detail, paste0("missing ", paste(missing_pairs, collapse = ", ")))
      if (length(duplicate_pairs)) detail <- c(detail, paste0("duplicated ", paste(duplicate_pairs, collapse = ", ")))
      add("delivery_metadata_coverage", "FAIL", paste(detail, collapse = "; "),
          "Record exactly one delivery_metadata row for each primary output and requested format.")
    } else {
      add("delivery_metadata_coverage", "PASS",
          sprintf("One metadata row covers each of %d requested output(s)", length(expected_pairs)))
    }
  }

  expected_width <- suppressWarnings(as.numeric(contract$final_width_mm))
  expected_height <- suppressWarnings(as.numeric(contract$final_height_mm))
  required_dpi <- suppressWarnings(as.numeric(contract$raster_dpi))
  if (is.null(metadata) || any(is.na(c(expected_width, expected_height)))) {
    add("dimensions", "FAIL", "Expected dimensions or delivery metadata are unavailable")
  } else {
    figure_rows <- metadata$format %in% requested & metadata$output_file %in%
      unlist(lapply(primary_outputs, function(x) paste0(sub("\\.[^.]+$", "", x), ".", requested)))
    dims_ok <- any(figure_rows) && all(abs(metadata$width_mm[figure_rows] - expected_width) <= 0.5) &&
      all(abs(metadata$height_mm[figure_rows] - expected_height) <= 0.5)
    if (dims_ok) add("dimensions", "PASS", sprintf("Outputs match %.1f x %.1f mm", expected_width, expected_height))
    else add("dimensions", "FAIL", "Recorded output dimensions do not match the selected profile")
  }

  raster_formats <- intersect(requested, c("png", "tif", "tiff", "jpeg", "jpg"))
  if (!length(raster_formats)) {
    add("raster_resolution", "PASS", "No raster export requested", scope = "not_applicable")
  } else if (is.null(metadata) || is.na(required_dpi)) {
    add("raster_resolution", "FAIL", "Raster DPI requirement or delivery metadata is unavailable")
  } else {
    raster_rows <- tolower(metadata$format) %in% raster_formats
    dpi_values <- suppressWarnings(as.numeric(metadata$dpi[raster_rows]))
    if (length(dpi_values) && all(!is.na(dpi_values) & dpi_values >= required_dpi)) {
      add("raster_resolution", "PASS", sprintf("Raster exports are at least %d dpi", required_dpi))
    } else {
      add("raster_resolution", "FAIL", "One or more raster exports are below the selected-profile DPI")
    }
  }

  source_files <- unique(unlist(lapply(manifest$source_data, split_values)))
  missing_sources <- source_files[!file.exists(file.path(directory, source_files))]
  if (length(missing_sources)) add("source_data", "FAIL", paste("Missing:", paste(missing_sources, collapse = ", ")))
  else add("source_data", "PASS", "Declared Source Data files exist")

  bad_names <- primary_outputs[!grepl("^[A-Za-z0-9._/-]+$", primary_outputs)]
  if (length(bad_names)) add("output_naming", "WARNING", paste("Non-portable names:", paste(bad_names, collapse = ", ")))
  else add("output_naming", "PASS", "Output names are stable and portable")

  session_file <- trim_scalar(contract$session_metadata)
  if (is_blank(session_file)) {
    add("reproducibility_metadata", "WARNING", "session_metadata was not declared")
  } else if (!file.exists(file.path(directory, session_file))) {
    add("reproducibility_metadata", "WARNING", paste("Declared session metadata is missing:", session_file))
  } else {
    add("reproducibility_metadata", "PASS", "Session/reproducibility metadata exists")
  }

  is_a4 <- identical(tolower(trim_scalar(contract$authoring_profile)), "a4-working")
  if (!is_a4) {
    add("a4_proof", "PASS", "A4 proof is not applicable to the selected authoring profile", scope = "not_applicable")
  } else {
    proof <- trim_scalar(contract$a4_proof_file)
    proof_exists <- !is_blank(proof) && file.exists(file.path(directory, proof))
    proof_dims <- FALSE
    if (proof_exists && !is.null(metadata)) {
      row <- metadata[metadata$output_file == proof, , drop = FALSE]
      proof_dims <- nrow(row) == 1 && (
        (abs(row$width_mm - 210) <= 0.5 && abs(row$height_mm - 297) <= 0.5) ||
        (abs(row$width_mm - 297) <= 0.5 && abs(row$height_mm - 210) <= 0.5)
      )
    }
    if (proof_exists && proof_dims) add("a4_proof", "PASS", "A4 working proof exists at A4 dimensions")
    else add("a4_proof", "FAIL", "a4-working requires an A4 proof with recorded A4 dimensions")
  }
  checks
}
