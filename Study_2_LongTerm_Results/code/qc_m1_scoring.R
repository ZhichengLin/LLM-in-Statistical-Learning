# Q14b: independent one-month rescoring (unchanged rule from the primary-38 package; paths parameterized).
# Rescore one-month task means from the deposited item file (correction_raw_data.xlsx, follow_up_t*_q* responses)
# with the answer key and compare with cohort.csv. Aggregate evidence only; no identifiers or values are printed.
# Usage: Rscript --vanilla qc_m1_scoring.R <out_dir>   (paths from <out_dir>/records/run_config.json)
suppressPackageStartupMessages({ library(readxl); library(jsonlite) })
args <- commandArgs(TRUE)
out <- normalizePath(args[1], mustWork = TRUE)
cfg <- fromJSON(file.path(out, "records", "run_config.json"))
priv <- cfg$private_inputs
src <- file.path(cfg$project_root, "Study_2_Early_Late_Correction/data/correction_raw_data.xlsx")

hdr <- names(read_excel(src, n_max = 0))
x <- as.data.frame(read_excel(src, col_types = ifelse(hdr %in% c("ID", "Label"), "text", "guess")))
d <- read.csv(file.path(priv, "cohort.csv"), check.names = FALSE, na.strings = c("", "NA"), colClasses = c(ID = "character"))
tasks <- list(t1 = 6, t2 = 5, t3 = 6)
truth <- list(t1 = rep(FALSE, 6), t2 = rep(FALSE, 5), t3 = c(FALSE, TRUE, TRUE, TRUE, FALSE, TRUE))
as_resp <- function(v) {
  if (is.logical(v)) return(v)
  if (is.numeric(v)) return(ifelse(is.na(v), NA, v != 0))
  u <- toupper(trimws(as.character(v)))
  out <- rep(NA, length(u)); out[u %in% c("TRUE", "T", "1")] <- TRUE; out[u %in% c("FALSE", "F", "0")] <- FALSE
  bad <- !is.na(u) & u != "" & is.na(out)
  if (any(bad)) stop("unrecognised one-month response coding")
  out
}
item_cols <- unlist(lapply(names(tasks), function(t) paste0("follow_up_", t, "_q", seq_len(tasks[[t]]))))
classes <- table(vapply(x[item_cols], function(v) class(v)[1], ""))
x$ID <- trimws(x$ID); d$ID <- trimws(d$ID)
x <- x[!is.na(x$overall_accuracy_stage1) & x$overall_accuracy_stage1 < .90, ]
stopifnot(nrow(x)==175,!anyDuplicated(x$ID),all(is.finite(suppressWarnings(as.numeric(x$ID)))))
x <- x[order(as.numeric(x$ID)), ]; x$ID <- as.character(1000 + seq_len(nrow(x)))
# Source keys exist only in memory before this assignment; no lookup is emitted.
m <- match(d$ID, x$ID)
unmatched <- sum(is.na(m))
dupl <- sum(duplicated(x$ID[x$ID %in% d$ID]))
completer <- !is.na(d$completed_1month) & d$completed_1month == 1
mism <- 0; maxdev <- 0; compared <- 0; item_complete_vs_flag <- 0
for (i in seq_len(nrow(d))) {
  if (is.na(m[i])) next
  row <- x[m[i], ]
  resp <- lapply(names(tasks), function(t) as_resp(unlist(row[paste0("follow_up_", t, "_q", seq_len(tasks[[t]]))])))
  names(resp) <- names(tasks)
  has_all <- all(vapply(resp, function(r) all(!is.na(r)), TRUE))
  has_none <- all(vapply(resp, function(r) all(is.na(r)), TRUE))
  if (completer[i] && !has_all) item_complete_vs_flag <- item_complete_vs_flag + 1
  if (!completer[i] && !has_none) item_complete_vs_flag <- item_complete_vs_flag + 1
  if (!completer[i] || !has_all) next
  total <- 0
  for (k in seq_along(tasks)) {
    t <- names(tasks)[k]; n <- tasks[[t]]
    correct <- sum(resp[[t]] == truth[[t]])
    total <- total + correct
    dev <- abs(d[[paste0("follow_task", k, "_accuracy")]][i] - correct / n)
    compared <- compared + 1
    if (is.na(dev)) { mism <- mism + 1; next }
    maxdev <- max(maxdev, dev); mism <- mism + (dev > 0.0005 + 1e-9)
  }
  dev <- abs(d$follow_task0_accuracy[i] - total / 17)
  compared <- compared + 1
  if (is.na(dev)) { mism <- mism + 1; next }
  maxdev <- max(maxdev, dev); mism <- mism + (dev > 0.0005 + 1e-9)
}
ok <- unmatched == 0 && dupl == 0 && item_complete_vs_flag == 0 && mism == 0 && compared == 4 * sum(completer)
res <- data.frame(
  rule_id = "Q14b", gate = "Data contract", severity = "Critical", status = if (ok) "PASS" else "FAIL",
  execution = "completed", checked = compared, eligible = 4 * sum(completer),
  observed = sprintf("cohort IDs unmatched in item file=%d; duplicate item-file IDs=%d; item completeness vs one-month flag conflicts=%d; task/17-item mismatches=%d; max abs deviation=%.6f; response column classes=%s",
                     unmatched, dupl, item_complete_vs_flag, mism, maxdev, paste(names(classes), classes, sep = ":", collapse = ",")),
  expected = "0; 0; 0; 0; <= .0005 (3-dp rounding)",
  note = "Independent source: correction_raw_data.xlsx follow_up items + answer key vs Study_2_Full_Data-derived cohort one-month means")
dir.create(file.path(out, "records"), showWarnings = FALSE, recursive = TRUE)
write.csv(res, file.path(out, "records", "qc_m1_scoring.csv"), row.names = FALSE)
cat("Q14b", res$status, "|", res$observed, "\n")
