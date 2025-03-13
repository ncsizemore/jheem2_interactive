#!/usr/bin/env Rscript
# deploy_shinyapps.R - Script to prepare and deploy to shinyapps.io

# Load required packages
library(rsconnect)
library(remotes)
library(yaml)

# Load deployment modules
source("deployment/prepare_cache_manager.R")

# Application configuration
APP_NAME <- "ryan-white" # The name of the app for deployment
ACCOUNT_NAME <- "jheem" # The shinyapps.io account name
SOURCE_BRANCH <- "dev" # The source branch for jheem2
DEPLOYMENT_BRANCH <- "ryan-white-deployment" # The deployment branch name

# ---------- STEP 1: Prepare jheem2 deployment branch ----------

cat("=== Preparing jheem2 deployment branch ===\n")

# File to store the last processed SHA
last_dev_sha_file <- ".last_dev_sha"

# Function to create/update deployment branch
prepare_deployment_branch <- function(force_update = FALSE) {
  # Get current dev branch SHA
  current_dev_sha <- system(paste0("git ls-remote https://github.com/tfojo1/jheem2.git ", SOURCE_BRANCH, " | cut -f1"), intern = TRUE)

  # Check if we need to update the deployment branch
  if (!force_update && file.exists(last_dev_sha_file)) {
    last_dev_sha <- readLines(last_dev_sha_file)
    if (current_dev_sha == last_dev_sha) {
      cat("Dev branch hasn't changed since last deployment, skipping branch creation\n")
      return(FALSE) # No update needed
    }
  }

  cat("Changes detected in dev branch, updating deployment branch...\n")

  # Create a temporary directory for cloning the repo
  temp_dir <- file.path(tempdir(), "jheem2_deploy")
  if (dir.exists(temp_dir)) {
    unlink(temp_dir, recursive = TRUE)
  }
  dir.create(temp_dir, recursive = TRUE)

  # Execute git commands
  tryCatch(
    {
      # Clone the repository to the temp directory
      system(paste0("git clone https://github.com/tfojo1/jheem2.git ", temp_dir))

      # Navigate to the temp directory
      current_dir <- getwd()
      setwd(temp_dir)

      # Checkout source branch and pull latest
      system(paste0("git checkout ", SOURCE_BRANCH))
      system(paste0("git pull origin ", SOURCE_BRANCH))

      # Create new deployment branch
      system(paste0("git checkout -b ", DEPLOYMENT_BRANCH))

      # Make deployment-specific modifications
      # 1. Remove .o files
      system("find . -name '*.o' -type f -delete")

      # 2. Set custom makevars from provided content
      makevars_content <- "# src/Makevars
CFLAGS = -O0
CXXFLAGS = -O0
PKG_CXXFLAGS = -I${R_HOME}/include
PKG_LIBS = -L${R_HOME}/lib -lR ${LAPACK_LIBS} ${BLAS_LIBS} ${FLIBS}"
      writeLines(makevars_content, "src/Makevars")

      # Commit and push changes
      system("git add -A")
      system(paste0("git commit -m 'Prepare ", DEPLOYMENT_BRANCH, " from ", SOURCE_BRANCH, " branch'"))
      system(paste0("git push origin ", DEPLOYMENT_BRANCH, " --force"))

      # Return to original directory
      setwd(current_dir)

      # Clean up temp directory
      unlink(temp_dir, recursive = TRUE)

      # Save the SHA we just processed
      writeLines(current_dev_sha, last_dev_sha_file)

      cat("Deployment branch created/updated successfully!\n")
      return(TRUE) # Branch was updated
    },
    error = function(e) {
      # Make sure we return to original directory even on error
      if (getwd() != current_dir) {
        setwd(current_dir)
      }

      # Clean up temp directory
      unlink(temp_dir, recursive = TRUE)

      stop(paste("Error preparing deployment branch:", e$message))
    }
  )
}

# Run the function to prepare deployment branch - can pass TRUE to force update
branch_updated <- prepare_deployment_branch(force_update = FALSE)

# ---------- STEP 2: Install jheem2 from deployment branch ----------

cat("\n=== Installing jheem2 from deployment branch ===\n")

# Record current package info to restore later if needed
has_jheem2 <- "jheem2" %in% installed.packages()[, "Package"]
if (has_jheem2) {
  current_jheem2 <- packageDescription("jheem2")
}

# Remove current jheem2 if installed
if (has_jheem2) {
  remove.packages("jheem2")
}

# Install from deployment branch
install_github(paste0("tfojo1/jheem2@", DEPLOYMENT_BRANCH), force = TRUE)

# ---------- STEP 3: Prepare external dependencies ----------

cat("\n=== Preparing external dependencies ===\n")

