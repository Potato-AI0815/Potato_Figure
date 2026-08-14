#!/usr/bin/env Rscript
# audit_color_system.R — Potato Figure Audit v0.4.1 Color-System Audit
# 执行 12 条 color rules，按三层聚合，输出 COLOR_AUDIT_STATUS 等状态。
# 用法: Rscript audit_color_system.R <figure_dir> [--json]

script_dir <- dirname(normalizePath(sub("^--file=", "",
  commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][1])))
source(file.path(script_dir, "lib", "qa_common.R"))
source(file.path(script_dir, "lib", "audit_core.R"))
source(file.path(script_dir, "lib", "color_system_core.R"))

args <- commandArgs(trailingOnly = TRUE)
directory <- if (length(args) && !startsWith(args[1], "--")) args[1] else "."
as_json <- "--json" %in% args

## 收集证据
contract_path <- file.path(directory, "figure_contract.yaml")
contract <- if (file.exists(contract_path)) tryCatch(read_flat_yaml(contract_path), error = function(e) list()) else list()
state_file <- if (!is_blank(contract$global_state_file)) contract$global_state_file else "global_figure_state.yaml"
state <- if (file.exists(file.path(directory, state_file))) {
  tryCatch(read_flat_yaml(file.path(directory, state_file)), error = function(e) list())
} else list()

evidence_source <- toupper(trim_scalar(contract$visual_evidence_source))
if (!nzchar(evidence_source)) {
  ## QUICK_REVIEW fallback: 主入口注入的默认证据（有图即 RASTER_REVIEW）
  fb <- toupper(trim_scalar(Sys.getenv("POTATO_COLOR_EVIDENCE_FALLBACK", "")))
  if (nzchar(fb) && fb %in% c("RASTER_REVIEW", "VECTOR_REVIEW", "VISION_MODEL_REVIEW", "MANUAL_REVIEW")) {
    evidence_source <- fb
  } else {
    evidence_source <- "NONE"
  }
}
has_image <- isTRUE(inventory_inputs(directory, contract)$final_figure$available) ||
  (!is_blank(contract$final_figure_file) && file.exists(file.path(directory, contract$final_figure_file)))

## 颜色相关元数据（GFS color_state 或 contract）
prefer_state <- function(state_value, contract_value) {
  x <- trim_scalar(state_value); if (nzchar(x)) x else trim_scalar(contract_value)
}
semantic_palette <- prefer_state(state$color_state.semantic_palette, contract$color_state.semantic_palette)
continuous_palettes <- prefer_state(state$color_state.continuous_palettes, contract$color_state.continuous_palettes)
hero_accent <- prefer_state(state$color_state.hero_accent, contract$color_state.hero_accent)
neutral_roles <- tolower(prefer_state(state$color_state.neutral_roles, contract$color_state.neutral_roles))
panel_palette_map <- prefer_state(state$color_state.panel_palette_map, contract$color_state.panel_palette_map)
hero_panel <- tolower(prefer_state(state$narrative.hero_panel, contract$narrative.hero_panel))

## Structured qualitative review. Image-review rules may PASS/FAIL only when the
## reviewer supplied the corresponding observation; metadata declarations alone
## never substitute for looking at the rendered figure.
review <- list(
  primary_evidence_gray_dominant = trim_scalar(contract$color_review.primary_evidence_gray_dominant),
  semantic_contrast_exists = trim_scalar(contract$color_review.semantic_contrast_exists),
  accent_hierarchy = toupper(trim_scalar(contract$color_review.accent_hierarchy)),
  grayscale_redundancy = toupper(trim_scalar(contract$color_review.grayscale_redundancy)),
  text_background_contrast = toupper(trim_scalar(contract$color_review.text_background_contrast)),
  saturation_balance = toupper(trim_scalar(contract$color_review.saturation_balance)),
  hero_salience = toupper(trim_scalar(contract$color_review.hero_salience)),
  confidence = toupper(trim_scalar(contract$color_review.confidence))
)
review_validation <- validate_color_evidence(evidence_source, review)
parse_bool <- function(x) {
  v <- toupper(trim_scalar(x))
  if (v %in% c("TRUE", "YES", "1")) TRUE else if (v %in% c("FALSE", "NO", "0")) FALSE else NA
}

