# Potato_Figure — 发表级科研做图统一技能

融合三套规范：
1. **期刊出版级**（journal figure）：figure contract 五要素、backend 独占、archetype 分类、统一 R/Python quick-start。
2. **小论文主图规则**（manuscript main-figure rules）：压缩无效留白、bar 语法统一、证据叙事、公共队列视觉、模式图—数据紧邻。
3. **大论文发表级统一规则**（dissertation figure rules）：语义化颜色合同、物理尺寸/字号/线宽合同、留白与信息密度、bar/forest/heatmap 定量规则、IHC/IVIS/WB 专项、正文准入与内部审计双轨。

> 用途：任何期刊论文、学位论文、基金图、补充图的做图、改图、QA 或审图请求，均可调用本技能。
> 核心立场：**图表服务于科学逻辑**；审美服从于结论清晰、可辩护、可审阅。

---

## 安装（opencode / Claude Code / Codex）

将本目录放入 `~/.config/opencode/skills/Potato_Figure/`（或其他 agent 的 skills 目录），重启后即可通过技能名 `Potato_Figure` 调用。

配套文件：

| 文件 | 用途 |
|---|---|
| `examples/potato_theme.R` | R 统一主题、导出、物理尺寸 QA 函数（可直接 source） |
| `examples/example_usage.R` | 完整示例：forest + heatmap + 分面面板，含 source data 输出 |
| `scripts/validate_figure.R` | 交付前静态预检：manifest 完整性、source data 存在性、四格式齐全 |
| `scripts/qa_physical_size.R` | PNG 物理尺寸实测（183/89 mm 合同核对） |

---

## 0. 做图前必须建立的 Figure Contract（五要素）

任何图在写代码前先回答：

1. **核心结论（一句话）**：这张图要辩护的单一 claim。
2. **证据链**：每个 panel 对应 claim 的哪一环；不能承担独立证据的 panel 删除。
3. **Archetype 分类**：`quantitative grid`（定量网格）/ `schematic-led composite`（模式图引导复合图）/ `image plate + quant`（图像板+定量）/ `asymmetric mixed-modality`（不对称混合模态）。
4. **Backend**：R 或 Python，选定后全程独占（绘图、预览、导出、视觉 QA 均用同一种语言）。
5. **Journal/export contract**：最终尺寸、字号下限、统计与 n、source data、图像完整性说明、导出格式（PDF/SVG/PNG/TIFF）。

每张图只有一个 **hero panel**；其余 panel 为它提供设计、复现与解释。遮住任一 panel 若整图论证无信息损失，删除或合并。

## 1. Backend 与运行环境

- 默认 **R**（ggplot2 / patchwork / ComplexHeatmap / ggrepel / svglite / ragg / cairo_pdf）；复杂热图用 ComplexHeatmap。
- 若用户明确要求 Python（matplotlib/seaborn），切换到 Python 并同样独占。
- 选定 backend 后不得跨语言渲染预览或导出。
- 缺失运行时/包时：报告具体 blocker，给出安装命令，不得改用另一语言画替代图。
- 位图导出优先 `ragg::agg_tiff()`/`agg_png()`；矢量 `svglite::svglite()` + `cairo_pdf()`；不用依赖 X11 的 `png()`。

### R 统一主题（quick-start，完整版见 examples/potato_theme.R）

```r
source("examples/potato_theme.R")   # 载入 potato_theme()、set_potato_theme()、save_fig()、qa_physical_size()
set_potato_theme()                  # 可选：设置全局主题（整份脚本用同一风格时调用）
```

```r
# 推荐用法：局部叠加（不污染全局）
p <- ggplot(...) + potato_theme()

# 或者需要全局统一时：
set_potato_theme()
```

> `potato_theme()` 只返回 theme 对象（可 `p + potato_theme()` 局部使用）；
> `set_potato_theme()` 才调用 `theme_set()` 设置全局主题。两者不要混用。

统一导出函数（每图四格式）：