# Get model specification file from config
config_file <- "src/ui/config/base.yaml"
if (!file.exists(config_file)) {
  stop("ERROR: Config file not found at ", config_file, ". Cannot proceed with deployment.")
}

config <- yaml::read_yaml(config_file)

# Check for model specification settings
if (is.null(config$model_specification)) {
  stop("ERROR: 'model_specification' section not defined in config. Check ", config_file)
}

if (is.null(config$model_specification$main_file)) {
  stop("ERROR: 'main_file' not defined in model_specification section. Check ", config_file)
}

# For deployment, we'll use the development path (we're preparing files for deployment)
dev_path <- config$model_specification$development_path
if (is.null(dev_path)) {
  stop("ERROR: 'development_path' not defined in model_specification section. Check ", config_file)
}

# Construct the full path to the model specification file
model_spec_file <- file.path(dev_path, config$model_specification$main_file)

# If path is relative and doesn't start with "../", add that prefix
if (!startsWith(model_spec_file, "/") && !startsWith(model_spec_file, "../")) {
  model_spec_file <- file.path("..", model_spec_file)
}

cat("Using model specification file:", model_spec_file, "\n")

# Function to copy a directory and all its contents
copy_directory_recursive <- function(source_dir, target_dir) {
  if (!dir.exists(source_dir)) {
    cat("WARNING: Source directory does not exist:", source_dir, "\n")
    return()
  }

  # Create target directory if it doesn't exist
  if (!dir.exists(target_dir)) {
    dir.create(target_dir, recursive = TRUE)
  }

  # Get all files in source directory
  files <- list.files(source_dir, full.names = TRUE)

  # Copy each file or directory
  for (file_path in files) {
    file_name <- basename(file_path)
    target_path <- file.path(target_dir, file_name)

    if (dir.exists(file_path)) {
      # If it's a directory, recursively copy it
      copy_directory_recursive(file_path, target_path)
    } else {
      # If it's a file, copy it
      file.copy(file_path, target_path, overwrite = TRUE)
      cat("Copied:", target_path, "\n")
    }
  }
}

# Create enhanced function to discover dependencies recursively
# This version detects both source() calls and data file references (read.csv, etc.)
discover_dependencies <- function(file_path, base_dir = "../jheem_analyses/") {
  if (!file.exists(file_path)) {
    warning(paste("File not found:", file_path))
    return(character(0))
  }

  content <- readLines(file_path, warn = FALSE)

  # Filter out commented lines (lines that have '#' before the function calls)
  # This keeps only uncommented calls
  content_filtered <- content[!grepl("^\\s*#", content)]

  # Get all dependencies
  all_deps <- c(file_path)

  # ----- First, find source() calls (as before) -----
  source_regex <- "source\\(['\"]\\.\\./(jheem_analyses/.*?)['\"]\\)"
  source_matches <- regmatches(content_filtered, gregexpr(source_regex, content_filtered, perl = TRUE))
  source_matches <- unlist(source_matches)

  # Extract the paths from source calls
  source_paths <- gsub(source_regex, "\\1", source_matches, perl = TRUE)
  source_full_paths <- file.path(dirname(base_dir), source_paths)

  # ----- Now, find read.csv and similar calls -----
  # Define patterns for common file reading functions
  data_file_patterns <- c(
    # read.csv patterns
    "read\\.csv\\(['\"]\\.\\./(jheem_analyses/.*?)['\"]",
    "read\\.csv\\(file\\s*=\\s*['\"]\\.\\./(jheem_analyses/.*?)['\"]",

    # read.table patterns
    "read\\.table\\(['\"]\\.\\./(jheem_analyses/.*?)['\"]",
    "read\\.table\\(file\\s*=\\s*['\"]\\.\\./(jheem_analyses/.*?)['\"]",

    # fread patterns
    "fread\\(['\"]\\.\\./(jheem_analyses/.*?)['\"]",
    "fread\\(input\\s*=\\s*['\"]\\.\\./(jheem_analyses/.*?)['\"]",

    # readRDS patterns
    "readRDS\\(['\"]\\.\\./(jheem_analyses/.*?)['\"]",
    "readRDS\\(file\\s*=\\s*['\"]\\.\\./(jheem_analyses/.*?)['\"]",

    # load patterns
    "load\\(['\"]\\.\\./(jheem_analyses/.*?)['\"]",
    "load\\(file\\s*=\\s*['\"]\\.\\./(jheem_analyses/.*?)['\"]",

    # read_excel patterns
    "read_excel\\(['\"]\\.\\./(jheem_analyses/.*?)['\"]",
    "read_excel\\(path\\s*=\\s*['\"]\\.\\./(jheem_analyses/.*?)['\"]",

    # file.path patterns (often used to construct file paths)
    "file\\.path\\(['\"]\\.\\./(jheem_analyses/.*?)['\"]"
  )

  # Get all data file paths
  data_file_paths <- character(0)

  for (pattern in data_file_patterns) {
    matches <- regmatches(content_filtered, gregexpr(pattern, content_filtered, perl = TRUE))
    matches <- unlist(matches)

    if (length(matches) > 0) {
      paths <- gsub(pattern, "\\1", matches, perl = TRUE)
      data_file_paths <- c(data_file_paths, paths)
    }
  }

  # Convert to full paths
  data_file_full_paths <- file.path(dirname(base_dir), unique(data_file_paths))

  # Combine all dependencies
  all_file_paths <- c(source_full_paths, data_file_full_paths)

  # Recursively find dependencies of source files
  # (We don't recursively process data files since they don't contain code)
  for (dep in source_full_paths) {
    all_deps <- c(all_deps, discover_dependencies(dep, base_dir))
  }

  # Add data files to dependencies
  all_deps <- c(all_deps, data_file_full_paths)

  # Also look for file path construction in variables
  file_path_vars <- grep("\\s*<-\\s*file\\.path\\(['\"]\\.\\./(jheem_analyses/.*?)['\"]", content_filtered, value = TRUE)
  if (length(file_path_vars) > 0) {
    cat("Found potential file path variables. You may need to manually add these data files.\n")
    cat("Variable assignments:\n")
    for (var in file_path_vars) {
      cat("  ", var, "\n")
    }
  }

  # Return unique paths
  return(unique(all_deps))
}