## findings 收集
findings <- list()
add_color <- function(rule_id, severity, status, issue, why = "", panels = "",
                      action = "", layer = NULL, measurement = "QUALITATIVE",
                      confidence = "MEDIUM", evidence = evidence_source) {
  if (is.null(layer)) layer <- color_layer(rule_id)
  findings[[length(findings) + 1]] <<- list(
    domain = "color", rule_id = rule_id, layer = layer,
    severity = severity, status = status, issue = issue, why = why,
    panels = panels, action = action, evaluation_source = evidence,
    measurement_type = measurement, confidence = confidence)
}

## ============ 执行 12 条规则 ============
## COLOR-01 SEMANTIC_COLOR_CONSISTENCY
if (nzchar(semantic_palette)) {
  add_color("COLOR-01", "INFO", "PASS",
            sprintf("Semantic palette declared: %s", semantic_palette),
            action = "Keep this mapping consistent across panels sharing the semantic contrast")
} else if (nzchar(panel_palette_map)) {
  add_color("COLOR-01", "WARNING", "WARNING",
            "Panel palette map declared but no figure-level semantic palette; same semantic may drift across panels",
            action = "Define color_state.semantic_palette at figure level")
} else {
  add_color("COLOR-01", "MINOR", "NOT_EVALUABLE",
            "No semantic palette declaration; cannot verify cross-panel color consistency",
            action = "Declare semantic_palette in global_figure_state.yaml color_state")
}

## COLOR-02 COLOR_MEANING_VALIDITY
## （需 legend/mapping 声明；metadata 层可查）
legend_declared <- nzchar(trim_scalar(contract$figure_legend)) || file.exists(file.path(directory, "figure_legend.md"))
if (legend_declared) {
  add_color("COLOR-02", "INFO", "PASS", "Legend/mapping declared; color-meaning validity evaluable at metadata level")
} else {
  add_color("COLOR-02", "WARNING", "WARNING",
            "No legend/mapping declaration; color meaning cannot be fully verified",
            action = "Provide legend or declared color-to-semantic mapping")
}

## COLOR-03 CROSS_PANEL_PALETTE_COHERENCE
if (nzchar(panel_palette_map)) {
  entries <- split_values(panel_palette_map)
  ## 提取每个 panel 声明的 palette 值（= 后部分），按实际 palette 家族去重
  pal_values <- sub("^[^=]+=", "", entries)
  n_families <- length(unique(tolower(trimws(pal_values))))
  if (n_families > 3) {
    add_color("COLOR-03", "MAJOR", "MAJOR",
              sprintf("Palette fragmentation risk: %d distinct palette families declared (%s)",
                      n_families, paste(unique(pal_values), collapse = ", ")),
              why = "Multiple unrelated palette families across panels reduce coherence",
              action = "Consolidate to one restrained palette family at figure level")
  } else {
    add_color("COLOR-03", "INFO", "PASS",
              sprintf("Panel palette map coherent (%d family/families)", n_families))
  }
} else {
  add_color("COLOR-03", "MINOR", "NOT_EVALUABLE",
            "No panel palette map; cross-panel coherence not declaratively verifiable")
}

## COLOR-04 NEUTRAL_GRAY_DOMINANCE（需要 image evidence）
if (evidence_source %in% c("VISION_MODEL_REVIEW", "MANUAL_REVIEW") && has_image && isTRUE(review_validation$valid)) {
  gray_dominant <- parse_bool(review$primary_evidence_gray_dominant)
  semantic_exists <- parse_bool(review$semantic_contrast_exists)
  if (identical(gray_dominant, FALSE)) {
    add_color("COLOR-04", "INFO", "PASS",
              "Image review reports primary evidence is not gray-dominant",
              evidence = evidence_source)
  } else if (identical(gray_dominant, TRUE) && !identical(semantic_exists, FALSE)) {
    add_color("COLOR-04", "MAJOR", "MAJOR",
              "Image review reports primary evidence is dominated by neutral gray",
              why = "If primary evidence is gray while semantic categories exist, biological contrast is lost at thumbnail scale",
              panels = hero_panel,
              action = "Map recurring contrast (D/R, up/down) to consistent semantic hues; keep gray for structure only",
              confidence = if (nzchar(trim_scalar(review$confidence))) review$confidence else "MEDIUM")
  } else {
    add_color("COLOR-04", "MINOR", "NOT_EVALUABLE",
              "Image reviewed but structured gray-dominance observation is missing")
  }
} else if (evidence_source == "RASTER_REVIEW" && has_image) {
  ## Pixel-derived finding is appended below after measurement.
} else {
  add_color("COLOR-04", "MINOR", "NOT_EVALUABLE",
            "No image evidence for gray-dominance assessment",
            action = "Provide RASTER/VISION/MANUAL review or real pixel measurement")
}

