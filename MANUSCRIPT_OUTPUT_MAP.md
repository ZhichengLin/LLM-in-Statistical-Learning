# Manuscript and SI output map

Current source mapping: `Main v2.docx` and `SI v2.docx`, verified on 2026-10-03,
with the title **Learning statistical concepts with generative AI: evidence
from longitudinal, randomized source-label experiments**. The authoring DOCX
files and their source fingerprints remain internal.

Main has Figures 1–6 and no numbered tables. SI has Texts S1–S5, Fig. S1, and
Tables S1–S24; there is no Fig. S2 target. Run `Rscript reproduce.R all` after
restoring both documented environments. Runner IDs are invoked from the
repository root. Paths below are relative to the named working directory
unless a repository-root path is shown.

The map identifies producing sources and computational boundaries. “Generated”
means that the named entry point produces the target, not that an unrecorded
fresh run has passed. The Oct 3 source audit matched all 101 numeric rows of the
new SI table blocks to the frozen aggregate results. Release verification
requires the complete `all` workflow in a clean clone after restoring both
pinned environments, with the tested commit, environment, exit status and
output checks recorded in the release notes. Historical scoped checks below
establish only their stated scope.

Generation terms:

- **Generated**: the ordered entrypoint regenerates the analysis output.
- **HTML only**: the value is printed in rendered HTML but no stable table
  workbook/CSV is exported.
- **Static/materials**: the target is an instrument, metadata record, or
  editorial figure rather than a code-generated statistical output.
- **Provenance gap**: the reported value cannot be independently rebuilt from
  the deposited inputs.

## Main-text targets

