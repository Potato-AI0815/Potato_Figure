# audit_core.R — Potato Figure Audit core (v0.4.1-alpha R2)
# 独立科研 Figure 审核与完整性检查层（generator-agnostic）。
# 本文件提供：input inventory、severity 系统、audit finding 结构、报告渲染。

## ---- severity 系统 ----
SEVERITY_ORDER <- c("BLOCKER", "MAJOR", "MINOR", "INFO")
severity_rank <- function(s) match(toupper(trimws(s)), SEVERITY_ORDER)

## ---- R6: Audit Modes ----
# QUICK_REVIEW            只有图（PNG/PDF/SVG/TIFF 之一或几种）→ 只看图本身能判断的域
# SCIENTIFIC_FIGURE_AUDIT 图 + manifest + 统计元数据 → Figure 完整性（默认）
# PUBLICATION_READY       全部材料 → 最严格投稿门（fail-closed）
AUDIT_MODES <- c("QUICK_REVIEW", "SCIENTIFIC_FIGURE_AUDIT", "PUBLICATION_READY")
AUDIT_MODE_DEFAULT <- "SCIENTIFIC_FIGURE_AUDIT"

## ---- v0.4.3-alpha versioning (single source of truth for JSON output) ----
SKILL_VERSION <- "0.4.3-alpha"
## Output contract generation consumed by orchestrators (workflow >= v0.2.0-alpha)
AUDIT_CONTRACT_VERSION <- "R6.1"

# 每个 mode 评估的 domain 集合
AUDIT_MODE_DOMAINS <- list(
  QUICK_REVIEW = c("VISUAL", "COLOR", "PANEL_ARCHITECTURE"),
  SCIENTIFIC_FIGURE_AUDIT = c("SCIENTIFIC", "STATISTICAL", "CLAIM_EVIDENCE",
                               "PANEL_ARCHITECTURE", "VISUAL", "COLOR"),
  PUBLICATION_READY = c("SCIENTIFIC", "STATISTICAL", "CLAIM_EVIDENCE",
                         "PANEL_ARCHITECTURE", "GLOBAL_COHERENCE", "VISUAL",
                         "COLOR", "DELIVERY")
)

# v0.4.2-alpha (fail-closed hardening):
# publication-critical domains. A NOT_EVALUABLE critical domain must NEVER
# coexist with PUBLICATION_READY = TRUE, in any mode.
PUBLICATION_CRITICAL_DOMAINS <- c("SCIENTIFIC", "STATISTICAL", "CLAIM_EVIDENCE",
                                 "PANEL_ARCHITECTURE", "VISUAL", "COLOR",
                                 "GLOBAL_COHERENCE", "DELIVERY")

## ---- v0.4.2-alpha: named domain-status normalization ----
## NOTE: as.character() strips names from a named vector. Without preserving
## them, name-based lookups silently fail and every domain degrades to
## NOT_EVALUABLE, so readiness could never be TRUE and repair routing was
## blind. This helper is the ONLY sanctioned way to normalize domain_status.
normalize_domain_status <- function(domain_status) {
  if (is.null(domain_status)) return(character())
  ds <- toupper(as.character(domain_status))
  if (!is.null(names(domain_status))) names(ds) <- toupper(names(domain_status))
  ds
}

## ---- v0.4.2-alpha: fail-closed readiness computation ----
# PUBLICATION_READY = TRUE requires ALL of:
#   1) FIGURE_INTEGRITY in {PASS, PASS_WITH_WARNINGS}
#      (non-blocking warnings do not defeat readiness; REVISE/FAIL do)
#   2) PUBLICATION_PACKAGE == PASS (INCOMPLETE/FAIL defeat readiness)
#   3) No publication-critical domain is NOT_EVALUABLE (fail-closed),
#      and no domain is FAIL/REVISE.
# This is the single readiness function used by the main entry, the report,
# and the JSON output, so all three can never disagree again.
compute_publication_ready <- function(figure_integrity, package_status,
                                      domain_status = NULL,
                                      audit_mode = AUDIT_MODE_DEFAULT) {
  if (!figure_integrity %in% c("PASS", "PASS_WITH_WARNINGS")) return(FALSE)
  if (!identical(package_status, "PASS")) return(FALSE)
  ds <- normalize_domain_status(domain_status)
  ## any explicit FAIL/REVISE anywhere defeats readiness
  if (any(ds %in% c("FAIL", "REVISE"))) return(FALSE)
  ## fail-closed: critical domains must actually be evaluated
  for (d in PUBLICATION_CRITICAL_DOMAINS) {
    st <- if (d %in% names(ds)) ds[[d]] else "NOT_EVALUABLE"
    if (st %in% c("NOT_EVALUABLE", "NOT_APPLICABLE")) {
      ## GLOBAL_COHERENCE may be not-applicable outside PUBLICATION_READY
      if (d == "GLOBAL_COHERENCE" && audit_mode != "PUBLICATION_READY") next
      if (st == "NOT_APPLICABLE" && d == "GLOBAL_COHERENCE") next
      return(FALSE)
    }
  }
  TRUE
}

# FIGURE_INTEGRITY 只包含"这张图本身对不对"的域
FIGURE_INTEGRITY_DOMAINS <- c("SCIENTIFIC", "STATISTICAL", "CLAIM_EVIDENCE",
                              "PANEL_ARCHITECTURE", "VISUAL", "COLOR")
