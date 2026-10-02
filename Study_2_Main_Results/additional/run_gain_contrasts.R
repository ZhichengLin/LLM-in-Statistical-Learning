#!/usr/bin/env Rscript
# Focused rerun of the canonical notebook's primary model and added gain
# comparisons, without rerunning unrelated models/figures or using caches.
# From data-code/: Rscript --vanilla Study_2_Main_Results/additional/run_gain_contrasts.R
# Uses the active library; record sessionInfo() when invoking outside renv.
args <- commandArgs(FALSE)
script <- sub("^--file=", "", grep("^--file=", args, value = TRUE))
script <- gsub("~\\+~", " ", script)
analysis_dir <- normalizePath(file.path(dirname(script), ".."), mustWork = TRUE)
setwd(analysis_dir)
suppressPackageStartupMessages({
  library(readxl); library(dplyr); library(tidyr); library(stringr)
  library(forcats); library(lme4); library(lmerTest); library(emmeans)
})
stopifnot(requireNamespace("pbkrtest", quietly = TRUE),
          requireNamespace("effectsize", quietly = TRUE))
lines <- readLines("Study 2 Main Results.Rmd", warn = FALSE)
run_chunk <- function(label) {
  starts <- grep(paste0("^```\\{r ", label, "(,|\\})"), lines)
  stopifnot(length(starts) == 1L)
  end <- which(seq_along(lines) > starts & lines == "```")[1]
  code <- paste(lines[(starts + 1L):(end - 1L)], collapse = "\n")
  invisible(eval(parse(text = code), envir = .GlobalEnv))
}
for (label in c("load-data-1", "filter-stage-1-task-0-accuracy-1",
                "recode-background-variables-1", "convert-to-long-format-1",
                "data-filter-1")) run_chunk(label)
# Bounded input gate; no participant-level records are printed.
stopifnot(nrow(df) == 175L, !anyDuplicated(df$ID),
          identical(as.integer(table(df$Label)), c(59L, 58L, 58L)),
          nrow(performance_long) == 1575L,
          !anyNA(performance_long$Value),
          all(performance_long$Value >= 0 & performance_long$Value <= 1),
          !anyDuplicated(performance_long[c("ID", "Task", "Phase")]))
run_chunk("registered-participant-intercept-model")
run_chunk("post-hoc-s1-s2-gain-comparisons")
print(gain_export, row.names = FALSE)
cat("\nSession information for this scoped run:\n")
print(sessionInfo())
