#!/usr/bin/env Rscript
# Retained Figure 6 completer-only tests from published commit c8158ef819d21b34b76b63cf5b83fafd44897f4f.
# Original cohort filter, covariate recoding, reshape, lmer formula/defaults,
# Phase levels, emmeans and pairs calls are preserved. Only paths and aggregate
# extraction are adapted. No participant rows or model objects are exported.
# Run before Figure_Study2_2.Rmd in the repository's original root renv environment.

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) stop("Could not locate reproduce_completer_tests.R")
script_path <- sub("^--file=", "", script_arg)
if (!file.exists(script_path)) script_path <- gsub("~\\+~", " ", script_path)
script_path <- normalizePath(script_path, mustWork = TRUE)
repo_root <- normalizePath(file.path(dirname(script_path), ".."), mustWork = TRUE)
active_project <- Sys.getenv("RENV_PROJECT")
if (!nzchar(active_project) || !identical(normalizePath(active_project, mustWork = FALSE), repo_root)) {
  Sys.setenv(RENV_PROJECT = repo_root)
  source(file.path(repo_root, "renv", "activate.R"), local = FALSE)
}
args <- commandArgs(trailingOnly = TRUE)
if (length(args) > 1L) stop("Usage: reproduce_completer_tests.R [output_directory]")
output_dir <- if (length(args)) args[[1L]] else file.path(repo_root, "Figures", "data")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

set.seed(42)
suppressPackageStartupMessages({
  library(tidyverse)
  library(readxl)
  library(lmerTest)
  library(emmeans)
})
GROUP_LEVELS <- c("AI", "AI Human", "Human")
# The deposited earlier workbook is immutable and is already in the public manifest.
manifest <- jsonlite::fromJSON(file.path(repo_root, "Figures", "publicfigure_input_manifest.json"))$file_sha256
input_rel <- "Study_2_FollowUp_Results/MAR/data/Study_2_Full_Data.xlsx"
input_file <- file.path(repo_root, input_rel)
input_sha <- paste(unclass(openssl::sha256(file(input_file))), collapse = "")
stopifnot(identical(input_sha, manifest[[input_rel]]))
data_raw <- read_excel(input_file)
data_filtered <- data_raw %>%
  filter(stage1_task0_accuracy < 0.9) %>%
  mutate(followup_complete = !is.na(follow_task0_confidence))
stopifnot(nrow(data_filtered) == 175L, sum(data_filtered$followup_complete) == 84L)

fit_completer_p <- function(measure) {
  completer_long <- data_filtered %>%
    filter(.data$followup_complete) %>%
    mutate(
      Label = factor(.data$Label, levels = GROUP_LEVELS),
      Used_LLM_Hours = case_when(
        .data$Used_LLM_Hours == "0" ~ "None",
        .data$Used_LLM_Hours %in% c("1–5", "6–10") ~ "Low",
        .data$Used_LLM_Hours %in% c("11–20", ">20") ~ "High",
        TRUE ~ NA_character_
      ),
      Used_LLM_Hours = droplevels(factor(
        .data$Used_LLM_Hours,
        levels = c("None", "Low", "High")
      ))
    ) %>%
    select(
      ID, Label, Age, Gender, Field, Used_LLM_Hours,
      matches(paste0("^stage[23]_task[1-3]_", measure, "$"))
    ) %>%
    pivot_longer(
      cols = matches("^stage[23]_task[1-3]_"),
      names_to = "fullvar",
      values_to = "Value"
    ) %>%
    mutate(
      Phase = str_extract(.data$fullvar, "^stage[23]"),
      Task = str_extract(.data$fullvar, "task[1-3]"),
      Phase = factor(.data$Phase, levels = c("stage3", "stage2")),
      ID = factor(.data$ID),
      Task = factor(.data$Task)
    )

  model <- lmer(
    Value ~ Phase * Label + Age + Gender + Field + Used_LLM_Hours +
      (1 | ID) + (1 | Task) + (1 | ID:Task),
    data = completer_long
  )

  result <- as.data.frame(
    pairs(emmeans(model, ~ Phase | Label))
  ) %>%
    filter(
      .data$contrast == "stage3 - stage2",
      .data$Label %in% GROUP_LEVELS
    ) %>%
    mutate(Label = factor(.data$Label, levels = GROUP_LEVELS)) %>%
    arrange(.data$Label)

  if (nrow(result) != length(GROUP_LEVELS) || any(!is.finite(result$p.value))) {
    stop(sprintf(
      "Could not calculate the three completer-only %s P values.",
      measure
    ))
  }

  # Aggregate extraction only; model specification and contrasts above are unchanged.
  fitted_rows <- model.frame(model)
  list(
    p = setNames(result$p.value, as.character(result$Label)),
    n_model_participants = length(unique(fitted_rows$ID)),
    n_model_observations = nobs(model)
  )
}


format_p <- function(p) {
  if (length(p) != 1L || !is.finite(p)) stop("Completer test did not produce one finite P value")
  if (p < 0.001) "italic(P)~'< 0.001'" else sprintf("italic(P)~'= %.3f'", p)
}
make_record <- function(measure, panel) {
  x <- fit_completer_p(measure)
  data.frame(
    panel = panel, sample = "Completers", label = names(x$p),
    measure = measure, contrast = "stage3 - stage2", p.value = unname(x$p),
    displayed = vapply(unname(x$p), format_p, ""),
    n_initial_sample = nrow(data_filtered),
    n_followup_completers = sum(data_filtered$followup_complete),
    n_model_participants = x$n_model_participants,
    n_model_observations = x$n_model_observations,
    model_name = paste0("Figure6_", measure, "_original_completer_lmer"),
    stringsAsFactors = FALSE
  )
}
computed <- bind_rows(make_record("willing", "B willingness"), make_record("useful", "C usefulness"))
stopifnot(nrow(computed) == 6L, !anyDuplicated(computed[c("panel", "sample", "label")]))
write.csv(computed, file.path(output_dir, "figure6_completer_tests.csv"), row.names = FALSE)
# The preserved artwork records three-decimal strings, not unrounded P values.
# Require exact display agreement; no invented raw-value tolerance is applied.
frozen <- read.csv(file.path(repo_root, "Figures", "data", "fig6_panel_bc_p_values.csv"), stringsAsFactors = FALSE)
frozen <- frozen[frozen$sample == "Completers", ]
key <- function(x) paste(x$panel, x$sample, x$label, sep = "|")
stopifnot(nrow(frozen) == 6L, !anyDuplicated(key(frozen)), setequal(key(computed), key(frozen)))
expected <- frozen$displayed[match(key(computed), key(frozen))]
mismatch <- computed$displayed != expected
if (any(mismatch)) {
  discrepancy <- paste(key(computed)[mismatch], "computed", computed$displayed[mismatch], "preserved", expected[mismatch])
  stop(paste("Original completer-test display differs:", paste(discrepancy, collapse = "; ")), call. = FALSE)
}
cat("Figure 6: original six completer-only tests reproduced; three-decimal displays match preserved artwork.\n")
