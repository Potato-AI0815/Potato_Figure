#!/usr/bin/env Rscript
# run_raster_security_tests.R — Potato Figure Audit v0.4.3-alpha (Gate A-3)
# P0 安全回归: "数据永远作为参数，绝不作为源码的一部分"。
#
# 用例:
#   S1  静态契约: R 侧不再把图像路径 sprintf/writeLines 进生成的 Python 源码
#   S2  hostile 文件名 E2E（单引号/空格/分号/&%!()/unicode）→ metrics+panels 正常
#   S3  注入形状文件名（伪 Python 代码片段）不得执行、不得崩溃
#   S4  Python 不可用 → 返回 NULL（fail-closed），不报错
#   S5  raster_measure.py 缺失 → 返回 NULL（fail-closed），不报错
#
# 用法: Rscript tests/run_raster_security_tests.R [skill_root]
#       （可选）POTATO_PYTHON 指定 python 可执行文件

args <- commandArgs(trailingOnly = TRUE)
root <- if (length(args) >= 1) args[1] else "."
root <- normalizePath(root, mustWork = TRUE)
scripts <- file.path(root, "scripts")

source(file.path(scripts, "lib", "qa_common.R"))
source(file.path(scripts, "lib", "color_system_core.R"))

pass <- 0; fail <- 0; skip <- 0
check <- function(name, ok, detail = "") {
  if (is.na(ok)) { skip <<- skip + 1; cat(sprintf("SKIP %-44s %s\n", name, detail)) }
  else if (ok)   { pass <<- pass + 1; cat(sprintf("PASS %-44s %s\n", name, detail)) }
  else           { fail <<- fail + 1; cat(sprintf("FAIL %-44s %s\n", name, detail)) }
}

## ---- S1 静态契约 ----
core_txt <- paste(readLines(file.path(scripts, "lib", "color_system_core.R"),
                            warn = FALSE, encoding = "UTF-8"), collapse = "\n")
check("S1 no Image.open interpolation in R",
      !grepl("Image\\.open\\(", core_txt) &&
      !grepl("writeLines\\(c\\([^)]*import sys", core_txt))
check("S1 static raster_measure.py shipped",
      file.exists(file.path(scripts, "raster_measure.py")))
py_txt <- paste(readLines(file.path(scripts, "raster_measure.py"),
                          warn = FALSE, encoding = "UTF-8"), collapse = "\n")
check("S1 raster_measure.py argv-driven (sys.argv/argparse)",
      grepl("argparse", py_txt) && grepl("args\\.image", py_txt) &&
      !grepl("sprintf|format\\(.*image", py_txt, ignore.case = TRUE))

## ---- python 可用性探测 ----
find_py <- function() {
  py <- trim_scalar(Sys.getenv("POTATO_PYTHON", ""))
  if (nzchar(py) && file.exists(py)) return(py)
  for (cand in c(Sys.which("python"), Sys.which("python3"))) if (nzchar(cand)) return(cand)
  ""
}
py <- find_py()
pil_ok <- FALSE
if (nzchar(py)) {
  r <- tryCatch(system2(py, c("-c", shQuote("import PIL, numpy")),
                        stdout = FALSE, stderr = FALSE), error = function(e) 1L)
  pil_ok <- identical(as.integer(r), 0L)
}

work <- tempfile("rastersec_")
dir.create(work, recursive = TRUE)

