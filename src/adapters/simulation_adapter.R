source("src/data/loader.R")
source("src/core/simulation/results.R")
source("src/ui/formatters/table_formatter.R")

#' Get simulation data based on settings and mode
#' @param settings List of settings that determine the simulation
#' @param mode Either "prerun" or "custom"
#' @return jheem simulation set
get_simulation_data <- function(settings, mode = c("prerun", "custom")) {
    mode <- match.arg(mode)
    print("=== get_simulation_data ===")
    print(paste("Mode:", mode))
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

    # Load base simset
    simset <- provider$load_simset(simset_key)

    # For custom mode, run intervention
    if (mode == "custom") {
        print("Creating intervention...")
        intervention <- create_intervention(settings, mode)
        print("Created intervention:")
        str(intervention)
        runner <- SimulationRunner$new(provider)
        simset <- runner$run_intervention(intervention, simset)
    }

    simset
}
