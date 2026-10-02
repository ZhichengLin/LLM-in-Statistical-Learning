# Full-cohort MAR models for the no-tools reanalysis (sourced by analysis.R after its entry guard; local scope).
# Population: cohort170 = original analytic cohort minus the five excluded long-term tool users (all their waves).
# Formulas are those of the 44-leading package (analyze.R and covariance_sensitivity.R); only the population changed.
# Uses objects from analysis.R: d, S, idc, phases, phase_names, register, save_fit, wcsv, logw.
fc <- d[S$cohort170, ]
stopifnot(nrow(fc) == 170, !any(idc[S$cohort170] %in% excluded_ids))
fc$ID <- factor(fc$ID)
fc$Age <- factor(fc$Age); fc$Gender <- factor(fc$Gender); fc$Field <- factor(fc$Field)
hrs <- trimws(fc$Used_LLM_Hours)
fc$Used_LLM_Hours <- factor(ifelse(hrs == "0", "None", ifelse(hrs %in% c("1–5", "6–10"), "Low",
                            ifelse(hrs %in% c("11–20", ">20"), "High", NA))), levels = c("None", "Low", "High"))
covs <- c("Age", "Gender", "Field", "Used_LLM_Hours")
register("fullcohort:cohort170", as.character(fc$ID), "fullcohort")
register("fullcohort:covariate_complete", as.character(fc$ID[complete.cases(fc[covs])]), "fullcohort")

long <- do.call(rbind, lapply(seq_along(phases), function(i) do.call(rbind, lapply(1:3, function(t) do.call(rbind, lapply(c("accuracy", "confidence"),
  function(m) data.frame(ID = fc$ID, Label = fc$Label, Age = fc$Age, Gender = fc$Gender, Field = fc$Field, Used_LLM_Hours = fc$Used_LLM_Hours,
                         Phase = phases[i], Task = as.character(t), Measure = m, Value = fc[[paste0(phases[i], "_task", t, "_", m)]])))))))
long <- long[!is.na(long$Value), ]
long$Phase <- factor(long$Phase, levels = phases); long$Task <- factor(long$Task)
tc_list <- list(`LT-S1` = c(-1, 0, 0, 0, 1), `LT-S3` = c(0, 0, -1, 0, 1), `LT-M1` = c(0, 0, 0, -1, 1))

