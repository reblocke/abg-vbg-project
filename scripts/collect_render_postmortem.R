#!/usr/bin/env Rscript

parse_args <- function(args) {
  out <- list(
    render_ts = NA_character_,
    results_dir = NA_character_,
    log_path = NA_character_,
    pdf_path = NA_character_,
    wrapper_status = NA_real_,
    postflight_passed = NA
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
  required <- c("render_ts", "results_dir", "log_path", "pdf_path")
  missing <- required[!nzchar(unlist(out[required])) | is.na(unlist(out[required]))]
  if (length(missing)) {
    stop("Missing required arguments: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  out$wrapper_status <- suppressWarnings(as.numeric(out$wrapper_status))
  if (is.na(out$postflight_passed) || !nzchar(out$postflight_passed)) {
    out$postflight_passed <- NA
  } else {
    out$postflight_passed <- switch(
      tolower(out$postflight_passed),
      true = TRUE,
      false = FALSE,
      na = NA,
      stop("Invalid value for --postflight-passed: ", out$postflight_passed, call. = FALSE)
    )
  }
  out
}

json_escape <- function(x) {
  x <- gsub("\\\\", "\\\\\\\\", x)
  x <- gsub("\"", "\\\\\"", x)
  x <- gsub("\n", "\\\\n", x, fixed = TRUE)
  x <- gsub("\r", "\\\\r", x, fixed = TRUE)
  x <- gsub("\t", "\\\\t", x, fixed = TRUE)
  x
}

json_scalar <- function(x) {
  if (length(x) == 0L || is.null(x) || (length(x) == 1L && is.na(x))) return("null")
  if (is.logical(x)) return(ifelse(isTRUE(x), "true", "false"))
  if (is.numeric(x)) return(format(x, scientific = FALSE, trim = TRUE))
  paste0("\"", json_escape(as.character(x)), "\"")
}

write_json_object <- function(values, path) {
  keys <- names(values)
  lines <- vapply(keys, function(key) {
    paste0("  \"", json_escape(key), "\": ", json_scalar(values[[key]]))
  }, character(1))
  writeLines(c("{", paste(lines, collapse = ",\n"), "}"), path)
}

read_csv_safe <- function(path) {
  if (!file.exists(path)) return(data.frame())
  tryCatch(
    utils::read.csv(path, stringsAsFactors = FALSE),
    error = function(e) {
      out <- data.frame()
      attr(out, "read_error") <- conditionMessage(e)
      out
    }
  )
}

render_log_tail <- function(path, n = 40L) {
  if (!file.exists(path)) return(character())
  lines <- readLines(path, warn = FALSE)
  utils::tail(lines, n)
}

format_df_block <- function(df, n = 5L) {
  if (!nrow(df)) return("_none_")
  paste(
    c(
      "```text",
      capture.output(print(utils::tail(df, n), row.names = FALSE)),
      "```"
    ),
    collapse = "\n"
  )
}

parse_log_value <- function(lines, prefix) {
  hits <- grep(paste0("^", prefix), lines, value = TRUE)
  if (!length(hits)) return(NA_character_)
  sub(paste0("^", prefix), "", utils::tail(hits, 1L))
}

detect_live_render <- function(qmd_path = NA_character_) {
  ps_lines <- tryCatch(
    system2("ps", c("-Ao", "pid=,command="), stdout = TRUE, stderr = FALSE),
    error = function(e) character()
  )
  if (!length(ps_lines)) return(FALSE)
  relevant <- grepl("render_pdf\\.sh|quarto(\\.js)? render|/Applications/quarto/share/rmd/rmd\\.R", ps_lines)
  if (is.character(qmd_path) && !is.na(qmd_path) && nzchar(qmd_path)) {
    qmd_hits <- grepl(qmd_path, ps_lines, fixed = TRUE)
    relevant <- relevant & (qmd_hits | grepl("/Applications/quarto/share/rmd/rmd\\.R", ps_lines))
  }
  any(relevant)
}

derive_anchor_time <- function(batch_df, combine_df, log_path) {
  candidates <- character()
  for (df in list(batch_df, combine_df)) {
    if (!nrow(df)) next
    for (field in c("finished_at", "started_at")) {
      if (field %in% names(df)) {
        vals <- df[[field]]
        vals <- vals[nzchar(vals)]
        if (length(vals)) candidates <- c(candidates, utils::tail(vals, 1L))
      }
    }
  }
  if (!length(candidates) && file.exists(log_path)) {
    return(as.POSIXct(file.info(log_path)$mtime, tz = Sys.timezone()))
  }
  ts <- suppressWarnings(as.POSIXct(candidates, tz = Sys.timezone()))
  ts <- ts[is.finite(ts)]
  if (!length(ts)) return(as.POSIXct(file.info(log_path)$mtime, tz = Sys.timezone()))
  utils::tail(ts, 1L)
}

system_log_snippets <- function(anchor_time) {
  if (length(anchor_time) == 0L || is.na(anchor_time)) return("System-log anchor time unavailable.")
  log_bin <- Sys.which("log")
  if (!nzchar(log_bin)) return("macOS `log` tool not available.")
  start_at <- format(anchor_time - 180, "%Y-%m-%d %H:%M:%S")
  end_at <- format(anchor_time + 180, "%Y-%m-%d %H:%M:%S")
  predicate <- paste(
    '(process == "R" OR process == "bash" OR process == "zsh" OR process == "quarto"',
    'OR eventMessage CONTAINS[c] "kill" OR eventMessage CONTAINS[c] "memory"',
    'OR eventMessage CONTAINS[c] "oom" OR eventMessage CONTAINS[c] "terminated")'
  )
  out <- tryCatch(
    system(
      paste(
        shQuote(log_bin),
        "show --style compact",
        "--start", shQuote(start_at),
        "--end", shQuote(end_at),
        "--predicate", shQuote(predicate)
      ),
      intern = TRUE,
      ignore.stderr = FALSE
    ),
    error = function(e) paste("log show failed:", conditionMessage(e))
  )
  out <- out[nzchar(trimws(out))]
  if (!length(out)) return("No matching macOS system-log lines found in the failure window.")
  paste(utils::tail(out, 25L), collapse = "\n")
}

args <- parse_args(commandArgs(trailingOnly = TRUE))

results_dir <- normalizePath(args$results_dir, winslash = "/", mustWork = TRUE)
log_path <- normalizePath(args$log_path, winslash = "/", mustWork = FALSE)
pdf_path <- normalizePath(args$pdf_path, winslash = "/", mustWork = FALSE)
render_logs_dir <- file.path(results_dir, "render_logs")
dir.create(render_logs_dir, recursive = TRUE, showWarnings = FALSE)

postmortem_path <- file.path(render_logs_dir, paste0("postmortem_", args$render_ts, ".md"))
status_path <- file.path(results_dir, paste0("mi_run_status_", args$render_ts, ".json"))
batch_path <- file.path(results_dir, "mice_batches_log.csv")
combine_path <- file.path(results_dir, "mice_combine_log.csv")

log_lines <- if (file.exists(log_path)) readLines(log_path, warn = FALSE) else character()
qmd_path <- parse_log_value(log_lines, "\\[render:qmd\\] ")
log_wrapper_status <- suppressWarnings(as.numeric(parse_log_value(log_lines, "\\[render:status\\] ")))
wrapper_status <- if (is.finite(args$wrapper_status)) args$wrapper_status else log_wrapper_status
wrapper_trailer_present <- any(grepl("^\\[render:end\\]", log_lines)) || any(grepl("^\\[render:status\\]", log_lines))
pdf_exists <- file.exists(pdf_path)

batch_df <- read_csv_safe(batch_path)
combine_df <- read_csv_safe(combine_path)
last_batch_row <- if (nrow(batch_df)) utils::tail(batch_df, 1L) else data.frame()
last_batch <- if (nrow(last_batch_row) && "batch" %in% names(last_batch_row)) last_batch_row$batch[[1]] else NA_integer_
last_stage <- if (nrow(last_batch_row) && "stage" %in% names(last_batch_row)) last_batch_row$stage[[1]] else NA_character_
has_mice_returned <- if (nrow(batch_df) && is.finite(last_batch)) {
  any(batch_df$batch == last_batch & batch_df$stage == "mice_returned")
} else {
  FALSE
}
live_render_detected <- detect_live_render(qmd_path)

status <- if (is.finite(wrapper_status)) {
  if (wrapper_status == 0 && identical(args$postflight_passed, TRUE) && pdf_exists) {
    "completed"
  } else {
    "failed_caught_error"
  }
} else if (!pdf_exists &&
           !wrapper_trailer_present &&
           !live_render_detected &&
           nrow(last_batch_row) &&
           last_stage %in% c("batch_started", "mice_call_entered") &&
           !has_mice_returned) {
  "failed_abrupt_termination_suspected"
} else if (pdf_exists && !live_render_detected && wrapper_trailer_present && isTRUE(log_wrapper_status == 0)) {
  "completed"
} else {
  "failed_caught_error"
}

anchor_time <- derive_anchor_time(batch_df, combine_df, log_path)
log_tail <- render_log_tail(log_path, n = 40L)
system_log_block <- system_log_snippets(anchor_time)

postmortem_lines <- c(
  paste0("# Render postmortem: ", args$render_ts),
  "",
  "## Summary",
  paste0("- Status: `", status, "`"),
  paste0("- PDF exists: `", pdf_exists, "`"),
  paste0("- Wrapper trailer present: `", wrapper_trailer_present, "`"),
  paste0("- Wrapper status: `", if (is.finite(wrapper_status)) wrapper_status else "NA", "`"),
  paste0("- Postflight passed: `", if (isTRUE(args$postflight_passed)) "TRUE" else if (identical(args$postflight_passed, FALSE)) "FALSE" else "NA", "`"),
  paste0("- Live render detected: `", live_render_detected, "`"),
  paste0("- QMD path: `", if (!is.na(qmd_path) && nzchar(qmd_path)) qmd_path else "NA", "`"),
  paste0("- PDF path: `", pdf_path, "`"),
  "",
  "## Last MI batch rows",
  format_df_block(batch_df, n = 8L),
  "",
  "## Last combine rows",
  format_df_block(combine_df, n = 8L),
  "",
  "## Render log tail",
  if (length(log_tail)) {
    paste(c("```text", log_tail, "```"), collapse = "\n")
  } else {
    "_render log missing_"
  },
  "",
  "## System log snippets",
  paste(c("```text", system_log_block, "```"), collapse = "\n")
)

writeLines(postmortem_lines, postmortem_path)

write_json_object(
  list(
    render_ts = args$render_ts,
    status = status,
    pdf_exists = pdf_exists,
    wrapper_trailer_present = wrapper_trailer_present,
    wrapper_status = wrapper_status,
    postflight_passed = args$postflight_passed,
    live_render_detected = live_render_detected,
    log_path = log_path,
    pdf_path = pdf_path,
    postmortem_path = postmortem_path,
    last_batch = last_batch,
    last_stage = last_stage,
    has_mice_returned_for_last_batch = has_mice_returned
  ),
  status_path
)

cat("[collect_render_postmortem] wrote ", postmortem_path, "\n", sep = "")
cat("[collect_render_postmortem] wrote ", status_path, "\n", sep = "")