## COLOR-05 ACCENT_HIERARCHY（需要 image evidence）
if (evidence_source %in% c("VISION_MODEL_REVIEW", "MANUAL_REVIEW") && has_image && review$accent_hierarchy %in% c("GOOD", "PASS", "CLEAR")) {
  add_color("COLOR-05", "INFO", "PASS", "Image review reports a clear accent hierarchy")
} else if (evidence_source %in% c("VISION_MODEL_REVIEW", "MANUAL_REVIEW") && has_image && review$accent_hierarchy %in% c("WEAK", "FAIL", "FLAT")) {
  add_color("COLOR-05", "MAJOR", "MAJOR",
            "Image review reports weak accent hierarchy",
            why = "Weak hierarchy impairs quick reading; hero evidence may lack salience",
            action = "Give primary evidence stronger accent; de-emphasize background",
            confidence = "MEDIUM")
} else {
  add_color("COLOR-05", "MINOR", "NOT_EVALUABLE", "No structured image evidence for accent hierarchy")
}

## COLOR-06 DIVERGING_SCALE_SEMANTICS（metadata 可查）
if (nzchar(continuous_palettes)) {
  if (grepl("diverging|gradient2|blue.*white.*red|cool.*warm", tolower(continuous_palettes))) {
    add_color("COLOR-06", "INFO", "PASS",
              sprintf("Diverging palette declared: %s", continuous_palettes),
              action = "Ensure midpoint at scientific zero (e.g., log2FC=0) and direction matches legend")
  } else {
    add_color("COLOR-06", "INFO", "PASS",
              sprintf("Continuous palette declared (non-diverging): %s", continuous_palettes))
  }
} else {
  add_color("COLOR-06", "MINOR", "NOT_EVALUABLE",
            "No continuous palette declaration; diverging semantics not verifiable")
}

## COLOR-07 COLORBLIND_ROBUSTNESS（metadata 可查：palette 是否红绿-only）
if (nzchar(semantic_palette) && grepl("red|green", tolower(semantic_palette)) &&
    !grepl("blue|coral|purple|orange", tolower(semantic_palette))) {
  add_color("COLOR-07", "WARNING", "WARNING",
            "Declared semantic palette appears red/green-only; colorblind robustness risk",
            why = "Red/green-only categorical distinction is hard for deuteranopia/protanopia",
            action = "Add shape/position/label redundancy or switch hues")
} else if (nzchar(semantic_palette)) {
  add_color("COLOR-07", "INFO", "PASS", "Semantic palette not red/green-only")
} else {
  add_color("COLOR-07", "MINOR", "NOT_EVALUABLE", "No palette declaration")
}

## COLOR-08 GRAYSCALE_REDUNDANCY（image evidence）
if (evidence_source %in% c("VISION_MODEL_REVIEW", "MANUAL_REVIEW") && has_image && review$grayscale_redundancy %in% c("PASS", "GOOD")) {
  add_color("COLOR-08", "INFO", "PASS", "Image review confirms key contrast survives grayscale")
} else if (evidence_source %in% c("VISION_MODEL_REVIEW", "MANUAL_REVIEW") && has_image && review$grayscale_redundancy %in% c("FAIL", "POOR")) {
  add_color("COLOR-08", "MAJOR", "MAJOR", "Key contrast does not survive grayscale",
            action = "Ensure shape/position/label redundancy for color-only encodings",
            confidence = "MEDIUM")
} else {
  add_color("COLOR-08", "MINOR", "NOT_EVALUABLE", "No structured grayscale-redundancy evidence")
}

## COLOR-09 TEXT_BACKGROUND_CONTRAST（必须 image evidence）
if (evidence_source %in% c("VISION_MODEL_REVIEW", "MANUAL_REVIEW") && has_image && review$text_background_contrast %in% c("PASS", "GOOD")) {
  add_color("COLOR-09", "INFO", "PASS",
            "Image review reports adequate text/background contrast",
            evidence = evidence_source)
} else if (evidence_source %in% c("VISION_MODEL_REVIEW", "MANUAL_REVIEW") && has_image && review$text_background_contrast %in% c("FAIL", "POOR")) {
  add_color("COLOR-09", "MAJOR", "MAJOR", "Image review reports inadequate text/background contrast",
            action = "Adjust text color or background luminance", evidence = evidence_source)
} else {
  add_color("COLOR-09", "MINOR", "NOT_EVALUABLE",
            "Metadata-only cannot declare text/background contrast PASS",
            action = "Provide image evidence (raster/vision/manual)")
}