```r
save_fig <- function(p, name, w_mm = 183, h_mm = 120, dpi = 600) {
  w <- w_mm / 25.4; h <- h_mm / 25.4
  svglite(paste0(name, ".svg"), width = w, height = h); print(p); dev.off()
  cairo_pdf(paste0(name, ".pdf"), width = w, height = h, family = "Helvetica"); print(p); dev.off()
  ragg::agg_tiff(paste0(name, ".tiff"), width = w, height = h, units = "in", res = dpi,
                 compression = "lzw"); print(p); dev.off()
  ggsave(paste0(name, ".png"), p, width = w, height = h, units = "in", dpi = 300)
}
```

## 2. 语义化颜色合同（通用语义，全文冻结，跨图不得换色）

所有 panel 只调用语义名称，禁止手写散色。

**通用语义色**（`examples/potato_theme.R` 中 `POTATO_COLORS`，任何课题通用）：

| 语义 | 颜色 | 十六进制 |
|---|---|---|
| CONTROL / 对照（细胞、动物、基线） | 中性深灰 | `#595959` |
| TREATMENT / 处理、疾病、实验组 | 暖红 | `#C95A5A` |
| UP / 上调 / 正向 | 暖红 | `#C95A5A` |
| DOWN / 下调 / 负向 | 蓝 | `#4F79A7` |
| HIGHLIGHT / 重点标记 | 金橙 | `#D88A24` |
| NEUTRAL / 非显著、背景 | 浅灰 | `#D7D7D7` |
| GROUP_1 / 第一分组 | 深暖橙红 | `#C0442B` |
| GROUP_2 / 第二分组 | 中灰 | `#9A9A9A` |
| GROUP_3 / 第三分组 | 冷蓝 | `#2C6E9C` |
| GREY / 弱信息、grey zone | 浅灰 | `#E6E6E6` |
| 热图 diverging 低/中/高 | 蓝/白/红 | `#2166AC` / `#F7F7F7` / `#B2182B` |

**项目专属语义**（疾病分组、分子标志等）通过 `profiles/` 加载：

```text
profiles/
  generic_biomedical.yaml    # 通用生物医学默认（内置）
  user_project.yaml          # 用户项目专属色（自行维护，不进入通用发布版）
```

规则：
- 红/蓝仅用于有明确定义的方向（上调/下调、处理/对照），不得同时充当无关类别色。
- 相同条件跨 Figure 颜色一致；组序一致。
- 每图一主色族 + 一信号色族 + 一强调色族；克制、色觉友好，不用彩虹色。
- 项目专属色只存在于 `user_project.yaml`，通用版不得包含任何单课题语义（如疾病分组名、特定基因名）。

## 3. 物理尺寸、字号与线宽合同

### 3.1 尺寸

**默认 profile**（未指定期刊时使用）：

| 图型 | 宽 | 高 |
|---|---|---|
| 双栏整图 | 183 mm | 按内容 120–225 mm |
| 单栏图 | 89 mm | 按内容 |
| 两组紧凑定量 panel | 42–55 mm | 45–52 mm |
| 三至四组定量 panel | 55–75 mm | 45–52 mm |

**指定目标期刊时**：加载期刊 profile，核对期刊官网当前投稿指南，覆盖默认值。
未知期刊/未指定时，交付物只能标为 provisional figure，投稿前必须重新核对。

> 89/183 mm 是常用默认，不是 universal contract；不同期刊（如双栏宽度、
> figure 上限、补充图规格）可能有差异，以目标期刊官方指南为准。

- panel 宽度随组数线性变化，bar 宽度与 panel 高度保持近似恒定；不把 2 组 bar 拉成宽幅。
- IVIS/IHC/组织代表图按证据重要性优先获得面积，不与小型 bar 等宽。

### 3.2 最终印刷字号

| 元素 | 目标字号 |
|---|---:|
| panel 字母 | 9–10 pt 粗体 |
| 坐标标题 | 7.5–8.5 pt |
| 坐标刻度 | 7–8 pt |
| 图内直接标签 | 7–8 pt |
| 图例 | 7–7.5 pt |
| 热图基因/通路名 | ≥6.5 pt，超量则删减或移补图 |

