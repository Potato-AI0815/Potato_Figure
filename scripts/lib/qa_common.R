trim_scalar <- function(x) {
  if (length(x) == 0 || is.na(x[1])) return("")
  trimws(as.character(x[1]))
}

is_blank <- function(x) {
  value <- trim_scalar(x)
  !nzchar(value) || toupper(value) %in% c("NA", "NULL", "NONE")
}

split_values <- function(x) {
  value <- trim_scalar(x)
  if (is_blank(value)) return(character())
  value <- sub("^\\[", "", value)
  value <- sub("\\]$", "", value)
  values <- trimws(unlist(strsplit(value, "[,;]")))
  values[nzchar(values)]
}

read_flat_yaml <- function(path) {
  if (!file.exists(path)) stop("YAML file not found: ", path)
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  out <- list()
  for (line in lines) {
    line <- sub("[[:space:]]+#.*$", "", line)
    if (!nzchar(trimws(line)) || grepl("^[[:space:]]", line)) next
    matched <- regexec("^([A-Za-z0-9_.-]+):[[:space:]]*(.*)$", line)
    parts <- regmatches(line, matched)[[1]]
    if (length(parts) != 3) next
    value <- trimws(parts[3])
    value <- sub("^['\"]", "", value)
    value <- sub("['\"]$", "", value)
    out[[parts[2]]] <- value
  }
  out
}

read_manifest <- function(path) {
  read.delim(path, check.names = FALSE, stringsAsFactors = FALSE,
             colClasses = "character", na.strings = character())
}

new_check <- function(rule, status, detail, advice = "", scope = "figure") {
  list(rule = rule, status = status, detail = detail, advice = advice, scope = scope)
}

overall_status <- function(checks) {
  statuses <- vapply(checks, function(x) x$status, character(1))
  if (any(statuses == "FAIL")) return("FAIL")
  if (any(statuses == "WARNING")) return("WARNING")
  "PASS"
}

json_escape <- function(x) {
  x <- gsub("\\\\", "\\\\\\\\", as.character(x))
  x <- gsub('"', '\\"', x, fixed = TRUE)
  x <- gsub("\n", "\\\\n", x, fixed = TRUE)
  x <- gsub("\r", "\\\\r", x, fixed = TRUE)
  x <- gsub("\t", "\\\\t", x, fixed = TRUE)
  x
}

json_scalar <- function(x) {
  if (is.null(x) || length(x) == 0 || is.na(x[1])) return("null")
  if (is.logical(x)) return(if (isTRUE(x[1])) "true" else "false")
  if (is.numeric(x)) return(as.character(x[1]))
  paste0('"', json_escape(x[1]), '"')
}

checks_to_json <- function(tool, checks, extra = list()) {
  check_json <- vapply(checks, function(item) {
    fields <- c("rule", "status", "detail", "advice", "scope")
    body <- paste(vapply(fields, function(field) {
      paste0('"', field, '":', json_scalar(item[[field]]))
    }, character(1)), collapse = ",")
    paste0("{", body, "}")
  }, character(1))
  head_fields <- c(list(tool = tool, overall_status = overall_status(checks)), extra)
  head_json <- paste(vapply(names(head_fields), function(field) {
    paste0('"', field, '":', json_scalar(head_fields[[field]]))
  }, character(1)), collapse = ",")
  paste0("{", head_json, ',"checks":[', paste(check_json, collapse = ","), "]}")
}

print_human_report <- function(title, directory, checks, footer = character()) {
  cat(sprintf("%s — %s\n\n", title, normalizePath(directory, mustWork = FALSE)))
  cat(sprintf("%-25s %-9s %s\n", "RULE", "STATUS", "DETAIL"))
  cat(strrep("-", 100), "\n")
  for (item in checks) {
    cat(sprintf("%-25s %-9s %s\n", item$rule, item$status, item$detail))
    if (nzchar(item$advice)) cat(sprintf("%-25s %-9s %s\n", "", "ADVICE", item$advice))
  }
  cat(strrep("-", 100), "\n")
  status <- overall_status(checks)
  counts <- table(factor(vapply(checks, function(x) x$status, character(1)),
                         levels = c("PASS", "WARNING", "FAIL")))
  cat(sprintf("%s: %d PASS, %d WARNING, %d FAIL\n",
              status, counts[["PASS"]], counts[["WARNING"]], counts[["FAIL"]]))
  if (length(footer)) cat(paste0(footer, collapse = "\n"), "\n")
}

script_directory <- function() {
  raw <- commandArgs(FALSE)
  file_arg <- raw[grepl("^--file=", raw)]
  if (!length(file_arg)) return(getwd())
  dirname(normalizePath(sub("^--file=", "", file_arg[1]), mustWork = FALSE))
}
