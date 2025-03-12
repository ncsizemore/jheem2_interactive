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

# Function to create R-version-compatible metadata files
create_compatible_metadata_files <- function() {
  cat("Creating R-version compatible metadata files...\n")
  
  # Handle data_manager_cache_metadata.Rdata
  source_path <- "../jheem_analyses/commoncode/data_manager_cache_metadata.Rdata"
  target_path <- "external/jheem_analyses/commoncode/data_manager_cache_metadata.Rdata"
  
  if (file.exists(source_path)) {
    # Load original data
    data.manager.cache.metadata <- get(load(source_path))
    
    # Save to target with current R version
    save(data.manager.cache.metadata, file = target_path)
    cat(sprintf("Created compatible version of data_manager_cache_metadata.Rdata\n"))
  } else {
    cat(sprintf("WARNING: Source metadata file not found: %s\n", source_path))
    # Create an empty fallback version
    data.manager.cache.metadata <- list()
    save(data.manager.cache.metadata, file = target_path)
    cat(sprintf("Created empty fallback metadata file\n"))
  }
  
  # Handle package_version_cache.Rdata
  source_path <- "../jheem_analyses/commoncode/package_version_cache.Rdata"
  target_path <- "external/jheem_analyses/commoncode/package_version_cache.Rdata"
  
  if (file.exists(source_path)) {
    # Load original data
    cache_file <- get(load(source_path))
    
    # Save to target with current R version
    save(cache_file, file = target_path)
    cat(sprintf("Created compatible version of package_version_cache.Rdata\n"))
  } else {
    cat(sprintf("WARNING: Source package version file not found: %s\n", source_path))
    # Create an empty fallback version
    cache_file <- list()
    save(cache_file, file = target_path)
    cat(sprintf("Created empty fallback package version file\n"))
  }
}