# PUBLICATION_PACKAGE 只包含"交付材料齐不齐"的域
PUBLICATION_PACKAGE_DOMAINS <- c("GLOBAL_COHERENCE", "DELIVERY", "SOURCE_DATA",
                                 "EXPORT_FORMATS", "DELIVERY_METADATA",
                                 "SESSION_METADATA", "PROVENANCE", "REPRODUCIBILITY")

# QUICK_REVIEW 下缺失统计材料 → 对应域 NOT_EVALUABLE（禁止当成 FAIL）
quick_review_not_evaluable <- function(domain) {
  domain %in% c("SCIENTIFIC", "STATISTICAL", "CLAIM_EVIDENCE", "GLOBAL_COHERENCE", "DELIVERY")
}

# 推断 audit mode：
#   1) 显式指定（--mode）优先
#   2) 只有图（无 manifest/contract/统计元数据）→ QUICK_REVIEW
#   3) 有图 + manifest + 统计元数据 → SCIENTIFIC_FIGURE_AUDIT
#   4) 显式要求"投稿/交付就绪"（PUBLICATION_READY）→ 最严格
infer_audit_mode <- function(directory, contract, explicit = "") {
  mode <- toupper(trimws(explicit))
  if (mode %in% AUDIT_MODES) return(mode)
  if (!nzchar(mode) && toupper(trim_scalar(contract$audit_mode)) %in% AUDIT_MODES) {
    return(toupper(trim_scalar(contract$audit_mode)))
  }
  has_manifest <- file.exists(file.path(directory, "figure_manifest.tsv"))
  has_stats <- file.exists(file.path(directory, "statistical_metadata.tsv")) ||
    (!is_blank(contract$statistical_metadata_file) &&
       file.exists(file.path(directory, contract$statistical_metadata_file)))
  has_figure <- any(file.exists(file.path(directory, c("figure.png", "figure.pdf", "figure.svg", "figure.tiff")))) ||
    (!is_blank(contract$final_figure_file) && file.exists(file.path(directory, contract$final_figure_file)))
  if (!has_figure && !has_manifest) return("QUICK_REVIEW")
  if (has_figure && !has_manifest) return("QUICK_REVIEW")
  if (has_manifest) return("SCIENTIFIC_FIGURE_AUDIT")
  "SCIENTIFIC_FIGURE_AUDIT"
}

## ---- visual evidence source（A5: 区分"看图"与"读 metadata"）----
# 允许值:
#   RASTER_REVIEW   实际打开 raster 检查
#   VECTOR_REVIEW   实际检查 vector
#   VISION_MODEL_REVIEW  用视觉模型看过图
#   MANUAL_REVIEW   人工看过图
#   METADATA_ONLY   只读了 visual_qa.tsv / contract 声明
#   NONE            没有任何视觉证据
VISUAL_EVIDENCE_SOURCES <- c("RASTER_REVIEW", "VECTOR_REVIEW", "VISION_MODEL_REVIEW",
                             "MANUAL_REVIEW", "METADATA_ONLY", "NONE")

# 判定：只有 metadata/contract 声明 → IMAGE_REVIEW 必须 NOT_EVALUABLE，不得 PASS
image_review_status <- function(evidence_source) {
  src <- toupper(trimws(evidence_source))
  if (src %in% c("RASTER_REVIEW", "VECTOR_REVIEW", "VISION_MODEL_REVIEW", "MANUAL_REVIEW")) {
    "PASS"
  } else if (src == "METADATA_ONLY") {
    "NOT_EVALUABLE"
  } else {
    "NOT_EVALUABLE"
  }
}

## ---- finding 结构 ----
# 每条发现:
#   domain      (scientific/statistical/claim_evidence/panel_architecture/
#                global_coherence/visual/delivery/input)
#   severity    BLOCKER|MAJOR|MINOR|INFO
#   status      PASS|WARNING|FAIL|NOT_EVALUABLE|REVISE
#   issue       short description
#   why         why it matters
#   panels      affected panels (comma-separated) or ""
#   action      recommended repair (not auto-applied)
#   owner       STATISTICS|ANALYSIS|FIGURE_GENERATOR|MANUSCRIPT|MANUAL_REVIEW
#   evidence    where the finding comes from (manifest row / file / metadata)

new_finding <- function(domain, severity, status, issue, why = "",
                        panels = "", action = "", owner = "MANUAL_REVIEW",
                        evidence = "", rule_id = "") {
  stopifnot(toupper(severity) %in% SEVERITY_ORDER,
            toupper(status) %in% c("PASS", "WARNING", "FAIL", "REVISE", "NOT_EVALUABLE", "INFO"))
  ## R6: 空 issue 校验 — 非 PASS finding 必须有非空诊断; PASS 也建议有正文
  if (!nzchar(trimws(issue))) {
    stop(sprintf("Empty finding message for %s/%s/%s — findings must carry a non-empty diagnosis",
                 toupper(domain), toupper(severity), toupper(status)))
  }
  list(domain = domain, severity = toupper(severity), status = toupper(status),
       issue = issue, why = why, panels = panels, action = action,
       owner = owner, evidence = evidence, rule_id = rule_id)
}

