# color_system_core.R — Potato Figure Audit v0.4.1 Color-System Audit
# 三层色彩规则体系 + 12 条正式规则。
#
# LAYER A — UNIVERSAL_COLOR_INTEGRITY（科学/可访问性, 可影响 PUBLICATION_READY）
# LAYER B — PUBLICATION_COLOR_COHERENCE（出版视觉质量, WARNING/MAJOR）
# LAYER C — PROFILE_COLOR_PREFERENCES（potato-user-v1 个人偏好, 不冒充 universal law）
#
# 证据纪律：
#   METADATA_ONLY  只能审 declared palette/semantic mapping/legend metadata,
#                  不得声明 image color PASS（COLOR-04/05/09/10/11 → NOT_EVALUABLE）
#   VISION_MODEL   允许定性判断（gray dominance 等）, 禁止编造精确像素百分比
#   RASTER_REVIEW  允许真实像素测量（须记录 measurement_method/thresholds/resolution）

## ---- 12 条规则定义 ----
COLOR_RULES <- list(
  list(rule_id = "COLOR-01", name = "SEMANTIC_COLOR_CONSISTENCY",
       layer = "A",
       description = "Same biological/experimental semantic contrast should keep a stable color mapping across panels",
       applies_when = "recurring semantic contrast (e.g., D vs R) appears in >1 panel",
       pass = "same semantic uses same mapping across panels (exceptions: continuous heatmap/density/signed scale)",
       warning = "same semantic mapped to different colors across panels without scientific reason",
       major = "semantic colors swapped between treatment/control across panels creating misleading reading",
       not_evaluable = "no manifest/legend metadata describing semantic mapping",
       evidence = c("METADATA", "MANUAL"),
       repair = "Define one semantic palette at figure level (see color_state.semantic_palette) and reuse across panels"),
  list(rule_id = "COLOR-02", name = "COLOR_MEANING_VALIDITY",
       layer = "A",
       description = "Color must not imply meaning that does not exist",
       applies_when = "categorical or continuous color used for statistical/biological contrast",
       pass = "declared mapping matches legend and scientific semantics",
       warning = "color used for groups but legend/annotation missing",
       major = "color implies false scientific meaning (e.g., significant-only red without declaration; treatment/control swapped)",
       not_evaluable = "no legend or declared mapping available",
       evidence = c("METADATA", "IMAGE_REVIEW", "MANUAL"),
       repair = "Align color mapping with declared semantics; add legend; do not encode meaning not present in data"),
  list(rule_id = "COLOR-03", name = "CROSS_PANEL_PALETTE_COHERENCE",
       layer = "B",
       description = "Whole figure should not fragment into unrelated palettes per panel",
       applies_when = "multi-panel figure",
       pass = "one coherent palette family (neutral + signal + accent) across panels",
       warning = "palette fragmentation without scientific reason",
       major = "severe fragmentation: every panel uses a different unrelated palette",
       not_evaluable = "not enough metadata to compare panels",
       evidence = c("METADATA", "IMAGE_REVIEW"),
       repair = "Choose one restrained palette family at figure level; keep same semantic hues"),
  list(rule_id = "COLOR-04", name = "NEUTRAL_GRAY_DOMINANCE",
       layer = "B",
       description = "Gray is acceptable as background/reference/connective; not as primary evidence when semantic categories exist",
       applies_when = "primary biological evidence present with identifiable semantic contrast",
       pass = "primary evidence uses semantic colors; gray limited to background/reference/connective",
       warning = "some primary evidence gray but semantic categories exist",
       major = "primary evidence visually dominated by neutral gray despite recurring biological contrast encodable with semantic color",
       not_evaluable = "metadata-only or no image evidence",
       evidence = c("IMAGE_REVIEW", "RASTER_REVIEW", "VISION_MODEL_REVIEW"),
       repair = "Map recurring contrast (D/R, up/down) to consistent semantic hues; keep gray for structure only"),
  list(rule_id = "COLOR-05", name = "ACCENT_HIERARCHY",
       layer = "B",
       description = "Figure should have a clear visual hierarchy (primary/secondary/background)",
       applies_when = "multi-panel or multi-element figure",
       pass = "clear primary/secondary/background distinction",
       warning = "weak hierarchy: all elements similar visual weight",
       major = "no identifiable hierarchy; hero evidence has no visual priority",
       not_evaluable = "metadata-only",
       evidence = c("IMAGE_REVIEW", "RASTER_REVIEW", "VISION_MODEL_REVIEW"),
       repair = "Give hero panel stronger accent; de-emphasize background/secondary with neutral tones"),
  list(rule_id = "COLOR-06", name = "DIVERGING_SCALE_SEMANTICS",
       layer = "A",
       description = "Diverging palettes must have a scientifically meaningful midpoint",
       applies_when = "log2FC / effect size / signed z-score / difference map",
       pass = "midpoint at scientific zero; negative-cool, positive-warm; legend consistent",
       warning = "midpoint near but not exactly zero without justification",
       major = "midpoint not at scientific zero; direction opposite to legend; diverging used without zero meaning",
       not_evaluable = "no scale declaration",
       evidence = c("METADATA", "IMAGE_REVIEW"),
       repair = "Set midpoint to scientific zero; align direction with legend; use sequential palette if no meaningful zero"),
  list(rule_id = "COLOR-07", name = "COLORBLIND_ROBUSTNESS",
       layer = "A",
       description = "Critical categorical distinctions should not rely on red/green alone",
       applies_when = "categorical contrast critical to the claim",
       pass = "color + position/shape/label redundancy for key contrast",
       warning = "red/green-only categorical distinction without redundancy",
       major = "red/green-only distinction for the central claim with no redundancy",
       not_evaluable = "cannot determine criticality",
       evidence = c("METADATA", "IMAGE_REVIEW", "MANUAL"),
       repair = "Add shape/position/label redundancy or switch to colorblind-safe hues"),
  list(rule_id = "COLOR-08", name = "GRAYSCALE_REDUNDANCY",
       layer = "A",
       description = "Main evidence should remain interpretable in grayscale",
       applies_when = "color used as primary encoding",
       pass = "shape/position/line-type/annotation provide redundancy",
       warning = "color-only encoding for primary evidence",
       major = "grayscale destroys essential distinction with no redundancy",
       not_evaluable = "cannot evaluate without image",
       evidence = c("IMAGE_REVIEW", "RASTER_REVIEW", "MANUAL"),
       repair = "Add shape/position/label redundancy"),
  list(rule_id = "COLOR-09", name = "TEXT_BACKGROUND_CONTRAST",
       layer = "A",
       description = "Text/labels must remain readable over fills",
       applies_when = "text on fill / label over heatmap / legend text",
       pass = "sufficient contrast observed",
       warning = "borderline contrast",
       major = "unreadable text over background",
       not_evaluable = "metadata-only (no image evidence)",
       evidence = c("IMAGE_REVIEW", "RASTER_REVIEW", "VISION_MODEL_REVIEW"),
       repair = "Adjust text color or background luminance"),
  list(rule_id = "COLOR-10", name = "SATURATION_BALANCE",
       layer = "B",
       description = "Avoid whole-figure over-desaturation, rainbow garishness, or flat accents",
       applies_when = "multi-panel figure",
       pass = "balanced saturation with clear accents",
       warning = "whole figure over-desaturated or over-saturated",
       major = "severe imbalance impairing readability",
       not_evaluable = "metadata-only",
       evidence = c("IMAGE_REVIEW", "RASTER_REVIEW", "VISION_MODEL_REVIEW"),
       repair = "Introduce restrained semantic accents; avoid rainbow palettes"),
  list(rule_id = "COLOR-11", name = "HERO_COLOR_PRIORITY",
       layer = "B",
       description = "Declared hero panel should receive visual priority",
       applies_when = "hero_panel declared in mission/GFS",
       pass = "hero visually salient (accent, area, emphasis)",
       warning = "hero present but weak salience",
       major = "hero panel visually equal to or weaker than secondary panels (e.g., all-gray trajectories)",
       not_evaluable = "no hero declared or metadata-only",
       evidence = c("IMAGE_REVIEW", "RASTER_REVIEW", "VISION_MODEL_REVIEW"),
       repair = "Emphasize hero endpoints with semantic colors; keep connecting lines neutral; avoid random per-patient colors"),
   list(rule_id = "COLOR-12", name = "UNUSED_COLOR_NOISE",
        layer = "B",
        description = "Color count should not exceed semantic need",
        applies_when = "categorical coloring",
        pass = "colors match semantic categories",
        warning = "unnecessary per-entity colors (e.g., 6 patients -> 6 random colors when patient identity is not the emphasis)",
        major = "rainbow patchwork without semantic role",
        not_evaluable = "cannot assess semantic need",
        evidence = c("METADATA", "IMAGE_REVIEW"),
        repair = "Reduce to semantic categories; use neutral + one accent unless identity tracking is required"),
  list(rule_id = "COLOR-13", name = "GRAY_RESIDUE_IN_SEMANTIC_PANEL",
       layer = "B",
       description = "When a semantic palette is declared, primary data encoding must not fall back to gray within statistical panels",
       applies_when = "semantic palette declared AND panel-level raster evidence available",
       pass = "statistical panels keep neutral fraction within semantic-color budget (<= 0.55 measured)",
       warning = "statistical panel neutral fraction 0.55-0.80: data encoding may partially fall back to gray (e.g., non-significant groups drawn gray)",
       major = "statistical panel neutral fraction > 0.80 despite semantic palette (same as COLOR-04 panel rule, kept for attribution)",
       not_evaluable = "no semantic palette declaration or no raster evidence",
       evidence = c("RASTER_REVIEW", "VISION_MODEL_REVIEW", "MANUAL"),
       repair = "Map every data-encoding element in statistical panels to the declared semantic palette, including non-significant groups (use a low-saturation tint of the same hue, never gray)"),
  list(rule_id = "COLOR-14", name = "SYMBOL_SEMANTIC_CONFLICT",
       layer = "A",
       description = "Cross marks (x, X, multiplication sign) are reserved for censoring/exclusion semantics; using them to mark non-significant results creates a semantic conflict",
       applies_when = "cross marks used as data markers or annotations",
       pass = "cross marks used only for censoring/exclusion and declared in legend",
       warning = "cross marks used for a non-censoring meaning but declared in legend",
       major = "cross marks used for non-significant/absent meaning without legend declaration (e.g., x marks on q-values that are not censoring)",
       not_evaluable = "no structured image/manual evidence about marker semantics",
       evidence = c("IMAGE_REVIEW", "VISION_MODEL_REVIEW", "MANUAL"),
       repair = "Replace cross marks with open circles or dots for non-significant annotations; reserve x only for censoring/exclusion")
)

