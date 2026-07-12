# Codex Ticket 4: Pre-Gas / Temporally Conservative Covariate Propensity Model

## Date
2026-06-26

## Precondition

Use the dated working notebook created by the overall ticket:

```text
Code Drafts/2026-06-26 ABG-VBG reverse-timing severity sensitivities.qmd
```

---

## Rationale

Some covariates in the current sampling model may be measured during the same encounter and may occur after, during, or because of blood gas ordering. This creates temporal ambiguity.

A more conservative sensitivity model should use only covariates plausibly available **before** the blood gas order or before acute deterioration.

This analysis asks:

> Are the ABG-VBG relative associations and absolute-risk differences robust when the test-ordering model is limited to temporally cleaner covariates?

---

## Expected findings and interpretation

### If results are stable
- The main conclusions are not dependent on same-encounter labs or potentially post-gas covariates.
- This strengthens causal-temporal credibility.

### If balance worsens but results remain similar
- The primary model may be better balanced, but temporal concerns do not drive the findings.

### If absolute-risk differences increase
- Same-encounter labs may be helping balance latent severity, even if temporally ambiguous.

### If absolute-risk differences shrink
- Some same-encounter covariates may have induced problematic conditioning or encoded test-ordering pathways.

---

# Covariate-set specification

## Conservative core covariates

Include variables likely to be pre-gas or baseline:

- age
- sex
- race/ethnicity
- location/region
- encounter type
- BMI if baseline/current but not test-derived
- comorbidities diagnosed on or before index encounter:
  - COPD
  - asthma
  - OSA
  - CHF
  - neuromuscular disease
  - pulmonary hypertension
  - CKD
  - diabetes
  - severe obesity/OHS flags if used

## Optional pre-gas/triage vital signs

Include only if these are clearly initial/triage values:

- heart rate
- systolic blood pressure
- diastolic blood pressure
- temperature
- respiratory rate
- SpO2

If timing is ambiguous, create two conservative models:

1. **demographics/comorbidities only**
2. **demographics/comorbidities + initial vitals**

## Exclude from pre-gas propensity model

Exclude variables likely to be test-derived, co-measured with blood gas, or post-order:

- lactate
- ABG/VBG pH
- ABG/VBG oxygenation values
- ABG/VBG bicarbonate if gas-derived
- procedures during encounter
- ventilatory support variables
- medications/treatments given during encounter
- same-day labs unless clearly pre-gas

Serum chemistry labs may be included only if the code can verify they are initial labs measured before the gas day/time. If only same-day timing is available, prefer excluding them in the conservative model.

---

# Analysis specification

## Step 1 — Covariate timing inventory

Create:

```text
Results/sensitivity_pregas_covariates/covariate_timing_inventory.csv
Results/sensitivity_pregas_covariates/covariate_timing_inventory.md
```

Columns:

```text
variable
primary_ps_included
timing_evidence
pregas_core
pregas_plus_vitals
excluded_reason
notes
```

## Step 2 — Fit conservative sampling models

Fit ABG and VBG test-ordering propensity models using:

### Model A
`pregas_core`

### Model B
`pregas_core_plus_vitals`

if vitals are plausible.

Generate weights using the same truncation/floor/stabilization rules as primary.

## Step 3 — Compare with primary

For each model compare:

- balance,
- overlap,
- weighted outcome rates,
- model-implied reference risks,
- categorical ORs,
- RORs if feasible,
- risk differences if feasible.

---

# Outputs

```text
Results/sensitivity_pregas_covariates/pregas_covariate_sets.csv
Results/sensitivity_pregas_covariates/pregas_balance_summary.csv
Results/sensitivity_pregas_covariates/pregas_weighted_outcome_rates.csv
Results/sensitivity_pregas_covariates/pregas_primary_categorical_results.csv
Results/sensitivity_pregas_covariates/pregas_vs_primary_comparison.csv
Results/sensitivity_pregas_covariates/pregas_interpretation_summary.md
```

Optional figures:

```text
Results/figs/pregas_balance_plot.png
Results/figs/pregas_weighted_outcome_rate_comparison.png
```

---

# Validation criteria

## 1% pilot validation

After implementation, run 1% pilot and confirm:

- conservative covariate set is nonempty and sensible,
- PS models fit,
- weights are not degenerate,
- balance summaries generated,
- outcome comparisons generated,
- all outputs present.

## Full run validation

After full run:

- assess whether pre-gas-only weighting materially changes ABG-VBG absolute-risk differences,
- assess whether relative association patterns remain stable.

---

# Non-goals

Do not:
- replace primary weighting model automatically,
- include outcome variables as covariates,
- condition on same-day IMV/NIV in the conservative propensity model,
- overinterpret poor balance from conservative model as primary model failure.

---

# Definition of done

This ticket is complete when at least one temporally conservative propensity model has been fit and compared with the primary model, with clear interpretation of whether temporally ambiguous covariates explain ABG-VBG absolute-risk differences.
