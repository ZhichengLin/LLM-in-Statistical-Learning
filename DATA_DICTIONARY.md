# Data dictionary and deposited-data lineage

This dictionary describes every deposited analysis input used by the notebooks
and figures. It records the physical file dimensions, analytic exclusions,
missing-value conventions, variable meanings, derived fields, and duplicate
lineages. The current analysis inputs begin after the Study 2 completion and
attention screens; they cannot reconstruct the earlier flow from 220 randomized
participants to 178 deposited records.

All participant and rater identifiers are pseudonymous. Missing values are
stored as blank cells; there are no textual `NA` values or sentinel codes. No
deposited workbook contains formulas.

## Input inventory

Dimensions exclude wholly blank formatted rows and columns. Every workbook has
one worksheet.

| Input | Sheet / rows × columns | Unit and key | Role and lineage |
|---|---:|---|---|
| `Study_1_Objective_Results/data/Study_1_Objective_Data.xlsx` | `Sheet1`, 450 × 21 | model × task × iteration; `software + model + question + iteration` | Canonical Study 1 benchmark input |
| `Figures/data/Study_1_Objective_Data.xlsx` | `Sheet1`, 450 × 21 | same | Byte-identical figure copy |
| `Study_1_Subjective_Results/data/Study_1_Subjective_Data.xlsx` | `sheet1`, 288 × 10 | rater × explanation; `ID + Task + Number` | Canonical Study 1 rating input |
| `Figures/data/Study_1_Subjective_Data.xlsx` | `sheet1`, 288 × 10 | same | Cell-value-identical figure copy; workbook bytes/styles differ |
| `Study_2_Main_Results/data/Study_2_Main_Results_Data.xlsx` | `Sheet1`, 178 × 67 | participant; `ID` | Initial-session input; 175 rows after the ceiling screen |
| `Study_2_FollowUp_Results/MAR/data/Study_2_Full_Data.xlsx` | `Sheet1`, 178 × 88 | participant; `ID` | Main file plus attrition and follow-up fields; common columns/values match the main input |
| `Study_2_FollowUp_Results/MAR/data/Followup_Interval_Days.xlsx` | `intervals`, 178 × 4 | participant; `ID` | Pseudonymous ID, assigned label, follow-up-pairing flag, and interval in days; 87 observed intervals and no submission timestamps |
| `Study_2_FollowUp_Results/Follow-Up Completers Only/data/Study_2_Followup_Data.xlsx` | `Sheet1`, 87 × 88 | follow-up respondent; `ID` | Exact `drop = 0` row subset of the full data; 84 rows after the ceiling screen |
| `Study_2_Main_Results/data/correction_raw_data.xlsx` | `Sheet1`, 178 × 71 | participant with item responses; `ID` | Canonical item-response input |
| `Study_2_FollowUp_Results/MAR/data/correction_raw_data.xlsx` | `Sheet1`, 178 × 71 | same | Byte-identical copy |
| `Study_2_FollowUp_Results/Follow-Up Completers Only/data/correction_raw_data.xlsx` | `Sheet1`, 178 × 71 | same | Byte-identical copy |
| `Study_2_Early_Late_Correction/data/correction_raw_data.xlsx` | `Sheet1`, 178 × 71 | same | Cell-value-identical copy; workbook bytes/styles differ |
| `Study_2_Early_Late_Correction/data/manipulation_recall.xlsx` | `Sheet1`, 178 × 2 | participant; `ID` | Exact `ID + Recalled_Label` projection of the main data |
| `Figures/data/Correction_Data.csv` | 145 × 5 | participant × correction-timing group; `ID + Group` | Derived by `Comparison.Rmd`; 565 item observations from 82 participants are aggregated to these 145 rows |
| `Figures/data/Correction_Timing_Contrasts.csv` | 3 × 10 | one Early/Late contrast per assigned label | Derived model output used for Figure 5 annotations |

The self-contained folder design intentionally duplicates several inputs. The
release audit verified equality at the level stated above: byte-identical where
possible and cell-value-identical otherwise. The Study 2 figures now read the
canonical full-sample workbook directly rather than relying on a reduced
plotting copy.

## Study 1 objective benchmark

| Field | Definition |
|---|---|
| `software` | Platform: `chatgpt`, `deepseek`, `tongyi`, `gemini`, `claude`, or `Grok` |
| `model` | Model/version label within platform |
| `question` | `Q1` P-value interpretation; `Q2` confidence-interval interpretation; `Q3` cross-study comparison |
| `iteration` | Repeated model run, 1–10 |
| `1`–`6` | Stored Boolean answers |
| `score1`–`score6` | Stored 0/1 correctness codes |
| `sum_score` | Correct-answer count for the task |
| `accuracy_rate` | Task accuracy: Q1 `sum_score / 6`, Q2 `sum_score / 5`, Q3 `sum_score / 6` |
| `Thinking_Model` | 1 = thinking/reasoning mode; 0 = standard mode |
| `Advance` | Undocumented, non-authoritative indicator. The SI states that the advanced/simple contrast was not sufficiently specified and was not performed. |
| `software_label` | Unused numeric platform code: DeepSeek 1, Alibaba 2, Anthropic 3, Google 4, OpenAI 5, xAI 6 |

