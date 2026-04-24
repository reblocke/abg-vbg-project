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

coalesce_logical <- function(x, fallback, n) {
  if (is.null(x)) return(rep(fallback, n))
  x <- as.logical(x)
  if (length(x) == 0L) return(rep(fallback, n))
  x[is.na(x)] <- fallback
  x
}

enrich_model_diag <- function(df, prob_eps = 1e-6) {
  if (is.null(df) || !nrow(df)) return(df)
  n <- nrow(df)
  if (!"top_warning" %in% names(df)) df$top_warning <- NA_character_
  if (!"min_phat" %in% names(df)) df$min_phat <- NA_real_
  if (!"max_phat" %in% names(df)) df$max_phat <- NA_real_
  if (!"converged" %in% names(df)) df$converged <- NA
  if (!"sep_flag" %in% names(df)) df$sep_flag <- FALSE
  if (!"nonconv_flag" %in% names(df)) df$nonconv_flag <- FALSE
  warn_chr <- as.character(df$top_warning)
  warn_chr[is.na(warn_chr)] <- ""
  phat_low_default <- is.finite(df$min_phat) & df$min_phat < prob_eps
  phat_high_default <- is.finite(df$max_phat) & df$max_phat > 1 - prob_eps
  sep_warn_default <- grepl("fitted probabilities numerically 0 or 1", warn_chr, fixed = TRUE) |
    grepl("separat", warn_chr, ignore.case = TRUE)
  nonconv_default <- coalesce_logical(df$nonconv_flag, FALSE, n) |
    coalesce_logical(!as.logical(df$converged), FALSE, n) |
    grepl("did not converge", warn_chr, fixed = TRUE)
  df$phat_low_flag <- if ("phat_low_flag" %in% names(df)) {
    coalesce_logical(df$phat_low_flag, FALSE, n) | phat_low_default
  } else {
    phat_low_default
  }
  df$phat_high_flag <- if ("phat_high_flag" %in% names(df)) {
    coalesce_logical(df$phat_high_flag, FALSE, n) | phat_high_default
  } else {
    phat_high_default
  }
  df$sep_warn_flag <- if ("sep_warn_flag" %in% names(df)) {
    coalesce_logical(df$sep_warn_flag, FALSE, n) | sep_warn_default
  } else {
    sep_warn_default
  }
  df$nonconv_flag <- nonconv_default
  df$central_plot_instability_flag <- if ("central_plot_instability_flag" %in% names(df)) {
    coalesce_logical(df$central_plot_instability_flag, FALSE, n)
  } else {
    rep(FALSE, n)
  }
  df$sep_flag <- coalesce_logical(df$sep_flag, FALSE, n) |
    df$phat_low_flag | df$phat_high_flag | df$sep_warn_flag
  df$diagnostic_class <- ifelse(
    df$nonconv_flag | df$sep_warn_flag | df$central_plot_instability_flag,
    "fail",
    ifelse(df$phat_low_flag | df$phat_high_flag | df$sep_flag, "warn", "pass")
  )
  df$diagnostic_status <- ifelse(
    df$diagnostic_class == "fail",
    "FAIL",
    ifelse(df$diagnostic_class == "warn", "PASS_WITH_WARNINGS", "PASS")
  )
  df
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

run_id_val <- if (!is.null(runtime_log) && "run_id" %in% names(runtime_log) && nrow(runtime_log) > 0) {
  as.character(runtime_log$run_id[[1]])
} else {
  format(Sys.time(), "%Y%m%d_%H%M%S")
}

run_ts_val <- if (!is.null(runtime_log) && "run_ts" %in% names(runtime_log) && nrow(runtime_log) > 0) {
  as.character(runtime_log$run_ts[[1]])
} else {
  as.character(Sys.time())
}

run_mode <- if (!is.null(runtime_log) && "run_mode" %in% names(runtime_log)) {
  paste(unique(runtime_log$run_mode), collapse = ", ")
} else {
  "NA"
}
is_pilot_mode <- grepl("pilot", run_mode, ignore.case = TRUE)

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
outcome_fail_total <- 0L
outcome_warn_total <- 0L
sep_by <- NULL
if (!is.null(model_diag)) {
  model_diag <- enrich_model_diag(model_diag)
  write.csv(model_diag, file.path(results_dir, "model_fit_diagnostics.csv"), row.names = FALSE)
  sep_total <- sum(model_diag$sep_flag, na.rm = TRUE)
  outcome_fail_total <- sum(model_diag$diagnostic_class == "fail", na.rm = TRUE)
  outcome_warn_total <- sum(model_diag$diagnostic_class == "warn", na.rm = TRUE)
  sep_by <- aggregate(sep_flag ~ analysis_variant + model_type + group + outcome,
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

if (any(!expected_tbl$present)) {
  missing_expected <- expected_tbl$artifact[!expected_tbl$present]
  add_issue(
    "medium",
    "Inventory",
    "Results/diagnostics_audit.md",
    paste0("Missing expected artifacts: ", paste(missing_expected, collapse = ", ")),
    "Missing diagnostics artifacts weaken validation coverage and can hide silent regressions.",
    "Regenerate the missing diagnostics artifacts or adjust the expected inventory if the contract changed intentionally."
  )
}

if (isTRUE(smoke_failed)) {
  add_issue(
    "high",
    "MI",
    "Results/mice_smoketest.log",
    "Smoke test failed",
    "A failed MI smoke test indicates the imputation path is unstable before full validation.",
    "Inspect the smoke-test log and fix the underlying MI execution error before relying on downstream pooled outputs."
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
  bal_severity <- if (isTRUE(is_pilot_mode)) "medium" else "high"
  add_issue(
    bal_severity,
    "Balance",
    "Results/balance_target_imp_summary.csv",
    paste0("ABG max|SMD|=", fmt_num(bal_max_abg)),
    if (identical(bal_severity, "high")) {
      "ABG target balance exceeds 0.10 threshold across imputations."
    } else {
      "ABG target balance exceeds 0.10 in a pilot/subset render; this is a validation warning, not a full-analysis failure."
    },
    if (identical(bal_severity, "high")) {
      "Revisit GBM tuning, covariate set, or truncation to improve ABG balance."
    } else {
      "Confirm balance on the larger validation subset or full render before changing the weighting model."
    }
  )
}

if (!is.na(bal_max_vbg) && bal_max_vbg > 0.10) {
  bal_severity <- if (isTRUE(is_pilot_mode)) "medium" else "high"
  add_issue(
    bal_severity,
    "Balance",
    "Results/balance_target_imp_summary.csv",
    paste0("VBG max|SMD|=", fmt_num(bal_max_vbg)),
    if (identical(bal_severity, "high")) {
      "VBG target balance exceeds 0.10 threshold across imputations."
    } else {
      "VBG target balance exceeds 0.10 in a pilot/subset render; this is a validation warning, not a full-analysis failure."
    },
    if (identical(bal_severity, "high")) {
      "Revisit GBM tuning, covariate set, or truncation to improve VBG balance."
    } else {
      "Confirm balance on the larger validation subset or full render before changing the weighting model."
    }
  )
}

if (!is.null(model_diag) && outcome_fail_total > 0) {
  add_issue(
    "high",
    "Outcome",
    "Results/model_fit_diagnostics.csv",
    paste0("diagnostic_class == fail for ", outcome_fail_total, " / ", nrow(model_diag), " fits"),
    "Nonconvergence, explicit separation warnings, or central-plot instability can invalidate manuscript-critical estimates.",
    "Inspect failed diagnostic rows and fix the affected model path before relying on the manuscript-facing display."
  )
}

if (!is.null(model_diag) && outcome_fail_total == 0 && outcome_warn_total > 0) {
  add_issue(
    "medium",
    "Outcome",
    "Results/model_fit_diagnostics.csv",
    paste0("tail/off-profile fitted-probability warnings for ", outcome_warn_total, " / ", nrow(model_diag), " fits"),
    "Tail-only fitted-probability extremes require transparent reporting but do not by themselves invalidate manuscript-facing plots.",
    "Keep the warning in the diagnostics summary and reassess if any flagged row affects the displayed central curve range."
  )
}

fit_issue_sep_col <- if (!is.null(fit_issue)) {
  intersect(c("n_sep_flag", "sep_n"), names(fit_issue))
} else {
  character()
}
if (!is.null(model_diag) && !is.null(fit_issue) && length(fit_issue_sep_col) &&
    sum(fit_issue[[fit_issue_sep_col[[1]]]], na.rm = TRUE) == 0 && sep_total > 0) {
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

severity_rank <- c(high = 3L, medium = 2L, low = 1L)
overall_status <- if (nrow(issues_df) && any(issues_df$severity == "high")) {
  "FAIL"
} else if (nrow(issues_df) && any(issues_df$severity %in% c("medium", "low"))) {
  "PASS_WITH_WARNINGS"
} else {
  "PASS"
}

add_summary_row <- function(component, metric, value, status, severity = "none",
                            evidence_file = "", note = "") {
  data.frame(
    component = component,
    metric = metric,
    value = as.character(value),
    status = status,
    severity = severity,
    evidence_file = evidence_file,
    note = note,
    stringsAsFactors = FALSE
  )
}

expected_missing_n <- sum(!expected_tbl$present)

summary_rows <- list(
  add_summary_row(
    "Audit",
    "overall_status",
    overall_status,
    tolower(if (identical(overall_status, "PASS")) "pass" else if (identical(overall_status, "PASS_WITH_WARNINGS")) "warn" else "fail"),
    if (identical(overall_status, "FAIL")) "high" else if (identical(overall_status, "PASS_WITH_WARNINGS")) "medium" else "none",
    "Results/diagnostics_audit_issues.csv",
    "Overall diagnostics audit status derived from the highest-severity unresolved issue."
  ),
  add_summary_row(
    "Inventory",
    "expected_artifacts_missing",
    expected_missing_n,
    if (expected_missing_n > 0) "warn" else "pass",
    if (expected_missing_n > 0) "medium" else "none",
    "Results/diagnostics_audit.md",
    "Count of expected diagnostics artifacts missing from Results/."
  ),
  add_summary_row(
    "MI",
    "smoke_test_failed",
    smoke_failed,
    if (isTRUE(smoke_failed)) "fail" else "pass",
    if (isTRUE(smoke_failed)) "high" else "none",
    "Results/mice_smoketest.log",
    "Smoke test failure indicates the MI execution path is unstable."
  ),
  add_summary_row(
    "MI",
    "chain_diagnostics_issue",
    chain_issue,
    if (isTRUE(chain_issue)) "warn" else "pass",
    if (isTRUE(chain_issue)) "medium" else "none",
    "Results/mice_chain_diagnostics.csv",
    chain_issue_note
  ),
  add_summary_row(
    "Balance",
    "abg_max_abs_smd",
    fmt_num(bal_max_abg),
    if (is.finite(bal_max_abg) && bal_max_abg > 0.10 && !isTRUE(is_pilot_mode)) "fail" else
      if (is.finite(bal_max_abg) && bal_max_abg > 0.10) "warn" else "pass",
    if (is.finite(bal_max_abg) && bal_max_abg > 0.10 && !isTRUE(is_pilot_mode)) "high" else
      if (is.finite(bal_max_abg) && bal_max_abg > 0.10) "medium" else "none",
    "Results/balance_target_imp_summary.csv",
    "ABG target balance threshold is 0.10; pilot/subset threshold misses are validation warnings."
  ),
  add_summary_row(
    "Balance",
    "vbg_max_abs_smd",
    fmt_num(bal_max_vbg),
    if (is.finite(bal_max_vbg) && bal_max_vbg > 0.10 && !isTRUE(is_pilot_mode)) "fail" else
      if (is.finite(bal_max_vbg) && bal_max_vbg > 0.10) "warn" else "pass",
    if (is.finite(bal_max_vbg) && bal_max_vbg > 0.10 && !isTRUE(is_pilot_mode)) "high" else
      if (is.finite(bal_max_vbg) && bal_max_vbg > 0.10) "medium" else "none",
    "Results/balance_target_imp_summary.csv",
    "VBG target balance threshold is 0.10; pilot/subset threshold misses are validation warnings."
  ),
  add_summary_row(
    "Outcome",
    "separation_flags_total",
    sep_total,
    if (outcome_fail_total > 0) "fail" else if (sep_total > 0) "warn" else "pass",
    if (outcome_fail_total > 0) "high" else if (sep_total > 0) "medium" else "none",
    "Results/model_fit_diagnostics.csv",
    "Broad legacy count of separation/extreme-probability flags; tail-only fitted-probability flags are warnings unless manuscript-facing curves are affected."
  ),
  add_summary_row(
    "Outcome",
    "diagnostic_failures_total",
    outcome_fail_total,
    if (outcome_fail_total > 0) "fail" else "pass",
    if (outcome_fail_total > 0) "high" else "none",
    "Results/model_fit_diagnostics.csv",
    "Failure count after splitting nonconvergence, explicit separation warnings, and central plotted-curve instability from tail-only probability warnings."
  ),
  add_summary_row(
    "Outcome",
    "diagnostic_warnings_total",
    outcome_warn_total,
    if (outcome_warn_total > 0) "warn" else "pass",
    if (outcome_warn_total > 0) "medium" else "none",
    "Results/model_fit_diagnostics.csv",
    "Warning count for tail-only or off-profile fitted-probability flags."
  ),
  add_summary_row(
    "Plotting",
    "plot_drop_log_present",
    !is.null(plot_drop),
    if (!is.null(plot_drop)) "pass" else "warn",
    if (!is.null(plot_drop)) "none" else "low",
    "Results/plot_drop_log.csv",
    "Plot drop logging should exist even if no rows are present."
  )
)

summary_df <- do.call(rbind, summary_rows)

if (nrow(issues_df)) {
  issues_df$run_id <- rep(run_id_val, nrow(issues_df))
  issues_df$run_ts <- rep(run_ts_val, nrow(issues_df))
} else {
  issues_df$run_id <- character()
  issues_df$run_ts <- character()
}
summary_df$run_id <- run_id_val
summary_df$run_ts <- run_ts_val

write.csv(issues_df, file.path(results_dir, "diagnostics_audit_issues.csv"), row.names = FALSE)
write.csv(summary_df, file.path(results_dir, "diagnostics_audit_summary.csv"), row.names = FALSE)

# --- Markdown report ----------------------------------------------------------
lines <- c(
  "# Diagnostics Audit",
  "",
  "## Executive Summary",
  paste0("- Overall status: ", overall_status),
  paste0("- Run mode: ", run_mode, "; pilot_frac: ", pilot_frac, "; m: ", m_used, "; maxit: ", maxit_used),
  paste0("- Runtime total (sec): ", fmt_num(total_seconds)),
  paste0("- MI batch status: ", batch_note),
  paste0("- Balance: ", bal_note),
  paste0("- Outcome diagnostic failures: ", outcome_fail_total, " / ", if (!is.null(model_diag)) nrow(model_diag) else 0),
  paste0("- Outcome diagnostic warnings: ", outcome_warn_total, " / ", if (!is.null(model_diag)) nrow(model_diag) else 0),
  paste0("- Legacy separation/extreme-probability flags: ", sep_total, " / ", if (!is.null(model_diag)) nrow(model_diag) else 0),
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
  lines <- c(lines, "Top separation/extreme-probability counts (analysis_variant/model_type/group/outcome):")
  top_sep <- head(sep_by, 6)
  sep_lines <- apply(top_sep, 1, function(r) {
    paste0("- ", r[["analysis_variant"]], " / ", r[["model_type"]], " / ",
           r[["group"]], " / ", r[["outcome"]], ": ", r[["sep_flag"]])
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