| Main target | Reported result or role | Runner task / working directory | Canonical input | Canonical output | Status and notes |
|---|---|---|---|---|---|
| Fig. 1, Study 1 workflow | Benchmark, blinded ratings, and selected explanations | `S1-objective-descriptives`, `S1-quality-descriptives`, `S1-material-selection`; objective, subjective, and materials folders | Study 1 objective/subjective data; `Materials/Study_1_Subjective_Evaluation.docx` | Objective/subjective HTML; selection CSVs; `Figures/figure/Figure_01_Study1_Workflow.{pdf,png}` | **Selection chain generated; final figure static.** The root runner verifies both static files by SHA-256. |
| Fig. 2, Study 2 flow/procedure | 220 randomized → 178 screened → 175 analytic; 84 one-month completers; 44 long-term returns − 5 reported-assistance users = 39 eligible, including 33 with both follow-ups and 6 without one-month data | `S2-initial-session`, `S2-followup-MAR`, `S2-followup-completers`, `S2-longterm`; historical and long-term folders | Original Study 2 workbooks; `Study_2_LongTerm_Results/data/cohort.csv` | `Figures/figure/Figure_02_Study2_Participant_Flow_and_Procedure.pdf`; `Study_2_LongTerm_Results/results/sample_flow.csv` | **Static artwork; downstream counts generated.** The runner hash-checks the PDF. The deposited data reproduce 178→175, the original 84, and long-term 44→5→39→33/6. The 220→178 screen remains an upstream provenance boundary. |
| Study 1 model accuracy and stability; Fig. 3 | Accuracy .76-1.00; GPT-4o/o1 = 1.00; mode tests P=.530/.198 | `S1-objective-descriptives`, `S1-objective-models`, `Figure-3`; `Study_1_Objective_Results/`, `Figures/` | `Study_1_Objective_Results/data/Study_1_Objective_Data.xlsx` | `Study_1_Objective_Results/Study-1-Objective-Descriptive-Results.html`; `Study_1_Objective_Results/Study-1-Objective-Model-Results.html`; `Figures/figure/Figure_Study1_1.{pdf,png,svg}` | **Generated.** The displayed mode-test P value is calculated from the canonical data and model specification. |
| Study 1 instructional quality; Fig. 4 | Top-bottom difference .24; Group x Rater P=.045 | `S1-quality-descriptives`, `S1-quality-models`, `Figure-4`; `Study_1_Subjective_Results/`, `Figures/` | `Study_1_Subjective_Results/data/Study_1_Subjective_Data.xlsx` | `Study_1_Subjective_Results/Study-1-Subjective-Decriptive-Results.html`; `Study_1_Subjective_Results/Study-1-Subjective-Model-Results.html`; `Figures/figure/Figure_Study1_2.{pdf,png,svg}` | **Generated.** |
| Study 1 material selection | GPT-4o iteration 2 (P value); o1 iteration 3 (confidence interval); GPT-4o iteration 2 (study comparison) | `S1-material-selection`; `Study_1_Subjective_Results/` | Study 1 subjective ratings | `results/Study_2_Selected_Materials.csv` plus the full candidate CSV | **Generated.** |
| Study 2 participant groups and baseline balance | N=175; 59/58/58; all balance P>.155 | `S2-initial-session`, `S2-initial-demographics`; `Study_2_Main_Results/` | `data/Study_2_Main_Results_Data.xlsx` | `results/Baseline/Demographic_Results.xlsx`; `results/Baseline/Baseline_Charateristics_By_Label.xlsx` | **Generated.** |
| Immediate accuracy Stage x Label | F(4,1394)=2.68, P=.030; S1-S2 gains 1.7/10.6/8.8 points | `S2-initial-session`; `Study_2_Main_Results/` | Main Study 2 data | `results/H1/H1_Performance_Comparison_LMM.xlsx` | **Generated.** |
| Immediate accuracy sensitivities | Task-structured P=.006; item-level and manipulation-recall results | `S2-initial-session`; `Study_2_Main_Results/` | Main Study 2 and item-level data | `results/H1/H1_Performance_Comparison_LMM_Task.xlsx`; `H1_Performance_ItemLevel_Binomial_GLMM.xlsx`; `H1_Model_Specification_Comparison.xlsx`; `H1_Performance_Comparison_LMM_PassersOnly.xlsx`; `H1_Performance_Comparison_LMM_PerceivedLabel.xlsx`, all under `results/H1/` | **Generated.** |
| Follow-up accuracy | Four-stage P<.001; registered Stage x Label P=.089; task sensitivities P=.024/.028; completer P=.408; attrition-covariate sensitivity n=173 | `S2-followup-MAR`, `S2-followup-completers`; MAR and completer folders | 178 physical/175 analytic full sample; 87 physical/84 analytic completers | MAR `results/MAR/H1/H1_Performance_Comparison_LMM.xlsx`, `H1_Model_Specification_Comparison.xlsx`, and `H1_Performance_Comparison_LMM_Task.xlsx`; completer `results/Follow-Up Activity/H1/H1_Stage1_Longterm_Accuracy_Comparison_LMM.xlsx` | **Generated.** |
| Correction timing; Fig. 5B | 82 participants/565 item observations; Early vs. late OR=2.55; interaction P=.049; AI+Human OR=5.97 | `S2-correction-timing`, then `Figure-5`; correction and figure folders | `Study_2_Early_Late_Correction/data/correction_raw_data.xlsx`; `Study_2_Early_Late_Correction/data/manipulation_recall.xlsx` | `Study_2_Early_Late_Correction/Comparison.html`; `Figures/data/Correction_Data.csv`; `Figures/data/Correction_Timing_Contrasts.csv`; `Figures/figure/Figure_Study2_1.{pdf,png,svg}` | **Generated; overall OR is HTML only.** |
| Accuracy trajectories; Fig. 5A | Available-sample five-assessment accuracy (175/84/33), plus Stages 1–3 comparisons of those samples | `S2-longterm`, then `Figure-5`; `Study_2_LongTerm_Results/`, `Figures/` | Original full-sample workbook and `Study_2_LongTerm_Results/data/cohort.csv` | `Figures/figure/Figure_Study2_1.{pdf,png,svg}`; `Figures/data/fig5_*summaries.csv`, `fig5_primary33_*.csv`, `fig5_checks.csv` | **Generated from deposited inputs.** Overall 17-item weighting is retained for continuity. Lines connect changing available samples, not matched within-person changes. Current PDF export requires macOS Quartz/Helvetica. |
| Immediate confidence | S2-S3 changes .04/.24/.15; Stage x Label P<.001 | `S2-initial-session`; `Study_2_Main_Results/` | Main Study 2 data | `results/H2/H2_Within_Task_Attitude_Perceptions.xlsx` | **Generated.** |
| Follow-up confidence | Follow-up vs. S1/S2/S3 +.23/-.15/-.29; Stage x Label P=.009 | `S2-followup-MAR`, `S2-followup-completers`; follow-up folders | Full-sample/completer data | MAR `results/MAR/H2/H2_Longterm_Confidence_Change.xlsx`; completer `results/Follow-Up Activity/H2/H2_Longterm_Confidence_Change.xlsx` | **Generated.** |
| Willingness/usefulness; Fig. 6B-C | AI changes -.11/-.13; interactions P=.013/.014 | `S2-initial-session`, `Figure-6-completer-tests`, then `Figure-6`; main and figure folders | `Study_2_Main_Results/data/Study_2_Main_Results_Data.xlsx`; `Study_2_FollowUp_Results/MAR/data/Study_2_Full_Data.xlsx`; generated main H2 workbook; required `Figures/data/fig6_panel_bc_p_values.csv` | `Study_2_Main_Results/results/H2/H2_Within_Task_Attitude_Perceptions.xlsx`; `Figures/data/figure6_completer_tests.csv`; `Figures/figure/Figure_Study2_2.{pdf,png,svg}`; refreshed `Figures/data/fig6_panel_bc_p_values.csv` | **Generated with a required startup control.** Full-sample and independently regenerated original completer contrasts must reproduce all twelve preserved three-decimal labels. The label CSV must remain present before startup; rendering refreshes its provenance descriptions. Figure 6 fits no models. |
| Confidence trajectories; Fig. 6A | Available-sample five-assessment confidence (175/84/33), plus Stages 1–3 sample comparisons | `S2-longterm`, then `Figure-6`; `Study_2_LongTerm_Results/`, `Figures/` | Original full-sample workbook and `Study_2_LongTerm_Results/data/cohort.csv` | `Figures/figure/Figure_Study2_2.{pdf,png,svg}`; `Figures/data/fig6_*summaries.csv`, `fig6_primary33_*.csv`, `fig6_three_stage_sample_comparison.csv`, `fig6_checks.csv` | **Generated from deposited inputs.** Original overall confidence means and between-person t intervals are retained. Lines connect changing available samples. Panels B/C remain historical outcomes; current PDF export requires macOS Quartz/Helvetica. |
| AI attitudes, literacy, self-efficacy | Phase effects and Phase x Label nulls; Fig. S1 | `S2-initial-session`, `S2-followup-MAR`, `S2-followup-completers`, `Figure-S1` | Canonical full-sample data and H2 model outputs | main `results/H2/H2_Attitude_Change_Immediate_Results.xlsx`; MAR/completer H2 PF/PPF workbooks; `Figures/figure/Figure_S01_AI_Related_Measures.{pdf,png,svg}` | **Generated; all displayed P values are model-derived.** |
| Perceived learning, satisfaction, sign-up, and follow-up behavior | No detectable label effects in the broader post-task/follow-up outcomes | `S2-initial-session`, `S2-followup-completers`; main and completer folders | Main and completer participant data | `results/H2/Post_Survey_Experience.xlsx`; `results/Follow-Up Activity/H2/Continued_Use_Application.xlsx` | **Generated.** |
| Exploratory 14-month accuracy, Main Results | Primary 33: LT−S1 +13.6 pp, LT−S3 −19.2 pp, LT−M1 +0.8 pp; eligible-39 sensitivity and separate 170/168 MAR continuations | `S2-longterm`; `Study_2_LongTerm_Results/` | `data/cohort.csv`; `analysis_contract.yaml` | `results/paired_contrasts.csv`, `fullcohort_gls_contrasts.csv`, `fullcohort_lmer_contrasts.csv` | **Generated; exploratory.** Primary equal-task weighting; Holm within three contrasts per family. LT−M1 uses the same 33 observed pairs in the primary and eligible-39 families; the +7.0 pp full-cohort MAR estimate has a different target and df qualification. |
| Exploratory 14-month confidence, Main Results | Primary 33: LT−S1 +0.40 scale points; LT−M1 +0.17 with Holm P=.093 | `S2-longterm`; `Study_2_LongTerm_Results/` | `data/cohort.csv` | `results/paired_contrasts.csv`; confidence sensitivity and diagnostic CSVs | **Generated; exploratory.** Equal-task confidence, recorded 1–5 scale; singular task-adjusted confidence model is not used for main-text inference. |
| Long-term administration interval, Main Methods | Historical all-44 mean 438.0 days, SD 4.0, range 429.3–448.1 | Source-record summary; eligible-39/primary-33 summaries generated by `S2-longterm` | Public `data/intervals.csv` contains eligible 39 only; `historical_controls/all44_interval_summary.csv` retains the original 44-person aggregate | `results/auxiliary_counts.csv` regenerates 33/39 summaries; the all-44 aggregate is retained metadata | **Bounded source summary.** The deposited all-44 aggregate matches the manuscript summary; it cannot be regenerated from the eligible-only interval input. |

