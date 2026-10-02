# Independent recomputation of the exact 33/39 results by a different code path (matrix algebra and closed-form
# formulas; no lm/anova.mlm/emmeans; eligibility re-implemented inline). Aggregate comparison output only.
# Usage: Rscript --vanilla verify_models.R <out_dir>
suppressPackageStartupMessages(library(jsonlite))
args <- commandArgs(TRUE)
out <- normalizePath(args[1], mustWork = TRUE)
cfg <- fromJSON(file.path(out, "records", "run_config.json"))
res <- function(f) read.csv(file.path(out, "results", f))
d <- read.csv(file.path(cfg$private_inputs, "cohort.csv"), check.names = FALSE, na.strings = c("", "NA"))
ph <- c(S1 = "stage1", S2 = "stage2", S3 = "stage3", M1 = "follow", LT = "follow2")
acc <- sapply(ph, function(w) rowMeans(d[paste0(w, "_task", 1:3, "_accuracy")]))
lab <- factor(d$Label, levels = c("AI", "AI Human", "Human"))
tool <- ifelse(is.na(d$follow2_tool_use), "", trimws(d$follow2_tool_use))
lt <- !is.na(d$follow2_returned) & d$follow2_returned == 1; m1 <- d$completed_1month == 1
i39 <- lt & tool == "no"; i33 <- i39 & m1
stopifnot(sum(i39) == 39, sum(i33) == 33)
checks <- list()
add <- function(name, diff, tol) checks[[length(checks) + 1]] <<- data.frame(check = name, max_abs_diff = diff, tolerance = tol, pass = is.finite(diff) && diff <= tol)

# Pillai trace by eigenvalues of E^-1 H (one-way MANOVA of four changes on Label in the 33).
Y <- acc[i33, ]; g <- droplevels(lab[i33])
D <- cbind(Y[, "S2"] - Y[, "S1"], Y[, "S3"] - Y[, "S1"], Y[, "M1"] - Y[, "S1"], Y[, "LT"] - Y[, "S1"])
gm <- colMeans(D); E <- matrix(0, 4, 4); H <- matrix(0, 4, 4)
for (k in levels(g)) {
  Dk <- D[g == k, , drop = FALSE]; mk <- colMeans(Dk)
  E <- E + crossprod(sweep(Dk, 2, mk)); H <- H + nrow(Dk) * tcrossprod(mk - gm)
}
lam <- Re(eigen(solve(E) %*% H, only.values = TRUE)$values)
V <- sum(lam / (1 + lam)); p <- 4; q <- nlevels(g) - 1; dfe <- nrow(D) - nlevels(g)
s <- min(p, q); m <- (abs(p - q) - 1) / 2; nn <- (dfe - p - 1) / 2
Fv <- (2 * nn + s + 1) / (2 * m + s + 1) * V / (s - V); df1 <- s * (2 * m + s + 1); df2 <- s * (2 * nn + s + 1)
pv <- pf(Fv, df1, df2, lower.tail = FALSE)
o <- res("mlm33_omnibus.csv")
add("Pillai value", abs(o$value - V), 1e-10); add("Pillai approx F", abs(o$approx_F - Fv), 1e-8)
add("Pillai df1/df2 (expected 8, 56)", max(abs(o$df1 - df1), abs(o$df2 - df2), abs(df1 - 8), abs(df2 - 56)), 0); add("Pillai P", abs(o$p - pv), 1e-10)

