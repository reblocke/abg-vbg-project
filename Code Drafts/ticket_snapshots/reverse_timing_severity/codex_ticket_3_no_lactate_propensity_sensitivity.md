# Codex Ticket 3: No-Lactate Propensity-Weighting Sensitivity

## Date
2026-06-26

## Precondition

Use the dated working notebook created by the overall ticket:

```text
Code Drafts/2026-06-26 ABG-VBG reverse-timing severity sensitivities.qmd
```

---

## Rationale

Lactate is highly predictive of ABG and VBG ordering in the propensity models. However, lactate may not be a clean baseline covariate:

- it can be measured on the ABG or VBG itself,
- it may occur because the clinician has already decided to order a blood gas,
- it may encode shock/severity and the testing pathway,
- and it may partially condition on downstream or co-measured information.

Thus lactate could either:
1. improve balancing of acute severity, or
2. induce collider/post-test adjustment by encoding the test-ordering pathway.

This sensitivity asks:

> Do ABG-VBG balance, weighted outcome rates, and primary associations materially change when lactate is excluded from the sampling model?

---

## Expected findings and interpretation

### If results are stable without lactate
- The primary findings are not driven by lactate/test-panel conditioning.
- Persistent ABG-VBG absolute-risk differences likely reflect broader residual clinical context.

### If absolute-risk differences shrink without lactate
- Lactate may have encoded test pathway or post-test severity in a way that distorted weighting.
- Consider discussing lactate as a sensitivity concern.

### If balance worsens substantially without lactate
- Lactate may be an important acute-severity proxy.
- The no-lactate model may be temporally cleaner but less confounding-resistant.

### If primary OR/ROR conclusions change
- The role of lactate needs careful interpretation before deciding on manuscript claims.

---

# Lactate variables to audit

Search for and classify variables including:

- `serum_lac`
- `serum_lac_date`
- `abg_lactate`
- `abg_lactate_date`
- `vbg_lactate`
- `vbg_lactate_date`
- lactate missingness indicators
- any derived lactate variables

Primary sensitivity should remove lactate variables from the **test-ordering propensity model**. It is acceptable for lactate to remain in the imputation model as an auxiliary predictor if this is simpler, but document that choice.

---

# Analysis specification

## Step 1 — Variable inventory

Create a lactate variable inventory:

```text
Results/sensitivity_no_lactate/lactate_variable_inventory.csv
Results/sensitivity_no_lactate/lactate_variable_inventory.md
```

Fields:

```text
variable
included_in_primary_ps
included_in_mi_model
imputed_if_missing
date_field_available
likely_source
notes
```

## Step 2 — No-lactate sampling models

Refit ABG and VBG test-ordering propensity models excluding lactate variables from `covars_ps`.

Use same:
- source cohort,
- MI datasets,
- weight truncation/flooring,
- stabilization,
- balance diagnostics.

## Step 3 — Compare diagnostics and outcomes

Compare primary vs no-lactate:

- propensity overlap,
- mean/max SMD,
- weighted outcome rates,
- model-implied reference risks,
- primary categorical ORs,
- RORs if feasible,
- risk differences if feasible.

---

# Outputs

```text
Results/sensitivity_no_lactate/no_lactate_weighting_diagnostics.csv
Results/sensitivity_no_lactate/no_lactate_balance_summary.csv
Results/sensitivity_no_lactate/no_lactate_weighted_outcome_rates.csv
Results/sensitivity_no_lactate/no_lactate_primary_categorical_results.csv
Results/sensitivity_no_lactate/no_lactate_vs_primary_comparison.csv
Results/sensitivity_no_lactate/no_lactate_interpretation_summary.md
```

Optional figures:

```text
Results/figs/no_lactate_balance_plot.png
Results/figs/no_lactate_weighted_outcome_rate_comparison.png
```

---

# Key comparison metrics

Calculate:

```text
delta_weighted_rate_difference = no_lactate_vbg_minus_abg - primary_vbg_minus_abg
delta_log_or = no_lactate_log_or - primary_log_or
delta_ror = no_lactate_ror - primary_ror
```

Flag material changes:

- weighted rate difference changes by >2.5 percentage points
- OR/ROR changes by >10-20% relative, depending on outcome
- balance deteriorates above max SMD >0.1 in key variables

These are review triggers, not failure criteria.

---

# Validation criteria

## 1% pilot validation

After implementation, run a 1% pilot and confirm:

- no-lactate models fit,
- weights generated,
- balance outputs generated,
- all four outcomes present,
- no missing tables,
- no impossible weights/rates/probabilities,
- code visible in PDF.

## Full run validation

After integrated full render:

- determine whether lactate materially affects ABG-VBG absolute-risk differences,
- determine whether primary relative association claims remain stable.

---

# Non-goals

Do not:
- automatically remove lactate from the primary model,
- claim lactate is a collider without evidence,
- remove all labs unless part of Ticket 4,
- interpret 1% pilot changes substantively.

---

# Definition of done

This ticket is complete when a no-lactate IPSW sensitivity has been fit and compared to the primary model, with clear interpretation of whether lactate explains any ABG-VBG absolute-risk differences.
