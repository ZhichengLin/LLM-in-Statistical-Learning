#!/usr/bin/env Rscript

# Verify the deposited multiplicity-corrected moderation outputs, reproduce the
# four BH-significant Label-dependent interactions from the analysis-ready
# data, and export a compact table plus targeted probes for SI Table S21.

suppressPackageStartupMessages({
  library(dplyr)
  library(effectsize)
  library(emmeans)
  library(forcats)
  library(lme4)
  library(lmerTest)
  library(openxlsx)
  library(readxl)
  library(stringr)
  library(tidyr)
})

set.seed(42)

output_dir <- file.path("results", "H3")
attitude_path <- file.path(output_dir, "H3_Attitude_Change_Moderation_Padjust.xlsx")
within_path <- file.path(output_dir, "H3_Within_Task_Moderation_Padjust.xlsx")

attitude_focal <- read_excel(attitude_path)
within_focal <- read_excel(within_path)

if (nrow(attitude_focal) != 108) {
  stop("Expected 108 corrected attitude-moderation rows; found ", nrow(attitude_focal))
}
if (nrow(within_focal) != 120) {
  stop("Expected 120 corrected within-task moderation rows; found ", nrow(within_focal))
}
if (!all(attitude_focal$n_in_family == 27)) {
  stop("Attitude correction-family size is not 27 for every outcome")
}
if (!all(within_focal$n_in_family == 30)) {
  stop("Within-task correction-family size is not 30 for every outcome")
}

label_dependent <- bind_rows(attitude_focal, within_focal) %>%
  filter(grepl("Label", Term, fixed = TRUE), p_BH < 0.05) %>%
  mutate(
    Outcome = dplyr::recode(
      DV,
      AI_Affect = "AI affect",
      confidence = "Confidence",
      useful = "Perceived usefulness",
      willing = "Willingness"
    ),
    Baseline_moderator = dplyr::recode(
      Moderator,
      GLAT_Objective_AI_Literacy = "Objective AI literacy",
      pre_AILS_CCS_Subjective_AI_Literacy = "Subjective AI literacy",
      pre_AI_Usefulness = "Perceived AI usefulness"
    ),
    Interaction = ifelse(
      grepl("^Phase", Term),
      "Phase x Label x Moderator",
      "Stage x Label x Moderator"
    ),
    Survives_Holm = ifelse(p_holm < 0.05, "Yes", "No")
  ) %>%
  select(
    Outcome, Baseline_moderator, Interaction, NumDF, DenDF, F_value,
    eta_p, p_value, p_BH, p_holm, Survives_Holm, Analysis, DV, Moderator, Term
  ) %>%
  arrange(match(
    Outcome,
    c("AI affect", "Confidence", "Perceived usefulness", "Willingness")
  ))

if (nrow(label_dependent) != 4) {
  stop("Expected four BH-significant Label-dependent interactions; found ", nrow(label_dependent))
}

data_path <- file.path("data", "Study_2_Main_Results_Data.xlsx")
df <- read_excel(data_path) %>%
  mutate(Label = factor(Label, levels = c("AI", "AI Human", "Human"))) %>%
  filter(stage1_task0_accuracy < 0.9) %>%
  mutate(
    Stats_Background = cut(
      as.numeric(as.character(Stats_Background)),
      breaks = c(1, 3, 5, 8),
      labels = c("Low", "Medium", "High"),
      right = TRUE,
      include.lowest = TRUE
    ),
    Used_LLM_Frequency = forcats::fct_collapse(
      as.character(Used_LLM_Frequency),
      Rarely = c("Never", "Less than once a month", "1–3 times per month"),
      Often = c("Weekly", "Daily")
    ),
    Used_LLM_Hours = forcats::fct_collapse(
      as.character(Used_LLM_Hours),
      None = "0",
      Low = c("1–5", "6–10"),
      High = c("11–20", ">20")
    )
  )

cols_to_long <- grep("^(Pre|Post|stage\\d+)_", colnames(df), value = TRUE)
df_long <- df %>%
  pivot_longer(
    cols = all_of(cols_to_long),
    names_to = "fullvar",
    values_to = "Value"
  ) %>%
  mutate(
    Phase = str_extract(fullvar, "^(Pre|Post|stage\\d+)"),
    tmp = str_remove(fullvar, "^(Pre|Post|stage\\d+)_"),
    task = ifelse(str_detect(tmp, "^task\\d+"), str_extract(tmp, "^task\\d+"), NA),
    measure = ifelse(!is.na(task), str_remove(tmp, "^task\\d+_"), tmp),
    Phase = factor(Phase, levels = c("Post", "stage3", "stage2", "stage1", "Pre")),
    Task = factor(task),
    Label = factor(Label),
    ID = factor(ID)
  ) %>%
  select(-tmp, -fullvar, -task)

