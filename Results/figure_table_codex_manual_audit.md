# Codex Manual Figure/Table Audit

## Accepted render
- Date: 2026-04-23 10:53 MDT
- Run mode: `pilot`
- Pilot fraction: `0.01`
- Accepted log: `Results/render_logs/render_20260423_104253.log`
- Accepted PDF: `Code Drafts/ABG-VBG-analysis-2026-4-21.pdf`
- PDF pages: `609`

## Validation checks
- `Results/pdf_asset_presence_scan.csv`: `61/61` checks passed
- `Results/discordance_validation_status.csv`: `22` completed, `2` skipped, `0` required failures
- `Results/discordance_marginal_standardized_alignment.csv`: `804` overlapping manuscript-vs-discordance rows with zero differences in `eta`, `var_eta`, `p`, `p_LCL`, and `p_UCL`
- Static preflight passed on the accepted source state:
  - `bash -n scripts/render_pdf.sh`
  - Quarto purl/parse check for `Code Drafts/ABG-VBG analysis 2026-4-21.qmd`
  - `Rscript --vanilla -e "source('scripts/check_env.R')"`
  - `Rscript --vanilla scripts/check_dependencies.R`

## Displays reviewed
- Figure 1: pass
- Figure 2: pass
- Table 1: pass
- Table 2: pass
- Table S1: pass
- Figure S1: pass
- Figure S2: pass
- Figure S3: pass
- Figure S4: pass
- Figure S5: pass
- Table S2: pass
- Table S3: pass
- Figure S6: pass
- Figure S7: pass
- Figure S8: pass
- Table S4: pass
- Table S5: pass
- Discordance standardization figure: pass for figure/table content review; notebook code echo excluded from scope
- Discordance tail/support figure: pass for figure/table content review; notebook code echo excluded from scope
- Discordance current summary table: pass for figure/table content review; notebook code echo excluded from scope
- Discordance interpretation summary table: pass for figure/table content review; notebook code echo excluded from scope
- Discordance IMV heterogeneity figure: pass for figure/table content review; notebook code echo excluded from scope

## Concrete defects fixed during the audit loop
- Replaced raw covariate/model-term labels in loveplots and SHAP panels with human-readable display labels.
- Replaced raw internal manuscript/supplement table headers with presentation labels.
- Replaced raw discordance table headers with presentation labels.
- Replaced raw discordance interpretation status tokens such as `partially_supported` and `not_supported` with readable labels.
- Harmonized discordance current-summary terminology so `cat3` renders as `3-level category`.
- Wrapped long loveplot titles to prevent clipping in Figure S6.
- Polished the IMV heterogeneity figure with readable facet labels, ordered CO2 categories, readable legend labels, and a deliberate color palette.
- Reordered paired ABG/VBG categorical tables outcome-first so paired rows now read `IMV: ABG, VBG`, then `NIV: ABG, VBG`, across Table 2 and analogous supplement/summary tables.
- Switched discordance marginal-standardized spline curves back onto the manuscript common-source Rubin-pooled link-scale estimator and confirmed exact overlap on the shared NIV/IMV grids.
- Clarified the pilot propensity-overlap subtitle so the 1% render explicitly notes that pilot mode uses `20` imputations while full runs use `80`.
- Declared `stringr` in `DESCRIPTION` because the notebook now uses `stringr::str_wrap()` in display code.

## Notes
- The discordance section still renders as a notebook-style technical appendix with echoed code below some plots. That notebook code-echo policy was explicitly out of scope for this ticket and is excluded from the pass criteria above.
- Temporary audit extracts live under `tmp/codex_figure_table_audit/` and were left unstaged.
