#!/usr/bin/env Rscript
# deploy.R - Script to prepare for deployment to shinyapps.io or Posit Connect

# Load required packages
library(rsconnect)

# Create a function to ensure directories exist
ensure_dir <- function(path) {
  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE)
    cat(sprintf("Created directory: %s\n", path))
  }
}

# Function to copy a directory and all its contents
copy_directory_recursive <- function(source_dir, target_dir) {
  if (!dir.exists(source_dir)) {
    cat(sprintf("WARNING: Source directory does not exist: %s\n", source_dir))
    return()
  }
  
  # Create target directory if it doesn't exist
  ensure_dir(target_dir)
  
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
      cat(sprintf("Copied: %s\n", target_path))
    }
  }
}

# Function to copy a file and modify source paths
copy_file <- function(source_path, target_path) {
  # Create parent directory if needed
  target_dir <- dirname(target_path)
  ensure_dir(target_dir)
  
  # If file exists, read content and adjust paths
  if (file.exists(source_path)) {
    # Read the file content
    file_content <- readLines(source_path, warn = FALSE)
    
    # Replace source paths for deployment
    file_content <- gsub(
      "source\\(['\"]\\.\\./(jheem_analyses/.*)['\"]\\)",
      "source('external/\\1')",
      file_content
    )
    
    # Write modified content to target file
    writeLines(file_content, target_path)
    cat(sprintf("Copied and adjusted: %s\n", target_path))
  } else {
    cat(sprintf("WARNING: Source file not found: %s\n", source_path))
  }
}

# Function to create a custom cache_manager.R for deployment
create_deployment_cache_manager <- function(source_path, target_path) {
  # Read the original file
  original_content <- readLines(source_path, warn = FALSE)
  
  # Find where to cut the beginning of the file
  header_end <- which(grepl("^## PUBLIC", original_content))[1] - 1
  
  if (is.na(header_end) || header_end < 1) {
    header_end <- 15  # Default if we can't find the marker
  }
  
  # Create new header with hard-coded paths
  new_header <- c(
    "# A lot of people have done the \"first time setup\" already, so they need to install this new dependency",
    "if (nchar(system.file(package = \"httr2\")) == 0) {",
    "    install.packages(\"httr2\")",
    "}",
    "",
    "# Set cache directory for deployment",
    "JHEEM.CACHE.DIR <- \"external/jheem_analyses/cached\"",
    "DATA.MANAGER.CACHE.METADATA.FILE <- \"external/jheem_analyses/commoncode/data_manager_cache_metadata.Rdata\"",
    "PACKAGE.VERSION.CACHE.FILE <- \"external/jheem_analyses/commoncode/package_version_cache.Rdata\"",
    "",
    "if (!dir.exists(JHEEM.CACHE.DIR)) {",
    "    stop(\"Cannot find the cached directory in the deployment folder. Please check that the deploy.R script ran correctly.\")",
    "}"
  )
  
  # Combine the new header with the rest of the file
  file_content <- c(
    new_header,
    original_content[header_end:length(original_content)]
  )
  
  # Write modified content to target file
  writeLines(file_content, target_path)
  cat(sprintf("Created custom deployment version: %s\n", target_path))
}

# List of specific files we need to copy
copy_deployment_files <- function() {
  source_base <- "../jheem_analyses"
  target_base <- "external/jheem_analyses"
  
  # Copy and adjust standard files
  files_to_copy <- c(
    # The main specification file
    "applications/EHE/ehe_specification.R",
    
    # Files we know are sourced from source_code.R
    "use_jheem2_package_setting.R",
    "source_code.R",
    "applications/EHE/ehe_base_parameters.R",
    "applications/EHE/ehe_specification_helpers.R",
    "applications/EHE/ehe_ontology_mappings.R",
    "applications/EHE/ehe_sampled_parameters.R",
    
    # Common code files
    "commoncode/target_populations.R",
    "commoncode/file_paths.R",
    "commoncode/age_mappings.R",
    "commoncode/cache_object_for_version_functions.R",
    "commoncode/logitnorm_helpers.R",
    
    # Metadata files
    "commoncode/data_manager_cache_metadata.Rdata",
    "commoncode/package_version_cache.Rdata",
    
    # Input managers
    "input_managers/input_helpers.R",
    "input_managers/covid_mobility_manager.R",
    "input_managers/covid_input_manager.R",
    "input_managers/idu_input_manager.R",
    "input_managers/prep_input_manager.R",
    "input_managers/pairing_input_manager.R",
    "input_managers/continuum_input_manager.R",
    "input_managers/idu_sexual_oes.R"
  )
  
  # Copy each file
  for (file in files_to_copy) {
    source_path <- file.path(source_base, file)
    target_path <- file.path(target_base, file)
    copy_file(source_path, target_path)
  }
  
  # Create custom cache_manager.R
  cache_manager_source <- file.path(source_base, "commoncode/cache_manager.R")
  cache_manager_target <- file.path(target_base, "commoncode/cache_manager.R")
  create_deployment_cache_manager(cache_manager_source, cache_manager_target)
  
  # Copy the entire cached directory
  source_cache_dir <- file.path(source_base, "cached")
  target_cache_dir <- file.path(target_base, "cached")
  
  cat(sprintf("Copying entire cached directory from %s to %s...\n", source_cache_dir, target_cache_dir))
  copy_directory_recursive(source_cache_dir, target_cache_dir)
}

# Run the function to copy deployment files
cat("Copying required files from jheem_analyses...\n")
copy_deployment_files()

# Generate the manifest
cat("Generating manifest.json...\n")
rsconnect::writeManifest()

# Print success message
cat("\n========================================\n")
cat("Deployment files prepared successfully!\n")
cat("========================================\n\n")
cat("IMPORTANT: These files need to be committed to Git before deploying\n")
cat("to Posit Connect or shinyapps.io. Follow these steps:\n\n")
cat("1. Run 'git add external/' to stage the copied files\n")
cat("2. Commit the changes: 'git commit -m \"Update deployment files\"'\n")
cat("3. Push to your repository if needed\n")
cat("4. Deploy using: rsconnect::deployApp()\n\n")
cat("To deploy to shinyapps.io, use this command:\n\n")
cat("rsconnect::deployApp(\n")
cat("  appDir = \"/Users/nicholas/Documents/jheem/code/jheem2_interactive\",\n")
cat("  appName = \"jheem2-interactive\",\n")
cat("  account = \"your-account-name\",  # Replace with your actual account name\n")
cat("  appFiles = c(\n")
cat("    \"app.R\",\n")
cat("    \"manifest.json\",\n")
cat("    list.files(\"src\", recursive = TRUE, full.names = TRUE),\n")
cat("    list.files(\"www\", recursive = TRUE, full.names = TRUE),\n")
cat("    list.files(\"external/jheem_analyses\", recursive = TRUE, full.names = TRUE)\n")
cat("  ),\n")
cat("  forceUpdate = TRUE\n")
cat(")\n\n")
cat("If you encounter missing file errors during deployment, add the\n")
cat("missing files to the 'files_to_copy' list in this script and run it again.\n")
