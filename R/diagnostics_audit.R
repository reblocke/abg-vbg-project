#!/usr/bin/env Rscript

results_dir <- Sys.getenv("DIAG_RESULTS_DIR", "Results")

safe_read_csv <- function(path) {
  if (file.exists(path)) {
    return(read.csv(path, stringsAsFactors = FALSE))
  }
  NULL
}

safe_read_lines <- function(path) {
  if (file.exists(path)) readLines(path) else character()
}

fmt_num <- function(x, digits = 3) {
  if (length(x) == 0L || all(!is.finite(x))) return("NA")
  formatC(x, format = "f", digits = digits)
}

write_md <- function(lines, path) {
  writeLines(lines, con = path)
}

dir.create(file.path(results_dir, "diagnostics_audit_snippets"), showWarnings = FALSE)

# --- Inventory ---------------------------------------------------------------
all_files <- list.files(results_dir, recursive = TRUE, full.names = TRUE)
all_files <- all_files[!grepl("/cache/", all_files)]
fi <- file.info(all_files)
inventory <- data.frame(
  path = all_files,
  size_bytes = fi$size,
  mtime = fi$mtime,
  stringsAsFactors = FALSE
)

expected <- c(
  "runtime_log.csv",
  "runtime_summary.csv",
  "runtime_summary_top15.csv",
  "warnings_log.csv",
  "mi_warnings_log.csv",
  "mice_smoketest.log",
  "mice_batches_log.csv",
  "mice_chain_diagnostics.csv",
  "mice_pred_width_preflight.csv",
  "mice_logged_events_raw.csv",
  "mice_logged_events_summary.csv",
  "mice_spec.rds",
  "mi_outcome_fit_diagnostics.csv",
  "model_fit_diagnostics.csv",
  "mi_spline_curve_abg.csv",
  "mi_spline_curve_vbg.csv",
  "balance_target_imp_summary.csv",
  "balance_max_smd_by_imp.csv",
  "weight_summary.csv",
  "ps_overlap_summary.csv",
  "diagnostics_summary.csv",
  "plot_drop_log.csv"
)

exists_expected <- file.exists(file.path(results_dir, expected))
expected_tbl <- data.frame(
  artifact = expected,
  present = exists_expected,
  stringsAsFactors = FALSE
)

# --- Run configuration -------------------------------------------------------
diag_sum <- safe_read_csv(file.path(results_dir, "diagnostics_summary.csv"))
runtime_log <- safe_read_csv(file.path(results_dir, "runtime_log.csv"))

run_mode <- if (!is.null(runtime_log) && "run_mode" %in% names(runtime_log)) {
  paste(unique(runtime_log$run_mode), collapse = ", ")
} else {
  "NA"
}

pilot_frac <- if (!is.null(diag_sum) && "pilot_frac" %in% names(diag_sum)) {
  paste(unique(diag_sum$pilot_frac), collapse = ", ")
} else {
  "NA"
}

m_used <- if (!is.null(diag_sum) && "m" %in% names(diag_sum)) {
  paste(unique(diag_sum$m), collapse = ", ")
} else {
  "NA"
}

maxit_used <- if (!is.null(diag_sum) && "maxit" %in% names(diag_sum)) {
  paste(unique(diag_sum$maxit), collapse = ", ")
} else {
  "NA"
}

# --- Runtime -----------------------------------------------------------------
runtime_top <- NULL
total_seconds <- NA_real_
if (!is.null(runtime_log)) {
  total_seconds <- sum(runtime_log$seconds, na.rm = TRUE)
  runtime_top <- runtime_log[order(-runtime_log$seconds), , drop = FALSE]
  runtime_top <- head(runtime_top, 10)
}

# --- MI health ---------------------------------------------------------------
smoke_lines <- safe_read_lines(file.path(results_dir, "mice_smoketest.log"))
smoke_failed <- any(grepl("Smoke test failed", smoke_lines, fixed = TRUE))