- 最小可接受：期刊图 5 pt，学位论文终稿 7 pt（关键标签 ≥8 pt）。
- 任何文字不得依赖放大查看器；拼版后以 100% 最终尺寸复核。

### 3.3 线宽与点

- 坐标轴 0.45–0.55 pt；误差条 0.5–0.7 pt；数据线 0.7–1.0 pt。
- 原始点最终尺寸约 1.5–2.2 mm，轻微抖动但不遮挡配对线。
- 每轮导出记录：数据区域占比、最大连续空白区、bar 实际 mm 尺寸、最小字体；不达标不得标为投稿版。

## 4. 留白与信息密度

1. 留白用于分隔证据块，不用于把弱信息 panel 撑成等宽。
2. 连续坐标默认数据范围上方仅留 8%–12% 标注空间；禁止因星号把 y 轴翻倍。
3. 重复图例移除或整行共享；删除重复 panel 标题、灰色方法句、无信息背景框。
4. 图题尽量进图注；panel 内只保留必要小标题或直接标签。
5. 森林图/效应图按比较数决定行高，避免大面积空白象限。

## 5. 证据叙事与模式图规则

### 5.1 叙事顺序

`真实设计信息 → 首要结果 → 支持/稳健性 → 下一项设计 → 下一项结果`

- 模式图必须紧邻其数据；禁止三个同形模式图并列后集中堆数据。
- 一个 panel 一个问题；panel 顺序按因果层级：观察性关联 → 扰动方向 → 组织验证 → 功能/体内因果 → 分子机制。

### 5.2 模式图必须编码（不允许装饰性）

- 研究系统、干预/自然对比、时间先后、取材部位、n、统计单位、主要 contrast。
- 公开队列：GSE 编号、病例/样本数、病灶类型、配对或共享参照、primary/secondary/复发状态；未报告字段写 `not reported`，不得推断。
- 不同免疫背景/治疗状态/模型的动物不得混成一个汇总效应图。
- 禁止用箭头暗示未经设计支持的因果/时间演化；桑基/弦图等伪高级网络禁止。

### 5.3 高级锚点（可选增强）

- 每 1 幅高信息密度锚点图配 2–4 幅紧凑定量图。
- "高级"来自一个画面同时编码 ≥3 个有量化含义的维度（模型、方向、效应量、患者内配对、证据层级），不来自阴影/渐变/伪三维/图标堆砌。
- 终稿最大单侧无效外边距 <15%。

## 6. 定量图形语法（按场景选择）

### 6.1 优先图形

| 场景 | 优先图形 |
|---|---|
| 患者/动物配对 | 配对点线 + 效应量（slopegraph） |
| 独立生物学重复 | 原始点 + 均值/95%CI，或箱线/小提琴 + 全部原始点 |
| 两组小样本 | 紧凑点图；若用 bar 必须叠加全部独立点 |
| 多数据集效应 | 森林图或方向矩阵（每个数据集效应+区间+设计类型） |
| 通路富集 | 紧凑 dot/lollipop：颜色=方向，大小=基因数/覆盖，横轴=NES 或效应量 |
| 表达连续分布 | 禁止纯 bar；violin/box + 原始点 |

### 6.2 bar 统一参数

- bar 宽 0.62–0.68 个离散单位；同类图固定高度、y 轴标题位置、误差端帽、点径、统计括号。
- bar 只作均值的淡色背景，前景必须保留全部独立点；配对数据保留连线。
- 纵轴零基线诚实；截断必须显示断点，不用视觉放大代替效应报告。
- 误差类型（SD/SEM/CI）写入图注；默认优先 95%CI 或 SD 并显示原始点，不用 SEM 掩盖离散。

### 6.3 统计合同（每 panel 必须可追溯）

