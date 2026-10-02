#!/usr/bin/env Rscript

# Ordered repository entrypoint for regenerating the manuscript and SI analyses.
# Run from any directory with: Rscript /path/to/data-code/reproduce.R all

args_all <- commandArgs(trailingOnly = FALSE)
script_arg <- grep("^--file=", args_all, value = TRUE)
if (length(script_arg) != 1L) {
  stop("Could not determine the path to reproduce.R")
}
script_path <- sub("^--file=", "", script_arg)
if (!file.exists(script_path)) {
  # Rscript on macOS can encode spaces in --file as the token "~+~".
  script_path <- gsub("~\\+~", " ", script_path)
}
repo_root <- normalizePath(dirname(script_path), mustWork = TRUE)

# R reads .Rprofile before it knows the script path. Explicitly activate this
# repository so an absolute invocation from another directory cannot silently
# use global packages or a different renv project.
active_project <- Sys.getenv("RENV_PROJECT")
active_project <- if (nzchar(active_project)) {
  normalizePath(active_project, mustWork = FALSE)
} else {
  ""
}
if (!identical(active_project, repo_root)) {
  Sys.setenv(RENV_PROJECT = repo_root)
  source(file.path(repo_root, "renv", "activate.R"), local = FALSE)
}
if (!identical(normalizePath(Sys.getenv("RENV_PROJECT"), mustWork = FALSE),
               repo_root)) {
  stop("Failed to activate the repository renv project: ", repo_root)
}

args <- commandArgs(trailingOnly = TRUE)
profile <- if (length(args) >= 1L) args[[1L]] else "all"
valid_profiles <- c("core", "all", "list")
if (!profile %in% valid_profiles) {
  stop("Unknown profile '", profile, "'. Choose one of: ",
       paste(valid_profiles, collapse = ", "))
}

task <- function(id, directory, file, type = "rmd", profiles = c("core", "all"),
                 expected = character()) {
  list(id = id, directory = directory, file = file, type = type,
       profiles = profiles, expected = expected)
}

# openxlsx 4.2.8 can emit worksheet relationship files that point to drawing
# or VML parts that are absent from the archive, even though the worksheet does
# not use those relationship IDs. Excel and LibreOffice tolerate this, but
# stricter readers reject the workbook. The functions below remove only that
# narrowly defined, unused relationship defect from generated XLSX outputs and
# then validate every internal archive relationship. Analysis inputs are never
# passed to this sanitizer.
normalize_package_target <- function(base_directory, target) {
  target <- utils::URLdecode(sub("#.*$", "", target))
  combined <- if (startsWith(target, "/")) {
    sub("^/+", "", target)
  } else if (nzchar(base_directory)) {
    paste(base_directory, target, sep = "/")
  } else {
    target
  }

  normalized <- character()
  for (component in strsplit(combined, "/", fixed = TRUE)[[1L]]) {
    if (!nzchar(component) || identical(component, ".")) {
      next
    }
    if (identical(component, "..")) {
      if (!length(normalized)) {
        stop("Invalid package-relative relationship target: ", target)
      }
      normalized <- head(normalized, -1L)
    } else {
      normalized <- c(normalized, component)
    }
  }
  paste(normalized, collapse = "/")
}

relationship_source_directory <- function(relationship_path) {
  if (identical(relationship_path, "_rels/.rels")) {
    return("")
  }
  sub("/_rels/[^/]+[.]rels$", "", relationship_path)
}

relationship_source_part <- function(relationship_path) {
  source_directory <- relationship_source_directory(relationship_path)
  source_name <- sub("[.]rels$", "", basename(relationship_path))
  if (!nzchar(source_name)) {
    return("")
  }
  if (nzchar(source_directory)) {
    paste(source_directory, source_name, sep = "/")
  } else {
    source_name
  }
}

archive_relative_path <- function(path, archive_root) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  archive_root <- normalizePath(archive_root, winslash = "/", mustWork = TRUE)
  substring(path, nchar(archive_root) + 2L)
}

