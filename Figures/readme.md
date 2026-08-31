# Figures — Study 1 and Study 2

R notebooks generating the code-produced paper figures (Main Figs. 3–6 and SI
Fig. S1), with outputs in `figure/` (PDF, PNG, and SVG). The same directory also
contains byte-for-byte copies of the current manually authored Main Figs. 1 and
2. The canonical notebooks use publication-size Helvetica typography, explicit
physical stroke widths, and 300-dpi PNG export.

## Data (`data/`)

| File | Description |
|------|-------------|
| `Study_1_Objective_Data.xlsx` | LLM objective accuracy (Study 1) |
| `Study_1_Subjective_Data.xlsx` | Human subjective ratings (Study 1) |
| `Correction_Data.csv` | Early/late correction data for the Study 2 correction figure |
| `Correction_Timing_Contrasts.csv` | Model-derived early/late contrasts and p-values used in Figure 5 |

Main Figs. 5–6 and Fig. S1 read the canonical Study 2 full-sample workbook
directly from
`../Study_2_FollowUp_Results/MAR/data/Study_2_Full_Data.xlsx`; no separately
maintained plotting workbook is required.

## Notebooks

| File | Figure |
|------|--------|
| `Figure_Study1_1.Rmd` | Main Fig. 3: Study 1 LLM accuracy and run-to-run variability |
| `Figure_Study1_2.Rmd` | Main Fig. 4: Study 1 quality ratings by model and rater group |
| `Figure_Study2_1.Rmd` | Main Fig. 5: Study 2 accuracy trajectories and correction timing |
| `Figure_Study2_2.Rmd` | Main Fig. 6: confidence, willingness, and perceived usefulness |
| `Figure_S01_AI_Related_Measures.Rmd` | Fig. S1: AI attitudes, literacy, and self-efficacy over time |
| `plot_util_test.R` | Helper `data_preprocessing()`: wide→long reshape, within-subject normalisation, Cousineau–Morey 95% CIs |

Each notebook writes its figure to `figure/` in PDF, PNG, and SVG.

## Static figures

| File | Figure |
|------|--------|
| `figure/Figure_01_Study1_Workflow.pdf` | Main Fig. 1, publication artwork |
| `figure/Figure_01_Study1_Workflow.png` | Main Fig. 1, raster preview |
| `figure/Figure_02_Study2_Participant_Flow_and_Procedure.pdf` | Main Fig. 2, publication artwork |

`Study_1_Objective_Data.xlsx` is synchronized with the objective-analysis copy;
`Study_1_Subjective_Data.xlsx` is value-identical to the subjective-analysis
copy. `Correction_Data.csv` and `Correction_Timing_Contrasts.csv` are regenerated
by `../Study_2_Early_Late_Correction/Comparison.Rmd` before Fig. 5.

Displayed P values are computation-driven: Fig. 3 fits the same Study 1
thinking-mode model as the objective-analysis notebook; Fig. 5 reads the
generated correction contrasts; Fig. 6 reads the generated full-sample H2
contrasts and fits the documented completer-only H2 models; and Fig. S1 reads
the generated immediate and completer H2 contrasts or fits its documented MAR
models.

Packages are pinned in the top-level `renv.lock`; figure-specific dependencies
include `cowplot`, `lemon`, `patchwork`, `ggtext`, `gridExtra`, `gtable`,
`Rmisc`, `lme4`, `lmerTest`, and `emmeans`.
