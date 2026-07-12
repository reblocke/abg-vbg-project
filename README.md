# ABG versus VBG analysis

R and Quarto code for the retrospective multicenter study, “Propensity-weighted prognostic associations of hypercapnia by arterial and venous blood gas.” The analysis compares associations between arterial or venous pCO2 and hypercapnic respiratory failure, ventilatory support, and 60-day mortality while accounting for differential test ordering.

Repository: <https://github.com/reblocke/abg-vbg-project>

## Current source

- Canonical self-contained notebook: `Code Drafts/ABG-VBG-analysis.qmd`
- Canonical render wrapper: `scripts/render_pdf.sh`
- Dependency declaration: `DESCRIPTION`
- Reproducible environment: `renv.lock`
- Data-governance statement: `DATA_ACCESS.md`
- Full-run and release lineage: `PROVENANCE.md`

The repository does not track patient-level data, the local codebook, manuscript drafts, generated `Results/`, rendered PDFs/TEX, or exploratory notebook history. The tagged release contains the compact review artifacts associated with the initial-submission snapshot.

## Quick start

Run all commands from the repository root with R 4.3 or newer.

1. Restore the locked environment:

```r
renv::restore()
```

2. Validate the environment and declared dependencies:

```bash
Rscript --vanilla -e "source('scripts/check_env.R')"
Rscript --vanilla scripts/check_dependencies.R
```

3. Run the canonical 1% pilot:

```bash
./scripts/render_pdf.sh -P run_mode:pilot -P pilot_frac:0.01
```

4. Run the full analysis only when a new full-data result is required:

```bash
./scripts/render_pdf.sh -P run_mode:full -P pilot_frac:1
```

The wrapper writes generated artifacts under ignored `Results/` and performs environment, output, PDF, and publication-quality postflight checks. Dataset scope (`run_mode` and `pilot_frac`) and machine-local resource controls are the only supported execution variations.

## Data access

The notebook expects restricted TriNetX-derived inputs under local `data/`. These inputs cannot be distributed with the repository. External users can inspect the complete analysis implementation and the aggregate release artifacts but cannot rerun the full pipeline without separately authorized data access. See `DATA_ACCESS.md`.

## Public artifact policy

The Git repository contains durable source, environment, documentation, and provenance only. Generated outputs are distributed, when appropriate, as curated release assets rather than ordinary Git blobs.

Public release assets are limited to:

- the final analysis PDF;
- manuscript-facing figures and tables selected from the artifact manifest;
- compact validation and provenance summaries;
- sanitized run metadata, file manifests, and SHA-256 checksums; and
- the exact QMD snapshot used for the successful full render.

Private material includes raw data, the codebook, manuscript and cover-letter drafts, full `Results/`, per-imputation grids, model state, render logs, checkpoints, TEX, and broad reviewer packages.

## Repository map

- `Code Drafts/ABG-VBG-analysis.qmd`: canonical top-to-bottom analysis
- `Code Drafts/ticket_snapshots/`: post-hoc implementation and traceability records, not preregistration
- `scripts/`: render, dependency, environment, and postflight checks
- `docs/`: publication-quality review guidance
- `PROVENANCE.md`: executed-source, output, and release hash crosswalk
- `WORKLOG.md`: persistent implementation and validation handoff log

## Reproducibility contract

- The canonical QMD contains all essential analysis and manuscript-facing artifact logic.
- `DESCRIPTION` lists direct R dependencies; `renv.lock` resolves their versions.
- Do not add `install.packages()` to committed code.
- After an intentional dependency change, validate the pilot and then run `renv::snapshot()`; do not snapshot merely to silence unreviewed drift.
- Generated outputs must be recreated through `scripts/render_pdf.sh`, not by editing result files directly.
- Random operations use explicit seeds recorded in the notebook and release provenance.

## Citation and licensing

- Software citation metadata: `CITATION.cff`
- Code license: MIT (`LICENSE`)
- Data and generated-output boundaries: `OUTPUT_LICENSE.md`
- Contribution guidance: `CONTRIBUTING.md`
- Support: `SUPPORT.md`
