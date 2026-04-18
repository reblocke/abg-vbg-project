#!/usr/bin/env Rscript

parse_args <- function(args) {
  out <- list(
    context = NA_character_,
    checkpoint = NA_character_,
    batch = NA_integer_,
    seed = NA_integer_,
    outdir = NA_character_
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
  required <- c("context", "checkpoint", "batch", "seed", "outdir")
  missing <- required[!nzchar(unlist(out[required])) | is.na(unlist(out[required]))]
  if (length(missing)) {
    stop("Missing required arguments: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  parse_integer_arg <- function(value, flag) {
    if (!is.character(value) || length(value) != 1L || is.na(value) || !nzchar(value)) {
      stop("Missing required argument: ", flag, call. = FALSE)
    }
    if (!grepl("^[0-9]+$", value)) {
      stop("Invalid value for ", flag, ": expected integer, got ", shQuote(value), call. = FALSE)
    }
    parsed <- suppressWarnings(as.integer(value))
    if (is.na(parsed)) {
      stop("Invalid value for ", flag, ": expected integer, got ", shQuote(value), call. = FALSE)
    }
    parsed
  }
  out$batch <- parse_integer_arg(out$batch, "--batch")
  out$seed <- parse_integer_arg(out$seed, "--seed")
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

ensure_packages_loaded <- function(pkgs) {
  invisible(lapply(pkgs, function(pkg) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop("Required package is not available: ", pkg, call. = FALSE)
    }
    suppressPackageStartupMessages(library(pkg, character.only = TRUE))
  }))
}

get_rss_mb <- function(pid = Sys.getpid()) {
  rss_txt <- tryCatch(
    system2("ps", c("-o", "rss=", "-p", as.character(pid)), stdout = TRUE, stderr = FALSE),
    error = function(e) character()
  )
  rss_kb <- suppressWarnings(as.numeric(trimws(rss_txt[[1]])))
  if (!length(rss_kb) || !is.finite(rss_kb) || rss_kb <= 0) return(NA_real_)
  rss_kb / 1024
}

safe_object_size_bytes <- function(x) {
  if (is.null(x)) return(NA_real_)
  as.numeric(utils::object.size(x))
}

start_rss_sampler <- function(pid, trace_path, interval_sec = 5L) {
  writeLines("sampled_at,target_pid,rss_kb,vsz_kb,state,etime,command", trace_path)
  script_path <- tempfile("batch40_rss_sampler_", fileext = ".sh")
  script_lines <- c(
    "#!/usr/bin/env bash",
    "set -euo pipefail",
    paste0("TARGET_PID=", pid),
    paste0("TRACE_PATH=", shQuote(trace_path)),
    paste0("INTERVAL_SEC=", interval_sec),
    "while kill -0 \"${TARGET_PID}\" 2>/dev/null; do",
    "  sampled_at=\"$(date '+%Y-%m-%d %H:%M:%S')\"",
    "  ps -o rss=,vsz=,state=,etime=,command= -p \"${TARGET_PID}\" | awk -v sampled_at=\"${sampled_at}\" -v target_pid=\"${TARGET_PID}\" 'NF { sub(/^ +/, \"\", $0); rss=$1; vsz=$2; state=$3; etime=$4; $1=$2=$3=$4=\"\"; sub(/^ +/, \"\", $0); gsub(/\"/, \"\"\"\"\", $0); printf \"%s,%s,%s,%s,%s,%s,\\\"%s\\\"\\n\", sampled_at, target_pid, rss, vsz, state, etime, $0; }' >> \"${TRACE_PATH}\" || true",
    "  sleep \"${INTERVAL_SEC}\"",
    "done"
  )
  writeLines(script_lines, script_path)
  Sys.chmod(script_path, mode = "0755")
  system2("bash", c(script_path), wait = FALSE, stdout = FALSE, stderr = FALSE)
}

args <- parse_args(commandArgs(trailingOnly = TRUE))

outdir <- normalizePath(args$outdir, winslash = "/", mustWork = FALSE)
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
log_path <- file.path(outdir, "batch40_mice_log.txt")
session_info_path <- file.path(outdir, "batch40_session_info.txt")
rss_trace_path <- file.path(outdir, "batch40_rss_trace.csv")
result_json_path <- file.path(outdir, "batch40_result.json")
mids_path <- file.path(outdir, "batch40_mids.rds")
for (path in c(log_path, session_info_path, rss_trace_path, result_json_path, mids_path)) {
  if (file.exists(path)) unlink(path, force = TRUE)
}

log_line <- function(...) {
  line <- paste0(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), " ", paste0(..., collapse = ""))
  cat(line, "\n")
  cat(line, "\n", file = log_path, append = TRUE)
}

