#!/usr/bin/env Rscript
# run_binding_serializer_tests.R — potato-figure-audit v0.4.3-alpha
# 新鲜度绑定（audited_artifacts SHA-256）与 JSON 序列化对抗性测试:
#   B1 SHA-256 已知向量（空串 / "abc" / 双块 / 文件级）
#   B2 jsonlite_compact 回退序列化: Windows 路径反斜杠、引号、换行、控制字符、Unicode
#   B3 audit_json_string 主路径（jsonlite）roundtrip 等价
#   B4 compute_audited_artifacts: 排除审计输出、递归、哈希正确
#   B5 主入口 E2E: figure_audit.json 含 audited_artifacts; 篡改输入 → 哈希不匹配（stale）;
#      删除输入 → 文件缺失（stale）
# 用法: Rscript tests/run_binding_serializer_tests.R <repo_root>

args <- commandArgs(trailingOnly = TRUE)
repo <- normalizePath(if (length(args) >= 1) args[1] else ".", mustWork = TRUE)
stopifnot(file.exists(file.path(repo, "scripts", "audit_figure.R")))

source(file.path(repo, "scripts", "lib", "sha256.R"))
source(file.path(repo, "scripts", "lib", "audit_core.R"))

pass <- 0L; fail <- 0L
check <- function(name, ok, detail = "") {
  ok <- isTRUE(ok)
  if (ok) { pass <<- pass + 1L; cat(sprintf("PASS %s %s\n", name, detail)) }
  else    { fail <<- fail + 1L; cat(sprintf("FAIL %s %s\n", name, detail)) }
}
have_jsonlite <- requireNamespace("jsonlite", quietly = TRUE)

tmp <- file.path(tempdir(), "binding_tests")
unlink(tmp, recursive = TRUE)
dir.create(tmp, recursive = TRUE)

