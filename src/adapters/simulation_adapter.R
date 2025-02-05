source("src/data/loader.R")
source("src/core/simulation/results.R")
source("src/ui/formatters/table_formatter.R")

#' Get simulation data based on settings and mode
#' @param settings List of settings that determine the simulation
#' @param mode Either "prerun" or "custom"
#' @return jheem simulation set
get_simulation_data <- function(settings, mode = c("prerun", "custom")) {
    mode <- match.arg(mode)
    print(paste("Getting simulation data for mode:", mode))
    print("Settings:")
    str(settings)

    # Initialize provider
    provider <- LocalProvider$new("simulations")

    # For development/testing, use test simset
    if (is.null(settings) || is.null(settings$location)) {
        return(provider$load_test_simset())
    }

    # TODO: Get these from config when implemented
    version <- "v1"
    calibration <- "baseline"

    simset_key <- paste(
        settings$location,
        version,
        calibration,
        sep = "_"
    )

    # Load through provider
    provider$load_simset(simset_key)
}
