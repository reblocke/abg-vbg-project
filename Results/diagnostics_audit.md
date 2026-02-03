# Diagnostics Audit

## Executive Summary
- Run mode: pilot; pilot_frac: 0.001; m: 80; maxit: 20
- Runtime total (sec): 236.540
- MI batch status: batches=0; m_batch=NA; failures=NA
- Balance: ABG max|SMD|=0.282; VBG max|SMD|=0.210
- Separation flags: 1151 / 1324

## Artifact Inventory (Found / Missing)

- runtime_log.csv: present
- runtime_summary.csv: present
- runtime_summary_top15.csv: present
- warnings_log.csv: present
- mi_warnings_log.csv: present
- mice_smoketest.log: present
- mice_batches_log.csv: present
- mice_chain_diagnostics.csv: present
- mice_pred_width_preflight.csv: present
- mice_logged_events_raw.csv: present
- mice_logged_events_summary.csv: present
- mice_spec.rds: present
- mi_outcome_fit_diagnostics.csv: present
- model_fit_diagnostics.csv: present
- mi_spline_curve_abg.csv: present
- mi_spline_curve_vbg.csv: present
- balance_target_imp_summary.csv: present
- balance_max_smd_by_imp.csv: present
- weight_summary.csv: present
- ps_overlap_summary.csv: present
- diagnostics_summary.csv: present
- plot_drop_log.csv: present

## Runtime Top Steps

- mi_single_pass: 164.559 sec
- mice_imputation: 63.429 sec
- shap_summary: 8.552 sec

## MI Health

- Smoke test failed: FALSE
- Predictor width max mm_cols: 37.000
- Chain diagnostics issue: FALSE (numeric_names=FALSE; drift_tail_na_frac=0.000)
- MI warnings rows: 4

## Balance

- ABG max |SMD|: 0.282
- VBG max |SMD|: 0.210

## Outcome Fits

Top separation counts (analysis_variant/group/outcome):
- mi_ipw / ABG / death_60d: 160
- mi_ipw / VBG / death_60d: 160
- mi_ipw / ABG / hypercap_resp_failure: 160
- mi_ipw / VBG / hypercap_resp_failure: 160
- mi_ipw / VBG / imv_proc: 160
- mi_ipw / ABG / niv_proc: 160

## Issues (prioritized)

- [high] Balance: ABG max|SMD|=0.282 (Results/balance_target_imp_summary.csv)
- [high] Outcome: sep_flag TRUE for 1151 / 1324 fits (Results/model_fit_diagnostics.csv)
