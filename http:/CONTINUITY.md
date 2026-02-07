Goal (incl. success criteria):
- Stabilize reproducibility checks so `renv` no longer reports false out-of-sync from archived files, and make preflight deterministic before long Quarto renders.

Constraints/Assumptions:
- Keep `renv` as authoritative environment manager for this R/Quarto project.
- No changes to analysis estimands/models; environment and workflow hardening only.

Key decisions:
- Add `.renvignore` to exclude archival folders (`Code Drafts/Prior versions/`, `Code Drafts/logistic/`, `Drafts/`, `Results/`, `http:/`).
- Run preflight via `Rscript --vanilla scripts/check_env.R` and explicitly activate/load project `renv` inside the script.

State:
- Complete for this milestone: `renv::status()` is synchronized and preflight passes via scripted invocation.

Done:
- Added `.renvignore`.
- Installed missing `shiny` package into project `renv` and snapshotted lockfile.
- Updated `scripts/check_env.R` to run deterministic `renv::status()` checks and fail with actionable guidance.
- Updated `scripts/render_pdf.sh` to run preflight via `Rscript -e "source('scripts/check_env.R')"`.
- Updated docs command examples in `README.md` and `CONTRIBUTING.md`.
- Verified:
  - `Rscript -e "renv::status()"` -> `No issues found -- the project is in a consistent state.`
  - `Rscript -e "source('scripts/check_env.R')"` -> preflight passed.

Now:
- Ready for user-triggered Quarto render with preflight wrapper.

Next:
- Keep lockfile update policy (`renv::snapshot()` on dependency intent change).

Open questions (UNCONFIRMED if needed):
- None.

Working set (files/ids/commands):
- /Users/reblocke/Research/abg-vbg-project/.renvignore
- /Users/reblocke/Research/abg-vbg-project/scripts/check_env.R
- /Users/reblocke/Research/abg-vbg-project/scripts/render_pdf.sh
- /Users/reblocke/Research/abg-vbg-project/README.md
- /Users/reblocke/Research/abg-vbg-project/CONTRIBUTING.md
- /Users/reblocke/Research/abg-vbg-project/renv.lock
- Rscript -e "renv::status()"
- Rscript -e "source('scripts/check_env.R')"
