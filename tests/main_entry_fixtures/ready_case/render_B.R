# B 版：完整 workflow 版（合成数据（synthetic myeloma cohort））
# 与 C 版差异（workflow 检查统计错误, nature-figure 不查）:
#   1. 统计单位: 样本去重到患者级（774 样本 -> 764 患者, 修复伪重复）
#   2. 多重校正: 12 基因 log-rank 全做 + BH-FDR, KM 标注 q 值而非未校正 P
#      （CD19 P=0.0214 未校正似显著, FDR 后 q=0.051 不显著 -> 不误导）
#   3. 森林图标 q 值 + 显著阈值
#   4. f 面板 = FDR 校正证据面板（nature-figure 流程不会生成这个）
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
dat0 <- merge(expr, phe, by = "sample")

## ---- 统计单位修复: 样本 -> 患者（修复 C 版伪重复）----
dat0$patient <- sub("^([^_]+_[^_]+)_.*$", "\\1", dat0$sample)
cat("=== B 版统计单位检查 ===\n")
cat("样本数:", nrow(dat0), "| 患者数:", length(unique(dat0$patient)), "\n")
dat <- dat0[!duplicated(dat0$patient), ]   # 每患者保留一个样本
cat("去重后样本数:", nrow(dat), "（修复", nrow(dat0) - nrow(dat), "个伪重复样本）\n")

## ---- 统一语义色族（potato-user-v1）----
HIGH_COL <- "#F47F68"; LOW_COL <- "#5B8CCB"; STRUCT <- "black"   # 结构线用黑, 不引入灰色系
NS_COL   <- "#A9C6E8"   # 不显著: 低饱和蓝（保持色系方向, 不用灰色）
NS_BAR   <- "#C6D9EE"   # 不显著柱: 淡蓝（sat>0.15, 可被彩色判定识别）

## ---- 预后分组（High = 预后差 / Low = 预后好）----
mk_grp <- function(dd, gene) {
  dd$g <- ifelse(dd[[gene]] > median(dd[[gene]], na.rm = TRUE), "High", "Low")
  dd
}

## ---- 多重校正: 12 基因 log-rank + BH-FDR（修复 C 版选择性报告）----
logrank_all <- sapply(names(expr)[-1], function(g) {
  dd <- mk_grp(dat, g)
  lr <- survdiff(Surv(OS.time, OS) ~ g, data = dd)
  1 - pchisq(lr$chisq, 1)
})
q_all <- p.adjust(logrank_all, method = "BH")
cat("=== B 版多重校正（BH-FDR, n=12 检验）===\n")
print(round(rbind(P = logrank_all, q = q_all), 4))
cat("FDR q<0.05 的基因:", sum(q_all < 0.05), "个\n")

## ---- a/b: KM 生存曲线（患者级, 标 BH-FDR q 值）----
mk_km <- function(dat, gene, seed) {
  set.seed(seed)
  dd <- mk_grp(dat, gene)
  fit <- survfit(Surv(OS.time, OS) ~ g, data = dd)
  lr <- survdiff(Surv(OS.time, OS) ~ g, data = dd)
  pval <- 1 - pchisq(lr$chisq, 1)
  qval <- q_all[[gene]]
  sf <- data.frame(time = fit$time, surv = fit$surv, strata = rep(names(fit$strata), fit$strata))
  sf$grp <- ifelse(grepl("High", sf$strata), "High", "Low")
  ggplot(sf, aes(time, surv, colour = grp)) +
    geom_step(linewidth = 0.5) +
    scale_colour_manual(values = c("High" = HIGH_COL, "Low" = LOW_COL)) +
    annotate("text", x = max(sf$time) * 0.6, y = 0.15,
             label = sprintf("FDR q = %.3g", qval), size = 2.5, colour = "black") +
    labs(title = paste(gene, ": prognosis groups (patient-level, n =", nrow(dd), ")"),
         x = "Days", y = "OS Probability") +
    theme(legend.position = "bottom", legend.key.height = unit(0.2, "cm"))
}
## a/b: 与 C 版同一对基因（CD38 真显著 / CD19 校正后不显著）
p1 <- mk_km(dat, "CD38", 1)
p2 <- mk_km(dat, "CD19", 2)

## ---- c: 表达分布（SDC1 预后分组 × CD19, 语义色）----
dat_grp <- mk_grp(dat, "SDC1")
p3 <- ggplot(dat_grp, aes(g, CD19, colour = g)) +
  geom_jitter(width = 0.12, size = 0.6, alpha = 0.35) +
  geom_boxplot(fill = NA, width = 0.4, outlier.shape = NA, linewidth = 0.35) +
  scale_colour_manual(values = c("High" = HIGH_COL, "Low" = LOW_COL)) +
  labs(x = NULL, y = "CD19 expression") +
  theme(legend.position = "none")

## ---- d: 基因相关热图（0 中心蓝白红）----
cor_m <- cor(expr[, -1], use = "pairwise.complete.obs")
corm <- melt(cor_m)
p4 <- ggplot(corm, aes(Var1, Var2, fill = value)) +
  geom_tile(colour = "white", linewidth = 0.3) +
  scale_fill_gradient2(low = LOW_COL, mid = "white", high = HIGH_COL, midpoint = 0,
                       limits = c(-1, 1), name = "r") +
  labs(x = NULL, y = NULL) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 5.8))

