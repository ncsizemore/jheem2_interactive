# Load and process configuration
library(yaml)

load_intervention_config <- function() {
    # Read YAML file
    config_path <- "config/interventions.yaml"
    config <- yaml::read_yaml(config_path)
    
    # Convert to environment for compatibility with existing code
    env <- new.env(parent = baseenv())
    
    # Process each selector configuration
    for (selector_name in names(config$selectors)) {
        selector_config <- config$selectors[[selector_name]]
        
        # Convert options to format matching current code
        options_list <- selector_config$options
        
        # Add to environment with expected naming convention
        # e.g., INTERVENTION_ASPECTS, TIMEFRAMES, etc.
        env[[toupper(selector_name)]] <- options_list
    }
    
    # Add UI configurations for access
    env$UI_CONFIG <- lapply(config$selectors, function(x) x$ui)
    
    env
}

# Usage:
# CONFIG <- load_intervention_config()