## SI targets

| SI target | Contents | Runner task(s) | Working directory | Canonical input | Canonical output | Status and notes |
|---|---|---|---|---|---|---|
| Text S1 | Preregistration deviations, implemented original analyses, and exploratory 14-month reporting decisions | Mapped original tasks plus `S2-longterm` | `Materials/` and analysis folders | Registrations, materials, original inputs, and `Study_2_LongTerm_Results/analysis_contract.yaml` | Source R/Rmd, retrospective long-term contract, and mapped outputs | **Mixed documentary/executable evidence.** Long-term primary-sample and assistance-exclusion decisions followed initial results. Raw platform history, linkage, and 220→178 screening remain upstream boundaries. |
| Text S2 | Detailed methods, task materials, instruments, cohort construction, follow-up interval, and statistical specifications | all mapped Study 1 and Study 2 tasks | `Materials/` and all analysis folders | Deposited materials and analysis-ready inputs, including `Study_2_FollowUp_Results/MAR/data/Followup_Interval_Days.xlsx` | Source R/Rmd, folder READMEs, `DATA_DICTIONARY.md`, `Study_2_FollowUp_Results/MAR/results/MAR/Baseline/Followup_Interval_Descriptives.xlsx`, and mapped outputs below | **Methods documented and analyses executable.** Model-service collection and the unavailable 220→178 screening records remain upstream boundaries. |
| Text S3 | Study 1 task patterns, thinking-mode tests and paired sensitivity, rater-specific quality results, and material selection | `S1-objective-descriptives`, `S1-objective-models`, `S1-quality-descriptives`, `S1-quality-models`, `S1-material-selection` | Study 1 objective and subjective folders | objective benchmark and subjective-rating workbooks | objective/subjective HTML; `results/Study_2_Selected_Materials.csv` and candidate CSV; Table S1 CSV | **Generated; inferential details are in HTML.** |
| Text S4 | Supplementary initial-session/one-month Study 2 results, sensitivities, correction timing, and moderation | Original Study 2 tasks | Main, MAR, completer, correction, and figure folders | Original participant/item inputs | Original HTML, H1–H3 outputs, and Figs. 5–6/S1 historical panels | **Generated apart from the stated participant-flow boundary.** The exploratory 14-month extension is separately mapped to Text S5. |
| Fig. S1 | AI attitudes, literacy, and self-efficacy over time | `S2-initial-session`, `S2-followup-MAR`, `S2-followup-completers`, `Figure-S1` | Study 2 main/MAR/completer folders; `Figures/` | Canonical full-sample participant data and H2 model outputs | `Figures/figure/Figure_S01_AI_Related_Measures.{pdf,png,svg}` plus H2 workbooks | **Generated; displayed P values are model-derived.** |
| Table S1 | Model/task means and SDs; overall accuracy/stability; thinking-mode tests | `S1-objective-descriptives`, `S1-objective-models` | `Study_1_Objective_Results/` | `data/Study_1_Objective_Data.xlsx` | `results/Study_1_Objective_Table_S01_Panel_A.csv`; both objective HTML files for Panel B | **Generated; Panel A CSV plus Panel B HTML.** |
| Table S2 | Composite instructional-quality ratings and mixed models | `S1-quality-descriptives`, `S1-quality-models` | `Study_1_Subjective_Results/` | `data/Study_1_Subjective_Data.xlsx` | `Study-1-Subjective-Decriptive-Results.html`; `Study-1-Subjective-Model-Results.html` | **HTML only.** |
| Table S3 | Objective top-two identity, selected explanation/model/iteration, model task accuracy, instructor rating, tie-break | `S1-material-selection` | `Study_1_Subjective_Results/` | Local subjective ratings plus `../Study_1_Objective_Results/data/Study_1_Objective_Data.xlsx` | `results/Study_2_Selected_Materials.csv`; candidate CSV | **Generated.** |
| Table S4 | Demographic/background balance | `S2-initial-demographics` | `Study_2_Main_Results/` | `data/Study_2_Main_Results_Data.xlsx` | `results/Baseline/Demographic_Results.xlsx` | **Generated.** |
| Table S5 | Baseline AI measures by label | `S2-initial-session` | `Study_2_Main_Results/` | `data/Study_2_Main_Results_Data.xlsx` | `results/Baseline/Baseline_Charateristics_By_Label.xlsx` | **Generated.** |
| Table S6 | Immediate omnibus accuracy/confidence/willing/useful models | `S2-initial-session` | `Study_2_Main_Results/` | `data/Study_2_Main_Results_Data.xlsx`; `data/correction_raw_data.xlsx` | `results/H1/H1_Performance_Comparison_LMM.xlsx`; `results/H1/H1_Model_Specification_Comparison.xlsx`; `results/H2/H2_Within_Task_Attitude_Perceptions.xlsx` | **Generated.** |
| Table S7, Panel A | Preregistered participant-intercept accuracy comparisons | `S2-initial-session` | `Study_2_Main_Results/` | main participant data | `results/H1/H1_Performance_Comparison_LMM.xlsx` | **Generated.** |
| Table S7, Panel B | Task-structured accuracy sensitivity comparisons | `S2-initial-session` | `Study_2_Main_Results/` | main participant data | `results/H1/H1_Performance_Comparison_LMM_Task.xlsx` | **Generated.** |
| Table S7, Panel C | Initial-session confidence, willingness, and usefulness comparisons | `S2-initial-session` | `Study_2_Main_Results/` | main participant data | `results/H2/H2_Within_Task_Attitude_Perceptions.xlsx` | **Generated.** |
| Table S7, Panel D | Full-sample covariate-adjusted four-stage confidence comparisons | `S2-followup-MAR` | `Study_2_FollowUp_Results/MAR/` | full participant data | `results/MAR/H2/H2_Longterm_Confidence_Change.xlsx` | **Generated.** |
| Table S7, Panel E | Completer-only covariate-adjusted four-stage confidence comparisons | `S2-followup-completers` | `Study_2_FollowUp_Results/Follow-Up Completers Only/` | completer participant data | `results/Follow-Up Activity/H2/H2_Longterm_Confidence_Change.xlsx` | **Generated.** |
| Table S7, Panel F | Added post hoc S2-minus-S1 accuracy gain comparisons between all three label pairs | `S2-initial-session`; focused rerun: `Rscript --vanilla Study_2_Main_Results/additional/run_gain_contrasts.R` | `Study_2_Main_Results/` | main participant data | `results/H1/H1_S2_minus_S1_Gain_Contrasts.csv` | **Generated and checked 2026-09-10.** Primary participant-intercept model; Kenward–Roger df; one Tukey family of three comparisons. |
| Table S8 | Retention models and contrasts | `S2-followup-MAR`, `S2-followup-completers` | MAR and completer folders | full and completer participant data | MAR `results/MAR/H1/H1_Performance_Comparison_LMM.xlsx`; MAR `results/MAR/H1/H1_Model_Specification_Comparison.xlsx`; completer `results/Follow-Up Activity/H1/H1_Stage1_Longterm_Accuracy_Comparison_LMM.xlsx` | **Generated.** |
| Table S9 | Correction timing, selection, and follow-up accuracy | `S2-correction-timing` | `Study_2_Early_Late_Correction/` | `data/correction_raw_data.xlsx`; `data/manipulation_recall.xlsx` | `Comparison.html` | **HTML only; figure CSVs contain only a subset.** |
| Table S10 | Omnibus attitudes/literacy/self-efficacy models | `S2-initial-session`, `S2-followup-MAR` | main and MAR folders | main/full participant data | main `results/H2/H2_Attitude_Change_Immediate_Results.xlsx`; MAR `results/MAR/H2/H2_Attitude_Change_Longterm_PF.xlsx`; MAR `results/MAR/H2/H2_Attitude_Change_Longterm_PPF.xlsx` | **Generated.** |
| Table S11 | Between-phase descriptive/model contrasts | `S2-initial-session`, `S2-followup-MAR` | main and MAR folders | main/full participant data | main `results/H2/H2_Attitude_Change_Immediate_Results.xlsx`; MAR `results/MAR/H2/H2_Attitude_Change_Longterm_PF.xlsx`; MAR `results/MAR/H2/H2_Attitude_Change_Longterm_PPF.xlsx` | **Generated.** |
| Table S12 | Post-task and follow-up behavior by label | `S2-initial-session`, `S2-followup-completers` | main and completer folders | main/completer participant data | `results/H2/Post_Survey_Experience.xlsx`; completer `results/Follow-Up Activity/H2/Continued_Use_Application.xlsx` | **Generated.** |
| Table S13 | Completer-only AI measures | `S2-followup-completers` | `Study_2_FollowUp_Results/Follow-Up Completers Only/` | `data/Study_2_Followup_Data.xlsx` | `results/Follow-Up Activity/H2/H2_Attitude_Change_Longterm_PF.xlsx`; `results/Follow-Up Activity/H2/H2_Attitude_Change_Longterm_PPF.xlsx` | **Generated.** |
| Table S14 | Evaluated models, access tier, and mode | none | n/a | manuscript metadata | no analysis output | **Manual metadata.** Access-tier provenance is not generated. |
| Table S15 | Guidance-quality rubric | none | `Materials/` | `Study_1_Subjective_Evaluation.docx` | same document | **Manual/materials.** |
| Text S4 / Table S16 | Completer-only within-task outcomes | `S2-followup-completers` | `Study_2_FollowUp_Results/Follow-Up Completers Only/` | completer participant/item data | `Study-2-Follow-Up-Only-Results.html`; `results/Follow-Up Activity/H1/H1_Stage1_Longterm_Accuracy_Comparison_LMM.xlsx`; `results/Follow-Up Activity/H2/H2_Longterm_Confidence_Change.xlsx` | **Generated.** Table S16 summarizes the omnibus models. Text S4 reports the signed `AI − AI + Human` S2 contrast as Δ = −12.31 percentage points, *t*(161) = −2.74, *P* = .019; the HTML supplies the corresponding raw contrast (−0.12312, −2.737, .0188). |
| Table S17 | Completer-only performance by task | `S2-followup-completers` | `Study_2_FollowUp_Results/Follow-Up Completers Only/` | completer participant data | `Study-2-Follow-Up-Only-Results.html` | **HTML only.** |
| Table S18 | Measure sources, scales, and phases, including 14-month auxiliary questions | none (instrument documentation); `S2-longterm` for deposited coding checks | `Materials/`, `Study_2_LongTerm_Results/` | `Full_Survey_English_Version.docx`; long-term eligibility question/recorded coding in `analysis_contract.yaml` and `DATA_DICTIONARY.md` | Same documentary sources; generated long-term auxiliary counts | **Materials and recorded schema.** These records do not establish complete historical platform administration. |
| Table S19 | Dimension-level guidance-quality descriptives | `S1-quality-descriptives` | `Study_1_Subjective_Results/` | `data/Study_1_Subjective_Data.xlsx` | `Study-1-Subjective-Decriptive-Results.html` | **HTML only.** |
| Table S20 | Initial and follow-up performance by task | `S2-initial-session`, `S2-followup-MAR` | main and MAR folders | main/full participant data | main `results/H1/H1_Performance_Comparison_LMM_Task.xlsx`; MAR `results/MAR/H1/H1_Performance_Comparison_LMM_Task.xlsx` | **Generated.** |
| Table S21 | BH-surviving label-dependent moderation effects | `S2-main-multiplicity`, `S2-focal-moderation` | `Study_2_Main_Results/` | main participant data; `results/H3/H3_Attitude_Change_Moderation_Padjust.xlsx`; `results/H3/H3_Within_Task_Moderation_Padjust.xlsx` | the two `*_Padjust.xlsx` inputs just listed; `results/H3/H3_Label_Dependent_Moderation.xlsx`; `results/H3/H3_Label_Dependent_Moderation_Omnibus.csv`; `results/H3/H3_Label_Dependent_Moderation_Change_Slopes.csv`; `results/H3/H3_Label_Dependent_Moderation_Label_Contrasts.csv`; `results/H3/H3_Label_Dependent_Moderation_Sensitivity.csv`; `results/H3/H3_Label_Dependent_Moderation_Session_Info.txt` | **Generated.** |
| Text S5 | Exploratory 14-month sample, eligibility, paired changes, label models, MAR continuations, confidence, correction timing, and diagnostics | `S2-longterm` | `Study_2_LongTerm_Results/` | `data/cohort.csv`, `data/items.csv`, `data/intervals.csv`, manifest, contract, historical aggregate controls | `results/*.csv`; `tables/Supplementary_Tables_S22-S24_no_tools.md`; QC and model-verification records | **Generated at the deposited-data boundary.** Statistical logic is retained from the executed exploratory analysis; excluded participants' long-term outcomes are suppressed. |
| Table S22, Panels A–B | 44→5→39; primary 33; source-label allocations; cohort 170/168; overlapping follow-up samples | `S2-longterm` | `Study_2_LongTerm_Results/` | `data/cohort.csv` | `results/sample_flow.csv`, `fullcohort_diagnostics.csv`; supplementary table export | **Generated.** Original 175/84 results remain separately preserved. |
| Table S22, Panel C | Selection profiles for primary 33, additional 6, one-month-only 46, neither-follow-up 85; five-wave accuracy | `S2-longterm` | `Study_2_LongTerm_Results/` | `data/cohort.csv` | `results/selection_descriptives.csv`; supplementary table export | **Generated.** Additional six are descriptive overall only. |
| Table S22, Panel D | Source recall, prior similar-item exposure, item-order condition, 33/39 elapsed-day summaries | `S2-longterm` | `Study_2_LongTerm_Results/` | `data/cohort.csv`, `data/intervals.csv` | `results/auxiliary_counts.csv`; supplementary table export | **Generated.** Auxiliary responses of excluded returners are not deposited. |
| Table S22, Panel E | Finite-cohort change bounds and tipping values | `S2-longterm` | `Study_2_LongTerm_Results/` | `data/cohort.csv`, 170-person continuation | `results/attrition_bounds.csv`, `attrition_tipping.csv`; supplementary table export | **Generated.** Identification bounds are distinct from the model-based MAR estimates. |
| Table S23, Panels A–C | Equal-task paired accuracy in primary 33 and eligible 39; no-prior-exposure 23/29 and 17-item-weighted 33/39 sensitivities | `S2-longterm` | `Study_2_LongTerm_Results/` | `data/cohort.csv`; contracted family order and seed 20260930 | `results/paired_contrasts.csv`; supplementary table export | **Generated.** Pointwise t intervals and 5,000 participant-resample bootstrap intervals; Holm-3 per family. No between-family adjustment or independent 33-vs-39 comparison. |
| Table S23, Panel D | Label-balanced temporal estimates in primary 33/eligible 39 and full-cohort GLS/mixed-model continuations | `S2-longterm` | `Study_2_LongTerm_Results/` | `data/cohort.csv`; model contract | `results/label_balanced_temporal.csv`, `fullcohort_gls_contrasts.csv`, `fullcohort_lmer_contrasts.csv`, `comparison_33_39_170.csv`; supplementary table export | **Generated with diagnostic qualifications.** Unadjusted cohort-170 accuracy GLS uses residual df=599 because `apVar` is unavailable. |
| Table S23, Panel E | Pillai profile omnibus and long-term level/gain label contrasts | `S2-longterm` | `Study_2_LongTerm_Results/` | `data/cohort.csv` | `results/mlm33_omnibus.csv`, `label_contrasts.csv`, `fullcohort_gls_lt_labels.csv`; supplementary table export | **Generated.** Single unadjusted Pillai test; Tukey-3 label-pair families. Imprecise/nonsignificant comparisons are not equivalence evidence. |
| Table S24, Panel A | Equal-task paired confidence for primary 33/eligible 39 and no-prior-exposure 23/29 | `S2-longterm` | `Study_2_LongTerm_Results/` | `data/cohort.csv` | `results/paired_contrasts.csv`; supplementary table export | **Generated; secondary exploratory outcome.** Recorded scale units and Holm-3 families. |
| Table S24, Panel B | Long-term early/late correction-timing association: 32/204 primary participants/responses; 37/241 eligible sensitivity | `S2-longterm` | `Study_2_LongTerm_Results/` | `data/items.csv`; original 175-person Stage-1 item difficulty retained as a historical nuisance predictor | `results/correction_timing.csv`, `correction_cells.csv`, `correction_positive_control.csv`; supplementary table export | **Generated.** Contracted logistic mixed model; profile intervals and unadjusted Wald tests. Earlier positive controls are aggregate checks, not independent replications. |
| Table S24, Panel C | Covariance/model diagnostics and fit qualifications | `S2-longterm` | `Study_2_LongTerm_Results/` | Contracted 33/39/170/168 model data | `results/gls_diagnostics.csv`, `gls_crosscheck.csv`, `fullcohort_diagnostics.csv`, `fullcohort_lmer_variance_components.csv`, `df_seed_sensitivity.csv`; supplementary table export | **Generated; overall QUALIFIED.** Cohort GLS unavailable `apVar`/df599 and adjusted task-confidence singular `ID:Task` variance zero remain diagnostic failures. Main confidence inference does not use the singular fit. |
| Table S24, Panel D | Eligible-39 recorded item-order association, adjusted for source label and baseline | `S2-longterm` | `Study_2_LongTerm_Results/` | `data/cohort.csv` | `results/item_order_association.csv`; supplementary table export | **Generated; ancillary association.** HC3 covariance; single unadjusted randomized-minus-fixed estimate. |