## ---- layer 查询 ----
color_layer <- function(rule_id) {
  for (r in COLOR_RULES) if (r$rule_id == rule_id) return(r$layer)
  NA_character_
}

## ---- 规则查询 ----
color_rule <- function(rule_id) {
  for (r in COLOR_RULES) if (r$rule_id == rule_id) return(r)
  NULL
}

## ---- 证据纪律 ----
# METADATA_ONLY: COLOR-04/05/09/10/11 → NOT_EVALUABLE（不得声明 image color PASS）
metadata_only_not_evaluable <- function(rule_id) {
  rule_id %in% c("COLOR-04", "COLOR-05", "COLOR-09", "COLOR-10", "COLOR-11")
}

## ---- raster 可量化指标（仅 RASTER_REVIEW）----
# v0.4.3-alpha 安全契约（P0 修复）: 数据永远作为参数，绝不作为源码的一部分。
# 图像路径只通过 argv 传给静态脚本 scripts/raster_measure.py，
# 不再 sprintf 进临时生成的 Python 源码（杜绝语法断裂与代码注入）。
raster_python_binary <- function() {
  py <- trim_scalar(Sys.getenv("POTATO_PYTHON", ""))
  if (nzchar(py)) return(py)
  py <- Sys.which("python")
  if (nzchar(py)) return(py)
  py <- Sys.which("python3")
  if (nzchar(py)) return(py)
  ""
}

