# Study 2 — Long-Term Main Analysis (MAR, Analytic *N* = 175)

The main long-term analysis reported in the paper body. Uses the full Study 2
sample (*N* = 175) and handles missing follow-up data under a missing-at-random
(MAR) assumption — mixed-effects models that use all available data. The
completers-only sensitivity check is the sibling
[`../Follow-Up Completers Only/`](../Follow-Up%20Completers%20Only/) (*N* = 84);
both run the same H1/H2/H3 models.

## Data (`data/`)

`Study_2_Full_Data.xlsx` — 178 deposited initial-session participants,
including follow-up non-completers. The notebook removes three ceiling cases
and fits the reported MAR models to the analytic *N* = 175.
Variables follow Study 2 Main (see `../../Study_2_Main_Results/readme.md`), plus
`drop` (follow-up non-completion: `0` = completed, `1` = dropped) used by the
attrition diagnostics.

`Followup_Interval_Days.xlsx` — one row for each of the 178 deposited
participants, containing the pseudonymous participant ID, assigned label,
follow-up-pairing flag, and observed interval in days for the 87 respondents.
The file omits the initial and follow-up submission timestamps because the
derived interval-days values are sufficient to reproduce the reported
descriptives.

The deposited analysis file excludes exact submission timestamps; the separate
interval-days input provides everything needed to reproduce the interval
descriptives. The derived `follow_activity_0` value for participant 191 is
3.50, matching the mean of the four component items; the analysis notebooks
use the component items and are unaffected by this correction.

> **Exclusion:** the deposited file has 178 rows. Three participants with
> `stage1_task0_accuracy >= 0.9` are removed by the ceiling filter, yielding the
> analytic *N* = 175.

## Notebooks

| File | Description |
|------|-------------|
| `Study 2 MAR Results.Rmd` | Main analysis: H1 long-term accuracy; H2 long-term confidence and attitude change (Pre→Follow, Pre→Post→Follow); H3 moderation — full sample under MAR |
| `Study 2 Drop Comparison.Rmd` | Attrition diagnostic: completers vs. dropouts on accuracy, confidence, and pre/post attitudes |
| `Study 2 Drop Demographic Results.Rmd` | Demographic comparison of completers vs. dropouts (chi-square) |
| `p-value adjudication.Rmd` | Holm/BH corrections for H3 moderation p-values (MAR + completer samples) |

`Study 2 MAR Results.Rmd` is CPU-bound and often takes 30+ minutes from scratch;
the exact time is hardware-dependent. A local knitr cache can make repeat
rendering faster, but `Study-2-MAR-Results_cache/` is
ignored and is not present in a clean clone. The root `reproduce.R` runner
removes ignored `*_cache` directories before rendering so its output-freshness
checks remain valid on repeated local runs.

## Outputs (`results/MAR/`)

Generated workbooks in per-hypothesis subfolders (`Baseline/`, `H1/`, `H2/`, `H3/`).

**`Study 2 MAR Results.Rmd`**

| Workbook | Contents |
|----------|----------|
| `H1/H1_Performance_Comparison_LMM.xlsx`, `_LMM_Task.xlsx` | Registered participant-intercept H1 long-term accuracy model and the task-interaction analysis: summary, ANOVA, partial η², and post-hoc contrasts |
| `H1/H1_Model_Specification_Comparison.xlsx`, `.csv` | Registered participant-intercept model and expanded task-structured sensitivity models without and with attrition covariates |
| `H2/H2_Longterm_Confidence_Change.xlsx` | H2 long-term confidence: simple effects + post-hoc |
| `H2/H2_Attitude_Change_Longterm_PF.xlsx`, `_PPF.xlsx` | H2 attitude change Pre→Follow / Pre→Post→Follow |
| `H3/H3_Attitude_Change_Longterm_Moderation_PF.xlsx` / `_PPF.xlsx`, `H3/H3_Attitude_Longterm_Moderation_Summary_PF.xlsx` / `_PPF.xlsx` | H3 attitude moderation models + per-term F/p |
| `H3/H3_Performance_Confidence_Longterm_Moderation.xlsx` (+ `_Summary.xlsx`) | H3 performance/confidence moderation + summary |
| `H3/H3_Moderation_Padjust_PF.xlsx` / `_PPF.xlsx`, `H3/H3_Performance_Confidence_Moderation_Padjust.xlsx` | Holm/BH-adjusted moderation p-values |

**`Study 2 Drop Demographic Results.Rmd`** → `Baseline/Demographic_Results_Drop.xlsx`.
`Study 2 Drop Comparison.Rmd` prints to HTML only.

`Study 2 MAR Results.Rmd` regenerates
`Baseline/Followup_Interval_Descriptives.xlsx` from
`data/Followup_Interval_Days.xlsx`. It reports aggregate intervals for all 87
follow-up respondents and the 84 analytic completers without participant
identifiers or exact timestamps.

Packages (pinned in the top-level `renv.lock`): `broom`, `car`, `DescTools`,
`dplyr`, `tidyr`, `stringr`, `forcats`, `DT`, `effectsize`, `emmeans`, `ggplot2`,
`interactions`, `janitor`, `lme4`, `lmerTest`, `lsr`, `MASS`, `openxlsx`,
`readxl`, `ordinal`, `performance`, `report`.
