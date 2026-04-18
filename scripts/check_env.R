#!/usr/bin/env Rscript

# Deterministic environment preflight for long Quarto runs.
# This script is designed to run with `Rscript --vanilla`.

options(warn = 1)

project_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
lockfile <- file.path(project_root, "renv.lock")
desc_path <- file.path(project_root, "DESCRIPTION")

if (!file.exists(lockfile)) {
  stop(
    "Missing renv.lock. Run `Rscript -e \"renv::snapshot()\"` and commit renv.lock.",
    call. = FALSE
  )
}

cat("Starting environment preflight...\n")
# Ensure the project-local renv package is discoverable even under
# `Rscript --vanilla`, which skips the repo `.Rprofile` autoloader.
project_renv_pkg <- Sys.glob(
  file.path(project_root, "renv", "library", "*", "R-*", R.version$platform, "renv")
)
if (length(project_renv_pkg) >= 1L) {
  project_renv_lib <- normalizePath(dirname(project_renv_pkg[[1]]), winslash = "/", mustWork = TRUE)
  .libPaths(unique(c(project_renv_lib, .libPaths())))
}

if (!requireNamespace("renv", quietly = TRUE)) {
  stop(
    paste(
      "Package `renv` is required but not available in this R session.",
      "Run `Rscript -e \"install.packages('renv')\"` if this machine does not yet have it,",
      "or restore the project library with `Rscript -e \"renv::restore()\"`."
    ),
    call. = FALSE
  )
}

read_declared_packages <- function(path) {
  if (!file.exists(path)) return(character())
  dcf <- read.dcf(path)
  fields <- intersect(c("Imports", "Depends"), colnames(dcf))
  vals <- unlist(lapply(fields, function(field) {
    txt <- dcf[1, field]
    if (!nzchar(txt)) return(character())
    pieces <- trimws(unlist(strsplit(gsub("[\r\n]+", " ", txt), ",")))
    sub("\\s*\\(.*\\)$", "", pieces)
  }))
  sort(unique(setdiff(vals, c("", "R"))))
}

declared_pkgs <- read_declared_packages(desc_path)
missing_declared <- setdiff(declared_pkgs, rownames(installed.packages()))
if (length(missing_declared)) {
  stop(
    "Missing declared packages: ", paste(missing_declared, collapse = ", "),
    ". Restore or install the direct dependencies before rendering.",
    call. = FALSE
  )
}

# Capture status output so we can surface lockfile drift without blocking a
# validated render on machines where only installable binary versions differ.
status_lines <- capture.output(status_obj <- renv::status(project = project_root))
out_of_sync <- any(grepl("out-of-sync", status_lines, ignore.case = TRUE, perl = TRUE))

if (is.list(status_obj) && !is.null(status_obj$synchronized)) {
  out_of_sync <- out_of_sync || identical(status_obj$synchronized, FALSE)
}

if (out_of_sync) {
  cat(paste(status_lines, collapse = "\n"), "\n")
  warning(
    paste(
      "Environment preflight warning:",
      "renv reports lockfile/library drift on this machine, but all declared direct dependencies are installed.",
      "Continue to the dependency audit and pilot render, then run",
      "`Rscript --vanilla -e \"source('renv/activate.R'); renv::snapshot(prompt = FALSE)\"`",
      "after the validated render to record the working state."
    ),
    call. = FALSE
  )
  cat("Environment preflight passed with lockfile-drift warning.\n")
} else {
  cat("Environment preflight passed.\n")
}
