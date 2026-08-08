# potato_theme.R — Potato_Figure 统一 R 主题、导出与 QA 函数
# 用法: source("potato_theme.R") 后调用 set_potato_theme() / save_fig() / qa_physical_size()
# 依赖: ggplot2, patchwork, svglite, ragg, png

## ---- 依赖检查 ----
.require_pkg <- function(p) {
  if (!requireNamespace(p, quietly = TRUE)) {
    stop(sprintf("Potato_Figure: required package '%s' is missing. Install with install.packages('%s').", p, p))
  }
}
.require_pkg("ggplot2"); .require_pkg("svglite"); .require_pkg("ragg"); .require_pkg("png")

## ---- 语义颜色合同（通用语义，全文冻结）----
# 通用语义色：任何课题/期刊场景下含义稳定，跨图不换色。
# 项目专属语义（如疾病分组）通过 profiles/ 加载，见 SKILL.md §2。
POTATO_COLORS <- c(
  CONTROL  = "#595959",   # 中性深灰：对照（细胞/动物/基线）
  TREATMENT = "#C95A5A",  # 暖红：处理/疾病/实验组
  UP       = "#C95A5A",   # 暖红：上调/正向
  DOWN     = "#4F79A7",   # 蓝：下调/负向
  HIGHLIGHT = "#D88A24",  # 金橙：重点标记
  NEUTRAL  = "#D7D7D7",   # 浅灰：非显著/背景
  GROUP_1  = "#C0442B",   # 深暖橙红：第一分组
  GROUP_2  = "#9A9A9A",   # 中灰：第二分组
  GROUP_3  = "#2C6E9C",   # 冷蓝：第三分组
  GREY     = "#E6E6E6",   # 浅灰：grey zone / 弱信息
  HEAT_LOW = "#2166AC",   # 热图 diverging 低
  HEAT_MID = "#F7F7F7",   # 热图 diverging 中
  HEAT_HIGH = "#B2182B"   # 热图 diverging 高
)

## ---- 统一主题（返回 theme 对象，供 p + potato_theme() 使用）----
potato_theme <- function(base_size = 6.5, family = "Helvetica") {
  ggplot2::theme_classic(base_size = base_size, base_family = family) +
    ggplot2::theme(axis.line = ggplot2::element_line(linewidth = 0.35, colour = "black"),
          axis.ticks = ggplot2::element_line(linewidth = 0.35, colour = "black"),
          legend.title = ggplot2::element_text(size = base_size - 0.3),
          legend.text = ggplot2::element_text(size = base_size - 0.7),
          strip.text = ggplot2::element_text(size = base_size - 0.3, face = "bold"),
          plot.title = ggplot2::element_text(size = base_size + 0.5, face = "bold"),
          axis.text = ggplot2::element_text(size = base_size - 0.3),
          panel.grid = ggplot2::element_blank())
}

## ---- 设置全局主题（仅需要全局生效时调用）----
set_potato_theme <- function(base_size = 6.5, family = "Helvetica") {
  ggplot2::theme_set(potato_theme(base_size, family))
  invisible(potato_theme(base_size, family))
}

## ---- 统一导出（PDF / SVG / TIFF600 / PNG300）----
save_fig <- function(p, name, w_mm = 183, h_mm = 120, dpi = 600) {
  w <- w_mm / 25.4; h <- h_mm / 25.4
  svglite::svglite(paste0(name, ".svg"), width = w, height = h); print(p); dev.off()
  grDevices::cairo_pdf(paste0(name, ".pdf"), width = w, height = h, family = "Helvetica")
  print(p); dev.off()
  ragg::agg_tiff(paste0(name, ".tiff"), width = w, height = h, units = "in",
                 res = dpi, compression = "lzw"); print(p); dev.off()
  ggplot2::ggsave(paste0(name, ".png"), p, width = w, height = h, units = "in", dpi = 300)
  invisible(paste0(name, ".pdf"))
}

## ---- 物理尺寸 QA（合同核对：183/89 mm 等）----
qa_physical_size <- function(dir = ".", pattern = ".*\\.png$", dpi = 300) {
  pngs <- list.files(dir, pattern = pattern, full.names = TRUE)
  out <- data.frame(file = basename(pngs), width_mm = NA_real_, height_mm = NA_real_,
                    stringsAsFactors = FALSE)
  for (i in seq_along(pngs)) {
    im <- png::readPNG(pngs[i])
    out$width_mm[i] <- dim(im)[2] / dpi * 25.4
    out$height_mm[i] <- dim(im)[1] / dpi * 25.4
  }
  out$within_183 <- abs(out$width_mm - 183) < 0.5 | abs(out$width_mm - 89) < 0.5 |
                    abs(out$width_mm - 110) < 0.5
  print(out, row.names = FALSE, digits = 2)
  cat("PASS:", sum(out$within_183), "of", nrow(out), "within contract widths\n")
  invisible(out)
}
