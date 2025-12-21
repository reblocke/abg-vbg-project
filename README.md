# ABG vs VBG Project

> Project with Anila Khan on the clinical / scientific significance of arterial blood gases (ABG) vs venous blood gases (VBG).  
> Repository: https://github.com/reblocke/abg-vbg-project

## Links & identifiers

- Paper (recommended): **TODO** (add DOI / journal URL / preprint)
- Code (this repo): https://github.com/reblocke/abg-vbg-project
- Reproducible release for the paper: **TODO** (create a GitHub Release and archive it to Zenodo to obtain a DOI)

## Cite this work

If you use this repository, please cite the accompanying paper (**TODO**) and/or the software release.

- See: [`CITATION.cff`](./CITATION.cff)

## Quick start (reproduce the main results)

> This repository appears to be an R/RStudio-based analysis project (it includes an `.Rproj` file).  
> The exact “one command” pipeline targets may need to be filled in once the analysis scripts are finalized.

### 1) Open the project

- Open `abg-vbg-project.Rproj` in RStudio.

### 2) Restore the analysis environment (recommended)

If you are using `renv` (recommended for reproducible R environments):

```r
install.packages("renv")
renv::restore()
```

If `renv.lock` is **not** present in the repo yet, create it once dependencies are stable:

```r
install.packages("renv")
renv::init()
renv::snapshot()
```

### 3) Run the analysis

**TODO:** Replace the examples below with the project’s real entrypoints once finalized.

```r
# Example patterns (choose one that matches your workflow)
source("Code Drafts/01_analysis.R")
rmarkdown::render("Drafts/manuscript.Rmd")
```

Expected outputs (examples):
- Generated tables/figures: `Results/`
- Intermediate datasets: `data/processed/` (recommended)

## Data access

- Location in repo: `data/`
- Data provenance: **TODO** (describe data source(s), versions, and any inclusion/exclusion criteria)
- Sensitive / human-subjects data: **DO NOT** commit PHI/PII. If any data are restricted, document:
  - how to request access,
  - what a reuser can run without access (e.g., a synthetic or de-identified sample),
  - and the expected directory layout for restricted files.

If you add any non-trivial datasets, also add:
- [`DATA_ACCESS.md`](./DATA_ACCESS.md) (template included in this repo)

## Environment

**Recommended to document once known:**
- R version (e.g., `R 4.3.x`)
- OS tested (macOS / Windows / Linux)
- Required system libraries (if any; e.g., `libxml2`, `openssl`)
- Hardware notes (if any)

Environment capture options:
- `renv` (recommended): `renv.lock`
- Container (optional): `Dockerfile` / `rocker/*` base image

## Repository layout

Top-level folders seen in the repo:

- `Code Drafts/` — exploratory scripts and early analysis drafts
- `Drafts/` — manuscript / report drafts (e.g., Rmd/Quarto)
- `Results/` — generated outputs (figures, tables, exports)
- `data/` — raw and/or intermediate data

**Recommendation:** consider adopting a standard split like:
- `src/` (reusable functions), `analysis/` (entrypoint scripts), `outputs/` (generated), `data/raw` vs `data/processed`

## Workflow overview (recommended)

**TODO:** Replace with the real pipeline once finalized.

1. Import / assemble study dataset(s) → `data/raw/`
2. Clean / derive analysis-ready dataset(s) → `data/processed/`
3. Run primary analyses → `Results/`
4. Render manuscript / report artifacts → `Results/` (or `Drafts/` build directory)

## Results mapping (paper ↔ code)

**TODO:** Fill this table so a reviewer can reproduce each paper artifact.

| Paper item | Script / notebook | Command | Output path |
|---|---|---|---|
| Fig 1 | `...` | `Rscript ...` | `Results/...` |
| Table 1 | `...` | `Rscript ...` | `Results/...` |

## Quality checks / tests (optional but recommended)

If you add automated checks, document them here. Suggested options:
- `testthat` for R unit tests (`tests/`)
- A small “smoke test” dataset in `data/example/` for fast CI runs

## License

- Code: MIT (see [`LICENSE`](./LICENSE))

If you add data, figures, or manuscripts, consider explicitly licensing those too
(e.g., CC BY 4.0 for text/figures), as they may differ from the software license.

## Funding & acknowledgements

- Funding sources: **TODO** (add grant numbers / institutional support)
- Acknowledgements: see [`ACKNOWLEDGEMENTS.md`](./ACKNOWLEDGEMENTS.md)

## Contributing & support

- Contributing guidelines: [`CONTRIBUTING.md`](./CONTRIBUTING.md)
- Support / questions: [`SUPPORT.md`](./SUPPORT.md)
- Code of conduct: [`CODE_OF_CONDUCT.md`](./CODE_OF_CONDUCT.md)

## Security

If you discover a security or privacy issue, please follow [`SECURITY.md`](./SECURITY.md).

## Maintainers / contact

- Maintainer: Brian Locke (GitHub: `reblocke`) — please open an issue in this repository.
- Co-investigator / collaborator: Anila Khan (add preferred contact if desired)

---

### Checklist to finish this README for a publication

- [ ] Add the manuscript title + DOI/preprint link
- [ ] Create a tagged release matching the paper
- [ ] Add a Zenodo (or equivalent) archived DOI for the release
- [ ] Add a one-command reproducibility target (`make all` / `Rscript run_all.R`)
- [ ] Fill Results mapping table for all figures/tables
- [ ] Add data provenance + access notes
- [ ] Pin dependencies (`renv.lock`)
