# Study 1 — Subjective Instructional-Quality Ratings

Blinded human ratings of LLM-generated statistics explanations. Two independent
notebooks — a descriptive comparison and a mixed-effects model analysis — share
the single input dataset below.

## Data (`data/`)

`Study_1_Subjective_Data.xlsx` — human ratings of LLM outputs (288 ratings × 10 columns).

**Raw columns**

| Variable | Description |
|----------|-------------|
| `ID` | Rater identifier |
| `Model` | Model rated (e.g., `ChatGPT_4o`, `ChatGPT_o1`, `Grok3`, `Gemini_2.0`) |
| `Task` | Statistics task rated |
| `Profession` | Rater role (`Student` / `Instructor`) |
| `Iteration` | Repeated-generation index (1–3) per Model × Task |
| `Statistical_Accuracy`, `Clarity_and_Structure`, `Conceptual_Depth`, `Pedagogical_Effectiveness` | The four rating dimensions |

**Derived in the notebooks**

| Variable | Description |
|----------|-------------|
| `RaterGroup` | Alias of `Profession` |
| `Rater` | Compound rater ID (`RaterGroup_ID`) |
| `OverallQuality` | Mean of the four dimensions — the modeled outcome |
| `ModelGroup` | `Top` / `Bottom` from the objective ranking (`Other` excluded from the comparison) |
| `Explanation` | `Model × Task × Iteration` — the unit scored in common by all 8 raters (primary random effect) |
| `Attempt` | Bare `Iteration` index; supplementary model only |

## Notebooks

Independent (no shared objects); each loads the dataset and sets this folder as
its working directory.

| File | Description |
|------|-------------|
| `Study 1 Subjective Decriptive Results.Rmd` | Top vs. Bottom overall mean/SD; per-model, per-task means by rater group; full Dimension × Model × Task × Profession breakdown |
| `Study 1 Subjective Model Results.Rmd` | Mixed-effects models of `OverallQuality` with Type-III ANOVA, effect sizes, `emmeans` contrasts (`ModelGroup`, `ModelGroup × RaterGroup`), and diagnostics; supplementary refit on `(1 | Attempt)` |
| `select_study2_materials.R` | Recomputes the task-specific material selection among the two top models, using instructor means first and student means to break an instructor tie; joins each selected model's mean objective task accuracy from the sibling objective benchmark; exports all six reported columns underlying SI Table S3 plus the student tie-break value |

```
Primary:        OverallQuality ~ ModelGroup * RaterGroup * Task + (1 | Rater) + (1 | Explanation)
Supplementary:  OverallQuality ~ ModelGroup * RaterGroup * Task + (1 | Rater) + (1 | Attempt)
```

`Explanation` (`Model × Task × Iteration`) is the unit all 8 raters score in
common; the supplementary `Attempt` variance is estimated at 0, raising the
denominator df for between-explanation effects.

The two R Markdown notebooks print their results to rendered HTML; they do not
write workbooks.

The selection script reads both the local subjective-rating workbook and
`../Study_1_Objective_Results/data/Study_1_Objective_Data.xlsx`, then writes two
machine-readable files under `results/`:
`Study_2_Material_Selection_Candidates.csv` and
`Study_2_Selected_Materials.csv`.

Packages (pinned in the top-level `renv.lock`): the descriptive notebook uses
`readxl`, `dplyr`, `tidyr`, `stringr`; the model notebook adds `lme4`,
`lmerTest`, `car`, `effectsize`, `emmeans`, `performance`, `report`, `ggplot2`,
and `cleanrmd` (optional themed HTML).
