required_global_state_fields <- function() {
  c(
    "state_version", "figure_id", "modality", "assembly_mode",
    "scientific.central_claim", "scientific.statistical_unit",
    "narrative.reading_order", "narrative.hero_panel", "narrative.panel_tags",
    "visual.profile", "visual.body_pt", "visual.axis_text_pt", "visual.panel_tag_pt",
    "geometry.target_width_occupancy", "geometry.target_height_occupancy",
    "geometry.outer_margin_mm", "geometry.panel_gap_mm",
    "assembly.final_canvas", "repair.change_log_file"
  )
}

global_qa_domains <- function() {
  c(
    "scientific_spine_preserved", "panel_role_consistency", "reading_order",
    "geometry_budget", "canvas_utilization", "physical_consistency",
    "chromatic_coherence", "typography_consistency", "assembly_coherence",
    "local_change_impact_closed"
  )
}

as_num <- function(x) {
  suppressWarnings(as.numeric(trim_scalar(x)))
}

contains_all_tokens <- function(observed, required) {
  obs <- tolower(split_values(gsub(";", ",", observed, fixed = TRUE)))
  req <- tolower(split_values(gsub(";", ",", required, fixed = TRUE)))
  all(req %in% obs)
}

read_impact_map <- function(repo_root) {
  path <- file.path(repo_root, "schemas", "impact_dependency_map.tsv")
  if (!file.exists(path)) stop("Impact dependency map not found: ", path)
  read.delim(path, stringsAsFactors = FALSE, check.names = FALSE,
             colClasses = "character", na.strings = character())
}

run_impact_audit <- function(directory, repo_root) {
  checks <- list()
  add <- function(rule, status, detail, advice = "", scope = "figure") {
    checks[[length(checks) + 1]] <<- new_check(rule, status, detail, advice, scope)
  }

  contract_path <- file.path(directory, "figure_contract.yaml")
  contract <- if (file.exists(contract_path)) {
    tryCatch(read_flat_yaml(contract_path), error = function(e) list())
  } else list()
  state_file <- if (!is_blank(contract$global_state_file)) contract$global_state_file else "global_figure_state.yaml"
  state_path <- file.path(directory, state_file)
  if (!file.exists(state_path)) {
    add("global_state_existence", "FAIL", paste("Missing", state_file),
        "Create global_figure_state.yaml before R4 impact tracking.")
    return(checks)
  }
  state <- tryCatch(read_flat_yaml(state_path), error = function(e) e)
  if (inherits(state, "error")) {
    add("global_state_parse", "FAIL", paste("Cannot read global state:", state$message))
    return(checks)
  }

  log_name <- if (!is_blank(state$repair.change_log_file)) state$repair.change_log_file else "local_change_log.tsv"
  log_path <- file.path(directory, log_name)
  if (!file.exists(log_path)) {
    last_change <- trim_scalar(state$repair.last_change_id)
    if (is_blank(last_change) || tolower(last_change) %in% c("none", "na")) {
      add("local_change_log", "PASS", "No local changes declared; change log not yet required.", scope = "not_applicable")
    } else {
      add("local_change_log", "FAIL", paste("State declares last change", last_change, "but change log is missing"),
          "Create the declared local change log and close all changes before readiness.")
    }
    return(checks)
  }

  log <- tryCatch(read.delim(log_path, stringsAsFactors = FALSE, check.names = FALSE,
                             colClasses = "character", na.strings = character()),
                  error = function(e) e)
  if (inherits(log, "error")) {
    add("local_change_log_parse", "FAIL", paste("Cannot read change log:", log$message))
    return(checks)
  }
  required_cols <- c("change_id", "timestamp", "change_type", "target_key", "reason",
                     "impact_scope", "required_rechecks", "recheck_status",
                     "global_state_updated", "closed", "notes")
  missing_cols <- setdiff(required_cols, names(log))
  if (length(missing_cols)) {
    add("local_change_log_schema", "FAIL", paste("Missing columns:", paste(missing_cols, collapse = ", ")),
        "Use schemas/local_change_log.example.tsv as the contract.")
    return(checks)
  }
  add("local_change_log_schema", "PASS", sprintf("%d change record(s) parsed", nrow(log)))
  if (!nrow(log)) {
    add("local_change_closure", "PASS", "Change log is empty; no unresolved local repair.")
    return(checks)
  }

  dep <- tryCatch(read_impact_map(repo_root), error = function(e) e)
  if (inherits(dep, "error")) {
    add("impact_dependency_map", "FAIL", dep$message)
    return(checks)
  }
  dep$change_type <- tolower(trimws(dep$change_type))

  for (i in seq_len(nrow(log))) {
    row <- log[i, , drop = FALSE]
    cid <- trim_scalar(row$change_id)
    ctype <- tolower(trim_scalar(row$change_type))
    if (!nzchar(ctype)) ctype <- "unknown"
    idx <- match(ctype, dep$change_type)
    if (is.na(idx)) idx <- match("unknown", dep$change_type)
    required <- if (!is.na(idx)) dep$required_rechecks[idx] else "full_global_recheck"
    logged <- trim_scalar(row$required_rechecks)
    if (!contains_all_tokens(logged, required)) {
      add("impact_scope_complete", "FAIL",
          sprintf("%s (%s) does not cover required rechecks: %s", cid, ctype, required),
          "Expand required_rechecks using schemas/impact_dependency_map.tsv before applying or closing the repair.",
          scope = cid)
    } else {
      add("impact_scope_complete", "PASS",
          sprintf("%s (%s) covers required dependency rechecks", cid, ctype), scope = cid)
    }

    closed <- tolower(trim_scalar(row$closed)) %in% c("yes", "true", "1", "closed")
    state_updated <- tolower(trim_scalar(row$global_state_updated)) %in% c("yes", "true", "1")
    recheck <- toupper(trim_scalar(row$recheck_status))
    if (!closed || !state_updated || recheck != "PASS") {
      add("local_change_closure", "FAIL",
          sprintf("%s unresolved: closed=%s, global_state_updated=%s, recheck_status=%s",
                  cid, trim_scalar(row$closed), trim_scalar(row$global_state_updated), recheck),
          "Rerender affected components and the final assembly, update global state, complete required rechecks, then close the change.",
          scope = cid)
    } else {
      add("local_change_closure", "PASS", sprintf("%s is closed after global recheck", cid), scope = cid)
    }
  }
  checks
}