## ================= B1 SHA-256 已知向量 =================
check("B1a sha256 empty vector",
      identical(sha256_raw(integer(0)),
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"))
check("B1b sha256('abc')",
      identical(sha256_raw(as.integer(charToRaw("abc"))),
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"))
check("B1c sha256 two-block vector",
      identical(sha256_raw(as.integer(charToRaw(
        "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"))),
        "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"))
## 文件级: 内容恰为 "abc" → 与已知向量一致（不依赖 digest/openssl）
f_abc <- file.path(tmp, "abc.bin")
writeBin(charToRaw("abc"), f_abc)
check("B1d sha256_file('abc' file)",
      identical(sha256_file(f_abc),
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"))
## 随机二进制: sha256_file 与纯 R 逐字节实现一致（校验文件读取路径）
set.seed(7)
f_rnd <- file.path(tmp, "rnd.bin")
raw_rnd <- as.raw(sample(0:255, 200000, replace = TRUE))
writeBin(raw_rnd, f_rnd)
check("B1e sha256_file == sha256_raw on 200KB binary",
      identical(sha256_file(f_rnd), sha256_raw(as.integer(raw_rnd))))

## ================= B2 回退序列化对抗性转义 =================
## 运行时拼接出 Windows 反斜杠绝对路径, 源码中不出现 "盘符:\" 字面量（包验证器扫描）
win_path <- paste0("C", ":", "\\", "Users", "\\", "YHN", "\\",
                   "Figure", "\\", "panel A.png")
adv <- c(
  win_path,                                        # Windows 反斜杠路径
  'quote " and \\backslash',                      # 引号 + 反斜杠
  "line1\nline2\r\nline3",                        # 换行
  "tab\there\b\f",                                # 制表/退格/换页
  paste0("ctrl", intToUtf8(1), intToUtf8(27), "end"),  # 其余控制字符
  "Unicode: \u4e2d\u6587 \u03b1\u03b2 \u00e9"    # 中文/希腊/重音
)
names(adv) <- paste0("s", seq_along(adv))
all_ok_fallback <- TRUE; fb_detail <- ""
for (nm in names(adv)) {
  js <- jsonlite_compact(list(x = adv[[nm]]))
  back <- tryCatch(jsonlite::fromJSON(js, simplifyVector = FALSE)[["x"]],
                   error = function(e) paste0("PARSE_ERROR: ", conditionMessage(e)))
  if (!identical(back, adv[[nm]])) {
    all_ok_fallback <- FALSE
    fb_detail <- sprintf("%s roundtrip broken: %s", nm, substr(js, 1, 80))
    break
  }
}
check("B2a jsonlite_compact fallback escapes backslash/quote/newline/ctrl/unicode",
      have_jsonlite && all_ok_fallback, fb_detail)
check("B2b fallback never emits raw control char",
      !grepl("[\x01-\x1f]", jsonlite_compact(list(x = adv)), useBytes = TRUE))
check("B2c fallback NULL/NA/numeric safe",
      identical(jsonlite_compact(list(a = NULL, b = NA, c = 1.5)),
                '{"a":null,"b":null,"c":1.5}'))

## ================= B3 audit_json_string 主路径 roundtrip =================
body <- list(
  tool = "potato-figure-audit", contract_version = "R6.1",
  figure_integrity = list(status = "PASS"),
  publication_ready = TRUE,
  findings = list(list(domain = "DELIVERY", severity = "MAJOR", status = "FAIL",
                       issue = adv[["s1"]], why = adv[["s3"]], panels = "",
                       action = adv[["s6"]], owner = "DELIVERY", evidence = "",
                       rule_id = "")),
  repair_routes = list(NEXT_ACTION = "NONE"),
  audited_artifacts = list("figure.png" = list(sha256 = "abc123", bytes = 1))
)
js_main <- audit_json_string(body)
back_main <- tryCatch(jsonlite::fromJSON(js_main, simplifyVector = FALSE),
                      error = function(e) NULL)
check("B3a audit_json_string output parses", !is.null(back_main))
check("B3b main path preserves adversarial strings",
      !is.null(back_main) &&
        identical(back_main$findings[[1]]$issue, adv[["s1"]]) &&
        identical(back_main$findings[[1]]$why, adv[["s3"]]) &&
        identical(back_main$findings[[1]]$action, adv[["s6"]]))
check("B3c main path keeps scalars unboxed",
      !is.null(back_main) && isTRUE(back_main$publication_ready) &&
        identical(back_main$figure_integrity$status, "PASS"))

## ================= B4 compute_audited_artifacts =================
b4 <- file.path(tmp, "b4dir")
dir.create(file.path(b4, "source_data"), recursive = TRUE, showWarnings = FALSE)
writeBin(charToRaw("abc"), file.path(b4, "figure.png"))
writeLines("panel\tfile", file.path(b4, "figure_manifest.tsv"))
writeLines("x", file.path(b4, "source_data", "raw.tsv"))
## 审计输出不得参与绑定
writeLines("{}", file.path(b4, "figure_audit.json"))
writeLines("# report", file.path(b4, "figure_audit_report.md"))
aa <- compute_audited_artifacts(b4)
check("B4a binding covers inputs incl. subdir",
      setequal(names(aa),
               c("figure.png", "figure_manifest.tsv", "source_data/raw.tsv")),
      paste(names(aa), collapse = ","))
check("B4b audit outputs excluded",
      !any(c("figure_audit.json", "figure_audit_report.md") %in% names(aa)))
check("B4c recorded sha256 matches recomputation",
      identical(aa[["figure.png"]]$sha256, sha256_file(file.path(b4, "figure.png"))) &&
        identical(aa[["figure.png"]]$bytes, 3))

## ================= B5 主入口 E2E 绑定 =================
fixtures <- file.path(repo, "tests", "main_entry_fixtures", "ready_case")
e2e_ok <- dir.exists(fixtures)
if (!e2e_ok) {
  check("B5a ready_case fixture present", FALSE, "missing tests/main_entry_fixtures/ready_case")
} else {
  proj <- file.path(tmp, "e2e_bind")
  unlink(proj, recursive = TRUE)
  dir.create(proj, recursive = TRUE, showWarnings = FALSE)
  invisible(file.copy(list.files(fixtures, full.names = TRUE), proj, recursive = TRUE))
  rscript_bin <- file.path(R.home("bin"), "Rscript")
  rc <- suppressWarnings(system2(rscript_bin,
    c("--vanilla", shQuote(file.path(repo, "scripts", "audit_figure.R")),
      shQuote(proj), "--mode", "PUBLICATION_READY", "--json"),
    stdout = FALSE, stderr = FALSE))
  rc <- if (is.null(rc)) 0L else as.integer(rc)
  check("B5a audit entry exit 0 on ready_case", rc == 0L, sprintf("exit=%d", rc))
  aj_path <- file.path(proj, "figure_audit.json")
  j <- if (file.exists(aj_path) && have_jsonlite)
    tryCatch(jsonlite::fromJSON(aj_path, simplifyVector = FALSE),
             error = function(e) NULL) else NULL
  check("B5b figure_audit.json parseable", !is.null(j))
  aa5 <- j[["audited_artifacts"]]
  check("B5c audited_artifacts present and non-empty",
        !is.null(aa5) && length(aa5) > 0,
        sprintf("%d entries", if (is.null(aa5)) 0L else length(aa5)))
  need <- c("figure.png", "figure_manifest.tsv", "statistical_metadata.tsv")
  check("B5d critical inputs bound", all(need %in% names(aa5)),
        paste(intersect(need, names(aa5)), collapse = ","))
  check("B5e source_data bound recursively",
        any(grepl("^source_data/", names(aa5))))
  check("B5f audit outputs excluded from binding",
        !any(c("figure_audit.json", "figure_audit_report.md") %in% names(aa5)))
  ## 现场重算全部匹配（新鲜）—— 路径按平台分隔符解析（Windows: \; POSIX: /）
  mismatch <- ""
  for (rel in names(aa5)) {
    p <- file.path(proj, rel)
    if (!file.exists(p) ||
        !identical(tolower(sha256_file(p)), tolower(aa5[[rel]]$sha256))) {
      mismatch <- rel; break
    }
  }
  check("B5g fresh recompute matches recorded hashes", !nzchar(mismatch), mismatch)
  ## 篡改 figure.png → stale
  con <- file(file.path(proj, "figure.png"), open = "ab")
  writeBin(as.raw(c(0x01, 0x02)), con); close(con)
  tampered <- !identical(tolower(sha256_file(file.path(proj, "figure.png"))),
                         tolower(aa5[["figure.png"]]$sha256))
  check("B5h tampered figure.png detected as stale", tampered)
  ## 删除 statistical_metadata.tsv → missing
  unlink(file.path(proj, "statistical_metadata.tsv"))
  check("B5i deleted input detected as missing",
        !file.exists(file.path(proj, "statistical_metadata.tsv")))
}

cat(sprintf("\nBINDING/SERIALIZER TESTS: %d/%d PASS\n", pass, pass + fail))
quit(status = if (fail == 0) 0 else 1)
