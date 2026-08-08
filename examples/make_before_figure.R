# make_before_figure.R — 生成 gallery 用的 "before"（默认 ggplot，无合同）
# 对照用途：展示 Potato_Figure 之前 vs 之后。仅用于 README gallery 演示。
# 运行: Rscript make_before_figure.R  （输出 before_figure.png）

script_dir <- dirname(normalizePath(sub("^--file=", "",
  commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))])))
setwd(script_dir)
suppressMessages({library(ggplot2); library(patchwork)})

## ---- 同样的数据，默认 ggplot 直接画（无主题/无颜色合同/无统计合同）----
set.seed(1)
n <- 60
d <- data.frame(
  group = factor(rep(c("Group A", "Group B"), each = n / 2)),
  score = c(rnorm(n / 2, 0.3, 1), rnorm(n / 2, 0, 1))
)
eff <- data.frame(
  event = c("Cytogenetic high risk", "del17p", "1q21 gain", "TP53 disruption",
            "t(4;14)", "t(14;16)", "Hyperdiploidy", "MYC any"),
  or = c(1.42, 1.91, 1.43, 2.53, 1.38, 0.27, 0.84, 0.97),
  lo = c(0.65, 0.73, 0.67, 0.99, 0.54, 0.02, 0.40, 0.46),
  hi = c(3.09, 5.01, 3.07, 6.45, 3.55, 4.73, 1.76, 2.07),
  stringsAsFactors = FALSE)
eff$event <- factor(eff$event, levels = rev(eff$event))

## Panel 1: 默认 boxplot（无原始点、默认配色）
p1 <- ggplot(d, aes(group, score)) +
  geom_boxplot(aes(fill = group), width = 0.5) +
  scale_fill_manual(values = c("red3", "steelblue"), guide = "none") +
  labs(x = NULL, y = "score")

## Panel 2: 默认 heatmap（彩虹色）
hm <- data.frame(row = rep(letters[1:5], 3), col = rep(1:3, each = 5),
                 value = round(rnorm(15, 0, 1.2), 2))
p2 <- ggplot(hm, aes(factor(col), row, fill = value)) +
  geom_tile(colour = "white") +
  scale_fill_gradientn(colours = rainbow(7), name = "NES") +
  labs(x = NULL, y = NULL)

## Panel 3: 默认 forest（无 FDR 标注、无 log 刻度、默认点色）
p3 <- ggplot(eff, aes(or, event)) +
  geom_vline(xintercept = 1, linetype = 2, colour = "grey") +
  geom_errorbar(aes(xmin = lo, xmax = hi), width = 0.2) +
  geom_point(colour = "steelblue", size = 2) +
  labs(x = "OR", y = NULL)

fig <- (p1 | p2) / p3 +
  plot_annotation(title = "Before: default ggplot (no contract)")

dir.create("gallery", showWarnings = FALSE)
ggsave("gallery/before_figure.png", fig, width = 183 / 25.4, height = 140 / 25.4,
       units = "in", dpi = 300)
cat("before figure written to gallery/before_figure.png\n")
