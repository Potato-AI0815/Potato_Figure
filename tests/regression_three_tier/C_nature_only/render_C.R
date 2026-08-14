# C 版：只用 nature-figure（不检查统计错误 + 无意识局部灰化）
# 体现的问题:
#   1. 12 个基因都做了 log-rank 检验, 只挑 2 个显著的展示（selective reporting）
#      未做多重校正（BH-FDR）—— nature-figure 不检查 multiplicity
#   2. 分组按预后: High（表达高 = 预后差）/ Low（表达低 = 预后好）
#   3. 样本当 n（10 患者有 2 个样本, 未按患者去重）—— nature-figure 不检查伪重复
#   4. 局部灰化: KM 主证据灰线 + 森林图不显著基因灰掉（无意识丢弃语义色）
#      —— 全图 neutral 不高（COLOR-04 抓不到）, 面板级 COLOR-13 才能抓
library(ggplot2); library(patchwork); library(reshape2)
suppressPackageStartupMessages(library(survival))

theme_set(
  theme_classic(base_size = 6.5, base_family = "Arial") +
    theme(
      axis.line = element_line(linewidth = 0.35, colour = "black"),
      axis.ticks = element_line(linewidth = 0.35, colour = "black"),
      legend.title = element_text(size = 6.2),
      legend.text = element_text(size = 5.8),
      strip.text = element_text(size = 6.2, face = "bold"),
      plot.title = element_text(size = 7, face = "bold"),
      panel.grid = element_blank()
    )
)

save_pub_r <- function(plot, filename, width_mm = 183, height_mm = 190, dpi = 600) {
  w <- width_mm / 25.4; h <- height_mm / 25.4
  svglite::svglite(paste0(filename, ".svg"), width = w, height = h); print(plot); dev.off()
  grDevices::cairo_pdf(paste0(filename, ".pdf"), width = w, height = h, family = "Arial"); print(plot); dev.off()
  ragg::agg_tiff(paste0(filename, ".tiff"), width = w, height = h, units = "in", res = dpi); print(plot); dev.off()
}

args <- commandArgs(trailingOnly = TRUE)
base <- if (length(args)) args[1] else "."
out <- file.path(base, "figure"); dir.create(out, showWarnings = FALSE, recursive = TRUE)

expr <- read.delim(file.path(base, "source_data", "synthetic_expression_targets.tsv"), check.names = FALSE)
phe  <- read.delim(file.path(base, "source_data", "synthetic_survival.tsv"), check.names = FALSE)
dat <- merge(expr, phe, by = "sample")

## ---- 语义色族（大部分面板正常用色; 只有 KM 主证据 + 森林图不显著处"无意识灰化"）----
HIGH_COL <- "#F47F68"; LOW_COL <- "#5B8CCB"; STRUCT <- "black"

## ---- 预后分组（High = 预后差 / Low = 预后好）----
mk_grp <- function(dd, gene) {
  dd$prog <- ifelse(dd[[gene]] > median(dd[[gene]], na.rm = TRUE), "Prognosis-poor", "Prognosis-good")
  dd
}

## ---- 统计错误 1: 12 基因全做 log-rank, 只挑 2 个显著的展示（无多重校正）----
logrank_all <- sapply(names(expr)[-1], function(g) {
  dd <- mk_grp(dat, g)
  lr <- survdiff(Surv(OS.time, OS) ~ prog, data = dd)
  1 - pchisq(lr$chisq, 1)
})
cat("=== C 版统计错误 1: 12 基因 log-rank 未校正 ===\n")
cat("12 个 P 值（未做 BH-FDR）:\n")
print(round(logrank_all, 4))
cat("只挑 P<0.05 的展示:", sum(logrank_all < 0.05), "个基因\n")

## ---- a/b: KM 曲线（预后分组）----
## 【灰化点 1】KM 主证据用灰色（默认灰线, 无意识丢弃语义色）
mk_km <- function(dat, gene, seed) {
  set.seed(seed)
  dd <- mk_grp(dat, gene)
  fit <- survfit(Surv(OS.time, OS) ~ prog, data = dd)
  lr <- survdiff(Surv(OS.time, OS) ~ prog, data = dd)
  pval <- 1 - pchisq(lr$chisq, 1)
  sf <- data.frame(time = fit$time, surv = fit$surv, strata = rep(names(fit$strata), fit$strata))
  sf$grp <- ifelse(grepl("poor", sf$strata), "Prognosis-poor", "Prognosis-good")
  ggplot(sf, aes(time, surv, colour = grp)) +
    geom_step(linewidth = 0.5) +
    scale_colour_manual(values = c("Prognosis-poor" = "grey25", "Prognosis-good" = "grey65")) +
    annotate("text", x = max(sf$time) * 0.55, y = 0.15,
             label = sprintf("log-rank P = %.3g* (uncorrected)", pval), size = 2.5, colour = "black") +
    labs(title = paste(gene, ": prognosis groups"), x = "Days", y = "OS Probability") +
    theme(legend.position = "bottom", legend.key.height = unit(0.2, "cm"))
}
## C 版: 挑 2 个"P<0.05"的基因展示（未做多重校正, 选择性报告）
## CD19: P=0.0214 未校正 -> 看似显著（实际 FDR 后不显著, 见 B 版 q=0.128）
p1 <- mk_km(dat, "CD38", 1)
p2 <- mk_km(dat, "CD19", 2)

