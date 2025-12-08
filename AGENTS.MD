# AGENTS.md

## Project overview
- This repository is an R- and Quarto-based analysis project for clinical and machine learning studies.
- The primary language is **R**. Do not suggest Python, Julia, or SQL implementations unless explicitly asked.

## Environment
- Analyses run under R ≥ 4.3 on macOS/Linux.
- Package management uses `renv`. When adding packages, show the `renv::snapshot()` command but do not run it automatically.
- Never put `install.packages()` in committed code.

## R style and packages
- Use tidyverse-style code for data manipulation: `dplyr`, `tidyr`, `stringr`, `purrr`, `forcats`.
- Use `ggplot2` for plots.
- Prefer pipes (`|>`) and clear, descriptive variable names.
- Avoid `attach()`, `setwd()`, and `<<-`. Use explicit data references.
- Use explicit namespaces in package-like code when ambiguity is possible, e.g. `dplyr::mutate`.

## Reproducibility
- All examples must be runnable from a fresh R session when pasted into a `.R` file or Quarto chunk.
- Always show required `library()` calls.
- For random operations, set an explicit seed near the beginning: `set.seed(1234)`.
- Use `here::here()` or `fs::path()` for file paths; never hard-code absolute paths.

## Quarto
- Reports are written in Quarto (`.qmd`), not R Markdown.
- Use chunk options via comment YAML (e.g. `#| label:`, `#| fig-cap:`) instead of inline `echo = FALSE` flags where possible.
- Label chunks with informative names that match their purpose (e.g. `data-cleaning`, `fit-primary-model`).

## Modeling
- Use modern modeling interfaces: `glm()`, `lme4::lmer()/glmer()`, `survival`, `brms`, `tidymodels`, etc., according to the context.
- Prefer returning tidy outputs with `broom` / `broom.mixed` where useful.
- Include basic diagnostics when proposing models (residual plots, checks for convergence, etc.).

## Tests and checks
- Use `testthat` for unit tests under `tests/testthat`.
- When creating or modifying R functions, propose new or updated tests and indicate the command to run them (for example, `devtools::test()`).

## What not to do
- Do not add interactive-only calls (`View()`, `fix()`) to analysis pipelines.
- Do not introduce hidden global state or non-determinism without clear explanation.
- Do not restructure code into new frameworks without being asked (e.g., don’t switch to `targets`/`drake` unless requested).