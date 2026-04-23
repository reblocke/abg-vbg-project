# Diagnostics Audit

## Executive Summary
- Overall status: FAIL
- Run mode: pilot; pilot_frac: 0.25; m: 20; maxit: 5
- Runtime total (sec): 771.701
- MI batch status: batches=70; m_batch=2; failures=0
- Balance: ABG max|SMD|=0.091; VBG max|SMD|=0.045
- Separation flags: 172 / 692

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

- mi_single_pass: 451.923 sec
- mice_batch_8: 33.861 sec
- mice_batch_7: 33.109 sec
- mice_batch_5: 32.354 sec
- mice_batch_6: 32.143 sec
- mice_batch_9: 32.068 sec
- mice_batch_4: 31.718 sec
- mice_batch_3: 31.572 sec
- mice_batch_10: 31.468 sec
- mice_batch_1: 31.097 sec

## MI Health

- Smoke test failed: FALSE
- Predictor width max mm_cols: 34.000
- Chain diagnostics issue: FALSE (numeric_names=FALSE; drift_tail_na_frac=0.000)
- MI warnings rows: 0

## Balance

- ABG max |SMD|: 0.091
- VBG max |SMD|: 0.045

## Outcome Fits

Top separation counts (analysis_variant/group/outcome):
- mi_ipw / VBG / niv_proc: 40
- mi_unweighted / VBG / niv_proc: 40
- mi_ipw / ABG / hypercap_resp_failure: 20
- mi_unweighted / ABG / hypercap_resp_failure: 20
- mi_ipw / ABG / niv_proc: 20
- mi_unweighted / ABG / niv_proc: 20

## Issues (prioritized)

- [high] Outcome: sep_flag TRUE for 172 / 692 fits (Results/model_fit_diagnostics.csv)