## ---- input inventory（第 1 层：Input Audit）----
# 输入项: required/optional 材料清单，输出 AVAILABLE/MISSING/NOT_EVALUABLE
INPUT_ITEMS <- c(
  "final_figure", "individual_panels", "figure_legend", "manuscript_results",
  "source_data", "statistical_metadata", "sample_metadata", "figure_manifest",
  "analysis_output", "before_after_pair", "journal_requirements"
)

inventory_inputs <- function(directory, contract) {
  out <- list()
  out$final_figure <- list(
    available = any(file.exists(file.path(directory, c("figure.png", "figure.pdf", "figure.svg", "figure.tiff")))) ||
      !is_blank(contract$final_figure_file) && file.exists(file.path(directory, contract$final_figure_file)),
    note = "final figure raster/vector")
  out$figure_manifest <- list(
    available = file.exists(file.path(directory, "figure_manifest.tsv")),
    note = "panel-level manifest")
  out$source_data <- list(
    available = length(list.files(directory, pattern = "source_data", full.names = TRUE)) > 0 ||
      (!is_blank(contract$source_data_glob) && length(Sys.glob(file.path(directory, contract$source_data_glob))) > 0),
    note = "panel-level source data")
  out$statistical_metadata <- list(
    available = file.exists(file.path(directory, "statistical_metadata.tsv")) ||
      (!is_blank(contract$statistical_metadata_file) && file.exists(file.path(directory, contract$statistical_metadata_file))),
    note = "statistical metadata")
  out$sample_metadata <- list(
    available = file.exists(file.path(directory, "sample_metadata.tsv")) ||
      (!is_blank(contract$sample_metadata_file) && file.exists(file.path(directory, contract$sample_metadata_file))),
    note = "sample metadata")
  out$figure_legend <- list(
    available = !is_blank(contract$figure_legend) || file.exists(file.path(directory, "figure_legend.md")),
    note = "legend text")
  out$manuscript_results <- list(
    available = !is_blank(contract$manuscript_results) || file.exists(file.path(directory, "manuscript_results.md")),
    note = "Results text")
  out$before_after_pair <- list(
    available = !is_blank(contract$before_figure_file) && file.exists(file.path(directory, contract$before_figure_file)) &&
      !is_blank(contract$after_figure_file) && file.exists(file.path(directory, contract$after_figure_file)),
    note = "before/after pair for change-impact audit")
  out
}

