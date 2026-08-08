# example_usage.R — Potato_Figure 完整示例
# 展示: forest + heatmap + 分面面板 的合同化实现，含 source data 输出
# 运行: Rscript example_usage.R  （输出到 ./example_output/，位于脚本同目录）

script_dir <- dirname(normalizePath(sub("^--file=", "",
  commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))])))
setwd(script_dir)
suppressMessages({library(ggplot2); library(patchwork)})
source("potato_theme.R")
set_potato_theme()
dir.create("example_output", showWarnings = FALSE)

## ---- 示例数据（模拟，仅演示图形语法；真实项目禁止模拟数据）----
set.seed(1)
n <- 60
d <- data.frame(
  group = factor(rep(c("GROUP_1", "GROUP_3"), each = n / 2), levels = c("GROUP_1", "GROUP_3")),
  score = c(rnorm(n / 2, 0.3, 1), rnorm(n / 2, 0, 1))
)
eff <- data.frame(
  event = c("Cytogenetic high risk", "del17p", "1q21 gain", "TP53 disruption",
            "t(4;14)", "t(14;16)", "Hyperdiploidy", "MYC any"),
  or = c(1.42, 1.91, 1.43, 2.53, 1.38, 0.27, 0.84, 0.97),
  lo = c(0.65, 0.73, 0.67, 0.99, 0.54, 0.02, 0.40, 0.46),
  hi = c(3.09, 5.01, 3.07, 6.45, 3.55, 4.73, 1.76, 2.07),
  fdr = rep("FDR ns", 8), stringsAsFactors = FALSE)
eff$event <- factor(eff$event, levels = rev(eff$event))

## ---- Panel 1: patient-level distribution（原始点 + 箱线）----
p1 <- ggplot(d, aes(group, score)) +
  geom_jitter(width = 0.16, size = 0.7, alpha = 0.45, colour = "grey40") +
  geom_boxplot(aes(fill = group), width = 0.45, outlier.shape = NA, alpha = 0.18,
               linewidth = 0.35) +
  scale_fill_manual(values = stats::setNames(
    as.character(POTATO_COLORS[c("GROUP_1", "GROUP_3")]), c("GROUP_1", "GROUP_3")),
    guide = "none") +
  labs(x = NULL, y = "Patient-level score") +
  potato_theme()

## ---- Panel 2: forest（FDR 标注，log 尺度）----
p2 <- ggplot(eff, aes(or, event)) +
  geom_vline(xintercept = 1, linetype = 2, colour = "grey60", linewidth = 0.35) +
  geom_errorbar(aes(xmin = lo, xmax = hi), width = 0.22, linewidth = 0.45) +
  geom_point(colour = POTATO_COLORS["GROUP_3"], size = 2.1) +
  geom_text(aes(label = fdr), x = 3.2, hjust = 0, size = 2, colour = "grey30") +
  scale_x_log10(limits = c(0.08, 8), breaks = c(0.1, 0.3, 1, 3)) +
  labs(x = "OR (95% CI)", y = NULL) +
  potato_theme()

## ---- Panel 3: heatmap（diverging 色板）----
hm <- data.frame(row = rep(letters[1:5], 3), col = rep(1:3, each = 5),
                 value = round(rnorm(15, 0, 1.2), 2))
p3 <- ggplot(hm, aes(factor(col), row, fill = value)) +
  geom_tile(colour = "white", linewidth = 0.5) +
  scale_fill_gradient2(low = POTATO_COLORS["HEAT_LOW"], mid = POTATO_COLORS["HEAT_MID"],
                       high = POTATO_COLORS["HEAT_HIGH"], midpoint = 0, name = "NES") +
  labs(x = NULL, y = NULL) +
  potato_theme() + theme(panel.border = element_rect(fill = NA, colour = "grey70", linewidth = 0.35))

## ---- 拼版 + 导出 ----
fig <- (p1 | p3) / p2 +
  plot_annotation(title = "Example figure (Potato_Figure)",
                  theme = theme(plot.title = element_text(size = 8, face = "bold")))
save_fig(fig, "example_output/example_figure", 183, 140)

## ---- source data + manifest ----
write.table(d, "example_output/panel1_data.tsv", sep = "\t", row.names = FALSE, quote = FALSE)
write.table(eff, "example_output/panel2_data.tsv", sep = "\t", row.names = FALSE, quote = FALSE)
write.table(hm, "example_output/panel3_data.tsv", sep = "\t", row.names = FALSE, quote = FALSE)
write.table(data.frame(panel = c("1", "2", "3"), script = "example_usage.R",
  source_data = c("panel1_data.tsv", "panel2_data.tsv", "panel3_data.tsv"),
  statistical_unit = "patient", n = n, transformation = "raw",
  statistical_test = "Wilcoxon / logistic", output_file = "example_figure.pdf"),
  "example_output/figure_manifest.tsv", sep = "\t", row.names = FALSE, quote = FALSE)

## ---- QA ----
qa_physical_size("example_output")
cat("example complete\n")
