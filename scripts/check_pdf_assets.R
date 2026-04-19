#!/usr/bin/env Rscript

parse_args <- function(args) {
  out <- list(
    pdf_path = "",
    results_dir = "Results",
    min_pages = 150L,
    min_images = 70L
  )
  idx <- 1L
  while (idx <= length(args)) {
    key <- args[[idx]]
    if (!startsWith(key, "--")) {
      stop("Unexpected positional argument: ", key, call. = FALSE)
    }
    if (idx == length(args)) {
      stop("Missing value for ", key, call. = FALSE)
    }
    value <- args[[idx + 1L]]
    name <- gsub("-", "_", sub("^--", "", key))
    if (!name %in% names(out)) {
      stop("Unknown argument: ", key, call. = FALSE)
    }
    out[[name]] <- value
    idx <- idx + 2L
  }
  out
}

as_clean_count <- function(value, flag) {
  value <- trimws(as.character(value))
  if (!grepl("^[0-9]+$", value)) {
    stop(flag, " must be a non-negative integer.", call. = FALSE)
  }
  as.integer(value)
}

run_capture <- function(command, args) {
  output <- tryCatch(
    system2(command, shQuote(args), stdout = TRUE, stderr = TRUE),
    error = function(e) {
      stop("Failed to run ", command, ": ", conditionMessage(e), call. = FALSE)
    }
  )
  status <- attr(output, "status")
  if (!is.null(status) && !identical(status, 0L)) {
    stop(command, " exited with status ", status, ".", call. = FALSE)
  }
  output
}

scan_row <- function(check, status, observed = "", threshold = "", scanner = "", detail = "") {
  data.frame(
    check = check,
    status = status,
    observed = as.character(observed),
    threshold = as.character(threshold),
    scanner = scanner,
    detail = detail,
    stringsAsFactors = FALSE
  )
}

args <- parse_args(commandArgs(trailingOnly = TRUE))
if (!nzchar(args$pdf_path)) {
  stop("--pdf-path is required.", call. = FALSE)
}
args$min_pages <- as_clean_count(args$min_pages, "--min-pages")
args$min_images <- as_clean_count(args$min_images, "--min-images")

pdf_path <- normalizePath(args$pdf_path, winslash = "/", mustWork = TRUE)
results_dir <- normalizePath(args$results_dir, winslash = "/", mustWork = TRUE)
scan_path <- file.path(results_dir, "pdf_asset_presence_scan.csv")

required_bins <- c("pdfinfo", "pdfimages", "pdftotext")
missing_bins <- required_bins[!nzchar(Sys.which(required_bins))]
if (length(missing_bins)) {
  utils::write.csv(
    scan_row(
      "tool_availability",
      "failed",
      observed = paste(missing_bins, collapse = ", "),
      scanner = "system",
      detail = "Required Poppler tools are not available."
    ),
    scan_path,
    row.names = FALSE,
    na = ""
  )
  stop("Missing required Poppler tool(s): ", paste(missing_bins, collapse = ", "), call. = FALSE)
}

rows <- list()

pdfinfo_out <- run_capture(Sys.which("pdfinfo"), pdf_path)
page_line <- grep("^Pages:", pdfinfo_out, value = TRUE)
page_count <- if (length(page_line)) {
  suppressWarnings(as.integer(sub("^Pages:\\s*", "", page_line[[1L]])))
} else {
  NA_integer_
}
page_status <- if (is.na(page_count) || page_count < args$min_pages) "failed" else "passed"
rows[[length(rows) + 1L]] <- scan_row(
  "page_count",
  page_status,
  observed = page_count,
  threshold = paste0(">=", args$min_pages),
  scanner = "pdfinfo",
  detail = "Rendered PDF should not match the truncated validation-only artifact."
)

image_out <- run_capture(Sys.which("pdfimages"), c("-list", pdf_path))
image_rows <- grep("^\\s*[0-9]+\\s+[0-9]+\\s+image\\s+", image_out, value = TRUE)
image_count <- length(image_rows)
image_status <- if (image_count < args$min_images) "failed" else "passed"
rows[[length(rows) + 1L]] <- scan_row(
  "image_count",
  image_status,
  observed = image_count,
  threshold = paste0(">=", args$min_images),
  scanner = "pdfimages",
  detail = "All-preview report should include the expected set of embedded plot images."
)

tmp_txt <- tempfile(fileext = ".txt")
text_status <- tryCatch({
  system2(Sys.which("pdftotext"), shQuote(c(pdf_path, tmp_txt)), stdout = TRUE, stderr = TRUE)
}, error = function(e) {
  structure(conditionMessage(e), status = 1L)
})
status_code <- attr(text_status, "status")
if (!is.null(status_code) && !identical(status_code, 0L)) {
  rows[[length(rows) + 1L]] <- scan_row(
    "text_extraction",
    "failed",
    scanner = "pdftotext",
    detail = paste(text_status, collapse = " ")
  )
} else {
  pdf_text <- paste(readLines(tmp_txt, warn = FALSE), collapse = " ")
  pdf_text <- gsub("-\\s+", "-", pdf_text, perl = TRUE)
  pdf_text <- gsub("\\s+", " ", pdf_text, perl = TRUE)

  required_snippets <- c(
    "Figure 1. Cohort assembly",
    "Figure 2. Primary MI-logistic IPSW-weighted spline associations",
    "Figure S1. Covariate balance after MI logistic inverse-probability weighting",
    "Figure S2. Propensity-score overlap for MI logistic",
    "Figure S3. SHAP-style contribution summaries for MI logistic",
    "Figure S4. MI-logistic IPSW-weighted categorical associations",
    "Figure S5. Unweighted covariate-adjusted spline associations",
    "Figure S6. Covariate balance after gradient-boosted propensity weighting",
    "Figure S7. Propensity-score overlap for gradient-boosted",
    "Figure S8. SHAP-style contribution summaries for gradient-boosted",
    "Table 1. Baseline characteristics",
    "Table 2. MI-pooled, MI-logistic IPSW-weighted 3-level categorical results",
    "Table S2. Crude associations",
    "Table S3. GBM IPSW-weighted associations"
  )
  found <- vapply(required_snippets, grepl, logical(1L), x = pdf_text, fixed = TRUE)
  for (idx in seq_along(required_snippets)) {
    rows[[length(rows) + 1L]] <- scan_row(
      paste0("required_text_", idx),
      if (found[[idx]]) "passed" else "failed",
      observed = if (found[[idx]]) "found" else "missing",
      scanner = "pdftotext",
      detail = required_snippets[[idx]]
    )
  }
}

scan_df <- do.call(rbind, rows)
utils::write.csv(scan_df, scan_path, row.names = FALSE, na = "")

if (any(scan_df$status == "failed", na.rm = TRUE)) {
  failed_checks <- scan_df$check[scan_df$status == "failed"]
  stop(
    "PDF asset-presence validation failed: ",
    paste(failed_checks, collapse = ", "),
    "; see ",
    scan_path,
    call. = FALSE
  )
}

cat("[pdf-assets] validation passed: ", scan_path, "\n", sep = "")