validate_xlsx_relationships <- function(workbook_path) {
  workbook_path <- normalizePath(workbook_path, mustWork = TRUE)
  archive_entries <- zip::zip_list(workbook_path)$filename
  required_parts <- c("[Content_Types].xml", "_rels/.rels", "xl/workbook.xml")
  missing_required <- setdiff(required_parts, archive_entries)
  if (length(missing_required)) {
    stop("Invalid XLSX archive '", workbook_path,
         "': missing required part(s): ", paste(missing_required, collapse = ", "))
  }
  if (anyDuplicated(archive_entries)) {
    stop("Invalid XLSX archive '", workbook_path,
         "': duplicate ZIP entry names")
  }

  extraction_directory <- tempfile("xlsx-relationship-check-")
  dir.create(extraction_directory)
  on.exit(unlink(extraction_directory, recursive = TRUE, force = TRUE), add = TRUE)
  zip::unzip(workbook_path, exdir = extraction_directory)

  workbook_document <- xml2::read_xml(
    file.path(extraction_directory, "xl", "workbook.xml")
  )
  sheet_names <- xml2::xml_attr(
    xml2::xml_find_all(workbook_document, "//*[local-name()='sheet']"),
    "name"
  )
  if (!length(sheet_names) || any(is.na(sheet_names)) || any(!nzchar(sheet_names))) {
    stop("Invalid XLSX worksheet title in ", workbook_path,
         ": every worksheet must have a non-empty name")
  }
  forbidden_characters <- c("\\", "/", ":", "*", "?", "[", "]")
  has_forbidden_character <- vapply(
    sheet_names,
    function(sheet_name) {
      any(vapply(
        forbidden_characters,
        function(character) grepl(character, sheet_name, fixed = TRUE),
        logical(1L)
      ))
    },
    logical(1L)
  )
  invalid_apostrophe <- startsWith(sheet_names, "'") | endsWith(sheet_names, "'")
  if (any(nchar(sheet_names) > 31L) || any(has_forbidden_character) ||
      any(invalid_apostrophe)) {
    invalid_names <- sheet_names[
      nchar(sheet_names) > 31L | has_forbidden_character | invalid_apostrophe
    ]
    stop("Invalid XLSX worksheet title(s) in ", workbook_path, ": ",
         paste(invalid_names, collapse = ", "))
  }
  if (anyDuplicated(tolower(sheet_names))) {
    stop("Invalid XLSX archive '", workbook_path,
         "': worksheet titles are not unique (case-insensitive)")
  }

  relationship_files <- list.files(
    extraction_directory, pattern = "[.]rels$", recursive = TRUE,
    full.names = TRUE, all.files = TRUE
  )
  for (relationship_file in relationship_files) {
    relationship_path <- archive_relative_path(
      relationship_file, extraction_directory
    )
    source_directory <- relationship_source_directory(relationship_path)
    relationship_document <- xml2::read_xml(relationship_file)
    relationships <- xml2::xml_find_all(
      relationship_document, "//*[local-name()='Relationship']"
    )
    for (relationship in relationships) {
      if (identical(xml2::xml_attr(relationship, "TargetMode"), "External")) {
        next
      }
      target <- xml2::xml_attr(relationship, "Target")
      if (is.na(target) || !nzchar(target)) {
        stop("Invalid empty relationship target in ", workbook_path,
             " (", relationship_path, ")")
      }
      target_part <- normalize_package_target(source_directory, target)
      if (!target_part %in% archive_entries) {
        stop("Dangling XLSX relationship in ", workbook_path, ": ",
             relationship_path, " -> ", target_part)
      }
    }
  }
  invisible(TRUE)
}