独立 n、检验名称、配对/非配对、单/双侧、多重校正、效应量、精确 P 值。星号仅作辅助，不能替代精确 P 与统计合同。FDR 状态必须标注（不能只标 nominal P）。

### 6.4 热图

- 保存实际绘图矩阵、行列排序与标准化方式（source data）。
- 按可读行数决定高度；不用大画布包围少量矩阵。
- diverging 色板只用于有明确 0 点的数据；行/列名最小字号按 §3.2。

### 6.5 森林图

- Y 轴 = 事件/比较；X = OR/HR/效应量（log 尺度时标注）。
- 显示效应量、95%CI、n/N、FDR；重点事件可用语义强调色，但不得成为整图中心标题。

## 7. 图像 panel（IHC / IVIS / WB）

### IHC
- 先小型患者特征表，再代表图（统一倍率/裁剪/色彩校正，含比例尺与标签），再患者级配对定量。
- 统计单位 = 患者，视野不是 n；无正交身份标志（如 CD138）时不得把形态学 ROI 写成已证实肿瘤细胞。

### IVIS
- 鼠体与信号占 tile 主要面积；裁掉黑底、软件边框、UI。
- 同一比较一致色标；若改变必须分面标记并禁止直接强度比较。
- CTR vs OE 与 CTR vs KD 定量分别绘制，不混一个 bar。
- 无原始 ROI/photon flux 时只能称 anatomical proxy。

### WB
- 条带裁剪高度一致、宽度按泳道数等比例；不改变条带几何。
- 全长膜、分子量、曝光、重复、归一化必须保留；效率 WB 与机制 WB 分工。
- 无独立重复 densitometry 不得宣称定量验证。

## 8. 数据完整性与禁止事项

1. 使用全部合格观察值；排除须有科学/统计理由并记录 before/after 计数与规则（QA 备注）。
2. 保留全部阴性、相反与不确定结果；不做结果驱动的基因集/阈值/样本/方向替换。
3. 禁止：伪重复（部位/视野/细胞当独立 n）、跨平台合并原始表达、结果驱动换 cutoff、LASSO/RF 事后挑特征、"最显著"面板替换主分析。
4. 内部审计图不删除、不改造成阳性；QC 失败材料进 internal_audit，不占正文。
5. 实验未做/未返回：留空白 contract 占位，禁止模拟数据。

## 9. 交付包（每张最终图）

- 绘图脚本（R/Python）
- `source_data/`：每 panel 一个 TSV（原始观察值、统计单位、n、变换、检验）
- PDF、SVG（可编辑文字）、600 dpi LZW TIFF、300 dpi PNG preview
- 图注与统计说明（含精确 P/FDR、效应量、n、误差类型）
- QA 文档：尺寸、字号、颜色、分辨率、数值抽查、session info、输入哈希
- 内部审计表：被排除/未上主图结果及其原因
- `figure_manifest.tsv`：panel | script | source_data | statistical unit | n | transformation | statistical test | output file

## 10. QA 清单（交付前逐项）

- [ ] Figure contract 五要素已写（核心结论/证据链/archetype/backend/export）
- [ ] 统计单位正确（患者/动物/独立实验；无伪重复）
- [ ] n 与 FDR 标注；无仅 nominal P
- [ ] 颜色全部来自语义合同
- [ ] 183/89 mm 物理尺寸；字号 ≥ 合同下限；100% 尺寸复核
- [ ] 无无效留白；bar 语法统一；原始点全部保留
- [ ] source data 每 panel 齐全；阴性结果保留
- [ ] 四格式导出 + manifest + QA 记录

## 11. 集成建议（agent 使用）

1. 收到做图请求 → 先写 Figure contract（§0），再动笔。
2. 每次改图前先更新 contract，再改代码，避免"为了好看"漂移。
3. 导出后必须跑 `scripts/qa_physical_size.R` 与 `scripts/validate_figure.R`，全部 PASS 才能交付。
4. 所有颜色、尺寸、字号参数只从 `examples/potato_theme.R` 调用，禁止在面板内硬编码。
