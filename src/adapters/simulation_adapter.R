source("src/data/loader.R")
source("src/core/simulation/runner.R")
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

    # Get relevant configs
    page_config <- get_page_complete_config(mode)
    sim_config <- page_config[[paste0(mode, "_simulations")]]
    
    # Initialize provider with config and mode
    provider <- LocalProvider$new(
        "simulations",
        config = sim_config,
        mode = mode
    )
    
    # Load base simset
    simset <- provider$load_simset(settings)
    
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