continuous_measures <- c(
  "GLAT_Objective_AI_Literacy",
  "AILS_CCS_Subjective_AI_Literacy",
  "AI_Trust",
  "AI_Usefulness",
  "AI_Affect",
  "AI_Self_Efficacy",
  "Behavioral_Intention"
)

baseline_mods <- df_long %>%
  filter(as.character(Phase) == "Pre", measure %in% continuous_measures) %>%
  select(ID, measure, Value) %>%
  pivot_wider(names_from = measure, names_prefix = "pre_", values_from = Value)

within_data <- df_long %>%
  filter(measure %in% c("accuracy", "confidence", "willing", "useful")) %>%
  left_join(baseline_mods, by = "ID") %>%
  mutate(Stage = as.factor(Phase)) %>%
  select(-Phase)

for (mod in c("pre_AILS_CCS_Subjective_AI_Literacy", "pre_AI_Usefulness")) {
  within_data[[mod]] <- as.numeric(scale(within_data[[mod]], scale = FALSE))
}

fit_within <- function(outcome, moderator) {
  dat <- within_data %>%
    filter(measure == outcome, Task != "task0", !is.na(.data[[moderator]]))
  full_formula <- as.formula(
    paste0(
      "Value ~ Stage * Label * ", moderator,
      " + (1|ID) + (1|Task) + (1|ID:Task)"
    )
  )
  simple_formula <- as.formula(
    paste0("Value ~ Stage * Label * ", moderator, " + (1|ID) + (1|Task)")
  )
  list(
    full = lmer(full_formula, data = dat),
    simplified = lmer(simple_formula, data = dat)
  )
}

models <- list(
  Confidence = fit_within("confidence", "pre_AILS_CCS_Subjective_AI_Literacy"),
  `Perceived usefulness` = fit_within("useful", "pre_AI_Usefulness"),
  Willingness = fit_within("willing", "pre_AI_Usefulness")
)

affect_data <- df_long %>%
  filter(measure == "AI_Affect", as.character(Phase) %in% c("Pre", "Post")) %>%
  mutate(Phase = factor(as.character(Phase), levels = c("Pre", "Post")))

affect_moderator <- df_long %>%
  filter(
    as.character(Phase) == "Pre",
    measure == "GLAT_Objective_AI_Literacy"
  ) %>%
  select(ID, ModeratorScore = Value)

affect_data <- affect_data %>%
  left_join(affect_moderator, by = "ID") %>%
  mutate(ModeratorScore = as.numeric(scale(ModeratorScore, scale = FALSE)))

affect_model <- lmer(
  Value ~ Phase * Label * ModeratorScore + (1|ID),
  data = affect_data
)

omnibus_from_model <- function(model, term) {
  a <- as.data.frame(anova(model))
  data.frame(
    NumDF = a[term, "NumDF"],
    DenDF = a[term, "DenDF"],
    F_value = a[term, "F value"],
    p_value = a[term, "Pr(>F)"]
  )
}

reproduced <- bind_rows(
  cbind(
    Outcome = "AI affect",
    omnibus_from_model(affect_model, "Phase:Label:ModeratorScore")
  ),
  cbind(
    Outcome = "Confidence",
    omnibus_from_model(
      models$Confidence$full,
      "Stage:Label:pre_AILS_CCS_Subjective_AI_Literacy"
    )
  ),
  cbind(
    Outcome = "Perceived usefulness",
    omnibus_from_model(
      models$`Perceived usefulness`$full,
      "Stage:Label:pre_AI_Usefulness"
    )
  ),
  cbind(
    Outcome = "Willingness",
    omnibus_from_model(
      models$Willingness$full,
      "Stage:Label:pre_AI_Usefulness"
    )
  )
)

comparison <- label_dependent %>%
  select(Outcome, NumDF_deposited = NumDF, DenDF_deposited = DenDF,
         F_deposited = F_value, p_deposited = p_value) %>%
  left_join(reproduced, by = "Outcome") %>%
  mutate(
    F_abs_diff = abs(F_deposited - F_value),
    p_abs_diff = abs(p_deposited - p_value)
  )

