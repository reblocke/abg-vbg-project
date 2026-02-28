# ABG vs VBG Project

Retrospective clinical analysis comparing prognostic associations of hypercapnia measured by arterial blood gas (ABG) and venous blood gas (VBG), implemented in R + Quarto.

Repository: <https://github.com/reblocke/abg-vbg-project>

## Current status (as of February 27, 2026)

- Active analysis notebook: `Code Drafts/ABG-VBG analysis 2025-12-11.qmd`
- Secondary working notebook (logistic-focused branch): `Code Drafts/logistic/ABG VBG analysis logistic full run 2026-2-6.qmd`
- Reproducible render entrypoint: `scripts/render_pdf.sh`
- Latest manuscript draft: `Drafts/02-17-2026 ABG_VBG_RoughDraft.docx`
- Latest manuscript draft state: rough draft with placeholder sections (e.g., abstract and some figure/table insert points still marked TODO in the `.docx`)

## Quick start (reproduce analysis PDF)

1. Open `abg-vbg-project.Rproj` in RStudio (or run commands from repo root).
2. Restore the R environment:

```r
renv::restore()
```

3. Run environment preflight:

```bash
Rscript -e "source('scripts/check_env.R')"
```

4. Render the main notebook:

```bash
quarto render "Code Drafts/ABG-VBG analysis 2025-12-11.qmd" --to pdf
```

Or use the wrapper (preflight + render):

```bash
./scripts/render_pdf.sh
```

Pilot render example:

```bash
quarto render "Code Drafts/ABG-VBG analysis 2025-12-11.qmd" --to pdf -P run_mode:pilot -P pilot_frac:0.05
```

## Repository audit snapshot

- Quarto notebooks (`.qmd`): 20 total
- Active notebooks: 2 (listed above)
- Archived notebook history: `Code Drafts/Prior versions/`
- R scripts (`.R`): 3 (`R/diagnostics_audit.R`, `scripts/check_env.R`, `renv/activate.R`)
- Render shell script: `scripts/render_pdf.sh`
- Generated outputs: `Results/` (tables, diagnostics, plot files, run logs)

## Main notebook coverage

`Code Drafts/ABG-VBG analysis 2025-12-11.qmd` includes:

- Cohort setup and schema/type normalization from TriNetX-derived extracts in `data/`
- Unweighted ABG/VBG outcome analyses
- Non-MI IPSW using GBM propensity models
- MI + IPSW analyses with pooled estimates
- Restricted cubic spline outcome modeling
- Diagnostics export and audit outputs (CSV + figures) to `Results/`
- Manuscript-oriented output tables (`Results/Table1.docx`, `Results/Table2.docx`, plus companion CSVs)

## Manuscript mapping notes

Latest manuscript draft reviewed: `Drafts/02-17-2026 ABG_VBG_RoughDraft.docx`.

The current draft narrative (ABG/VBG hypercapnia associations, IPSW, MI, spline analyses) is directionally aligned with the active Quarto workflow. For figure/table assembly, use this mapping:

- Baseline tables: `Results/Table1.docx`, `Results/Table2.docx`, `Results/Table1_ABG_VBG.docx`
- Core adjusted 3-level OR summary: `Results/table_summary_adjusted_threelevel.csv` and cohort-specific split CSVs
- Non-MI and MI diagnostics/plots: `Results/figs/` with lookup in `Results/plot_registry.csv`
- Supplement diagnostics tables: `Results/diagnostics_summary.csv`, `Results/diagnostics_audit.md`, `Results/diagnostics_audit_issues.csv`

Note: figure filenames in `Results/figs/` can include chunk index suffixes; use `Results/plot_registry.csv` as the canonical crosswalk.

## Data access and governance

- Data source context: TriNetX data under data use agreement (per manuscript draft)
- Individual-level patient data are restricted and not shareable in this repository
- Keep PHI/PII out of version control
- Additional access notes/template: `DATA_ACCESS.md`

## Reproducibility and checks

- Dependency lockfile: `renv.lock`
- Preflight check before long renders: `Rscript -e "source('scripts/check_env.R')"`
- No `testthat` suite is currently present in this repository

## Project structure

- `Code Drafts/`: active and historical Quarto analysis notebooks
- `Drafts/`: manuscript and abstract drafts
- `Results/`: generated figures/tables/diagnostics/logs
- `data/`: project data inputs (restricted/raw-derived)
- `scripts/`: reproducibility helper scripts
- `R/`: standalone R helper(s)

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