# Function to copy data files identified by discover_dependencies
copy_data_files <- function(data_file_paths, base_dir = "../jheem_analyses/") {
  cat("\n=== Copying data files ===\n")

  # Process each data file
  for (file_path in data_file_paths) {
    # Skip non-data files (which should be handled by the source file copy process)
    if (!grepl("\\.(csv|txt|rds|rdata|xlsx|xls)$", tolower(file_path), ignore.case = TRUE)) {
      next
    }

    # Get relative path
    if (startsWith(file_path, base_dir) || startsWith(file_path, file.path("..", "jheem_analyses"))) {
      rel_path <- sub("^\\.\\./(jheem_analyses/.*?)$", "\\1", file_path)
    } else {
      # For files that don't match the expected pattern, skip with a warning
      cat("WARNING: Skipping file with unexpected path format:", file_path, "\n")
      next
    }

    # Set target path
    target_path <- file.path("external", rel_path)

    # Create parent directory if needed
    target_dir <- dirname(target_path)
    if (!dir.exists(target_dir)) {
      dir.create(target_dir, recursive = TRUE)
    }

    # Copy the file if it exists
    if (file.exists(file_path)) {
      # Direct copy for data files (no content modification needed)
      file.copy(file_path, target_path, overwrite = TRUE)
      cat("Copied data file:", target_path, "\n")
    } else {
      cat("WARNING: Data file not found:", file_path, "\n")
    }
  }

  # Also copy the entire data_files directory to be safe
  source_data_dir <- file.path(dirname(base_dir), "jheem_analyses/data_files")
  target_data_dir <- "external/jheem_analyses/data_files"

  if (dir.exists(source_data_dir)) {
    cat("Copying entire data_files directory to ensure all data dependencies are included...\n")
    copy_directory_recursive(source_data_dir, target_data_dir)
  } else {
    cat("WARNING: data_files directory not found at", source_data_dir, "\n")
  }
}

# Discover all dependencies
all_dependencies <- discover_dependencies(model_spec_file)
cat("Discovered", length(all_dependencies), "dependency files\n")

# Ensure external directory exists
if (!dir.exists("external/jheem_analyses")) {
  dir.create("external/jheem_analyses", recursive = TRUE)
}

# Copy and modify each dependency
for (source_path in all_dependencies) {
  # Skip data files - they'll be handled separately
  if (grepl("\\.(csv|txt|rds|rdata|xlsx|xls)$", tolower(source_path), ignore.case = TRUE)) {
    next
  }

  rel_path <- sub("^\\.\\./(jheem_analyses/.*?)$", "\\1", source_path)
  target_path <- file.path("external", rel_path)

  # Create parent directory if needed
  target_dir <- dirname(target_path)
  if (!dir.exists(target_dir)) {
    dir.create(target_dir, recursive = TRUE)
  }

  # Read content and adjust paths
  content <- readLines(source_path, warn = FALSE)
  modified_content <- gsub(
    "source\\(['\"]\\.\\./(jheem_analyses/.*?)['\"]\\)",
    "source('external/\\1')",
    content
  )

  # Also modify data file paths
  modified_content <- gsub(
    "([^a-zA-Z0-9_])([\"'])\\.\\./(jheem_analyses/.*?)(\\2)",
    "\\1\\2external/\\3\\4",
    modified_content
  )

  # Write modified content
  writeLines(modified_content, target_path)
  cat("Copied and adjusted:", target_path, "\n")
}