## COLOR-10 SATURATION_BALANCE（image evidence）
if (evidence_source %in% c("VISION_MODEL_REVIEW", "MANUAL_REVIEW") && has_image && review$saturation_balance %in% c("PASS", "BALANCED")) {
  add_color("COLOR-10", "INFO", "PASS", "Image review reports balanced saturation")
} else if (evidence_source %in% c("VISION_MODEL_REVIEW", "MANUAL_REVIEW") && has_image && review$saturation_balance %in% c("OVER", "UNDER", "FAIL")) {
  add_color("COLOR-10", "MAJOR", "MAJOR",
            sprintf("Image review reports %s saturation", tolower(review$saturation_balance)),
            action = "Introduce restrained semantic accents; avoid rainbow palettes",
            confidence = "MEDIUM")
} else {
  add_color("COLOR-10", "MINOR", "NOT_EVALUABLE", "No structured image evidence for saturation balance")
}

## COLOR-11 HERO_COLOR_PRIORITY（image evidence + hero 声明）
if (nzchar(hero_panel)) {
  if (evidence_source %in% c("VISION_MODEL_REVIEW", "MANUAL_REVIEW") && has_image && review$hero_salience %in% c("HIGH", "GOOD", "PASS")) {
    add_color("COLOR-11", "INFO", "PASS", sprintf("Hero panel '%s' has clear color priority", hero_panel))
  } else if (evidence_source %in% c("VISION_MODEL_REVIEW", "MANUAL_REVIEW") && has_image && review$hero_salience %in% c("LOW", "WEAK", "FAIL")) {
    add_color("COLOR-11", "MAJOR", "MAJOR",
              sprintf("Hero panel '%s' has weak color priority", hero_panel),
              why = "Declared hero must be visually salient; all-gray hero trajectories lose priority",
              panels = hero_panel,
              action = "Emphasize hero endpoints with semantic colors; keep connecting lines neutral; avoid random per-patient colors",
              confidence = "MEDIUM")
  } else {
    add_color("COLOR-11", "MINOR", "NOT_EVALUABLE",
              sprintf("Hero '%s' declared but no structured salience observation", hero_panel))
  }
} else {
  add_color("COLOR-11", "MINOR", "NOT_EVALUABLE", "No hero panel declared")
}

## COLOR-12 UNUSED_COLOR_NOISE（metadata 可查：面板级颜色数）
if (nzchar(panel_palette_map)) {
  n_entries <- length(split_values(panel_palette_map))
  if (n_entries > 8) {
    add_color("COLOR-12", "WARNING", "WARNING",
              sprintf("%d palette entries; risk of unused color noise (per-entity colors without semantic need)", n_entries),
              action = "Reduce to semantic categories; neutral + one accent unless identity tracking required")
  } else {
    add_color("COLOR-12", "INFO", "PASS", "Palette size bounded")
  }
} else {
  add_color("COLOR-12", "MINOR", "NOT_EVALUABLE", "No panel palette map")
}

