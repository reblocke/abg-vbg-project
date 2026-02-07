#!/usr/bin/env Rscript

# Deterministic environment preflight for long Quarto runs.
# This script is designed to run with `Rscript --vanilla`.

options(warn = 1)

project_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
lockfile <- file.path(project_root, "renv.lock")

if (!file.exists(lockfile)) {
  stop(
    "Missing renv.lock. Run `Rscript -e \"renv::snapshot()\"` and commit renv.lock.",
    call. = FALSE
  )
}

cat("Starting environment preflight...\n")
if (!requireNamespace("renv", quietly = TRUE)) {
  stop("Package `renv` is required but not available in this R session.", call. = FALSE)
}

# Capture status output so we can fail with a concise actionable message.
status_lines <- capture.output(status_obj <- renv::status(project = project_root))
out_of_sync <- any(grepl("out-of-sync", status_lines, ignore.case = TRUE, perl = TRUE))

if (is.list(status_obj) && !is.null(status_obj$synchronized)) {
  out_of_sync <- out_of_sync || identical(status_obj$synchronized, FALSE)
}

if (out_of_sync) {
  cat(paste(status_lines, collapse = "\n"), "\n")
  stop(
    paste(
      "Environment preflight failed.",
      "Run `Rscript -e \"renv::restore()\"` and then `Rscript -e \"renv::snapshot()\"`",
      "if dependency intent changed."
    ),
    call. = FALSE
  )
}

cat("Environment preflight passed.\n")