required_pkgs <- c("haven", "labelled", "dplyr", "tibble", "mice")
ensure_packages_loaded(required_pkgs)
capture.output(sessionInfo(), file = session_info_path)

ctx <- readRDS(args$context)
imp_acc <- readRDS(args$checkpoint)

if (!inherits(ctx$mi_df_run, "data.frame")) {
  stop("Saved MI context does not contain a usable `mi_df_run` data frame.", call. = FALSE)
}
if (!inherits(imp_acc, "mids")) {
  stop("Checkpoint must be a `mids` object.", call. = FALSE)
}

expected_seed <- ctx$base_seed + args$batch * 100000L
checkpoint_size_bytes <- safe_object_size_bytes(imp_acc)

write_json_object(
  list(
    status = "started",
    batch = args$batch,
    seed = args$seed,
    expected_seed = expected_seed,
    context_path = normalizePath(args$context, winslash = "/", mustWork = TRUE),
    checkpoint_path = normalizePath(args$checkpoint, winslash = "/", mustWork = TRUE),
    checkpoint_m = imp_acc$m,
    checkpoint_size_bytes = checkpoint_size_bytes,
    started_at = as.character(Sys.time())
  ),
  result_json_path
)

log_line("Loaded MI context from ", args$context)
log_line("Loaded accumulator checkpoint from ", args$checkpoint)
log_line("Checkpoint mids m = ", imp_acc$m, "; size bytes = ", checkpoint_size_bytes)
log_line("Requested batch = ", args$batch, "; requested seed = ", args$seed, "; expected seed from base rule = ", expected_seed)
log_line("Context maxit = ", ctx$maxit, "; MI rows = ", nrow(ctx$mi_df_run), "; MI cols = ", ncol(ctx$mi_df_run))
log_line("Loaded package set: ", paste(required_pkgs, collapse = ", "))

start_rss_sampler(Sys.getpid(), rss_trace_path, interval_sec = 5L)

warnings_seen <- character()
started_at <- Sys.time()
rss_before <- get_rss_mb()

result <- withCallingHandlers(
  tryCatch(
    mice::mice(
      data = ctx$mi_df_run,
      m = 1L,
      maxit = ctx$maxit,
      predictorMatrix = ctx$predictorMatrix,
      method = ctx$method,
      printFlag = FALSE,
      seed = args$seed
    ),
    error = function(e) e
  ),
  warning = function(w) {
    warnings_seen <<- c(warnings_seen, conditionMessage(w))
    log_line("warning: ", conditionMessage(w))
    invokeRestart("muffleWarning")
  }
)

finished_at <- Sys.time()
elapsed_seconds <- as.numeric(difftime(finished_at, started_at, units = "secs"))
rss_after <- get_rss_mb()

if (inherits(result, "error")) {
  err_msg <- conditionMessage(result)
  log_line("batch-40 mice() returned a caught error: ", err_msg)
  write_json_object(
    list(
      status = "caught_error",
      batch = args$batch,
      seed = args$seed,
      expected_seed = expected_seed,
      checkpoint_m = imp_acc$m,
      checkpoint_size_bytes = checkpoint_size_bytes,
      elapsed_seconds = elapsed_seconds,
      rss_mb_before = rss_before,
      rss_mb_after = rss_after,
      warning_count = length(warnings_seen),
      error_message = err_msg,
      finished_at = as.character(finished_at)
    ),
    result_json_path
  )
  quit(status = 1L)
}

saveRDS(result, mids_path)
result_size_bytes <- safe_object_size_bytes(result)
log_line("batch-40 mice() returned successfully; result size bytes = ", result_size_bytes)
write_json_object(
  list(
    status = "success",
    batch = args$batch,
    seed = args$seed,
    expected_seed = expected_seed,
    checkpoint_m = imp_acc$m,
    checkpoint_size_bytes = checkpoint_size_bytes,
    result_size_bytes = result_size_bytes,
    elapsed_seconds = elapsed_seconds,
    rss_mb_before = rss_before,
    rss_mb_after = rss_after,
    warning_count = length(warnings_seen),
    finished_at = as.character(finished_at),
    mids_path = mids_path
  ),
  result_json_path
)
