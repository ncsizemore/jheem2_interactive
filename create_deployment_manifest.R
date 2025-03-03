# Create Deployment Manifest Script
# This script creates a manifest.json for deployment that excludes jheem2 but preserves its dependencies

create_deployment_manifest <- function() {
  # Required libraries
  if (!requireNamespace("jsonlite", quietly = TRUE)) install.packages("jsonlite")
  
  # 1. Check if there's an existing manifest to extract jheem2 dependencies
  jheem2_deps <- c("Rcpp", "deSolve", "magrittr", "methods") # Default known dependencies
  
  if (file.exists("manifest.json")) {
    tryCatch({
      current_manifest <- jsonlite::fromJSON("manifest.json")
      if ("jheem2" %in% names(current_manifest$packages)) {
        # Get jheem2's dependencies from current manifest
        message("Extracting jheem2 dependencies from existing manifest.json...")
        jheem2_info <- current_manifest$packages$jheem2
        if (!is.null(jheem2_info$depends)) {
          jheem2_deps <- unique(c(jheem2_deps, names(jheem2_info$depends)))
        }
      }
    }, error = function(e) {
      warning("Could not extract dependencies from existing manifest: ", e$message)
    })
  }
  
  message("jheem2 dependencies identified: ", paste(jheem2_deps, collapse = ", "))
  
  # 2. Specify exactly which files to include
  message("Generating list of files to include...")
  app_files <- c(
    # Core app files
    "app.R", 
    "init-jheem2.R",
    "update-jheem2.sh",
    
    # Configuration files
    if (file.exists("config.yml")) "config.yml",
    
    # All relevant directories
    list.files("vendor", recursive = TRUE, full.names = TRUE),
    list.files("src", recursive = TRUE, full.names = TRUE),
    list.files("www", recursive = TRUE, full.names = TRUE)
  )
  
  # 3. Generate manifest with specific files
  message("Generating manifest.json with rsconnect...")
  if (!requireNamespace("rsconnect", quietly = TRUE)) install.packages("rsconnect")
  rsconnect::writeManifest(appFiles = app_files)
  
  # 4. Post-process to remove jheem2 but keep its dependencies
  message("Post-processing manifest.json to remove jheem2 but keep dependencies...")
  manifest <- jsonlite::fromJSON("manifest.json")
  
  # Remember the original package count
  original_package_count <- length(names(manifest$packages))
  
  # Remove jheem2 from packages list
  if ("jheem2" %in% names(manifest$packages)) {
    manifest$packages <- manifest$packages[names(manifest$packages) != "jheem2"]
    message("Removed jheem2 from package list")
  }
  
  # Ensure all jheem2 dependencies are included
  packages_added <- 0
  if (length(jheem2_deps) > 0) {
    for (dep in jheem2_deps) {
      if (!dep %in% names(manifest$packages) && requireNamespace(dep, quietly = TRUE)) {
        pkg_version <- as.character(packageVersion(dep))
        manifest$packages[[dep]] <- list(version = pkg_version)
        packages_added <- packages_added + 1
        message("Added dependency: ", dep, " (", pkg_version, ")")
      }
    }
  }
  
  # 5. Write the modified manifest back
  jsonlite::write_json(manifest, "manifest.json", pretty = TRUE, auto_unbox = TRUE)
  
  message("Deployment manifest created successfully.")
  message("Packages: ", original_package_count - 1 + packages_added, 
          " (removed jheem2, added ", packages_added, " missing dependencies)")
  message("The app now uses the source version of jheem2 from vendor/jheem2/")
}

# Run the function if this script is executed directly
if (interactive()) {
  message("Call create_deployment_manifest() to generate the deployment manifest")
} else {
  create_deployment_manifest()
}
