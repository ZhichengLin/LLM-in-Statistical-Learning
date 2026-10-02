# Long-term eligibility rule, independent R implementation of contract section `eligibility`.
# Only an exact trimmed "no" is eligible; "yes" is excluded; any other value (blank/NA/other) is excluded as unknown.
# Keyed set fingerprints use HMAC-SHA256 over sorted (byte-order) trimmed IDs joined by "\n", matching common.py.
classify_tool_use <- function(returned, tool_value) {
  v <- ifelse(is.na(tool_value), "", trimws(as.character(tool_value)))
  out <- ifelse(v == "no", "eligible", ifelse(v == "yes", "excluded_reported_use", "excluded_unknown"))
  ifelse(returned, out, "not_returned")
}

read_ids_chr <- function(path) {
  x <- read.csv(path, colClasses = "character", check.names = FALSE, na.strings = character(0))
  trimws(x$ID)
}

set_fingerprint <- function(key_raw, ids) {
  ids <- sort(trimws(as.character(ids)), method = "radix")
  as.character(openssl::sha256(paste(ids, collapse = "\n"), key = key_raw))
}

# Derive every contracted sample from the cohort file (numeric read, as used by the analysis) plus the character IDs.
derive_samples <- function(d, id_chr) {
  stopifnot(length(id_chr) == nrow(d), !anyDuplicated(id_chr),
            all(as.character(suppressWarnings(as.integer(id_chr))) == id_chr))  # numeric and character IDs are 1:1
  returned <- !is.na(d$follow2_returned) & d$follow2_returned == 1
  cls <- classify_tool_use(returned, d$follow2_tool_use)
  m1 <- !is.na(d$completed_1month) & d$completed_1month == 1
  expo <- ifelse(is.na(d$follow2_prior_exposure), "", trimws(as.character(d$follow2_prior_exposure)))
  elig <- cls == "eligible"
  list(
    class = cls,
    lt_returns = returned,
    excluded_reported_use = cls == "excluded_reported_use",
    excluded_unknown = cls == "excluded_unknown",
    eligible39 = elig,
    primary33 = elig & m1,
    additional6 = elig & !m1,
    cohort170 = !(returned & !elig),
    one_month_eligible = !(returned & !elig) & m1,
    one_month_only = !(returned & !elig) & m1 & !returned,
    neither_followup = !(returned & !elig) & !m1 & !returned,
    primary33_no_prior_exposure = elig & m1 & expo == "no",
    eligible39_no_prior_exposure = elig & expo == "no"
  )
}
