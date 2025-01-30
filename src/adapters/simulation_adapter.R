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

    # For now, use a fixed simset key for testing
    simset_key <- "init.pop.ehe_simset_2024-12-16_C.12580"
    simset <- load_simset(simset_key)

    print(paste("Loaded simulation data of class:", class(simset)[1]))
    return(simset)
}
