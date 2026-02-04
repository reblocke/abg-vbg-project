# Diagnostics Audit

## Executive Summary
- Run mode: pilot; pilot_frac: 0.05; m: 80; maxit: 20
- Runtime total (sec): 900.534
- MI batch status: batches=40; m_batch=2; failures=0
- Balance: ABG max|SMD|=0.100; VBG max|SMD|=0.051
- Separation flags: 905 / 1324

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

- mi_single_pass: 195.230 sec
- mice_batch_36: 18.205 sec
- mice_batch_37: 18.120 sec
- mice_batch_35: 18.066 sec
- mice_batch_34: 18.025 sec
- mice_batch_38: 18.017 sec
- mice_batch_1: 17.993 sec
- mice_batch_40: 17.782 sec
- mice_batch_6: 17.762 sec
- mice_batch_14: 17.747 sec

## MI Health

- Smoke test failed: FALSE
- Predictor width max mm_cols: 34.000
- Chain diagnostics issue: FALSE (numeric_names=FALSE; drift_tail_na_frac=0.000)
- MI warnings rows: 0

## Balance

- ABG max |SMD|: 0.100
- VBG max |SMD|: 0.051

## Outcome Fits

Top separation counts (analysis_variant/group/outcome):
- mi_ipw / ABG / death_60d: 160
- mi_ipw / VBG / death_60d: 160
- mi_ipw / VBG / hypercap_resp_failure: 160
- mi_ipw / ABG / niv_proc: 160
- mi_ipw / VBG / niv_proc: 160
- mi_ipw / ABG / hypercap_resp_failure:  80

## Issues (prioritized)

- [high] Balance: ABG max|SMD|=0.100 (Results/balance_target_imp_summary.csv)
- [high] Outcome: sep_flag TRUE for 905 / 1324 fits (Results/model_fit_diagnostics.csv)
