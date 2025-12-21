# Contributing

Thanks for your interest in contributing!

## Ways to contribute
- Report bugs or reproducibility issues via GitHub Issues
- Propose improvements to documentation or analysis clarity
- Add tests, small example datasets, or CI checks
- Improve the results-to-code mapping table in `README.md`

## Ground rules
1. **Do not commit sensitive data.** No PHI/PII, access tokens, or credentials.
2. Keep outputs out of version control unless they are small, stable, and intended (e.g., a final figure for a paper).
3. Prefer reproducible workflows:
   - pin R package versions with `renv`
   - keep analysis entrypoints scripted (avoid “click-only” runs)

## Development setup (suggested)
- Install R and RStudio
- Open `abg-vbg-project.Rproj`
- If using `renv`:
  ```r
  install.packages("renv")
  renv::restore()
  ```

## Style
- Prefer clear file names (e.g., `01_import.R`, `02_clean.R`, `03_model.R`)
- Put reusable functions in a shared file (e.g., `src/utils.R`)
- Keep parameters configurable (e.g., at top of script or via a config file)

## Pull requests
- Create a branch from `main`
- Keep PRs focused and describe:
  - what changed
  - why
  - how to reproduce / test
- If results change, note which tables/figures are affected.

## Code of Conduct
This project follows [`CODE_OF_CONDUCT.md`](./CODE_OF_CONDUCT.md).