if (any(comparison$F_abs_diff > 2e-4) || any(comparison$p_abs_diff > 1e-7)) {
  stop("Freshly refitted omnibus tests do not match the deposited corrected output")
}

add_probe <- function(model, outcome, moderator, time_var, var_name, methods) {
  trends <- emtrends(
    model,
    specs = as.formula(paste0("~", time_var, " * Label")),
    var = var_name
  )
  changes <- contrast(trends, method = methods, by = "Label", adjust = "none")
  list(
    slopes = as.data.frame(changes) %>%
      mutate(Outcome = outcome, Baseline_moderator = moderator, .before = 1),
    contrasts = as.data.frame(pairs(changes, by = "contrast", adjust = "tukey")) %>%
      mutate(Outcome = outcome, Baseline_moderator = moderator, .before = 1)
  )
}

probes <- list(
  add_probe(
    affect_model,
    "AI affect", "Objective AI literacy", "Phase", "ModeratorScore",
    list("Post-Pre" = c(-1, 1))
  ),
  add_probe(
    models$Confidence$full,
    "Confidence", "Subjective AI literacy", "Stage",
    "pre_AILS_CCS_Subjective_AI_Literacy",
    list("S2-S1" = c(0, 1, -1), "S3-S2" = c(1, -1, 0))
  ),
  add_probe(
    models$`Perceived usefulness`$full,
    "Perceived usefulness", "Perceived AI usefulness", "Stage",
    "pre_AI_Usefulness", list("S3-S2" = c(1, -1))
  ),
  add_probe(
    models$Willingness$full,
    "Willingness", "Perceived AI usefulness", "Stage",
    "pre_AI_Usefulness", list("S3-S2" = c(1, -1))
  )
)

probe_slopes <- bind_rows(lapply(probes, `[[`, "slopes"))
probe_contrasts <- bind_rows(lapply(probes, `[[`, "contrasts"))

sensitivity <- bind_rows(lapply(names(models), function(outcome) {
  term <- if (outcome == "Confidence") {
    "Stage:Label:pre_AILS_CCS_Subjective_AI_Literacy"
  } else {
    "Stage:Label:pre_AI_Usefulness"
  }
  bind_rows(
    cbind(
      Outcome = outcome,
      Model = "Full random-intercept structure",
      Singular = isSingular(models[[outcome]]$full),
      omnibus_from_model(models[[outcome]]$full, term)
    ),
    cbind(
      Outcome = outcome,
      Model = "Zero-variance ID-by-Task intercept removed",
      Singular = isSingular(models[[outcome]]$simplified),
      omnibus_from_model(models[[outcome]]$simplified, term)
    )
  )
}))

out_path <- file.path(output_dir, "H3_Label_Dependent_Moderation.xlsx")
write.xlsx(
  list(
    Omnibus = label_dependent,
    Reproduction_Check = comparison,
    Change_Slopes = probe_slopes,
    Label_Contrasts = probe_contrasts,
    Singular_Fit_Sensitivity = sensitivity
  ),
  out_path,
  overwrite = TRUE
)

write.csv(
  label_dependent,
  file.path(output_dir, "H3_Label_Dependent_Moderation_Omnibus.csv"),
  row.names = FALSE
)
write.csv(
  probe_slopes,
  file.path(output_dir, "H3_Label_Dependent_Moderation_Change_Slopes.csv"),
  row.names = FALSE
)
write.csv(
  probe_contrasts,
  file.path(output_dir, "H3_Label_Dependent_Moderation_Label_Contrasts.csv"),
  row.names = FALSE
)
write.csv(
  sensitivity,
  file.path(output_dir, "H3_Label_Dependent_Moderation_Sensitivity.csv"),
  row.names = FALSE
)

expected_rows <- c(
  Omnibus = 4,
  Reproduction_Check = 4,
  Change_Slopes = 15,
  Label_Contrasts = 15,
  Singular_Fit_Sensitivity = 6
)
for (sheet in names(expected_rows)) {
  observed <- nrow(read_excel(out_path, sheet = sheet))
  if (observed != expected_rows[[sheet]]) {
    stop(sheet, " has ", observed, " rows; expected ", expected_rows[[sheet]])
  }
}

capture.output(
  sessionInfo(),
  file = file.path(output_dir, "H3_Label_Dependent_Moderation_Session_Info.txt")
)

cat("Verified deposited correction families and refitted four focal models.\n")
print(label_dependent %>% select(
  Outcome, Baseline_moderator, NumDF, DenDF, F_value, eta_p, p_value, p_BH, p_holm
))
