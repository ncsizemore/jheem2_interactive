# Helper functions for the UnifiedCacheManager

# Global instance
CACHE_MANAGER <- NULL

#' Get the UnifiedCacheManager instance
#' @return UnifiedCacheManager instance
get_cache_manager <- function() {
  # print("[UCACHE_HELPER] Getting cache manager instance")
  # print(sprintf("[UCACHE_HELPER] Current working directory: %s", getwd()))

  if (is.null(CACHE_MANAGER)) {
    # print("[UCACHE_HELPER] No existing instance, creating new one")

    # Source the manager if needed
    if (!exists("UnifiedCacheManager")) {
      # print("[UCACHE_HELPER] Sourcing manager.R file")
      tryCatch(
        {
          # Check if the file exists using different path approaches
          manager_path <- "src/data/unified_cache/manager.R"
          absolute_path <- normalizePath(manager_path, mustWork = FALSE)

          # # Log path information
          # print(sprintf("[UCACHE_HELPER] Relative path: %s", manager_path))
          # print(sprintf("[UCACHE_HELPER] Normalized path: %s", absolute_path))
          # print(sprintf("[UCACHE_HELPER] File exists (relative): %s", file.exists(manager_path)))
          # print(sprintf("[UCACHE_HELPER] File exists (absolute): %s", file.exists(absolute_path)))

          # Try to source using the best available path
          if (file.exists(manager_path)) {
            # print("[UCACHE_HELPER] Sourcing using relative path")
            source(manager_path)
          } else if (file.exists(absolute_path)) {
            # print("[UCACHE_HELPER] Sourcing using absolute path")
            source(absolute_path)
          } else {
            # Try alternative paths
            alt_path <- "./src/data/unified_cache/manager.R"
            # print(sprintf("[UCACHE_HELPER] Trying alternative path: %s", alt_path))
            # print(sprintf("[UCACHE_HELPER] File exists (alternative): %s", file.exists(alt_path)))
            source(alt_path) # Assume this works if others fail
          }
          # print("[UCACHE_HELPER] Successfully sourced manager.R")
        },
        error = function(e) {
          # Keep error printing for sourcing issues
          print(sprintf("[UCACHE_HELPER] Error sourcing manager.R: %s", e$message))
          # # Print additional debug info for path resolution
          # print("[UCACHE_HELPER] Checking file system structure:")
          potential_dirs <- c(
            "src",
            "src/data",
            "src/data/unified_cache",
            "./src",
            "./src/data",
            "./src/data/unified_cache"
          )

          # for (dir_path in potential_dirs) {
          #   print(sprintf("[UCACHE_HELPER] Directory '%s' exists: %s", dir_path, file.exists(dir_path)))
          #   if (file.exists(dir_path) && dir.exists(dir_path)) {
          #     print(sprintf("[UCACHE_HELPER] Contents of '%s':", dir_path))
          #     print(list.files(dir_path, all.files = TRUE))
          #   }
          # }
          stop(e) # Re-throw the error
        }
      )
    }

    # Create instance with config
    # print("[UCACHE_HELPER] Getting cache config")
    config <- tryCatch(
      {
        # # Add detailed logging for config loading
        # print("[UCACHE_HELPER] Before calling get_component_config")
        cfg <- get_component_config("caching") # This is cached now
        # print("[UCACHE_HELPER] After calling get_component_config")
        cfg
      },
      error = function(e) {
        # Keep error printing for config loading issues
        print(sprintf("[UCACHE_HELPER] Error loading config: %s", e$message))
        # # Create a minimal default config
        # print("[UCACHE_HELPER] Creating default config as fallback")
        default_config <- list(
          unified_cache = list(
            base_path = "cache", # Ensure base_path exists
            max_disk_usage_mb = 1500, # Provide sensible defaults
            memory_threshold_mb = 6000, # Provide sensible defaults
            retain_referenced = TRUE # Provide sensible defaults
          ),
          simulation_cache = list( # Ensure simulation_cache exists
            enable_disk_cache = TRUE, # Provide sensible defaults
            path = "cache/simulations" # Provide sensible defaults
          )
        )
        # print("[UCACHE_HELPER] Created default config as fallback")
        default_config
      }
    )

    # print("[UCACHE_HELPER] Creating UnifiedCacheManager instance")
    tryCatch(
      {
        # # Inspect the config structure before passing to constructor
        # print("[UCACHE_HELPER] Config structure before passing to constructor:")
        # print(sprintf("[UCACHE_HELPER] Config type: %s, class: %s", typeof(config), paste(class(config), collapse=",")))
        # print("[UCACHE_HELPER] Config contents:")
        # print(str(config, max.level=3))

        # # Check if UnifiedCacheManager exists
        # print(sprintf("[UCACHE_HELPER] UnifiedCacheManager class exists: %s", exists("UnifiedCacheManager")))

        # Create the cache directories before initialization
        # Use %||% for safety in case config loading failed
        cache_base <- config$unified_cache$base_path %||% "cache"
        onedrive_cache <- file.path(cache_base, "onedrive")
        simulations_cache <- file.path(cache_base, "simulations")

        # print(sprintf("[UCACHE_HELPER] Creating cache directories if needed"))
        # print(sprintf("[UCACHE_HELPER] Cache base: %s", cache_base))
        # print(sprintf("[UCACHE_HELPER] OneDrive cache: %s", onedrive_cache))
        # print(sprintf("[UCACHE_HELPER] Simulations cache: %s", simulations_cache))

        dir.create(cache_base, recursive = TRUE, showWarnings = FALSE)
        dir.create(onedrive_cache, recursive = TRUE, showWarnings = FALSE)
        dir.create(simulations_cache, recursive = TRUE, showWarnings = FALSE)

        # print(sprintf("[UCACHE_HELPER] Cache directories created"))
        # print(sprintf("[UCACHE_HELPER] Cache base exists: %s", dir.exists(cache_base)))
        # print(sprintf("[UCACHE_HELPER] OneDrive cache exists: %s", dir.exists(onedrive_cache)))
        # print(sprintf("[UCACHE_HELPER] Simulations cache exists: %s", dir.exists(simulations_cache)))

        # Now create the cache manager
        # print("[UCACHE_HELPER] About to create UnifiedCacheManager instance")
        CACHE_MANAGER <<- UnifiedCacheManager$new(config)
        # print("[UCACHE_HELPER] Successfully created cache manager")
      },
      error = function(e) {
        # Keep error printing for critical cache manager creation issues
        print(sprintf("[UCACHE_HELPER] Error creating cache manager: %s", e$message))
        # # Also print stack trace
        # print("[UCACHE_HELPER] Stack trace:")
        # print(traceback())

        # # Check for specific potential issues
        # if (!exists("UnifiedCacheManager")) {
        #   print("[UCACHE_HELPER] CRITICAL ERROR: UnifiedCacheManager class not defined after sourcing")
        # }
        # if (is.null(config) || !is.list(config)) {
        #   print("[UCACHE_HELPER] CRITICAL ERROR: Config is NULL or not a list")
        # }
        # if (!is.null(config) && (is.null(config$unified_cache) || !is.list(config$unified_cache))) {
        #   print("[UCACHE_HELPER] CRITICAL ERROR: config$unified_cache is NULL or not a list")
        # }
        #
        # # Attempt to identify any R6 class creation issues
        # print("[UCACHE_HELPER] Checking R6 package status:")
        # print(sprintf("[UCACHE_HELPER] R6 package loaded: %s", requireNamespace("R6", quietly = TRUE)))

        stop(e) # Re-throw the error
      }
    )
  } else {
    # print("[UCACHE_HELPER] Using existing cache manager instance")
  }

  CACHE_MANAGER
}

#' Initialize the unified cache manager
#' @param config Cache configuration
#' @return The initialized UnifiedCacheManager instance
initialize_unified_cache <- function(config) {
  # Create a new UnifiedCacheManager
  CACHE_MANAGER <<- UnifiedCacheManager$new(config)

  # Return the instance
  CACHE_MANAGER
}

#' Normalize a file path for consistency
#' @param path Path to normalize
#' @return Normalized path
normalize_path <- function(path) {
  # Handle NULL or empty paths
  if (is.null(path) || path == "") {
    return("cache")
  }

  # Ensure path is a character vector
  if (!is.character(path)) {
    warning("Path is not a character string, converting")
    path <- as.character(path)
  }

  # Ensure path starts with ./ or / for better consistency
  if (!grepl("^(\\./|/)", path)) {
    path <- paste0("./", path)
  }

  # Remove trailing slashes
  path <- gsub("/+$", "", path)

  # Replace backslashes with forward slashes for cross-platform compatibility
  path <- gsub("\\\\", "/", path)

  return(path)
}
