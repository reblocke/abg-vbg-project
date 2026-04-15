run_id: 20260415_003149 run_ts: 2026-04-15 00:31:49.347034
# Diagnostics Audit

## A1. MI workflow
- Impute -> single-pass per‑imputation loop (weights, target balance, 3‑level outcomes, spline outcomes) -> pool curves and coefficients with Rubin’s rules (chunk: `mi-single-pass`; downstream MI display chunks read those objects).
## A2. MI settings
- m = 20, maxit = 5, seed = 20251206; treatments/outcomes/PaCO2/VBG CO2 are not imputed but are predictors (`mi-exec`).
## A3. Propensity weighting
- Unimputed weighting uses WeightIt with method = "gbm" and balance-based stopping (stop.method = "smd.max"); no AUC-based tuning (`propensity-config`, `ipw-abg-weighting`, `ipw-vbg-workflow`).
- MI weighting uses logistic PS with restricted cubic splines (glm + rcs); no SHAP is computed for MI.
## A4. One-sided IPSW + truncation
- Weights are 1/ps for observed tests (ABG or VBG), truncated only for very small propensities (ps floor = 1st percentile), then stabilized by the mean; controls receive weight 1 for balance diagnostics only.
## A5. Robust variance
- Outcome models are survey::svyglm with svydesign (robust SEs), using spline(CO2) + X adjustment; ABG and VBG are fit separately within the measured cohort.
## A6. Pooling
- mitools::MIcombine pools coefficients and robust vcov from svyglm; spline curves are pooled pointwise on log-OR (relative to CO2_ref) and on eta for predicted-probability curves (helpers defined in `mi-single-pass`).

## Potential mismatches / risks
- Target balance diagnostics compare weighted treated cohort to the full analytic sample (no treated-vs-control balance).
- MI stability across m uses subsets of the first m imputations from the main mids object (not full re-imputation at each m).
- Unweighted analyses remain earlier in the notebook for context; primary inference is based on weighted spline models.
