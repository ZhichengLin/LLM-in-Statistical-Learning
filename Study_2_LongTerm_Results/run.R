# Self-contained numerical reproduction of the exploratory 14-month extension.
# Run from any working directory; no packages are installed by this entry point.
args <- commandArgs(TRUE)
file_arg <- grep("^--file=",commandArgs(FALSE),value=TRUE)
if(length(file_arg)!=1) stop("Invoke this entry point with Rscript, in a fresh R process")
pkg <- dirname(normalizePath(gsub("~+~"," ",sub("^--file=","",file_arg),fixed=TRUE)))
repo <- dirname(pkg)
if(!file.exists(file.path(pkg,"renv","activate.R"))) stop("Nested pinned environment missing; follow the repository setup instructions")
Sys.setenv(RENV_PROJECT=pkg)
source(file.path(pkg,"renv","activate.R"))
suppressPackageStartupMessages({library(jsonlite);library(openssl)})
lock <- jsonlite::fromJSON(file.path(pkg,"renv.lock"),simplifyVector=FALSE)
if(getRversion()!=package_version(lock$R$Version)) stop("R version differs from the pinned extension environment")
versions <- vapply(names(lock$Packages),function(nm) if(requireNamespace(nm,quietly=TRUE)) packageDescription(nm)$Version else "MISSING","")
expected <- vapply(lock$Packages,function(x)x$Version,"")
if(!identical(unname(versions),unname(expected))) stop("Locked package versions unavailable or different; restore in an authorized environment first")
# Child Rscript --vanilla calls use the same pinned library; they do not activate another project.
Sys.setenv(R_LIBS_USER=.libPaths()[1],R_LIBS=.libPaths()[1],PYTHONDONTWRITEBYTECODE="1")
python <- Sys.getenv("LONGTERM_PYTHON",unset=Sys.which("python3"))
if(!nzchar(python)) stop("Python 3 is required (standard library only)")
qc_only <- FALSE; out <- pkg; i <- 1L
while(i<=length(args)) {
  if(args[i]=="--qc-only") {qc_only<-TRUE;i<-i+1L}
  else if(args[i]=="--out") {if(i==length(args))stop("--out needs a directory");out<-args[i+1L];i<-i+2L}
  else stop("Supported arguments: --qc-only, --out DIR")
}
dir.create(out,showWarnings=FALSE,recursive=TRUE);out<-normalizePath(out)
for(p in c("records","results","tables","private"))dir.create(file.path(out,p),showWarnings=FALSE,recursive=TRUE)
Sys.chmod(file.path(out,"private"),"0700")
# An old ready record never survives a new validation attempt.
unlink(file.path(out,"records","ready_binding.json"))
config<-list(project_root=repo,private_inputs=file.path(pkg,"data"),fingerprint_key=file.path(out,"private","fingerprint_key.bin"))
jsonlite::write_json(config,file.path(out,"records","run_config.json"),auto_unbox=TRUE,pretty=TRUE)
writeLines(capture.output(sessionInfo()),file.path(out,"records","environment_sessionInfo.txt"))
code<-file.path(pkg,"code")
run<-function(program,arguments){status<-system2(program,vapply(arguments,shQuote,""));if(status!=0)stop("Pipeline step failed; downstream work stopped")}
py<-function(name)run(python,c(file.path(code,name),"--out",out))
rs<-function(name)run(file.path(R.home("bin"),"Rscript"),c("--vanilla",file.path(code,name),out))
jsonlite::write_json(list(verdict="NOT READY",scope="Current validation attempt pending"),file.path(out,"records","qc_summary.json"),auto_unbox=TRUE,pretty=TRUE)
jsonlite::write_json(list(status="NOT RUN",numerical_status="NOT RUN",failed_model_diagnostics=list()),file.path(out,"records","verification.json"),auto_unbox=TRUE,pretty=TRUE)
py("build_qc_report.py")
py("verify_inputs.py")
rs("qc_m1_scoring.R")
py("qc_checks.py")
py("test_qc_fixtures.py")
py("test_entry_guard.py")
py("bind_ready.py")
py("build_qc_report.py")
if(qc_only){cat("Public data QC finished; no inferential models run.\n");quit(status=0)}
rs("analysis.R")
rs("df_seed_sensitivity.R")
py("auxiliary_counts.py")
rs("audit_fit_membership.R")
rs("verify_models.R")
py("verify_outputs.py")
py("build_supplementary_tables.py")
py("build_qc_report.py")
cat("Long-term numerical reproduction complete. Check records/verification.json for retained diagnostic qualifications.\n")
