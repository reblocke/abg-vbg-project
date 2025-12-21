# Data Access & Provenance

This repository contains a `data/` directory. Please document the following as the project matures.

## What data are used?
- Dataset name(s):
- Source(s) / URL(s) / DOI(s):
- Version(s) / release date(s):
- Any inclusion/exclusion criteria:

## Where should data live locally?
Recommended layout:

- `data/raw/` — original immutable inputs (not edited)
- `data/processed/` — derived analysis-ready datasets
- `data/example/` — small synthetic/de-identified sample to run tests/CI

## Restrictions / sensitive data
If any data are restricted (e.g., human-subject data, PHI/PII):
- Do **not** commit restricted files.
- Describe the access pathway (DAC/DUA/IRB, etc.).
- Provide a way to run the pipeline without restricted data (e.g., synthetic subset).

## Checksums (optional)
For large or controlled datasets, consider recording checksums:
- filename
- SHA256
- source version