sanitize_generated_xlsx <- function(workbook_path) {
  workbook_path <- normalizePath(workbook_path, mustWork = TRUE)
  archive_entries <- zip::zip_list(workbook_path)$filename
  extraction_directory <- tempfile("xlsx-sanitize-")
  dir.create(extraction_directory)
  on.exit(unlink(extraction_directory, recursive = TRUE, force = TRUE), add = TRUE)
  zip::unzip(workbook_path, exdir = extraction_directory)

  relationship_files <- list.files(
    extraction_directory, pattern = "[.]rels$", recursive = TRUE,
    full.names = TRUE, all.files = TRUE
  )
  removed <- 0L
  for (relationship_file in relationship_files) {
    relationship_path <- archive_relative_path(
      relationship_file, extraction_directory
    )
    source_directory <- relationship_source_directory(relationship_path)
    source_part <- relationship_source_part(relationship_path)
    source_file <- if (nzchar(source_part)) {
      file.path(extraction_directory, source_part)
    } else {
      ""
    }

    referenced_ids <- character()
    if (nzchar(source_file) && file.exists(source_file)) {
      source_document <- xml2::read_xml(source_file)
      relationship_attributes <- xml2::xml_find_all(
        source_document,
        "//@*[namespace-uri()='http://schemas.openxmlformats.org/officeDocument/2006/relationships']"
      )
      referenced_ids <- xml2::xml_text(relationship_attributes)
    }

    relationship_document <- xml2::read_xml(relationship_file)
    relationships <- xml2::xml_find_all(
      relationship_document, "//*[local-name()='Relationship']"
    )
    changed <- FALSE
    for (relationship in relationships) {
      if (identical(xml2::xml_attr(relationship, "TargetMode"), "External")) {
        next
      }
      relationship_type <- xml2::xml_attr(relationship, "Type")
      target <- xml2::xml_attr(relationship, "Target")
      relationship_id <- xml2::xml_attr(relationship, "Id")
      if (is.na(target) || is.na(relationship_type)) {
        next
      }
      target_part <- normalize_package_target(source_directory, target)
      is_missing <- !target_part %in% archive_entries
      is_unused <- is.na(relationship_id) || !relationship_id %in% referenced_ids
      is_drawing <- grepl("/(drawing|vmlDrawing)$", relationship_type)

      if (is_missing && is_drawing && is_unused) {
        xml2::xml_remove(relationship)
        removed <- removed + 1L
        changed <- TRUE
      } else if (is_missing && is_drawing && !is_unused) {
        stop("Generated workbook references a missing drawing part: ",
             workbook_path, " (", relationship_path, " -> ", target_part, ")")
      }
    }
    if (changed) {
      xml2::write_xml(relationship_document, relationship_file)
    }
  }

  if (removed) {
    archive_files <- list.files(
      extraction_directory, recursive = TRUE, full.names = FALSE,
      all.files = TRUE, include.dirs = FALSE, no.. = TRUE
    )
    replacement_path <- tempfile(
      paste0(".", basename(workbook_path), "-"),
      tmpdir = dirname(workbook_path), fileext = ".xlsx"
    )
    on.exit(unlink(replacement_path, force = TRUE), add = TRUE)
    zip::zipr(
      replacement_path, sort(archive_files), root = extraction_directory,
      include_directories = FALSE, compression_level = 9, mode = "mirror"
    )
    validate_xlsx_relationships(replacement_path)
    if (!file.copy(replacement_path, workbook_path, overwrite = TRUE)) {
      stop("Could not install sanitized XLSX output: ", workbook_path)
    }
  }

  validate_xlsx_relationships(workbook_path)
  removed
}