read_global_manual_qa <- function(directory, contract) {
  qa_name <- if (!is_blank(contract$global_coherence_qa_file)) contract$global_coherence_qa_file else "global_coherence_qa.tsv"
  qa_path <- file.path(directory, qa_name)
  domains <- global_qa_domains()
  out <- list(interface = "NOT_READY", status = "NOT_REVIEWED", domain_count = 0L, path = qa_path)
  if (!file.exists(qa_path)) return(out)
  qa <- tryCatch(read.delim(qa_path, stringsAsFactors = FALSE, check.names = FALSE), error = function(e) NULL)
  if (is.null(qa) || !all(c("domain", "status", "notes") %in% names(qa))) return(out)
  vals <- trimws(as.character(qa$domain))
  counts <- table(vals)
  missing <- setdiff(domains, unique(vals))
  duplicated <- domains[domains %in% names(counts) & counts[domains] > 1]
  extra <- setdiff(unique(vals), domains)
  out$domain_count <- length(vals)
  if (length(missing) || length(duplicated) || length(extra) || length(vals) != length(domains)) return(out)
  status <- setNames(toupper(trimws(as.character(qa$status))), vals)[domains]
  allowed <- c("PASS", "REVISE", "FAIL", "NOT_REVIEWED")
  if (!all(status %in% allowed)) return(out)
  out$interface <- "READY"
  if (any(status == "FAIL")) out$status <- "FAIL"
  else if (any(status == "REVISE")) out$status <- "REVISE"
  else if (any(status == "NOT_REVIEWED")) out$status <- "NOT_REVIEWED"
  else out$status <- "PASS"
  out
}