# ---- GLS participant-wave models (covariance_sensitivity.R specification) ---------------------------------
gls_res <- list(); gls_means <- list(); gls_labels <- list(); gls_diag <- list()
for (spec in c("accuracy_unadjusted", "accuracy_adjusted", "confidence_adjusted")) {
  measure <- strsplit(spec, "_")[[1]][1]; adjusted <- !grepl("_unadjusted$", spec)
  lm_ <- long[long$Measure == measure, ]
  gd <- aggregate(Value ~ ID + Phase, data = lm_, FUN = mean)
  nt <- aggregate(Value ~ ID + Phase, data = lm_, FUN = length)
  stopifnot(all(nt$Value == 3))
  gd <- merge(gd, fc[, c("ID", "Label", covs)], by = "ID")
  gd$wave <- as.integer(gd$Phase)
  gd <- gd[order(gd$ID, gd$wave), ]
  if (adjusted) gd <- gd[complete.cases(gd[, covs]), ]
  gd$ID <- droplevels(gd$ID)
  formula <- if (adjusted) Value ~ Phase * Label + Age + Gender + Field + Used_LLM_Hours else Value ~ Phase * Label
  warns <- character()
  fit <- tryCatch(withCallingHandlers(gls(formula, data = gd, correlation = corSymm(form = ~ wave | ID), weights = varIdent(form = ~ 1 | Phase),
                                          method = "REML", control = glsControl(msMaxIter = 300)),
                                      warning = function(w) { warns <<- c(warns, conditionMessage(w)); invokeRestart("muffleWarning") }),
                  error = function(e) e)
  structure <- "unstructured"; fail <- ""
  if (inherits(fit, "error")) {
    fail <- conditionMessage(fit); structure <- "heterogeneous_CS"
    fit <- tryCatch(gls(formula, data = gd, correlation = corCompSymm(form = ~ wave | ID), weights = varIdent(form = ~ 1 | Phase), method = "REML"),
                    error = function(e) e)
  }
  if (inherits(fit, "error")) {
    fail <- paste(fail, conditionMessage(fit)); structure <- "participant_RI"
    fit <- lmer(update(formula, . ~ . + (1 | ID)), data = gd)
    em <- emmeans(fit, ~ Phase, weights = "equal", lmer.df = "kenward-roger")
    el <- emmeans(fit, ~ Label | Phase, at = list(Phase = "follow2"), lmer.df = "kenward-roger")
  } else {
    fit$call$model <- formula; fit$call$data <- gd
    em <- emmeans(fit, ~ Phase, weights = "equal", mode = "satterthwaite")
    el <- emmeans(fit, ~ Label | Phase, at = list(Phase = "follow2"), mode = "satterthwaite")
  }
  if (length(warns)) for (w in unique(warns)) logw(paste("fullcohort GLS", spec), w)
  z <- as.data.frame(summary(contrast(em, tc_list, adjust = "none"), infer = c(TRUE, TRUE)))
  z$p_holm <- p.adjust(z$p.value, "holm"); z$model <- spec; z$participants <- nlevels(gd$ID); z$covariance <- structure
  gls_res[[spec]] <- z
  gls_means[[spec]] <- transform(as.data.frame(confint(em)), model = spec)
  gls_labels[[spec]] <- transform(as.data.frame(summary(pairs(el, adjust = "tukey"), infer = c(TRUE, TRUE))), model = spec)
  # Record requested and effective df modes (emmeans uses df.error whenever apVar is not a matrix) and apVar status.
  gls_diag[[spec]] <- data.frame(model = spec, nobs = nrow(gd), participants = nlevels(gd$ID), LT_n = sum(gd$Phase == "follow2"),
                                 M1_n = sum(gd$Phase == "follow"), covariance = structure, fallback_reason = fail,
                                 warnings = paste(unique(warns), collapse = " | "),
                                 requested_df_mode = if (structure == "participant_RI") "kenward-roger" else "satterthwaite",
                                 effective_df_mode = if (structure == "participant_RI") "kenward-roger" else attr(em@dffun, "mesg"),
                                 apVar_available = if (inherits(fit, "gls")) is.matrix(fit$apVar) else NA,
                                 apVar_message = if (inherits(fit, "gls") && !is.matrix(fit$apVar)) as.character(fit$apVar)[1] else "",
                                 df_error_used = if (inherits(fit, "gls") && identical(attr(em@dffun, "mesg"), "df.error"))
                                   unique(round(summary(em)$df, 6))[1] else NA)
  save_fit(paste0("fullcohort_gls_", spec), fit, gd, if (adjusted) "covariate_complete" else "cohort170", if (structure == "participant_RI") "lmer" else "gls")
}
fc_contrasts <- do.call(rbind, gls_res)
wcsv(fc_contrasts, "fullcohort_gls_contrasts")
wcsv(do.call(rbind, gls_means), "fullcohort_gls_means")
wcsv(do.call(rbind, gls_labels), "fullcohort_gls_lt_labels")
n_covariate_complete <- gls_diag$accuracy_adjusted$participants
stopifnot(gls_diag$accuracy_unadjusted$participants == 170, n_covariate_complete == 168, gls_diag$accuracy_unadjusted$LT_n == 39)

