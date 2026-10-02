# Exploratory 14-month follow-up

This module reproduces the current long-term extension from deposited analysis-ready data. The long-term wave was not preregistered. The choices to report both-follow-up completers as primary and to exclude reported external tool/material use followed inspection of earlier long-term results. The original randomized study and historical one-month analyses retain their original populations.

Run from the repository root, after restoring the nested pinned R environment as described in the repository setup instructions:

```sh
Rscript --vanilla Study_2_LongTerm_Results/run.R --qc-only
Rscript --vanilla Study_2_LongTerm_Results/run.R
```

`--out /absolute/output/directory` redirects all generated records, results, tables and private fit caches. Python 3 uses only its standard library; `LONGTERM_PYTHON` can select its executable. `run.R` checks the exact R/package versions before proceeding and installs no analysis packages. Its activation script can bootstrap the pinned `renv` infrastructure if absent; restore the environment before running. The repository's ordered `reproduce.R` workflow calls this module before the long-term figures.

The data contain 175 original analytic participants, 44 recorded long-term submissions, five exclusions for reported tools/materials, 39 eligible returners, and 33 eligible participants with both follow-ups. All-wave MAR sensitivity models omit the five excluded people, giving 170, or 168 with complete covariates. Eligibility is self-report; it does not prove absence of assistance. The six eligible returners without one-month data are descriptive overall only.

`data/cohort.csv` contains participant-level task/overall scores and necessary covariates; `data/items.csv` contains correctness records; `data/intervals.csv` contains eligible follow-up intervals. Public numeric keys preserve source numeric ordering but no source-key lookup is deposited. `follow2_returned` distinguishes recorded returns from nonreturns. The five excluded participants' long-term outcomes and auxiliary fields are deliberately blank; their return/tool-use flags support counts and exclusions. Other blank follow-up outcomes mean not collected. Eligible outcomes and historical scores are unchanged. Interval records for excluded people are omitted. Public intervals are rounded to 0.1 day; the reported one-decimal summaries for the 33/39 samples are unchanged. Intervals are descriptive metadata and are not model inputs. The aggregate all-44 interval summary supports the submission-window description.

`input_manifest.json` pins every consumed input, including aggregate positive controls under `historical_controls/` and the earlier deposited item workbook used for independent one-month rescoring. Historical controls are restricted to the no-tools rows with the same current participants; they do not supply evidence for obsolete long-term populations.

Before fitting, the pipeline strictly checks schema, keys, joins, missingness, scale/grid validity, independent accuracy rescoring, eligibility, sample relations and timing rows. Actual synthetic fault/valid fixtures cover unknown and missing tool responses, nonreturn precedence, privacy suppression and row order. The R fitting entry guard checks the nested R/package versions; every R entry guard verifies the exact bound data/code/contract/QC/model-lock snapshot and independently rederives sample fingerprints. `records/QC_PLAN.md`, `QC_REPORT.md` and `discrepancy_log.csv` describe the scoped gate. Changed bound files invalidate readiness.

Numerical outputs are aggregate CSVs in `results/`; `tables/Supplementary_Tables_S22-S24_no_tools.md` is generated from them. Fitted objects, membership registries, keys and synthetic guard data remain in ignored `private/` caches. The compatibility field named `private_inputs` in the ignored runtime configuration points exclusively to these public `data/` files; it does not require any private source data.

The primary estimand is an observed within-person mean change among the 33 eligible completers, with equal task weights. Other paired, label-balanced and full-cohort MAR specifications target different populations or assumptions. The 17-item weighting is a separate accuracy sensitivity and is used in the manuscript accuracy figures. Neither nonsignificance nor similar values establishes equivalence or sustained causal label effects.

Two strict model qualifications from the executed analysis are retained: the unadjusted full-cohort GLS uses residual df when its approximate variance matrix is unavailable, and the task-adjusted confidence continuation is singular. `records/verification.json` separates numerical checks from these diagnostics; an overall `QUALIFIED` result is not an unqualified model pass.

The public adapter's recorded development validation used R 4.5.1/macOS
arm64 with `C.UTF-8` collation. The frozen analysis recorded `en_US`
collation; both order the published factor categories identically on the
recorded R build. This is
near-canonical (Tier B) execution, with documented locale and public-input
adaptations. Comparisons use named CSV cells rather than container bytes.
The eight interval-summary cells can differ at four decimals after privacy
rounding; every reported one-decimal summary is preserved. Plain `C`/POSIX
collation can change age-factor level order, so cell identity under that
locale is not established. Record the locale in `sessionInfo()` when
reproducing the adjusted models. The recorded development run also emitted
warnings that the pinned `lme4` and `emmeans` binaries were built under
R 4.5.2 while the runtime was R 4.5.1; package-version equality does not
establish identical binary build environments.

Reproduction starts at deposited scores and correctness records. Complete historical acquisition/delivery, independent private roster linkage, administration/consent/ethics records and two unmatched submissions are outside this module. Current numerical checks do not establish that missing source evidence passed.
