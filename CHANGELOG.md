# CHANGELOG

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
