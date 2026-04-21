#!/usr/bin/env Rscript

# Deterministic direct-dependency audit for the Quarto notebook and
# reproducibility scripts. This is designed to run with `Rscript --vanilla`.

options(warn = 1)

project_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
desc_path <- file.path(project_root, "DESCRIPTION")

if (!file.exists(desc_path)) {
  stop("Missing DESCRIPTION. Declare direct dependencies before rendering.", call. = FALSE)
}

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
  stop("Package `renv` is required for dependency auditing.", call. = FALSE)
}

read_declared_packages <- function(path) {
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

extract_code_pkgs <- function(path) {
  if (!file.exists(path)) return(character())
  lines <- readLines(path, warn = FALSE)
  capture_group <- function(pattern, x) {
    hits <- regexec(pattern, x, perl = TRUE)
    matches <- regmatches(x, hits)
    vals <- vapply(matches, function(m) if (length(m) >= 2L) m[2] else NA_character_, character(1))
    vals[nzchar(vals) & !is.na(vals)]
  }
  lib_pkgs <- capture_group("library\\s*\\(\\s*['\"]?([A-Za-z][A-Za-z0-9.]*)['\"]?", lines)
  req_pkgs <- capture_group("requireNamespace\\s*\\(\\s*['\"]?([A-Za-z][A-Za-z0-9.]*)['\"]?", lines)
  ns_pkgs <- capture_group("([A-Za-z][A-Za-z0-9.]*)::[A-Za-z][A-Za-z0-9._]*", lines)
  unique(c(lib_pkgs, req_pkgs, ns_pkgs))
}

extract_seed_pkgs <- function(path) {
  if (!file.exists(path)) return(character())
  lines <- readLines(path, warn = FALSE)
  start <- grep("^seed_pkgs\\s*<-\\s*c\\(", lines)
  if (!length(start)) return(character())
  idx <- start[[1]]
  out <- character()
  while (idx <= length(lines)) {
    out <- c(out, regmatches(lines[idx], gregexpr("\"([A-Za-z][A-Za-z0-9.]*)\"", lines[idx], perl = TRUE))[[1]])
    if (grepl("\\)\\s*$", lines[idx])) break
    idx <- idx + 1L
  }
  out <- gsub("^\"|\"$", "", out)
  unique(out[nzchar(out)])
}

audit_paths <- c(
  file.path(project_root, "Code Drafts", "ABG-VBG analysis 2026-4-21.qmd"),
  file.path(project_root, "scripts", "check_env.R"),
  file.path(project_root, "scripts", "check_dependencies.R")
)

seed_pkgs <- extract_seed_pkgs(audit_paths[[1]])
manual_pkgs <- sort(unique(unlist(lapply(audit_paths, extract_code_pkgs))))
renv_pkgs <- tryCatch(
  {
    dep_tbl <- renv::dependencies(audit_paths, progress = FALSE)
    if (!is.null(dep_tbl$Package)) sort(unique(dep_tbl$Package)) else character()
  },
  error = function(e) character()
)

base_drop <- c(
  "base", "compiler", "datasets", "graphics", "grDevices", "grid",
  "methods", "parallel", "splines", "stats", "tools", "utils"
)
ignore_pkgs <- c("pkg")

used_pkgs <- sort(unique(setdiff(c(seed_pkgs, manual_pkgs), c(base_drop, ignore_pkgs))))
declared_pkgs <- read_declared_packages(desc_path)
renv_only <- setdiff(renv_pkgs, c(used_pkgs, base_drop, ignore_pkgs))

missing_decl <- setdiff(used_pkgs, declared_pkgs)
unused_decl <- setdiff(declared_pkgs, used_pkgs)

cat("Dependency audit targets:\n")
cat(paste0("- ", audit_paths), sep = "\n")
cat("\n")

if (length(renv_only)) {
  cat("Dependency audit note (renv::dependencies only):\n")
  cat(paste0("- ", renv_only), sep = "\n")
  cat("\n")
}

if (length(missing_decl) || length(unused_decl)) {
  if (length(missing_decl)) {
    cat("Used but undeclared packages:\n")
    cat(paste0("- ", missing_decl), sep = "\n")
    cat("\n")
  }
  if (length(unused_decl)) {
    cat("Declared but unused packages:\n")
    cat(paste0("- ", unused_decl), sep = "\n")
    cat("\n")
  }
  stop(
    "Dependency audit failed. Update DESCRIPTION so declared direct dependencies match actual notebook/script usage.",
    call. = FALSE
  )
}

cat("Dependency audit passed for ", length(declared_pkgs), " declared direct packages.\n", sep = "")
