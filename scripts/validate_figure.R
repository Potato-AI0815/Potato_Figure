# validate_figure.R — Potato_Figure 交付前静态预检
# 检查: figure_manifest.tsv 完整性、source data 存在性、四格式导出齐全
# 用法: Rscript validate_figure.R <figure_dir> [<manifest_file>]
# 默认: figure_dir = "." , manifest = "figure_manifest.tsv"

args <- commandArgs(trailingOnly = TRUE)
dir <- if (length(args) >= 1) args[1] else "."
mf_path <- if (length(args) >= 2) args[2] else file.path(dir, "figure_manifest.tsv")

if (!file.exists(mf_path)) {
  stop("figure_manifest.tsv not found: ", mf_path)
}
mf <- read.delim(mf_path, check.names = FALSE, stringsAsFactors = FALSE)
required_cols <- c("panel", "script", "source_data", "statistical_unit", "n",
                   "transformation", "statistical_test", "output_file")
miss_cols <- setdiff(required_cols, names(mf))
if (length(miss_cols) > 0) stop("manifest missing columns: ", paste(miss_cols, collapse = ", "))

fails <- character()
for (i in seq_len(nrow(mf))) {
  sd_files <- unlist(strsplit(mf$source_data[i], ";"))
  for (sf in sd_files) {
    p <- file.path(dir, sf)
    if (!file.exists(p)) fails <- c(fails, sprintf("source_data missing: %s (panel %s)", sf, mf$panel[i]))
  }
  out <- sub("\\.pdf$", "", mf$output_file[i])
  for (ext in c(".pdf", ".svg", ".png", ".tiff")) {
    if (!file.exists(paste0(file.path(dir, out), ext)))
      fails <- c(fails, sprintf("export missing: %s%s (panel %s)", out, ext, mf$panel[i]))
  }
  if (!is.na(mf$n[i]) && grepl("NA", mf$n[i])) {
    fails <- c(fails, sprintf("n contains NA placeholder (panel %s)", mf$panel[i]))
  }
}

if (length(fails) == 0) {
  cat(sprintf("VALIDATE PASS: %d panels, all source data and 4-format exports present\n", nrow(mf)))
} else {
  cat("VALIDATE FAIL:\n"); cat(paste0(" - ", fails, collapse = "\n"), "\n")
  quit(status = 1)
}
