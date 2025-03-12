# prepare_cache_manager.R
# Module for preparing cache_manager.R for deployment

#' Prepares cache_manager.R for deployment
#' 
#' Instead of modifying the original cache_manager.R file, this function
#' uses a template-based approach to create a deployment-specific version.
#' 
#' @param target_dir Directory where the deployment version should be placed
#' @param template_path Path to the template file (defaults to deployment/templates/cache_manager.R.template)
#' @param verbose Whether to print progress messages
#' @return Path to the created file
prepare_cache_manager <- function(
  target_dir = "external/jheem_analyses/commoncode",
  template_path = "deployment/templates/cache_manager.R.template",
  verbose = TRUE
) {
  if (verbose) {
    cat("\n=== Preparing cache_manager.R for deployment ===\n")
  }
  
  # Check if template exists
  if (!file.exists(template_path)) {
    stop("ERROR: Cache manager template not found at ", template_path)
  }
  
  # Create target directory if it doesn't exist
  if (!dir.exists(target_dir)) {
    dir.create(target_dir, recursive = TRUE)
    if (verbose) {
      cat("Created directory:", target_dir, "\n")
    }
  }
  
  # Target file path
  target_file <- file.path(target_dir, "cache_manager.R")
  
  # Read the template content
  template_content <- readLines(template_path, warn = FALSE)
  
  # Write to target file
  writeLines(template_content, target_file)
  
  if (verbose) {
    cat("Created deployment version of cache_manager.R at", target_file, "\n")
  }
  
  # Prepare compatible metadata files
  prepare_metadata_files(target_dir, verbose)
  
  # Return the path to the created file
  invisible(target_file)
}

#' Creates compatible metadata files for deployment
#' 
#' @param target_dir Directory where the metadata files should be placed
#' @param verbose Whether to print progress messages
#' @return Invisible NULL
prepare_metadata_files <- function(
  target_dir = "external/jheem_analyses/commoncode", 
  verbose = TRUE
) {
  if (verbose) {
    cat("\n=== Creating compatible metadata files ===\n")
  }
  
  # Handle data_manager_cache_metadata.Rdata
  source_path <- "../jheem_analyses/commoncode/data_manager_cache_metadata.Rdata"
  target_path <- file.path(target_dir, "data_manager_cache_metadata.Rdata")
  
  if (file.exists(source_path)) {
    tryCatch({
      # Load original data
      data.manager.cache.metadata <- get(load(source_path))
      
      # Save to target with current R version
      save(data.manager.cache.metadata, file = target_path)
      if (verbose) {
        cat("Created compatible version of data_manager_cache_metadata.Rdata\n")
      }
    }, error = function(e) {
      if (verbose) {
        cat("WARNING: Could not load source metadata file:", e$message, "\n")
      }
      # Create an empty fallback version
      data.manager.cache.metadata <- list()
      save(data.manager.cache.metadata, file = target_path)
      if (verbose) {
        cat("Created empty fallback metadata file\n")
      }
    })
  } else {
    if (verbose) {
      cat("WARNING: Source metadata file not found:", source_path, "\n")
    }
    # Create an empty fallback version
    data.manager.cache.metadata <- list()
    save(data.manager.cache.metadata, file = target_path)
    if (verbose) {
      cat("Created empty fallback metadata file\n")
    }
  }
  
  # Handle package_version_cache.Rdata
  source_path <- "../jheem_analyses/commoncode/package_version_cache.Rdata"
  target_path <- file.path(target_dir, "package_version_cache.Rdata")
  
  if (file.exists(source_path)) {
    tryCatch({
      # Load original data
      cache_file <- get(load(source_path))
      
      # Save to target with current R version
      save(cache_file, file = target_path)
      if (verbose) {
        cat("Created compatible version of package_version_cache.Rdata\n")
      }
    }, error = function(e) {
      if (verbose) {
        cat("WARNING: Could not load source package version file:", e$message, "\n")
      }
      # Create an empty fallback version
      cache_file <- list()
      save(cache_file, file = target_path)
      if (verbose) {
        cat("Created empty fallback package version file\n")
      }
    })
  } else {
    if (verbose) {
      cat("WARNING: Source package version file not found:", source_path, "\n")
    }
    # Create an empty fallback version
    cache_file <- list()
    save(cache_file, file = target_path)
    if (verbose) {
      cat("Created empty fallback package version file\n")
    }
  }
  
  invisible(NULL)
}
