# Codex Ticket 1: Timing Diagnostic for Blood Gas Measurement vs IMV/NIV Timing

## Date
2026-06-26

## Precondition

Use the dated working notebook created by the overall ticket:

```text
Code Drafts/2026-06-26 ABG-VBG reverse-timing severity sensitivities.qmd
```

Do not edit older notebook versions.

---

## Rationale

A major concern is that ABGs may be obtained **after or on the same day as intubation** to manage mechanical ventilation. In that pathway:

1. patient deteriorates or is intubated,
2. ABG is obtained for ventilator management,
3. both ABG and IMV appear on the same calendar day,
4. the analysis treats ABG pCO2 as an exposure and IMV as an outcome.

This creates timing ambiguity and may explain why ABG-tested encounters have persistently higher absolute IMV risk than VBG-tested encounters even after weighting.

A similar but probably weaker concern exists for NIV.

This diagnostic asks:

> Among ABG- and VBG-tested encounters, how often do IMV/NIV events occur before, on the same day as, or after the blood gas measurement day?

---

## Expected findings and interpretation

### Expected if reverse/same-day management is important
- ABG encounters, especially IMV-positive ABG encounters, will have a high proportion of IMV on the same day as or before the ABG measurement day.
- VBG encounters will have fewer same-day/post-outcome gas patterns.
- This would support the interpretation that ABG is partly a marker of ventilator management context rather than purely pre-intubation prognosis.

### Expected if reverse timing is not driving the issue
- Most ABG and VBG blood gases occur before IMV/NIV.
- Same-day/post-outcome proportions are small or similar across modalities.
- Persistent absolute-risk differences would then more likely reflect residual unmeasured severity/workflow rather than direct post-intubation ABG use.

### Manuscript implications
If ABG frequently occurs same-day/after IMV:

> The stronger absolute IMV risk in ABG-tested encounters may partly reflect ABG use during or after intubation for ventilator management rather than purely pre-intubation prognosis.

---

# Required data elements

Search the data/codebook/QMD for these or equivalent fields:

## Blood gas timing
- `paco2_date`
- `vbg_co2_date`
- `meas_art_gas_proc_first_date`
- `meas_venous_o2_proc_first_date`
- `art_punct_proc_first_date`

## Ventilatory support timing
- `imv_proc_first_date`
- `niv_proc_first_date`
- `vent_proc_first_date`

## Outcomes
- `imv_proc`
- `niv_proc`
- `hypercap_resp_failure`
- `death_60d`

If exact variable names differ, identify the corresponding fields from labels/codebook and document the mapping.

---

# Analysis specification

For each test type and each ventilatory outcome:

## Test-specific gas day
- ABG analysis: use `paco2_date` or best available ABG pCO2/gas date.
- VBG analysis: use `vbg_co2_date` or best available VBG pCO2/gas date.

## Timing classes

For each outcome with an available first-date field, classify:

- `outcome_before_gas`: outcome first day < gas day
- `outcome_same_day_as_gas`: outcome first day == gas day
- `outcome_after_gas`: outcome first day > gas day
- `no_outcome`: outcome absent
- `missing_gas_day`
- `missing_outcome_day`

Use encounter-day offsets consistently. If dates are calendar-day offsets rather than timestamps, label same-day as temporally ambiguous.

## Outputs

Create:

```text
Results/sensitivity_reverse_timing/timing_classification_counts.csv
Results/sensitivity_reverse_timing/timing_classification_counts.md
Results/sensitivity_reverse_timing/timing_classification_by_modality_outcome.csv
Results/sensitivity_reverse_timing/timing_classification_method_note.md
```

Optional figure:

```text
Results/figs/timing_classification_by_modality_outcome.png
Results/figs/timing_classification_by_modality_outcome.pdf
```

## Tables

Produce a table with rows:

- gas modality: ABG / VBG
- outcome: IMV / NIV
- timing class
- n
- percent among tested cohort
- percent among outcome-positive tested cohort

Example columns:

```text
modality
outcome
timing_class
n
percent_of_tested
percent_of_outcome_positive
gas_day_field
outcome_day_field
missingness_note
```

---

# Validation criteria

## 1% pilot validation

After implementation, run a 1% pilot and confirm:

- all timing classes are produced,
- both ABG and VBG are present,
- both IMV and NIV are present,
- no impossible timing categories,
- missing dates are explicitly counted,
- no PDF/table clipping,
- analysis code is visible in the notebook PDF,
- QA files are produced to disk.

## Full run validation

After all tickets are implemented and integrated, rerun full dataset and confirm:

- timing proportions are stable enough to interpret,
- same-day/pre-gas IMV rates are summarized by modality,
- interpretation note is generated.

---

# Non-goals

Do not:
- change primary outcomes,
- replace primary results,
- assume same-day means post-outcome; label it as temporally ambiguous,
- interpret missing timing as absence of timing ambiguity.

---

# Definition of done

This ticket is complete when a 1% pilot render produces timing classification tables for ABG and VBG for IMV/NIV, with clear interpretation of before/same-day/after gas patterns and explicit missingness handling.