## Known boundaries

These boundaries must not be mistaken for computational mismatches:

1. Main Figs. 1 and 2 are deposited as final static figures rather than
   regenerated by R.
2. The 220 randomized records and the 31 incomplete/11 attention-check
   exclusions are not available; the analysis-ready precursor begins at 178.
3. Tables S2, S9, S17, and S19 are reproduced in rendered HTML rather than as
   separate table-shaped files.
4. The long-term inputs do not reconstruct private identity/email linkage,
   two unmatched submissions, complete platform delivery, or invitation,
   consent, and ethics records. Exact downstream numerical reproduction does
   not establish full study-execution validation.
5. Eligible public intervals are rounded to 0.1 day. All reported one-decimal
   summaries are preserved; eight four-decimal auxiliary values can differ
   from the private-input run. Duration is not an inferential-model input.
6. The original 44-person interval summary is deposited as retained aggregate
   source metadata in `historical_controls/all44_interval_summary.csv`;
   eligible-only public intervals reproduce the 33/39 summaries.
7. Current Fig. 5/6 PDFs require macOS Quartz/Helvetica for the approved artwork.
8. The authoring Main/SI files are outside the repository. Stable links to the
   article and published SI should be added after publication; the DOCX files
   themselves do not need to be deposited.

## Historical verification and authoring records