## COLOR-14 SYMBOL_SEMANTIC_CONFLICT
## x/×/✕ 交叉标记是 censoring/exclusion 的标准语义; 用于"不显著"等标注会误导。
## 需要结构化 image/manual 证据（VISION_MODEL_REVIEW / MANUAL / IMAGE_REVIEW）。
symbol_obs <- toupper(trim_scalar(contract$color_review.symbol_semantic_conflict))
if (!nzchar(symbol_obs) || symbol_obs == "NA") {
  add_color("COLOR-14", "MINOR", "NOT_EVALUABLE",
            "No structured evidence about marker semantics; COLOR-14 (symbol-semantic conflict) not evaluable",
            action = "Provide color_review.symbol_semantic_conflict (CENSORING_ONLY / NON_SIGNIFICANT_CROSS / DECLARED_NON_CENSORING)")
} else if (symbol_obs == "CENSORING_ONLY") {
  add_color("COLOR-14", "INFO", "PASS",
            "Cross marks used only for censoring/exclusion semantics (declared)",
            confidence = "MEDIUM")
} else if (symbol_obs == "DECLARED_NON_CENSORING") {
  add_color("COLOR-14", "WARNING", "WARNING",
            "Cross marks used for non-censoring meaning but declared in legend; verify readers will not misread censoring",
            action = "Prefer open circles/dots for non-significant annotations; reserve x for censoring/exclusion",
            confidence = "MEDIUM")
} else if (symbol_obs == "NON_SIGNIFICANT_CROSS") {
  add_color("COLOR-14", "MAJOR", "MAJOR",
            "Cross marks used for non-significant results without censoring/exclusion meaning — semantic conflict (x conventionally means censored/excluded in survival/time-to-event figures)",
            why = "Readers familiar with survival analysis interpret x as censoring; marking q-values with x conflates statistics with event semantics",
            action = "Replace cross marks with open circles or dots for non-significant annotations",
            confidence = "HIGH")
} else {
  add_color("COLOR-14", "WARNING", "WARNING",
            sprintf("Unknown symbol-semantic observation: %s", symbol_obs),
            action = "Use CENSORING_ONLY / NON_SIGNIFICANT_CROSS / DECLARED_NON_CENSORING")
}

