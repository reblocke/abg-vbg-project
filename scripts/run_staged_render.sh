#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QMD_PATH="${ROOT_DIR}/Code Drafts/ABG-VBG-analysis.qmd"
TARGET="0.05"
MIN_DISK_GB="20"
MAX_PEAK_RSS_GB="12"

usage() {
  cat <<USAGE
Usage: scripts/run_staged_render.sh [--qmd PATH] [--target FRACTION|full] [--min-disk-gb N] [--max-peak-rss-gb N]

Runs one resource-gated staged render and writes Results/render_escalation_status.csv.
The script intentionally runs only one target at a time; use the generated next
recommendation before launching the next larger subset.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --qmd)
      QMD_PATH="$2"
      shift 2
      ;;
    --target)
      TARGET="$2"
      shift 2
      ;;
    --min-disk-gb)
      MIN_DISK_GB="$2"
      shift 2
      ;;
    --max-peak-rss-gb)
      MAX_PEAK_RSS_GB="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

cd "${ROOT_DIR}"

if [[ ! -f "${QMD_PATH}" ]]; then
  echo "[staged-render:error] QMD not found: ${QMD_PATH}" >&2
  exit 2
fi

target_fraction() {
  Rscript --vanilla -e '
    x <- tolower(commandArgs(TRUE)[1])
    if (x %in% c("full", "1", "1.0", "100", "100%")) {
      cat("1\n")
    } else {
      x <- sub("%$", "", x)
      val <- suppressWarnings(as.numeric(x))
      if (!is.finite(val) || val <= 0) stop("Invalid target: ", x, call. = FALSE)
      if (val > 1) val <- val / 100
      if (val <= 0 || val > 1) stop("Target must be in (0, 1] or full.", call. = FALSE)
      cat(format(val, scientific = FALSE, trim = TRUE), "\n", sep = "")
    }
  ' "${TARGET}"
}

disk_free_gb() {
  df -k . | awk 'NR == 2 { printf "%.2f\n", $4 / 1024 / 1024 }'
}

current_ram_pressure_note() {
  if command -v vm_stat >/dev/null 2>&1; then
    vm_stat | awk '
      /Pages free/ {gsub("\\.","",$3); free=$3}
      /Pages speculative/ {gsub("\\.","",$3); spec=$3}
      /Pages occupied by compressor/ {gsub("\\.","",$5); comp=$5}
      END {printf "free_pages=%s speculative_pages=%s compressor_pages=%s", free, spec, comp}
    '
  else
    printf "vm_stat_unavailable"
  fi
}

safe_lock_component() {
  printf '%s' "$1" | tr -cs 'A-Za-z0-9._-' '_' | sed 's/^_*//; s/_*$//'
}

mkdir -p Results/render_logs
qmd_basename="$(basename "${QMD_PATH}")"
qmd_lock_slug="$(safe_lock_component "${qmd_basename}")"
lock_dir="Results/render_logs/staged_render_${qmd_lock_slug}.lock"
if ! mkdir "${lock_dir}" 2>/dev/null; then
  lock_pid="$(cat "${lock_dir}/pid" 2>/dev/null || true)"
  if [[ "${lock_pid}" =~ ^[0-9]+$ ]] && kill -0 "${lock_pid}" 2>/dev/null; then
    echo "[staged-render:error] A staged render for ${qmd_basename} appears to already be running under PID ${lock_pid}." >&2
    exit 2
  fi
  echo "[staged-render:lock] Removing stale staged-render lock: ${lock_dir}" >&2
  rm -rf "${lock_dir}"
  if ! mkdir "${lock_dir}" 2>/dev/null; then
    echo "[staged-render:error] Could not acquire staged-render lock: ${lock_dir}" >&2
    exit 2
  fi
fi
printf '%s\n' "$$" > "${lock_dir}/pid"
printf '%s\n' "${QMD_PATH}" > "${lock_dir}/qmd"
cleanup_lock() {
  rm -rf "${lock_dir}"
}
trap cleanup_lock EXIT

running_render_matches="$(
  pgrep -fl "quarto.*render|render_pdf.sh" 2>/dev/null |
    awk -v self="$$" -v qmd="${qmd_basename}" 'NF && $1 != self && index($0, qmd) {print}' || true
)"
running_render_count="$(printf '%s\n' "${running_render_matches}" | awk -v self="$$" 'NF && $1 != self {n++} END {print n + 0}')"
if [[ "${running_render_count}" != "0" ]]; then
  echo "[staged-render:error] A matching render for ${qmd_basename} appears to already be running." >&2
  printf '%s\n' "${running_render_matches}" >&2
  exit 2
