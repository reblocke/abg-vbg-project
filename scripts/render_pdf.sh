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
RSS_TRACE_PATH="${LOG_DIR}/rss_trace_${RUN_TS}.csv"
COLLECTOR_SCRIPT="${ROOT_DIR}/scripts/collect_render_postmortem.R"
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
PID_MARKER_WATCHER=""
RSS_SAMPLER_PID=""
POSTFLIGHT_PASSED=0

cd "${ROOT_DIR}"
mkdir -p "${LOG_DIR}"

find_quarto_pid() {
  local qmd_path="$1"
  ps -Ao pid=,command= | awk -v path="${qmd_path}" '(index($0, "quarto.js render") || index($0, "quarto render")) && index($0, path) { print $1; exit }'
}

find_r_pid() {
  ps -Ao pid=,command= | awk 'index($0, "/Applications/quarto/share/rmd/rmd.R") { print $1; exit }'
}

watch_pid_markers() {
  local qmd_path="$1"
  local quarto_pid=""
  local r_pid=""
  local attempt
  for attempt in $(seq 1 30); do
    sleep 1
    if [[ -z "${quarto_pid}" ]]; then
      quarto_pid="$(find_quarto_pid "${qmd_path}")"
      [[ -n "${quarto_pid}" ]] && echo "[render:quarto_pid] ${quarto_pid}"
    fi
    if [[ -z "${r_pid}" ]]; then
      r_pid="$(find_r_pid)"
      [[ -n "${r_pid}" ]] && echo "[render:r_pid] ${r_pid}"
    fi
    if [[ -n "${quarto_pid}" && -n "${r_pid}" ]]; then
      break
    fi
  done
}

detect_timing_mode() {
  if [[ -x /usr/bin/time ]] && /usr/bin/time -l true >/dev/null 2>&1; then
    echo "usrbin_time_l"
    return 0
  fi

  if command -v gtime >/dev/null 2>&1 && gtime -v true >/dev/null 2>&1; then
    echo "gtime_v"
    return 0
  fi

  echo "none"
}

run_with_timing() {
  local timing_mode="$1"
  shift

  case "${timing_mode}" in
    usrbin_time_l)
      echo "[render:timing] /usr/bin/time -l"
      /usr/bin/time -l "$@"
      ;;
    gtime_v)
      echo "[render:timing] gtime -v"
      gtime -v "$@"
      ;;
    none)
      echo "[render:timing] unavailable"
      "$@"
      ;;
    *)
      echo "[render:timing] unknown mode: ${timing_mode}"
      return 1
      ;;
  esac
}

archive_debug_artifacts() {
  local archive_root="${RESULTS_DIR}/archive/pre_run_${RUN_TS}"
  local moved_any=0

  move_debug_artifact() {
    local src="$1"
    local rel="$2"
    [[ -e "${src}" ]] || return 0
    mkdir -p "${archive_root}/$(dirname "${rel}")"
    mv "${src}" "${archive_root}/${rel}"
    echo "[render:archive] moved ${src} -> ${archive_root}/${rel}"
    moved_any=1
  }

  move_debug_artifact "${RESULTS_DIR}/mice_batches_log.csv" "mice_batches_log.csv"
  move_debug_artifact "${RESULTS_DIR}/mice_combine_log.csv" "mice_combine_log.csv"
  move_debug_artifact "${RESULTS_DIR}/mi_batch_context.rds" "mi_batch_context.rds"
  move_debug_artifact "${RESULTS_DIR}/mi_batch_checkpoints" "mi_batch_checkpoints"

  shopt -s nullglob
  local src
  for src in "${RESULTS_DIR}"/mi_run_status_*.json; do
    move_debug_artifact "${src}" "$(basename "${src}")"
  done
  for src in "${LOG_DIR}"/postmortem_*.md; do
    move_debug_artifact "${src}" "render_logs/$(basename "${src}")"
  done
  for src in "${LOG_DIR}"/rss_trace_*.csv; do
    move_debug_artifact "${src}" "render_logs/$(basename "${src}")"
  done
  shopt -u nullglob

  if [[ ${moved_any} -eq 0 ]]; then
    echo "[render:archive] no prior MI/debug artifacts found"
  fi
}

