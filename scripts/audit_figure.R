# audit_figure.R — Potato_Figure 错误审计（Figure Audit）
# 输入一张图（或其交付目录 + figure_manifest.tsv + source data），
# 输出结构化错误报告：每条规则 = PASS / WARNING / FAIL + 错误说明 + 修改建议。
# 这是 Potato_Figure 与普通绘图主题的核心差异：不仅画对，还能诊断错在哪。
#
# 用法: Rscript audit_figure.R <figure_dir> [--json]
#   默认输出人类可读报告；--json 输出结构化 JSON（供 agent/CI 消费）。
# 示例: Rscript audit_figure.R examples/example_output
#       Rscript audit_figure.R examples/example_output --json

args <- commandArgs(trailingOnly = TRUE)
dir <- if (length(args) >= 1) args[1] else "."
as_json <- any(args == "--json")

## ---- 审计条目收集 ----
audit <- list()  # 每项: list(rule, status, detail, advice)
add <- function(rule, status, detail, advice = "") {
  audit[[length(audit) + 1]] <<- list(rule = rule, status = status,
                                      detail = detail, advice = advice)
}

## ---- 1. manifest 存在性 ----
mf_path <- file.path(dir, "figure_manifest.tsv")
if (!file.exists(mf_path)) {
  add("manifest", "FAIL", "figure_manifest.tsv 缺失",
      "运行 example 或交付脚本生成 manifest（panel/script/source_data/statistical_unit/n/transformation/statistical_test/output_file）")
} else {
  mf <- read.delim(mf_path, check.names = FALSE, stringsAsFactors = FALSE)
  required_cols <- c("panel", "script", "source_data", "statistical_unit", "n",
                     "transformation", "statistical_test", "output_file")
  miss_cols <- setdiff(required_cols, names(mf))
  if (length(miss_cols) > 0) {
    add("manifest", "FAIL", sprintf("manifest 缺列: %s", paste(miss_cols, collapse = ", ")),
        "补齐全部 8 列；每 panel 一行")
  } else {
    add("manifest", "PASS", sprintf("manifest 完整：%d panels", nrow(mf)))
  }
}