tasks <- list(
  task(
    "S1-objective-descriptives", "Study_1_Objective_Results",
    "Study 1 Objective Descriptive Results.Rmd",
    expected = c(
      "Study-1-Objective-Descriptive-Results.html",
      "results/Study_1_Objective_Table_S01_Panel_A.csv"
    )
  ),
  task(
    "S1-objective-models", "Study_1_Objective_Results",
    "Study 1 Objective Model Results.Rmd",
    expected = "Study-1-Objective-Model-Results.html"
  ),
  task(
    "S1-quality-descriptives", "Study_1_Subjective_Results",
    "Study 1 Subjective Decriptive Results.Rmd",
    expected = "Study-1-Subjective-Decriptive-Results.html"
  ),
  task(
    "S1-quality-models", "Study_1_Subjective_Results",
    "Study 1 Subjective Model Results.Rmd",
    expected = "Study-1-Subjective-Model-Results.html"
  ),
  task(
    "S1-material-selection", "Study_1_Subjective_Results",
    "select_study2_materials.R", type = "r",
    expected = c(
      "results/Study_2_Material_Selection_Candidates.csv",
      "results/Study_2_Selected_Materials.csv"
    )
  ),
  task(
    "S2-initial-session", "Study_2_Main_Results",
    "Study 2 Main Results.Rmd",
    expected = c(
      "Study-2-Main-Results.html",
      "results/Baseline/Baseline_Charateristics_By_Label.xlsx",
      "results/H1/H1_Performance_Comparison_LMM.xlsx",
      "results/H1/H1_S2_minus_S1_Gain_Contrasts.csv",
      "results/H1/H1_Model_Specification_Comparison.xlsx",
      "results/H1/H1_Model_Specification_Comparison.csv",
      "results/H1/H1_Performance_Comparison_LMM_Task.xlsx",
      "results/H1/H1_Performance_ItemLevel_Binomial_GLMM.xlsx",
      "results/H1/H1_Performance_Comparison_LMM_PassersOnly.xlsx",
      "results/H1/H1_Performance_Comparison_LMM_PerceivedLabel.xlsx",
      "results/H2/H2_Within_Task_Attitude_Perceptions.xlsx",
      "results/H2/H2_Attitude_Change_Immediate_Results.xlsx",
      "results/H2/Post_Survey_Experience.xlsx",
      "results/H3/H3_Within_Task_Moderation_ALL_Posthoc.xlsx",
      "results/H3/H3_Within_Task_Moderation_Summary.xlsx",
      "results/H3/H3_Attitude_Change_Immediate_Moderation_POSTHOC.xlsx",
      "results/H3/H3_Attitude_Change_Moderation_Summary.xlsx",
      "results/H3/Post_Survey_Moderation_Results.xlsx",
      "results/H3/Post_Survey_Moderation_Results_2.xlsx"
    )
  ),
  task(
    "S2-initial-demographics", "Study_2_Main_Results",
    "Study 2 Main Demographic Results.Rmd", profiles = "all",
    expected = c(
      "Study-2-Main-Demographic-Results.html",
      "results/Baseline/Demographic_Results.xlsx"
    )
  ),
  task(
    "S2-main-multiplicity", "Study_2_Main_Results",
    "additional/p-value adjudication.Rmd", profiles = "all",
    expected = c(
      "p-value-adjudication.html",
      "results/H3/H3_Attitude_Change_Moderation_Padjust.xlsx",
      "results/H3/H3_Within_Task_Moderation_Padjust.xlsx"
    )
  ),
  task(
    "S2-focal-moderation", "Study_2_Main_Results",
    "additional/report_label_dependent_moderation.R", type = "r",
    profiles = "all",
    expected = c(
      "results/H3/H3_Label_Dependent_Moderation.xlsx",
      "results/H3/H3_Label_Dependent_Moderation_Omnibus.csv",
      "results/H3/H3_Label_Dependent_Moderation_Change_Slopes.csv",
      "results/H3/H3_Label_Dependent_Moderation_Label_Contrasts.csv",
      "results/H3/H3_Label_Dependent_Moderation_Sensitivity.csv",
      "results/H3/H3_Label_Dependent_Moderation_Session_Info.txt"
    )
  ),
  task(
    "S2-followup-MAR", "Study_2_FollowUp_Results/MAR",
    "Study 2 MAR Results.Rmd",
    expected = c(
      "Study-2-MAR-Results.html",
      "results/MAR/Baseline/Followup_Interval_Descriptives.xlsx",
      "results/MAR/H1/H1_Performance_Comparison_LMM.xlsx",
      "results/MAR/H1/H1_Model_Specification_Comparison.xlsx",
      "results/MAR/H1/H1_Model_Specification_Comparison.csv",
      "results/MAR/H1/H1_Performance_Comparison_LMM_Task.xlsx",
      "results/MAR/H1/H1_Performance_ItemLevel_Binomial_GLMM.xlsx",
      "results/MAR/H1/H1_Performance_PassersOnly_LMM.xlsx",
      "results/MAR/H1/H1_Performance_PerceivedLabel_LMM.xlsx",
      "results/MAR/H2/H2_Longterm_Confidence_Change.xlsx",
      "results/MAR/H2/H2_Attitude_Change_Longterm_PF.xlsx",
      "results/MAR/H2/H2_Attitude_Change_Longterm_PPF.xlsx",
      "results/MAR/H3/H3_Attitude_Change_Longterm_Moderation_PF.xlsx",
      "results/MAR/H3/H3_Attitude_Longterm_Moderation_Summary_PF.xlsx",
      "results/MAR/H3/H3_Attitude_Change_Longterm_Moderation_PPF.xlsx",
      "results/MAR/H3/H3_Attitude_Longterm_Moderation_Summary_PPF.xlsx",
      "results/MAR/H3/H3_Performance_Confidence_Longterm_Moderation.xlsx",
      "results/MAR/H3/H3_Performance_Confidence_Longterm_Moderation_Summary.xlsx"
    )
  ),
  task(
    "S2-attrition-comparison", "Study_2_FollowUp_Results/MAR",
    "Study 2 Drop Comparison.Rmd", profiles = "all",
    expected = "Study-2-Drop-Comparison.html"
  ),
  task(
    "S2-attrition-demographics", "Study_2_FollowUp_Results/MAR",
    "Study 2 Drop Demographic Results.Rmd", profiles = "all",
    expected = c(
      "Study-2-Drop-Demographic-Results.html",
      "results/MAR/Baseline/Demographic_Results_Drop.xlsx"
    )
  ),
  task(
    "S2-followup-completers", "Study_2_FollowUp_Results/Follow-Up Completers Only",
    "Study 2 Follow-Up Only Results.Rmd",
    expected = c(
      "Study-2-Follow-Up-Only-Results.html",
      "results/Follow-Up Activity/H1/H1_Stage1_Longterm_Accuracy_Comparison_LMM.xlsx",
      "results/Follow-Up Activity/H1/H1_Performance_ItemLevel_Binomial_GLMM.xlsx",
      "results/Follow-Up Activity/H1/H1_Performance_PassersOnly_LMM.xlsx",
      "results/Follow-Up Activity/H1/H1_Performance_PerceivedLabel_LMM.xlsx",
      "results/Follow-Up Activity/H2/H2_Longterm_Confidence_Change.xlsx",
      "results/Follow-Up Activity/H2/H2_Attitude_Change_Longterm_PF.xlsx",
      "results/Follow-Up Activity/H2/H2_Attitude_Change_Longterm_PPF.xlsx",
      "results/Follow-Up Activity/H2/Continued_Use_Application.xlsx",
      "results/Follow-Up Activity/H3/H3_Attitude_Change_Longterm_Moderation_PF.xlsx",
      "results/Follow-Up Activity/H3/H3_Attitude_Longterm_Moderation_Summary_PF.xlsx",
      "results/Follow-Up Activity/H3/H3_Attitude_Change_Longterm_Moderation_PPF.xlsx",
      "results/Follow-Up Activity/H3/H3_Attitude_Longterm_Moderation_Summary_PPF.xlsx",
      "results/Follow-Up Activity/H3/H3_Performance_Confidence_Longterm_Moderation.xlsx",
      "results/Follow-Up Activity/H3/H3_Performance_Confidence_Longterm_Moderation_Summary.xlsx"
    )
  ),
  task(
    "S2-completer-demographics", "Study_2_FollowUp_Results/Follow-Up Completers Only",
    "Study 2 Follow-Up Only Demographic Results.Rmd", profiles = "all",
    expected = c(
      "Study-2-Follow-Up-Only-Demographic-Results.html",
      "results/Follow-Up Activity/Baseline/Demographic_Results_Followup_Only.xlsx"
    )
  ),
  task(
    "S2-followup-multiplicity", "Study_2_FollowUp_Results/MAR",
    "p-value adjudication.Rmd", profiles = "all",
    expected = c(
      "p-value-adjudication.html",
      "results/MAR/H3/H3_Moderation_Padjust_PF.xlsx",
      "results/MAR/H3/H3_Moderation_Padjust_PPF.xlsx",
      "results/MAR/H3/H3_Performance_Confidence_Moderation_Padjust.xlsx",
      "../Follow-Up Completers Only/results/Follow-Up Activity/H3/H3_Moderation_Padjust_PF.xlsx",
      "../Follow-Up Completers Only/results/Follow-Up Activity/H3/H3_Moderation_Padjust_PPF.xlsx",
      "../Follow-Up Completers Only/results/Follow-Up Activity/H3/H3_Performance_Confidence_Moderation_Padjust.xlsx"
    )
  ),
  task(
    "S2-correction-timing", "Study_2_Early_Late_Correction",
    "Comparison.Rmd",
    expected = c(
      "Comparison.html",
      "../Figures/data/Correction_Data.csv",
      "../Figures/data/Correction_Timing_Contrasts.csv"
    )
  ),
  task(
    "Figure-6-completer-tests", "Figures", "reproduce_completer_tests.R", type = "rscript",
    expected = "data/figure6_completer_tests.csv"
  ),
  task(
    "S2-longterm", "Study_2_LongTerm_Results", "run.R", type = "nested_r",
    expected = c("results/paired_contrasts.csv", "results/sample_flow.csv",
                 "results/fullcohort_gls_contrasts.csv", "results/fullcohort_diagnostics.csv",
                 "records/verification.json", "records/QC_REPORT.md",
                 "tables/Supplementary_Tables_S22-S24_no_tools.md")
  ),
  task(
    "Figure-3", "Figures", "Figure_Study1_1.Rmd",
    expected = c("Figure_Study1_1.html", "figure/Figure_Study1_1.pdf",
                 "figure/Figure_Study1_1.png", "figure/Figure_Study1_1.svg")
  ),
  task(
    "Figure-4", "Figures", "Figure_Study1_2.Rmd",
    expected = c("Figure_Study1_2.html", "figure/Figure_Study1_2.pdf",
                 "figure/Figure_Study1_2.png", "figure/Figure_Study1_2.svg")
  ),
  task(
    "Figure-5", "Figures", "Figure_Study2_1.Rmd", type = "nested_rmd",
    expected = c("Figure_Study2_1.html", "figure/Figure_Study2_1.pdf",
                 "figure/Figure_Study2_1.png", "figure/Figure_Study2_1.svg")
  ),
  task(
    "Figure-6", "Figures", "Figure_Study2_2.Rmd", type = "nested_rmd",
    expected = c("Figure_Study2_2.html", "figure/Figure_Study2_2.pdf",
                 "figure/Figure_Study2_2.png", "figure/Figure_Study2_2.svg")
  ),
  task(
    "Figure-S1", "Figures", "Figure_S01_AI_Related_Measures.Rmd",
    expected = c(
      "Figure_S01_AI_Related_Measures.html",
      "figure/Figure_S01_AI_Related_Measures.pdf",
      "figure/Figure_S01_AI_Related_Measures.png",
      "figure/Figure_S01_AI_Related_Measures.svg"
    )
  )
)