Q2 retains six stored response/score columns, but its contested fifth item is
excluded from final accuracy. The deposited `accuracy_rate` already uses the
correct five-item denominator; the descriptive notebook applies the same rule
if it must reconstruct the field.

## Study 1 explanation ratings

| Field | Definition / observed values |
|---|---|
| `ID` | Pseudonymous rater ID; eight raters, each rating all 36 explanations |
| `Profession` | `Student` 144 rows; `Instructor` 144 rows |
| `Task` | `Q1`, `Q2`, `Q3`; 96 rows each |
| `Number` | Randomized stimulus code 1–12 within task; mapped to `Model + Iteration` in `Materials/README.md` |
| `Model` | `ChatGPT_4o`, `ChatGPT_o1`, `Grok3`, `Gemini_2.0`; 72 rows each |
| `Iteration` | Explanation generation 1–3; this is not a repeated rating |
| `Statistical_Accuracy` | 1–7 rating; observed 1–7 |
| `Clarity_and_Structure` | 1–7 rating; observed 2–7 |
| `Conceptual_Depth` | 1–7 rating; observed 2–7 |
| `Pedagogical_Effectiveness` | 1–7 rating; observed 2–7 |

`OverallQuality` is the downstream row mean of the four ratings (observed
2.000–7.000). `ModelGroup`, `Rater`, and `Explanation` are also derived in code.
All 288 rows belong to the two selected top and two selected bottom models; the
documented `Other` exclusion removes no deposited row.

## Study 2 cohort and exclusions

The deposited participant-level inputs contain 178 rows. Assigned allocation
is AI 59, AI Human 59, and Human 60. Every primary Study 2 workflow applies
`stage1_task0_accuracy < 0.9`, removing one AI Human and two Human participants
and producing the analytic 59/58/58 allocation (*N* = 175).

The follow-up respondent file contains 87 rows before that same screen and 84
after it. The MAR workflow keeps all 175 initial-session participants, with 84
observed and 91 missing follow-up records. Manipulation-passer sensitivity
analyses retain 153 of 175 participants by comparing assigned and recalled
labels.

`Attention_Check` equals 1 for every deposited participant. It therefore does
not reconstruct the earlier five-check screening rule or the excluded cases.

The interval input contains one row for every deposited Study 2 participant.
`paired = TRUE` identifies the 87 follow-up respondents and coincides exactly
with a nonmissing `interval_days` value; the other 91 values are blank. The MAR
notebook regenerates
`Study_2_FollowUp_Results/MAR/results/MAR/Baseline/Followup_Interval_Descriptives.xlsx`
for all 87 respondents and the 84 non-ceiling analytic completers.

## Study 2 participant fields

| Field | Definition / exact deposited levels |
|---|---|
| `ID` | Pseudonymous participant linkage key; unique within each participant-level file |
| `Label` | Randomized assigned description: `AI` 59, `AI Human` 59, `Human` 60 |
| `Recalled_Label` | Recalled description: `AI` 51, `AI + Human` 80, `Human` 47. The hybrid spelling differs from `Label` and is explicitly recoded in code. |
| `Attention_Check` | Constant 1 for all 178 deposited rows |
| `Gender` | `Female` 113; `Male` 63; `Prefer not to say` 2 |
| `Age` | `≤ 20` 19; `21–30` 152; `31–40` 6; `41–50` 1 |
| `Identity` | `Undergraduate` 128; `Master or PHD` 34; `Industry professional` 10; `Post-doc or Faculty` 4; `Others` 2 |
| `Field` | `Computer Science or Engineering` 73; `Social Sciences` 65; `Health and Medical` 18; `Arts and Humanities` 12; `Natural Sciences` 7; `Other` 3 |
| `Stats_Background` | Ordered 2–7; counts 5, 69, 81, 16, 5, 2 respectively |
| `Used_LLM` | 0 no: 2; 1 yes: 176 |
| `Used_LLM_Frequency` | `Less than once a month` 1; `1–3 times per month` 32; `Weekly` 94; `Daily` 49; blank 2 |
| `Used_LLM_Hours` | `1–5` 45; `6–10` 36; `11–20` 37; `>20` 58; blank 2 |
| `Sign_Up` | 0 no: 19; 1 yes: 159 |
| `drop` | 0 follow-up completed: 87; 1 not completed: 91 |

The two blank `Used_LLM_Frequency`/`Used_LLM_Hours` rows both have
`Used_LLM = 0`; these are structural missing values.

## Study 2 composite measures

These fields are analysis-ready composite scores. The deposited package does
not contain code that reconstructs them from raw survey exports.