## ---- e: 表达热图（50 样本 × 12 基因, z-score）----
set.seed(42)
sub50 <- expr[sample(nrow(expr), 50), ]
z <- scale(sub50[, -1])
eml <- melt(data.frame(sample = sub50$sample, z), id.vars = "sample")
p5 <- ggplot(eml, aes(variable, sample, fill = value)) +
  geom_tile(colour = "white", linewidth = 0.3) +
  scale_fill_gradient2(low = LOW_COL, mid = "white", high = HIGH_COL, midpoint = 0, name = "z") +
  labs(x = NULL, y = NULL) +
  theme(axis.text = element_blank(), axis.ticks = element_blank())

## ---- f: FDR 校正证据面板（12 基因 log-rank, q<0.05 阈值线）----
## 这是 workflow 统计检查的核心证据: C 版不会生成
p6 <- ggplot(data.frame(gene = names(q_all), q = q_all, p = logrank_all),
             aes(reorder(gene, p), p)) +
  geom_hline(yintercept = 0.05, linetype = 2, colour = STRUCT, linewidth = 0.3) +
  geom_bar(stat = "identity", aes(fill = q < 0.05), width = 0.7) +
  geom_point(aes(y = q, colour = "FDR q"), size = 1.6, shape = 21, stroke = 0.8, fill = "white") +
  geom_text(aes(y = q, label = sprintf("q=%.2g", q)), hjust = -0.2, size = 1.8, colour = "black") +
  scale_fill_manual(values = c("TRUE" = HIGH_COL, "FALSE" = NS_BAR), guide = "none") +
  scale_colour_manual(values = c("FDR q" = LOW_COL), name = NULL) +
  coord_flip() +
  labs(x = NULL, y = "log-rank P (bar) / BH-FDR q (open circle)") +
  theme(legend.position = "bottom", legend.key.height = unit(0.2, "cm"),
        axis.text = element_text(size = 5.8))

## ---- g: 森林图（cox HR, 标 q 值 + 显著阈值）----
cox_res <- do.call(rbind, lapply(names(expr)[-1], function(g) {
  dd <- mk_grp(dat, g)
  cf <- coxph(Surv(OS.time, OS) ~ g, data = dd)
  s <- summary(cf)
  data.frame(gene = g, hr = s$conf.int[1, 1], lo = s$conf.int[1, 3],
             hi = s$conf.int[1, 4], p = s$coefficients[1, 5])
}))
cox_res$q <- q_all[cox_res$gene]
cox_res$sig <- cox_res$q < 0.05
p7 <- ggplot(cox_res, aes(hr, reorder(gene, hr))) +
  geom_vline(xintercept = 1, linetype = 2, colour = STRUCT, linewidth = 0.3) +
  geom_errorbarh(aes(xmin = lo, xmax = hi, colour = sig), height = 0.3, linewidth = 0.5) +
  geom_point(aes(colour = sig), size = 1.8) +
  geom_text(aes(label = sprintf("q=%.2g", q)), x = max(cox_res$hi) * 1.15, hjust = 0, size = 1.8, colour = "black") +
  scale_colour_manual(values = c("TRUE" = HIGH_COL, "FALSE" = NS_COL), guide = "none") +
  scale_x_log10() +
  coord_cartesian(xlim = c(min(cox_res$lo) * 0.8, max(cox_res$hi) * 1.9)) +
  labs(x = "Hazard Ratio (95% CI), q = BH-FDR", y = NULL) +
  theme(axis.text = element_text(size = 5.8))

## ---- h: 表达相关散点（SDC1 × CD38, 条件色 + 回归）----
p8 <- ggplot(dat_grp, aes(SDC1, CD38, colour = g)) +
  geom_point(size = 0.6, alpha = 0.5) +
  geom_smooth(method = "lm", se = TRUE, colour = STRUCT, fill = NS_BAR, linewidth = 0.4) +
  scale_colour_manual(values = c("High" = HIGH_COL, "Low" = LOW_COL)) +
  labs(x = "SDC1", y = "CD38") +
  theme(legend.position = "none")

## ---- i: 生存时间分布（患者级, 语义色）----
p9 <- ggplot(dat_grp, aes(OS.time, fill = g)) +
  geom_histogram(bins = 30, position = "identity", alpha = 0.6, colour = "white", linewidth = 0.2) +
  scale_fill_manual(values = c("High" = HIGH_COL, "Low" = LOW_COL)) +
  labs(x = "OS time (days)", y = "count") +
  theme(legend.position = "bottom", legend.key.height = unit(0.2, "cm"))

## ---- 组装: hero 主导非等宽（KM 大块）----
design <- "aabb\nccdd\nccdd\neeff\neeff\nghii\nghii"
fig <- p1 + p2 + p3 + p4 + p5 + p6 + p7 + p8 + p9 + plot_layout(design = design)

save_pub_r(fig, file.path(out, "figure"), width_mm = 183, height_mm = 190, dpi = 600)
ggsave(file.path(out, "figure.png"), fig, width = 183/25.4, height = 190/25.4, dpi = 300)
cat("B版（workflow）synthetic 9-panel 完成\n")
