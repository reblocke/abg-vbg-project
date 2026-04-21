# Diagnostics Audit

## Executive Summary
- Overall status: FAIL
- Run mode: full; pilot_frac: 1; m: 80; maxit: 20
- Runtime total (sec): 70418.348
- MI batch status: batches=280; m_batch=2; failures=0
- Balance: ABG max|SMD|=0.091; VBG max|SMD|=0.042
- Separation flags: 328 / 2612

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

- mi_single_pass: 14593.127 sec
- mice_batch_26: 4028.354 sec
- mice_batch_33: 2827.165 sec
- mice_batch_30: 2431.267 sec
- mice_batch_23: 2420.444 sec
- mice_batch_11: 2378.014 sec
- mice_batch_8: 2271.435 sec
- mice_batch_38: 2199.348 sec
- mice_batch_9: 2110.349 sec
- mice_batch_36: 2055.018 sec

## MI Health

- Smoke test failed: FALSE
- Predictor width max mm_cols: 34.000
- Chain diagnostics issue: FALSE (numeric_names=FALSE; drift_tail_na_frac=0.000)
- MI warnings rows: 0

## Balance

- ABG max |SMD|: 0.091
- VBG max |SMD|: 0.042

## Outcome Fits

Top separation counts (analysis_variant/group/outcome):
- mi_ipw / ABG / hypercap_resp_failure: 80
- mi_unweighted / ABG / hypercap_resp_failure: 80
- mi_ipw / ABG / niv_proc: 80
- mi_unweighted / ABG / niv_proc: 80
- ipw / ABG / hypercap_resp_failure:  2
- ipw / ABG / niv_proc:  2

## Issues (prioritized)

- [high] Outcome: sep_flag TRUE for 328 / 2612 fits (Results/model_fit_diagnostics.csv)