if (profile == "list") {
  for (x in tasks) {
    cat(sprintf("%-30s  %s/%s  [%s]\n", x$id, x$directory, x$file,
                paste(x$profiles, collapse = ",")))
  }
  quit(status = 0L)
}

if (!requireNamespace("rmarkdown", quietly = TRUE)) {
  stop("Package 'rmarkdown' is not installed. From the repository root run: ",
       "Rscript -e 'renv::restore(prompt = FALSE)'")
}
if (!requireNamespace("callr", quietly = TRUE)) {
  stop("Package 'callr' is required to isolate each task. From the repository root run: ",
       "Rscript -e 'renv::restore(prompt = FALSE)'")
}
if (!requireNamespace("xml2", quietly = TRUE) ||
    !requireNamespace("zip", quietly = TRUE)) {
  stop("Packages 'xml2' and 'zip' are required to validate generated XLSX files. ",
       "From the repository root run: ",
       "Rscript -e 'renv::restore(prompt = FALSE)'")
}
if (!requireNamespace("digest", quietly = TRUE)) {
  stop("Package 'digest' is required to verify static figure assets. ",
       "From the repository root run: ",
       "Rscript -e 'renv::restore(prompt = FALSE)'")
}
if (!rmarkdown::pandoc_available()) {
  stop("Pandoc is required to render the R Markdown notebooks but was not found")
}

