#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
root <- if (length(args)) args[1] else file.path("tests", "generated")
dir.create(root, recursive = TRUE, showWarnings = FALSE)

write_text <- function(path, text) writeLines(text, path, useBytes = TRUE)

make_plot_files <- function(directory, stem = "figure", width_mm = 180, height_mm = 120) {
  width_in <- width_mm / 25.4
  height_in <- height_mm / 25.4
  draw <- function() {
    plot(c(1, 2, 3), c(1, 3, 2), type = "b", xlab = "Synthetic x", ylab = "Synthetic y")
    title("Synthetic R1 execution fixture")
  }
  pdf(file.path(directory, paste0(stem, ".pdf")), width = width_in, height = height_in); draw(); dev.off()
  svg(file.path(directory, paste0(stem, ".svg")), width = width_in, height = height_in); draw(); dev.off()
  png(file.path(directory, paste0(stem, ".png")), width = width_mm / 25.4,
      height = height_mm / 25.4, units = "in", res = 300); draw(); dev.off()
  tiff_args <- list(filename = file.path(directory, paste0(stem, ".tiff")),
                    width = width_mm / 25.4, height = height_mm / 25.4,
                    units = "in", res = 600, compression = "lzw")
  if (isTRUE(capabilities("cairo"))) tiff_args$type <- "cairo"
  do.call(tiff, tiff_args); draw(); dev.off()
}

