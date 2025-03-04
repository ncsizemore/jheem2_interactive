#!/usr/bin/env Rscript
# deploy.R - Script to prepare for deployment to Posit Connect

# Load required packages
library(rsconnect)
library(jsonlite)

# Parameters for deployment
jheem2_branch <- "test-deploy"
jheem2_sha <- "c388e283e6e825e9d9d4f8f2709d94c91e0e1175"

# Create a function to ensure directories exist
ensure_dir <- function(path) {
  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE)
    cat(sprintf("Created directory: %s\n", path))
  }
}

# Function to copy a file, creating parent directories if needed
copy_file <- function(source_path, target_path) {
  # Create parent directory if needed
  target_dir <- dirname(target_path)
  ensure_dir(target_dir)
  
  # Copy the file
  if (file.exists(source_path)) {
    file.copy(source_path, target_path, overwrite = TRUE)
    cat(sprintf("Copied: %s\n", target_path))
  } else {
    cat(sprintf("WARNING: Source file not found: %s\n", source_path))
  }
}

# List of specific files we need to copy
copy_deployment_files <- function() {
  source_base <- "../jheem_analyses"
  target_base <- "external/jheem_analyses"
  
  # Explicitly list required files
  files_to_copy <- c(
    # The main specification file
    "applications/EHE/ehe_specification.R",
    
    # Files we know are sourced from source_code.R
    "use_jheem2_package_setting.R",
    "applications/EHE/ehe_base_parameters.R",
    "applications/EHE/ehe_specification_helpers.R",
    "applications/EHE/ehe_ontology_mappings.R",
    "applications/EHE/ehe_sampled_parameters.R",
    
    # Add more files as needed if deployment issues arise
    "commoncode/target_populations.R",
    "commoncode/file_paths.R",
    "commoncode/cache_manager.R"
  )
  
  # Copy each file
  for (file in files_to_copy) {
    source_path <- file.path(source_base, file)
    target_path <- file.path(target_base, file)
    copy_file(source_path, target_path)
  }
}

# Run the function to copy deployment files
cat("Copying required files from jheem_analyses...\n")
copy_deployment_files()

# Generate the manifest
cat("Generating manifest.json...\n")
rsconnect::writeManifest()

# Update the manifest to use the specific branch/SHA
manifest <- jsonlite::read_json("manifest.json")

# Update the packages section to use the specific branch of jheem2
jheem2_found <- FALSE
for (i in seq_along(manifest$packages)) {
  if (names(manifest$packages)[i] == "jheem2") {
    manifest$packages$jheem2$source <- "github"
    manifest$packages$jheem2$repository <- "tfojo1/jheem2"
    manifest$packages$jheem2$branch <- jheem2_branch
    manifest$packages$jheem2$sha <- jheem2_sha
    jheem2_found <- TRUE
    cat("Updated jheem2 package in manifest.json\n")
    break
  }
}

# Add jheem2 if it's not already in the manifest
if (!jheem2_found) {
  cat("Adding jheem2 to manifest.json\n")
  manifest$packages$jheem2 <- list(
    name = "jheem2",
    source = "github",
    repository = "tfojo1/jheem2",
    branch = jheem2_branch,
    sha = jheem2_sha
  )
}

# Write the updated manifest
jsonlite::write_json(manifest, "manifest.json", pretty = TRUE)

# Print success message
cat("\n========================================\n")
cat("Deployment files prepared successfully!\n")
cat("========================================\n\n")
cat("IMPORTANT: These files need to be committed to Git before deploying\n")
cat("to Posit Connect. Follow these steps:\n\n")
cat("1. Run 'git add external/' to stage the copied files\n")
cat("2. Commit the changes: 'git commit -m \"Update deployment files\"'\n")
cat("3. Push to your repository if needed\n")
cat("4. Deploy using: rsconnect::deployApp()\n\n")
cat("If you encounter missing file errors during deployment, add the\n")
cat("missing files to the 'files_to_copy' list in this script and run it again.\n\n")
cat("jheem2 package will be installed from:\n")
cat(sprintf("- Repository: tfojo1/jheem2\n"))
cat(sprintf("- Branch: %s\n", jheem2_branch))
cat(sprintf("- SHA: %s\n", jheem2_sha))