# Function to create a more resilient cache_manager.R
make_resilient_cache_manager <- function() {
  source_path <- "../jheem_analyses/commoncode/cache_manager.R"
  target_path <- "external/jheem_analyses/commoncode/cache_manager.R"
  
  if (!file.exists(source_path)) {
    cat(sprintf("WARNING: Source cache_manager.R not found: %s\n", source_path))
    return()
  }
  
  # Read the original file
  original_content <- readLines(source_path, warn = FALSE)
  
  # Find where to cut the beginning of the file
  header_end <- which(grepl("^## PUBLIC", original_content))[1] - 1
  
  if (is.na(header_end) || header_end < 1) {
    header_end <- 15  # Default if we can't find the marker
  }
  
  # Create new header with error-resilient paths
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
    "# Make sure the directory exists",
    "if (!dir.exists(JHEEM.CACHE.DIR)) {",
    "    warning(\"Cannot find the cached directory in the deployment folder. Some functionality may be limited.\")",
    "}"
  )
  
  # Find and modify the get.data.manager.cache.metadata function to be more resilient
  function_start <- which(grepl("^get\\.data\\.manager\\.cache\\.metadata", original_content))
  function_end <- NULL
  
  if (length(function_start) > 0) {
    # Find where this function ends (next function or section starts)
    for (i in (function_start[1] + 1):length(original_content)) {
      if (grepl("^[a-zA-Z0-9_.]+\\s*<-\\s*function", original_content[i]) || 
          grepl("^##", original_content[i])) {
        function_end <- i - 1
        break
      }
    }
    
    if (!is.null(function_end)) {
      # Replace with our resilient version
      resilient_function <- c(
        "get.data.manager.cache.metadata <- function(pretty.print=T, error.prefix = \"\") {",
        "    # Try to load the metadata file, but handle errors gracefully",
        "    if (!file.exists(DATA.MANAGER.CACHE.METADATA.FILE)) {",
        "        warning(paste0(error.prefix, \"The metadata file is missing. Creating an empty one.\"))",
        "        data.manager.cache.metadata <- list()",
        "    } else {",
        "        tryCatch({",
        "            data.manager.cache.metadata <- get(load(DATA.MANAGER.CACHE.METADATA.FILE))",
        "        }, error = function(e) {",
        "            warning(paste0(error.prefix, \"Could not load metadata file. Error: \", e$message, \". Creating an empty one.\"))",
        "            data.manager.cache.metadata <- list()",
        "        })",
        "    }",
        "",
        "    if (pretty.print) {",
        "        if (length(data.manager.cache.metadata) == 0) {",
        "            cat(\"Using empty metadata (no cached data managers available)\\n\")",
        "        } else {",
        "            cat(\"Local copies of each data manager must be last modified by these dates or later: \",\"\\n\")",
        "            for (data.manager in names(data.manager.cache.metadata)) {",
        "                cat(data.manager, \"-\", format(data.manager.cache.metadata[[data.manager]][[\"last.modified.date\"]], usetz = T),\"\\n\")",
        "            }",
        "        }",
        "    }",
        "    invisible(data.manager.cache.metadata)",
        "}"
      )
      
      # Replace the function in the content
      original_content <- c(
        original_content[1:(function_start[1]-1)],
        resilient_function,
        original_content[(function_end+1):length(original_content)]
      )
    }
  }
  
  # Similarly make is.package.out.of.date more resilient
  function_start <- which(grepl("^is\\.package\\.out\\.of\\.date", original_content))
  function_end <- NULL
  
  if (length(function_start) > 0) {
    # Find where this function ends
    for (i in (function_start[1] + 1):length(original_content)) {
      if (grepl("^[a-zA-Z0-9_.]+\\s*<-\\s*function", original_content[i]) || 
          grepl("^##", original_content[i])) {
        function_end <- i - 1
        break
      }
    }
    
    if (!is.null(function_end)) {
      # Replace with our resilient version
      resilient_function <- c(
        "is.package.out.of.date <- function(package=\"jheem2\", verbose=F) {",
        "    error.prefix <- \"Cannot check if package is out of date: \"",
        "    if (!is.character(package) || length(package)!=1 || is.na(package))",
        "        stop(paste0(error.prefix, \"'package' must be a single character value. Defaults to 'jheem2'\"))",
        "    if (!is.logical(verbose) || length(verbose)!=1 || is.na(verbose))",
        "        stop(paste0(error.prefix, \"'verbose' must be TRUE or FALSE\"))",
        "    if (nchar(system.file(package = package)) == 0)",
        "        stop(paste0(error.prefix, \"package '\", package, \"' is not installed. Install it with 'devtools::install_github('tfojo1/\", package, \"')'\"))",
        "    ",
        "    # Try to load the package version file, but handle errors gracefully",
        "    if (!file.exists(PACKAGE.VERSION.CACHE.FILE)) {",
        "        warning(paste0(error.prefix, \"The package version file could not be found. Assuming package is up to date.\"))",
        "        return(FALSE)",
        "    }",
        "    ",
        "    # Load with error handling",
        "    tryCatch({",
        "        cache_file <- get(load(PACKAGE.VERSION.CACHE.FILE))",
        "        if (!(package %in% names(cache_file))) {",
        "            if (verbose)",
        "                cat(paste0(\"No version requirement found for package '\", package, \"'. Assuming it's up to date.\\n\"))",
        "            return(FALSE)",
        "        }",
        "        if (verbose)",
        "            print(paste0(\"The version for package '\", package, \"' must be >= \", cache_file[[package]], \"; installed version is \", as.character(packageVersion(package)), \".\"))",
        "        return(packageVersion(package) < cache_file[[package]])",
        "    }, error = function(e) {",
        "        warning(paste0(error.prefix, \"Failed to load package version cache: \", e$message, \". Assuming package is up to date.\"))",
        "        return(FALSE)",
        "    })",
        "}"
      )
      
      # Replace the function in the content
      original_content <- c(
        original_content[1:(function_start[1]-1)],
        resilient_function,
        original_content[(function_end+1):length(original_content)]
      )
    }
  }
  
  # Combine our custom header with the rest of the file
  file_content <- c(
    new_header,
    original_content[header_end:length(original_content)]
  )
  
  # Write the modified file
  writeLines(file_content, target_path)
  cat(sprintf("Created resilient cache_manager.R for deployment\n"))
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
  
  # Copy the entire cached directory
  source_cache_dir <- file.path(source_base, "cached")
  target_cache_dir <- file.path(target_base, "cached")
  
  cat(sprintf("Copying entire cached directory from %s to %s...\n", source_cache_dir, target_cache_dir))
  copy_directory_recursive(source_cache_dir, target_cache_dir)
  
  # Now create compatible metadata files and resilient cache_manager
  create_compatible_metadata_files()
  make_resilient_cache_manager()
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
cat("To deploy to shinyapps.io, use this command:\n\n")
cat("rsconnect::deployApp(\n")
cat("  appDir = \"/Users/nicholas/Documents/jheem/code/jheem2_interactive\",\n")
cat("  appName = \"jheem2-interactive\",\n")
cat("  account = \"jheem-test\",\n")
cat("  appFiles = c(\n")
cat("    \"app.R\",\n")
cat("    list.files(\"src\", recursive = TRUE, full.names = TRUE),\n")
cat("    list.files(\"www\", recursive = TRUE, full.names = TRUE),\n")
cat("    list.files(\"external/jheem_analyses\", recursive = TRUE, full.names = TRUE)\n")
cat("  ),\n")
cat("  forceUpdate = TRUE\n")
cat(")\n\n")
cat("If you encounter missing file errors during deployment, add the\n")
cat("missing files to the 'files_to_copy' list in this script and run it again.\n")
