# Data access and provenance

This project analyzes restricted TriNetX-derived patient-level data under applicable data-use and institutional controls. Patient-level inputs and the local codebook are not public repository artifacts.

## Local inputs

The canonical notebook `Code Drafts/ABG-VBG-analysis.qmd` expects:

- `data/full_db.dta`: primary Stata-format analysis input;
- `data/full_trinetx.rdata`: legacy local comparison snapshot, when needed; and
- `data/codebookr.docx`: governed local data dictionary/codebook.

The entire `data/` directory is ignored by Git. Do not commit raw extracts, row-level derivatives, codebooks, credentials, or PHI/PII.

## Required private provenance

The data custodian or analyst should retain, in approved private storage:

- extract or refresh date;
- TriNetX query/cohort-definition source;
- inclusion and exclusion criteria;
- any preprocessing performed before the canonical notebook begins; and
- the applicable data-use, disclosure, and small-cell rules.

## Public reproducibility boundary

The public repository provides the complete statistical implementation, locked R environment, and selected aggregate review outputs. It does not provide a synthetic dataset and cannot reproduce the full analysis without separately authorized access to the restricted inputs.

Release artifacts must pass direct-identifier, row-level-data, absolute-path, and disclosure review before publication. Screening flags are review prompts and do not replace institutional or data-use requirements.