# ---- Task-level lmer continuations (analyze.R specification) ---------------------------------------------
lmer_res <- list(); lmer_means <- list(); lmer_labels <- list(); lmer_diag <- list(); lmer_vc <- list()
fit_one <- function(formula, dat, name, measure) {
  warns <- character()
  fit <- withCallingHandlers(lmer(formula, data = dat, REML = TRUE),
                             warning = function(w) { warns <<- c(warns, conditionMessage(w)); invokeRestart("muffleWarning") })
  key <- paste(name, measure)
  em <- emmeans(fit, ~ Phase, weights = "equal", lmer.df = "kenward-roger")
  vc <- as.data.frame(VarCorr(fit))
  lmer_vc[[key]] <<- data.frame(model = name, measure = measure, component = vc$grp, variance = vc$vcov, sd = vc$sdcor,
                                at_boundary = vc$grp != "Residual" & vc$vcov < 1e-8)
  lmer_diag[[key]] <<- data.frame(model = name, measure = measure, nobs = nobs(fit), participants = length(unique(model.frame(fit)$ID)),
                                  singular = isSingular(fit), warning = paste(unique(c(warns, fit@optinfo$conv$lme4$messages)), collapse = "; "),
                                  requested_df_mode = "kenward-roger", effective_df_mode = attr(em@dffun, "mesg"),
                                  boundary_components = paste(vc$grp[vc$grp != "Residual" & vc$vcov < 1e-8], collapse = "; "))
  ans <- as.data.frame(summary(contrast(em, tc_list, adjust = "none"), infer = c(TRUE, TRUE)))
  ans$p_holm <- p.adjust(ans$p.value, "holm"); ans$model <- name; ans$measure <- measure
  ans$participants <- length(unique(model.frame(fit)$ID))
  lmer_res[[key]] <<- ans
  lmer_means[[key]] <<- transform(as.data.frame(confint(em)), model = name, measure = measure)
  el <- emmeans(fit, ~ Label | Phase, at = list(Phase = "follow2"), lmer.df = "kenward-roger")
  lmer_labels[[key]] <<- transform(as.data.frame(summary(pairs(el, adjust = "tukey"), infer = c(TRUE, TRUE))), model = name, measure = measure)
  mf <- model.frame(fit)
  save_fit(paste0("fullcohort_lmer_", name, "_", measure), fit, mf,
           if (length(unique(mf$ID)) == 170) "cohort170" else "covariate_complete", "lmer")
}
for (m in c("accuracy", "confidence")) {
  dat <- long[long$Measure == m, ]
  if (m == "accuracy") fit_one(Value ~ Phase * Label + (1 | ID), dat, "historical_structure", m)
  if (m == "accuracy") fit_one(Value ~ Phase * Label + (1 | Task) + (1 | ID) + (1 | ID:Task), dat, "task_dependence", m)
  fit_one(Value ~ Phase * Label + Age + Gender + Field + Used_LLM_Hours + (1 | Task) + (1 | ID) + (1 | ID:Task), dat, "task_adjusted", m)
}
wcsv(do.call(rbind, lmer_res), "fullcohort_lmer_contrasts")
wcsv(do.call(rbind, lmer_means), "fullcohort_lmer_means")
wcsv(do.call(rbind, lmer_labels), "fullcohort_lmer_lt_labels")
gd_all <- do.call(rbind, gls_diag); ld_all <- do.call(rbind, lmer_diag)
fc_diag <- rbind(
  data.frame(family = "gls", model = gd_all$model, measure = sub("_.*$", "", gd_all$model), nobs = gd_all$nobs, participants = gd_all$participants,
             covariance = gd_all$covariance, singular = NA, boundary_components = "", requested_df_mode = gd_all$requested_df_mode,
             effective_df_mode = gd_all$effective_df_mode, apVar_available = gd_all$apVar_available, apVar_message = gd_all$apVar_message,
             df_error_used = gd_all$df_error_used, LT_n = gd_all$LT_n, warnings = gd_all$warnings, fallback_reason = gd_all$fallback_reason),
  data.frame(family = "lmer", model = ld_all$model, measure = ld_all$measure, nobs = ld_all$nobs, participants = ld_all$participants,
             covariance = "random intercepts", singular = ld_all$singular, boundary_components = ld_all$boundary_components,
             requested_df_mode = ld_all$requested_df_mode, effective_df_mode = ld_all$effective_df_mode, apVar_available = NA,
             apVar_message = "", df_error_used = NA, LT_n = NA, warnings = ld_all$warning, fallback_reason = ""))
wcsv(do.call(rbind, lmer_vc), "fullcohort_lmer_variance_components")
wcsv(fc_diag, "fullcohort_diagnostics")

# ---- Finite-cohort attrition bounds (cohort170; observed long-term outcomes = eligible39) ----------------
fc_obs <- fc[fc$returned, ]
stopifnot(nrow(fc_obs) == 39)
obs_sum <- sum(fc_obs$LT_accuracy); total_baseline <- sum(fc$S1_accuracy); nmiss <- sum(!fc$returned)
wcsv(data.frame(N = nrow(fc), observed = nrow(fc_obs), missing = nmiss, cohort_S1_mean = mean(fc$S1_accuracy),
                observed_LT_mean = mean(fc_obs$LT_accuracy), lower_change = (obs_sum - total_baseline) / nrow(fc),
                upper_change = (obs_sum + nmiss - total_baseline) / nrow(fc), missing_LT_mean_for_zero_change = (total_baseline - obs_sum) / nmiss,
                nonreturner_S1_mean = mean(fc$S1_accuracy[!fc$returned]),
                note = "identification bounds (not confidence intervals); cohort170 excludes the five tool users entirely"), "attrition_bounds")
wcsv(data.frame(missing_LT_mean = seq(0, 1, .05), cohort_LT_mean = (obs_sum + nmiss * seq(0, 1, .05)) / nrow(fc),
                cohort_change = (obs_sum + nmiss * seq(0, 1, .05) - total_baseline) / nrow(fc)), "attrition_tipping")
register("attrition:observed39", as.character(fc_obs$ID), "descriptive")