static_asset_hashes <- c(
  "Figures/figure/Figure_01_Study1_Workflow.pdf" =
    "6f5365c931ecb27460d78b3cb1b6dcc4d5aafce9354d44d95185d1db2a99a713",
  "Figures/figure/Figure_01_Study1_Workflow.png" =
    "4b586ab1245d60d4fccbad94b39bfc320689b8735b721ce7ef503d8a6835a490",
  "Figures/figure/Figure_02_Study2_Participant_Flow_and_Procedure.pdf" =
    "e53d33cb04620a287feb361e91b9a69698be12999cf4e495b33505bd7e20dd45"
)
for (relative_path in names(static_asset_hashes)) {
  asset_path <- file.path(repo_root, relative_path)
  if (!file.exists(asset_path)) {
    stop("Missing static figure asset: ", relative_path)
  }
  actual_hash <- digest::digest(file = asset_path, algo = "sha256",
                                serialize = FALSE)
  if (!identical(actual_hash, unname(static_asset_hashes[[relative_path]]))) {
    stop("Static figure asset hash mismatch: ", relative_path,
         "\nExpected: ", static_asset_hashes[[relative_path]],
         "\nActual:   ", actual_hash)
  }
}

selected <- Filter(function(x) profile %in% x$profiles, tasks)
cat("Repository:", repo_root, "\n")
cat("Profile:", profile, "\n")
cat("R:", R.version.string, "\n")
cat("Static assets:", length(static_asset_hashes), "verified\n")
cat("Tasks:", length(selected), "\n\n")