## ---- 报告渲染（R6: 分离 Figure Integrity / Publication Package）----
render_audit_markdown <- function(verdict, findings, inventory, directory,
                                  audit_mode = AUDIT_MODE_DEFAULT,
                                  figure_integrity = NULL,
                                  package_status = NULL,
                                  package_class = NULL,
                                  aggregated_rules = NULL,
                                  domain_status = NULL,
                                  publication_ready = NULL) {
  if (is.null(figure_integrity)) figure_integrity <- verdict
  lines <- c("# Potato Figure Audit", "",
             sprintf("Directory: `%s`", normalizePath(directory, mustWork = FALSE)),
             sprintf("Generated: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")), "",
             "## Executive Summary", "",
             sprintf("Audit Mode: `%s`", audit_mode), "")
  # Figure Integrity
  lines <- c(lines, "**Figure Integrity:**", "")
  lines <- c(lines, sprintf("**%s**", figure_integrity), "")
  if (!is.null(domain_status)) {
    fi_notes <- vapply(FIGURE_INTEGRITY_DOMAINS, function(d) {
      s <- if (d %in% names(domain_status)) domain_status[[d]] else "NOT_EVALUABLE"
      sprintf("- %s: %s", d, s)
    }, character(1))
  } else {
    fi_notes <- vapply(FIGURE_INTEGRITY_DOMAINS, function(d) {
      sub <- findings[vapply(findings, function(f) toupper(f$domain) == d, logical(1))]
      if (!length(sub)) return(sprintf("- %s: NOT_EVALUABLE", d))
      st <- unique(vapply(sub, function(f) f$status, character(1)))
      s <- if (any(st == "FAIL")) "FAIL" else if (any(st %in% c("REVISE", "WARNING"))) "REVISE" else if (any(st == "NOT_EVALUABLE")) "NOT_EVALUABLE" else "PASS"
      sprintf("- %s: %s", d, s)
    }, character(1))
  }
  lines <- c(lines, fi_notes, "")
  # Publication Package
  lines <- c(lines, "**Publication Package:**", "")
  if (!is.null(package_status)) {
    lines <- c(lines, sprintf("**%s**", package_status), "")
  }
  if (!is.null(package_class) && length(package_class$missing)) {
    lines <- c(lines, "Missing delivery items (not figure errors):", "")
    for (m in package_class$missing) lines <- c(lines, sprintf("- %s", m))
    lines <- c(lines, "")
  }
  if (!is.null(package_class) && length(package_class$error)) {
    lines <- c(lines, "Delivery errors (declared but wrong):", "")
    for (e in package_class$error) lines <- c(lines, sprintf("- %s", e))
    lines <- c(lines, "")
  }
  # Final Readiness
  lines <- c(lines, "**Final Publication Readiness:**", "")
  ready_flag <- if (is.null(publication_ready)) {
    compute_publication_ready(figure_integrity,
      if (is.null(package_status)) "NOT_EVALUABLE" else package_status,
      domain_status, audit_mode)
  } else isTRUE(publication_ready)
  lines <- c(lines, sprintf("**%s**", if (ready_flag) "READY" else "NOT READY"), "")
  # input inventory
  lines <- c(lines, "## Input Inventory", "",
             "| Item | Status |", "|---|---|")
  for (nm in names(inventory)) {
    st <- if (isTRUE(inventory[[nm]]$available)) "AVAILABLE" else "MISSING"
    lines <- c(lines, sprintf("| %s | %s |", nm, st))
  }
  lines <- c(lines, "")
  # What Passed / What Needs Revision / What Is Missing
  passed_domains <- c("SCIENTIFIC", "STATISTICAL", "CLAIM_EVIDENCE", "PANEL_ARCHITECTURE",
                      "VISUAL", "COLOR")
  passed <- character(); revise <- character(); missing <- character()
  for (d in passed_domains) {
    sub <- findings[vapply(findings, function(f) toupper(f$domain) == d, logical(1))]
    if (!length(sub)) next
    st <- unique(vapply(sub, function(f) f$status, character(1)))
    if (all(st %in% c("PASS", "INFO"))) passed <- c(passed, d)
    else if (any(st %in% c("REVISE", "WARNING"))) revise <- c(revise, d)
    else if (any(st == "FAIL")) revise <- c(revise, d)
  }
  lines <- c(lines, "## What Passed", "")
  if (!length(passed)) lines <- c(lines, "None (or not evaluable).", "")
  else for (d in passed) lines <- c(lines, sprintf("- %s", d))
  lines <- c(lines, "")
  lines <- c(lines, "## What Needs Revision", "")
  if (!length(revise)) {
    lines <- c(lines, "None.", "")
  } else {
    for (d in revise) {
      lines <- c(lines, sprintf("- **%s**", d))
      sub <- findings[vapply(findings, function(f) toupper(f$domain) == d && f$status %in% c("FAIL", "REVISE", "WARNING"), logical(1))]
      for (f in sub) lines <- c(lines, sprintf("  - %s", f$issue))
    }
    lines <- c(lines, "")
  }
  lines <- c(lines, "## What Is Missing For Publication Delivery", "")
  if (is.null(package_class) || !length(c(package_class$missing, package_class$error))) {
    lines <- c(lines, "Nothing (package complete or not evaluated).", "")
  } else {
    for (m in package_class$missing) lines <- c(lines, sprintf("- %s", m))
    for (e in package_class$error) lines <- c(lines, sprintf("- %s", e))
    lines <- c(lines, "")
  }
  # aggregated rules（合并同 rule 多 evidence）
  if (!is.null(aggregated_rules) && length(aggregated_rules)) {
    lines <- c(lines, "## Color Rule Evidence (aggregated)", "")
    for (rid in names(aggregated_rules)) {
      ag <- aggregated_rules[[rid]]
      lines <- c(lines, sprintf("- **%s** → **%s**", rid, ag$final_status))
      if (length(ag$evidence)) {
        for (ev in ag$evidence) {
          lines <- c(lines, sprintf("  - [%s/%s] %s", ev$severity, ev$status, ev$issue))
        }
      }
    }
    lines <- c(lines, "")
  }
  # grouped top issues（R6: 不再单一 Top Blocking）
  lines <- c(lines, "## Scientific / Figure Issues", "")
  sci <- findings[vapply(findings, function(f) toupper(f$domain) %in% c("SCIENTIFIC", "STATISTICAL", "CLAIM_EVIDENCE") && f$status %in% c("FAIL", "REVISE", "WARNING"), logical(1))]
  if (!length(sci)) lines <- c(lines, "None.", "") else {
    for (f in sci) lines <- c(lines, sprintf("- **[%s/%s]** %s", f$severity, f$status, f$issue))
    lines <- c(lines, "")
  }
  lines <- c(lines, "## Visual / Color Issues", "")
  vis <- findings[vapply(findings, function(f) toupper(f$domain) %in% c("VISUAL", "COLOR", "PANEL_ARCHITECTURE") && f$status %in% c("FAIL", "REVISE", "WARNING"), logical(1))]
  if (!length(vis)) lines <- c(lines, "None.", "") else {
    for (f in vis) lines <- c(lines, sprintf("- **[%s/%s]** %s", f$severity, f$status, f$issue))
    lines <- c(lines, "")
  }
  lines <- c(lines, "## Publication Package Missing Items", "")
  pkg_missing <- findings[vapply(findings, function(f) toupper(f$domain) %in% c("DELIVERY", "GLOBAL_COHERENCE") && f$status == "FAIL", logical(1))]
  if (is.null(package_class) || (!length(package_class$missing) && !length(package_class$error) && !length(pkg_missing))) {
    lines <- c(lines, "None.", "")
  } else {
    for (m in package_class$missing) lines <- c(lines, sprintf("- %s", m))
    for (e in package_class$error) lines <- c(lines, sprintf("- %s", e))
    for (f in pkg_missing) lines <- c(lines, sprintf("- %s", f$issue))
    lines <- c(lines, "")
  }
  lines <- c(lines, "## Reproducibility / Delivery Issues", "")
  repro <- findings[vapply(findings, function(f) toupper(f$domain) == "DELIVERY" && f$status %in% c("FAIL", "REVISE", "WARNING"), logical(1))]
  if (!length(repro)) lines <- c(lines, "None.", "") else {
    for (f in repro) lines <- c(lines, sprintf("- %s", f$issue))
    lines <- c(lines, "")
  }
  # recommended repairs grouped by owner
  lines <- c(lines, "## Recommended Repairs (by Owner)", "")
  repairs <- findings[vapply(findings, function(f) f$status %in% c("FAIL", "REVISE", "WARNING"), logical(1))]
  if (!length(repairs)) {
    lines <- c(lines, "None.", "")
  } else {
    owners <- c("STATISTICS", "FIGURE_GENERATOR", "ANALYSIS", "MANUAL_REVIEW", "DELIVERY", "USER")
    for (o in owners) {
      sub <- repairs[vapply(repairs, function(f) toupper(f$owner) == o, logical(1))]
      if (!length(sub)) next
      lines <- c(lines, sprintf("**%s:**", o), "")
      for (f in sub) {
        lines <- c(lines, sprintf("- %s → %s", f$issue, if (nzchar(f$action)) f$action else "review required"))
      }
      lines <- c(lines, "")
    }
  }
  # per-domain（保留详细层）
  domains <- c("scientific", "statistical", "claim_evidence", "panel_architecture",
               "global_coherence", "visual", "color", "delivery", "input")
  for (d in domains) {
    sub <- findings[vapply(findings, function(f) f$domain == d, logical(1))]
    lines <- c(lines, sprintf("## %s", toupper(d)), "")
    if (!length(sub)) {
      lines <- c(lines, "No findings.", "")
    } else {
      for (f in sub) {
        lines <- c(lines, sprintf("- [%s/%s] %s", f$severity, f$status, f$issue))
        if (nzchar(f$evidence)) lines <- c(lines, sprintf("  - Evidence: %s", f$evidence))
      }
      lines <- c(lines, "")
    }
  }
  lines
}

