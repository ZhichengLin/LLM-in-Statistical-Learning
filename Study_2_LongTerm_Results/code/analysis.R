# No-tools long-term reanalysis, implementing analysis_contract.yaml v1 (minimal new version of the primary-38
# analysis.R: eligibility rule, populations, paths and dependent labels/counts changed; formulas, contrasts,
# families, df rules and fallbacks unchanged). Aggregate outputs only; identifiers and participant-level values are
# never printed or written outside private/ (0700 directory, 0600 files).
# Usage: Rscript --vanilla analysis.R <out_dir>   (paths from <out_dir>/records/run_config.json)
suppressPackageStartupMessages({ library(nlme); library(emmeans); library(lme4); library(jsonlite); library(openssl) })
Sys.umask("077")
args <- commandArgs(TRUE)
out <- normalizePath(args[1], mustWork = TRUE)
code_dir <- dirname(normalizePath(gsub("~+~", " ", sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]), fixed=TRUE)))
cfg <- fromJSON(file.path(out, "records", "run_config.json"))
source(file.path(code_dir, "eligibility.R")); source(file.path(code_dir, "guard.R"))

# ---- Entry guard (fails closed before any model) ---------------------------------------------------------
entry_guard(out, cfg, code_dir, file.path(dirname(code_dir), "analysis_contract.yaml"), model_environment=TRUE)
cat("Entry guard passed: READY binding verified against consumed inputs, contract, code and QC records.\n")

priv_in <- cfg$private_inputs
controls <- file.path(dirname(code_dir), "historical_controls")
res_dir <- file.path(out, "results"); rec_dir <- file.path(out, "records"); prv <- file.path(out, "private")
fits_dir <- file.path(prv, "fits")
for (p in c(res_dir, rec_dir, prv, fits_dir)) dir.create(p, showWarnings = FALSE, recursive = TRUE)
Sys.chmod(c(prv, fits_dir), "0700")
emm_options(msg.interaction = FALSE)

warn_log <- data.frame(step = character(), message = character())
logw <- function(step, msg) warn_log[nrow(warn_log) + 1, ] <<- list(step, msg)
wcsv <- function(x, name) write.csv(x, file.path(res_dir, paste0(name, ".csv")), row.names = FALSE, na = "")
registry <- list()   # private: participant IDs behind every reported computation (audited later)
register <- function(name, ids, kind) registry[[name]] <<- list(kind = kind, ids = sort(unique(as.character(ids)), method = "radix"))
save_fit <- function(name, fit, data, sample, kind) {
  f <- file.path(fits_dir, paste0(name, ".rds"))
  saveRDS(list(fit = fit, data = data, sample = sample, kind = kind), f); Sys.chmod(f, "0600")
}

# ---- Data and contracted samples ------------------------------------------------------------------------
d <- read.csv(file.path(priv_in, "cohort.csv"), check.names = FALSE, na.strings = c("", "NA"))
idc <- read_ids_chr(file.path(priv_in, "cohort.csv"))
stopifnot(nrow(d) == 175, identical(as.character(d$ID), idc))
S <- derive_samples(d, idc)
options(contrasts = c("contr.sum", "contr.poly"))
d$Label <- factor(d$Label, levels = c("AI", "AI Human", "Human"))
phases <- c("stage1", "stage2", "stage3", "follow", "follow2"); phase_names <- c("S1", "S2", "S3", "M1", "LT")
for (measure in c("accuracy", "confidence")) for (i in seq_along(phases)) {
  d[[paste0(phase_names[i], "_", measure)]] <- rowMeans(d[paste0(phases[i], "_task", 1:3, "_", measure)])
  d[[paste0(phase_names[i], "_", measure, "_item")]] <- d[[paste0(phases[i], "_task0_", measure)]]
}
d$returned <- S$lt_returns # explicit return flag retains observation counts after masking ineligible outcomes
e39 <- d[S$eligible39, ]; p33 <- d[S$primary33, ]; a6 <- d[S$additional6, ]; c170 <- d[S$cohort170, ]
p33ne <- d[S$primary33_no_prior_exposure, ]; e39ne <- d[S$eligible39_no_prior_exposure, ]
lab_n <- function(x) as.integer(table(factor(x$Label, levels = levels(d$Label))))
stopifnot(nrow(e39) == 39, identical(lab_n(e39), c(19L, 12L, 8L)), nrow(p33) == 33, identical(lab_n(p33), c(16L, 10L, 7L)),
          nrow(a6) == 6, nrow(c170) == 170, identical(lab_n(c170), c(59L, 58L, 53L)), sum(S$excluded_reported_use) == 5,
          sum(S$excluded_unknown) == 0, nrow(p33ne) == 23, nrow(e39ne) == 29, all(e39$follow2_tool_use == "no"),
          all(complete.cases(p33[paste0(phase_names, "_accuracy")])), all(complete.cases(p33[paste0(phase_names, "_confidence")])))
excluded_ids <- idc[S$excluded_reported_use | S$excluded_unknown]
for (nm in c("eligible39", "primary33", "additional6", "cohort170", "primary33_no_prior_exposure", "eligible39_no_prior_exposure"))
  register(paste0("sample:", nm), idc[S[[nm]]], "sample")

