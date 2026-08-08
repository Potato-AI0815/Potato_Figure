# qa_physical_size.R — Potato_Figure 物理尺寸 QA 命令行入口
# 用法: Rscript qa_physical_size.R <dir> [pattern] [dpi]
# 输出: 每张 PNG 的实测宽/高（mm）与是否落在合同宽度（183/89/110 mm）
script_dir <- dirname(normalizePath(sub("^--file=", "",
  commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))])))
source(file.path(script_dir, "..", "examples", "potato_theme.R"))
args <- commandArgs(trailingOnly = TRUE)
dir <- if (length(args) >= 1) args[1] else "."
pattern <- if (length(args) >= 2) args[2] else ".*\\.png$"
dpi <- if (length(args) >= 3) as.numeric(args[3]) else 300
qa_physical_size(dir, pattern, dpi)