The following dated entries preserve the scope and status recorded at the
time. Statements about uncommitted files, private figure dependencies, or
pending release work refer to those historical working copies. The current
release uses the public long-term module and the current map above. These
records are not claims that a new complete workflow has run.

### Scoped addition verified 2026-09-10: S1-to-S2 gain comparisons

The canonical initial-session notebook now generates Table S7 Panel F in chunk
`post-hoc-s1-s2-gain-comparisons`. The focused runner executes the notebook's
original preprocessing and primary model plus that chunk, without caches or
unrelated analyses. It uses the active R library; `--vanilla` bypasses the
currently incomplete local renv activation and is not a pinned-environment
reproduction. This run used R 4.5.1, lme4 1.1-38, lmerTest 3.2-0,
emmeans 2.0.1, and pbkrtest 0.5.5. No packages were installed.

The new CSV has three rows. `contrast` identifies the difference between two
S2-minus-S1 gains; `estimate_pp`, `SE_pp`, `lower_CL_pp`, and `upper_CL_pp` are
in percentage points; `df` and `t_ratio` describe the two-sided contrast test;
`p_tukey` and the 95% confidence limits use one family of all three comparisons.
The contrasts are post hoc additions, not preregistered tests. No input schema,
exclusion, primary model, or existing result file was changed.

