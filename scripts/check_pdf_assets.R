#!/usr/bin/env Rscript

parse_args <- function(args) {
  out <- list(
    pdf_path = "",
    results_dir = "Results",
    min_pages = 40L,
    min_images = 0L
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

read_active_manifest <- function(results_dir) {
  manifest_path <- file.path(results_dir, "manuscript_asset_manifest.csv")
  if (!file.exists(manifest_path)) return(data.frame())
  manifest <- tryCatch(
    utils::read.csv(manifest_path, stringsAsFactors = FALSE, na.strings = character()),
    error = function(e) data.frame()
  )
  required_cols <- c("manuscript_label", "title", "status", "pdf_display")
  if (!all(required_cols %in% names(manifest))) return(data.frame())
  pdf_display <- tolower(as.character(manifest$pdf_display)) %in% c("true", "1", "yes")
  active <- manifest[pdf_display & manifest$status != "draft_only", , drop = FALSE]
  active[order(seq_len(nrow(active))), , drop = FALSE]
}

write_pdf_label_scan <- function(active_manifest, pdf_text, results_dir) {
  if (!nrow(active_manifest)) return(invisible(NULL))
  run_id <- if ("run_id" %in% names(active_manifest)) {
    unique(active_manifest$run_id[nzchar(active_manifest$run_id)])[1]
  } else {
    NA_character_
  }
  run_ts <- if ("run_ts" %in% names(active_manifest)) {
    unique(active_manifest$run_ts[nzchar(active_manifest$run_ts)])[1]
  } else {
    NA_character_
  }
  if (is.na(run_id) || !nzchar(run_id)) run_id <- format(Sys.time(), "%Y%m%d_%H%M%S")
  if (is.na(run_ts) || !nzchar(run_ts)) run_ts <- as.character(Sys.time())
  labels <- active_manifest$manuscript_label
  detected <- vapply(
    paste0(labels, "."),
    grepl,
    logical(1L),
    x = pdf_text,
    fixed = TRUE
  )
  label_scan <- data.frame(
    label = labels,
    expected = TRUE,
    detected = detected,
    status = ifelse(detected, "PASS", "FAIL"),
    detail = ifelse(detected, "Active label detected in final PDF text.", "Active label missing from final PDF text."),
    run_id = run_id,
    run_ts = run_ts,
    stringsAsFactors = FALSE
  )
  utils::write.csv(
    label_scan,
    file.path(results_dir, "pdf_parse_table_figure_check.csv"),
    row.names = FALSE,
    na = ""
  )
  invisible(label_scan)
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
    detail = "Rendered PDF should contain the canonical manuscript/supplement display set."
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
  detail = "Image-count threshold is optional because manuscript figures may render as vector PDF inclusions."
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

  active_manifest <- read_active_manifest(results_dir)
  write_pdf_label_scan(active_manifest, pdf_text, results_dir)
  required_snippets <- if (nrow(active_manifest)) {
    paste0(active_manifest$manuscript_label, ". ", active_manifest$title)
  } else {
    character()
  }
  if (!length(required_snippets)) {
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
      "Table S1. Inclusion criteria",
      "Table S2. Crude associations",
      "Table S3. GBM IPSW-weighted associations",
      "Table S4. Missingness of baseline covariates",
      "Table S5. Multiple-imputation diagnostic summary"
    )
  }
	  required_snippets <- c(
	    required_snippets,
	    "marginally standardized to the common eligible source-population covariate distribution",
	    "relative association strength",
	    "standardized risk differences"
	  )
	  lr_labels_active <- nrow(active_manifest) &&
	    any(active_manifest$manuscript_label %in% c("Table S12", "Table S13", "Table S14", "Table S15", "Figure S13", "Figure S14"))
	  if (isTRUE(lr_labels_active)) {
	    required_snippets <- c(
	      required_snippets,
	      "Likelihood ratios are defined as pCO2-conditioned predicted outcome odds divided by the common weighted target-population baseline odds",
	      "LR =",
	      "VBG/ABG LR ratio"
	    )
	  }
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

  required_code_checks <- list(
    list(
      check = "scientific_code_visible_data_subset",
      snippets = c(
        "subset_data <- dplyr::sample_frac",
        "subset_data <-dplyr::sample_frac",
        "subset_data <- subset_data %>%",
        "subset_data <-subset_data %>%"
      )
    ),
    list(
      check = "scientific_code_visible_spline_model",
      snippets = c(
        "fit_spline_glm <- function",
        "fit_spline_glm <-function",
        "fit_imv <- fit_spline_glm",
        "fit_imv <-fit_spline_glm"
      )
    ),
    list(
      check = "scientific_code_visible_mi_single_pass",
      snippets = c(
        "This single-pass loop computes MI weights",
        "prepare_mi_ps_frame <- function",
        "extract_imputation <- function",
        "mitools::MIcombine"
      )
    ),
    list(
      check = "scientific_code_visible_ggplot",
      snippets = c("ggplot(", "ggplot2::ggplot(")
    )
  )
  for (item in required_code_checks) {
    present <- vapply(item$snippets, grepl, logical(1L), x = pdf_text, fixed = TRUE)
    ok <- any(present)
    rows[[length(rows) + 1L]] <- scan_row(
      item$check,
      if (ok) "passed" else "failed",
      observed = if (ok) item$snippets[[which(present)[[1L]]]] else "missing",
      scanner = "pdftotext",
      detail = paste(item$snippets, collapse = " OR ")
    )
  }

  last_window <- function(text, anchor, width = 5000L) {
    starts <- gregexpr(anchor, text, fixed = TRUE)[[1L]]
    if (identical(starts, -1L)) return("")
    start <- starts[[length(starts)]]
    substring(text, start, min(nchar(text), start + width))
  }

  required_window_checks <- list(
    list(
      check = "figure_2_note_below_display",
      anchor = "Figure 2. Primary MI-logistic IPSW-weighted spline associations",
      snippet = "Predicted probability curves are marginally standardized to the common eligible source-population covariate distribution"
    ),
    list(
      check = "figure_s4_note_below_display",
      anchor = "Figure S4. MI-logistic IPSW-weighted categorical associations",
      snippet = "Predicted probabilities are pooled on the link scale and marginally standardized to the common eligible source-population covariate distribution"
    ),
    list(
      check = "figure_s5_note_below_display",
      anchor = "Figure S5. Unweighted covariate-adjusted spline associations",
      snippet = "Note: Odds ratio curves are relative to the test-specific reference CO2 values"
    )
  )
  for (item in required_window_checks) {
    window <- last_window(pdf_text, item$anchor)
    ok <- nzchar(window) && grepl(item$snippet, window, fixed = TRUE)
    rows[[length(rows) + 1L]] <- scan_row(
      item$check,
      if (ok) "passed" else "failed",
      observed = if (ok) "found" else "missing",
      scanner = "pdftotext",
      detail = paste(item$anchor, "=>", item$snippet)
    )
  }

  global_forbidden_checks <- list(
    list(
      check = "no_embedded_missingness_strings",
      snippet = "missing (",
      detail = "Validation PDF should not include embedded missingness denominators in table cells."
    ),
    list(
      check = "no_noncanonical_table_2a",
      snippet = "Table 2a. Crude outcomes by CO2 category",
      detail = "Validation PDF should suppress exploratory crude CO2-category outcome tables."
    ),
    list(
      check = "no_diagnostics_heading",
      snippet = "Diagnostics and Exports",
      detail = "QA/QC diagnostics headings should be hidden from the manuscript-facing PDF."
    ),
    list(
      check = "no_validation_build_summary_heading",
      snippet = "Validation build summary",
      detail = "Validation build summary should be a side-effect artifact, not a manuscript-facing PDF heading."
    ),
    list(
      check = "no_diagnostics_audit_summary_heading",
      snippet = "Diagnostics audit summary",
      detail = "Diagnostics audit summary should be hidden from the manuscript-facing PDF."
    ),
    list(
      check = "no_artifact_provenance_summary_heading",
      snippet = "Artifact provenance summary",
      detail = "Artifact provenance summary should be hidden from the manuscript-facing PDF."
    ),
    list(
      check = "no_publication_quality_asset_audit_heading",
      snippet = "Publication-quality asset audit",
      detail = "Publication-quality asset audit should be a CSV artifact, not a manuscript-facing PDF heading."
    ),
    list(
      check = "no_internal_abg_residual_note",
      snippet = "ABG residual imbalance",
      detail = "Internal future-work notes should be side-effect artifacts, not manuscript-facing PDF text."
    ),
    list(
      check = "no_internal_separation_todo_note",
      snippet = "separation/nonconvergence",
      detail = "Internal future-work notes should be side-effect artifacts, not manuscript-facing PDF text."
    ),
	    list(
	      check = "no_internal_discontinuity_todo_note",
	      snippet = "possible discontinuity",
	      detail = "Internal future-work notes should be side-effect artifacts, not manuscript-facing PDF text."
	    ),
	    list(
	      check = "no_prognostic_likelihood_ratio_wording",
	      snippet = "prognostic likelihood ratio",
	      detail = "Manuscript-facing PDF should use plain likelihood-ratio wording."
	    ),
	    list(
	      check = "no_prognostic_lr_wording",
	      snippet = "prognostic lr",
	      detail = "Manuscript-facing PDF should use plain LR wording."
	    ),
	    list(
	      check = "no_model_based_likelihood_ratio_wording",
	      snippet = "model-based likelihood ratio",
	      detail = "Manuscript-facing PDF should use plain likelihood-ratio wording."
	    ),
	    list(
	      check = "no_not_diagnostic_likelihood_ratio_wording",
	      snippet = "not diagnostic likelihood ratio",
	      detail = "Manuscript-facing PDF should use plain likelihood-ratio wording."
	    ),
    list(
      check = "no_discordance_diagnostics_heading",
      snippet = "Analysis of the discordance between predicted probabilities and OR for NIV and IMV",
      detail = "Discordance diagnostics should remain side-effect artifacts, not manuscript-facing PDF sections."
    )
  )
  pdf_text_lower <- tolower(pdf_text)
  for (item in global_forbidden_checks) {
    ok <- !grepl(tolower(item$snippet), pdf_text_lower, fixed = TRUE)
    rows[[length(rows) + 1L]] <- scan_row(
      item$check,
      if (ok) "passed" else "failed",
      observed = if (ok) "absent" else item$snippet,
      scanner = "pdftotext",
      detail = item$detail
    )
  }

  forbidden_window_checks <- list(
    list(
      check = "table_1_no_internal_columns",
      anchor = "Table 1. Baseline characteristics",
      snippets = c("var_type", "row_type", "run_id", "run_ts", "missing (")
    ),
    list(
      check = "table_2_no_split_parts",
      anchor = "Table 2. MI-pooled, MI-logistic IPSW-weighted 3-level categorical results",
      snippets = c("(Part A)", "(Part B)", "Part A", "Part B")
    ),
    list(
      check = "table_s2_no_split_parts",
      anchor = "Table S2. Crude associations",
      snippets = c("(Part A)", "(Part B)", "Part A", "Part B")
    ),
    list(
      check = "table_s3_no_split_parts",
      anchor = "Table S3. GBM IPSW-weighted associations",
      snippets = c("(Part A)", "(Part B)", "Part A", "Part B")
    )
  )
  for (item in forbidden_window_checks) {
    window <- last_window(pdf_text, item$anchor)
    present <- if (nzchar(window)) {
      item$snippets[vapply(item$snippets, grepl, logical(1L), x = window, fixed = TRUE)]
    } else {
      item$snippets
    }
    ok <- nzchar(window) && !length(present)
    rows[[length(rows) + 1L]] <- scan_row(
      item$check,
      if (ok) "passed" else "failed",
      observed = if (ok) "absent" else paste(present, collapse = ", "),
      scanner = "pdftotext",
      detail = paste0("Forbidden table-layout/internal text near ", item$anchor)
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
