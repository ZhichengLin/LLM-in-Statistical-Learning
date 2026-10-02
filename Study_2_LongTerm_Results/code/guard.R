# Public-data guard: every fitting/figure entry verifies the exact consumed snapshot and completed gate inventories.
# This is a reproducibility barrier, not cryptographic authorization or validation of historical study execution.
bound_code_files <- function(code_dir, extensions) {
  f <- list.files(code_dir, recursive=TRUE, all.files=FALSE)
  keep <- tolower(tools::file_ext(f)) %in% tolower(sub("^\\.","",extensions)) & !grepl("(^|/)(__pycache__|\\.)",f)
  f <- f[keep]
  if (file.exists(file.path(code_dir,"../run.R"))) f <- c(f,"../run.R")
  sort(f,method="radix")
}
entry_guard <- function(out,cfg,code_dir,contract_path,model_environment=FALSE) {
  sha <- function(p) paste(unclass(openssl::sha256(file(p))),collapse="")
  pkg <- dirname(code_dir); rec <- file.path(out,"records"); fail <- character()
  load <- function(p) if(file.exists(p)) jsonlite::fromJSON(p,simplifyVector=FALSE) else list()
  req <- load(file.path(code_dir,"gate_requirements.json")); b <- load(file.path(rec,"ready_binding.json"))
  if (!length(req) || !identical(b$verdict,"READY")) stop("GUARD REJECTED: required gate inventory or READY binding missing",call.=FALSE)
  if (!identical(load(file.path(rec,"qc_summary.json"))$verdict,"READY")) fail <- c(fail,"current QC is not READY")
  manifest_path <- file.path(pkg,"input_manifest.json"); manifest <- load(manifest_path)
  if (!file.exists(manifest_path) || !identical(sha(manifest_path),b$manifest_sha256)) fail <- c(fail,"manifest changed or missing")
  iv <- load(file.path(rec,"input_verification.json")); vf <- iv$files
  if (!isTRUE(iv$all_required_match) || !identical(iv$manifest_sha256,b$manifest_sha256)) fail <- c(fail,"input verification failed or stale")
  if (!length(manifest$files) || !setequal(names(manifest$files),names(b$inputs))) fail <- c(fail,"input inventory differs")
  for (rel in names(manifest$files)) {
    p <- file.path(pkg,rel); cur <- if(file.exists(p)) sha(p) else NA_character_
    v <- Filter(function(x) identical(x$path,rel) && identical(x$role,"required"),vf)
    if (is.na(cur) || !identical(cur,manifest$files[[rel]]$sha256) || !identical(cur,b$inputs[[rel]]) ||
        length(v)!=1 || !identical(v[[1]]$expected,cur) || !identical(v[[1]]$observed,cur) || !isTRUE(v[[1]]$match))
      fail <- c(fail,paste("consumed input changed or unverified:",rel))
  }
  lock_path <- file.path(pkg,"renv.lock")
  if (!file.exists(lock_path) || !identical(sha(lock_path),b$model_lock_sha256)) fail <- c(fail,"model environment lock missing or changed")
  if (model_environment && file.exists(lock_path)) {
    locked <- load(lock_path)
    if (getRversion()!=package_version(locked$R$Version)) fail <- c(fail,"model R version differs from lock")
    for (nm in names(locked$Packages)) {
      v <- tryCatch(utils::packageDescription(nm)$Version,error=function(e)NULL)
      if (!identical(v,locked$Packages[[nm]]$Version)) fail <- c(fail,paste("model package version differs:",nm))
    }
  }
  if (!file.exists(contract_path) || !identical(sha(contract_path),b$contract_sha256) ||
      !identical(load(file.path(rec,"contract_freeze.json"))$sha256,b$contract_sha256)) fail <- c(fail,"contract missing or changed")
  if (!identical(normalizePath(cfg$private_inputs,mustWork=FALSE),normalizePath(file.path(pkg,"data"),mustWork=FALSE))) fail <- c(fail,"configuration redirects deposited data")
  files <- bound_code_files(code_dir,unlist(req$bound_code_extensions))
  if (!identical(files,sort(names(b$code),method="radix"))) fail <- c(fail,"code file inventory changed")
  for (rel in intersect(files,names(b$code))) if (!identical(sha(file.path(code_dir,rel)),b$code[[rel]])) fail <- c(fail,paste("code changed:",rel))
  if (!setequal(names(b$records),unlist(req$required_records))) fail <- c(fail,"bound record inventory incomplete")
  for (rel in names(b$records)) if (!file.exists(file.path(out,rel)) || !identical(sha(file.path(out,rel)),b$records[[rel]])) fail <- c(fail,paste("QC record changed:",rel))
  qpath <- file.path(rec,"qc_checks.csv")
  q <- if(file.exists(qpath)) read.csv(qpath,colClasses="character") else data.frame()
  wanted <- unlist(req$required_qc_rules)
  if (!nrow(q) || anyDuplicated(q$rule_id) || !all(wanted %in% q$rule_id)) fail <- c(fail,"QC rule inventory incomplete")
  else if (!all(q$status[q$rule_id %in% wanted]=="PASS" & q$execution[q$rule_id %in% wanted]=="completed")) fail <- c(fail,"required QC not completed PASS")
  for (spec in list(c("qc_fixture_results.csv","required_fixture_cases"),c("guard_tests.csv","required_guard_cases"))) {
    path <- file.path(rec,spec[1]); x <- if(file.exists(path)) read.csv(path,colClasses="character") else data.frame()
    ids <- if(nrow(x)) sub(" .*$","",x$case) else character()
    if (!length(ids) || anyDuplicated(ids) || !all(unlist(req[[spec[2]]]) %in% ids) || !all(x$result=="ok")) fail <- c(fail,paste("fixture/guard inventory incomplete:",spec[1]))
  }
  fpf <- file.path(out,"private","qc_fingerprints.json")
  if (!file.exists(fpf) || !file.exists(cfg$fingerprint_key)) fail <- c(fail,"sample fingerprints or key missing")
  else if (!length(fail)) {
    qfp <- jsonlite::fromJSON(fpf); key <- readBin(cfg$fingerprint_key,"raw",64)
    cp <- file.path(cfg$private_inputs,"cohort.csv"); d <- read.csv(cp,check.names=FALSE,na.strings=c("","NA")); idc <- read_ids_chr(cp)
    s <- derive_samples(d,idc)
    for (nm in setdiff(names(s),c("class","lt_returns")))
      if (is.null(qfp[[nm]]) || set_fingerprint(key,idc[s[[nm]]])!=qfp[[nm]]$fingerprint || sum(s[[nm]])!=qfp[[nm]]$n) fail <- c(fail,paste("independent sample fingerprint differs:",nm))
  }
  if(length(fail)) stop(paste("GUARD REJECTED:",paste(unique(fail),collapse="; ")),call.=FALSE)
  invisible(TRUE)
}