The generated values were checked independently using the fixed-effect model
matrix and covariance matrix, including the studentized-range adjustment.
Original stage-specific between-label contrasts reproduced the existing H1
workbook within 1e-7. Main's accuracy-gain reporting and Methods, SI Texts S1–S2,
and Table S7 Panel F were reconciled at this scope. This does not refresh the
full 2026-09-01 manuscript audit recorded above. The full pipeline and unrelated
sensitivity analyses were not rerun.

### Working-copy maintenance (2026-09-30)

Figure 2 was synchronized with the PI-finalized export; the original study models, exclusions and data are unchanged. `SHA256SUMS` was refreshed for the current working files, including the existing September 10 gain-comparison script and CSV. This is an interim integrity inventory, not a final release or a full reproduction check. The September 10 additions remain uncommitted; final manuscript reconciliation, a full pinned-environment run and release reconciliation remain pending.

### Figure 5 authoring revision 2026-09-30

`Figure-5` now renders the approved five-assessment available-sample trajectory (175/84/33), a three-stage comparison of all 175, one-month 84 and eligible both-follow-up 33, and the unchanged one-month correction-timing results. Source: `Figures/Figure_Study2_1.Rmd`; outputs: `Figure_Study2_1.html` and `Figures/figure/Figure_Study2_1.{pdf,png,svg}`. The private long-term cohort and no-tools READY binding are verified before rendering; consumed workbook/helper/correction CSVs are pinned to the frozen analysis contract. New `Figures/data/fig5_primary33_three_stage.csv` records the three-stage Cousineau–Morey summaries. The original five-wave and historical aggregates are reproduced unchanged. Current figure and red caption were inserted in Main.docx with EndNote fields preserved. This scoped figure regeneration is distinct from a full pipeline run; long-term private inputs remain external to the deposited checkout.


