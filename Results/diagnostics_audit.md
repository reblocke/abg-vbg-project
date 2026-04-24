# Diagnostics Audit

## Executive Summary
- Overall status: PASS_WITH_WARNINGS
- Run mode: pilot; pilot_frac: 0.01; m: 20; maxit: 5
- Runtime total (sec): 177.724
- MI batch status: batches=70; m_batch=2; failures=0
- Balance: ABG max|SMD|=0.108; VBG max|SMD|=0.079
- Outcome diagnostic failures: 0 / 692
- Outcome diagnostic warnings: 540 / 692
- Legacy separation/extreme-probability flags: 540 / 692

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

- mi_single_pass: 163.192 sec
- mice_batch_9: 1.598 sec
- mice_batch_2: 1.569 sec
- mice_batch_1: 1.479 sec
- mice_batch_10: 1.442 sec
- mice_batch_3: 1.420 sec
- mice_batch_8: 1.408 sec
- mice_batch_6: 1.408 sec
- mice_batch_4: 1.408 sec
- mice_batch_7: 1.403 sec

## MI Health

- Smoke test failed: FALSE
- Predictor width max mm_cols: 33.000
- Chain diagnostics issue: FALSE (numeric_names=FALSE; drift_tail_na_frac=0.000)
- MI warnings rows: 0

## Balance

- ABG max |SMD|: 0.108
- VBG max |SMD|: 0.079

## Outcome Fits

Top separation/extreme-probability counts (analysis_variant/model_type/group/outcome):
- mi_ipw / cat3 / ABG / death_60d: 20
- mi_ipw / spline / ABG / death_60d: 20
- mi_ipw / cat3 / VBG / death_60d: 20
- mi_unweighted / cat3 / VBG / death_60d: 20
- mi_ipw / spline / VBG / death_60d: 20
- mi_unweighted / spline / VBG / death_60d: 20

## Issues (prioritized)

- [medium] Balance: ABG max|SMD|=0.108 (Results/balance_target_imp_summary.csv)
- [medium] Outcome: tail/off-profile fitted-probability warnings for 540 / 692 fits (Results/model_fit_diagnostics.csv)
