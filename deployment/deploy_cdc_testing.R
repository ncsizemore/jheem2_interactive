#!/usr/bin/env Rscript
# deploy_cdc_testing.R - Script to prepare and deploy CDC testing app to shinyapps.io

# Load required packages
library(rsconnect)
library(remotes)

# Application configuration
APP_NAME <- "cdc-testing" # The name of the app for deployment
ACCOUNT_NAME <- "jheem" # The shinyapps.io account name
SOURCE_BRANCH <- "dev" # The source branch for jheem2
DEPLOYMENT_BRANCH <- "cdc-testing-deployment" # The deployment branch name

# ---------- STEP 1: Prepare jheem2 deployment branch ----------

cat("=== Preparing jheem2 deployment branch ===\n")

# File to store the last processed SHA
last_dev_sha_file <- ".last_dev_sha_cdc"

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
  temp_dir <- file.path(tempdir(), "jheem2_deploy_cdc")
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

# ---------- STEP 3: Generate deployment command ----------

cat("\n=== Generating deployment command ===\n")

# Make sure simulation directories exist
if (!dir.exists("simulations/cdct-w")) {
  cat("WARNING: simulations/cdct-w directory does not exist!\n")
}

if (!dir.exists("simulations/cdct-ws")) {
  cat("WARNING: simulations/cdct-ws directory does not exist!\n")
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
cat("    list.files(\"simulations/cdct-w\", recursive = TRUE, full.names = TRUE),\n")
cat("    list.files(\"simulations/cdct-ws\", recursive = TRUE, full.names = TRUE)\n")
cat("  ),\n")
cat("  forceUpdate = TRUE,\n")
cat("  lint = FALSE\n")
cat(")\n\n")

# ---------- STEP 4: Notify user about restoring original jheem2 package ----------

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
cat("CDC Testing deployment preparation complete!\n")
cat("========================================\n")