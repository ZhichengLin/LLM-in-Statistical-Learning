# Study 1 — Objective LLM Performance

Objective accuracy and response stability of 15 LLMs across models and thinking
modes on the three statistical-reasoning tasks.

## Data (`data/`)

`Study_1_Objective_Data.xlsx` — item-level accuracy for all LLMs.

| Variable | Description |
|----------|-------------|
| `software` | Platform (`chatgpt` / `deepseek` / `tongyi` / `gemini` / `claude` / `Grok`) |
| `model` | Model version (e.g., `gpt-4o`, `DeepSeek-R1`) |
| `Thinking_Model` | Thinking/reasoning mode enabled (`1` = yes, `0` = no) |
| `question` | Question identifier |
| `iteration` | Repeated-run index (for stability) |
| `accuracy_rate` | Proportion correct (0–1); precomputed from 6 scored items in Q1, 5 in Q2 (item 5 is excluded), and 6 in Q3. The notebook applies these task-specific denominators if it must reconstruct this field. |

## Notebooks

| File | Description |
|------|-------------|
| `Study 1 Objective Descriptive Results.Rmd` | Model ranking and task descriptives underlying Main Fig. 3 and SI Table S1; flags the top/bottom models carried into the rating phase |
| `Study 1 Objective Model Results.Rmd` | Mixed-effects models for accuracy and stability (SD) testing thinking mode, question type, and platform |

The model tests for SI Table S1 Panel B print to the rendered HTML. The
descriptive notebook also writes
`results/Study_1_Objective_Table_S01_Panel_A.csv`, containing the complete
per-model/per-task means and SDs plus overall accuracy and run-to-run SD used in
Panel A.

Packages (versions pinned in the top-level `renv.lock`): `readxl`, `dplyr`,
`stringr`, `tidyr`, `lme4`, `lmerTest`, `emmeans`, `effectsize`, `report`.