# ---- 1. Paired contrasts (primary, focal sensitivity, ancillary) -----------------------------------------
paired <- function(dat, measure = "accuracy", item = FALSE, population = "primary33") {
  suffix <- paste0("_", measure, if (item) "_item" else "")
  res <- lapply(c("S1", "S3", "M1"), function(ref) {
    a <- dat[[paste0("LT", suffix)]]; b <- dat[[paste0(ref, suffix)]]; diff <- a - b
    register(paste("paired", population, measure, if (item) "17-item" else "equal-task", paste0("LT-", ref), sep = "|"),
             dat$ID[is.finite(diff)], "paired")
    diff <- diff[is.finite(diff)]; n <- length(diff)
    fit <- t.test(diff); bs <- replicate(5000, mean(sample(diff, n, replace = TRUE))); qq <- quantile(bs, c(.025, .975))
    data.frame(reference_mean = mean(b[is.finite(a - b)]), longterm_mean = mean(a[is.finite(a - b)]), population, measure,
               weighting = if (item) "17-item" else "equal-task", contrast = paste0("LT-", ref), n, estimate = mean(diff),
               SE = sd(diff) / sqrt(n), df = n - 1, lower = fit$conf.int[1], upper = fit$conf.int[2],
               t = unname(fit$statistic), p = fit$p.value, boot_lower = unname(qq[1]), boot_upper = unname(qq[2]))
  })
  res <- do.call(rbind, res); res$p_holm <- p.adjust(res$p, "holm"); res
}
# Contract order after one set.seed(20260930); the first two families occupy the same RNG position as the prior
# s38_no_tools families (positive control).
set.seed(20260930)
pc <- do.call(rbind, list(
  paired(p33, "accuracy", FALSE, "primary33"), paired(p33, "confidence", FALSE, "primary33"),
  paired(e39, "accuracy", FALSE, "eligible39"), paired(e39, "confidence", FALSE, "eligible39"),
  paired(p33ne, "accuracy", FALSE, "primary33_no_prior_exposure"), paired(p33ne, "confidence", FALSE, "primary33_no_prior_exposure"),
  paired(e39ne, "accuracy", FALSE, "eligible39_no_prior_exposure"), paired(e39ne, "confidence", FALSE, "eligible39_no_prior_exposure"),
  paired(p33, "accuracy", TRUE, "primary33_item_weighted"), paired(e39, "accuracy", TRUE, "eligible39_item_weighted")))
pc$sample <- pc$population
pc$boot_seed <- 20260930; pc$boot_B <- 5000; pc$row_origin <- "new (seed 20260930, contract order)"
pc$sample_role <- with(pc, ifelse(sample == "primary33" & measure == "accuracy", "primary",
                  ifelse(sample == "primary33", "secondary (exploratory confidence)",
                  ifelse(sample == "eligible39" & measure == "accuracy", "focal sensitivity (one-month participation not required)",
                  ifelse(sample == "eligible39", "secondary sensitivity (exploratory confidence)",
                  ifelse(grepl("item_weighted$", sample), "ancillary scoring (within eligible)", "ancillary robustness (within eligible)"))))))
pc$family_id <- paste(pc$sample, pc$measure, pc$weighting, sep = "|")
pc$note <- ""
pc$note[pc$contrast == "LT-M1" & pc$sample == "eligible39"] <- "same 33 participants as primary33 LT-M1; estimate/t-CI/P identical, bootstrap draws differ by RNG position"
pc$note[pc$contrast == "LT-M1" & pc$sample == "eligible39_no_prior_exposure"] <- "same 23 participants as primary33_no_prior_exposure LT-M1; estimate/t-CI/P identical, bootstrap draws differ by RNG position"
pc$note[pc$contrast == "LT-M1" & pc$sample == "eligible39_item_weighted"] <- "same 33 participants as primary33_item_weighted LT-M1; estimate/t-CI/P identical, bootstrap draws differ by RNG position"
pc$note[pc$measure == "confidence"] <- trimws(paste(pc$note[pc$measure == "confidence"], "exploratory confidence: recorded 1-5 codes"))
pc <- pc[, c("family_id", "sample", "sample_role", "population", "measure", "weighting", "contrast", "n", "reference_mean", "longterm_mean",
             "estimate", "SE", "df", "t", "p", "p_holm", "lower", "upper", "boot_lower", "boot_upper", "boot_seed", "boot_B", "row_origin", "note")]
wcsv(pc, "paired_contrasts")

# Positive controls against the frozen primary-38 package (same participants; never current evidence).
prior_pc <- read.csv(file.path(controls, "p38_paired_contrasts.csv"))
det_cols <- c("reference_mean", "longterm_mean", "n", "estimate", "SE", "df", "lower", "upper", "t", "p", "p_holm")
boot_cols <- c("boot_lower", "boot_upper")
pcc <- do.call(rbind, lapply(seq_len(nrow(pc)), function(i) {
  r <- pc[i, ]
  if (!(r$sample %in% c("primary33", "eligible39")) || r$weighting != "equal-task") return(NULL)
  tgt <- if (r$sample == "primary33") "s38_no_tools" else "all44_no_tools"
  pr <- prior_pc[prior_pc$sample == tgt & prior_pc$measure == r$measure & prior_pc$weighting == "equal-task" & prior_pc$contrast == r$contrast, ]
  stopifnot(nrow(pr) == 1)
  dd <- max(abs(unlist(r[det_cols]) - unlist(pr[det_cols]))); bd <- max(abs(unlist(r[boot_cols]) - unlist(pr[boot_cols])))
  data.frame(sample = r$sample, measure = r$measure, contrast = r$contrast, prior_target = tgt,
             max_abs_diff_deterministic = dd, max_abs_diff_bootstrap = bd,
             bootstrap_required_equal = r$sample == "primary33",
             pass = dd <= 1e-12 && (r$sample != "primary33" || bd <= 1e-12))
}))
wcsv(pcc, "paired_positive_control")
stopifnot(nrow(pcc) == 12, all(pcc$pass))