### Figure 6 authoring revision 2026-09-30

`Figure-6` now renders connected five-assessment available-sample confidence means (175/84/33) and a Stages 1–3 comparison of the 175/84/33 samples. Source: `Figures/Figure_Study2_2.Rmd`; outputs: its HTML and `Figures/figure/Figure_Study2_2.{pdf,png,svg}`. Confidence values and between-participant t intervals are unchanged. Panels B/C and displayed P values are preserved. Private cohort eligibility is verified through the existing no-tools READY binding; consumed workbooks and the frozen aggregate P-value record are hash-verified. New aggregates `fig6_available_label_summaries.csv`, `fig6_primary33_three_stage.csv` and `fig6_three_stage_sample_comparison.csv` document the displayed comparisons. No inferential model or full pipeline was rerun, and manuscripts/captions were not edited. This source depends on retained verified private inputs and is outside standalone deposited-data reproduction.


Figure 6 follow-up styling (2026-09-30): Initial-session connections in Panel A left are solid; both follow-up connections are dashed. The gray vertical divider and “1-month delay” text are removed; “Follow-up” is centered above the Stage 3 to one-month segment. Markers, error bars, all plotted values and the other panels are unchanged.


Figure 6 legend spacing (2026-09-30): Vertical spacing was slightly increased in both Panel A legends, and “Follow-up” was lowered toward the first dashed segment. Helvetica is retained; the final PDF embeds Helvetica regular, bold and oblique font files. All plotted aggregates, markers and error bars are unchanged; Panels B/C remain pixel-identical. Manuscripts and captions were not edited.