fi

free_before="$(disk_free_gb)"
echo "[staged-render:resource] disk_free_gb_before=${free_before}"
echo "[staged-render:resource] $(current_ram_pressure_note)"
Rscript --vanilla -e '
  free <- as.numeric(commandArgs(TRUE)[1])
  min_free <- as.numeric(commandArgs(TRUE)[2])
  if (!is.finite(free) || free < min_free) {
    stop("Insufficient free disk for staged render: ", free, " GiB available; require >= ", min_free, " GiB.", call. = FALSE)
  }
' "${free_before}" "${MIN_DISK_GB}"

frac="$(target_fraction)"
if [[ "${frac}" == "1" ]]; then
  quarto_args=(-P run_mode:full -P pilot_frac:1)
else
  quarto_args=(-P run_mode:pilot -P "pilot_frac:${frac}")
fi

echo "[staged-render:target] target=${TARGET} fraction=${frac}"
echo "[staged-render:static] bash -n scripts/render_pdf.sh"
bash -n scripts/render_pdf.sh
echo "[staged-render:static] QMD purl/parse"
Rscript --vanilla -e "tmp <- tempfile(fileext = '.R'); invisible(knitr::purl('${QMD_PATH}', output = tmp, quiet = TRUE)); expr <- parse(tmp); cat('parsed_expressions=', length(expr), '\n', sep = '')"
echo "[staged-render:static] check_env"
Rscript --vanilla -e "source('scripts/check_env.R')"
echo "[staged-render:static] check_dependencies"
Rscript --vanilla scripts/check_dependencies.R
echo "[staged-render:static] git diff --check"
git diff --check -- "${QMD_PATH}" WORKLOG.md scripts/render_pdf.sh scripts/check_pdf_assets.R scripts/render_escalation_check.R scripts/run_staged_render.sh

echo "[staged-render:render] ./scripts/render_pdf.sh ${QMD_PATH} ${quarto_args[*]}"
stage_log="Results/render_logs/staged_render_$(date '+%Y%m%d_%H%M%S').log"
set +e
./scripts/render_pdf.sh "${QMD_PATH}" "${quarto_args[@]}" 2>&1 | tee "${stage_log}"
render_status=${PIPESTATUS[0]}
set -e
render_ts="$(awk '/^\[render:start\]/ {next} /^\[render:log\]/ {sub(/^.*render_/, "", $0); sub(/\.log$/, "", $0); print; exit}' "${stage_log}")"
if [[ -z "${render_ts}" ]]; then
  render_ts="$(ls -t Results/render_logs/render_*.log 2>/dev/null | head -n 1 | sed 's/^.*render_//; s/\.log$//')"
fi

if [[ "${render_status}" -ne 0 ]]; then
  echo "[staged-render:render] wrapper_status=${render_status}"
  Rscript --vanilla scripts/render_escalation_check.R \
    --target "${TARGET}" \
    --qmd "${QMD_PATH}" \
    --render-ts "${render_ts}" \
    --status fail || true
  exit "${render_status}"
fi

echo "[staged-render:post] render_ts=${render_ts}"
Rscript --vanilla scripts/render_escalation_check.R \
  --target "${TARGET}" \
  --qmd "${QMD_PATH}" \
  --render-ts "${render_ts}" \
  --status pass

peak_rss_gb="$(Rscript --vanilla -e '
  status <- utils::read.csv("Results/render_escalation_status.csv", stringsAsFactors = FALSE)
  row <- tail(status, 1)
  cat(row$peak_rss_gb)
')"
Rscript --vanilla -e '
  peak <- as.numeric(commandArgs(TRUE)[1])
  max_peak <- as.numeric(commandArgs(TRUE)[2])
  if (is.finite(peak) && peak > max_peak) {
    stop("Peak sampled RSS exceeded staged-render threshold: ", peak, " GiB > ", max_peak, " GiB.", call. = FALSE)
  }
' "${peak_rss_gb}" "${MAX_PEAK_RSS_GB}"

echo "[staged-render:complete] target=${TARGET} render_ts=${render_ts} peak_rss_gb=${peak_rss_gb}"