# ---- 2. Descriptives ----------------------------------------------------------------------------------
wave_desc <- function(dat, pop, label = "all") {
  do.call(rbind, lapply(c("accuracy", "confidence"), function(m) do.call(rbind, lapply(phase_names, function(ph) {
    v <- dat[[paste0(ph, "_", m)]]; v <- v[!is.na(v)]; n <- length(v)
    if (n == 0) return(NULL)
    se <- if (n > 1) sd(v) / sqrt(n) else NA
    q <- if (n > 1) qt(.975, n - 1) else NA
    data.frame(population = pop, label = label, measure = m, phase = ph, n = n, mean = mean(v), sd = if (n > 1) sd(v) else NA,
               se = se, lower = mean(v) - q * se, upper = mean(v) + q * se)
  }))))
}
wd <- rbind(wave_desc(p33, "primary33"), wave_desc(e39, "eligible39"), wave_desc(a6, "additional6"),
            do.call(rbind, lapply(levels(d$Label), function(g) wave_desc(p33[p33$Label == g, ], "primary33", g))),
            do.call(rbind, lapply(levels(d$Label), function(g) wave_desc(e39[e39$Label == g, ], "eligible39", g))))
wd$note <- ifelse(wd$measure == "confidence", "exploratory confidence (recorded 1-5 codes)", "")
wd$note[wd$population == "additional6"] <- trimws(paste(wd$note[wd$population == "additional6"], "descriptive only; no label split"))
wcsv(wd, "wave_descriptives")
register("descriptives:additional6", a6$ID, "descriptive")

chg <- list()
for (pop in c("primary33", "eligible39")) {
  dat <- if (pop == "primary33") p33 else e39
  for (g in levels(d$Label)) for (m in c("accuracy", "confidence")) for (ref in c("S1", "S3", "M1")) {
    sub <- dat[dat$Label == g, ]
    x <- sub[[paste0("LT_", m)]] - sub[[paste0(ref, "_", m)]]; x <- x[is.finite(x)]; n <- length(x)
    se <- sd(x) / sqrt(n); q <- qt(.975, n - 1)
    chg[[length(chg) + 1]] <- data.frame(population = pop, label = g, measure = m, contrast = paste0("LT-", ref), n = n, mean = mean(x),
                                         sd = sd(x), se = se, lower = mean(x) - q * se, upper = mean(x) + q * se,
                                         note = "descriptive only; no within-label tests; not for between-label inference")
  }
}
wcsv(do.call(rbind, chg), "change_descriptives_by_label")

grp <- list(primary33 = p33, additional6 = a6, one_month_only = d[S$one_month_only, ], neither_followup = d[S$neither_followup, ])
stopifnot(nrow(grp$one_month_only) == 46, nrow(grp$neither_followup) == 85)
for (g in names(grp)) register(paste0("selection:", g), grp[[g]]$ID, "descriptive")
sel <- do.call(rbind, lapply(names(grp), function(g) {
  x <- grp[[g]]
  do.call(rbind, lapply(c("S1_accuracy", "S2_accuracy", "S3_accuracy", "M1_accuracy", "LT_accuracy", "S1_confidence"), function(v) {
    y <- x[[v]]; y <- y[!is.na(y)]
    if (!length(y)) return(NULL)
    data.frame(group = g, variable = v, n = length(y), mean = mean(y), sd = if (length(y) > 1) sd(y) else NA)
  }))
}))
wcsv(sel, "selection_descriptives")

tab3 <- function(x) as.list(setNames(lab_n(x), c("AI", "AI_Human", "Human")))
flow_row <- function(q, x, split = TRUE, note = "") {
  t <- tab3(x); data.frame(quantity = q, total = nrow(x), AI = if (split) t$AI else NA, AI_Human = if (split) t$AI_Human else NA,
                           Human = if (split) t$Human else NA, note = note)
}
excl <- d[S$excluded_reported_use | S$excluded_unknown, ]
flow <- rbind(
  flow_row("cohort175", d, note = "original analytic cohort (historical reference; not used in new fits)"),
  flow_row("one_month_completers_original", d[d$completed_1month == 1, ], note = "original one-month analyses (historical)"),
  flow_row("longterm_returns", d[d$returned, ], note = "observation count: long-term submissions in the frozen snapshot"),
  flow_row("excluded_reported_tool_use", excl, note = "mandatory exclusion (self-reported external tool/material use); counts only"),
  flow_row("excluded_unknown_tool_use", d[S$excluded_unknown, ], note = "missing/unknown response (none)"),
  flow_row("eligible39", e39, note = "eligibility count: long-term returns reporting no tool use"),
  flow_row("primary33", p33, note = "primary: eligible and completed both follow-ups"),
  flow_row("additional6", a6, split = FALSE, note = "eligible, no one-month data; descriptive only, no label split"),
  flow_row("cohort170", c170, note = "full-cohort model population (cohort175 minus the excluded five)"),
  flow_row("one_month_eligible", d[S$one_month_eligible, ], note = "one-month completers within cohort170"),
  data.frame(quantity = "covariate_complete", total = NA, AI = NA, AI_Human = NA, Human = NA, note = "filled by full-cohort models"),
  flow_row("primary33_no_prior_exposure", p33ne, split = FALSE, note = "ancillary robustness"),
  flow_row("eligible39_no_prior_exposure", e39ne, split = FALSE, note = "ancillary robustness"),
  flow_row("one_month_only", grp$one_month_only, split = FALSE, note = "within cohort170"),
  flow_row("neither_followup", grp$neither_followup, split = FALSE, note = "within cohort170"))
