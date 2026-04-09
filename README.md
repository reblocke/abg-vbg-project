# ABG vs VBG Project

Retrospective clinical analysis comparing prognostic associations of hypercapnia measured by arterial blood gas (ABG) and venous blood gas (VBG), implemented in R + Quarto.

Repository: <https://github.com/reblocke/abg-vbg-project>

## Current state (as of April 8, 2026)

- Primary analysis notebook: `Code Drafts/ABG-VBG analysis 2026-2-28.qmd`
- Secondary maintained notebook: `Code Drafts/ABG-VBG analysis 2025-12-11.qmd`
- Reproducible render wrapper: `scripts/render_pdf.sh` (now defaults to the 2026-2-28 notebook)
- Latest rendered analysis PDF: `Code Drafts/ABG-VBG-analysis-2026-2-28.pdf`
- Latest `Results/` snapshot: pilot run `run_id = 20260301_131122`; see `Results/run_metadata.csv`
- Run settings snapshot for that output set: `Results/run_config.json` (includes machine-specific absolute paths from the render environment)
- Most recently modified manuscript draft: `Drafts/04-08-25 ABG_VBG_Rough Draft BL.docx` (mtime 2026-04-08)

## Start here for review

- Code: start with `Code Drafts/ABG-VBG analysis 2026-2-28.qmd`, then compare against `Code Drafts/ABG-VBG analysis 2025-12-11.qmd` if you need continuity with the older December workflow.
- Outputs: use `Results/run_metadata.csv`, `Results/diagnostics_audit.md`, `Results/plot_registry.csv`, `Results/table_summary_adjusted_threelevel.csv`, `Results/Table1.docx`, `Results/Table2.docx`, and `Results/figs/` as the main review surfaces.
- Manuscript: use `Drafts/04-08-25 ABG_VBG_Rough Draft BL.docx` first, then older draft files in `Drafts/` only for revision history.

## Quick start

1. Open `abg-vbg-project.Rproj` in RStudio, or run commands from the repo root.
2. Restore the R environment:

```r
renv::restore()
```

3. Run the environment preflight:

```bash
Rscript -e "source('scripts/check_env.R')"
```

4. Render the current primary notebook:

```bash
quarto render "Code Drafts/ABG-VBG analysis 2026-2-28.qmd" --to pdf
```

Or use the wrapper:

```bash
./scripts/render_pdf.sh
```

Pilot render example matching the current `Results/` snapshot:

```bash
quarto render "Code Drafts/ABG-VBG analysis 2026-2-28.qmd" --to pdf -P run_mode:pilot -P pilot_frac:0.01
```

If you need to reproduce the older December notebook for comparison:

```bash
quarto render "Code Drafts/ABG-VBG analysis 2025-12-11.qmd" --to pdf
```

## Repository map

- `Code Drafts/`: the maintained Quarto analysis notebooks and rendered notebook PDFs
- `Code Drafts/Prior versions/`: archived notebook history; use only for provenance or older branching logic
- `Drafts/`: manuscript and abstract drafts
- `Results/`: generated review artifacts, including tables, figures, diagnostics, runtime logs, and output crosswalks
- `data/`: restricted local input files and local codebook artifacts
- `scripts/`: reproducibility helpers (`check_env.R`, `render_pdf.sh`)
- `R/`: standalone helper code (`R/diagnostics_audit.R`)

## Analysis coverage

The primary notebook `Code Drafts/ABG-VBG analysis 2026-2-28.qmd` covers:

- Cohort setup and schema/type normalization from TriNetX-derived extracts in `data/`
- Unweighted ABG/VBG outcome analyses
- Non-MI IPSW using GBM propensity models
- MI + IPSW analyses with pooled estimates
- Restricted cubic spline outcome modeling
- Diagnostics export and audit outputs to `Results/`
- Manuscript-oriented tables and figure registries for review

The December notebook remains useful as a stable comparison point, but it is no longer the primary entrypoint.

## Results-to-manuscript mapping

Use these as the main crosswalk from analysis outputs into the manuscript:

- Baseline tables: `Results/Table1.docx`, `Results/Table2.docx`, `Results/Table1_ABG_VBG.docx`
- Core adjusted 3-level OR summary: `Results/table_summary_adjusted_threelevel.csv` and the cohort-specific split CSVs
- Plot lookup and figure registry: `Results/plot_registry.csv`
- Diagnostics summary: `Results/diagnostics_summary.csv`, `Results/diagnostics_audit.md`, `Results/runtime_summary.csv`
- Figure files: `Results/figs/`

Note: figure filenames in `Results/figs/` can include chunk index suffixes; use `Results/plot_registry.csv` as the canonical crosswalk.

## Stable outputs vs transient scratch files

- Treat the CSV, DOCX, PNG, PDF, JSON, and Markdown files in `Results/` as the stable review artifacts.
- MI scratch files such as `Results/mi_abg_vbg_mids.rds`, `Results/subset_data_pre_mi.rds`, `Results/mi_logistic_ps_*.rds`, and `Results/mi_weights/` are transient by design and may be auto-cleaned during renders.
- If you need those transient MI artifacts for debugging, render with `KEEP_MI_TRANSIENT=1`.

## Data access and governance

- Data source context: TriNetX-derived patient data under local access restrictions / data use controls
- Individual-level patient data are restricted and not shareable in this repository
- Keep PHI/PII out of version control
- See `DATA_ACCESS.md` for the current local file expectations and provenance notes

## Reproducibility and checks

- Dependency lockfile: `renv.lock`
- Preflight check before long renders: `Rscript -e "source('scripts/check_env.R')"`
- The checked-in `Results/` snapshot reflects a pilot run; rerender the primary notebook for a fresh production run
- No `testthat` suite is currently present in this repository

## Citation, license, and support

- Citation metadata: `CITATION.cff`
- Code license: MIT (`LICENSE`)
- Contributing guide: `CONTRIBUTING.md`
- Support: `SUPPORT.md`
- Code of conduct: `CODE_OF_CONDUCT.md`
- Acknowledgements: `ACKNOWLEDGEMENTS.md`

## Maintainers

- Brian Locke (`reblocke`)
- Anila Mehta / collaborators listed in manuscript drafts
