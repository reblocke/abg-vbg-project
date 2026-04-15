local({
  project_root <- Sys.getenv("RENV_PROJECT", unset = "")

  if (!nzchar(project_root)) {
    profile_file <- tryCatch(
      normalizePath(sys.frame(1)$ofile, winslash = "/", mustWork = TRUE),
      error = function(e) ""
    )
    if (nzchar(profile_file)) {
      project_root <- dirname(profile_file)
    }
  }

  if (!nzchar(project_root)) {
    project_root <- getwd()
  }

  project_root <- normalizePath(project_root, winslash = "/", mustWork = TRUE)
  activate_file <- file.path(project_root, "renv", "activate.R")

  if (!file.exists(activate_file)) {
    stop(
      "Could not find renv activation script at ", activate_file,
      ". Set RENV_PROJECT to the repo root or launch R from the repo root.",
      call. = FALSE
    )
  }

  Sys.setenv(RENV_PROJECT = project_root)
  source(activate_file)
})