## ---- readiness 判定（fail-closed）----
compute_verdict <- function(findings) {
  has_blocker <- any(vapply(findings, function(f) f$severity == "BLOCKER", logical(1)))
  has_fail <- any(vapply(findings, function(f) f$status == "FAIL", logical(1)))
  has_revise <- any(vapply(findings, function(f) f$status %in% c("REVISE", "WARNING"), logical(1)))
  if (has_blocker || has_fail) return("FAIL")
  if (has_revise) return("REVISE")
  "PASS"
}

## ---- R6: domain 状态聚合 ----
# 从 findings 计算每个 domain 的最终状态
# FAIL > REVISE > WARNING > NOT_EVALUABLE > PASS
# 证据缺失型 WARNING（"not declared/not verifiable/missing"）降级为 NOT_EVALUABLE
evidence_missing_issue <- function(issue) {
  msg <- tolower(issue)
  patterns <- c("no ", "not declared", "not evaluable", "cannot be fully verified",
                "not declaratively", "no structured", "missing", "not verifiable",
                "metadata-only", "no legend", "no panel palette", "no continuous",
                "no hero", "no accent")
  any(vapply(patterns, function(p) grepl(p, msg, fixed = TRUE), logical(1)))
}

domain_status_from_findings <- function(findings, domains) {
  out <- character()
  for (d in domains) {
    sub <- findings[vapply(findings, function(f) toupper(f$domain) == toupper(d), logical(1))]
    if (!length(sub)) {
      out[[d]] <- "NOT_EVALUABLE"
    } else {
      st <- unique(vapply(sub, function(f) toupper(f$status), character(1)))
      if (any(st == "FAIL")) out[[d]] <- "FAIL"
      else if (any(st == "REVISE")) out[[d]] <- "REVISE"
      else if (any(st == "WARNING")) {
        ## 区分"证据缺失型"WARNING 与真实 WARNING
        warn_issues <- vapply(sub[vapply(sub, function(f) toupper(f$status) == "WARNING", logical(1))],
                              function(f) f$issue, character(1))
        all_missing_type <- all(vapply(warn_issues, evidence_missing_issue, logical(1)))
        if (all_missing_type && any(st == "PASS")) {
          ## 缺失型 WARNING（如 COLOR-02 无 legend）只是材料提示;
          ## 域已有实测 PASS 证据 → 状态取 PASS（不降级为 NE）
          out[[d]] <- "PASS"
        } else if (all_missing_type) {
          out[[d]] <- "NOT_EVALUABLE"
        } else {
          out[[d]] <- "WARNING"
        }
      }
      else if (any(st == "PASS")) out[[d]] <- "PASS"   ## 有实测通过证据 → PASS（NE 不覆盖）
      else if (any(st == "NOT_EVALUABLE")) out[[d]] <- "NOT_EVALUABLE"
      else out[[d]] <- "PASS"
    }
  }
  out
}

