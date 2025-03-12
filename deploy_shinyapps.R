#!/usr/bin/env Rscript
# deploy_shinyapps.R - Script to prepare and deploy to shinyapps.io

# Load required packages
library(rsconnect)
library(remotes)
library(yaml)

# Load deployment modules
source("deployment/prepare_cache_manager.R")

# Application configuration
APP_NAME <- "ryan-white"  # The name of the app for deployment
ACCOUNT_NAME <- "jheem-test"  # The shinyapps.io account name
SOURCE_BRANCH <- "dev"  # The source branch for jheem2
DEPLOYMENT_BRANCH <- "ryan-white-deployment"  # The deployment branch name

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
      return(FALSE)  # No update needed
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
  tryCatch({
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
    return(TRUE)  # Branch was updated
  }, error = function(e) {
    # Make sure we return to original directory even on error
    if (getwd() != current_dir) {
      setwd(current_dir)
    }
    
    # Clean up temp directory
    unlink(temp_dir, recursive = TRUE)
    
    stop(paste("Error preparing deployment branch:", e$message))
  })
}

# Run the function to prepare deployment branch - can pass TRUE to force update
branch_updated <- prepare_deployment_branch(force_update = FALSE)

# ---------- STEP 2: Install jheem2 from deployment branch ----------

cat("\n=== Installing jheem2 from deployment branch ===\n")

# Record current package info to restore later if needed
has_jheem2 <- "jheem2" %in% installed.packages()[,"Package"]
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

# Create function to discover dependencies recursively
discover_dependencies <- function(file_path, base_dir = "../jheem_analyses/") {
  if (!file.exists(file_path)) {
    warning(paste("File not found:", file_path))
    return(character(0))
  }
  
  content <- readLines(file_path, warn = FALSE)
  
  # Filter out commented lines (lines that have '#' before the source() call)
  # This keeps only uncommented source() calls
  content_filtered <- content[!grepl("^\\s*#.*source\\(", content)]
  
  # Look for source() calls with paths
  source_regex <- "source\\(['\"]\\.\\./(jheem_analyses/.*?)['\"]\\)"
  matches <- regmatches(content_filtered, gregexpr(source_regex, content_filtered, perl = TRUE))
  matches <- unlist(matches)
  
  # Extract the paths
  paths <- gsub(source_regex, "\\1", matches, perl = TRUE)
  full_paths <- file.path(dirname(base_dir), paths)
  
  # Add this file to the list
  all_deps <- c(file_path)
  
  # Recursively find dependencies of dependencies
  for (dep in full_paths) {
    all_deps <- c(all_deps, discover_dependencies(dep, base_dir))
  }
  
  return(unique(all_deps))
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
  
  # Write modified content
  writeLines(modified_content, target_path)
  cat("Copied and adjusted:", target_path, "\n")
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
cat("  appDir = \"", getwd(), "\",\n", sep="")
cat("  appName = \"", APP_NAME, "\",\n", sep="")
cat("  account = \"", ACCOUNT_NAME, "\",\n", sep="")
cat("  appFiles = c(\n")
cat("    \"app.R\",\n")
cat("    \".Renviron\",\n")
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
