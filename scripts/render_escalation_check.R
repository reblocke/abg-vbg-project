#!/usr/bin/env Rscript

parse_args <- function(args) {
  out <- list(
    target = NA_character_,
    qmd = "Code Drafts/ABG-VBG-analysis.qmd",
    render_ts = NA_character_,
    results_dir = "Results",
    status = "unknown"
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

read_csv_if_exists <- function(path) {
  if (!file.exists(path)) return(data.frame())
  tryCatch(
    utils::read.csv(path, stringsAsFactors = FALSE, na.strings = c("", "NA")),
    error = function(e) data.frame()
  )
}

read_lines_if_exists <- function(path) {
  if (!file.exists(path)) return(character())
  readLines(path, warn = FALSE)
}

latest_file <- function(pattern, dir) {
  files <- list.files(dir, pattern = pattern, full.names = TRUE)
  if (!length(files)) return(NA_character_)
  files[which.max(file.info(files)$mtime)]
}

disk_free_gb <- function(path = ".") {
  out <- tryCatch(system2("df", c("-k", path), stdout = TRUE, stderr = FALSE), error = function(e) character())
  if (length(out) < 2L) return(NA_real_)
  fields <- strsplit(trimws(out[[2L]]), "\\s+")[[1L]]
  if (length(fields) < 4L) return(NA_real_)
  suppressWarnings(as.numeric(fields[[4L]]) / 1024^2)
}

physical_ram_gb <- function() {
  sys_name <- Sys.info()[["sysname"]]
  if (identical(sys_name, "Darwin")) {
    out <- tryCatch(system2("sysctl", c("-n", "hw.memsize"), stdout = TRUE, stderr = FALSE), error = function(e) character())
    ram_bytes <- suppressWarnings(as.numeric(out[[1L]]))
    if (is.finite(ram_bytes)) return(ram_bytes / 1024^3)
  }
  meminfo <- "/proc/meminfo"
  if (file.exists(meminfo)) {
    first <- readLines(meminfo, n = 1L, warn = FALSE)
    ram_kb <- suppressWarnings(as.numeric(gsub("[^0-9]", "", first)))
    if (is.finite(ram_kb)) return(ram_kb / 1024^2)
  }
  NA_real_
}

target_to_fraction <- function(target) {
  target <- tolower(trimws(target))
  if (target %in% c("full", "1", "1.0", "100", "100%")) return(1)
  target <- sub("%$", "", target)
  val <- suppressWarnings(as.numeric(target))
  if (!is.finite(val)) return(NA_real_)
  if (val > 1) val <- val / 100
  val
}

target_label <- function(frac) {
  if (!is.finite(frac)) return("unknown")
  if (frac >= 1) return("full")
  paste0(format(frac * 100, trim = TRUE, scientific = FALSE), "pct")
}

next_target <- function(frac, status, peak_rss_gb, disk_after_gb,
                        elapsed_minutes, blocking_failures) {
  if (!identical(status, "pass") || blocking_failures > 0L) return("repeat_or_optimize_current")
  if (!is.finite(frac) || frac <= 0) return("0.05")
  if (!is.finite(peak_rss_gb) || !is.finite(disk_after_gb)) return("repeat_current_with_resource_check")
  if (disk_after_gb < 20) return("cleanup_disk_before_next")
  if (peak_rss_gb > 12) return("optimize_or_use_larger_memory_before_next")

  if (frac < 0.05) return("0.05")
  if (frac < 0.10) {
    if (peak_rss_gb < 6 && (!is.finite(elapsed_minutes) || elapsed_minutes < 90)) return("0.25")
    return("0.10")
  }
  if (frac < 0.25) {
    if (peak_rss_gb < 8 && (!is.finite(elapsed_minutes) || elapsed_minutes < 150)) return("0.25")
    return("repeat_or_optimize_current")
  }
  if (frac < 0.50) {
    if (peak_rss_gb < 10) return("0.50")
    return("optimize_or_use_larger_memory_before_next")
  }
  if (frac < 1) {
    if (peak_rss_gb < 12 && disk_after_gb >= 25) return("full")
    return("optimize_or_use_larger_memory_before_full")
  }
  "complete"
}

max_rss_gb_from_trace <- function(path) {
  trace <- read_csv_if_exists(path)
  if (!nrow(trace) || !"rss_kb" %in% names(trace)) return(NA_real_)
  max(trace$rss_kb, na.rm = TRUE) / 1024^2
}

max_rss_gb_from_time_log <- function(path) {
  txt <- read_lines_if_exists(path)
  line <- grep("maximum resident set size", txt, value = TRUE)
  if (!length(line)) return(NA_real_)
  last <- tail(line, 1L)
  fields <- strsplit(trimws(last), "\\s+")[[1L]]
  val <- suppressWarnings(as.numeric(fields[[1L]]))
  if (!is.finite(val)) return(NA_real_)
  val / 1024^3
}

elapsed_minutes_from_log <- function(path) {
  txt <- read_lines_if_exists(path)
  line <- grep(" real ", txt, value = TRUE)
  if (!length(line)) return(NA_real_)
  last <- tail(line, 1L)
  val <- suppressWarnings(as.numeric(strsplit(trimws(last), "\\s+")[[1L]][[1L]]))
  if (!is.finite(val)) return(NA_real_)
  val / 60
}

validation_failures <- function(results_dir) {
  checks <- list(
    pdf_labels = list(path = file.path(results_dir, "pdf_parse_table_figure_check.csv"), col = "status", bad = c("FAIL", "WARN")),
    stacked_ror = list(path = file.path(results_dir, "stacked_ror_validation_status.csv"), col = "status", bad = c("FAIL", "WARN")),
    risk_difference = list(path = file.path(results_dir, "risk_difference_validation_status.csv"), col = "status", bad = c("FAIL", "WARN")),
    likelihood_ratio = list(path = file.path(results_dir, "baseline_relative_predicted_odds_validation_status.csv"), col = "status", bad = c("FAIL", "WARN")),
    outcome_rate_reference_risk = list(path = file.path(results_dir, "outcome_rate_reference_risk_audit.csv"), col = "status", bad = c("FAIL")),
    table_visual = list(path = file.path(results_dir, "table_visual_qc.csv"), col = "status", bad = c("FAIL")),
    publication_quality = list(path = file.path(results_dir, "publication_quality_asset_audit.csv"), col = "severity", bad = c("Fatal", "Major")),
    table2_validation = list(path = file.path(results_dir, "stacked_ror_vs_table2_validation.csv"), col = "validation_status", bad = c("FAIL", "WARN"))
  )

  out <- lapply(names(checks), function(name) {
    spec <- checks[[name]]
    df <- read_csv_if_exists(spec$path)
    if (!nrow(df) || !spec$col %in% names(df)) {
      return(data.frame(check = name, rows = nrow(df), bad_n = NA_integer_, status = "MISSING"))
    }
    bad_n <- sum(df[[spec$col]] %in% spec$bad, na.rm = TRUE)
    data.frame(check = name, rows = nrow(df), bad_n = bad_n, status = if (bad_n == 0L) "PASS" else "FAIL")
  })
  do.call(rbind, out)
}

args <- parse_args(commandArgs(trailingOnly = TRUE))
results_dir <- normalizePath(args$results_dir, winslash = "/", mustWork = TRUE)
log_dir <- file.path(results_dir, "render_logs")
render_ts <- args$render_ts
if (is.na(render_ts) || !nzchar(render_ts)) {
  latest_log <- latest_file("^render_[0-9]{8}_[0-9]{6}\\.log$", log_dir)
  render_ts <- sub("^render_|\\.log$", "", basename(latest_log))
}

log_path <- file.path(log_dir, paste0("render_", render_ts, ".log"))
rss_path <- file.path(log_dir, paste0("rss_trace_", render_ts, ".csv"))
mi_status_path <- file.path(results_dir, paste0("mi_run_status_", render_ts, ".json"))
run_config <- read_lines_if_exists(file.path(results_dir, "run_config.json"))
wrapper_status <- if (length(read_lines_if_exists(mi_status_path))) {
  status_text <- paste(read_lines_if_exists(mi_status_path), collapse = "\n")
  if (grepl('"wrapper_status"\\s*:\\s*0', status_text)) 0L else 1L
} else {
  NA_integer_
}

target_fraction <- target_to_fraction(args$target)
validation <- validation_failures(results_dir)
blocking_failures <- sum(validation$status %in% c("FAIL", "MISSING"), na.rm = TRUE)
peak_rss_time_gb <- max_rss_gb_from_time_log(log_path)
peak_rss_trace_gb <- max_rss_gb_from_trace(rss_path)
peak_rss_gb <- if (is.finite(peak_rss_time_gb)) peak_rss_time_gb else peak_rss_trace_gb
peak_rss_source <- if (is.finite(peak_rss_time_gb)) "time_log" else "rss_trace"
elapsed_minutes <- elapsed_minutes_from_log(log_path)
disk_after <- disk_free_gb(".")
ram_total <- physical_ram_gb()
render_status <- if (identical(args$status, "pass") || identical(wrapper_status, 0L)) "pass" else "fail"
recommendation <- next_target(target_fraction, render_status, peak_rss_gb, disk_after, elapsed_minutes, blocking_failures)

status_row <- data.frame(
  checked_at = as.character(Sys.time()),
  render_ts = render_ts,
  target = args$target,
  target_fraction = target_fraction,
  target_label = target_label(target_fraction),
  render_status = render_status,
  wrapper_status = wrapper_status,
  blocking_failures = blocking_failures,
  peak_rss_gb = round(peak_rss_gb, 3),
  peak_rss_source = peak_rss_source,
  elapsed_minutes = round(elapsed_minutes, 2),
  disk_free_gb_after = round(disk_after, 2),
  physical_ram_gb = round(ram_total, 2),
  next_recommendation = recommendation,
  qmd = args$qmd,
  log_path = log_path,
  rss_trace_path = rss_path,
  stringsAsFactors = FALSE
)

status_path <- file.path(results_dir, "render_escalation_status.csv")
old_status <- read_csv_if_exists(status_path)
missing_old <- setdiff(names(status_row), names(old_status))
for (nm in missing_old) old_status[[nm]] <- NA_character_
missing_new <- setdiff(names(old_status), names(status_row))
for (nm in missing_new) status_row[[nm]] <- NA_character_
status_all <- rbind(old_status[, names(status_row), drop = FALSE], status_row)
utils::write.csv(status_all, status_path, row.names = FALSE, na = "")

validation_path <- file.path(results_dir, "render_escalation_validation_checks.csv")
validation$render_ts <- render_ts
validation$target <- args$target
utils::write.csv(validation, validation_path, row.names = FALSE, na = "")

md_path <- file.path(results_dir, "render_escalation_status.md")
lines <- c(
  "# Render Escalation Status",
  "",
  paste0("- Checked at: ", status_row$checked_at),
  paste0("- Render timestamp: `", render_ts, "`"),
  paste0("- Target: `", args$target, "`"),
  paste0("- Render status: `", render_status, "`"),
  paste0("- Blocking validation failures: `", blocking_failures, "`"),
  paste0("- Peak RSS: `", status_row$peak_rss_gb, " GiB` (source: `", status_row$peak_rss_source, "`)"),
  paste0("- Elapsed wrapper runtime: `", status_row$elapsed_minutes, " minutes`"),
  paste0("- Free disk after render: `", status_row$disk_free_gb_after, " GiB`"),
  paste0("- Physical RAM: `", status_row$physical_ram_gb, " GiB`"),
  paste0("- Next recommendation: `", recommendation, "`"),
  "",
  "## Validation Checks",
  "",
  paste(
    sprintf("- `%s`: `%s` (%s bad rows / %s rows)", validation$check, validation$status, validation$bad_n, validation$rows),
    collapse = "\n"
  )
)
writeLines(lines, md_path, useBytes = TRUE)

cat("render_ts=", render_ts, "\n", sep = "")
cat("render_status=", render_status, "\n", sep = "")
cat("blocking_failures=", blocking_failures, "\n", sep = "")
cat("peak_rss_gb=", round(peak_rss_gb, 3), "\n", sep = "")
cat("peak_rss_source=", peak_rss_source, "\n", sep = "")
cat("elapsed_minutes=", round(elapsed_minutes, 2), "\n", sep = "")
cat("disk_free_gb_after=", round(disk_after, 2), "\n", sep = "")
cat("next_recommendation=", recommendation, "\n", sep = "")

if (!identical(render_status, "pass") || blocking_failures > 0L) {
  quit(status = 1L)
}