## ---- R6: FIGURE_INTEGRITY_STATUS ----
# 只回答"这张 Figure 本身是否成立"（科学/统计/claim/架构/视觉/色彩）
# PASS / PASS_WITH_WARNINGS / PASS_WITH_LIMITED_EVIDENCE / REVISE / FAIL / NOT_EVALUABLE
# 语义: 被评估的域全部通过 → PASS; 有 WARNING → PASS_WITH_WARNINGS;
#       部分域未提供材料（NE）但被评估域通过 → PASS（未发现错误 ≠ 不通过）
#       PASS_WITH_LIMITED_EVIDENCE 仅当 integrity 域中评估域通过但存在 NE 域时也可用,
#       但 spec 要求 B= PASS, 因此 NE 域不降级（除非全部 NE）
compute_figure_integrity <- function(domain_status) {
  doms <- intersect(FIGURE_INTEGRITY_DOMAINS, names(domain_status))
  if (!length(doms)) return("NOT_EVALUABLE")
  st <- domain_status[doms]
  evaluated <- st[st != "NOT_EVALUABLE"]
  if (!length(evaluated)) return("NOT_EVALUABLE")
  if (any(evaluated == "FAIL")) return("FAIL")
  if (any(evaluated == "REVISE")) return("REVISE")
  if (any(evaluated == "WARNING")) return("PASS_WITH_WARNINGS")
  ## 被评估域全部 PASS（NE 域不影响, 未发现错误）
  "PASS"
}

## ---- R6: PUBLICATION_PACKAGE_STATUS ----
# 只回答"投稿交付包是否完整"
# 关键语义: 缺东西 = INCOMPLETE（不是 Figure 无效）; 东西存在但明显错误 = FAIL
# PASS / INCOMPLETE / FAIL / NOT_EVALUABLE
compute_publication_package <- function(domain_status, package_class = NULL) {
  doms <- intersect(PUBLICATION_PACKAGE_DOMAINS, names(domain_status))
  if (!length(doms)) return("NOT_EVALUABLE")
  st <- domain_status[doms]
  ## 交付域 FAIL: 用 classify 区分"缺材料"与"材料错误"
  if (!is.null(package_class) && length(package_class$error)) return("FAIL")
  if (any(st == "FAIL")) {
    ## 有 FAIL 但 classify 没标 error → 视为 INCOMPLETE（缺东西）
    return("INCOMPLETE")
  }
  if (any(st %in% c("INCOMPLETE", "NOT_EVALUABLE"))) return("INCOMPLETE")
  "PASS"
}

## ---- R6: 判定缺失 vs 错误的证据分类 ----
# 返回 list(missing = c(...), error = c(...))
# 用于 delivery 域: 缺格式/元数据 → INCOMPLETE; 声明但矛盾 → FAIL
classify_package_findings <- function(findings) {
  missing <- character(); error <- character()
  for (f in findings) {
    if (toupper(f$domain) != "DELIVERY" && toupper(f$domain) != "GLOBAL_COHERENCE") next
    if (toupper(f$status) == "PASS") next
    msg <- tolower(f$issue)
    ## 明确的"存在但错误"模式 → FAIL
    wrong_patterns <- c("hash mismatch", "contradict", "falsely declared", "not match",
                        "do not match", "does not match", "inconsistent", "invalid",
                        "unreadable", "violat", "missing contract fields", "cannot read",
                        "corrupt", "schema-incomplete", "duplicated", "dpi")
    ## 明确的"缺东西"模式 → INCOMPLETE
    missing_patterns <- c("missing", "not supplied", "not declared", "not available",
                          "cannot verify", "was not declared", "unavailable")
    is_wrong <- any(vapply(wrong_patterns, function(p) grepl(p, msg, fixed = TRUE), logical(1)))
    is_missing <- any(vapply(missing_patterns, function(p) grepl(p, msg, fixed = TRUE), logical(1)))
    if (is_wrong && !is_missing) {
      error <- c(error, f$issue)
    } else {
      missing <- c(missing, f$issue)
    }
  }
  list(missing = unique(missing), error = unique(error))
}

## ---- R6: RULE_EVIDENCE_AGGREGATION ----
# 同一 rule 可能有多条 evidence 记录（declarative/raster/vision）。
# 最终状态: confirmed contradiction > missing evidence > supportive evidence
# 允许最终: PASS / PASS_WITH_LIMITED_EVIDENCE / WARNING / REVISE / FAIL / NOT_EVALUABLE
aggregate_rule_evidence <- function(findings) {
  rules <- unique(vapply(findings, function(f) f$rule_id, character(1)))
  rules <- rules[nzchar(rules)]
  if (!length(rules)) return(list())
  out <- list()
  for (rid in rules) {
    sub <- findings[vapply(findings, function(f) identical(f$rule_id, rid), logical(1))]
    final <- "NOT_EVALUABLE"
    evidence_records <- lapply(sub, function(f) {
      list(domain = f$domain, severity = f$severity, status = f$status,
           issue = f$issue, evidence = f$evidence)
    })
    sts <- vapply(sub, function(f) toupper(f$status), character(1))
    ## 冲突证据（confirmed contradiction）优先级最高 → FAIL/REVISE
    if (any(sts == "FAIL")) {
      final <- "FAIL"
    } else if (any(sts == "REVISE")) {
      final <- "REVISE"
    } else if (any(sts == "WARNING") && any(sts == "PASS")) {
      ## PASS + WARNING 并存: 以 WARNING 为准（但标注有通过证据）
      final <- "WARNING"
    } else if (any(sts == "WARNING")) {
      final <- "WARNING"
    } else if (any(sts == "PASS") && any(sts == "NOT_EVALUABLE")) {
      ## 有通过证据 + 有缺证据 → PASS_WITH_LIMITED_EVIDENCE
      final <- "PASS_WITH_LIMITED_EVIDENCE"
    } else if (all(sts == "PASS")) {
      final <- "PASS"
    } else if (any(sts == "NOT_EVALUABLE")) {
      final <- "NOT_EVALUABLE"
    }
    out[[rid]] <- list(rule_id = rid, final_status = final,
                       evidence_count = length(sub),
                       evidence = evidence_records)
  }
  out
}