fr <- data.frame(quantity = c("33/170", "33/79", "39/170", "6/91", "33/39", "39/44"),
                 total = c(33 / 170, 33 / sum(S$one_month_eligible), 39 / 170, 6 / sum(S$cohort170 & !(d$completed_1month == 1)), 33 / 39, 39 / 44),
                 AI = NA, AI_Human = NA, Human = NA, note = "coverage fraction")
flow_all <- rbind(flow, fr)

# ---- 3. Complete-33 multivariate linear model -------------------------------------------------------------
Y <- as.matrix(p33[paste0(phase_names, "_accuracy")])
D <- cbind(S2mS1 = Y[, 2] - Y[, 1], S3mS1 = Y[, 3] - Y[, 1], M1mS1 = Y[, 4] - Y[, 1], LTmS1 = Y[, 5] - Y[, 1])
lab33 <- droplevels(p33$Label)
mlm <- lm(D ~ lab33)
av <- anova(mlm, test = "Pillai")
row <- av["lab33", ]
omni <- data.frame(analysis = "MLM33 Phase x Label (profile parallelism)", n = nrow(D), groups = nlevels(lab33), dvs = ncol(D),
                   change_basis = "S2-S1, S3-S1, M1-S1, LT-S1 (test invariant to full-rank basis)", statistic = "Pillai",
                   value = row$Pillai, approx_F = row$`approx F`, df1 = row$`num Df`, df2 = row$`den Df`, p = row$`Pr(>F)`,
                   note = "single omnibus specified in the retrospective analysis contract before model fitting; includes initial-session label differences; not evidence of parallelism if nonsignificant")
wcsv(omni, "mlm33_omnibus")
save_fit("mlm33", mlm, data.frame(ID = p33$ID, lab33 = lab33, D), "primary33", "lm")

lab_df <- function(y, lab) data.frame(y = y, Label = lab)
exact_pairs <- function(y, lab, ids, family, population, model_label, fit_name) {
  dat <- lab_df(y, lab); f <- lm(y ~ Label, data = dat)
  save_fit(fit_name, f, cbind(ID = ids, dat), population, "lm")
  s <- as.data.frame(summary(pairs(emmeans(f, ~Label), adjust = "tukey"), infer = c(TRUE, TRUE)))
  data.frame(analysis = model_label, population = population, family = family, contrast = s$contrast, estimate = s$estimate, SE = s$SE,
             df = s$df, df_method = "exact residual", t = s$t.ratio, p_adjusted = s$p.value, adjustment = "Tukey (3 pairs)",
             lower = s$lower.CL, upper = s$upper.CL, ci_type = "Tukey simultaneous 95%")
}
lab39 <- droplevels(e39$Label)
label_pairs <- rbind(
  exact_pairs(p33$LT_accuracy, lab33, p33$ID, "LT level", "primary33", "MLM33 (lm on complete per-person scores)", "pairs_lt_primary33"),
  exact_pairs(p33$LT_accuracy - p33$S1_accuracy, lab33, p33$ID, "LT-S1 gain", "primary33", "MLM33 (lm on complete per-person scores)", "pairs_gain_primary33"),
  exact_pairs(e39$LT_accuracy, lab39, e39$ID, "LT level", "eligible39", "lm39 (complete per-person scores)", "pairs_lt_eligible39"),
  exact_pairs(e39$LT_accuracy - e39$S1_accuracy, lab39, e39$ID, "LT-S1 gain", "eligible39", "lm39 (complete per-person scores)", "pairs_gain_eligible39"))
wcsv(label_pairs, "label_contrasts")

lb33 <- do.call(rbind, lapply(c("S1", "S3", "M1"), function(ref) {
  dat <- lab_df(p33$LT_accuracy - p33[[paste0(ref, "_accuracy")]], lab33)
  f <- lm(y ~ Label, data = dat)
  save_fit(paste0("label_balanced_primary33_LT-", ref), f, cbind(ID = p33$ID, dat), "primary33", "lm")
  s <- as.data.frame(summary(emmeans(f, ~1), infer = c(TRUE, TRUE)))
  data.frame(analysis = "MLM33 label-balanced (exact)", population = "primary33", contrast = paste0("LT-", ref), estimate = s$emmean,
             SE = s$SE, df = s$df, df_method = "exact residual", t = s$t.ratio, p = s$p.value, lower = s$lower.CL, upper = s$upper.CL)
}))
lb33$p_holm <- p.adjust(lb33$p, "holm")

