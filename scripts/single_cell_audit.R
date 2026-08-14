#!/usr/bin/env Rscript
# single_cell_audit.R — R2.12 Conservative single-cell error detection
# 只对高置信度科学矛盾 FAIL；无法确定 WARNING；不充当全能统计专家。
# 输入: figure_manifest.tsv + figure_contract.yaml（可选）
# 用法: Rscript single_cell_audit.R <figure_dir> [--json]

script_dir <- dirname(normalizePath(sub("^--file=", "",
  commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][1])))
source(file.path(script_dir, "lib", "qa_common.R"))

args <- commandArgs(trailingOnly = TRUE)
directory <- if (length(args) && !startsWith(args[1], "--")) args[1] else "."
as_json <- "--json" %in% args

checks <- list()
add <- function(rule, status, detail, fix = "", panel = "", why = "", evidence = "") {
  d <- detail
  if (nzchar(panel)) d <- paste0(d, " [panel: ", panel, "]")
  if (nzchar(why)) d <- paste0(d, " | why: ", why)
  if (nzchar(evidence)) d <- paste0(d, " | evidence: ", evidence)
  checks[[length(checks) + 1]] <<- list(
    rule = rule, status = status, detail = d, advice = fix, scope = "figure")
}

manifest_path <- file.path(directory, "figure_manifest.tsv")
if (!file.exists(manifest_path)) {
  add("manifest_existence", "FAIL", "figure_manifest.tsv is missing",
      "Create the panel-level manifest before single-cell audit.", evidence = "file check")
} else {
  manifest <- tryCatch(read_manifest(manifest_path), error = function(e) e)
  if (inherits(manifest, "error")) {
    add("manifest_schema", "FAIL", paste("Cannot read manifest:", manifest$message))
  } else {
    req <- c("panel", "statistical_unit", "n", "pairing", "statistical_test",
             "multiplicity_applicable", "source_data", "output_file")
    missing <- setdiff(req, names(manifest))
    if (length(missing)) {
      add("manifest_schema", "FAIL", paste("Missing columns:", paste(missing, collapse = ", ")))
    } else {
      add("manifest_schema", "PASS", "Manifest schema acceptable for single-cell audit")

      ## Rule B1: statistical_unit=cell + multiple samples + inferential claim -> FAIL
      pseudo <- c("cell", "cells", "视野", "细胞")
      units <- tolower(trimws(manifest$statistical_unit))
      for (i in seq_len(nrow(manifest))) {
        if (units[i] %in% pseudo) {
          add("single_cell_pseudoreplication", "FAIL",
              sprintf("statistical_unit=%s while biological samples/patients exist",
                      manifest$statistical_unit[i]),
              "Aggregate to sample/patient level (pseudobulk) or use a hierarchical model; cells nested within patients are not independent biological replicates",
              panel = manifest$panel[i],
              why = "Cells within a patient are correlated; treating them as independent n inflates significance",
              evidence = paste("manifest row", i))
        }
      }

      ## Rule B2/B3: pairing vs test contradiction -> FAIL
      for (i in seq_len(nrow(manifest))) {
        pair <- tolower(trimws(manifest$pairing[i]))
        test <- tolower(manifest$statistical_test[i])
        if (pair == "paired" && grepl("rank[ -]?sum|mann[ -]?whitney|welch|unpaired|independent", test)) {
          add("pairing_test_contradiction", "FAIL",
              sprintf("paired design but test '%s' is unpaired", manifest$statistical_test[i]),
              "Use a paired test (e.g., Wilcoxon signed-rank, paired t-test)",
              panel = manifest$panel[i],
              why = "Unpaired test on paired data loses the pairing information and can mis-estimate the effect",
              evidence = paste("manifest row", i))
        }
        if (pair == "unpaired" && grepl("signed[ -]?rank|paired[ -]?t", test)) {
          add("pairing_test_contradiction", "FAIL",
              sprintf("unpaired design but test '%s' is paired", manifest$statistical_test[i]),
              "Use an unpaired test",
              panel = manifest$panel[i],
              why = "Paired test assumes matched observations that do not exist in an unpaired design",
              evidence = paste("manifest row", i))
        }
      }

      ## Rule B4: cell-level descriptive (UMAP/FeaturePlot/violin/DotPlot) as sole support for patient-level claim -> WARNING
      ## Rule B7: marker DotPlot alone supporting group-level DE -> WARNING
      ## (claim-level rules need contract; do the manifest-level part here)
      test_names <- tolower(manifest$statistical_test)
      for (i in seq_len(nrow(manifest))) {
        if (units[i] %in% pseudo && grepl("descriptive|violin|umap|featureplot|dotplot", test_names[i])) {
          add("cell_level_as_inference", "WARNING",
              sprintf("panel %s: cell-level descriptive view; if this supports a patient/sample-level claim, add patient-level inference",
                      manifest$panel[i]),
              "Add patient/sample-level paired proportion or pseudobulk analysis",
              panel = manifest$panel[i],
              why = "Cell-level descriptive evidence cannot alone support group-level inferential claims",
              evidence = "manifest statistical_test + statistical_unit")
        }
      }

      ## Rule B5: composition stacked bar without sample-level proportion -> WARNING (contract-level)
      ## Rule B6: cell-level DE using cells as replicates -> FAIL (same as B1 for DE panels)
      for (i in seq_len(nrow(manifest))) {
        if (grepl("differential|de |deg|volcano|pseudobulk", tolower(manifest$statistical_test[i]))) {
          if (units[i] %in% pseudo) {
            add("cell_level_de_pseudoreplication", "FAIL",
                sprintf("panel %s: differential expression declared with cell-level n",
                        manifest$panel[i]),
                "Use sample/patient-level pseudobulk DE; cells are not independent replicates",
                panel = manifest$panel[i],
                why = "Cell-level DE with cells as replicates is a classic pseudoreplication error in scRNA-seq",
                evidence = "manifest statistical_unit + statistical_test")
          } else {
            add("cell_level_de_pseudoreplication", "PASS",
                sprintf("panel %s: DE uses sample-level unit (%s)", manifest$panel[i], manifest$statistical_unit[i]),
                panel = manifest$panel[i])
          }
        }
      }
    }
  }
}

## ---- output ----
if (as_json) {
  cat(checks_to_json("single_cell_audit", checks), "\n", sep = "")
} else {
  print_human_report("Potato_Figure Single-Cell Audit (R2.12)", directory, checks)
}
quit(status = if (overall_status(checks) == "FAIL") 1 else 0)
