#!/usr/bin/env Rscript

# Reproduce the Study 2 material-selection calculation reported in Main Fig. 1
# and SI Table S3. Run with Study_1_Subjective_Results/ as the working directory.

suppressPackageStartupMessages({
  library(dplyr)
  library(readxl)
  library(tidyr)
})

dimensions <- c(
  "Statistical_Accuracy",
  "Clarity_and_Structure",
  "Conceptual_Depth",
  "Pedagogical_Effectiveness"
)

objective_raw <- read_excel(
  "../Study_1_Objective_Results/data/Study_1_Objective_Data.xlsx"
)

objective_ranking <- objective_raw %>%
  mutate(
    task_items = dplyr::recode(question, Q1 = 6, Q2 = 5, Q3 = 6)
  ) %>%
  group_by(software, model, Thinking_Model) %>%
  summarise(
    Overall_Accuracy = weighted.mean(
      as.numeric(accuracy_rate), w = task_items, na.rm = TRUE
    ),
    .groups = "drop"
  ) %>%
  arrange(desc(Overall_Accuracy), software, model) %>%
  mutate(Objective_Rank = row_number())

top_models <- objective_ranking %>%
  slice_head(n = 2L) %>%
  mutate(
    Subjective_Model = case_when(
      software == "chatgpt" & model == "gpt-4o" ~ "ChatGPT_4o",
      software == "chatgpt" & model == "o1" ~ "ChatGPT_o1",
      TRUE ~ NA_character_
    ),
    Model = case_when(
      software == "chatgpt" & model == "gpt-4o" ~ "GPT-4o",
      software == "chatgpt" & model == "o1" ~ "OpenAI o1",
      TRUE ~ NA_character_
    )
  )

if (anyNA(top_models$Subjective_Model)) {
  stop("A top-two objective model has no mapping to the subjective-rating data.")
}

objective_accuracy <- objective_raw %>%
  inner_join(
    top_models %>%
      select(software, model, Thinking_Model, Model, Objective_Rank),
    by = c("software", "model", "Thinking_Model"),
    suffix = c("_Raw", "")
  ) %>%
  mutate(
    Task = dplyr::recode(
      question,
      Q1 = "P-value",
      Q2 = "95% confidence interval",
      Q3 = "Study comparison"
    )
  ) %>%
  group_by(Task, Model, Objective_Rank) %>%
  summarise(
    Model_Task_Accuracy = mean(as.numeric(accuracy_rate)),
    .groups = "drop"
  )

ratings <- read_excel("data/Study_1_Subjective_Data.xlsx") %>%
  mutate(
    OverallQuality = rowMeans(across(all_of(dimensions)), na.rm = TRUE)
  ) %>%
  filter(Model %in% top_models$Subjective_Model) %>%
  group_by(Task, Model, Iteration, Profession) %>%
  summarise(Mean = mean(OverallQuality), .groups = "drop") %>%
  pivot_wider(names_from = Profession, values_from = Mean) %>%
  mutate(
    Task = dplyr::recode(
      Task,
      Q1 = "P-value",
      Q2 = "95% confidence interval",
      Q3 = "Study comparison"
    ),
    Model = dplyr::recode(
      Model,
      ChatGPT_4o = "GPT-4o",
      ChatGPT_o1 = "OpenAI o1"
    )
  ) %>%
  left_join(objective_accuracy, by = c("Task", "Model")) %>%
  arrange(factor(Task, levels = c(
    "P-value", "95% confidence interval", "Study comparison"
  )), Model, Iteration)

if (anyNA(ratings$Model_Task_Accuracy)) {
  stop("The objective benchmark did not supply task accuracy for every candidate.")
}

selected <- ratings %>%
  group_by(Task) %>%
  mutate(
    Highest_Instructor_Mean = max(Instructor),
    Instructor_Tie = abs(Instructor - Highest_Instructor_Mean) < 1e-12,
    Number_Tied = sum(Instructor_Tie)
  ) %>%
  filter(Instructor_Tie) %>%
  arrange(desc(Student), Model, Iteration, .by_group = TRUE) %>%
  slice_head(n = 1L) %>%
  mutate(
    Selection_Basis = if_else(
      Number_Tied > 1L,
      "Tied highest instructor mean; higher student mean",
      "Highest instructor mean"
    )
  ) %>%
  ungroup() %>%
  select(
    Task, Model, Iteration, Model_Task_Accuracy, Objective_Rank,
    Instructor, Student, Selection_Basis
  )

dir.create("results", showWarnings = FALSE)
write.csv(
  ratings,
  "results/Study_2_Material_Selection_Candidates.csv",
  row.names = FALSE,
  na = "",
  quote = FALSE
)
write.csv(
  selected,
  "results/Study_2_Selected_Materials.csv",
  row.names = FALSE,
  na = "",
  quote = FALSE
)

print(selected)
