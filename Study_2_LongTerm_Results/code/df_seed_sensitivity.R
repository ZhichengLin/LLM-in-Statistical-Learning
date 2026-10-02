# Numerical uncertainty diagnostic (no new substantive model specification): sensitivity of emmeans' approximate-
# Satterthwaite df to the random-number state, using the saved fits. emmeans' appx-satterthwaite gradient for gls
# ("gradV.kludge") internally refits the SAME GLS specification under random parameter perturbations, so df, P and
# CI bounds of the GLS39 label-balanced contrasts and of the adjusted cohort GLS contrasts can depend on the RNG state.
# The pipeline values are reproducible because the RNG state is fixed by the contracted seed sequence; this script
# recomputes the same contrasts under two further fixed seeds, records the actual df/P/CI spread, and fails unless the
# estimates and SEs equal the pipeline values (they do not depend on the df approximation). P values here are
# unadjusted. The unadjusted cohort GLS uses df.error (apVar not positive definite) and is deterministic.
# Usage: Rscript --vanilla df_seed_sensitivity.R <out_dir>
suppressPackageStartupMessages({ library(nlme); library(emmeans); library(jsonlite); library(openssl); library(yaml) })
args <- commandArgs(TRUE)
out <- normalizePath(args[1], mustWork = TRUE)
code_dir <- dirname(normalizePath(gsub("~+~", " ", sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]), fixed=TRUE)))
cfg <- fromJSON(file.path(out, "records", "run_config.json"))
source(file.path(code_dir, "eligibility.R")); source(file.path(code_dir, "guard.R"))
entry_guard(out, cfg, code_dir, file.path(dirname(code_dir), "analysis_contract.yaml"), model_environment=TRUE)
options(contrasts = c("contr.sum", "contr.poly"))   # parameterization of the saved fits (required by the gradient refits)
emm_options(msg.interaction = FALSE)
tc <- list(`LT-S1` = c(-1, 0, 0, 0, 1), `LT-S3` = c(0, 0, -1, 0, 1), `LT-M1` = c(0, 0, 0, -1, 1))
fits <- file.path(out, "private", "fits")
res <- read.csv(file.path(out, "results", "label_balanced_temporal.csv"))
fcr <- read.csv(file.path(out, "results", "fullcohort_gls_contrasts.csv"))
rows <- list()
add <- function(model, seed, z) rows[[length(rows) + 1]] <<- data.frame(model = model, seed = seed, contrast = z$contrast, estimate = z$estimate,
                                                                        SE = z$SE, df = z$df, t = z$t.ratio, p = z$p.value, lower = z$lower.CL, upper = z$upper.CL)
p39 <- res[res$population == "eligible39", ]
add("GLS39 label-balanced", "pipeline (contract seed sequence)", data.frame(contrast = p39$contrast, estimate = p39$estimate, SE = p39$SE, df = p39$df,
    t.ratio = p39$t, p.value = p39$p, lower.CL = p39$lower, upper.CL = p39$upper))
for (m in c("accuracy_adjusted", "confidence_adjusted")) {
  x <- fcr[fcr$model == m, ]
  add(paste("full-cohort GLS", m), "pipeline (contract seed sequence)", data.frame(contrast = x$contrast, estimate = x$estimate, SE = x$SE, df = x$df,
      t.ratio = x$t.ratio, p.value = x$p.value, lower.CL = x$lower.CL, upper.CL = x$upper.CL))
}
for (s in c(1, 2)) {
  g39 <- readRDS(file.path(fits, "gls39.rds"))
  set.seed(s)
  rg <- suppressMessages(ref_grid(g39$fit, data = g39$data, mode = "appx-satterthwaite"))
  add("GLS39 label-balanced", paste("seed", s), as.data.frame(summary(contrast(emmeans(rg, ~Phase), tc, adjust = "none"), infer = c(TRUE, TRUE))))
  for (m in c("accuracy_adjusted", "confidence_adjusted")) {
    f <- readRDS(file.path(fits, paste0("fullcohort_gls_", m, ".rds")))$fit
    set.seed(s)
    em <- suppressMessages(emmeans(f, ~Phase, weights = "equal", mode = "satterthwaite"))
    add(paste("full-cohort GLS", m), paste("seed", s), as.data.frame(summary(contrast(em, tc, adjust = "none"), infer = c(TRUE, TRUE))))
  }
}
out_df <- do.call(rbind, rows)
# Numerical check: 3 models x 3 contrasts x 3 RNG variants; estimates and SEs must equal the pipeline values.
stopifnot(nrow(out_df) == 27, length(unique(paste(out_df$model, out_df$contrast))) == 9, all(table(out_df$seed) == 9))
pipe <- out_df[grepl("^pipeline", out_df$seed), ]
key <- function(x) paste(x$model, x$contrast)
m <- match(key(out_df), key(pipe))
d_est <- max(abs(out_df$estimate - pipe$estimate[m])); d_se <- max(abs(out_df$SE - pipe$SE[m]) / pipe$SE[m])
out_df$estimate_equals_pipeline <- abs(out_df$estimate - pipe$estimate[m]) <= 1e-10
out_df$se_equals_pipeline <- abs(out_df$SE - pipe$SE[m]) / pipe$SE[m] <= 1e-8
write.csv(out_df, file.path(out, "results", "df_seed_sensitivity.csv"), row.names = FALSE)
sm <- do.call(rbind, lapply(split(out_df, key(out_df)), function(x)
  data.frame(model = x$model[1], contrast = x$contrast[1], df_min = min(x$df), df_max = max(x$df), p_unadjusted_range = diff(range(x$p)),
             lower_range = diff(range(x$lower)), upper_range = diff(range(x$upper)))))
print(sm, row.names = FALSE, digits = 4)
cat(sprintf("df seed diagnostic: rows=%d; max |d estimate|=%.3g; max relative |d SE|=%.3g\n", nrow(out_df), d_est, d_se))
if (!all(out_df$estimate_equals_pipeline & out_df$se_equals_pipeline)) stop("estimates or SEs differ from the pipeline across RNG states")
