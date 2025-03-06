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
            private$error_boundaries <- list()
        },

        #' @description Register error boundary for a page
        #' @param page_id Character: page identifier
        #' @param session Shiny session object
        #' @param output Shiny output object
        register_error_boundary = function(page_id, session, output) {
            if (!is.null(session) && !is.null(output)) {
                # Create a simulation boundary for the adapter
                private$error_boundaries[[page_id]] <- create_simulation_boundary(
                    session, output, page_id, "simulation", state_manager = private$store
                )
                
                print(sprintf("[SIMULATION_ADAPTER] Registered error boundary for page %s", page_id))
            }
            invisible(self)
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
            
            # Get Shiny session
            shiny_session <- getDefaultReactiveDomain()
            
            # Check if EHE specification is loaded
            if (!is.null(shiny_session$userData$is_ehe_spec_loaded) && 
                !shiny_session$userData$is_ehe_spec_loaded()) {
                
                print("EHE specification not loaded. Creating pending simulation...")
                
                # Create initial simulation state
                sim_id <- private$store$add_simulation(
                    mode = mode,
                    settings = settings,
                    results = list(simset = NULL, transformed = NULL)
                )
                
                # Update to pending status
                private$store$update_simulation(sim_id, list(status = "pending"))
                
                # Set as current simulation for the page
                private$store$set_current_simulation(mode, sim_id)
                
                # Show loading notification
                shiny::showNotification(
                    "Loading simulation environment before running...",
                    id = "loading_sim_env",
                    duration = NULL
                )
                
                # Trigger loading the EHE specification
                if (!is.null(shiny_session$userData$load_ehe_spec)) {
                    # Load the EHE specification
                    if (shiny_session$userData$load_ehe_spec()) {
                        # Successfully loaded, remove notification
                        shiny::removeNotification(id = "loading_sim_env")
                        
                        # Now we can continue with the simulation
                        return(self$get_simulation_data(settings, mode))
                    } else {
                        # Loading failed
                        shiny::removeNotification(id = "loading_sim_env")
                        shiny::showNotification(
                            "Failed to load simulation environment. Please try again later.",
                            type = "error",
                            duration = NULL
                        )
                        
                        return(sim_id)
                    }
                } else {
                    # Can't load the EHE specification
                    shiny::removeNotification(id = "loading_sim_env")
                    shiny::showNotification(
                        "Cannot load simulation environment.",
                        type = "error",
                        duration = NULL
                    )
                    
                    return(sim_id)
                }
            }
            
            # First check if we have a matching simulation
            existing_sim_id <- private$store$find_matching_simulation(settings, mode)
            if (!is.null(existing_sim_id)) {
                print(paste0("[SIMULATION_ADAPTER] Using existing simulation with ID: ", existing_sim_id))
                
                # Check if existing simulation has error status
                sim_state <- private$store$get_simulation(existing_sim_id)
                if (sim_state$status == "error") {
                    # If sim has error and we have an error boundary, set it
                    if (!is.null(private$error_boundaries[[mode]])) {
                        private$error_boundaries[[mode]]$set_error(
                            message = sim_state$error_message,
                            type = ERROR_TYPES$SIMULATION,
                            severity = SEVERITY_LEVELS$ERROR
                        )
                    }
                    
                    # Set as current simulation for the page
                    private$store$set_current_simulation(mode, existing_sim_id)
                    
                    # Still return the ID so page can handle appropriately
                    return(existing_sim_id)
                }
                
                # Set as current simulation for the page
                private$store$set_current_simulation(mode, existing_sim_id)
                return(existing_sim_id)
            }
            
            print("[SIMULATION_ADAPTER] Creating new simulation")
            
            # Clear any existing error for this page/mode
            if (!is.null(private$error_boundaries[[mode]])) {
                private$error_boundaries[[mode]]$clear()
            }
            
            # Get relevant configs
            page_config <- get_page_complete_config(mode)
            sim_config <- page_config[[paste0(mode, "_simulations")]]
            
            # Initialize provider with config and mode
            # Get the simulation_root from base config
            base_config <- get_base_config()
            root_dir <- base_config$simulation_root %||% "simulations"  
            
            provider <- LocalProvider$new(
                root_dir,  # Use the configured root directory
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
            
            # TEST CASES - Force errors for testing purposes
            if (identical(settings$location, "test_error")) {
                print("[TEST] Forcing a simulation error for testing")
                
                # Create a test error message
                error_message <- "TEST ERROR: This is a forced error for testing purposes"
                
                # Update with error status
                private$store$update_simulation(
                    sim_id,
                    list(
                        status = "error",
                        error_message = error_message
                    )
                )
                
                # If we have an error boundary, set the error
                if (!is.null(private$error_boundaries[[mode]])) {
                    private$error_boundaries[[mode]]$set_error(
                        message = error_message,
                        type = ERROR_TYPES$SIMULATION,
                        severity = SEVERITY_LEVELS$ERROR
                    )
                }
                
                # Return the ID for proper state management
                return(sim_id)
            }
            
            # TEST CASE - Pre-existing error
            if (identical(settings$location, "test_existing_error")) {
                # Create an error simulation and return it
                print("[TEST] Creating a pre-existing simulation with error")
                
                # Update with error status
                private$store$update_simulation(
                    sim_id,
                    list(
                        status = "error",
                        error_message = "TEST ERROR: This is a pre-existing simulation error"
                    )
                )
                
                # Use error boundary to communicate error
                if (!is.null(private$error_boundaries[[mode]])) {
                    private$error_boundaries[[mode]]$set_error(
                        message = "TEST ERROR: This is a pre-existing simulation error",
                        type = ERROR_TYPES$SIMULATION,
                        severity = SEVERITY_LEVELS$ERROR
                    )
                }
                
                return(sim_id)
            }
            
            # TEST CASE - Transform error
            if (identical(settings$location, "test_transform_error")) {
                # Create a simulation with missing properties that will fail transformation
                print("[TEST] Creating a simulation that will cause a transform error")
                
                # Get a minimal simset that will cause transform errors
                dummy_simset <- list()
                class(dummy_simset) <- "simset"
                
                # Update with the dummy simset
                private$store$update_simulation(
                    sim_id,
                    list(
                        results = list(
                            simset = dummy_simset,
                            transformed = NULL
                        ),
                        status = "complete"
                    )
                )
                
                return(sim_id)
            }
            
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
                
                # Explicitly try to cache the completed simulation
                tryCatch({
                    # Only cache custom simulations, not prerun ones
                    if (mode == "custom") {
                        print("[SIMULATION_ADAPTER] Explicitly caching completed simulation")
                        sim_state <- private$store$get_simulation(sim_id)
                        cache_simulation(settings, mode, sim_state)
                    } else {
                        print("[SIMULATION_ADAPTER] Skipping cache for prerun simulation (already saved as simset)")
                    }
                }, error = function(e) {
                    print(sprintf("[SIMULATION_ADAPTER] Error caching simulation: %s", e$message))
                })
                
                # Clear any errors that might have been set
                if (!is.null(private$error_boundaries[[mode]])) {
                    private$error_boundaries[[mode]]$clear()
                }
                
                sim_id
            }, error = function(e) {
                # Convert error message to string and ensure it is properly formatted
                error_message <- as.character(conditionMessage(e))
                
                # 1. Update simulation state with error info
                private$store$update_simulation(
                    sim_id,
                    list(
                        status = "error",
                        error_message = error_message
                    )
                )
                
                # 2. Use error boundary for structured error communication
                if (!is.null(private$error_boundaries[[mode]])) {
                    private$error_boundaries[[mode]]$set_error(
                        message = error_message,
                        type = ERROR_TYPES$SIMULATION,
                        severity = SEVERITY_LEVELS$ERROR,
                        details = as.character(e)  # Include full error details
                    )
                }
                
                # Return the simulation ID despite the error
                # This allows proper state management
                sim_id
            })
        }
    ),
    private = list(
        store = NULL,
        error_boundaries = NULL
    )
)

# Create global instance
SIMULATION_ADAPTER <- SimulationAdapter$new(get_store())

#' Helper function to get adapter instance
#' @return SimulationAdapter instance
get_simulation_adapter <- function() {
    SIMULATION_ADAPTER
}