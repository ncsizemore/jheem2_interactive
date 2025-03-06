source("src/data/providers/provider_interface.R")
source("src/data/providers/local_provider.R")
source("src/data/cache.R")

# Global provider instance
.provider <- NULL

#' Initialize the data provider
#' @param provider_type Type of provider to use ("local" or "aws")
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
    .provider <<- if (provider_type == "local") {
        LocalProvider$new(...)
    } else {
        stop("AWS provider not yet implemented")
    }
}

#' Get simulation data using configured provider
#' @param simset_key Identifier for the simulation set
#' @return JHEEM simulation set
load_simset <- function(simset_key) {
    if (is.null(.provider)) {
        initialize_provider()
    }
    .provider$load_simset(simset_key)
}