## ---- R6 / v0.4.2-alpha: repair routes（按 owner 分组, 供 orchestrator 路由）----
## 只收集"需要行动"的 finding（FAIL/REVISE）; NOT_EVALUABLE/WARNING 是材料缺失提示,
## 不进入修复路由（否则 orchestrator 会误路由成重画图）
##
## v0.4.2-alpha NEXT_ACTION vocabulary (consumed by workflow >= v0.2.0-alpha):
##   RETURN_TO_STATISTICS    SCIENTIFIC/STATISTICAL domain FAIL/REVISE
##   RETURN_TO_CLAIM_EVIDENCE  CLAIM_EVIDENCE domain FAIL/REVISE
##   REVISE_FIGURE           only VISUAL/COLOR/PANEL_ARCHITECTURE need work
##   COMPLETE_DELIVERY       figure OK, publication package INCOMPLETE
##   FIX_DELIVERY            delivery material declared but wrong
##   HUMAN_REVIEW_REQUIRED   multiple distinct repair targets or not evaluable
##   NONE                    ready
repair_routes <- function(findings, figure_integrity, package_status, domain_status = NULL) {
  owners <- c("STATISTICS", "FIGURE_GENERATOR", "ANALYSIS", "MANUAL_REVIEW", "DELIVERY", "USER")
  routes <- list()
  for (o in owners) {
    routes[[o]] <- list()
  }
  for (f in findings) {
    if (!toupper(f$status) %in% c("FAIL", "REVISE")) next
    owner <- toupper(f$owner)
    if (!owner %in% names(routes)) owner <- "USER"
    routes[[owner]][[length(routes[[owner]]) + 1]] <- f$issue
  }
  ## ---- domain-aware top-level routing ----
  ds <- normalize_domain_status(domain_status)
  bad_domain <- function(d) (d %in% names(ds)) && ds[[d]] %in% c("FAIL", "REVISE")
  need_stat   <- bad_domain("SCIENTIFIC") || bad_domain("STATISTICAL")
  need_claim  <- bad_domain("CLAIM_EVIDENCE")
  need_figure <- bad_domain("VISUAL") || bad_domain("COLOR") || bad_domain("PANEL_ARCHITECTURE")
  n_targets   <- sum(c(need_stat, need_claim, need_figure))
  ## 顶层路由
  if (figure_integrity %in% c("FAIL", "REVISE")) {
    if (n_targets >= 2) {
      routes$NEXT_ACTION <- "HUMAN_REVIEW_REQUIRED"
    } else if (need_stat) {
      routes$NEXT_ACTION <- "RETURN_TO_STATISTICS"
    } else if (need_claim) {
      routes$NEXT_ACTION <- "RETURN_TO_CLAIM_EVIDENCE"
    } else {
      routes$NEXT_ACTION <- "REVISE_FIGURE"
    }
  } else if (figure_integrity == "NOT_EVALUABLE") {
    routes$NEXT_ACTION <- "HUMAN_REVIEW_REQUIRED"
  } else if (package_status == "INCOMPLETE") {
    routes$NEXT_ACTION <- "COMPLETE_DELIVERY"
  } else if (package_status == "FAIL") {
    routes$NEXT_ACTION <- "FIX_DELIVERY"
  } else {
    routes$NEXT_ACTION <- "NONE"
  }
  lapply(routes, unique)
}

## ---- JSON 输出 ----
findings_to_list <- function(findings) {
  lapply(findings, function(f) {
    list(domain = f$domain, severity = f$severity, status = f$status,
         issue = f$issue, why = f$why, panels = f$panels,
         action = f$action, owner = f$owner, evidence = f$evidence,
         rule_id = if (is.null(f$rule_id) || is.na(f$rule_id)) "" else f$rule_id)
  })
}

write_audit_json <- function(verdict, findings, inventory, path,
                             audit_mode = AUDIT_MODE_DEFAULT,
                             figure_integrity = NULL,
                             package_status = NULL,
                             aggregated_rules = NULL,
                             routes = NULL,
                             publication_ready = NULL,
                             domain_status = NULL,
                             audited_artifacts = NULL) {
  if (is.null(figure_integrity)) figure_integrity <- verdict
  ## v0.4.2-alpha: readiness is computed ONCE by compute_publication_ready()
  ## (fail-closed). Callers must pass it; we never recompute it loosely here.
  if (is.null(publication_ready)) {
    publication_ready <- compute_publication_ready(figure_integrity,
      if (is.null(package_status)) "NOT_EVALUABLE" else package_status,
      domain_status, audit_mode)
  }
  body <- list(
    tool = "potato-figure-audit", version = SKILL_VERSION,
    contract_version = AUDIT_CONTRACT_VERSION,
    audit_mode = audit_mode,
    figure_integrity = list(status = figure_integrity),
    publication_package = list(status = if (is.null(package_status)) "NOT_EVALUABLE" else package_status),
    publication_ready = isTRUE(publication_ready),
    ## v0.4.2-alpha 新鲜度绑定: 被审计输入文件的 SHA-256 清单。
    ## 编排器消费审计结果前必须重算; 任一缺失/不匹配 → AUDIT_STALE。
    audited_artifacts = if (is.null(audited_artifacts)) list() else audited_artifacts,
    ## legacy flat fields (kept for backward compatibility; deprecated —
    ## orchestrators >= v0.2.0-alpha must consume the nested contract above)
    verdict = verdict,
    figure_integrity_legacy = figure_integrity,
    publication_package_legacy = if (is.null(package_status)) "NOT_EVALUABLE" else package_status,
    domain_status = as.list(domain_status),
    input_inventory = lapply(inventory, function(x) list(available = isTRUE(x$available), note = x$note)),
    findings = findings_to_list(findings),
    aggregated_rules = if (is.null(aggregated_rules)) list() else aggregated_rules,
    repair_routes = if (is.null(routes)) list() else routes,
    raw_evidence = findings_to_list(findings)
  )
  writeLines(audit_json_string(body), path)
}

