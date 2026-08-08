# make_annotated_before.R — 生成"错误标注版" Before 图
# 在默认 ggplot 的 before 图上标注典型科研作图错误（红色编号框），
# 用于 README gallery 与小红书传播：直观展示"错在哪"，而非只展示"丑在哪"。
# 运行: Rscript make_annotated_before.R  （输出 gallery/annotated_before.png）

script_dir <- dirname(normalizePath(sub("^--file=", "",
  commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))])))
setwd(script_dir)
suppressMessages({library(ggplot2); library(patchwork)})

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

## 错误标注样式
mark <- function(x, y, label, xmin, xmax, ymin, ymax) {
  list(
    annotate("rect", xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax,
             fill = NA, colour = "#D7191C", linewidth = 0.9, linetype = "dashed"),
    annotate("point", x = x, y = y, colour = "#D7191C", size = 6, shape = 21,
             fill = "white", stroke = 1.6),
    annotate("text", x = x, y = y, label = label, colour = "#D7191C",
             size = 3.4, fontface = "bold")
  )
}

## Panel 1: 箱线图 —— 错误①：隐藏原始点（伪重复风险、n 不可见）
p1 <- ggplot(d, aes(group, score)) +
  geom_boxplot(aes(fill = group), width = 0.5) +
  scale_fill_manual(values = c("red3", "steelblue"), guide = "none") +
  labs(x = NULL, y = "score") +
  mark(1.5, 1.72, "1", 0.55, 2.45, 1.45, 2.05) +
  coord_cartesian(ylim = c(-2.5, 2.2))

## Panel 2: 热图 —— 错误②：彩虹色板（色觉不友好、0 点无语义）
hm <- data.frame(row = rep(letters[1:5], 3), col = rep(1:3, each = 5),
                 value = round(rnorm(15, 0, 1.2), 2))
p2 <- ggplot(hm, aes(factor(col), row, fill = value)) +
  geom_tile(colour = "white") +
  scale_fill_gradientn(colours = rainbow(7), name = "NES") +
  labs(x = NULL, y = NULL) +
  mark(2, 0.65, "2", 0.55, 3.45, 0.15, 1.15) +
  coord_cartesian(ylim = c(0, 5.6))

## Panel 3: 森林图 —— 错误③：无 FDR/n 标注（显著性不可判断）
p3 <- ggplot(eff, aes(or, event)) +
  geom_vline(xintercept = 1, linetype = 2, colour = "grey") +
  geom_errorbar(aes(xmin = lo, xmax = hi), width = 0.2) +
  geom_point(colour = "steelblue", size = 2) +
  labs(x = "OR", y = NULL) +
  mark(3.6, 8.5, "3", 2.9, 4.3, 7.3, 9.7) +
  coord_cartesian(xlim = c(0, 4.6), ylim = c(0.5, 10))

## 错误编号图例（底部）
err_legend <- data.frame(x = 1:4, y = rep(1, 4), lab = c(
  "1 箱线图隐藏原始点：n=60 不可见，伪重复风险",
  "2 彩虹色板：色觉不友好、无 0 点语义",
  "3 森林图无 FDR/n 标注：显著性不可判断",
  "4 无 Source Data / manifest / QA：不可追溯"))
p4 <- ggplot(err_legend, aes(x, y)) +
  geom_blank() +
  annotate("rect", xmin = 0.4, xmax = 4.6, ymin = 0.4, ymax = 1.75,
           fill = NA, colour = "#D7191C", linewidth = 0.8, linetype = "dashed") +
  annotate("point", x = 0.55, y = 1.1, colour = "#D7191C", size = 4, shape = 21,
           fill = "white", stroke = 1.4) +
  annotate("text", x = 0.7, y = 1.1, label = "4", colour = "#D7191C",
           size = 2.8, fontface = "bold") +
  annotate("text", x = 2.6, y = 1.1, hjust = 0.5,
           label = "这张图看起来正常，但四类错误都会被审稿人抓住",
           size = 3.2, colour = "grey25") +
  labs(x = NULL, y = NULL) +
  theme_void() +
  coord_cartesian(xlim = c(0.3, 4.7), ylim = c(0.3, 1.9))

fig <- (p1 | p2) / p3 / p4 +
  plot_annotation(title = "Before: 默认 ggplot — 错在哪？(4 处典型错误)",
                  theme = theme(plot.title = element_text(size = 9, face = "bold")))

dir.create("gallery", showWarnings = FALSE)
ggsave("gallery/annotated_before.png", fig, width = 183 / 25.4, height = 190 / 25.4,
       units = "in", dpi = 300)
cat("annotated before figure written to gallery/annotated_before.png\n")
