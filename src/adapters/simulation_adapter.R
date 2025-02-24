source("src/data/loader.R")
source("src/core/simulation/runner.R")
source("src/core/simulation/results.R")
source("src/ui/formatters/table_formatter.R")

#' Simulation Adapter Class
#' @description Handles simulation operations with state management
SimulationAdapter <- R6::R6Class(
    "SimulationAdapter",
    public = list(
        #' @description Initialize the adapter
        #' @param store StateStore instance
        initialize = function(store) {
            private$store <- store
        },

        #' @description Get simulation data based on settings and mode
        #' @param settings List of settings that determine the simulation
        #' @param mode Either "prerun" or "custom"
        #' @return Character: simulation ID
        get_simulation_data = function(settings, mode = c("prerun", "custom")) {
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

            # Create initial simulation state
            sim_id <- private$store$add_simulation(
                mode = mode,
                settings = settings,
                results = list(simset = NULL, transformed = NULL)
            )

            # Update to running status
            private$store$update_simulation(sim_id, list(status = "running"))
            
            tryCatch({
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
                
                # Update state with results
                private$store$update_simulation(
                    sim_id,
                    list(
                        results = list(
                            simset = simset,
                            transformed = NULL
                        ),
                        status = "complete"
                    )
                )
                
                sim_id
            }, error = function(e) {
                private$store$update_simulation(
                    sim_id,
                    list(
                        status = "error",
                        error_message = e$message
                    )
                )
                stop(e)
            })
        }
    ),
    private = list(
        store = NULL
    )
)

# Create global instance
SIMULATION_ADAPTER <- SimulationAdapter$new(get_store())

#' Helper function to get adapter instance
#' @return SimulationAdapter instance
get_simulation_adapter <- function() {
    SIMULATION_ADAPTER
}