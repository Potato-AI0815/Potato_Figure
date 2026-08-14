#!/usr/bin/env Rscript
# claim_evidence_audit.R — R2.12 Claim-Evidence Consistency Audit
# 用 figure_contract 的 central_claim / hero_evidence / supporting_evidence
# 检查 claim 的证据层级是否匹配。Claim-aware：identity/descriptive claim
# 不强制要求统计；patient-level claim 必须有 patient-level 证据。
# 用法: Rscript claim_evidence_audit.R <figure_dir> [--json]

script_dir <- dirname(normalizePath(sub("^--file=", "",
  commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][1])))
source(file.path(script_dir, "lib", "qa_common.R"))

args <- commandArgs(trailingOnly = TRUE)
directory <- if (length(args) && !startsWith(args[1], "--")) args[1] else "."
as_json <- "--json" %in% args

checks <- list()
add <- function(rule, status, detail, fix = "", panel = "", why = "", evidence = "") {
  d <- detail
  if (nzchar(panel)) d <- paste0(d, " [panel: ", panel, "]")
  if (nzchar(why)) d <- paste0(d, " | why: ", why)
  if (nzchar(evidence)) d <- paste0(d, " | evidence: ", evidence)
  checks[[length(checks) + 1]] <<- list(
    rule = rule, status = status, detail = d, advice = fix, scope = "figure")
}

## ---- 读取 contract ----
contract_path <- file.path(directory, "figure_contract.yaml")
if (!file.exists(contract_path)) {
  add("contract_existence", "FAIL", "figure_contract.yaml is missing",
      "Claim-Evidence audit requires the figure-level design contract")
} else {
  contract <- tryCatch(read_flat_yaml(contract_path), error = function(e) e)
  if (inherits(contract, "error")) {
    add("contract_parse", "FAIL", paste("Cannot read contract:", contract$message))
  } else {
    claim <- trim_scalar(contract$central_claim)
    hero <- trim_scalar(contract$hero_evidence)
    support <- trim_scalar(contract$supporting_evidence)
    grammar <- trim_scalar(contract$figure_grammar)
    if (is_blank(claim)) {
      add("claim_declared", "FAIL", "central_claim is blank",
          "State the single figure-level claim before audit")
    } else {
      add("claim_declared", "PASS", paste("Claim:", substr(claim, 1, 80)))
    }
    if (is_blank(hero)) {
      add("hero_declared", "FAIL", "hero_evidence is blank",
          "Identify which panel carries the claim")
    } else {
      add("hero_declared", "PASS", "Hero evidence declared")
    }

    ## ---- claim-aware evidence-level classification ----
    claim_lc <- tolower(claim)
    ## 检测 claim 是否涉及患者/样本级推断
    patient_claim <- grepl("patient|sample|between|across|group|relapse|diagnosis|effect|increase|decrease|differ", claim_lc)
    ## 检测 claim 是否仅为 identity/descriptive
    identity_claim <- grepl("identif|express|marker|defin|characteri|landscape|state|map|compos", claim_lc)

    ## hero 面板证据层判断（从 contract 文本推断）
    hero_lc <- tolower(paste(hero, grammar))
    hero_cell_level <- grepl("umap|featureplot|violin|dotplot|cell-level|cell level|tsne", hero_lc)
    hero_patient_level <- grepl("patient|sample|pseudobulk|proportion|paired|effect|summary|delta", hero_lc)
    hero_identity <- grepl("dotplot|heatmap|signature|marker|umap|embedding", hero_lc)

    if (patient_claim && !identity_claim) {
      ## 患者级 claim
      if (hero_patient_level) {
        add("claim_evidence_consistency", "PASS",
            "Patient/sample-level claim is supported by patient-level hero evidence")
      } else if (hero_cell_level) {
        add("claim_evidence_consistency", "WARNING",
            "Patient/sample-level claim relies on cell-level descriptive hero (UMAP/FeaturePlot/violin/DotPlot)",
            "Add patient-level paired state proportion / effect / pseudobulk analysis as hero or co-hero",
            panel = "hero",
            why = "Cell-level descriptive evidence cannot alone support a patient-level inferential claim",
            evidence = "figure_contract: central_claim + hero_evidence + figure_grammar")
      } else {
        add("claim_evidence_consistency", "WARNING",
            "Cannot confirm hero evidence level matches the patient-level claim; verify manually",
            "Confirm the hero panel carries patient/sample-level evidence")
      }
    } else if (identity_claim) {
      ## identity/descriptive claim
      if (hero_identity) {
        add("claim_evidence_consistency", "PASS",
            "Identity/descriptive claim is appropriately supported by descriptive/identity evidence (no statistics required)")
      } else {
        add("claim_evidence_consistency", "PASS",
            "Claim is descriptive; evidence level acceptable (claim-aware, no forced statistics)")
      }
    } else {
      add("claim_evidence_consistency", "NOT_EVALUABLE",
          "Claim type not clearly patient-level or identity-level; manual review required")
    }

    ## ---- redundancy check (R2.7): hero vs supporting ----
    if (!is_blank(hero) && !is_blank(support)) {
      if (tolower(trimws(hero)) == tolower(trimws(support))) {
        add("hero_support_redundancy", "WARNING",
            "hero_evidence and supporting_evidence describe the same panel",
            "Remove one; redundant panels must be deleted, not kept for layout")
      } else {
        add("hero_support_redundancy", "PASS", "Hero and supporting evidence are distinct")
      }
    }
  }
}

if (as_json) {
  cat(checks_to_json("claim_evidence_audit", checks), "\n", sep = "")
} else {
  print_human_report("Potato_Figure Claim-Evidence Audit (R2.12)", directory, checks)
}
quit(status = if (overall_status(checks) == "FAIL") 1 else 0)