| Field | Observed range / observed N |
|---|---:|
| `Pre_GLAT_Objective_AI_Literacy` | 0.200–1.000 / 178 |
| `Pre_AILS_CCS_Subjective_AI_Literacy` | 2.200–4.667 / 178 |
| `Pre_AI_Trust` | 1.500–4.750 / 178 |
| `Pre_AI_Usefulness` | 2.200–5.000 / 178 |
| `Pre_AI_Affect` | 2.500–5.000 / 178 |
| `Pre_AI_Self_Efficacy` | 1.667–3.833 / 178 |
| `Pre_Behavioral_Intention` | 2.667–5.000 / 178 |
| `Post_AI_Trust` | 1.250–5.000 / 178 |
| `Post_AI_Usefulness` | 1.200–5.000 / 178 |
| `Post_AI_Affect` | 1.500–5.000 / 178 |
| `Post_Behavioral_Intention` | 1.000–5.000 / 178 |
| `follow_GLAT_Objective_AI_Literacy` | 0.250–1.000 / 87 |
| `follow_AILS_CCS_Subjective_AI_Literacy` | 3.000–4.733 / 87 |
| `follow_AI_Trust` | 2.000–4.750 / 87 |
| `follow_AI_Usefulness` | 2.200–5.000 / 87 |
| `follow_AI_Affect` | 2.000–5.000 / 87 |
| `follow_AI_Self_Efficacy` | 1.667–3.833 / 87 |
| `follow_Behavioral_Intention` | 2.333–5.000 / 87 |

There are no post-task GLAT, AILS-CCS, or self-efficacy fields in the deposited
files.

## Study 2 learning-task fields

The patterns below account for the repeated stage fields. `task0` is the
aggregate across task 1 (six P-value items), task 2 (five confidence-interval
items), and task 3 (six cross-study comparison items).

| Pattern | Meaning | Scale / deposited coverage |
|---|---|---|
| `stage[1-3]_task[0-3]_accuracy` | Proportion correct by stage and task | 0–1; 178 observed per field |
| `stage[1-3]_task[0-3]_confidence` | Mean confidence by stage and task | 1–5; 178 observed per field |
| `stage[2-3]_task[0-3]_willing` | Willingness to accept guidance/answers | 1–5; 178 observed per field; not measured at Stage 1 |
| `stage[2-3]_task[0-3]_useful` | Perceived usefulness of guidance/answers | 1–5; 178 observed per field; not measured at Stage 1 |
| `follow_task[0-3]_accuracy` | Follow-up accuracy parallel to the stage fields | 0–1; 87 observed and 91 blank per field |
| `follow_task[0-3]_confidence` | Follow-up confidence parallel to the stage fields | 1–5; 87 observed and 91 blank per field |

## Post-task and follow-up-use fields

| Field | Meaning / deposited values |
|---|---|
| `Task_Difficulty` | 1–5 post-task evaluation; counts 3, 8, 118, 44, 5 |
| `Stats_Improvement` | 1–5 perceived improvement; counts 1, 0, 12, 107, 58 |
| `Satisfaction` | 1–5 satisfaction; counts 1, 5, 8, 103, 61 |
| `follow_activity_1`–`follow_activity_4` | Four ordered 1–5 continued-use/application items; 87 observed and 91 blank each |
| `follow_activity_0` | Mean of the four activity items; observed 1.750–5.000 for 87 respondents |

## Item-level correction fields and derivations

| Field | Definition |
|---|---|
| `Label`, `ID`, `overall_accuracy_stage1` | Exact matches to the participant-level data |
| `stage[1-3]_t[1-3]_q[...]` | Boolean responses at Stages 1–3; these are not correctness codes |
| `follow_up_t[1-3]_q[...]` | Boolean follow-up responses; blank for nonrespondents |
| `S1c`, `S2c`, `S3c`, `FUc` | Downstream response scoring against the notebook's truth key |
| `CorrectionTiming = Early` | Wrong at Stage 1 and correct by Stage 2 |
| `CorrectionTiming = Late` | Wrong through Stage 2 and correct at Stage 3 |
| `difficulty_c` | Centered Stage-1 full-sample item accuracy; larger values indicate easier items |

The main correction subset also requires an observed follow-up answer. It
contains 565 item observations from 82 participants: 237 Early and 328 Late.
Aggregation by `ID + Label + CorrectionTiming` produces the 145 rows in
`Correction_Data.csv`; `Measure_Raw` is mean follow-up correctness and
`Measure` is the corresponding percentage.

## Provenance and data scope

- No deposited script regenerates the analysis-ready workbooks from raw survey
  or model-service exports. Their upstream transformation provenance must be
  supplied separately if required for a public release.
- The public inputs cannot reproduce the 220→178 completion/attention-screen
  flow, because all 178 deposited rows have `Attention_Check = 1`.
- Exact initial and follow-up submission timestamps are not deposited.

Participant and rater identifiers are pseudonymous numeric keys retained to
link repeated observations. The deposited package contains no participant
names, email addresses, telephone numbers, postal addresses, IP addresses,
exact submission timestamps, or identity crosswalk.