## ============ raster 可量化指标（仅真实 RASTER_REVIEW） ============
raster_metrics <- NULL
## 统计面板判定（COLOR-13 需要）：manifest 中 statistical_test 非 descriptive/none 的面板
stat_panels <- character()
manifest_path_ra <- file.path(directory, "figure_manifest.tsv")
if (file.exists(manifest_path_ra)) {
  mf_tmp <- tryCatch(read_manifest(manifest_path_ra), error = function(e) NULL)
  if (!is.null(mf_tmp) && nrow(mf_tmp) && "statistical_test" %in% names(mf_tmp)) {
    test_col <- tolower(trimws(mf_tmp$statistical_test))
    desc <- grepl("descriptive|none|^na$", test_col)
    stat_panels <- mf_tmp$panel[!desc]
  }
}
has_stat_panels <- length(stat_panels) > 0
semantic_palette_declared <- nzchar(semantic_palette)
if (evidence_source == "RASTER_REVIEW" && has_image) {
  fig_path <- file.path(directory, if (!is_blank(contract$final_figure_file)) contract$final_figure_file else "figure.png")
  if (file.exists(fig_path)) {
    manifest_path <- file.path(directory, "figure_manifest.tsv")
    panel_count <- if (file.exists(manifest_path)) nrow(tryCatch(read_manifest(manifest_path), error = function(e) data.frame())) else 1L
    raster_metrics <- raster_color_metrics(fig_path, panel_count = max(1L, panel_count),
                                           script_dir = script_dir)
    if (!is.null(raster_metrics) && !is.null(raster_metrics$neutral_fraction)) {
      nf <- raster_metrics$neutral_fraction
      if (!is.na(nf) && nf > 0.70) {
        add_color("COLOR-04", "MAJOR", "MAJOR",
                  sprintf("Measured neutral ink fraction %.2f (>0.70 heuristic) — primary evidence may be gray-dominant",
                          nf),
                  why = "Measured from raster; gray dominance impairs semantic contrast recovery",
                  action = "Introduce semantic hues for primary evidence",
                  measurement = "MEASURED", confidence = "HIGH")
      } else if (!is.na(nf)) {
        add_color("COLOR-04", "INFO", "PASS",
                  sprintf("Measured neutral ink fraction %.2f (within profile heuristic 0.70)", nf),
                  measurement = "MEASURED", confidence = "HIGH")
      }
      ## COLOR-10 饱和平衡实测
      if (!is.null(raster_metrics$mean_saturation)) {
        add_color("COLOR-10", "INFO", "INFO",
                  sprintf("Measured mean saturation %.2f", raster_metrics$mean_saturation),
                  measurement = "MEASURED", confidence = "HIGH")
      }
      add_color("COLOR-03", "INFO", "INFO",
                sprintf("Measured palette clusters=%s; panel palette similarity=%s",
                        raster_metrics$palette_cluster_count,
                        if (is.null(raster_metrics$panel_palette_similarity)) "NA" else sprintf("%.2f", raster_metrics$panel_palette_similarity)),
                measurement = "MEASURED", confidence = "HIGH")
      add_color("COLOR-05", "INFO", "INFO",
                sprintf("Measured accent area fraction %.2f", raster_metrics$accent_area_fraction),
                measurement = "MEASURED", confidence = "HIGH")

      ## ---- 面板级局部灰化检测（v0.4.1+：全图平均会掩盖局部灰）----
      ## 从 GFS/contract 读面板布局（grid "2x2" 或 bbox），对每个面板独立测
      panel_grid <- trim_scalar(state$color_state.panel_grid)
      panel_bboxes_raw <- trim_scalar(state$color_state.panel_bboxes)
      panel_bboxes <- if (nzchar(panel_bboxes_raw) && panel_bboxes_raw != "NA") {
        strsplit(panel_bboxes_raw, ";")[[1]]
      } else NULL
      if (has_image) {
        fig_path2 <- fig_path
        pm <- tryCatch(raster_panel_metrics(fig_path2,
                       panel_bboxes = panel_bboxes,
                       grid_layout = if (nzchar(panel_grid)) panel_grid else NULL,
                       script_dir = script_dir),
                       error = function(e) NULL)
        if (!is.null(pm) && !is.null(pm$panels)) {
          pdat <- pm$panels
          if (is.data.frame(pdat)) {
            ## COLOR-13: 语义面板灰色残留（先收集面板 neutral, 循环后聚合判定）
            panel_nf <- list()
            for (i in seq_len(nrow(pdat))) {
              nf_p <- pdat$neutral_fraction[i]
              nink <- pdat$n_ink[i]
              panel_nf[[i]] <- list(nf = nf_p, nink = nink,
                                    id = if ("row" %in% names(pdat)) sprintf("r%s c%s", pdat$row[i], pdat$col[i]) else as.character(i))
              if (!is.na(nf_p) && !is.null(nf_p) && nf_p > 0.80 && !is.na(nink) && nink > 500) {
                add_color("COLOR-04", "MAJOR", "MAJOR",
                          sprintf("Panel-level gray dominance: panel(r=%s,c=%s) neutral=%.2f (n_ink=%d) despite full-figure average within heuristic",
                                  pdat$row[i], pdat$col[i], nf_p, nink),
                          why = "Full-figure average can mask a locally gray-dominant panel; primary evidence in this panel lacks semantic color",
                          action = "Introduce semantic hues for this panel's primary evidence (or confirm gray is structural only)",
                          measurement = "MEASURED", confidence = "HIGH")
              } else if (!is.na(nf_p) && !is.null(nf_p)) {
                add_color("COLOR-04", "INFO", "INFO",
                          sprintf("Panel(r=%s,c=%s) neutral=%.2f", pdat$row[i], pdat$col[i], nf_p),
                          measurement = "MEASURED", confidence = "HIGH")
              }
            }
            ## COLOR-13 GRAY_RESIDUE_IN_SEMANTIC_PANEL
            ## 证据设计：raster 只能给"面板 neutral 偏高"的提示（黑轴/文字也是 neutral，
            ## 无法区分结构黑与数据灰），定性判定必须来自 vision/manual 观察
            ## gray_data_encoding（TRUE=数据编码含灰色 / FALSE=无）。
            gray_obs <- toupper(trim_scalar(contract$color_review.gray_data_encoding))
            if (semantic_palette_declared) {
              ## raster 提示层
              high_neutral <- vapply(panel_nf, function(x) {
                !is.na(x$nf) && !is.null(x$nf) && x$nf > 0.55 &&
                  !is.na(x$nink) && !is.null(x$nink) && x$nink > 500
              }, logical(1))
              ids_hi <- if (any(high_neutral)) {
                ids_v <- vapply(panel_nf[high_neutral], function(x) {
                  if (length(x$id) && nzchar(x$id)) x$id else "unknown"
                }, character(1))
                paste(ids_v, collapse = ", ")
              } else "none"
              ## 定性判定层（vision/manual 观察优先）
              if (!nzchar(gray_obs) || gray_obs == "NA") {
                add_color("COLOR-13", "WARNING", "WARNING",
                          sprintf("Raster shows panel(s) with elevated neutral ink (%s; max neutral %.2f) — cannot distinguish structural black from gray data encoding without vision/manual observation",
                                  ids_hi,
                                  if (any(high_neutral)) max(vapply(panel_nf[high_neutral], function(x) x$nf, numeric(1))) else NA_real_),
                          why = "Raster neutral fraction conflates axis/ticks/text with data-encoding gray; a declared semantic palette demands a human/vision check on data-encoding colors",
                          action = "Provide color_review.gray_data_encoding: FALSE (data encoding fully semantic) or TRUE (gray data encoding present)",
                          measurement = "MIXED", confidence = "MEDIUM")
              } else if (gray_obs == "TRUE") {
                add_color("COLOR-13", "MAJOR", "MAJOR",
                          "Vision/manual review confirms gray data encoding in statistical panels despite declared semantic palette",
                          why = "Data-encoding elements (points/bars/CI) fall back to gray while a semantic palette exists — readers lose the semantic signal for those elements",
                          action = "Map non-significant / secondary data encodings to low-saturation tints of the same semantic hue, not gray",
                          measurement = "QUALITATIVE", confidence = "HIGH")
              } else if (gray_obs == "FALSE") {
                add_color("COLOR-13", "INFO", "PASS",
                          sprintf("Vision/manual review confirms no gray data encoding (raster neutral panels: %s)",
                                  if (any(high_neutral)) ids_hi else "none above 0.55"),
                          measurement = "MIXED", confidence = "HIGH")
              } else {
                add_color("COLOR-13", "WARNING", "WARNING",
                          sprintf("Unknown gray_data_encoding observation: %s", gray_obs),
                          action = "Use TRUE or FALSE")
              }
            } else {
              add_color("COLOR-13", "MINOR", "NOT_EVALUABLE",
                        "No semantic palette declared; COLOR-13 (gray residue) not evaluable",
                        action = "Declare color_state.semantic_palette to enable gray-residue detection")
            }
          }
        }
      }
    }
  }
}