raster_measure_script <- function(script_dir = NULL) {
  env <- trim_scalar(Sys.getenv("POTATO_RASTER_SCRIPT", ""))
  if (nzchar(env) && file.exists(env)) return(env)
  candidates <- character()
  if (!is.null(script_dir) && nzchar(script_dir)) {
    candidates <- c(candidates, file.path(script_dir, "raster_measure.py"))
  }
  candidates <- c(candidates,
                  file.path(getwd(), "scripts", "raster_measure.py"),
                  file.path(getwd(), "raster_measure.py"))
  for (p in candidates) if (file.exists(p)) return(normalizePath(p, mustWork = FALSE))
  NULL
}

## v0.4.3-alpha 跨平台健壮性：R 的 system2() 在非 UTF-8 的 Windows locale 下
## 传非 ASCII 命令行参数会失真，导致 Python 打不开含中文/重音的文件名。
## raster 测量只依赖像素内容（与路径无关），故将非 ASCII 路径复制到
## ASCII 安全的临时文件再测；ASCII 路径原样通过。调用方负责 unlink(tmp)。
raster_prepare_image_path <- function(image_path) {
  if (!grepl("[^ -~]", image_path)) return(list(path = image_path, tmp = NULL))
  ext <- tolower(tools::file_ext(image_path))
  if (!nzchar(ext)) ext <- "png"
  tmp <- tempfile(fileext = paste0(".", ext))
  ok <- tryCatch(file.copy(image_path, tmp, overwrite = TRUE), error = function(e) FALSE)
  if (isTRUE(ok) && file.exists(tmp)) return(list(path = tmp, tmp = tmp))
  ## 复制失败 → 仍返回原路径（fail-closed 由下游处理），不留临时文件
  list(path = image_path, tmp = NULL)
}

