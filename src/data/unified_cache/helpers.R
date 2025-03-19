# Helper functions for the UnifiedCacheManager

# Global instance
CACHE_MANAGER <- NULL

#' Get the UnifiedCacheManager instance
#' @return UnifiedCacheManager instance
get_cache_manager <- function() {
  print("[UCACHE_HELPER] Getting cache manager instance")
  
  if (is.null(CACHE_MANAGER)) {
    print("[UCACHE_HELPER] No existing instance, creating new one")
    
    # Source the manager if needed
    if (!exists("UnifiedCacheManager")) {
      print("[UCACHE_HELPER] Sourcing manager.R file")
      tryCatch({
        source("src/data/unified_cache/manager.R")
        print("[UCACHE_HELPER] Successfully sourced manager.R")
      }, error = function(e) {
        print(sprintf("[UCACHE_HELPER] Error sourcing manager.R: %s", e$message))
        stop(e)
      })
    }
    
    # Create instance with config
    print("[UCACHE_HELPER] Getting cache config")
    config <- tryCatch({
      get_component_config("caching")
    }, error = function(e) {
      print(sprintf("[UCACHE_HELPER] Error loading config: %s", e$message))
      NULL
    })
    
    print("[UCACHE_HELPER] Creating UnifiedCacheManager instance")
    tryCatch({
      CACHE_MANAGER <<- UnifiedCacheManager$new(config)
      print("[UCACHE_HELPER] Successfully created cache manager")
    }, error = function(e) {
      print(sprintf("[UCACHE_HELPER] Error creating cache manager: %s", e$message))
      # Also print stack trace
      print(traceback())
      stop(e)
    })
  } else {
    print("[UCACHE_HELPER] Using existing cache manager instance")
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