# ---- 4. GLS (unstructured) for 39 (inference) and 33 (equivalence diagnostic) ------------------------
long_of <- function(dat) {
  gd <- do.call(rbind, lapply(seq_along(phase_names), function(i)
    data.frame(ID = dat$ID, Label = dat$Label, Phase = phase_names[i], wave = i, Value = dat[[paste0(phase_names[i], "_accuracy")]])))
  gd <- gd[!is.na(gd$Value), ]
  gd$Phase <- factor(gd$Phase, levels = phase_names); gd$ID <- factor(gd$ID); gd$Label <- droplevels(gd$Label)
  gd[order(gd$ID, gd$wave), ]
}
fit_gls <- function(gd, name) {
  res <- list(structure = "unstructured", error = "")
  fit <- tryCatch(withCallingHandlers(
    gls(Value ~ Phase * Label, data = gd, correlation = corSymm(form = ~ wave | ID), weights = varIdent(form = ~ 1 | Phase),
        method = "REML", control = glsControl(msMaxIter = 300)),
    warning = function(w) { logw(paste(name, "gls UN"), conditionMessage(w)); invokeRestart("muffleWarning") }),
    error = function(e) e)
  if (inherits(fit, "error")) {
    res$error <- conditionMessage(fit); res$structure <- "heterogeneous_CS"
    fit <- tryCatch(gls(Value ~ Phase * Label, data = gd, correlation = corCompSymm(form = ~ wave | ID),
                        weights = varIdent(form = ~ 1 | Phase), method = "REML"), error = function(e) e)
    if (inherits(fit, "error")) { res$error <- paste(res$error, "|", conditionMessage(fit)); res$structure <- "unstable"; fit <- NULL }
  }
  if (!is.null(fit)) { fit$call$data <- gd; save_fit(name, fit, gd, if (name == "gls33") "primary33" else "eligible39", "gls") }
  res$fit <- fit; res
}
gls_summaries <- function(g, gd, name) {
  fit <- g$fit
  set.seed(20260930)
  msgs <- character()
  rg <- withCallingHandlers(ref_grid(fit, data = gd, mode = "appx-satterthwaite"),
                            message = function(m) { msgs <<- c(msgs, conditionMessage(m)); invokeRestart("muffleMessage") })
  df_mode <- attr(rg@dffun, "mesg")
  emm_PL <- emmeans(rg, ~ Phase | Label)
  emm_P <- emmeans(rg, ~ Phase)                       # equal label weights (emmeans default)
  tc <- as.data.frame(summary(contrast(emm_P, list(`LT-S1` = c(-1, 0, 0, 0, 1), `LT-S3` = c(0, 0, -1, 0, 1), `LT-M1` = c(0, 0, 0, -1, 1)),
                                       adjust = "none"), infer = c(TRUE, TRUE)))
  emm_LP <- emmeans(rg, ~ Label | Phase)
  lt_pairs <- as.data.frame(summary(pairs(emm_LP, adjust = "tukey"), infer = c(TRUE, TRUE)))
  lt_pairs <- lt_pairs[lt_pairs$Phase == "LT", ]
  gain <- contrast(emm_PL, list(`LT-S1` = c(-1, 0, 0, 0, 1)), by = "Label")
  gain_pairs <- as.data.frame(summary(pairs(gain, by = "contrast", adjust = "tukey"), infer = c(TRUE, TRUE)))
  means <- rbind(transform(as.data.frame(summary(emm_PL)), weighting = "label-specific"),
                 transform(as.data.frame(summary(emm_P)), Label = "equal-weighted", weighting = "equal label weights"))
  cms <- corMatrix(fit$modelStruct$corStruct)
  R <- cms[[which(vapply(cms, function(m) NROW(m) == 5, TRUE))[1]]]
  ratios <- coef(fit$modelStruct$varStruct, unconstrained = FALSE, allCoef = TRUE)[phase_names]
  sds <- fit$sigma * unname(ratios)
  cs <- diag(sds) %*% R %*% diag(sds)
  list(df_mode = df_mode, messages = paste(unique(msgs), collapse = " | "), temporal = tc, lt_pairs = lt_pairs, gain_pairs = gain_pairs,
       means = means, cov = cs)
}
g_out <- list(); diag_rows <- list(); cov_rows <- list(); mean_rows <- list(); lb_rows <- list(lb33); xcheck <- list()
for (nm in c("gls33", "gls39")) {
  dat <- if (nm == "gls33") p33 else e39
  gd <- long_of(dat)
  stopifnot(nrow(gd) == if (nm == "gls33") 165 else 189)
  g <- fit_gls(gd, nm)
  if (is.null(g$fit)) {
    diag_rows[[nm]] <- data.frame(model = nm, rows = nrow(gd), participants = nlevels(gd$ID), covariance = g$structure,
                                  error = g$error, apVar_available = NA, df_mode = NA, min_eigen_cov = NA, logLik = NA, messages = "")
    next
  }
  s <- gls_summaries(g, gd, nm)
  ev <- eigen(s$cov, symmetric = TRUE, only.values = TRUE)$values
  diag_rows[[nm]] <- data.frame(model = nm, rows = nrow(gd), participants = nlevels(gd$ID), covariance = g$structure, error = g$error,
                                apVar_available = is.matrix(g$fit$apVar), df_mode = s$df_mode, min_eigen_cov = min(ev),
                                logLik = as.numeric(logLik(g$fit)), messages = s$messages)
  sds <- sqrt(diag(s$cov)); cr <- cov2cor(s$cov)
  cov_rows[[nm]] <- rbind(data.frame(model = nm, quantity = "SD", row = phase_names, col = "", value = unname(sds)),
                          do.call(rbind, lapply(1:4, function(i) data.frame(model = nm, quantity = "correlation", row = phase_names[i],
                                                                             col = phase_names[(i + 1):5], value = unname(cr[i, (i + 1):5])))))
  mean_rows[[nm]] <- data.frame(model = nm, Phase = s$means$Phase, Label = s$means$Label, weighting = s$means$weighting,
                                emmean = s$means$emmean, SE = s$means$SE, df = s$means$df)
  inference_ok <- identical(s$df_mode, "appx-satterthwaite")
  tc <- s$temporal
  tc_ok <- inference_ok & is.finite(tc$df) & tc$df > 0
  lbg <- data.frame(analysis = paste0(toupper(nm), " label-balanced (unstructured GLS, REML)"),
                    population = if (nm == "gls33") "primary33" else "eligible39", contrast = tc$contrast, estimate = tc$estimate, SE = tc$SE,
                    df = ifelse(tc_ok, tc$df, NA), df_method = ifelse(tc_ok, "appx-satterthwaite", "unavailable"),
                    t = ifelse(tc_ok, tc$t.ratio, NA), p = ifelse(tc_ok, tc$p.value, NA),
                    lower = ifelse(tc_ok, tc$lower.CL, NA), upper = ifelse(tc_ok, tc$upper.CL, NA))
  lbg$p_holm <- if (all(tc_ok)) p.adjust(lbg$p, "holm") else NA
  if (nm == "gls39") lb_rows[[length(lb_rows) + 1]] <- lbg
  g_out[[nm]] <- list(temporal = lbg, lt_pairs = s$lt_pairs, gain_pairs = s$gain_pairs)
}
lbt <- do.call(rbind, lb_rows)
lbt$note <- ifelse(lbt$population == "eligible39", "MAR within eligible returners for M1 (6 missing); estimate/SE retained if df unavailable",
                   "complete data; exact t(30)")
