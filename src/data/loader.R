source("src/data/providers/provider_interface.R")
source("src/data/providers/local_provider.R")
source("src/data/providers/onedrive_provider.R")
source("src/data/cache.R")

# Global provider instance
.provider <- NULL

#' Initialize the data provider
#' @param provider_type Type of provider to use ("local", "onedrive", or "aws")
#' @param ... Additional arguments passed to provider initialization
#' 
#' The root directory for simulations is determined by the following priority:
#' 1. Explicitly provided as parameter (root_dir = ...)
#' 2. From base.yaml configuration (simulation_root)
#' 3. Default "simulations" if neither of the above is available
#' 
#' This allows for branch-specific simulation directories when working with multiple
#' model versions on the same machine.
initialize_provider <- function(provider_type = "local", ...) {
    # Get current Shiny session for progress updates
    current_session <- getDefaultReactiveDomain()
    print(sprintf("[LOADER] Initialize provider with session: %s", 
                 if(is.null(current_session)) "NULL" else "valid session"))
    
    .provider <<- if (provider_type == "local") {
        LocalProvider$new(...)
    } else if (provider_type == "onedrive") {
        # Pass session parameter to OneDriveProvider
        OneDriveProvider$new(...)
    } else if (provider_type == "aws") {
        stop("AWS provider not yet implemented")
    } else {
        stop(sprintf("Unknown provider type: %s", provider_type))
    }
}

#' Get simulation data using configured provider
#' @param simset_key Identifier for the simulation set
#' @return JHEEM simulation set
load_simset <- function(simset_key) {
    if (is.null(.provider)) {
        # Get provider type from config based on mode (prerun or custom)
        mode <- if (!is.null(simset_key$intervention_mode) && simset_key$intervention_mode == "custom") {
            "custom"
        } else {
            "prerun"
        }
        
        tryCatch({
            # Load appropriate config based on mode
            if (mode == "custom") {
                config <- get_page_complete_config("custom")$custom_simulations
                provider_type <- config$provider %||% "local"
                print(sprintf("Initializing %s provider for custom mode", provider_type))
                initialize_provider(provider_type, config = config, mode = "custom")
            } else {
                config <- get_page_complete_config("prerun")$prerun_simulations
                provider_type <- config$provider %||% "local"
                print(sprintf("Initializing %s provider for prerun mode", provider_type))
                initialize_provider(provider_type, config = config, mode = "prerun")
            }
        }, error = function(e) {
            print(sprintf("Error getting provider config: %s", e$message))
            initialize_provider()
        })
    }
    .provider$load_simset(simset_key)
}
