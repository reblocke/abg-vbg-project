# Sentinel Procedure Specificity Note

Sentinel v2 selection prioritizes procedures that are common enough to audit capture/completeness but less tightly linked to the respiratory/cardiac pathway than NIV or IMV.

Selected sentinels:
- Chest radiograph (`cxr1v`): capture_or_documentation_sentinel; specificity=medium; workflow_dependence=medium.
- Transthoracic echocardiography (`tte_proc`): workflow_or_documentation_sentinel; specificity=high; workflow_dependence=high.
- CT chest / CT pulmonary angiography (`ctccon`): workflow_or_documentation_sentinel; specificity=high; workflow_dependence=high.

High-specificity or high-workflow-dependence candidates are interpreted as workflow/documentation sentinels rather than pure procedure-capture sentinels.