batches <- safe_read_csv(file.path(results_dir, "mice_batches_log.csv"))
batch_note <- "NA"
batch_m_unique <- NULL
gc_limit_bad <- FALSE
if (!is.null(batches)) {
  if ("m_batch" %in% names(batches)) {
    batch_m_unique <- sort(unique(batches$m_batch))
  }
  ok_vals <- NULL
  if ("ok" %in% names(batches)) {
    ok_vals <- batches$ok
    if (is.character(ok_vals)) ok_vals <- as.logical(ok_vals)
    if (is.factor(ok_vals)) ok_vals <- as.logical(as.character(ok_vals))
  }
  fail_n <- if (!is.null(ok_vals)) sum(!ok_vals, na.rm = TRUE) else NA_integer_
  batch_note <- paste0("batches=", nrow(batches),
                       "; m_batch=", if (!is.null(batch_m_unique)) paste(batch_m_unique, collapse = ", ") else "NA",
                       "; failures=", if (!is.na(fail_n)) fail_n else "NA")

  limit_col <- NULL
  for (cand in c("vcells_limit_mb_post", "vcells_limit_mb_pre", "vcells_limit_mb", "gc_vcells_limit_mb")) {
    if (cand %in% names(batches)) {
      limit_col <- cand
      break
    }
  }
  if (!is.null(limit_col)) {
    lim <- batches[[limit_col]]
    lim <- as.numeric(lim)
    gc_limit_bad <- all(is.finite(lim)) && max(lim, na.rm = TRUE) < 1
  }
}

chain_diag <- safe_read_csv(file.path(results_dir, "mice_chain_diagnostics.csv"))
chain_issue <- FALSE
chain_issue_note <- "NA"
if (!is.null(chain_diag)) {
  if ("empty" %in% names(chain_diag) || !"variable" %in% names(chain_diag)) {
    chain_issue <- TRUE
    chain_issue_note <- "chain diagnostics empty or missing columns"
  } else {
    all_numeric_names <- all(grepl("^\\d+$", chain_diag$variable))
    eligible <- rep(TRUE, nrow(chain_diag))
    if ("method" %in% names(chain_diag)) {
      eligible <- eligible & chain_diag$method != ""
    }
    if ("diagnostic_available" %in% names(chain_diag)) {
      eligible <- eligible & (chain_diag$diagnostic_available %in% TRUE)
    }
    drift_tail_na <- if (any(eligible)) mean(is.na(chain_diag$drift_tail[eligible])) else NA_real_
    drift_tail_any <- if (any(eligible)) sum(is.finite(chain_diag$drift_tail[eligible])) else 0
    chain_issue <- all_numeric_names ||
      (is.finite(drift_tail_na) && drift_tail_na > 0.20) ||
      (any(eligible) && drift_tail_any == 0)
    chain_issue_note <- paste0("numeric_names=", all_numeric_names,
                               "; drift_tail_na_frac=", fmt_num(drift_tail_na))
  }
}

pred_width <- safe_read_csv(file.path(results_dir, "mice_pred_width_preflight.csv"))
max_mm_cols <- NA_real_
if (!is.null(pred_width) && "mm_cols" %in% names(pred_width)) {
  max_mm_cols <- max(pred_width$mm_cols, na.rm = TRUE)
}

mi_warn <- safe_read_csv(file.path(results_dir, "mi_warnings_log.csv"))
mi_warn_note <- "NA"
if (!is.null(mi_warn)) {
  mi_warn_note <- paste0("warnings=", nrow(mi_warn))
}

# --- Balance -----------------------------------------------------------------
bal_imp <- safe_read_csv(file.path(results_dir, "balance_target_imp_summary.csv"))
bal_note <- "NA"
bal_max_abg <- NA_real_
bal_max_vbg <- NA_real_
if (!is.null(bal_imp) && all(c("group", "max_abs_post") %in% names(bal_imp))) {
  bal_max_abg <- max(bal_imp$max_abs_post[bal_imp$group == "ABG"], na.rm = TRUE)
  bal_max_vbg <- max(bal_imp$max_abs_post[bal_imp$group == "VBG"], na.rm = TRUE)
  bal_note <- paste0("ABG max|SMD|=", fmt_num(bal_max_abg),
                     "; VBG max|SMD|=", fmt_num(bal_max_vbg))
}