wcsv(lbt, "label_balanced_temporal")
wcsv(do.call(rbind, cov_rows), "gls_covariance")
wcsv(do.call(rbind, mean_rows), "gls_means")

cmp <- function(a_est, a_se, b_est, b_se) c(max_abs_d_estimate = max(abs(a_est - b_est)), max_rel_d_se = max(abs(a_se - b_se) / b_se))
if (!is.null(g_out$gls33)) {
  e1 <- cmp(g_out$gls33$temporal$estimate, g_out$gls33$temporal$SE, lb33$estimate, lb33$SE)
  lp33 <- label_pairs[label_pairs$population == "primary33", ]
  e2 <- cmp(c(g_out$gls33$lt_pairs$estimate, g_out$gls33$gain_pairs$estimate), c(g_out$gls33$lt_pairs$SE, g_out$gls33$gain_pairs$SE),
            lp33$estimate, lp33$SE)
  xcheck$gls33 <- data.frame(check = "GLS33 vs exact MLM33", max_abs_d_estimate = max(e1[1], e2[1]), max_rel_d_se = max(e1[2], e2[2]),
                             gls_df_range = paste(signif(range(c(g_out$gls33$temporal$df, g_out$gls33$lt_pairs$df, g_out$gls33$gain_pairs$df), na.rm = TRUE), 5), collapse = "-"),
                             exact_df = 30, pass = max(e1[1], e2[1]) <= 1e-6 && max(e1[2], e2[2]) <= 1e-3)
}
if (!is.null(g_out$gls39)) {
  lp39 <- label_pairs[label_pairs$population == "eligible39", ]
  e3 <- cmp(c(g_out$gls39$lt_pairs$estimate, g_out$gls39$gain_pairs$estimate), c(g_out$gls39$lt_pairs$SE, g_out$gls39$gain_pairs$SE),
            lp39$estimate, lp39$SE)
  xcheck$gls39 <- data.frame(check = "GLS39 label pairs vs lm39 (diagnostic only)", max_abs_d_estimate = e3[1], max_rel_d_se = e3[2],
                             gls_df_range = paste(signif(range(c(g_out$gls39$lt_pairs$df, g_out$gls39$gain_pairs$df), na.rm = TRUE), 5), collapse = "-"),
                             exact_df = 36, pass = NA)
}
diag_all <- do.call(rbind, diag_rows)
wcsv(diag_all, "gls_diagnostics")
wcsv(do.call(rbind, xcheck), "gls_crosscheck")

