# Diagnostics Audit

## Executive Summary
- Overall status: FAIL
- Run mode: pilot; pilot_frac: 0.01; m: 20; maxit: 5
- Runtime total (sec): 198.512
- MI batch status: batches=70; m_batch=2; failures=0
- Balance: ABG max|SMD|=0.108; VBG max|SMD|=0.079
- Separation flags: 540 / 692

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

- mi_single_pass: 182.927 sec
- mice_batch_6: 1.634 sec
- mice_batch_10: 1.595 sec
- mice_batch_7: 1.578 sec
- mice_batch_2: 1.560 sec
- mice_batch_8: 1.559 sec
- mice_batch_1: 1.546 sec
- mice_batch_4: 1.539 sec
- mice_batch_3: 1.535 sec
- mice_batch_9: 1.520 sec

## MI Health

- Smoke test failed: FALSE
- Predictor width max mm_cols: 33.000
- Chain diagnostics issue: FALSE (numeric_names=FALSE; drift_tail_na_frac=0.000)
- MI warnings rows: 0

## Balance

- ABG max |SMD|: 0.108
- VBG max |SMD|: 0.079

## Outcome Fits

Top separation counts (analysis_variant/group/outcome):
- mi_ipw / ABG / death_60d: 40
- mi_ipw / VBG / death_60d: 40
- mi_unweighted / VBG / death_60d: 40
- mi_ipw / ABG / hypercap_resp_failure: 40
- mi_unweighted / ABG / hypercap_resp_failure: 40
- mi_ipw / VBG / hypercap_resp_failure: 40

## Issues (prioritized)

- [high] Balance: ABG max|SMD|=0.108 (Results/balance_target_imp_summary.csv)
- [high] Outcome: sep_flag TRUE for 540 / 692 fits (Results/model_fit_diagnostics.csv)