# --- Outcome fits -------------------------------------------------------------
model_diag <- safe_read_csv(file.path(results_dir, "model_fit_diagnostics.csv"))
sep_total <- 0L
sep_by <- NULL
if (!is.null(model_diag) && "sep_flag" %in% names(model_diag)) {
  model_diag$sep_flag <- as.logical(model_diag$sep_flag)
  sep_total <- sum(model_diag$sep_flag, na.rm = TRUE)
  sep_by <- aggregate(sep_flag ~ analysis_variant + group + outcome,
                      data = model_diag, FUN = sum)
  sep_by <- sep_by[order(-sep_by$sep_flag), , drop = FALSE]
}

fit_issue <- safe_read_csv(file.path(results_dir, "mi_fit_issue_summary.csv"))

# --- Plot integrity -----------------------------------------------------------
plot_drop <- safe_read_csv(file.path(results_dir, "plot_drop_log.csv"))

# --- Issues list --------------------------------------------------------------
issues <- list()

add_issue <- function(severity, component, file, snippet, why, fix) {
  issues[[length(issues) + 1L]] <<- data.frame(
    severity = severity,
    component = component,
    evidence_file = file,
    evidence_snippet = snippet,
    why_it_matters = why,
    recommended_fix = fix,
    stringsAsFactors = FALSE
  )
}

if (!exists_expected[match("mice_logged_events_summary.csv", expected)]) {
  add_issue(
    "medium",
    "MI",
    "Results/mice_logged_events_summary.csv",
    "Missing file",
    "Logged-events summary is absent; cannot verify MICE stability drivers.",
    "Ensure loggedEvents summary is written even when empty (write a 0-row CSV)."
  )
}

if (chain_issue) {
  add_issue(
    "medium",
    "MI",
    "Results/mice_chain_diagnostics.csv",
    chain_issue_note,
    "Chain diagnostics appear incomplete (numeric variable names and/or drift_tail all NA).",
    "Check chainMean/chainVar dimension names and skip variables with insufficient finite iterations."
  )
}

if (gc_limit_bad) {
  add_issue(
    "low",
    "MI",
    "Results/mice_batches_log.csv",
    "gc_vcells_limit_mb < 1 MB",
    "Vcells limit appears mis-scaled; memory pressure fraction may be invalid.",
    "Verify mem.maxVSize units and logging conversion in get_vcells_stats()."
  )
}

if (!is.na(bal_max_abg) && bal_max_abg > 0.10) {
  add_issue(
    "high",
    "Balance",
    "Results/balance_target_imp_summary.csv",
    paste0("ABG max|SMD|=", fmt_num(bal_max_abg)),
    "ABG target balance exceeds 0.10 threshold across imputations.",
    "Revisit GBM tuning, covariate set, or truncation to improve ABG balance."
  )
}

if (!is.null(model_diag) && sep_total > 0) {
  add_issue(
    "high",
    "Outcome",
    "Results/model_fit_diagnostics.csv",
    paste0("sep_flag TRUE for ", sep_total, " / ", nrow(model_diag), " fits"),
    "High rate of separation/near-separation can bias ORs and CIs.",
    "Inspect flagged outcomes; consider penalized fits or check data sparsity."
  )
}

if (!is.null(model_diag) && !is.null(fit_issue) && any(fit_issue$sep_n == 0) && sep_total > 0) {
  add_issue(
    "high",
    "Outcome",
    "Results/mi_fit_issue_summary.csv",
    "sep_n = 0 while model_fit_diagnostics has sep_flag TRUE",
    "Summary contradicts diagnostics; downstream interpretation may be wrong.",
    "Regenerate mi_fit_issue_summary from model_fit_diagnostics or align logic."
  )
}

