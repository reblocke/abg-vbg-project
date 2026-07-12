# Overall Codex Implementation Ticket: Reverse-Timing / Latent Severity Sensitivity Program

## Date
2026-06-26

## Purpose

Implement a structured set of diagnostic and sensitivity analyses to clarify why ABG- and VBG-based models show broadly similar relative pCO2-outcome associations but different absolute standardized risks, especially for IMV and 60-day mortality.

The goal is to distinguish among plausible explanations:

1. **Reverse or same-day timing:** ABGs may be drawn after intubation or during ventilator management.
2. **Post-test or co-measured covariates:** lactate and other labs may encode the blood gas ordering pathway rather than only baseline illness severity.
3. **Residual acute severity / workflow selection:** ABG and VBG may remain embedded in different clinical contexts even after measured-covariate weighting.
4. **Offset/measurement-scale issues:** pCO2 mapping may explain some differences for hypercapnia-specific outcomes but likely not broad severity outcomes.
5. **True scale dependence:** relative association strength may align even when absolute standardized risks differ.

This is a **sensitivity and diagnostics program**, not a replacement of the current primary analysis unless the diagnostics reveal a clear implementation flaw.

---

# Step 0 — Create a dated working notebook copy

## Required action

Before making any changes, copy the current working notebook to a new file whose filename is prefixed with today's date.

Use a filename like:

```text
Code Drafts/2026-06-26 ABG-VBG reverse-timing severity sensitivities.qmd
```

or, if preserving the existing naming convention:

```text
Code Drafts/2026-06-26 ABG-VBG analysis reverse-timing severity sensitivities.qmd
```

## Rules

- Do not overwrite the current working notebook.
- Do not edit older date-stamped notebooks.
- All changes for these tickets should occur in the new `2026-06-26` notebook copy.
- Keep the notebook PDF behavior unchanged:
  - scientific code visible,
  - shaded/boxed code blocks,
  - scientific outputs visible,
  - QA/QC artifacts written to disk,
  - no long QA/QC report pages printed in the PDF.
- Do not introduce separate execution modes beyond dataset fraction:
  - pilot fraction < 1,
  - full fraction = 1.

## Acceptance criteria

- A dated working notebook copy exists.
- The copied notebook renders in 1% pilot mode before any substantive changes.
- The copy preserves current primary outputs and diagnostics.

---

# Implementation sequence

Implement the following five tickets sequentially.

## Ticket 1
**Timing diagnostic for blood gas measurement vs IMV/NIV timing**

Purpose: determine whether ABG is often drawn same-day or after IMV/NIV, consistent with ventilator-management rather than pre-outcome prognosis.

## Ticket 2
**Timing-stratified weighted outcome-rate diagnostics**

Purpose: determine whether ABG-VBG absolute risk differences are concentrated in pre/same-day ventilatory-support contexts.

## Ticket 3
**No-lactate propensity-weighting sensitivity**

Purpose: determine whether lactate is acting as a test-pathway/post-test covariate rather than only a baseline severity covariate.

## Ticket 4
**Pre-gas / temporally conservative covariate propensity model**

Purpose: determine whether results are robust when the sampling model uses only covariates plausibly available before blood gas ordering.

## Ticket 5
**Acute severity / workflow proxy sensitivity**

Purpose: determine whether adding same-encounter acute severity and workflow proxies attenuates residual ABG-VBG absolute risk differences.

---

# Run plan

## After each ticket

Run a **1% pilot render** after implementing each individual ticket.

For each 1% run, verify:

- notebook completes,
- no primary artifacts break,
- new diagnostic files are generated,
- no table clipping or missing columns,
- no new hard diagnostic failures,
- warnings are proportionate and interpretable,
- new analyses are clearly labeled as diagnostics/sensitivity analyses.

Do **not** interpret 1% numerical findings substantively.

## After all five tickets

Run a final **1% integrated verification render** with all five analyses active.

Then run the **full dataset rerender** only if the integrated 1% render is structurally clean.

## Full run acceptance criteria

- Full render completes.
- All five diagnostic/sensitivity bundles render or export correctly.
- Primary analysis artifacts remain unchanged unless intentionally updated.
- Final diagnostic summary distinguishes:
  - likely same-day/post-intubation ABG use,
  - lactate/test-pathway sensitivity,
  - temporally conservative model sensitivity,
  - acute severity/workflow proxy sensitivity,
  - persistent residual context differences.
- The full run produces a concise interpretation note suitable for manuscript revision.

---

# Global output files

Each ticket should write outputs into a clearly named diagnostic subdirectory, for example:

```text
Results/sensitivity_reverse_timing/
Results/sensitivity_timing_stratified_rates/
Results/sensitivity_no_lactate/
Results/sensitivity_pregas_covariates/
Results/sensitivity_acute_workflow/
```

Create a final combined summary:

```text
Results/reverse_timing_severity_sensitivity_summary.md
Results/reverse_timing_severity_sensitivity_summary.csv
```

The combined summary should state:

- which analyses were implemented,
- what each found,
- whether ABG-VBG absolute risk differences were attenuated,
- whether relative association patterns remained stable,
- which explanation is most supported,
- and what manuscript wording should change.

---

# Global interpretation framework

Use this language to keep interpretation disciplined:

> These diagnostics evaluate whether the observed absolute-risk differences between ABG- and VBG-tested cohorts are explained by timing, co-measured covariates, or residual clinical-context differences. They do not change the primary estimand unless they reveal a clear implementation flaw.

If differences persist:

> Persistent absolute-risk differences after these sensitivity checks would suggest that ABG and VBG are ordered in different clinical contexts not fully captured by measured covariates, especially for broad severity outcomes such as IMV and mortality.

If differences attenuate:

> Attenuation of ABG-VBG absolute-risk differences after timing restrictions or covariate-set changes would suggest that same-day/post-outcome testing or post-test covariates partially explain the risk-scale differences.

---

# Non-goals

Do not:
- replace the primary analysis automatically,
- force ABG and VBG risks to be equal,
- add post-outcome variables to the primary propensity model without clearly labeling sensitivity analyses,
- hide scientific code from the PDF,
- interpret 1% pilot results substantively,
- use these diagnostics to claim equivalence or noninferiority.

---

# Final deliverables

1. Dated working notebook copied from current notebook.
2. Five implemented diagnostic/sensitivity modules.
3. Five 1% pilot render logs or output bundles, one after each module.
4. One integrated 1% verification render.
5. One full dataset rerender.
6. Combined sensitivity summary markdown/CSV.
7. Proposed manuscript interpretation language.