## ---- c: 表达分布（预后分组 × CD19, 语义色）----
dat_grp <- mk_grp(dat, "SDC1")
p3 <- ggplot(dat_grp, aes(prog, CD19, colour = prog)) +
  geom_jitter(width = 0.12, size = 0.6, alpha = 0.35) +
  geom_boxplot(fill = NA, width = 0.4, outlier.shape = NA, linewidth = 0.35) +
  scale_colour_manual(values = c("Prognosis-poor" = HIGH_COL, "Prognosis-good" = LOW_COL)) +
  labs(x = NULL, y = "CD19 expression") +
  theme(legend.position = "none", axis.text.x = element_text(angle = 15, hjust = 1, size = 5.8))

## ---- d: 基因相关热图（语义蓝白红）----
cor_m <- cor(expr[, -1], use = "pairwise.complete.obs")
corm <- melt(cor_m)
p4 <- ggplot(corm, aes(Var1, Var2, fill = value)) +
  geom_tile(colour = "white", linewidth = 0.3) +
  scale_fill_gradient2(low = LOW_COL, mid = "white", high = HIGH_COL, midpoint = 0,
                       limits = c(-1, 1), name = "r") +
  labs(x = NULL, y = NULL) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 5.8))

## ---- e: 表达热图（50 样本 × 12 基因, z-score 语义色）----
set.seed(42)
sub50 <- expr[sample(nrow(expr), 50), ]
z <- scale(sub50[, -1])
eml <- melt(data.frame(sample = sub50$sample, z), id.vars = "sample")
p5 <- ggplot(eml, aes(variable, sample, fill = value)) +
  geom_tile(colour = "white", linewidth = 0.3) +
  scale_fill_gradient2(low = LOW_COL, mid = "white", high = HIGH_COL, midpoint = 0, name = "z") +
  labs(x = NULL, y = NULL) +
  theme(axis.text = element_blank(), axis.ticks = element_blank())

## ---- f: 预后分组组成（语义色）----
p6 <- ggplot(dat_grp, aes(prog, fill = prog)) +
  geom_bar(position = "fill", width = 0.7) +
  scale_fill_manual(values = c("Prognosis-poor" = HIGH_COL, "Prognosis-good" = LOW_COL)) +
  labs(x = NULL, y = "proportion") +
  theme(legend.position = "none", axis.text.x = element_text(angle = 15, hjust = 1, size = 5.8))

## ---- g: 森林图（cox HR, 不标 FDR 校正）----
cox_res <- do.call(rbind, lapply(names(expr)[-1], function(g) {
  dd <- mk_grp(dat, g)
  cf <- coxph(Surv(OS.time, OS) ~ prog, data = dd)
  s <- summary(cf)
  data.frame(gene = g, hr = s$conf.int[1, 1], lo = s$conf.int[1, 3], hi = s$conf.int[1, 4], p = s$coefficients[1, 5])
}))
## 统计错误 2: 12 个基因的 HR 都展示, 但未标多重校正
cat("=== C 版统计错误 2: 森林图无多重校正标注 ===\n")
cat("12 基因 HR 展示但无 BH-FDR q 值\n")
## 【灰化点 2】森林图: 不显著基因用灰（显著用语义色, 不显著灰掉）
p7 <- ggplot(cox_res, aes(hr, reorder(gene, hr))) +
  geom_vline(xintercept = 1, linetype = 2, colour = STRUCT, linewidth = 0.3) +
  geom_errorbarh(aes(xmin = lo, xmax = hi, colour = p < 0.05), height = 0.3, linewidth = 0.5) +
  geom_point(aes(colour = p < 0.05), size = 1.8) +
  scale_colour_manual(values = c("TRUE" = HIGH_COL, "FALSE" = "grey70")) +
  scale_x_log10() +
  labs(x = "Hazard Ratio (95% CI)", y = NULL) +
  theme(legend.position = "none", axis.text = element_text(size = 5.8))

## ---- h: 表达相关散点（SDC1 × CD38, 语义色）----
p8 <- ggplot(dat_grp, aes(SDC1, CD38, colour = prog)) +
  geom_point(size = 0.6, alpha = 0.5) +
  scale_colour_manual(values = c("Prognosis-poor" = HIGH_COL, "Prognosis-good" = LOW_COL)) +
  labs(x = "SDC1", y = "CD38") +
  theme(legend.position = "none")

## ---- i: 生存时间分布（预后分组叠放, 语义色）----
p9 <- ggplot(dat_grp, aes(OS.time, fill = prog)) +
  geom_histogram(bins = 30, position = "identity", alpha = 0.6, colour = "white", linewidth = 0.2) +
  scale_fill_manual(values = c("Prognosis-poor" = HIGH_COL, "Prognosis-good" = LOW_COL)) +
  labs(x = "OS time (days)", y = "count") +
  theme(legend.position = "bottom", legend.key.height = unit(0.2, "cm"))

## ---- 组装 ----
design <- "aabb\nccdd\nccdd\neeff\neeff\nghii\nghii"
fig <- p1 + p2 + p3 + p4 + p5 + p6 + p7 + p8 + p9 + plot_layout(design = design)

save_pub_r(fig, file.path(out, "figure"), width_mm = 183, height_mm = 190, dpi = 600)
ggsave(file.path(out, "figure.png"), fig, width = 183/25.4, height = 190/25.4, dpi = 300)
cat("C版（只用 nature-figure, 含统计错误）9-panel 完成\n")