write_manifest <- function(directory, statistical_unit = "patient", pairing = "paired",
                           multiplicity = "no", method = "NA", source = "source_data.tsv",
                           test_name = NULL) {
  manifest <- data.frame(
    panel = "A",
    script = "plot.R",
    source_data = source,
    statistical_unit = statistical_unit,
    n = "6",
    pairing = pairing,
    transformation = "none",
    statistical_test = if (is.null(test_name)) {
      if (pairing == "paired") "Wilcoxon signed-rank" else "Welch t-test"
    } else test_name,
    multiplicity_applicable = multiplicity,
    multiplicity_method = method,
    hypothesis_family = if (multiplicity == "yes") "all_tested_markers" else "primary_prespecified_comparison",
    output_file = "figure.pdf",
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  write.table(manifest, file.path(directory, "figure_manifest.tsv"), sep = "\t",
              quote = FALSE, row.names = FALSE, na = "NA")
}

write_contract <- function(directory, authoring = "a4-working", visual = "PASS", proof = "a4_proof.pdf") {
  lines <- c(
    "central_claim: Synthetic evidence supports the declared R1 test condition",
    "figure_legend: Control blue; treatment coral",
    "hero_evidence: panel_A",
    "supporting_evidence: none",
    "figure_grammar: paired_quantitative",
    "visual_profile: synthetic_test_profile",
    paste0("authoring_profile: ", authoring),
    "target_journal: unspecified",
    "reference_figure: none",
    "reading_order: A",
    "scientific_status: NOT_REVIEWED",
    "delivery_status: NOT_REVIEWED",
    paste0("visual_status: ", visual),
    "requested_formats: pdf,svg,png,tiff",
    "final_width_mm: 180",
    "final_height_mm: 120",
    "raster_dpi: 300",
    "delivery_metadata_file: delivery_metadata.tsv",
    "session_metadata: sessionInfo.txt",
    paste0("a4_proof_file: ", proof),
    "visual_qa_file: visual_qa.tsv"
    ,"visual_evidence_source: MANUAL_REVIEW"
    ,"narrative.hero_panel: A"
    ,"color_state.semantic_palette: control=blue;treatment=coral"
    ,"color_state.continuous_palettes: diverging blue-white-red midpoint=0"
    ,"color_state.panel_palette_map: A=blue;support=coral"
    ,"color_review.primary_evidence_gray_dominant: false"
    ,"color_review.semantic_contrast_exists: true"
    ,"color_review.accent_hierarchy: good"
    ,"color_review.grayscale_redundancy: pass"
    ,"color_review.text_background_contrast: pass"
    ,"color_review.saturation_balance: balanced"
    ,"color_review.hero_salience: high"
    ,"color_review.confidence: high"
  )
  write_text(file.path(directory, "figure_contract.yaml"), lines)
}

write_delivery_metadata <- function(directory, include_proof = TRUE) {
  metadata <- data.frame(
    output_file = c("figure.pdf", "figure.svg", "figure.png", "figure.tiff"),
    format = c("pdf", "svg", "png", "tiff"),
    width_mm = 180,
    height_mm = 120,
    dpi = c(NA, NA, 300, 600),
    stringsAsFactors = FALSE
  )
  if (include_proof) {
    metadata <- rbind(metadata, data.frame(output_file = "a4_proof.pdf", format = "pdf",
                                           width_mm = 210, height_mm = 297, dpi = NA))
  }
  write.table(metadata, file.path(directory, "delivery_metadata.tsv"), sep = "\t",
              quote = FALSE, row.names = FALSE, na = "NA")
}

write_visual <- function(directory, overall = "PASS") {
  domains <- c("hero_clarity", "evidence_hierarchy", "reading_path", "panel_balance",
               "typography", "colour_semantics", "whitespace", "information_density",
               "legend_strategy", "thumbnail_readability")
  status <- rep("PASS", length(domains))
  if (overall == "REVISE") status[domains == "panel_balance"] <- "REVISE"
  if (overall == "FAIL") status[domains == "thumbnail_readability"] <- "FAIL"
  visual <- data.frame(domain = domains, status = status,
                       notes = ifelse(status == "PASS", "Human review completed.", "Human revision requested."))
  write.table(visual, file.path(directory, "visual_qa.tsv"), sep = "\t",
              quote = FALSE, row.names = FALSE)
}

make_base <- function(name, authoring = "a4-working", visual = "PASS") {
  directory <- file.path(root, name)
  unlink(directory, recursive = TRUE, force = TRUE)
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  make_plot_files(directory)
  if (authoring == "a4-working") {
    pdf(file.path(directory, "a4_proof.pdf"), width = 210 / 25.4, height = 297 / 25.4)
    plot.new(); text(0.5, 0.5, "A4 synthetic proof"); dev.off()
  }
  write_manifest(directory)
  write_contract(directory, authoring = authoring, visual = visual,
                 proof = if (authoring == "a4-working") "a4_proof.pdf" else "NA")
  write_delivery_metadata(directory, include_proof = authoring == "a4-working")
  write_visual(directory, visual)
  write_text(file.path(directory, "plot.R"), "# Synthetic fixture rendering script")
  write.table(data.frame(sample_id = paste0("S", 1:6), value = 1:6),
              file.path(directory, "source_data.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
  capture.output(sessionInfo(), file = file.path(directory, "sessionInfo.txt"))
  directory
}

make_base("valid_complete")

directory <- make_base("pseudoreplication_cell_as_n")
write_manifest(directory, statistical_unit = "cell")

directory <- make_base("multiplicity_yes_missing_method")
write_manifest(directory, multiplicity = "yes", method = "NA")

directory <- make_base("prespecified_paired_test_no_multiplicity", authoring = "journal-final")
write_manifest(directory, pairing = "paired", multiplicity = "no", method = "NA")

directory <- make_base("missing_source_data")
unlink(file.path(directory, "source_data.tsv"))

directory <- make_base("incomplete_exports")
unlink(file.path(directory, c("figure.svg", "figure.png", "figure.tiff")))

make_base("non_A4_profile_without_A4_proof", authoring = "journal-final")

directory <- make_base("A4_profile_missing_A4_proof")
unlink(file.path(directory, "a4_proof.pdf"))

make_base("visual_status_REVISE", authoring = "journal-final", visual = "REVISE")

directory <- make_base("valid_unpaired_t_test", authoring = "journal-final")
write_manifest(directory, pairing = "unpaired", test_name = "unpaired t-test")

directory <- make_base("visual_contract_PASS_but_domain_REVISE", authoring = "journal-final", visual = "PASS")
write_visual(directory, "REVISE")

directory <- make_base("visual_contract_PASS_but_domain_FAIL", authoring = "journal-final", visual = "PASS")
write_visual(directory, "FAIL")

directory <- make_base("paired_rank_sum_mismatch", authoring = "journal-final")
write_manifest(directory, pairing = "paired", test_name = "Wilcoxon rank-sum")

directory <- make_base("unpaired_signed_rank_mismatch", authoring = "journal-final")
write_manifest(directory, pairing = "unpaired", test_name = "Wilcoxon signed-rank")

directory <- make_base("missing_delivery_metadata_row", authoring = "journal-final")
metadata <- read.delim(file.path(directory, "delivery_metadata.tsv"), stringsAsFactors = FALSE)
metadata <- metadata[metadata$format != "tiff", , drop = FALSE]
write.table(metadata, file.path(directory, "delivery_metadata.tsv"), sep = "\t",
            quote = FALSE, row.names = FALSE, na = "NA")

directory <- make_base("duplicate_visual_domain_conflict", authoring = "journal-final")
visual <- read.delim(file.path(directory, "visual_qa.tsv"), stringsAsFactors = FALSE)
visual <- rbind(visual,
                data.frame(domain = "thumbnail_readability", status = "FAIL",
                           notes = "Conflicting duplicate domain for regression testing."))
write.table(visual, file.path(directory, "visual_qa.tsv"), sep = "\t",
            quote = FALSE, row.names = FALSE)

cat(sprintf("Generated 16 synthetic fixtures in %s\n", normalizePath(root)))