run_task <- function(x) {
  task_dir <- file.path(repo_root, x$directory)
  source_path <- file.path(task_dir, x$file)
  if (!file.exists(source_path)) {
    stop("Missing entrypoint: ", source_path)
  }

  # A cached knitr chunk can complete successfully without rewriting the
  # workbook that it originally created. Remove only ignored generated cache
  # directories before an R Markdown task so the freshness checks remain valid
  # on both a clean clone and a repeated local run.
  if (x$type %in% c("rmd", "nested_rmd")) {
    cache_dirs <- list.dirs(task_dir, recursive = TRUE, full.names = TRUE)
    cache_dirs <- cache_dirs[grepl("_cache$", basename(cache_dirs))]
    if (length(cache_dirs)) {
      cat("    clearing generated knitr cache(s):\n")
      cat(paste0("      ", cache_dirs, "\n"))
      unlink(cache_dirs, recursive = TRUE, force = TRUE)
      remaining_cache <- cache_dirs[dir.exists(cache_dirs)]
      if (length(remaining_cache)) {
        stop("Could not remove generated knitr cache(s): ",
             paste(remaining_cache, collapse = ", "))
      }
    }
  }

  expected_paths <- file.path(task_dir, x$expected)
  before_exists <- file.exists(expected_paths)
  before_mtime <- file.info(expected_paths)$mtime

  cat("==>", x$id, "\n")
  cat("    working directory:", task_dir, "\n")
  cat("    source:", x$file, "\n")

  # Each notebook/script runs in a fresh R process. This prevents packages,
  # options, contrasts, and other session state loaded by an earlier task from
  # changing a later task (for example, car::recode masking dplyr::recode).
  if (x$type %in% c("rscript", "nested_r", "nested_rmd")) {
    # The extension and current Figures 5–6 use their separately pinned
    # September 2026 environment in a fresh native Rscript process.
    nested <- file.path(repo_root, "Study_2_LongTerm_Results")
    env_names <- c("RENV_PROJECT", "R_LIBS", "R_LIBS_USER", "R_LIBS_SITE",
                   "R_PROFILE_USER", "RENV_PATHS_LIBRARY")
    prior <- Sys.getenv(env_names, unset = NA_character_)
    restore_environment <- function() {
      Sys.unsetenv(env_names)
      present <- !is.na(prior)
      if (any(present)) do.call(Sys.setenv, as.list(prior[present]))
    }
    on.exit(restore_environment(), add = TRUE)
    Sys.unsetenv(env_names)
    if (!identical(x$type, "rscript")) Sys.setenv(RENV_PROJECT = nested)
    child_args <- if (x$type %in% c("rscript", "nested_r")) {
      c("--vanilla", source_path)
    } else {
      c("--vanilla", file.path(nested, "render_figure.R"), source_path)
    }
    status <- system2(file.path(R.home("bin"), "Rscript"),
                      vapply(child_args, shQuote, ""))
    restore_environment()
    if (status != 0L) stop("Nested task failed: ", x$id)
  } else {
  callr::r(
    function(task_dir, file, type, repo_root) {
      Sys.setenv(RENV_PROJECT = repo_root)
      source(file.path(repo_root, "renv", "activate.R"), local = FALSE)
      setwd(task_dir)
      if (identical(type, "rmd")) {
        rmarkdown::render(
          input = file,
          envir = new.env(parent = globalenv()),
          clean = TRUE,
          quiet = FALSE
        )
      } else {
        sys.source(file, envir = new.env(parent = globalenv()))
      }
      invisible(TRUE)
    },
    args = list(
      task_dir = task_dir,
      file = x$file,
      type = x$type,
      repo_root = repo_root
    ),
    libpath = .libPaths(),
    stdout = "|",
    stderr = "|",
    show = TRUE,
    spinner = FALSE,
    user_profile = FALSE,
    env = c(RENV_PROJECT = repo_root)
  )
  }

  missing <- x$expected[!file.exists(expected_paths)]
  if (length(missing)) {
    stop("Task '", x$id, "' completed without expected output(s): ",
         paste(missing, collapse = ", "))
  }

  after_mtime <- file.info(expected_paths)$mtime
  refreshed <- !before_exists | is.na(before_mtime) | after_mtime > before_mtime
  if (any(!refreshed)) {
    stale <- x$expected[!refreshed]
    stop("Task '", x$id, "' did not refresh expected output(s): ",
         paste(stale, collapse = ", "),
         ". Re-run in a clean clone or remove the relevant generated cache.")
  }

  generated_xlsx <- expected_paths[
    grepl("[.]xlsx$", expected_paths, ignore.case = TRUE)
  ]
  for (workbook_path in generated_xlsx) {
    removed_relationships <- sanitize_generated_xlsx(workbook_path)
    if (removed_relationships) {
      cat("    sanitized", removed_relationships,
          "unused dangling XLSX relationship(s):",
          basename(workbook_path), "\n")
    }
  }
  cat("<==", x$id, "completed\n\n")
}

for (x in selected) {
  run_task(x)
}

cat("All", length(selected), "tasks in profile '", profile,
    "' completed and produced their expected files.\n", sep = " ")
