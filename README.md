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
Rscript --vanilla -e "source('scripts/check_env.R')"
```

4. Run the direct-dependency audit:

```bash
Rscript --vanilla scripts/check_dependencies.R
```

5. Render the current primary notebook from the repo root via the canonical wrapper:

```bash
./scripts/render_pdf.sh
```

The wrapper is the only sanctioned validation entrypoint. It writes a timestamped combined stdout/stderr log to `Results/render_logs/` and preserves `/usr/bin/time -l` output for the render.

Machine-local MI resource overrides are available when needed for operational troubleshooting:

```bash
ABGVBG_MI_RAM_GB=8 ABGVBG_MI_BATCH_START=1 ./scripts/render_pdf.sh
```

Pilot render example matching the current `Results/` snapshot:

```bash
./scripts/render_pdf.sh -P run_mode:pilot -P pilot_frac:0.01
```

If you need to reproduce the older December notebook for comparison:

```bash
./scripts/render_pdf.sh "Code Drafts/ABG-VBG analysis 2025-12-11.qmd"
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
- MI scratch files such as `Results/mi_abg_vbg_mids.rds`, `Results/subset_data_pre_mi.rds`, `Results/mi_logistic_ps_*.rds`, and `Results/mi_weights/` are transient by design and are auto-cleaned during renders.

## Data access and governance

- Data source context: TriNetX-derived patient data under local access restrictions / data use controls
- Individual-level patient data are restricted and not shareable in this repository
- Keep PHI/PII out of version control
- See `DATA_ACCESS.md` for the current local file expectations and provenance notes

## Reproducibility and checks

- Direct dependency manifest: `DESCRIPTION`
- Dependency lockfile: `renv.lock`
- Canonical render root: the repo root only. Do not validate renders from `Code Drafts/` or any other subdirectory.
- Preflight check before long renders: `Rscript --vanilla -e "source('scripts/check_env.R')"`
- Direct dependency audit before long renders: `Rscript --vanilla scripts/check_dependencies.R`
- Canonical render command: `./scripts/render_pdf.sh` from the repo root
- Render contract: one canonical report path only. Do not add alternate render modes that change figure embedding, table inclusion, scratch retention, or other report content/presentation.
- The only sanctioned execution variation is dataset scope (`run_mode` with `pilot_frac`) plus machine-local path/resource controls that do not change analytical outputs.
- The checked-in `Results/` snapshot reflects a pilot run; rerender the primary notebook for a fresh production run
- No `testthat` suite is currently present in this repository

## Dependency workflow

- `DESCRIPTION` is the canonical list of direct R dependencies used by the notebook and reproducibility scripts.
- `renv.lock` is the canonical fully resolved environment that collaborators restore onto a machine.
- Lockfile-first recovery workflow on a new or drifted machine:
  - `Rscript --vanilla -e "source('renv/activate.R'); renv::restore(clean = TRUE, prompt = FALSE)"`
  - `Rscript --vanilla -e "source('scripts/check_env.R')"`
  - `Rscript --vanilla scripts/check_dependencies.R`
  - `./scripts/render_pdf.sh -P run_mode:pilot -P pilot_frac:0.01`
  - only after a validated render, `Rscript --vanilla -e "source('renv/activate.R'); renv::snapshot(prompt = FALSE)"` if dependencies intentionally changed
- Approved workflow for any dependency change:
  - update code,
  - add or remove the direct dependency in `DESCRIPTION`,
  - install only the intended package change with `renv::install(...)`,
  - run `Rscript --vanilla scripts/check_dependencies.R`,
  - run a 1% pilot render through `./scripts/render_pdf.sh`,
  - run `Rscript --vanilla -e "source('renv/activate.R'); renv::snapshot(prompt = FALSE)"`,
  - commit code, `DESCRIPTION`, and `renv.lock` together.
- If `renv::status()` shows version drift but the dependency audit passes and declared packages are installed, validate with a wrapper pilot render and only then snapshot the intentional working state.

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