Figure 5 styling matched to Figure 6 (2026-09-30): Both legends now use the modest final Figure 6 row spacing. Stage 1 to Stage 3 connections remain solid; Stage 3 to one month to 14 months connections are dashed. The gray vertical divider and “1-month delay” text were removed, with “Follow-up” positioned above the first dashed segment clear of the steeper accuracy curves. The attrition subtitle is retained. Helvetica is embedded in the checked PDF. All plotted values, intervals and tests are unchanged; Panel B is pixel-identical. Source, HTML and PDF/PNG/SVG exports were regenerated. No model fits or manuscript/caption edits were made.


Figure 5 sample markers and legend order (2026-09-30): The sample-comparison legend and plotted markers now encode both follow-ups as black triangles, one-month completers as gray triangles, and all participants as open circles, in that top-to-bottom legend order. The legend was slightly lowered away from the subtitle. Existing sample-specific line styles and all values, intervals and tests are preserved. Panel A left and Panel B are pixel-identical. Source/HTML and PDF/PNG/SVG were refreshed; manuscripts and captions were not edited.


Figures 5–6 PDF typography repair (2026-09-30): A controlled Helvetica export test showed Cairo glyph advances rounded to coarse point increments, while native macOS Quartz retained fractional advances. Both current Rmd sources now export PDFs through Quartz; Helvetica regular, bold and oblique are embedded, with Symbol used only for mathematical glyphs/spacing. PNG/SVG use their existing devices. Figure 6 PNG/SVG are byte-identical to the preceding exports. Figure 5 also has its sample legend lowered further, with a minimal left adjustment to clear the Stage 3 markers. All aggregate records and tests are unchanged; manuscripts/captions were not edited. The final PDFs were rendered and visually checked; the current PDF-export function requires macOS Quartz. Previous source/artwork and the controlled-device tests are retained in task scratch.


Figure 6 sample legend synchronized with Figure 5 (2026-09-30): Both follow-ups use black triangles, one-month completers use gray triangles, and all participants use open circles, in that top-to-bottom order. Marker mappings and existing line styles match Figure 5. The same row spacing and measured subtitle-to-legend gap are used; Figure 6 has a layout-specific position anchor. Open circles are drawn last so they remain visible where sample means overlap. All plotted values, intervals and tests are unchanged; Panel A left and Panels B/C are pixel-identical in PNG. Source/HTML and PDF/PNG/SVG were regenerated and visually checked. Figure 5, manuscripts and captions were preserved.
