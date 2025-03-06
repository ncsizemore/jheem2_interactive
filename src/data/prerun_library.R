# Pre-run simulation library functionality
# This module provides access to pre-computed simulations

#' Get available pre-run simulation scenarios
#' @return Data frame with available scenarios
get_available_scenarios <- function() {
  config <- tryCatch({
    get_component_config("caching")$prerun_library
  }, error = function(e) {
    # Use default if config not found
    list(
      provider = "disk",
      path = "simulations"
    )
  })
  
  if (config$provider == "disk") {
    # Look for .Rdata files in the local directory
    sim_path <- config$path
    if (!dir.exists(sim_path)) {
      warning(sprintf("Pre-run simulation directory '%s' not found", sim_path))
      return(data.frame())
    }
    
    # List .Rdata files
    files <- list.files(sim_path, pattern = "\\.Rdata$", full.names = FALSE)
    
    # Create simple data frame with available files
    scenarios <- data.frame(
      id = sub("\\.Rdata$", "", files),
      filename = files,
      stringsAsFactors = FALSE
    )
    
    return(scenarios)
  } else if (config$provider == "aws") {
    # This will be implemented in Phase 6
    warning("AWS provider for pre-run simulations not yet implemented")
    return(data.frame())
  } else {
    warning(sprintf("Unknown pre-run provider: %s", config$provider))
    return(data.frame())
  }
}

#' Load a pre-run simulation by ID
#' @param scenario_id ID of the scenario to load
#' @return Loaded simulation or NULL if not found
load_prerun_simulation <- function(scenario_id) {
  config <- tryCatch({
    get_component_config("caching")$prerun_library
  }, error = function(e) {
    # Use default if config not found
    list(
      provider = "disk",
      path = "simulations"
    )
  })
  
  if (config$provider == "disk") {
    # Look for .Rdata file in the local directory
    sim_path <- config$path
    sim_file <- file.path(sim_path, paste0(scenario_id, ".Rdata"))
    
    if (!file.exists(sim_file)) {
      warning(sprintf("Pre-run simulation file '%s' not found", sim_file))
      return(NULL)
    }
    
    # Create a new environment to load the simulation into
    sim_env <- new.env()
    
    # Load the .Rdata file into the environment
    load(sim_file, envir = sim_env)
    
    # Examine what was loaded
    sim_objects <- ls(sim_env)
    print(sprintf("Loaded simulation objects: %s", paste(sim_objects, collapse = ", ")))
    
    # Look for a simulation object - this would need to be adapted based on actual file structure
    if ("simulation" %in% sim_objects) {
      return(sim_env$simulation)
    } else if (length(sim_objects) == 1) {
      # If there's only one object, return that
      return(get(sim_objects[1], envir = sim_env))
    } else {
      # Return the whole environment if we can't identify a specific object
      warning("Could not identify specific simulation object, returning environment")
      return(sim_env)
    }
  } else if (config$provider == "aws") {
    # This will be implemented in Phase 6
    warning("AWS provider for pre-run simulations not yet implemented")
    return(NULL)
  } else {
    warning(sprintf("Unknown pre-run provider: %s", config$provider))
    return(NULL)
  }
}

#' Check if a pre-run simulation exists
#' @param scenario_id ID of the scenario to check
#' @return TRUE if simulation exists, FALSE otherwise
has_prerun_simulation <- function(scenario_id) {
  config <- tryCatch({
    get_component_config("caching")$prerun_library
  }, error = function(e) {
    # Use default if config not found
    list(
      provider = "disk",
      path = "simulations"
    )
  })
  
  if (config$provider == "disk") {
    # Check if .Rdata file exists in the local directory
    sim_path <- config$path
    sim_file <- file.path(sim_path, paste0(scenario_id, ".Rdata"))
    
    return(file.exists(sim_file))
  } else if (config$provider == "aws") {
    # This will be implemented in Phase 6
    warning("AWS provider for pre-run simulations not yet implemented")
    return(FALSE)
  } else {
    warning(sprintf("Unknown pre-run provider: %s", config$provider))
    return(FALSE)
  }
}
