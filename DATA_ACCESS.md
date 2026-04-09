# Data Access & Provenance

This repository expects restricted local patient-level inputs in `data/`. The current notebooks are built around a direct local file layout rather than a public sample-data workflow.

## Current local inputs

- `data/full_db.dta`: the primary Stata-format input expected by the maintained analysis notebooks
- `data/full_trinetx.rdata`: a local legacy RData snapshot retained for older workflows and comparison
- `data/codebookr.docx`: local codebook / data dictionary artifact

## Current notebook expectations

- The maintained Quarto notebooks read directly from `data/`, not from `data/raw/` and `data/processed/`.
- The primary notebook is `Code Drafts/ABG-VBG analysis 2026-2-28.qmd`.
- If the local data layout changes, update `README.md`, this file, and any render helpers in the same change.

## Restrictions / sensitive data

- These files are restricted and should be treated as governed patient-level data.
- Do **not** commit raw patient-level extracts, PHI/PII, credentials, or derivative files that would expose restricted data.
- Access should remain consistent with the governing TriNetX / local institutional data-use and review constraints.

## Provenance notes to capture outside the repo when needed

- extract date or refresh date
- query or cohort definition source
- inclusion / exclusion criteria
- any preprocessing performed before the notebook begins

## Public reproducibility note

- This repository does not currently include a synthetic or de-identified example dataset.
- External reviewers can inspect code, manuscript drafts, and derived non-patient-level outputs in `Results/`, but they cannot reproduce the full pipeline without approved local access to the restricted input files.