if (is.null(plot_drop)) {
  add_issue(
    "low",
    "Plotting",
    "Results/plot_drop_log.csv",
    "Missing file",
    "Plot drop logging not available; harder to diagnose dropped OR rows.",
    "Write plot_drop_log.csv even if empty to confirm plotting integrity."
  )
}

issues_df <- if (length(issues)) do.call(rbind, issues) else {
  data.frame(
    severity = character(), component = character(), evidence_file = character(),
    evidence_snippet = character(), why_it_matters = character(), recommended_fix = character(),
    stringsAsFactors = FALSE
  )
}

write.csv(issues_df, file.path(results_dir, "diagnostics_audit_issues.csv"), row.names = FALSE)

# --- Markdown report ----------------------------------------------------------
lines <- c(
  "# Diagnostics Audit",
  "",
  "## Executive Summary",
  paste0("- Run mode: ", run_mode, "; pilot_frac: ", pilot_frac, "; m: ", m_used, "; maxit: ", maxit_used),
  paste0("- Runtime total (sec): ", fmt_num(total_seconds)),
  paste0("- MI batch status: ", batch_note),
  paste0("- Balance: ", bal_note),
  paste0("- Separation flags: ", sep_total, " / ", if (!is.null(model_diag)) nrow(model_diag) else 0),
  "",
  "## Artifact Inventory (Found / Missing)",
  ""
)

inv_lines <- vapply(seq_len(nrow(expected_tbl)), function(i) {
  paste0("- ", expected_tbl$artifact[i], ": ",
         if (isTRUE(expected_tbl$present[i])) "present" else "missing")
}, character(1))
lines <- c(lines, inv_lines, "", "## Runtime Top Steps", "")

if (!is.null(runtime_top)) {
  rt_lines <- vapply(seq_len(nrow(runtime_top)), function(i) {
    paste0("- ", runtime_top$step_name[i], ": ",
           fmt_num(runtime_top$seconds[i]), " sec")
  }, character(1))
  lines <- c(lines, rt_lines)
} else {
  lines <- c(lines, "- runtime_log.csv not found")
}

lines <- c(lines, "", "## MI Health", "")
lines <- c(lines,
           paste0("- Smoke test failed: ", smoke_failed),
           paste0("- Predictor width max mm_cols: ", fmt_num(max_mm_cols)),
           paste0("- Chain diagnostics issue: ", chain_issue, " (", chain_issue_note, ")"))

if (!is.null(mi_warn)) {
  lines <- c(lines, paste0("- MI warnings rows: ", nrow(mi_warn)))
}

lines <- c(lines, "", "## Balance", "")
lines <- c(lines, paste0("- ABG max |SMD|: ", fmt_num(bal_max_abg)),
           paste0("- VBG max |SMD|: ", fmt_num(bal_max_vbg)))

lines <- c(lines, "", "## Outcome Fits", "")
if (!is.null(sep_by) && nrow(sep_by)) {
  lines <- c(lines, "Top separation counts (analysis_variant/group/outcome):")
  top_sep <- head(sep_by, 6)
  sep_lines <- apply(top_sep, 1, function(r) {
    paste0("- ", r[["analysis_variant"]], " / ", r[["group"]], " / ",
           r[["outcome"]], ": ", r[["sep_flag"]])
  })
  lines <- c(lines, sep_lines)
} else {
  lines <- c(lines, "- No model_fit_diagnostics.csv found")
}

lines <- c(lines, "", "## Issues (prioritized)", "")
if (nrow(issues_df) == 0L) {
  lines <- c(lines, "- No issues detected.")
} else {
  issue_lines <- vapply(seq_len(nrow(issues_df)), function(i) {
    paste0("- [", issues_df$severity[i], "] ", issues_df$component[i], ": ",
           issues_df$evidence_snippet[i], " (", issues_df$evidence_file[i], ")")
  }, character(1))
  lines <- c(lines, issue_lines)
}

write_md(lines, file.path(results_dir, "diagnostics_audit.md"))
