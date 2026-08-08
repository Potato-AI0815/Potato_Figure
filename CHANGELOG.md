# CHANGELOG

## [0.1.5-alpha] - 2026-08-08

### Changed

- **Multiplicity 规则科学化**：不再靠检验名称（Wilcoxon/Cox/ANOVA 等）自动
  断言"必须校正"——预指定两组比较不需要 multiplicity adjustment。
  改为 manifest 三字段驱动：`multiplicity_applicable`(yes/no) +
  `multiplicity_method` + `hypothesis_family`；
  yes 缺方法 → FAIL；no → PASS；字段缺失时仅对明显多重比较语境
  （genome-wide/pairwise/两两比较等）提示"请确认"，不制造假阳性。
- example manifest 新增三字段示范（预指定比较不校正 + 全基因组 BH-FDR）。
- README/README_EN 第一屏版本：v0.1.3 → v0.1.5。

### Verified

- 字段声明版（example）：10 rules 全 PASS
- 预指定两组 Wilcoxon（无字段、无多重语境）：multiplicity 不误报
- genome-wide/pairwise 语境（无字段）：提示"请确认"而非"必须校正"

## [0.1.4-alpha] - 2026-08-08

### Added

- **多重校正方法检查**：audit_figure.R 新增 multiplicity 规则——多组/多重
  比较检验（ANOVA/Kruskal/Wilcoxon/logistic/Cox/paired 等）必须声明
  BH/FDR/Holm/Bonferroni 校正方法，缺失时输出 WARNING + 建议。
  example manifest 已补示范正确写法（"Wilcoxon (BH-FDR)"）。
- **CI 增加 --json 模式验证**：audit_figure.R --json 输出经 python 解析
  校验，确认 JSON 模式可用且结构稳定。

### Fixed

- README/README_EN 第一屏版本残留：v0.1.1-alpha → v0.1.3-alpha。
- 仓库 description 版本号更新。
- audit_figure.R 头部注释明确能力边界：审计对象是交付目录的结构与元数据，
  不读取 PNG/PDF 图像像素内容（图像级检查属 v0.2 artefact inspector）。
- SKILL.md §9.5 规则表补充 multiplicity 规则 + 能力边界说明。

## [0.1.3-alpha] - 2026-08-08

### Added

- **Figure Audit（错误审计）**：`scripts/audit_figure.R` —— 输入交付目录，
  逐条输出 PASS/WARNING/FAIL + 错误说明 + 修改建议；审计规则：
  统计单位伪重复（cell/view/视野/ROI/切片 ≠ 独立 n）、n 完整性、检验声明、
  Source Data 存在性、四格式导出、拼版图感知的 output 检查。
  支持 `--json` 输出供 agent/CI 消费。
- **错误标注版 Before 图**：`examples/make_annotated_before.R` 生成
  `gallery/annotated_before.png`，在默认 ggplot 上标注 4 处典型错误
  （隐藏原始点、彩虹色板、无 FDR 标注、无 Source Data）。
- README Gallery 升级：明确"Before 错在哪"（4 处错误逐条对照），
  不再只是"丑 vs 好看"，而是"错 vs 对"。

### Changed

- SKILL.md 新增 §9.5 错误审计章节（Figure Audit 用法与规则表）。
- CI 增加 audit_figure.R 步骤。
- manifest.yaml 增加 audit 资产声明。

### Verified

- 好图审计：7 条规则全 PASS（拼版图正确识别为合法）。
- 坏图审计：准确抓出伪重复 / n=NA / source data 缺失 / 导出缺失。

## [0.1.1-alpha] - 2026-08-08

### Changed

- **颜色合同通用化**：移除单课题语义（IMM/EMM、SPATS2-OE/KD、B/C/D），
  替换为通用语义（CONTROL/TREATMENT/UP/DOWN/HIGHLIGHT/NEUTRAL/GROUP_1-3）；
  项目专属色改为 `profiles/` 机制，通用版不再包含任何单课题语义。
- **theme 接口拆分**：`potato_theme()` 现在只返回 theme 对象（可 `p + potato_theme()`），
  新增 `set_potato_theme()` 设置全局主题；修复两种用法混用的问题。
- **尺寸合同措辞**：89/183 mm 明确为"默认 profile"，指定目标期刊时必须
  核对期刊官方指南并覆盖默认值；未指定时交付物标为 provisional。
- **backend 声明**：manifest 改为 `supported_backends: [r]`，
  Python 标注为 policy-guided/experimental（暂无 Python 资产）。

### Added

- `profiles/README.md`：颜色 profile 分层说明（generic vs user_project）。
- `examples/make_before_figure.R` + `examples/gallery/`：Before/After 对照图，
  供 README gallery 与传播展示。

## [0.1.0] - 2026-08-08

### Added

- Initial release of Potato_Figure, merging three rule sets:
  - journal-level figure contracts (core conclusion / evidence chain / archetype / exclusive backend / export contract)
  - manuscript main-figure rules (whitespace compression, unified bar grammar, evidence-driven narrative, design–data adjacency)
  - dissertation-grade unified rules (semantic color contract, physical size/font/linewidth contract, quantitative figure grammar, IHC/IVIS/WB special rules, admission vs. internal-audit dual track)
- Semantic color contract (IMM/EMM, CTR/KD/OE, group B/C/D/grey, heatmap diverging)
- Unified R theme and four-format export (`examples/potato_theme.R`)
- Complete worked example (forest + heatmap + faceted panels + source data + manifest) (`examples/example_usage.R`)
- Static preflight script (`scripts/validate_figure.R`)
- Physical-size QA script (`scripts/qa_physical_size.R`)
- Bilingual README (zh/en), MIT license, `manifest.yaml`
