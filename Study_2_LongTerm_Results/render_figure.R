# Render current Figures 5–6 in the separately pinned extension environment.
args <- commandArgs(TRUE)
if (length(args) != 1L) stop("Provide one figure Rmd path")
file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script <- gsub("~\\+~", " ", sub("^--file=", "", file_arg))
pkg <- dirname(normalizePath(script, mustWork = TRUE))
Sys.setenv(RENV_PROJECT = pkg)
source(file.path(pkg, "renv", "activate.R"))
lock <- jsonlite::fromJSON(file.path(pkg, "renv.lock"), simplifyVector = FALSE)
stopifnot(getRversion() == package_version(lock$R$Version))
for (nm in names(lock$Packages)) {
  if (!requireNamespace(nm, quietly = TRUE) ||
      packageDescription(nm)$Version != lock$Packages[[nm]]$Version)
    stop("Restore the nested lock before rendering Figures 5–6: ", nm)
}
figure <- normalizePath(args[[1L]], mustWork = TRUE)
setwd(dirname(figure))
rmarkdown::render(basename(figure), envir = new.env(parent = globalenv()),
                  clean = TRUE, quiet = FALSE)
