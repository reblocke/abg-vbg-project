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

## Code design and readability (optimize for humans first)
The primary performance constraint in most analysis code is *developer time* (maintenance, review, debugging),
not CPU time. Default to **clarity and correctness**, and only “pay” complexity when profiling shows it is needed.

- **Prefer “deep modules” over excessive modularity**
  - Write functions with *simple interfaces* (ideally 0–3 key arguments) that encapsulate complexity internally.
  - Avoid splitting logic into many tiny wrapper functions that add indirection without hiding complexity.
  - If a function starts needing many arguments, consider:
    - grouping parameters into a single `list()` (e.g., `control`, `spec`), or
    - passing a single data object + a small set of “key knobs”.

- **Keep cognitive load low**
  - Avoid deep nesting (multiple levels of `if`/`for`/`tryCatch` inside each other).
  - Prefer guard clauses and early returns for validation and edge cases.
  - Prefer straightforward multi-line code over clever one-liners.

- **Naming**
  - Use meaningful, explicit names for objects, functions, arguments, and intermediate results.
  - Avoid cryptic abbreviations and single-letter names in analysis code unless in very local scope
    (e.g., `i` as a loop index is fine; `df` is acceptable if there is only one primary data frame in scope).

- **Make side effects explicit**
  - Prefer functions that *return* values rather than modifying globals.
  - If a function writes files, creates plots, or depends on external state, make that clear:
    - explicit arguments like `output_path`, `fig_path`, `cache_dir`
    - clear comments on I/O and assumptions

- **Error handling**
  - Fail fast with informative messages for invalid inputs.
  - Prefer explicit checks at the top of functions (e.g., required columns, types, ranges).

## Performance and optimization (optimize wisely, only when needed)
When performance matters, use a systematic workflow: **measure → change → re-measure**, and stop when the code
is “fast enough” without compromising clarity.

- **Do not optimize prematurely**
  - Write correct, readable code first.
  - Only optimize when runtime/memory is a real constraint (large datasets, repeated runs, production loops).

- **Prefer algorithmic wins over micro-optimizations**
  - Look for unnecessary work, redundant passes, repeated joins/summaries, repeated model fits, and inefficient I/O.
  - Choose data structures deliberately:
    - vectors/matrices for heavy numeric computation
    - tibbles/data frames for analysis pipelines
    - `data.table` only when profiling shows a bottleneck where reference semantics materially help, and only with clear comments about in-place mutation.

- **Vectorization: distinguish “vectorized syntax” from “faster code”**
  - Base arithmetic and matrix operations often use compiled backends and can be very fast.
  - Functions like `apply()`, `lapply()`, and `purrr::map()` are primarily *loops for expressiveness*; do not assume they improve speed.

- **Loops are acceptable when written well**
  - In performance-critical R code, a well-written `for` loop with **pre-allocation** is often faster and clearer than building objects incrementally.
  - Avoid growing objects inside loops (e.g., repeated `c()`, repeated `bind_rows()`).
    - Prefer “accumulate in a list → combine once”.

- **Memory management**
  - Avoid unnecessary copies of large objects.
  - Pre-allocate output sizes when known.
  - Be careful with repeated intermediate tibbles in long pipelines; consider consolidating steps when memory becomes a constraint.

- **Parallelization**
  - Only parallelize when work is sufficiently coarse-grained and independent.
  - Prefer approaches that keep the user-facing API simple and preserve reproducibility.
  - Avoid introducing parallel backends unless requested or clearly justified by profiling/benchmarks.

- **Profiling and benchmarking**
  - If optimization is required:
    - Profile to find hot spots (e.g., `profvis`/`Rprof`).
    - Benchmark candidate changes (e.g., `bench`/`microbenchmark`) and verify correctness.
  - If you add profiling/benchmarking packages, do so via `renv` and show the `renv::snapshot()` command (do not run it).

## Reproducibility
- All examples must be runnable from a fresh R session when pasted into a `.R` file or Quarto chunk.
- Always show required `library()` calls.
- For random operations, set an explicit seed near the beginning: `set.seed(1234)`.
- Use `here::here()` or `fs::path()` for file paths; never hard-code absolute paths.
- This notebook is intended to execute strictly top-to-bottom. If an error occurs because a variable or function is missing, treat it as a code-ordering bug to fix (move/define earlier), not something to patch with conditional existence checks. The only intended execution variation is full dataset vs subset (pilot) size.
- When auditing PDFs, it is approved to install PDF parsers locally: `pdftools` via `renv` and `pypdf` via `pip` (project-local). Show the `renv::snapshot()` command after adding packages, but do not run it automatically.

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
- Do not introduce performance-driven complexity (Rcpp, `data.table` by-reference mutation, custom C/C++ code) unless profiling demonstrates a real bottleneck and the trade-off is justified in comments.

## References (background, for humans)
- https://www.blasbenito.com/2025/12/19/r-code-optimization-design-readability/
- https://www.blasbenito.com/2025/12/18/r-code-optimization-foundations-principles/
- https://www.blasbenito.com/2025/12/20/r-code-optimization-hardware-performance/
- https://www.blasbenito.com/2025/12/21/r-code-optimization-toolbox/