## ---- S2/S3 hostile 文件名 E2E ----
if (!nzchar(py) || !pil_ok) {
  check("S2 hostile filenames metrics", NA, "python/PIL unavailable")
  check("S3 injection-shaped filename", NA, "python/PIL unavailable")
} else {
  maker <- file.path(root, "tests", "lib", "make_fixture_png.py")
  hostile <- c("it's a test.png", "space name.png", "semi;colon.png",
               "and&percent%s!(bang).png", "uni_\u4e2d\u6587_\u00e9.png")
  ok_all <- TRUE; detail <- character()
  for (nm in hostile) {
    p <- file.path(work, nm)
    rc <- tryCatch(system2(py, c(shQuote(maker), shQuote(p)),
                           stdout = FALSE, stderr = FALSE), error = function(e) 1L)
    if (!identical(as.integer(rc), 0L) || !file.exists(p)) {
      ## unicode 名在此 locale 下 list/创建受限 → 直接写副本兜底
      base <- file.path(work, "base_fixture.png")
      if (!file.exists(base)) system2(py, c(shQuote(maker), shQuote(base)),
                                      stdout = FALSE, stderr = FALSE)
      file.copy(base, p, overwrite = TRUE)
    }
    m <- raster_color_metrics(p, panel_count = 2L, script_dir = scripts)
    pm <- raster_panel_metrics(p, grid_layout = "1x2", script_dir = scripts)
    okm <- !is.null(m) && !is.null(m$n_ink) && m$n_ink > 0 &&
           length(m$panel_mean_saturation) == 2
    okp <- !is.null(pm) && !is.null(pm$panels) && nrow(pm$panels) == 2
    if (!(okm && okp)) { ok_all <- FALSE; detail <- c(detail, nm) }
  }
  check("S2 hostile filenames metrics+panels", ok_all,
        if (ok_all) sprintf("%d names", length(hostile)) else paste(detail, collapse = "|"))

  ## S3: 文件名本身是"注入载荷"——旧实现把它拼进源码执行。
  ## 探针: 若载荷被执行，会在 cwd 生成 PWNED_MARKER.txt。
  inj_name <- "x');open('PWNED_MARKER.txt','w').write('1');print('.png"
  inj <- file.path(work, inj_name)
  base2 <- file.path(work, "base_fixture.png")
  if (!file.exists(base2)) system2(py, c(shQuote(maker), shQuote(base2)),
                                   stdout = FALSE, stderr = FALSE)
  file.copy(base2, inj, overwrite = TRUE)
  old_wd <- setwd(work)
  m3 <- tryCatch(raster_color_metrics(inj, panel_count = 1L, script_dir = scripts),
                 error = function(e) "ERROR")
  setwd(old_wd)
  marker <- file.path(work, "PWNED_MARKER.txt")
  check("S3 injection-shaped filename inert",
        !file.exists(marker) && !identical(m3, "ERROR"),
        if (file.exists(marker)) "PAYLOAD EXECUTED" else
          if (is.null(m3)) "no execution, NULL result" else "no execution, measured")
}

## ---- S4 Python 不可用 → NULL ----
old_py <- Sys.getenv("POTATO_PYTHON", NA)
Sys.setenv(POTATO_PYTHON = file.path(work, "no_such_python.exe"))
r4 <- tryCatch(raster_color_metrics(file.path(work, "whatever.png"),
                                    script_dir = scripts), error = function(e) "ERROR")
check("S4 python unavailable -> NULL (fail-closed)", is.null(r4),
      if (identical(r4, "ERROR")) "threw instead" else "")
if (is.na(old_py)) Sys.unsetenv("POTATO_PYTHON") else Sys.setenv(POTATO_PYTHON = old_py)

## ---- S5 脚本缺失 → NULL ----
old_rs <- Sys.getenv("POTATO_RASTER_SCRIPT", NA)
Sys.unsetenv("POTATO_RASTER_SCRIPT")
r5 <- tryCatch(raster_color_metrics(file.path(work, "whatever.png"),
                                    script_dir = file.path(work, "empty_dir")),
               error = function(e) "ERROR")
check("S5 missing raster script -> NULL (fail-closed)", is.null(r5),
      if (identical(r5, "ERROR")) "threw instead" else "")
if (!is.na(old_rs)) Sys.setenv(POTATO_RASTER_SCRIPT = old_rs)

unlink(work, recursive = TRUE)
cat(sprintf("\nRASTER SECURITY TESTS: %d/%d PASS (%d skipped)\n", pass, pass + fail, skip))
quit(status = if (fail == 0) 0 else 1)