# 输入: 图像路径 + ink 阈值（与白背景距离）
# 输出: neutral_ink_fraction / chromatic_ink_fraction / accent_area_fraction /
#       mean_saturation / panel_mean_saturation（按面板分块）
# 注意: 必须排除白背景（INK PIXELS = 与白背景距离 > threshold）
raster_color_metrics <- function(image_path, ink_threshold = 20, panel_count = 1L,
                                 script_dir = NULL) {
  ## 无 Python/PIL 依赖或脚本缺失时返回 NULL（调用方应处理 NOT_EVALUABLE）
  py <- raster_python_binary()
  if (!nzchar(py)) return(NULL)
  script <- raster_measure_script(script_dir)
  if (is.null(script)) return(NULL)
  prep <- raster_prepare_image_path(image_path)
  args <- c(shQuote(script), "metrics", shQuote(prep$path),
            "--ink-threshold", format(ink_threshold, scientific = FALSE),
            "--panel-count", as.character(as.integer(panel_count)))
  res <- tryCatch(system2(py, args, stdout = TRUE, stderr = FALSE), error = function(e) NULL)
  if (!is.null(prep$tmp)) unlink(prep$tmp)
  if (is.null(res) || !length(res)) return(NULL)
  tryCatch(jsonlite::fromJSON(paste(res, collapse = "")), error = function(e) NULL)
}