if (exists("mf")) {
  ## ---- 2. 统计单位（伪重复审计 —— 核心规则）----
  pseudo_units <- c("cell", "cells", "视野", "view", "views", "field", "fields",
                    "roi", "well", "wells", "image", "images", "section", "切片",
                    "细胞", "克隆")
  units <- unique(tolower(trimws(mf$statistical_unit)))
  bad_units <- units[units %in% pseudo_units]
  if (length(bad_units) > 0) {
    add("statistical_unit", "FAIL",
        sprintf("统计单位疑似伪重复: %s —— 细胞/视野/ROI/切片不能作为独立 n",
                paste(bad_units, collapse = ", ")),
        "统计单位必须是患者/动物/独立实验/独立生物学重复；技术重复不可作为 n")
  } else if (any(is.na(mf$statistical_unit) | mf$statistical_unit == "")) {
    add("statistical_unit", "WARNING", "存在未填写的统计单位",
        "每个 panel 必须声明 statistical_unit")
  } else {
    add("statistical_unit", "PASS",
        sprintf("统计单位已声明: %s", paste(unique(mf$statistical_unit), collapse = ", ")))
  }

  ## ---- 3. n 完整性 ----
  n_na <- is.na(mf$n) | grepl("NA", mf$n) | mf$n == ""
  if (any(n_na)) {
    add("n", "WARNING", sprintf("%d 个 panel 的 n 未填写或为 NA 占位", sum(n_na)),
        "填写真实独立样本数；禁止 NA 占位（缺失实验留空白 contract 占位，不用模拟数据）")
  } else {
    add("n", "PASS", "所有 panel 已标注 n")
  }

  ## ---- 4. 统计检验与 FDR ----
  no_test <- is.na(mf$statistical_test) | mf$statistical_test == ""
  if (any(no_test)) {
    add("statistical_test", "WARNING",
        sprintf("%d 个 panel 未声明统计检验", sum(no_test)),
        "填写检验名称（含配对/非配对、多重校正方法）")
  } else {
    add("statistical_test", "PASS", "所有 panel 已声明统计检验")
  }

  ## ---- 5. Source Data 存在性 ----
  sd_missing <- character()
  for (i in seq_len(nrow(mf))) {
    for (sf in unlist(strsplit(mf$source_data[i], ";"))) {
      if (!file.exists(file.path(dir, sf))) sd_missing <- c(sd_missing, sf)
    }
  }
  if (length(sd_missing) > 0) {
    add("source_data", "FAIL",
        sprintf("Source Data 缺失: %s", paste(sd_missing, collapse = ", ")),
        "每 panel 一个 TSV：原始观察值、统计单位、n、变换、检验")
  } else {
    add("source_data", "PASS", "所有 panel 的 Source Data 存在")
  }

  ## ---- 6. 四格式导出 ----
  export_missing <- character()
  for (i in seq_len(nrow(mf))) {
    out <- sub("\\.pdf$", "", mf$output_file[i])
    for (ext in c(".pdf", ".svg", ".png", ".tiff")) {
      if (!file.exists(paste0(file.path(dir, out), ext)))
        export_missing <- c(export_missing, sprintf("%s%s", out, ext))
    }
  }
  if (length(export_missing) > 0) {
    add("export", "FAIL",
        sprintf("导出格式缺失: %s", paste(export_missing, collapse = ", ")),
        "交付需 PDF / SVG（可编辑文字）/ TIFF600 LZW / PNG300 四格式")
  } else {
    add("export", "PASS", "四格式导出齐全（PDF/SVG/TIFF/PNG）")
  }

  ## ---- 7. 输出文件与 panel 关系（拼版图感知）----
  out_tbl <- table(mf$output_file)
  shared <- names(out_tbl)[out_tbl > 1]
  if (length(shared) > 0) {
    # 全部 panel 共享同一 output = 有意拼版（patchwork 合成），合法；
    # 部分共享 = 可能覆盖事故
    if (length(shared) == 1 && length(unique(mf$output_file)) == 1) {
      add("output", "PASS",
          sprintf("拼版图：%d panels 合成 1 个输出文件（%s）",
                  nrow(mf), shared[1]))
    } else {
      add("output", "WARNING",
          sprintf("部分 panel 共享输出文件: %s（确认是否拼版或覆盖）",
                  paste(shared, collapse = ", ")),
          "若为拼版图请保持单一 output；若独立出图请逐 panel 命名")
    }
  } else {
    add("output", "PASS", "输出文件逐 panel 独立")
  }
}

## ---- 输出 ----
if (as_json) {
  cat(jsonlite::toJSON(audit, auto_unbox = TRUE, pretty = TRUE))  # 若无 jsonlite 会报错，见下
} else {
  cat(sprintf("Potato_Figure Audit — %s\n", normalizePath(dir)))
  cat(sprintf("%-18s %-8s %s\n", "RULE", "STATUS", "DETAIL"))
  cat(strrep("-", 78), "\n")
  for (a in audit) {
    cat(sprintf("%-18s %-8s %s\n", a$rule, a$status, a$detail))
    if (nzchar(a$advice)) cat(sprintf("%-18s %-8s %s\n", "", "建议", a$advice))
  }
  n_fail <- sum(vapply(audit, function(a) a$status == "FAIL", logical(1)))
  n_warn <- sum(vapply(audit, function(a) a$status == "WARNING", logical(1)))
  cat(strrep("-", 78), "\n")
  if (n_fail == 0 && n_warn == 0) {
    cat(sprintf("AUDIT PASS: %d rules, no errors found\n", length(audit)))
  } else {
    cat(sprintf("AUDIT: %d FAIL, %d WARNING, %d PASS (of %d rules)\n",
                n_fail, n_warn, length(audit) - n_fail - n_warn, length(audit)))
    quit(status = if (n_fail > 0) 1 else 0)
  }
}