# ---- 5. Correction timing (eligible participants only) ------------------------------------------------
it <- read.csv(file.path(priv_in, "items.csv"))
it$ID <- factor(it$ID); it$Item <- factor(it$Item); it$Task <- factor(it$Task); it$Label <- factor(it$Label)
dif <- tapply(it$S1, it$Item, mean)                           # fixed original-study nuisance predictor (175 x S1)
it$item_difficulty <- unname(dif[as.character(it$Item)]) - mean(dif)
ct <- it[it$S1 == 0 & (it$S2 == 1 | it$S3 == 1) & !is.na(it$LT), ]
ct$Timing <- factor(ifelse(ct$S2 == 1, "Early", "Late"), levels = c("Late", "Early"))
contrasts(ct$Timing) <- contr.treatment(levels(ct$Timing))
samples <- list(primary33 = ct[as.character(ct$ID) %in% idc[S$primary33], ], eligible39 = ct[as.character(ct$ID) %in% idc[S$eligible39], ])
stopifnot(!any(as.character(samples$eligible39$ID) %in% excluded_ids))
timing <- list(); cells <- list()
for (nm in names(samples)) {
  cd <- samples[[nm]]   # no droplevels(): it would drop the treatment contrasts set on Timing (as in the prior code)
  w <- character()
  fitg <- function(fml) withCallingHandlers(
    glmer(fml, data = cd, family = binomial, control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))),
    warning = function(x) { w <<- c(w, conditionMessage(x)); invokeRestart("muffleWarning") })
  gf <- fitg(LT ~ Timing + Label + Task + item_difficulty + baseline + (1 | ID) + (1 | Item))
  vc <- as.data.frame(VarCorr(gf)); item_var <- vc$vcov[vc$grp == "Item"]; dropped <- FALSE
  if (item_var < 1e-8) { dropped <- TRUE; gf <- fitg(LT ~ Timing + Label + Task + item_difficulty + baseline + (1 | ID)) }
  b <- unname(fixef(gf)["TimingEarly"]); se <- sqrt(vcov(gf)["TimingEarly", "TimingEarly"]); z <- b / se
  pw <- character()
  prof <- tryCatch(withCallingHandlers(suppressMessages(confint(gf, parm = "TimingEarly", method = "profile")),
                                       warning = function(x) { pw <<- c(pw, conditionMessage(x)); invokeRestart("muffleWarning") }),
                   error = function(e) { pw <<- c(pw, paste("ERROR:", conditionMessage(e))); matrix(NA_real_, 1, 2) })
  em <- as.data.frame(summary(contrast(emmeans(gf, ~Timing), list(`Early/Late` = c(-1, 1))), infer = c(TRUE, TRUE), type = "response"))
  ppl <- tapply(as.character(cd$Timing), as.character(cd$ID), function(x) length(unique(x)))
  vcp <- as.data.frame(VarCorr(gf))
  tab_cells <- aggregate(LT ~ Label + Timing, data = cd, FUN = function(x) c(responses = length(x), successes = sum(x)))
  cm <- data.frame(sample = nm, Label = tab_cells$Label, Timing = tab_cells$Timing, responses = tab_cells$LT[, "responses"],
                   successes = tab_cells$LT[, "successes"])
  cm$failures <- cm$responses - cm$successes
  cm$participants <- mapply(function(l, t) length(unique(cd$ID[cd$Label == l & cd$Timing == t])), cm$Label, cm$Timing)
  cells[[nm]] <- cm
  task_cells <- aggregate(LT ~ Task + Timing, data = cd, FUN = function(x) c(n = length(x), s = sum(x)))
  sep_flag <- any(cm$successes == 0 | cm$failures == 0) || any(task_cells$LT[, "s"] == 0 | task_cells$LT[, "s"] == task_cells$LT[, "n"])
  timing[[nm]] <- data.frame(
    sample = nm, participants = length(unique(cd$ID)), responses = nrow(cd), items = length(unique(cd$Item)),
    early_responses = sum(cd$Timing == "Early"), late_responses = sum(cd$Timing == "Late"),
    early_participants = length(unique(cd$ID[cd$Timing == "Early"])), late_participants = length(unique(cd$ID[cd$Timing == "Late"])),
    both_category_participants = sum(ppl == 2), observed_LT_early = mean(cd$LT[cd$Timing == "Early"]),
    observed_LT_late = mean(cd$LT[cd$Timing == "Late"]), beta = b, se = se, z = z, p_wald = 2 * pnorm(-abs(z)), or = exp(b),
    wald_lower = exp(b - qnorm(.975) * se), wald_upper = exp(b + qnorm(.975) * se),
    profile_lower = exp(prof[1, 1]), profile_upper = exp(prof[1, 2]),
    emmeans_or = em$odds.ratio, emmeans_p = em$p.value,
    var_participant = vcp$vcov[vcp$grp == "ID"], var_item_initial = item_var, item_intercept_dropped = dropped,
    singular = isSingular(gf), separation_flag = sep_flag, quasi_separation_flag = abs(b) > 10 || se > 5,
    warnings = paste(unique(c(w, gf@optinfo$conv$lme4$messages)), collapse = " | "), profile_warnings = paste(unique(pw), collapse = " | "),
    coding = "Timing treatment (Late reference); Label, Task sum-coded")
  save_fit(paste0("timing_", nm), gf, cd, nm, "glmer")
}
tm <- do.call(rbind, timing)
wcsv(tm, "correction_timing")
wcsv(do.call(rbind, cells), "correction_cells")
pt38 <- read.csv(file.path(controls, "p38_correction_timing.csv")); pt38 <- pt38[pt38$sample == "s38_no_tools", ]
pt44 <- read.csv(file.path(controls, "p44_correction_timing.csv")); pt44 <- pt44[pt44$population == "no_tools", ]
t33 <- tm[tm$sample == "primary33", ]; t39 <- tm[tm$sample == "eligible39", ]
pcnt <- data.frame(
  check = c("primary33 OR", "primary33 Wald P", "primary33 profile lower", "primary33 profile upper", "primary33 participants/responses",
            "eligible39 OR", "eligible39 P", "eligible39 profile lower", "eligible39 profile upper", "eligible39 participants/responses"),
  prior_target = c(rep("primary-38 package s38_no_tools row", 5), rep("44-leading package no_tools row", 5)),
  prior = c(pt38$or, pt38$p_wald, pt38$profile_lower, pt38$profile_upper, paste(pt38$participants, pt38$responses, sep = "/"),
            pt44$odds.ratio, pt44$p.value, pt44$profile_lower, pt44$profile_upper, paste(pt44$participants, pt44$items, sep = "/")),
  current = c(t33$or, t33$p_wald, t33$profile_lower, t33$profile_upper, paste(t33$participants, t33$responses, sep = "/"),
              t39$or, t39$p_wald, t39$profile_lower, t39$profile_upper, paste(t39$participants, t39$responses, sep = "/")),
  tolerance = c(1e-4, 1e-4, 1e-3, 1e-3, 0, 1e-4, 1e-4, 1e-3, 1e-3, 0))
