# Codex Ticket 5: Acute Severity / Workflow Proxy Sensitivity

## Date
2026-06-26

## Precondition

Use the dated working notebook created by the overall ticket:

```text
Code Drafts/2026-06-26 ABG-VBG reverse-timing severity sensitivities.qmd
```

---

## Rationale

Even after measured-covariate weighting, ABG-tested encounters retain higher absolute risk for broad severity outcomes such as IMV and mortality. This may reflect unmeasured acute severity or clinical workflow context, including:

- ICU-level monitoring,
- post-procedure status,
- shock/sepsis evaluation,
- severe hypoxemia,
- airway or ventilator management,
- clinician concern,
- arterial line / ventilator workflow.

Some of these may be partially captured by same-encounter acute severity or workflow proxies. These variables may not be appropriate for the primary model if they are post-baseline, but they are useful for a sensitivity analysis.

This analysis asks:

> Do ABG-VBG absolute-risk differences shrink when the sampling model includes acute severity and workflow proxies?

---

## Expected findings and interpretation

### If adding acute/workflow proxies attenuates absolute-risk differences
- The ABG-VBG absolute-risk gap likely reflects residual acute severity/workflow context.
- The primary ROR findings may still be valid as relative association comparisons, but absolute risk differences require caution.

### If adding proxies does not attenuate differences
- Residual unmeasured context persists despite additional proxies.
- The difference may reflect variables unavailable in TriNetX/EHR, such as real-time clinician concern, ventilator setting context, arterial line placement, or within-day event ordering.

### If balance worsens or weights become unstable
- Same-encounter proxy model may be overfit, collider-prone, or positivity-limited.
- Use only as exploratory support.

---

# Candidate variable inventory

Search codebook/QMD/data labels for acute severity/workflow variables.

Potential candidates include but are not limited to:

## Critical care / high-acuity workflow
- `cc_time`
- `cc_time_first_date`
- ICU-related fields if available
- arterial line or arterial puncture procedure fields
- blood culture procedure
- sepsis diagnosis
- inpatient antibiotics
- vasopressor or shock-related variables if available

## Respiratory severity / workflow
- respiratory rate
- SpO2
- oxygenation variables if not gas-derived
- CPAP / NIV / ventilation procedure dates
- paralytic use
- bronchodilator / nebulizer treatments
- steroids, if available

## Acute metabolic/organ dysfunction
- creatinine
- bicarbonate if serum chemistry, not gas-derived
- potassium
- sodium
- WBC
- platelet count
- lactate only if this variant intentionally includes it as an acute proxy

## Exclude or flag carefully
Variables that are outcomes or direct descendants of outcomes:
- IMV/NIV outcome indicators,
- IMV/NIV same-day procedure status,
- gas-derived pH/PaO2/PvO2/O2 saturation,
- variables known to occur after blood gas.

They may be used for stratified diagnostics, but should not be casually included in a propensity model without labeling.

---

# Analysis specification

## Step 1 — Candidate proxy inventory

Create:

```text
Results/sensitivity_acute_workflow/acute_proxy_inventory.csv
Results/sensitivity_acute_workflow/acute_proxy_inventory.md
```

Columns:

```text
variable
domain
available
missing_pct
date_field_available
likely_timing
candidate_for_enhanced_ps
candidate_for_stratification_only
excluded_reason
notes
```

## Step 2 — Define enhanced proxy model variants

At minimum define one enhanced model:

### Model A: Primary PS + acute workflow proxies
Add selected acute/workflow proxies to the primary propensity covariate set.

If feasible, define separate variants:

### Model B: Primary PS + respiratory severity proxies
Examples: RR, SpO2, oxygenation-related non-gas-derived fields.

### Model C: Primary PS + sepsis/shock/workflow proxies
Examples: critical care time, sepsis, blood cultures, antibiotics, paralytic, vasopressor variables if present.

Do not add outcome variables directly unless this is explicitly labeled as stratification-only or exploratory collider-prone sensitivity.

## Step 3 — Fit weights and compare

For each enhanced model:

- fit ABG/VBG sampling models,
- generate weights,
- assess overlap and SMD balance,
- compute weighted outcome rates,
- compute model-implied reference risks,
- compute primary categorical ORs,
- compute RORs/risk differences if feasible.

## Step 4 — Compare attenuation

Calculate:

```text
primary_vbg_minus_abg_weighted_rate_diff
enhanced_vbg_minus_abg_weighted_rate_diff
attenuation_pct = 100 * (1 - enhanced_diff / primary_diff)
```

Use absolute differences when appropriate.

Report attenuation for:
- IMV,
- death,
- NIV,
- hypercapnic RF.

---

# Outputs

```text
Results/sensitivity_acute_workflow/acute_proxy_inventory.csv
Results/sensitivity_acute_workflow/acute_proxy_model_definitions.csv
Results/sensitivity_acute_workflow/acute_proxy_balance_summary.csv
Results/sensitivity_acute_workflow/acute_proxy_weighted_outcome_rates.csv
Results/sensitivity_acute_workflow/acute_proxy_reference_risks.csv
Results/sensitivity_acute_workflow/acute_proxy_vs_primary_comparison.csv
Results/sensitivity_acute_workflow/acute_proxy_interpretation_summary.md
```

Optional figures:

```text
Results/figs/acute_proxy_weighted_outcome_rate_attenuation.png
Results/figs/acute_proxy_balance_plot.png
```

---

# Validation criteria

## 1% pilot validation

After implementation, run 1% pilot and confirm:

- candidate inventory generated,
- selected proxy variables exist,
- missingness documented,
- PS models fit or failures are documented,
- weights not pathologically extreme,
- comparison outputs generated,
- all outcomes/modalities present.

## Full run validation

After full run:

- assess whether acute/workflow proxies attenuate ABG-VBG absolute-risk differences,
- assess whether relative association patterns remain stable,
- assess whether enhanced model introduces balance/positivity problems.

---

# Non-goals

Do not:
- use this model as primary without deliberate manuscript decision,
- assume post-baseline proxies are safe confounders,
- condition on outcomes in the primary analysis,
- obscure collider concerns,
- interpret attenuation as proof of causal mechanism.

---

# Definition of done

This ticket is complete when an enhanced acute-severity/workflow proxy sensitivity analysis has been implemented, compared to the primary model, and summarized with explicit discussion of whether residual ABG-VBG absolute-risk differences appear to reflect acute clinical context.