run_global_coherence_audit <- function(directory, repo_root) {
  checks <- list()
  add <- function(rule, status, detail, advice = "", scope = "figure") {
    checks[[length(checks) + 1]] <<- new_check(rule, status, detail, advice, scope)
  }
  contract_path <- file.path(directory, "figure_contract.yaml")
  if (!file.exists(contract_path)) {
    add("contract_existence", "FAIL", "figure_contract.yaml is missing")
    return(checks)
  }
  contract <- tryCatch(read_flat_yaml(contract_path), error = function(e) e)
  if (inherits(contract, "error")) {
    add("contract_parse", "FAIL", paste("Cannot read contract:", contract$message))
    return(checks)
  }
  state_file <- if (!is_blank(contract$global_state_file)) contract$global_state_file else "global_figure_state.yaml"
  state_path <- file.path(directory, state_file)
  if (!file.exists(state_path)) {
    add("global_state_existence", "FAIL", paste("Missing", state_file),
        "R4 publication/high-impact mode requires a persistent Global Figure State.")
    return(checks)
  }
  state <- tryCatch(read_flat_yaml(state_path), error = function(e) e)
  if (inherits(state, "error")) {
    add("global_state_parse", "FAIL", paste("Cannot read global state:", state$message))
    return(checks)
  }

  missing <- required_global_state_fields()[vapply(required_global_state_fields(), function(k) is_blank(state[[k]]), logical(1))]
  if (length(missing)) {
    add("global_state_required_fields", "FAIL", paste("Missing/blank:", paste(missing, collapse = ", ")),
        "Start from schemas/global_figure_state.example.yaml and preserve the scientific/narrative/visual/geometry spines.")
  } else add("global_state_required_fields", "PASS", "Required R4 global-state fields are present")

  tags <- tolower(split_values(state$narrative.panel_tags))
  order <- tolower(split_values(state$narrative.reading_order))
  hero <- tolower(trim_scalar(state$narrative.hero_panel))
  if (length(tags) && anyDuplicated(tags)) add("panel_tags_unique", "FAIL", "Duplicate manuscript panel tags in global state")
  else add("panel_tags_unique", "PASS", "Manuscript panel tags are unique")
  if (length(tags) && !all(order %in% tags)) {
    add("reading_order_valid", "FAIL", "reading_order contains tags not present in panel_tags")
  } else add("reading_order_valid", "PASS", "Reading order is consistent with panel tags")
  if (length(tags) && nzchar(hero) && !hero %in% tags) {
    add("hero_in_panel_graph", "FAIL", paste("Hero panel", hero, "is not in panel_tags"))
  } else add("hero_in_panel_graph", "PASS", "Hero panel belongs to the manuscript panel graph")

  if (tolower(trim_scalar(state$assembly.final_canvas)) != "one_figure") {
    add("single_canvas_assembly", "FAIL", "assembly.final_canvas must be one_figure",
        "Final publication output must be one coherent manuscript figure, not independent plots sharing a directory.")
  } else add("single_canvas_assembly", "PASS", "Final assembly declared as one coherent figure canvas")

  if (tolower(trim_scalar(state$visual.profile)) == "potato-user-v1") {
    body <- as_num(state$visual.body_pt); axis <- as_num(state$visual.axis_text_pt); tag <- as_num(state$visual.panel_tag_pt)
    if (any(is.na(c(body, axis, tag)))) {
      add("potato_profile_typography", "FAIL", "Typography fields must be numeric for potato-user-v1")
    } else if (body < 8 || body > 12 || axis < 8 || axis > 12 || tag < 10 || tag > 12) {
      add("potato_profile_typography", "WARNING",
          sprintf("Typography outside preferred final-size profile: body=%.1f axis=%.1f tag=%.1f pt", body, axis, tag),
          "Use 8–12 pt ordinary text and 10–12 pt panel tags unless a journal/final-size exception is documented.")
    } else add("potato_profile_typography", "PASS", "Typography is within the personal-profile target range")

    wm <- as_num(state$geometry.target_width_occupancy); hm <- as_num(state$geometry.target_height_occupancy)
    gap <- as_num(state$geometry.panel_gap_mm); margin <- as_num(state$geometry.outer_margin_mm)
    if (!is.na(wm) && wm < 0.88) add("potato_profile_width_budget", "WARNING", sprintf("Target width occupancy %.2f < 0.88", wm))
    else add("potato_profile_width_budget", "PASS", "Width occupancy target matches compact personal profile")
    if (!is.na(hm) && hm < 0.82) add("potato_profile_height_budget", "WARNING", sprintf("Target height occupancy %.2f < 0.82", hm))
    else add("potato_profile_height_budget", "PASS", "Height occupancy target matches compact personal profile")
    if (!is.na(gap) && (gap < 2.5 || gap > 4.0)) add("potato_profile_panel_gap", "WARNING", sprintf("Panel gap %.2f mm outside preferred 2.5–4 mm range", gap))
    else add("potato_profile_panel_gap", "PASS", "Panel gap target matches compact profile")
    if (!is.na(margin) && (margin < 3.0 || margin > 4.0)) add("potato_profile_outer_margin", "WARNING", sprintf("Outer margin %.2f mm outside preferred 3–4 mm range", margin))
    else add("potato_profile_outer_margin", "PASS", "Outer margin target matches compact profile")
  } else {
    add("visual_profile_specific_rules", "PASS", "Non-personal profile: personal numeric heuristics are not imposed", scope = "not_applicable")
  }

  impact <- run_impact_audit(directory, repo_root)
  checks <- c(checks, impact)
  manual <- read_global_manual_qa(directory, contract)
  if (manual$interface != "READY") {
    add("global_manual_qa_interface", "WARNING", "Global coherence QA is missing or malformed",
        "Complete schemas/global_coherence_qa_template.tsv after final full-size and thumbnail review.")
  } else if (manual$status == "PASS") {
    add("global_manual_qa_interface", "PASS", "All required global-coherence review domains passed")
  } else if (manual$status == "FAIL") {
    add("global_manual_qa_interface", "FAIL", "Manual global-coherence review contains a FAIL")
  } else {
    add("global_manual_qa_interface", "WARNING", paste("Manual global-coherence status:", manual$status),
        "Resolve REVISE/NOT_REVIEWED domains before publication readiness.")
  }
  checks
}