# Tukey label pairs from pooled-variance closed forms (ptukey/qtukey).
lc <- res("label_contrasts.csv")
tukey_manual <- function(y, gg) {
  gg <- droplevels(gg); lv <- levels(gg); nk <- table(gg); mk <- tapply(y, gg, mean)
  dfe <- length(y) - length(lv); s2 <- sum((y - mk[as.character(gg)])^2) / dfe
  pr <- combn(lv, 2)
  do.call(rbind, lapply(seq_len(ncol(pr)), function(j) {
    a <- pr[1, j]; b <- pr[2, j]; est <- mk[a] - mk[b]; se <- sqrt(s2 * (1 / nk[a] + 1 / nk[b])); tt <- est / se
    padj <- ptukey(abs(tt) * sqrt(2), length(lv), dfe, lower.tail = FALSE)
    hw <- qtukey(0.95, length(lv), dfe) / sqrt(2) * se
    data.frame(estimate = unname(est), SE = unname(se), df = dfe, p_adjusted = unname(padj), lower = unname(est - hw), upper = unname(est + hw))
  }))
}
for (spec in list(list("primary33", "LT level", acc[i33, "LT"], lab[i33], 30), list("primary33", "LT-S1 gain", acc[i33, "LT"] - acc[i33, "S1"], lab[i33], 30),
                  list("eligible39", "LT level", acc[i39, "LT"], lab[i39], 36), list("eligible39", "LT-S1 gain", acc[i39, "LT"] - acc[i39, "S1"], lab[i39], 36))) {
  mm <- tukey_manual(spec[[3]], spec[[4]])
  rr <- lc[lc$population == spec[[1]] & lc$family == spec[[2]], ]
  add(paste("Tukey pairs", spec[[1]], spec[[2]], "(df", spec[[5]], ")"),
      max(abs(as.matrix(rr[c("estimate", "SE", "df", "p_adjusted", "lower", "upper")]) - as.matrix(mm)), abs(mm$df - spec[[5]])), 1e-6)
}

# Label-balanced exact contrasts: mean of label means, SE from pooled variance, df = n - 3.
lb <- res("label_balanced_temporal.csv"); lb <- lb[lb$population == "primary33", ]
man <- do.call(rbind, lapply(c("S1", "S3", "M1"), function(ref) {
  y <- acc[i33, "LT"] - acc[i33, ref]; gg <- droplevels(lab[i33]); nk <- table(gg); mk <- tapply(y, gg, mean)
  dfe <- length(y) - 3; s2 <- sum((y - mk[as.character(gg)])^2) / dfe
  est <- mean(mk); se <- sqrt(s2 * sum(1 / nk) / 9); tt <- est / se
  data.frame(estimate = est, SE = se, df = dfe, p = 2 * pt(-abs(tt), dfe))
}))
man$p_holm <- p.adjust(man$p, "holm")
add("Label-balanced exact contrasts (33; df 30)", max(abs(as.matrix(lb[c("estimate", "SE", "df", "p", "p_holm")]) - as.matrix(man))), 1e-10)

# Paired t P values from pt() and Holm by hand for every paired row.
pc <- res("paired_contrasts.csv")
p_manual <- 2 * pt(-abs(pc$estimate / pc$SE), pc$df)
holm_manual <- ave(p_manual, pc$family_id, FUN = function(x) { o <- order(x); k <- length(x); a <- pmin(1, cummax((k - seq_len(k) + 1) * x[o])); a[order(o)] })
add("Paired t P values (pt)", max(abs(p_manual - pc$p)), 1e-12); add("Paired Holm (manual)", max(abs(holm_manual - pc$p_holm)), 1e-12)
add("Paired CI half-width = qt * SE", max(abs((pc$upper - pc$estimate) - qt(.975, pc$df) * pc$SE)), 1e-12)

# Full-cohort model contrasts: P from t(df) and Holm within each model; attrition bounds recomputed.
for (f in c("fullcohort_gls_contrasts.csv", "fullcohort_lmer_contrasts.csv")) {
  x <- res(f); key <- if ("measure" %in% names(x)) paste(x$model, x$measure) else x$model
  pm <- 2 * pt(-abs(x$estimate / x$SE), x$df)
  hm <- ave(pm, key, FUN = function(v) { o <- order(v); k <- length(v); a <- pmin(1, cummax((k - seq_len(k) + 1) * v[o])); a[order(o)] })
  add(paste(f, "P from t(df) and Holm"), max(abs(pm - x$p.value), abs(hm - x$p_holm)), 1e-10)
}
i170 <- !(lt & tool != "no")
ab <- res("attrition_bounds.csv")
obs <- sum(acc[i170 & lt, "LT"]); base <- sum(acc[i170, "S1"]); nmiss <- sum(i170 & !lt)
add("attrition bounds (170)", max(abs(c(ab$N - sum(i170), ab$observed - 39, ab$lower_change - (obs - base) / sum(i170),
                                         ab$upper_change - (obs + nmiss - base) / sum(i170)))), 1e-12)

out_df <- do.call(rbind, checks)
write.csv(out_df, file.path(out, "records", "verify_models.csv"), row.names = FALSE)
cat("verify_models:", if (all(out_df$pass)) "PASS" else "FAIL", sprintf("(%d checks)\n", nrow(out_df)))
if (!all(out_df$pass)) { print(out_df[!out_df$pass, ]); quit(status = 1) }
