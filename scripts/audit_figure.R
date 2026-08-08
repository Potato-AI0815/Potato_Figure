# audit_figure.R — Potato_Figure 错误审计（Figure Audit）
# 审计对象：标准化 Figure 交付目录（figure_manifest.tsv + source data + 导出文件），
# 输出结构化错误报告：每条规则 = PASS / WARNING / FAIL + 错误说明 + 修改建议。
#
# 能力边界（重要）：本脚本审计的是"交付物结构与元数据"——
#   statistical_unit / n / statistical_test / source_data / 导出格式 / panel-output 关系；
# 它【不】读取 PNG/PDF 图像像素内容（不识别图中是否有彩虹色、是否隐藏原始点）。
# 图像内容层面的检查（artefact inspector）属于 v0.2 方向。
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

  ## ---- 4. 统计检验与多重性（multiplicity）----
  # 设计原则：不靠检验名称自动断言"必须校正"（预指定两组 Wilcoxon 不需要 FDR）。
  # 优先级：manifest 显式字段 > 关键词提示确认。
  #   字段（推荐）：multiplicity_applicable (yes/no) + multiplicity_method + hypothesis_family
  no_test <- is.na(mf$statistical_test) | mf$statistical_test == ""
  if (any(no_test)) {
    add("statistical_test", "WARNING",
        sprintf("%d 个 panel 未声明统计检验", sum(no_test)),
        "填写检验名称（含配对/非配对）")
  } else {
    add("statistical_test", "PASS", "所有 panel 已声明统计检验")
  }

  # 4.1 显式字段驱动（manifest 新增三字段）
  has_mapp <- "multiplicity_applicable" %in% names(mf)
  has_mmeth <- "multiplicity_method" %in% names(mf)
  if (has_mapp) {
    for (i in seq_len(nrow(mf))) {
      mapp <- tolower(trimws(as.character(mf$multiplicity_applicable[i])))
      if (mapp == "yes") {
        meth <- if (has_mmeth) trimws(as.character(mf$multiplicity_method[i])) else ""
        if (is.na(meth) || meth == "" || meth == "NA") {
          add("multiplicity", "FAIL",
              sprintf("panel %s：声明 multiplicity_applicable=yes 但未提供 multiplicity_method",
                      mf$panel[i]),
              "填写校正方法（BH-FDR/Holm/Bonferroni 等）或改为 no（需在 hypothesis_family 说明理由）")
        } else {
          add("multiplicity", "PASS",
              sprintf("panel %s：多重校正方法已声明（%s）", mf$panel[i], meth))
        }
      } else if (mapp == "no") {
        add("multiplicity", "PASS",
            sprintf("panel %s：声明不适用多重校正（hypothesis_family=%s）",
                    mf$panel[i],
                    if ("hypothesis_family" %in% names(mf)) mf$hypothesis_family[i] else "unspecified"))
      } else if (is.na(mapp) || mapp == "") {
        add("multiplicity", "WARNING",
            sprintf("panel %s：multiplicity_applicable 未填写", mf$panel[i]),
            "请确认该 panel 是否涉及多重比较；如适用请声明校正方法")
      } else {
        add("multiplicity", "WARNING",
            sprintf("panel %s：multiplicity_applicable 取值 '%s' 无法识别（应为 yes/no）",
                    mf$panel[i], mf$multiplicity_applicable[i]))
      }
    }
  } else {
    # 4.2 无显式字段时的关键词提示（只提示确认，不自动断言）
    # 触发词限定为真正暗示多重比较的语境；单检验名称（Wilcoxon/Cox/ANOVA）
    # 不再单独触发——预指定两组比较不需要校正。
    multi_hint <- c("genome-wide", "genome wide", "all tested", "many comparison",
                    "pairwise", "post-hoc", "post hoc", "multiple comparison",
                    "multiple testing", "all genes", "全基因组", "两两比较",
                    "多重比较", "多组")
    for (i in seq_len(nrow(mf))) {
      tt <- paste(as.character(mf$statistical_test[i]),
                  if ("hypothesis_family" %in% names(mf)) as.character(mf$hypothesis_family[i]) else "",
                  collapse = " ")
      if (is.na(tt) || tt == "") next
      hit <- any(vapply(multi_hint, function(k) grepl(k, tt, fixed = TRUE), logical(1)))
      if (hit) {
        add("multiplicity", "WARNING",
            sprintf("panel %s：检测到多重比较语境（%s），请确认是否需要 multiplicity adjustment；如需要请声明方法",
                    mf$panel[i], tt),
            "建议在 manifest 增加 multiplicity_applicable / multiplicity_method / hypothesis_family 三字段明确声明")
      }
    }
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
