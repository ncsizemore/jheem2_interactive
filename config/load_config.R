# Load and process configuration
library(yaml)

#' Load intervention configuration for a given page type
#' @param page_type String: either "prerun" or "custom", defaulting to "prerun"
#' @return Environment containing processed configuration
get_intervention_config <- function(page_type = "prerun") {
    # Read YAML file
    config_path <- file.path("config", "interventions", paste0(page_type, ".yaml"))
    
    tryCatch({
        config <- yaml::read_yaml(config_path)
    }, error = function(e) {
        stop(sprintf("Error reading configuration file %s: %s", config_path, e$message))
    })
    
    # Convert to environment for compatibility
    env <- new.env(parent = baseenv())
    
    # Process each selector configuration
    for (selector_name in names(config$selectors)) {
        selector_config <- config$selectors[[selector_name]]
        
        # Convert options to format matching current code
        options_list <- selector_config$options
        
        # Add to environment with expected naming convention
        env[[toupper(selector_name)]] <- options_list
    }
    
    # Add UI configurations for access
    env$UI_CONFIG <- lapply(config$selectors, function(x) x$ui)
    
    env
}

#' Load layout configuration
#' @return List containing layout configuration
load_layout_config <- function() {
    config_path <- file.path("config", "layout.yaml")
    tryCatch({
        yaml::read_yaml(config_path)
    }, error = function(e) {
        stop(sprintf("Error reading layout config file %s: %s", config_path, e$message))
    })
}