## ---- 新鲜度绑定: audited_artifacts SHA-256 清单 ----
## 审计输出本身不参与绑定（它们是审计产物, 不是被审计输入）。
AUDIT_OUTPUT_BASENAMES <- c("figure_audit.json", "figure_audit_report.md")

compute_audited_artifacts <- function(directory, extra_exclude_basenames = character()) {
  all_rel <- list.files(directory, recursive = TRUE, full.names = FALSE)
  all_rel <- all_rel[file.exists(file.path(directory, all_rel))]
  excl <- unique(c(AUDIT_OUTPUT_BASENAMES, extra_exclude_basenames))
  keep <- !(all_rel %in% excl) & !(basename(all_rel) %in% excl)
  all_rel <- sort(all_rel[keep])
  out <- list()
  for (rel in all_rel) {
    p <- file.path(directory, rel)
    rel_posix <- gsub("\\\\", "/", rel)
    out[[rel_posix]] <- list(sha256 = sha256_file(p),
                             bytes = as.numeric(file.info(p)$size))
  }
  out
}

## ---- JSON 序列化（完整转义; jsonlite 优先）----
## 主路径: jsonlite::toJSON(auto_unbox=TRUE)（jsonlite 为文档化运行时要求）。
## 回退路径: jsonlite_compact() —— 完整转义 \、"、控制字符（\n \r \t \b \f 及
## 其余 <0x20 → \u00XX）。旧实现只转义双引号, 含反斜杠的 Windows 绝对路径与
## 含换行/Unicode 的 finding 会产生非法 JSON, 已修复。
audit_json_string <- function(body) {
  if (requireNamespace("jsonlite", quietly = TRUE)) {
    return(as.character(jsonlite::toJSON(body, auto_unbox = TRUE,
                                         null = "null", na = "null", digits = 15)))
  }
  jsonlite_compact(body)
}

esc_json_string <- function(x) {
  x <- as.character(x)
  x <- gsub("\\", "\\\\", x, fixed = TRUE)
  x <- gsub('"', '\\"', x, fixed = TRUE)
  x <- gsub("\n", "\\n", x, fixed = TRUE)
  x <- gsub("\r", "\\r", x, fixed = TRUE)
  x <- gsub("\t", "\\t", x, fixed = TRUE)
  x <- gsub("\b", "\\b", x, fixed = TRUE)
  x <- gsub("\f", "\\f", x, fixed = TRUE)
  ## 剩余控制字符 → \u00XX
  for (cp in c(1:7, 11, 14:31)) {
    x <- gsub(intToUtf8(cp), sprintf("\\u%04x", cp), x, fixed = TRUE)
  }
  ## 非 ASCII → \uXXXX（best-effort; 主路径由 jsonlite 处理）
  m <- gregexpr("[^\x20-\x7e]", x)
  hits <- unique(unlist(regmatches(x, m)))
  for (h in hits) {
    cp <- tryCatch(utf8ToInt(h), error = function(e) NA_integer_)
    if (length(cp) && !is.na(cp[1])) {
      x <- gsub(h, sprintf("\\u%04x", cp[1]), x, fixed = TRUE)
    }
  }
  x
}

jsonlite_compact <- function(x) {
  # 无 jsonlite 依赖的极简 JSON 序列化（字符串/逻辑/列表; 完整转义）
  if (is.null(x)) return("null")
  if (is.list(x)) {
    if (is.null(names(x)) || !length(names(x)) || all(!nzchar(names(x)))) {
      return(paste0("[", paste(vapply(x, jsonlite_compact, character(1)), collapse = ","), "]"))
    }
    inner <- vapply(names(x), function(nm) {
      paste0('"', esc_json_string(nm), '":', jsonlite_compact(x[[nm]]))
    }, character(1))
    paste0("{", paste(inner, collapse = ","), "}")
  } else if (length(x) > 1) {
    paste0("[", paste(vapply(as.list(x), jsonlite_compact, character(1)), collapse = ","), "]")
  } else if (length(x) == 0) {
    "null"
  } else if (is.atomic(x) && length(x) == 1 && is.na(x)) {
    "null"
  } else if (is.logical(x)) {
    if (isTRUE(x)) "true" else "false"
  } else if (is.numeric(x)) {
    if (is.na(x)) "null" else as.character(x)
  } else {
    paste0('"', esc_json_string(x), '"')
  }
}