## ============ 聚合状态 ============
agg <- aggregate_color_status(findings)
## R6.1: severity-preserving 聚合。
## COLOR_AUDIT_STATUS: FAIL(universal FAIL/MAJOR) > REVISE(publication MAJOR) >
##   PASS_WITH_WARNINGS(universal/publication WARNING) > PASS_WITH_LIMITED_EVIDENCE(universal NE) > PASS
color_audit_status <- if (agg$universal %in% c("FAIL", "MAJOR")) "FAIL" else
  if (agg$publication == "MAJOR") "REVISE" else
  if (agg$universal == "WARNING" || agg$publication == "WARNING") "PASS_WITH_WARNINGS" else
  if (agg$universal == "NOT_EVALUABLE") "PASS_WITH_LIMITED_EVIDENCE" else "PASS"
## COLOR_SYSTEM_READY: 仅被阻断性问题（FAIL/MAJOR/REVISE）阻止。
## 非阻断性 NOT_EVALUABLE（证据缺失型规则, 如 COLOR-14 无 vision 观察）不阻止 ready。
## （blocking violations 已体现在 COLOR_AUDIT_STATUS=FAIL/REVISE, 由 readiness 层拦截）
color_system_ready <- !agg$universal %in% c("FAIL", "MAJOR") && agg$publication != "MAJOR"
profile_color_ready <- agg$profile %in% c("PASS", "NOT_EVALUABLE")

## ============ 输出 ============
if (as_json) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("jsonlite is required for --json")
  payload <- list(COLOR_AUDIT_STATUS = color_audit_status,
                  COLOR_SYSTEM_READY = color_system_ready,
                  PROFILE_COLOR_READY = profile_color_ready,
                  UNIVERSAL = agg$universal, PUBLICATION = agg$publication,
                  PROFILE = agg$profile, raster_metrics = raster_metrics,
                  findings = findings)
  cat(jsonlite::toJSON(payload, auto_unbox = TRUE, null = "null"), "\n")
} else {
  cat("=== Color System Audit ===\n")
  for (f in findings) {
    cat(sprintf("[%s/%s/%s] %s — %s\n", f$layer, f$severity, f$status, f$rule_id, f$issue))
  }
  cat(sprintf("\nCOLOR_AUDIT_STATUS = %s\n", color_audit_status))
  cat(sprintf("COLOR_SYSTEM_READY = %s\n", if (color_system_ready) "TRUE" else "FALSE"))
  cat(sprintf("PROFILE_COLOR_READY = %s\n", if (profile_color_ready) "TRUE" else "FALSE"))
}
quit(status = if (color_system_ready) 0 else 1)