pcnt$abs_diff <- suppressWarnings(abs(as.numeric(pcnt$prior) - as.numeric(pcnt$current)))
pcnt$pass <- ifelse(pcnt$tolerance == 0, pcnt$prior == pcnt$current, pcnt$abs_diff <= pcnt$tolerance)
wcsv(pcnt, "correction_positive_control")

# ---- 6. Item-order association (ancillary; eligible 39) --------------------------------------------------
fo <- lm(LT_accuracy ~ follow2_item_order + Label + S1_accuracy, data = e39)
ho <- sandwich::vcovHC(fo, type = "HC3")
eo <- emmeans(fo, ~ follow2_item_order, vcov. = ho)
oc <- as.data.frame(summary(contrast(eo, method = list(`randomized-fixed` = c(-1, 1))), infer = c(TRUE, TRUE)))
wcsv(data.frame(population = "eligible39", n = nobs(fo), fixed = sum(e39$follow2_item_order == "fixed"),
                randomized = sum(e39$follow2_item_order == "randomized"), contrast = oc$contrast, estimate = oc$estimate, SE = oc$SE,
                df = oc$df, t = oc$t.ratio, p = oc$p.value, lower = oc$lower.CL, upper = oc$upper.CL,
                vcov = "HC3", note = "ancillary association adjusted for label and S1 accuracy; replaces the historical all-44 estimate"),
     "item_order_association")
save_fit("item_order_eligible39", fo, data.frame(ID = e39$ID, LT_accuracy = e39$LT_accuracy, follow2_item_order = e39$follow2_item_order,
                                                  Label = e39$Label, S1_accuracy = e39$S1_accuracy), "eligible39", "lm")

# ---- 7. Full-cohort (170) MAR models and attrition bounds -------------------------------------------
source(file.path(code_dir, "fullcohort_models.R"), local = TRUE)
flow_all$total[flow_all$quantity == "covariate_complete"] <- n_covariate_complete
wcsv(flow_all, "sample_flow")

# ---- 8. Comparison of paired, label-balanced and full-cohort estimates -----------------------------
pp <- pc[pc$weighting == "equal-task" & pc$sample %in% c("primary33", "eligible39") & pc$measure == "accuracy", ]
cmp_rows <- data.frame(outcome = pp$measure, contrast = pp$contrast,
                       analysis = ifelse(pp$sample == "primary33", "paired, primary 33", "paired, eligible 39 (LT-M1 uses the 33)"),
                       n = pp$n, weighting = "participants equal", missing_data = "none (observed pairs)", estimate = pp$estimate,
                       lower = pp$lower, upper = pp$upper, df = pp$df, p = pp$p, p_adjusted = pp$p_holm, adjustment = "Holm-3",
                       source = "paired_contrasts.csv")
cmp_rows <- rbind(cmp_rows, data.frame(outcome = "accuracy", contrast = lbt$contrast, analysis = lbt$analysis,
                                       n = ifelse(lbt$population == "primary33", 33, 39), weighting = "labels equal",
                                       missing_data = ifelse(lbt$population == "primary33", "none (complete)", "MAR within eligible returners (M1 for 6)"),
                                       estimate = lbt$estimate, lower = lbt$lower, upper = lbt$upper, df = lbt$df, p = lbt$p,
                                       p_adjusted = lbt$p_holm, adjustment = "Holm-3", source = "label_balanced_temporal.csv"))
gfc <- fc_contrasts[fc_contrasts$model %in% c("accuracy_unadjusted", "accuracy_adjusted"), ]
cmp_rows <- rbind(cmp_rows, data.frame(outcome = "accuracy", contrast = gfc$contrast,
                                       analysis = paste("full-cohort GLS", gfc$model), n = gfc$participants, weighting = "labels equal",
                                       missing_data = sprintf("MAR, cohort of %d (LT missing for %d)", gfc$participants, gfc$participants - 39),
                                       estimate = gfc$estimate, lower = gfc$lower.CL, upper = gfc$upper.CL, df = gfc$df, p = gfc$p.value,
                                       p_adjusted = gfc$p_holm, adjustment = "Holm-3", source = "fullcohort_gls_contrasts.csv"))
wcsv(cmp_rows, "comparison_33_39_170")

# ---- Private membership registry and logs ----------------------------------------------------------------
reg_file <- file.path(prv, "membership_registry.rds"); saveRDS(registry, reg_file); Sys.chmod(reg_file, "0600")
write.csv(warn_log, file.path(rec_dir, "analysis_warnings.csv"), row.names = FALSE)
writeLines(capture.output(sessionInfo()), file.path(rec_dir, "sessionInfo.txt"))
cat("Analysis complete: ", nrow(pc), " paired rows; paired positive controls: ", all(pcc$pass),
    "; timing positive controls: ", all(pcnt$pass), "; GLS: ", paste(diag_all$model, diag_all$covariance, diag_all$df_mode, collapse = "; "),
    "; full-cohort fits: ", nrow(fc_diag), "\n", sep = "")