start_rss_sampler() {
  local trace_path="$1"
  local wrapper_pid="$2"
  local qmd_path="$3"

  cat > "${trace_path}" <<CSV
sampled_at,render_ts,sampled_pid,role,rss_kb,vsz_kb,state,etime,command
CSV

  (
    append_ps_row() {
      local role="$1"
      local pid="$2"
      local sampled_at=""
      local ps_line=""
      local rss_kb=""
      local vsz_kb=""
      local state=""
      local etime=""
      local command_field=""
      [[ -n "${pid}" ]] || return 0
      kill -0 "${pid}" 2>/dev/null || return 0
      sampled_at="$(date '+%Y-%m-%d %H:%M:%S')"
      ps_line="$(ps -o rss=,vsz=,state=,etime=,command= -p "${pid}" 2>/dev/null || true)"
      [[ -n "${ps_line// }" ]] || return 0
      rss_kb="$(awk '{print $1}' <<<"${ps_line}")"
      vsz_kb="$(awk '{print $2}' <<<"${ps_line}")"
      state="$(awk '{print $3}' <<<"${ps_line}")"
      etime="$(awk '{print $4}' <<<"${ps_line}")"
      command_field="$(awk '{$1=$2=$3=$4=""; sub(/^ +/, ""); print}' <<<"${ps_line}")"
      command_field="${command_field//\"/\"\"}"
      printf '"%s","%s",%s,"%s",%s,%s,"%s","%s","%s"\n' \
        "${sampled_at}" "${RUN_TS}" "${pid}" "${role}" "${rss_kb}" "${vsz_kb}" "${state}" "${etime}" "${command_field}" >> "${trace_path}"
    }

    while kill -0 "${wrapper_pid}" 2>/dev/null; do
      append_ps_row "wrapper" "${wrapper_pid}"
      append_ps_row "quarto" "$(find_quarto_pid "${qmd_path}")"
      append_ps_row "r" "$(find_r_pid)"
      sleep 15
    done
  ) &

  RSS_SAMPLER_PID=$!
  echo "[render:rss_trace] ${trace_path}"
  echo "[render:rss_sampler_pid] ${RSS_SAMPLER_PID}"
}

run_collector() {
  local wrapper_status="$1"
  local postflight_flag="$2"
  if [[ ! -f "${COLLECTOR_SCRIPT}" ]]; then
    echo "[render:collector] missing collector script: ${COLLECTOR_SCRIPT}"
    return 0
  fi
  if ! Rscript --vanilla "${COLLECTOR_SCRIPT}" \
      --render-ts "${RUN_TS}" \
      --results-dir "${RESULTS_DIR}" \
      --log-path "${LOG_PATH}" \
      --pdf-path "${OUTPUT_PDF}" \
      --wrapper-status "${wrapper_status}" \
      --postflight-passed "${postflight_flag}"
  then
    echo "[render:collector] collector failed for ${RUN_TS}"
  fi
}

on_exit() {
  local status=$?
  local finished_at=""
  local postflight_flag="FALSE"
  set +e
  if [[ -n "${PID_MARKER_WATCHER}" ]]; then
    kill "${PID_MARKER_WATCHER}" 2>/dev/null || true
    wait "${PID_MARKER_WATCHER}" 2>/dev/null || true
  fi
  if [[ -n "${RSS_SAMPLER_PID}" ]]; then
    kill "${RSS_SAMPLER_PID}" 2>/dev/null || true
    wait "${RSS_SAMPLER_PID}" 2>/dev/null || true
  fi
  finished_at="$(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "[render:end] ${finished_at}"
  echo "[render:status] ${status}"
  echo "[render:log] ${LOG_PATH}"
  if [[ ${POSTFLIGHT_PASSED} -eq 1 ]]; then
    postflight_flag="TRUE"
  fi
  run_collector "${status}" "${postflight_flag}"
}
trap on_exit EXIT

exec > >(tee -a "${LOG_PATH}") 2>&1

