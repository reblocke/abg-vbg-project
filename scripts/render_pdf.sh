#!/usr/bin/env bash
set -euo pipefail

# Reproducible render wrapper:
# 1) verify environment consistency
# 2) render the main Quarto analysis PDF

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QMD_DEFAULT="${ROOT_DIR}/Code Drafts/ABG-VBG analysis 2026-2-28.qmd"
if [[ $# -gt 0 && "${1}" != -* ]]; then
  QMD_PATH="$1"
  shift
else
  QMD_PATH="${QMD_DEFAULT}"
fi
QUARTO_ARGS=("$@")
RESULTS_DIR="${ROOT_DIR}/Results"
LOG_DIR="${RESULTS_DIR}/render_logs"
RUN_TS="$(date '+%Y%m%d_%H%M%S')"
LOG_PATH="${LOG_DIR}/render_${RUN_TS}.log"
QMD_DIR="$(cd "$(dirname "${QMD_PATH}")" && pwd)"
QMD_STEM="$(basename "${QMD_PATH}" .qmd)"
QMD_RMARKDOWN="${QMD_DIR}/${QMD_STEM}.rmarkdown"
QMD_SANITIZED_STEM="$(printf '%s' "${QMD_STEM}" | sed 's/[^[:alnum:]._-]/-/g')"
QMD_SANITIZED_RMARKDOWN="${QMD_DIR}/${QMD_SANITIZED_STEM}.rmarkdown"
OUTPUT_PDF="${QMD_DIR}/${QMD_SANITIZED_STEM}.pdf"
OUTPUT_TEX="${QMD_DIR}/${QMD_SANITIZED_STEM}.tex"
OUTPUT_KNIT_MD="${QMD_DIR}/${QMD_SANITIZED_STEM}.knit.md"
OUTPUT_AUX="${QMD_DIR}/${QMD_SANITIZED_STEM}.aux"
OUTPUT_LOG="${QMD_DIR}/${QMD_SANITIZED_STEM}.log"
OUTPUT_TOC="${QMD_DIR}/${QMD_SANITIZED_STEM}.toc"

cd "${ROOT_DIR}"
mkdir -p "${LOG_DIR}"

on_exit() {
  local status=$?
  local finished_at
  finished_at="$(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "[render:end] ${finished_at}"
  echo "[render:status] ${status}"
  echo "[render:log] ${LOG_PATH}"
}
trap on_exit EXIT

exec > >(tee -a "${LOG_PATH}") 2>&1

echo "[render:start] $(date '+%Y-%m-%d %H:%M:%S %z')"
echo "[render:qmd] ${QMD_PATH}"
echo "[render:log] ${LOG_PATH}"
echo "[render:pdf_target] ${OUTPUT_PDF}"
if [[ ${#QUARTO_ARGS[@]} -gt 0 ]]; then
  printf '[render:args]'
  printf ' %q' "${QUARTO_ARGS[@]}"
  printf '\n'
fi
for stale_file in \
  "${QMD_RMARKDOWN}" \
  "${QMD_SANITIZED_RMARKDOWN}" \
  "${OUTPUT_TEX}" \
  "${OUTPUT_PDF}" \
  "${OUTPUT_KNIT_MD}" \
  "${OUTPUT_AUX}" \
  "${OUTPUT_LOG}" \
  "${OUTPUT_TOC}"
do
  if [[ -f "${stale_file}" ]]; then
    rm -f "${stale_file}"
    echo "[render:cleanup] removed stale ${stale_file}"
  fi
done

TEX_BIN="${HOME}/Library/TinyTeX/bin/universal-darwin"
if [[ -d "${TEX_BIN}" ]]; then
  export PATH="${TEX_BIN}:${PATH}"
fi
export R_PROFILE_USER="${ROOT_DIR}/.Rprofile"
export RENV_PROJECT="${ROOT_DIR}"
echo "[render:root] ${ROOT_DIR}"
echo "[render:preflight] check_env"
Rscript --vanilla -e "source('scripts/check_env.R')"
echo "[render:preflight] check_dependencies"
Rscript --vanilla scripts/check_dependencies.R
echo "[render:quarto] begin"
cd "${ROOT_DIR}"
echo "[render:cwd] ${ROOT_DIR}"
/usr/bin/time -l quarto render "${QMD_PATH}" --to pdf "${QUARTO_ARGS[@]}"
echo "[render:postflight] validate_outputs"
Rscript --vanilla - "${ROOT_DIR}" "${RESULTS_DIR}" "${OUTPUT_TEX}" "${OUTPUT_PDF}" <<'RSCRIPT'
args <- commandArgs(trailingOnly = TRUE)
project_root <- normalizePath(args[[1]], winslash = "/", mustWork = TRUE)
results_dir <- normalizePath(args[[2]], winslash = "/", mustWork = TRUE)
tex_file <- normalizePath(args[[3]], winslash = "/", mustWork = FALSE)
pdf_file <- normalizePath(args[[4]], winslash = "/", mustWork = FALSE)

write_csv <- function(df, path) {
  utils::write.csv(df, path, row.names = FALSE, na = "")
}

render_scan_path <- file.path(results_dir, "render_path_hygiene_scan.csv")
pdf_scan_path <- file.path(results_dir, "pdf_hygiene_scan.csv")

if (!file.exists(tex_file)) {
  write_csv(
    data.frame(scan_status = "missing_tex", line = "", stringsAsFactors = FALSE),
    render_scan_path
  )
  stop("Render path validation missing TeX output: ", tex_file, call. = FALSE)
}

tex_lines <- readLines(tex_file, warn = FALSE)
bad_private_var <- grepl("/private/var/", tex_lines, fixed = TRUE)
bad_parent_results <- grepl("\\.\\./Results/", tex_lines, perl = TRUE)
bad_absolute_include <- grepl("\\\\includegraphics.*\\{(/|[A-Za-z]:\\\\)", tex_lines, perl = TRUE)
bad_render_lines <- tex_lines[bad_private_var | bad_parent_results | bad_absolute_include]
write_csv(
  data.frame(
    scan_status = if (length(bad_render_lines)) "failed" else "passed",
    line = if (length(bad_render_lines)) bad_render_lines else "",
    stringsAsFactors = FALSE
  ),
  render_scan_path
)
if (length(bad_render_lines)) {
  stop("Render path validation found non-canonical image paths; see ", render_scan_path, call. = FALSE)
}

if (!file.exists(pdf_file)) {
  write_csv(
    data.frame(scan_status = "missing_pdf", scanner = "none", line = "", stringsAsFactors = FALSE),
    pdf_scan_path
  )
  stop("PDF validation missing PDF output: ", pdf_file, call. = FALSE)
}

txt <- character()
scanner <- "none"
pdftotext_bin <- Sys.which("pdftotext")
if (nzchar(pdftotext_bin)) {
  tmp_txt <- tempfile(fileext = ".txt")
  scan_ok <- tryCatch({
    system2(pdftotext_bin, c(pdf_file, tmp_txt), stdout = FALSE, stderr = FALSE)
    file.exists(tmp_txt)
  }, error = function(e) FALSE)
  if (isTRUE(scan_ok)) {
    scanner <- "pdftotext"
    txt <- readLines(tmp_txt, warn = FALSE)
  }
}

if (length(txt) == 0 && requireNamespace("pdftools", quietly = TRUE)) {
  scanner <- "pdftools"
  txt <- tryCatch(
    unlist(pdftools::pdf_text(pdf_file), use.names = FALSE),
    error = function(e) character()
  )
}

if (length(txt) == 0) {
  write_csv(
    data.frame(scan_status = "missing_scanner", scanner = scanner, line = "", stringsAsFactors = FALSE),
    pdf_scan_path
  )
  stop("PDF validation could not read rendered PDF text; see ", pdf_scan_path, call. = FALSE)
}

path_pattern <- "(/Users/[A-Za-z0-9._-]+/[A-Za-z0-9._/ -]+)|([A-Za-z]:\\\\[^[:space:]]+)"
bad_pdf_lines <- txt[grepl(path_pattern, txt)]
write_csv(
  data.frame(
    scan_status = if (length(bad_pdf_lines)) "failed" else "passed",
    scanner = scanner,
    line = if (length(bad_pdf_lines)) bad_pdf_lines else "",
    stringsAsFactors = FALSE
  ),
  pdf_scan_path
)
if (length(bad_pdf_lines)) {
  stop("PDF validation detected absolute filesystem paths; see ", pdf_scan_path, call. = FALSE)
}

cat("[render:postflight] render path and PDF validation passed\n")
RSCRIPT
echo "[render:quarto] complete"