# Copy data files
copy_data_files(all_dependencies)

# Copy object_for_version_cache directory (needed for cached model objects)
source_cache_obj_dir <- "../jheem_analyses/commoncode/object_for_version_cache"
target_cache_obj_dir <- "external/jheem_analyses/commoncode/object_for_version_cache"

if (dir.exists(source_cache_obj_dir)) {
  cat("\n=== Copying cached model objects directory ===\n")
  copy_directory_recursive(source_cache_obj_dir, target_cache_obj_dir)
} else {
  cat("WARNING: cached objects directory not found at", source_cache_obj_dir, "\n")
  dir.create(target_cache_obj_dir, recursive = TRUE)
}

# ---------- STEP 4: Prepare cache_manager.R using template-based approach ----------
# Use our new modular function to prepare the cache manager
prepare_cache_manager(
  target_dir = "external/jheem_analyses/commoncode",
  template_path = "deployment/templates/cache_manager.R.template",
  verbose = TRUE
)

# ---------- STEP 5: Copy cached directory ----------

cat("\n=== Copying cached directory ===\n")

# Copy the entire cached directory
source_cache_dir <- "../jheem_analyses/cached"
target_cache_dir <- "external/jheem_analyses/cached"

if (dir.exists(source_cache_dir)) {
  cat("Copying cached directory...\n")
  copy_directory_recursive(source_cache_dir, target_cache_dir)
} else {
  cat("WARNING: cached directory not found at", source_cache_dir, "\n")
  dir.create(target_cache_dir, recursive = TRUE)
}

# ---------- STEP 6: Generate deployment command ----------

cat("\n=== Generating deployment command ===\n")

# Make sure simulation directories exist
if (!dir.exists("simulations/ryan-white/prerun")) {
  cat("WARNING: simulations/ryan-white/prerun directory does not exist!\n")
}

if (!file.exists("simulations/ryan-white/base/C.12580_base.Rdata")) {
  cat("WARNING: simulations/ryan-white/base/C.12580_base.Rdata file does not exist!\n")
}

# Generate deployment command
cat("\n========================================\n")
cat("To deploy to shinyapps.io, use this command:\n\n")
cat("rsconnect::deployApp(\n")
cat("  appDir = \"", getwd(), "\",\n", sep = "")
cat("  appName = \"", APP_NAME, "\",\n", sep = "")
cat("  account = \"", ACCOUNT_NAME, "\",\n", sep = "")
cat("  appFiles = c(\n")
cat("    \"app.R\",\n")
cat("    \".Renviron\",\n")
cat("    \"deployment/deployment_dependencies.R\",\n")
cat("    list.files(\"src\", recursive = TRUE, full.names = TRUE),\n")
cat("    list.files(\"www\", recursive = TRUE, full.names = TRUE),\n")
cat("    list.files(\"external/jheem_analyses\", recursive = TRUE, full.names = TRUE),\n")
cat("    list.files(\"simulations/ryan-white/prerun\", recursive = TRUE, full.names = TRUE),\n")
cat("    \"simulations/ryan-white/base/C.12580_base.Rdata\"\n")
cat("  ),\n")
cat("  forceUpdate = TRUE,\n")
cat("  lint = FALSE\n") # Added lint=FALSE to bypass browser() warnings
cat(")\n\n")

# ---------- STEP 7: Notify user about restoring original jheem2 package ----------

cat("\n=== Note about jheem2 package ===\n")

# Provide information about restoring the original package
if (has_jheem2) {
  # Get GitHub info from the original package
  original_ref <- NULL
  if (!is.null(current_jheem2$GithubSHA1)) {
    original_ref <- current_jheem2$GithubSHA1
  } else if (!is.null(current_jheem2$GithubRef)) {
    original_ref <- current_jheem2$GithubRef
  } else {
    # Default to dev branch if no specific reference found
    original_ref <- "dev"
  }

  cat("NOTE: The jheem2 package has been installed from the deployment branch.\n")
  cat("After deployment, you may want to restore your original version with:\n\n")
  cat("  remove.packages(\"jheem2\")\n")
  cat(paste0("  remotes::install_github(\"tfojo1/jheem2@", original_ref, "\")\n\n"))
}

cat("\n========================================\n")
cat("Deployment preparation complete!\n")
cat("========================================\n")