## ---- 面板级色彩测量（v0.4.1+，解决"平均掩盖局部灰"）----
# 支持三种分区（按优先级）:
#   1) panel_bboxes: 显式相对坐标 [x0,y0,x1,y1]（来自 GFS color_state.panel_bboxes 或 contract）
#   2) grid_layout:  "2x2" / "2x1" / "1x3" 行列数（来自 GFS color_state.panel_grid）
#   3) auto:         2 行均分（常见 hero-top 设计）
# 返回每面板 mean_saturation / neutral_fraction / chromatic_fraction，
# 调用方据此检测"局部面板灰化"（全图平均无法发现）。
raster_panel_metrics <- function(image_path, ink_threshold = 20,
                                 panel_bboxes = NULL, grid_layout = NULL,
                                 script_dir = NULL) {
  py <- raster_python_binary()
  if (!nzchar(trimws(py))) return(NULL)
  script <- raster_measure_script(script_dir)
  if (is.null(script)) return(NULL)
  ## v0.4.3-alpha: 路径与分区参数全部作为 argv 传递，绝不内嵌源码
  prep <- raster_prepare_image_path(image_path)
  bbox_arg <- if (is.null(panel_bboxes)) "" else paste(panel_bboxes, collapse = ";")
  layout_arg <- if (is.null(grid_layout)) "auto" else grid_layout
  args <- c(shQuote(script), "panels", shQuote(prep$path),
            "--ink-threshold", format(ink_threshold, scientific = FALSE),
            "--bboxes", shQuote(bbox_arg),
            "--layout", shQuote(layout_arg))
  res <- tryCatch(system2(py, args, stdout = TRUE, stderr = FALSE), error = function(e) NULL)
  if (!is.null(prep$tmp)) unlink(prep$tmp)
  if (is.null(res) || !length(res)) return(NULL)
  tryCatch(jsonlite::fromJSON(paste(res, collapse = "")), error = function(e) NULL)
}

## ---- 视觉模型证据校验 ----
# Vision/manual evidence may contain qualitative judgments, but numerical pixel
# fractions are accepted only from RASTER_REVIEW. This prevents invented metrics.
validate_color_evidence <- function(evidence_source, observation) {
  src <- toupper(trim_scalar(evidence_source))
  if (is.null(observation)) observation <- list()
  numeric_claims <- c("neutral_ink_fraction", "chromatic_ink_fraction",
                      "accent_area_fraction", "mean_saturation",
                      "panel_mean_saturation", "palette_cluster_count",
                      "panel_palette_similarity")
  present_numeric <- intersect(names(observation), numeric_claims)
  if (src != "RASTER_REVIEW" && length(present_numeric)) {
    return(list(valid = FALSE,
                reason = sprintf("%s cannot supply measured fields: %s",
                                 src, paste(present_numeric, collapse = ","))))
  }
  allowed_qualitative <- c("primary_evidence_gray_dominant", "semantic_contrast_exists",
                           "accent_hierarchy", "text_background_contrast",
                           "grayscale_redundancy", "saturation_balance", "hero_salience",
                           "symbol_semantic_conflict", "gray_data_encoding", "confidence")
  unknown <- setdiff(names(observation), c(allowed_qualitative, numeric_claims))
  list(valid = !length(unknown),
       reason = if (length(unknown)) sprintf("Unknown color-review fields: %s", paste(unknown, collapse = ",")) else "")
}

## ---- 状态判定 ----
# 从 findings 聚合 COLOR_AUDIT_STATUS / COLOR_SYSTEM_READY / PROFILE_COLOR_READY
aggregate_color_status <- function(findings) {
  layer_a <- findings[vapply(findings, function(f) f$domain == "color" && f$layer == "A", logical(1))]
  layer_b <- findings[vapply(findings, function(f) f$domain == "color" && f$layer == "B", logical(1))]
  layer_c <- findings[vapply(findings, function(f) f$domain == "color" && f$layer == "C", logical(1))]
  status_of <- function(fl) {
    if (!length(fl)) return("PASS")
    st <- unique(vapply(fl, function(f) f$status, character(1)))
    if (any(st == "FAIL")) "FAIL" else if (any(st == "MAJOR")) "MAJOR" else if (any(st == "WARNING")) "WARNING" else if (any(st == "NOT_EVALUABLE")) "NOT_EVALUABLE" else "PASS"
  }
  list(
    universal = status_of(layer_a),
    publication = status_of(layer_b),
    profile = status_of(layer_c)
  )
}
