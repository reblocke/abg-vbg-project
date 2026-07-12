# Codex Ticket 2: Timing-Stratified Weighted Outcome-Rate Diagnostics

## Date
2026-06-26

## Precondition

Use the dated working notebook created by the overall ticket:

```text
Code Drafts/2026-06-26 ABG-VBG reverse-timing severity sensitivities.qmd
```

Ticket 1 timing classifications should already exist.

---

## Rationale

The weighted outcome-rate diagnostics showed that ABG-tested pseudo-populations retain higher absolute risk for broad severity outcomes, especially IMV and 60-day mortality, even after measured-covariate weighting.

A plausible explanation is that ABGs are more often obtained in encounters where IMV is already present or occurs on the same day as the gas. This ticket asks:

> Are ABG-VBG absolute-risk differences concentrated in encounters with pre/same-day ventilatory support timing?

Because using IMV timing as a stratum for the IMV outcome is partly tautological, this ticket should focus on descriptive timing distributions and carefully defined post-gas outcome rates.

---

## Expected findings and interpretation

### If ABG absolute-risk gap is driven by same-day/post-intubation ABG use
- ABG will have a higher weighted proportion of pre/same-day IMV timing.
- Strict post-gas IMV rates may be more similar between ABG and VBG after excluding pre/same-day IMV.
- IMV absolute-risk gap may shrink in a post-gas-only sensitivity.

### If ABG absolute-risk gap persists after timing stratification
- ABG remains higher risk even among those without pre/same-day IMV.
- This would support broader residual clinical-context differences, not only reverse timing.

### If hypercapnia-specific outcomes remain aligned
- NIV and coded hypercapnic RF may continue to show close ABG/VBG alignment.
- This supports the current interpretation that the strongest evidence is for hypercapnia-specific prognostic information.

---

# Analysis specification

## Part A — Weighted distribution of timing classes

Using Ticket 1 timing classes, estimate weighted distributions by modality for:

- IMV timing class
- NIV timing class

Use primary MI-logistic IPSW weights.

For each modality/outcome:

- unweighted n
- weighted percentage in each timing class
- percent among tested cohort
- percent among outcome-positive encounters

## Part B — Strict post-gas outcome rates

Define sensitivity outcomes:

- `imv_after_gas_strict`: IMV first day > gas day
- `niv_after_gas_strict`: NIV first day > gas day

Also define inclusive ambiguous versions:

- `imv_same_or_after_gas`: IMV first day >= gas day
- `niv_same_or_after_gas`: NIV first day >= gas day

Report weighted rates by modality for:
- strict post-gas IMV,
- same-day-or-after IMV,
- strict post-gas NIV,
- same-day-or-after NIV.

## Part C — Outcome rates excluding pre/same-day IMV context

For broader outcomes such as death and hypercapnic RF, compare weighted rates after excluding encounters with:

- IMV before gas,
- IMV same day as gas.

Optional: repeat excluding pre/same-day NIV.

---

# Outputs

Create:

```text
Results/sensitivity_timing_stratified_rates/weighted_timing_class_distribution.csv
Results/sensitivity_timing_stratified_rates/weighted_post_gas_outcome_rates.csv
Results/sensitivity_timing_stratified_rates/weighted_rates_excluding_presame_imv.csv
Results/sensitivity_timing_stratified_rates/timing_stratified_rates_summary.md
```

Optional figures:

```text
Results/figs/weighted_timing_class_distribution.png
Results/figs/post_gas_outcome_rate_comparison.png
```

---

# Required table columns

## Timing distribution table

```text
modality
timing_outcome
timing_class
unweighted_n
weighted_percent
percent_among_outcome_positive
weight_type
diagnostic_note
```

## Post-gas outcome-rate table

```text
outcome_definition
modality
weighted_rate_pct
weighted_rate_se_pct
weighted_rate_difference_vbg_minus_abg_pct
rate_ratio_vbg_over_abg
eligibility_restriction
diagnostic_status
```

---

# Validation criteria

## 1% pilot validation

After implementation, run a 1% pilot and confirm:

- outputs generated,
- timing classes join correctly to weighted data,
- strict post-gas outcomes are not all zero/missing unless expected by pilot sparsity,
- no impossible rates,
- both modalities represented,
- no table clipping.

## Full run validation

After all tickets and full render:

- determine whether pre/same-day IMV explains the ABG absolute IMV risk gap,
- determine whether post-gas-only IMV rates narrow the ABG/VBG difference,
- write interpretation summary.

---

# Non-goals

Do not:
- redefine primary outcomes,
- treat same-day as definitively before or after,
- use timing-stratified results as primary unless later chosen,
- hide same-day ambiguity.

---

# Definition of done

This ticket is complete when timing-stratified weighted outcome-rate diagnostics quantify whether ABG-VBG absolute-risk differences are concentrated in pre/same-day ventilatory-support contexts.
