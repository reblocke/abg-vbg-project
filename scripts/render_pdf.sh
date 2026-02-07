#!/usr/bin/env bash
set -euo pipefail

# Reproducible render wrapper:
# 1) verify environment consistency
# 2) render the main Quarto analysis PDF

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QMD_DEFAULT="${ROOT_DIR}/Code Drafts/ABG-VBG analysis 2025-12-11.qmd"
QMD_PATH="${1:-${QMD_DEFAULT}}"

cd "${ROOT_DIR}"
Rscript -e "source('scripts/check_env.R')"
quarto render "${QMD_PATH}" --to pdf
