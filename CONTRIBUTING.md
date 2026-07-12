# Contributing

Contributions that improve analytical correctness, reproducibility, validation, or documentation are welcome.

## Ground rules

1. Never commit patient-level data, the local codebook, manuscript correspondence, credentials, PHI/PII, or broad generated output directories.
2. Treat `Code Drafts/ABG-VBG-analysis.qmd` as the single canonical top-to-bottom analysis.
3. Keep essential analysis, table, figure, and diagnostic logic inside the canonical QMD.
4. Use project-root-safe paths and explicit seeds; do not use `setwd()`, `attach()`, or hidden global state.
5. Keep `WORKLOG.md` current after substantial implementation, validation, or rendering work.

## Development setup

```r
renv::restore()
```

```bash
Rscript --vanilla -e "source('scripts/check_env.R')"
Rscript --vanilla scripts/check_dependencies.R
./scripts/render_pdf.sh -P run_mode:pilot -P pilot_frac:0.01
```

## Dependencies

- Declare direct R dependencies in `DESCRIPTION`.
- Resolve package versions with `renv.lock`.
- Never add `install.packages()` to committed code.
- For an intentional dependency change, update the code and `DESCRIPTION`, validate a pilot, then run `renv::snapshot()` and commit the lockfile with the code.

## Output and release policy

Generated `Results/`, rendered PDF/TEX files, model state, logs, and checkpoints remain ignored. Public outputs are assembled from validated results into a curated release bundle with a file manifest and checksums.

If results change, document the affected estimands, tables, figures, and validation checks. Release candidates must pass identifier/path screening, disclosure review, static checks, and the canonical pilot render.

## Pull requests

Keep changes focused and explain what changed, why, any analytical effect, and the checks performed. Never use a catch-all stage when the working tree contains private or generated files.

This project follows `CODE_OF_CONDUCT.md`.
