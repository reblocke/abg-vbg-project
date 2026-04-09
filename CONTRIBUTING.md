# Contributing

Thanks for your interest in contributing!

## Ways to contribute
- Report bugs or reproducibility issues via GitHub Issues
- Propose improvements to documentation or analysis clarity
- Add tests, small example datasets, or CI checks
- Improve the current-state and results-to-manuscript pointers in `README.md`

## Ground rules
1. **Do not commit sensitive data.** No PHI/PII, access tokens, or credentials.
2. Keep outputs out of version control unless they are small, stable, and intended (e.g., a final figure for a paper).
3. Prefer reproducible workflows:
   - pin R package versions with `renv`
   - keep analysis entrypoints scripted (avoid “click-only” runs)

## Development setup (suggested)
- Install R and RStudio
- Open `abg-vbg-project.Rproj`
- Restore packages from lockfile:
  ```r
  renv::restore()
  ```
- The primary analysis entrypoint is `Code Drafts/ABG-VBG analysis 2026-2-28.qmd`
- The render wrapper `scripts/render_pdf.sh` runs environment preflight and renders that notebook by default

## Dependency workflow (required)
1. Use `renv.lock` as the canonical R dependency snapshot.
2. Before long renders, run:
   ```bash
   Rscript -e "source('scripts/check_env.R')"
   ```
3. If dependencies change:
   ```r
   renv::snapshot()
   ```
4. Commit `renv.lock` in the same PR as code changes that require new packages.
5. Do not add `install.packages()` calls to project scripts or notebooks.

Python sidecars (optional):
- If Python helper scripts become part of routine workflow, manage them with `uv`.
- Keep that scope separate from R dependency management (`renv` remains authoritative for analysis execution).

## Style
- Prefer keeping the current main analysis in the newest maintained notebook under `Code Drafts/`
- Use dated notebook names only when freezing a real snapshot; do not rename older notebooks in place
- Put reusable helper code in `R/` or `scripts/` instead of duplicating it across notebooks when practical
- Keep parameters explicit at the top of notebooks or in a small helper script rather than relying on hidden session state
- If you update which notebook, manuscript draft, or output snapshot is considered current, update `README.md` in the same change

## Pull requests
- Create a branch from `main`
- Keep PRs focused and describe:
  - what changed
  - why
  - how to reproduce / test
- If results change, note which tables/figures are affected.
- If you need transient MI scratch artifacts for debugging, document that and render with `KEEP_MI_TRANSIENT=1`.

## Code of Conduct
This project follows [`CODE_OF_CONDUCT.md`](./CODE_OF_CONDUCT.md).
