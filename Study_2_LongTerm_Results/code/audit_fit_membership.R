# All-fit participant audit. For every saved fitted object (private/fits/*.rds) and every registered computation
# (private/membership_registry.rds), extract the participant set actually used, compare its keyed fingerprint with the
# Python QC fingerprint of the contracted sample (independent implementation), count excluded participants present,
# and for lm objects confirm that the stored data reproduce the saved fit. Public output: aggregates and booleans only.
# Usage: Rscript --vanilla audit_fit_membership.R <out_dir>
suppressPackageStartupMessages({ library(jsonlite); library(openssl); library(nlme); library(lme4) })
args <- commandArgs(TRUE)
out <- normalizePath(args[1], mustWork = TRUE)
code_dir <- dirname(normalizePath(gsub("~+~", " ", sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]), fixed=TRUE)))
cfg <- fromJSON(file.path(out, "records", "run_config.json"))
source(file.path(code_dir, "eligibility.R"))
options(contrasts = c("contr.sum", "contr.poly"))
key <- readBin(cfg$fingerprint_key, "raw", 64)
qfp <- fromJSON(file.path(out, "private", "qc_fingerprints.json"))
cp <- file.path(cfg$private_inputs, "cohort.csv")
d <- read.csv(cp, check.names = FALSE, na.strings = c("", "NA")); idc <- read_ids_chr(cp)
S <- derive_samples(d, idc)
excluded <- idc[S$excluded_reported_use | S$excluded_unknown]
label_of <- setNames(as.character(d$Label), idc)

audit_row <- function(object, kind, ids, expected, refit_ok = NA) {
  ids <- sort(unique(as.character(ids)), method = "radix")
  fp_ok <- !is.null(qfp[[expected]]) && set_fingerprint(key, ids) == qfp[[expected]]$fingerprint && length(ids) == qfp[[expected]]$n
  lab <- table(factor(label_of[ids], levels = c("AI", "AI Human", "Human")))
  data.frame(object = object, kind = kind, expected_sample = expected, n_participants = length(ids),
             n_expected = if (is.null(qfp[[expected]])) NA else qfp[[expected]]$n, set_matches_contract = fp_ok,
             excluded_present = sum(ids %in% excluded), AI = lab[[1]], AI_Human = lab[[2]], Human = lab[[3]],
             stored_data_reproduce_fit = refit_ok,
             pass = fp_ok && sum(ids %in% excluded) == 0 && (is.na(refit_ok) || isTRUE(refit_ok)))
}

# ---- saved fits --------------------------------------------------------------------------------------------
expected_for <- function(name, sample) {
  if (grepl("^timing_", name)) return(paste0("timing_", sample))
  sample
}
refit_lm <- function(obj) {
  f <- obj$fit; dat <- obj$data
  new <- if (is.matrix(coef(f))) {
    lm(as.matrix(dat[c("S2mS1", "S3mS1", "M1mS1", "LTmS1")]) ~ dat$lab33)
  } else lm(formula(f), data = dat)
  isTRUE(max(abs(unname(as.matrix(coef(new))) - unname(as.matrix(coef(f))))) < 1e-10) && nobs(new) == nobs(f)
}
rows <- list()
for (fp in sort(list.files(file.path(out, "private", "fits"), pattern = "\\.rds$", full.names = TRUE))) {
  obj <- readRDS(fp); name <- sub("\\.rds$", "", basename(fp)); fit <- obj$fit
  if (inherits(fit, "gls")) {
    g <- as.character(getGroups(fit))
    ids <- unique(g); refit <- identical(sort(unique(g)), sort(unique(as.character(obj$data$ID)))) && nobs(fit) == nrow(obj$data)
  } else if (inherits(fit, "merMod")) {
    ids <- unique(as.character(fit@frame$ID)); refit <- nobs(fit) == nrow(obj$data)
  } else if (inherits(fit, "lm")) {
    ids <- as.character(obj$data$ID); refit <- refit_lm(obj)
  } else stop("unknown fit class in ", name)
  rows[[name]] <- audit_row(name, class(fit)[1], ids, expected_for(name, obj$sample), refit)
}

# ---- registered non-model computations (paired rows, descriptives, bounds) ----------------------------------
reg <- readRDS(file.path(out, "private", "membership_registry.rds"))
reg_expected <- function(nm) {
  parts <- strsplit(nm, "[|:]")[[1]]
  if (parts[1] == "paired") {
    pop <- sub("_item_weighted$", "", parts[2]); ref <- parts[5]
    if (ref == "LT-M1") return(if (grepl("no_prior_exposure", pop)) "primary33_no_prior_exposure" else "primary33")
    return(pop)
  }
  switch(parts[1], sample = parts[2], descriptives = parts[2], selection = parts[2],
         fullcohort = parts[2], attrition = "eligible39", stop("unmapped registry entry"))
}
for (nm in names(reg)) rows[[nm]] <- audit_row(nm, reg[[nm]]$kind, reg[[nm]]$ids, reg_expected(nm))

res <- do.call(rbind, rows); rownames(res) <- NULL
write.csv(res, file.path(out, "records", "fit_membership_audit.csv"), row.names = FALSE)
n_fit <- sum(!res$kind %in% c("sample", "paired", "descriptive", "fullcohort"))
cat(sprintf("fit membership audit: %d objects (%d fitted models, %d registered computations); all pass=%s; excluded participants present in any object=%d\n",
            nrow(res), n_fit, nrow(res) - n_fit, all(res$pass), sum(res$excluded_present)))
if (!all(res$pass)) { print(res[!res$pass, c("object", "expected_sample", "n_participants", "n_expected", "set_matches_contract", "excluded_present", "stored_data_reproduce_fit")]); quit(status = 1) }
