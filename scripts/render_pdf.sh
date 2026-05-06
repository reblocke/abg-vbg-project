#!/usr/bin/env bash
set -euo pipefail

# Reproducible render wrapper:
# 1) verify environment consistency
# 2) render the main Quarto analysis PDF

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QMD_DEFAULT="${ROOT_DIR}/Code Drafts/ABG-VBG analysis 2026-4-21.qmd"
if [[ $# -gt 0 && "${1}" != -* ]]; then
  QMD_PATH="$1"
  shift
else
  QMD_PATH="${QMD_DEFAULT}"
fi
QUARTO_ARGS=()
if [[ $# -gt 0 ]]; then
  QUARTO_ARGS=("$@")
fi
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
OUTPUT_BACKUP_DIR=""
OUTPUT_PDF_BACKUP=""
OUTPUT_TEX_BACKUP=""
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

backup_existing_render_outputs() {
  local copied_any=0
  OUTPUT_BACKUP_DIR="${LOG_DIR}/output_backup_${RUN_TS}"

  if [[ -f "${OUTPUT_PDF}" || -f "${OUTPUT_TEX}" ]]; then
    mkdir -p "${OUTPUT_BACKUP_DIR}"
  fi

  if [[ -f "${OUTPUT_PDF}" ]]; then
    OUTPUT_PDF_BACKUP="${OUTPUT_BACKUP_DIR}/$(basename "${OUTPUT_PDF}")"
    cp -p "${OUTPUT_PDF}" "${OUTPUT_PDF_BACKUP}"
    echo "[render:backup] copied prior PDF -> ${OUTPUT_PDF_BACKUP}"
    copied_any=1
  fi

  if [[ -f "${OUTPUT_TEX}" ]]; then
    OUTPUT_TEX_BACKUP="${OUTPUT_BACKUP_DIR}/$(basename "${OUTPUT_TEX}")"
    cp -p "${OUTPUT_TEX}" "${OUTPUT_TEX_BACKUP}"
    echo "[render:backup] copied prior TeX -> ${OUTPUT_TEX_BACKUP}"
    copied_any=1
  fi

  if [[ ${copied_any} -eq 0 ]]; then
    echo "[render:backup] no prior PDF/TEX outputs found"
  fi
}

restore_render_output_backups_on_failure() {
  local wrapper_status="$1"
  [[ "${wrapper_status}" -ne 0 ]] || return 0

  archive_failed_render_output() {
    local label="$1"
    local output_path="$2"
    local backup_path="$3"
    local archived_path=""

    [[ -s "${output_path}" ]] || return 0
    if [[ -n "${backup_path}" && -f "${backup_path}" ]] && cmp -s "${output_path}" "${backup_path}"; then
      return 0
    fi

    mkdir -p "${OUTPUT_BACKUP_DIR}"
    archived_path="${OUTPUT_BACKUP_DIR}/failed_${RUN_TS}_$(basename "${output_path}")"
    cp -p "${output_path}" "${archived_path}"
    echo "[render:restore] archived failed ${label} output -> ${archived_path}"
  }

  archive_failed_render_output "PDF" "${OUTPUT_PDF}" "${OUTPUT_PDF_BACKUP}"
  archive_failed_render_output "TeX" "${OUTPUT_TEX}" "${OUTPUT_TEX_BACKUP}"

  if [[ -n "${OUTPUT_PDF_BACKUP}" && -f "${OUTPUT_PDF_BACKUP}" ]]; then
    cp -p "${OUTPUT_PDF_BACKUP}" "${OUTPUT_PDF}"
    echo "[render:restore] restored prior PDF after failed render: ${OUTPUT_PDF}"
  else
    echo "[render:restore] no prior PDF backup available after failed render"
  fi

  if [[ -n "${OUTPUT_TEX_BACKUP}" && -f "${OUTPUT_TEX_BACKUP}" ]]; then
    cp -p "${OUTPUT_TEX_BACKUP}" "${OUTPUT_TEX}"
    echo "[render:restore] restored prior TeX after failed render: ${OUTPUT_TEX}"
  else
    echo "[render:restore] no prior TeX backup available after failed render"
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

rel_from_root() {
  local one_abs="$1"
  case "${one_abs}" in
    "${ROOT_DIR}")
      printf '.\n'
      ;;
    "${ROOT_DIR}"/*)
      printf '%s\n' "${one_abs#"${ROOT_DIR}/"}"
      ;;
    *)
      printf '%s\n' "${one_abs}"
      ;;
  esac
}

sha256_file() {
  local one_file="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "${one_file}" | awk '{print $1}'
    return 0
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${one_file}" | awk '{print $1}'
    return 0
  fi
  if command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "${one_file}" | awk '{print $NF}'
    return 0
  fi
  printf 'sha256_unavailable\n'
}

create_clean_output_bundle() {
  [[ ${POSTFLIGHT_PASSED} -eq 1 ]] || return 0
  command -v zip >/dev/null 2>&1 || {
    echo "[render:bundle] zip command unavailable; skipped clean output bundle"
    return 0
  }

  local export_dir="${RESULTS_DIR}/exports"
  local bundle_scope="render"
  local args_joined=""
  local zip_path=""
  local manifest_path=""
  local checksum_path=""
  local tmp_list=""
  local rel_path=""
  local abs_path=""
  local readme_path="${RESULTS_DIR}/README_CURRENT_RENDER.md"
  local code_snapshot_path="${RESULTS_DIR}/CODE_SNAPSHOT.md"
  local git_ref="unknown"
  local git_dirty_count="unknown"
  local qmd_sha="unknown"
  local qmd_rel=""
  local args_display="(none)"

  mkdir -p "${export_dir}"
  if [[ ${#QUARTO_ARGS[@]} -gt 0 ]]; then
    args_joined="$(printf ' %s' "${QUARTO_ARGS[@]}")"
    args_display="${args_joined# }"
  fi
  if [[ "${args_joined}" == *"run_mode:pilot"* && "${args_joined}" == *"pilot_frac:0.01"* ]]; then
    bundle_scope="1pct"
  fi

  git_ref="$(git -C "${ROOT_DIR}" rev-parse --short HEAD 2>/dev/null || printf 'unknown')"
  git_dirty_count="$(git -C "${ROOT_DIR}" status --short 2>/dev/null | wc -l | tr -d ' ' || printf 'unknown')"
  if [[ -f "${QMD_PATH}" ]]; then
    qmd_sha="$(sha256_file "${QMD_PATH}")"
  fi
  qmd_rel="$(rel_from_root "${QMD_PATH}")"

  zip_path="${export_dir}/abg_vbg_clean_${bundle_scope}_outputs_${RUN_TS}.zip"
  manifest_path="${export_dir}/abg_vbg_clean_${bundle_scope}_outputs_${RUN_TS}_manifest.csv"
  checksum_path="${zip_path}.sha256"
  tmp_list="$(mktemp)"

  {
    printf '# ABG/VBG Current Render Output Bundle\n\n'
    printf 'This bundle contains the current render PDF, manuscript-facing figures/tables, validation artifacts, and source traceability files from the successful wrapper postflight.\n\n'
    printf -- '- Render timestamp: `%s`\n' "${RUN_TS}"
    printf -- '- Bundle scope: `%s`\n' "${bundle_scope}"
    printf -- '- Quarto arguments: `%s`\n' "${args_display}"
    printf -- '- Render log: `%s`\n' "$(basename "${LOG_PATH}")"
    printf -- '- Git commit: `%s`\n' "${git_ref}"
    printf -- '- Dirty worktree entries at bundle creation: `%s`\n\n' "${git_dirty_count}"
    printf '## Canonical Manuscript Outputs\n\n'
    printf -- '- `Code Drafts/%s`\n' "$(basename "${OUTPUT_PDF}")"
    printf -- '- `Code Drafts/%s`\n' "$(basename "${OUTPUT_TEX}")"
    printf -- '- `Results/figs/figure_*.pdf`\n'
    printf -- '- `Results/table_*.csv` and `Results/table_*.pdf` files explicitly allowlisted by the wrapper\n\n'
    printf '## Supporting Validation Outputs\n\n'
    printf 'Poster QC, probability-standardization audits, publication-quality audits, artifact registries, and render logs are included to explain how the bundle was validated. Deprecated/debug table sidecars are intentionally excluded.\n\n'
    printf '## Source Traceability\n\n'
    printf -- '- Active QMD source is included at `%s`.\n' "${qmd_rel}"
    printf -- '- A compact source snapshot is included at `Results/CODE_SNAPSHOT.md`.\n'
  } > "${readme_path}"

  {
    printf '# Code Snapshot\n\n'
    printf -- '- Render timestamp: `%s`\n' "${RUN_TS}"
    printf -- '- QMD path: `%s`\n' "${qmd_rel}"
    printf -- '- QMD SHA-256: `%s`\n' "${qmd_sha}"
    printf -- '- Git commit: `%s`\n' "${git_ref}"
    printf -- '- Dirty worktree entries at bundle creation: `%s`\n' "${git_dirty_count}"
    printf -- '- Quarto arguments: `%s`\n\n' "${args_display}"
    printf 'The active QMD source file is bundled alongside this snapshot. The dirty-entry count is informational because validation renders often update generated artifacts under `Results/`.\n'
  } > "${code_snapshot_path}"

  add_abs_path() {
    local one_abs="$1"
    [[ -f "${one_abs}" ]] || return 0
    rel_path="$(rel_from_root "${one_abs}")"
    case "${rel_path}" in
      Results/archive/*|Results/mi_batch_checkpoints/*|Results/population_standardization_run_*|*.DS_Store)
        return 0
        ;;
    esac
    printf '%s\n' "${rel_path}" >> "${tmp_list}"
  }

  add_rel_path() {
    local one_rel="$1"
    add_abs_path "${ROOT_DIR}/${one_rel}"
  }

  add_glob() {
    local pattern="$1"
    local matched=0
    shopt -s nullglob
    for abs_path in ${pattern}; do
      add_abs_path "${abs_path}"
      matched=1
    done
    shopt -u nullglob
    return 0
  }

  add_rel_path "Code Drafts/$(basename "${OUTPUT_PDF}")"
  add_rel_path "Code Drafts/$(basename "${OUTPUT_TEX}")"
  add_abs_path "${QMD_PATH}"
  add_abs_path "${LOG_PATH}"
  add_abs_path "${RSS_TRACE_PATH}"
  add_abs_path "${LOG_DIR}/postmortem_${RUN_TS}.md"

  add_glob "${RESULTS_DIR}/figs/figure_*.pdf"
  add_glob "${RESULTS_DIR}/figs/key-results-*.pdf"
  add_glob "${RESULTS_DIR}/figs/cohort_flow_poster.*"
  add_glob "${RESULTS_DIR}/figs/key-results-spline-main-mi-ipw-abg-vbg_poster.*"

  for rel_path in \
    Results/table1_combined.csv \
    Results/table1_combined.pdf \
    Results/table_1_baseline_characteristics_analytic_cohort.csv \
    Results/table_1_baseline_characteristics_analytic_cohort.pdf \
    Results/table_2_weighted_categorical_outcomes.csv \
    Results/table_2_weighted_categorical_outcomes.pdf \
    Results/table_s1_inclusion_criteria.csv \
    Results/table_s1_inclusion_criteria.pdf \
    Results/table_s2_crude_threelevel.csv \
    Results/table_s2_crude_threelevel.pdf \
    Results/table_s3_gbm_threelevel.csv \
    Results/table_s3_gbm_threelevel.pdf \
    Results/table_s4_missingness_primary_analysis.csv \
    Results/table_s4_missingness_primary_analysis.pdf \
    Results/table_s5_mi_diagnostic_summary.csv \
    Results/table_s5_mi_diagnostic_summary.pdf \
    Results/poster_visual_qc.md \
    Results/poster_caption_text.md \
    Results/figure2_probability_standardization_audit.md \
    Results/gbm_probability_standardization_audit.md \
    Results/poster_figure_export_status.csv \
    Results/table_visual_qc.csv \
    Results/table_visual_qc.md \
    Results/publication_quality_asset_audit.csv \
    Results/publication_quality_asset_audit_summary.csv \
    Results/publication_quality_pdf_text_scan.csv \
    Results/validation_build_status.csv \
    Results/pdf_asset_presence_scan.csv \
    Results/discordance_validation_status.csv \
    Results/artifact_check_status.csv \
    Results/artifact_check_summary.csv \
    Results/artifact_provenance_manifest.csv \
    Results/canonical_asset_registry.csv \
    Results/manuscript_asset_manifest.csv \
    Results/manuscript_sync_report.md \
    Results/glyph_audit.csv \
    Results/duplicate_asset_audit.csv \
    Results/diagnostics_audit.md \
    Results/diagnostics_audit_summary.csv \
    Results/diagnostics_audit_issues.csv \
    Results/run_config.json \
    Results/run_metadata.csv \
    Results/README_CURRENT_RENDER.md \
    Results/CODE_SNAPSHOT.md
  do
    add_rel_path "${rel_path}"
  done

  sort -u "${tmp_list}" -o "${tmp_list}"
  {
    printf 'path,size_bytes,sha256\n'
    while IFS= read -r rel_path; do
      abs_path="${ROOT_DIR}/${rel_path}"
      [[ -f "${abs_path}" ]] || continue
    printf '%s,%s,%s\n' \
        "${rel_path}" \
        "$(stat -f '%z' "${abs_path}" 2>/dev/null || stat -c '%s' "${abs_path}")" \
        "$(sha256_file "${abs_path}")"
    done < "${tmp_list}"
  } > "${manifest_path}"
  printf '%s\n' "$(rel_from_root "${manifest_path}")" >> "${tmp_list}"
  sort -u "${tmp_list}" -o "${tmp_list}"

  (
    cd "${ROOT_DIR}"
    zip -q -@ "${zip_path}" < "${tmp_list}"
  )
  printf '%s  %s\n' "$(sha256_file "${zip_path}")" "${zip_path}" > "${checksum_path}"
  rm -f "${tmp_list}"
  echo "[render:bundle] ${zip_path}"
  echo "[render:bundle_manifest] ${manifest_path}"
  echo "[render:bundle_sha256] ${checksum_path}"
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
  restore_render_output_backups_on_failure "${status}"
  run_collector "${status}" "${postflight_flag}"
  if [[ "${status}" -eq 0 && ${POSTFLIGHT_PASSED} -eq 1 ]]; then
    create_clean_output_bundle
  fi
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
backup_existing_render_outputs

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
if [[ ${#QUARTO_ARGS[@]} -gt 0 ]]; then
  run_with_timing "$(detect_timing_mode)" quarto render "${QMD_PATH}" --to pdf "${QUARTO_ARGS[@]}"
else
  run_with_timing "$(detect_timing_mode)" quarto render "${QMD_PATH}" --to pdf
fi
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
publication_quality_pdf_scan_path <- file.path(results_dir, "publication_quality_pdf_text_scan.csv")

write_publication_quality_pdf_scan <- function(txt, scanner, path) {
  normalized_text <- paste(txt, collapse = " ")
  normalized_text <- gsub("-\\s+", "-", normalized_text, perl = TRUE)
  normalized_text <- gsub("\\s+", " ", normalized_text, perl = TRUE)

  scan_row <- function(check, status, severity, observed = "", detail = "") {
    data.frame(
      check = check,
      status = status,
      severity = severity,
      observed = as.character(observed),
      scanner = scanner,
      detail = detail,
      stringsAsFactors = FALSE
    )
  }

  required_labels <- c(
    "Figure 1. Cohort assembly",
    "Figure 2. Primary MI-logistic IPSW-weighted spline associations",
    "Table 1. Baseline characteristics",
    "Table 2. MI-pooled, MI-logistic IPSW-weighted 3-level categorical results",
    "Table S1. Inclusion criteria",
    "Figure S1. Covariate balance after MI logistic inverse-probability weighting",
    "Figure S2. Propensity-score overlap for MI logistic",
    "Figure S3. SHAP-style contribution summaries for MI logistic",
    "Figure S4. MI-logistic IPSW-weighted categorical associations",
    "Figure S5. Unweighted covariate-adjusted spline associations",
    "Table S2. Crude associations",
    "Table S3. GBM IPSW-weighted associations",
    "Figure S6. Covariate balance after gradient-boosted propensity weighting",
    "Figure S7. Propensity-score overlap for gradient-boosted",
    "Figure S8. SHAP-style contribution summaries for gradient-boosted",
    "Table S4. Missingness of baseline covariates",
    "Table S5. Multiple-imputation diagnostic summary"
  )

  rows <- lapply(required_labels, function(label) {
    found <- grepl(label, normalized_text, fixed = TRUE)
    scan_row(
      paste0("required_label_", gsub("[^A-Za-z0-9]+", "_", tolower(label))),
      if (found) "passed" else "failed",
      "Fatal",
      observed = if (found) "found" else "missing",
      detail = label
    )
  })

  mojibake_pattern <- paste0(
    "(",
    paste(vapply(c(0x00e2, 0x00c3, 0x00c2), intToUtf8, character(1L)), collapse = "|"),
    ")"
  )

  forbidden_checks <- list(
    list(check = "no_tbd_text", pattern = "TBD", severity = "Major", fixed = TRUE, ignore_case = TRUE),
    list(check = "no_placeholder_text", pattern = "placeholder", severity = "Major", fixed = TRUE, ignore_case = TRUE),
    list(check = "no_things_like_text", pattern = "Things like", severity = "Major", fixed = TRUE, ignore_case = TRUE),
    list(check = "no_global_shap_language", pattern = "global SHAP", severity = "Major", fixed = TRUE, ignore_case = TRUE),
    list(check = "no_negative_control_language", pattern = "negative control outcome", severity = "Major", fixed = TRUE, ignore_case = TRUE),
    list(check = "no_active_figure_3_caption", pattern = "Figure 3. ", severity = "Fatal", fixed = TRUE, ignore_case = TRUE),
    list(check = "no_replacement_character", pattern = "\uFFFD", severity = "Major", fixed = TRUE, ignore_case = FALSE),
    list(check = "no_utf8_mojibake", pattern = mojibake_pattern, severity = "Major", fixed = FALSE, ignore_case = FALSE)
  )

  for (item in forbidden_checks) {
    ignore_case <- isTRUE(item$ignore_case)
    present <- if (isTRUE(item$fixed)) {
      scan_text <- if (ignore_case) tolower(normalized_text) else normalized_text
      scan_pattern <- if (ignore_case) tolower(item$pattern) else item$pattern
      grepl(scan_pattern, scan_text, fixed = TRUE)
    } else {
      grepl(item$pattern, normalized_text, perl = TRUE, ignore.case = ignore_case)
    }
    rows[[length(rows) + 1L]] <- scan_row(
      item$check,
      if (present) "failed" else "passed",
      item$severity,
      observed = if (present) "present" else "absent",
      detail = item$pattern
    )
  }

  scan_df <- do.call(rbind, rows)
  write_csv(scan_df, path)
  invisible(scan_df)
}

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
  write_csv(
    data.frame(
      check = "pdf_text_extraction",
      status = "failed",
      severity = "Fatal",
      observed = "missing_pdf",
      scanner = "none",
      detail = pdf_file,
      stringsAsFactors = FALSE
    ),
    publication_quality_pdf_scan_path
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
  write_csv(
    data.frame(
      check = "pdf_text_extraction",
      status = "failed",
      severity = "Fatal",
      observed = "missing_scanner",
      scanner = scanner,
      detail = "Could not extract rendered PDF text.",
      stringsAsFactors = FALSE
    ),
    publication_quality_pdf_scan_path
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

publication_quality_pdf_scan <- write_publication_quality_pdf_scan(
  txt,
  scanner,
  publication_quality_pdf_scan_path
)
publication_quality_failures <- publication_quality_pdf_scan[
  publication_quality_pdf_scan$status == "failed" &
    publication_quality_pdf_scan$severity %in% c("Fatal", "Major"),
  ,
  drop = FALSE
]
if (nrow(publication_quality_failures)) {
  stop(
    "Publication-quality PDF text validation failed: ",
    paste(publication_quality_failures$check, collapse = ", "),
    "; see ",
    publication_quality_pdf_scan_path,
    call. = FALSE
  )
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
  "diagnostics_audit_issues.csv",
  "publication_quality_asset_audit.csv",
  "publication_quality_asset_audit_summary.csv",
  "publication_quality_pdf_text_scan.csv",
  "poster_visual_qc.md",
  "poster_caption_text.md",
  "figure2_probability_standardization_audit.md",
  "gbm_probability_standardization_audit.md",
  "table_visual_qc.csv",
  "table_visual_qc.md"
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
  diagnostics_audit_issues.csv = c("severity", "component", "evidence_file", "evidence_snippet"),
  publication_quality_asset_audit.csv = c(
    "asset_label", "asset_title", "asset_type", "expected_location",
    "artifact_path", "present", "label_correct", "purpose_correct",
    "caption_self_explanatory", "method_labeled", "numbers_match_manifest",
    "render_clean", "no_clipping", "no_detached_columns", "no_raw_fields",
    "glyph_safe", "grayscale_safe", "pilot_full_status_clear", "severity",
    "issue_summary", "recommended_fix", "resolved"
  ),
  publication_quality_asset_audit_summary.csv = c("severity", "n_assets", "status", "run_id", "run_ts"),
  publication_quality_pdf_text_scan.csv = c("check", "status", "severity", "observed", "scanner", "detail"),
  table_visual_qc.csv = c(
    "asset_label", "artifact_path", "page", "status", "severity",
    "min_margin_px", "left_margin_px", "right_margin_px",
    "top_margin_px", "bottom_margin_px", "detail"
  )
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
  --min-pages 40 \
  --min-images 0
POSTFLIGHT_PASSED=1
echo "[render:quarto] complete"