echo "[render:start] $(date '+%Y-%m-%d %H:%M:%S %z')"
echo "[render:qmd] ${QMD_PATH}"
echo "[render:log] ${LOG_PATH}"
echo "[render:pdf_target] ${OUTPUT_PDF}"
echo "[render:wrapper_pid] $$"
if [[ ${#QUARTO_ARGS[@]} -gt 0 ]]; then
  printf '[render:args]'
  printf ' %q' "${QUARTO_ARGS[@]}"
  printf '\n'
fi

archive_debug_artifacts

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
watch_pid_markers "${QMD_PATH}" &
PID_MARKER_WATCHER=$!
start_rss_sampler "${RSS_TRACE_PATH}" "$$" "${QMD_PATH}"

RENDER_STATUS=0
set +e
run_with_timing "$(detect_timing_mode)" quarto render "${QMD_PATH}" --to pdf "${QUARTO_ARGS[@]}"
RENDER_STATUS=$?
set -e
if [[ ${RENDER_STATUS} -ne 0 ]]; then
  exit "${RENDER_STATUS}"
fi

echo "[render:postflight] validate_outputs"
POSTFLIGHT_STATUS=0
set +e
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

required_validation_artifacts <- c(
  "artifact_provenance_manifest.csv",
  "artifact_check_status.csv",
  "artifact_check_missing.csv",
  "canonical_asset_registry.csv",
  "manuscript_sync_report.md",
  "glyph_audit.csv",
  "duplicate_asset_audit.csv",
  "diagnostics_audit_summary.csv",
  "diagnostics_audit_issues.csv"
)

missing_validation_artifacts <- required_validation_artifacts[
  !file.exists(file.path(results_dir, required_validation_artifacts))
]
if (length(missing_validation_artifacts)) {
  stop(
    "Validation artifact postflight failed; missing files: ",
    paste(missing_validation_artifacts, collapse = ", "),
    call. = FALSE
  )
}

required_validation_cols <- list(
  artifact_provenance_manifest.csv = c("manuscript_label", "numbering_slot", "status", "source_type"),
  artifact_check_status.csv = c("manuscript_label", "artifact_role", "check_status", "severity"),
  artifact_check_missing.csv = c("manuscript_label", "artifact_role", "check_status", "severity"),
  canonical_asset_registry.csv = c("numbering_slot", "manuscript_label", "status", "source_type"),
  glyph_audit.csv = c("manuscript_label", "field_name", "glyph_status", "severity"),
  duplicate_asset_audit.csv = c("audit_scope", "audit_key", "status", "severity"),
  diagnostics_audit_summary.csv = c("component", "metric", "value", "status", "severity"),
  diagnostics_audit_issues.csv = c("severity", "component", "evidence_file", "evidence_snippet")
)

for (artifact_name in names(required_validation_cols)) {
  artifact_path <- file.path(results_dir, artifact_name)
  artifact_df <- tryCatch(
    utils::read.csv(artifact_path, nrows = 1, stringsAsFactors = FALSE),
    error = function(e) stop("Could not read validation artifact ", artifact_name, ": ", conditionMessage(e), call. = FALSE)
  )
  missing_cols <- setdiff(required_validation_cols[[artifact_name]], names(artifact_df))
  if (length(missing_cols)) {
    stop(
      "Validation artifact ", artifact_name, " missing required columns [",
      paste(missing_cols, collapse = ", "),
      "].",
      call. = FALSE
    )
  }
}

cat("[render:postflight] render path and PDF validation passed\n")
RSCRIPT
POSTFLIGHT_STATUS=$?
set -e
if [[ ${POSTFLIGHT_STATUS} -ne 0 ]]; then
  exit "${POSTFLIGHT_STATUS}"
fi
echo "[render:postflight] check_pdf_assets"
Rscript --vanilla "${ROOT_DIR}/scripts/check_pdf_assets.R" \
  --pdf-path "${OUTPUT_PDF}" \
  --results-dir "${RESULTS_DIR}" \
  --min-pages 150 \
  --min-images 70
POSTFLIGHT_PASSED=1
echo "[render:quarto] complete"
