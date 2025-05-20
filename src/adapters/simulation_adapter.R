source("src/data/loader.R")
source("src/core/simulation/runner.R")
source("src/core/simulation/results.R")
source("src/ui/formatters/table_formatter.R")
source("src/ui/state/types.R") # For create_simulation_progress

#' Simulation Adapter Class
#' @description Handles simulation operations with state management
#'
#' This adapter implements a dual approach for progress tracking:
#' 1. State Store Updates: Store progress in the central state store
#'    for architectural consistency and standard state management.
#' 2. Direct UI Messaging: Send progress updates directly to the browser
#'    via UI Messenger, bypassing Shiny's reactive system when the main
#'    thread is blocked during long-running simulations.
#'
#' The dual approach is necessary because Shiny's reactive system cannot
#' update the UI while the main R thread is blocked during simulation runs.
SimulationAdapter <- R6::R6Class(
    "SimulationAdapter",
    public = list(
        #' @description Initialize the adapter
        #' @param store StateStore instance
        initialize = function(store) {
            private$store <- store
            private$error_boundaries <- list()
            private$sessions <- list() # Store sessions to access UI messenger for progress updates
        },

        #' @description Register error boundary for a page
        #' @param page_id Character: page identifier
        #' @param session Shiny session object - Also used to access UI messenger for progress updates
        #' @param output Shiny output object
        #' @param vis_manager Optional visualization manager for state management
        #'
        #' This method not only registers error boundaries but also stores the session object
        #' which is crucial for the dual approach to progress tracking. The stored session
        #' allows us to access the UI messenger even when the main thread is blocked.
        register_error_boundary = function(page_id, session, output, vis_manager = NULL) {
            if (!is.null(session) && !is.null(output)) {
                # Determine which state manager to use
                state_manager <- if (!is.null(vis_manager)) {
                    print(sprintf("[SIMULATION_ADAPTER] Using visualization manager for error boundary of page %s", page_id))
                    vis_manager
                } else {
                    print(sprintf("[SIMULATION_ADAPTER] Using store for error boundary of page %s", page_id))
                    private$store
                }

                # Create a simulation boundary for the adapter
                private$error_boundaries[[page_id]] <- create_simulation_boundary(
                    session, output, page_id, "simulation",
                    state_manager = state_manager
                )

                # Store the session for this page
                private$sessions[[page_id]] <- session

                print(sprintf("[SIMULATION_ADAPTER] Registered error boundary for page %s", page_id))
            }
            invisible(self)
        },

        #' @description Get simulation data based on settings and mode (potentially asynchronously)
        #' @param settings List of settings that determine the simulation
        #' @param mode Either "prerun" or "custom"
        #' @return A promise that resolves with the simulation ID, or the ID directly if no async needed.
        get_simulation_data = function(settings, mode = c("prerun", "custom")) {
            mode <- match.arg(mode)
            print("=== get_simulation_data (ASYNC WRAPPER) ===")
            print(paste("Mode:", mode))
            print("Settings:")
            str(settings)

            # Make sure the error boundary exists for this mode
            if (is.null(private$error_boundaries[[mode]])) {
                print(sprintf("[WARNING] No error boundary found for mode: %s", mode))
            }


            # Get current model state
            store_model_state <- private$store$get_model_state()
            model_status <- store_model_state$status

            if (model_status != "loaded") {
                print(paste("Model not ready. Current status:", model_status))

                # Create initial simulation state
                sim_id <- private$store$add_simulation(
                    mode = mode,
                    settings = settings,
                    results = list(simset = NULL, transformed = NULL)
                )

                # Update to proper status based on model status
                if (model_status == "loading") {
                    # Still loading - mark as pending
                    private$store$update_simulation(sim_id, list(status = "pending"))

                    # Show notification
                    shiny::showNotification(
                        "Model environment is still loading. Simulation will be queued to run after loading completes.",
                        id = "model_loading_wait",
                        duration = 5,
                        type = "message"
                    )
                } else if (model_status == "error") {
                    # Error loading model - mark simulation as error
                    private$store$update_simulation(sim_id, list(
                        status = "error",
                        error_message = paste(
                            "Cannot run simulation: Model failed to load.",
                            store_model_state$error_message
                        )
                    ))

                    # Show notification
                    shiny::showNotification(
                        paste(
                            "Cannot run simulation: Model loading failed.",
                            store_model_state$error_message
                        ),
                        type = "error",
                        duration = 8
                    )
                }

                # Set as current simulation for the page
                private$store$set_current_simulation(mode, sim_id)

                # Return a resolved promise as no async operation happened here
                return(promises::promise_resolve(sim_id))
            }

            # First check if we have a matching simulation (this now returns a promise)
            sim_id_promise <- private$store$find_matching_simulation(settings, mode)

            # Chain the rest of the logic onto the promise
            sim_id_promise %...>% (function(existing_sim_id) { # Added parentheses
                if (!is.null(existing_sim_id)) {
                    print(paste0("[SIMULATION_ADAPTER ASYNC] Using existing/loaded simulation with ID: ", existing_sim_id))

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

                # --- If no existing simulation found, create a new one ---
                print("[SIMULATION_ADAPTER ASYNC] Creating new simulation")

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

                # Use the provider type from configuration
                provider_type <- sim_config$provider %||% "local"
                print(sprintf("[SIMULATION_ADAPTER ASYNC] Using provider type: %s for mode: %s", provider_type, mode))

                # Initialize the provider using loader.R's initialize_provider function
                initialize_provider(provider_type,
                    root_dir = root_dir,
                    config = sim_config,
                    mode = mode
                )

                # Get the initialized provider
                provider <- .provider

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
                    error_message <- "TEST ERROR: This is a forced error for testing purposes"
                    private$store$update_simulation(sim_id, list(status = "error", error_message = error_message))
                    if (!is.null(private$error_boundaries[[mode]])) {
                        private$error_boundaries[[mode]]$set_error(message = error_message, type = ERROR_TYPES$SIMULATION, severity = SEVERITY_LEVELS$ERROR)
                    }
                    return(sim_id) # Return ID even on forced error
                }
                if (identical(settings$location, "test_existing_error")) {
                    print("[TEST] Creating a pre-existing simulation with error")
                    private$store$update_simulation(sim_id, list(status = "error", error_message = "TEST ERROR: This is a pre-existing simulation error"))
                    if (!is.null(private$error_boundaries[[mode]])) {
                        private$error_boundaries[[mode]]$set_error(message = "TEST ERROR: This is a pre-existing simulation error", type = ERROR_TYPES$SIMULATION, severity = SEVERITY_LEVELS$ERROR)
                    }
                    return(sim_id) # Return ID even on forced error
                }
                if (identical(settings$location, "test_transform_error")) {
                    print("[TEST] Creating a simulation that will cause a transform error")
                    dummy_simset <- list()
                    class(dummy_simset) <- "simset"
                    private$store$update_simulation(sim_id, list(results = list(simset = dummy_simset, transformed = NULL), status = "complete"))
                    return(sim_id) # Return ID even on forced error
                }

                # --- Run the actual simulation (potentially long running) ---
                # Note: This part remains synchronous for now. If simulation RUNNING is also slow,
                # this would need to be wrapped in a future_promise as well.
                tryCatch(
                    {
                        # Load base simset
                        print("[SIMULATION_ADAPTER ASYNC] Loading base simset from provider")
                        simset <- provider$load_simset(settings)
                        print("[SIMULATION_ADAPTER ASYNC] Successfully loaded simset!")

                        # For custom mode, run intervention
                        if (mode == "custom") {
                            print("Creating intervention...")
                            intervention <- create_intervention(settings, mode)
                            print("Created intervention:")
                            str(intervention)
                            runner <- SimulationRunner$new(provider)

                            # Store a copy of the original base simulation for comparison
                            original_base_simset <- simset
                            print("[SIMULATION_ADAPTER ASYNC] Stored original base simulation for baseline comparison")

                            # DEBUG: Examine everything right before running the intervention
                            browser()

                            # Create progress callback (remains the same, uses dual approach)
                            progress_callback <- function(index, total, done) {
                                percent <- 0
                                if (total > 0) {
                                    percent <- round(min(100, (index / total) * 100))
                                }
                                progress_state <- create_simulation_progress(current = index, total = total, percentage = percent, done = done)
                                private$store$update_simulation(sim_id, list(progress = progress_state))
                                if (!is.null(private$sessions[[mode]])) {
                                    ui_messenger <- private$sessions[[mode]]$userData$ui_messenger
                                    if (!is.null(ui_messenger)) {
                                        ui_messenger$send_simulation_progress(id = sim_id, current = index, total = total, percent = percent, description = "Running Intervention")
                                    }
                                }
                                if (index %% 10 == 0 || index == 1 || index == total || done) {
                                    print(sprintf("[SIMULATION_ADAPTER ASYNC] Progress: %d/%d (%d%%) - Done: %s", index, total, percent, done))
                                }
                            }

                            # Initialize progress tracking (remains the same, uses dual approach)
                            initial_progress <- create_simulation_progress(0, 0, 0, FALSE)
                            private$store$update_simulation(sim_id, list(progress = initial_progress))
                            if (!is.null(private$sessions[[mode]])) {
                                ui_messenger <- private$sessions[[mode]]$userData$ui_messenger
                                if (!is.null(ui_messenger)) {
                                    ui_messenger$send_simulation_start(id = sim_id, description = "Running Intervention")
                                }
                            }

                            # Run intervention with progress tracking
                            simset <- runner$run_intervention(intervention = intervention, simset = simset, progress_callback = progress_callback)
                        }

                        # Handle simulation completion (remains the same, uses dual approach)
                        final_progress <- NULL
                        if (mode == "custom") {
                            final_progress <- create_simulation_progress(current = 100, total = 100, percentage = 100, done = TRUE)
                            if (!is.null(private$sessions[[mode]])) {
                                ui_messenger <- private$sessions[[mode]]$userData$ui_messenger
                                if (!is.null(ui_messenger)) {
                                    ui_messenger$send_simulation_complete(id = sim_id, description = "Simulation Complete")
                                }
                            }
                        }

                        # Update state with results and final progress
                        update_data <- list(results = list(simset = simset, transformed = NULL), status = "complete")
                        if (mode == "custom" && exists("original_base_simset")) {
                            update_data$original_base_simset <- original_base_simset
                        }
                        if (!is.null(final_progress)) {
                            update_data$progress <- final_progress
                        }
                        private$store$update_simulation(sim_id, update_data)

                        # Explicitly try to cache the completed simulation
                        tryCatch(
                            {
                                if (mode == "custom") {
                                    print("[SIMULATION_ADAPTER ASYNC] Explicitly caching completed simulation")
                                    sim_state <- private$store$get_simulation(sim_id)
                                    cache_simulation(settings, mode, sim_state) # Assuming this is synchronous for now
                                } else {
                                    print("[SIMULATION_ADAPTER ASYNC] Skipping cache for prerun simulation")
                                }
                            },
                            error = function(e) {
                                print(sprintf("[SIMULATION_ADAPTER ASYNC] Error caching simulation: %s", e$message))
                            }
                        )

                        # Clear any errors
                        if (!is.null(private$error_boundaries[[mode]])) {
                            private$error_boundaries[[mode]]$clear()
                        }

                        return(sim_id) # Return the ID of the newly run simulation
                    },
                    error = function(e) {
                        # Handle errors during simulation run
                        error_message <- as.character(conditionMessage(e))
                        error_progress <- NULL
                        if (mode == "custom") {
                            error_progress <- create_simulation_progress(current = 0, total = 0, percentage = 0, done = TRUE)
                            if (!is.null(private$sessions[[mode]])) {
                                ui_messenger <- private$sessions[[mode]]$userData$ui_messenger
                                if (!is.null(ui_messenger)) {
                                    ui_messenger$send_simulation_error(id = sim_id, message = error_message, error_type = ERROR_TYPES$SIMULATION, severity = SEVERITY_LEVELS$ERROR)
                                }
                            }
                        }
                        update_data <- list(status = "error", error_message = error_message)
                        if (!is.null(error_progress)) {
                            update_data$progress <- error_progress
                        }
                        private$store$update_simulation(sim_id, update_data)
                        if (!is.null(private$error_boundaries[[mode]])) {
                            private$error_boundaries[[mode]]$set_error(message = error_message, type = ERROR_TYPES$SIMULATION, severity = SEVERITY_LEVELS$ERROR, details = as.character(e))
                        }
                        return(sim_id) # Return ID even on error
                    }
                ) # End outer tryCatch for simulation run
            }) %...!% (function(error) { # Added parentheses
                # Handle errors from the find_matching_simulation promise itself
                print(sprintf("[SIMULATION_ADAPTER ASYNC] Error finding/loading simulation: %s", error$message))
                # Create a dummy simulation entry with error status
                error_sim_id <- private$store$add_simulation(mode = mode, settings = settings, results = NULL)
                private$store$update_simulation(error_sim_id, list(status = "error", error_message = paste("Failed to find or load simulation:", error$message)))
                if (!is.null(private$error_boundaries[[mode]])) {
                    private$error_boundaries[[mode]]$set_error(message = paste("Failed to find or load simulation:", error$message), type = ERROR_TYPES$SIMULATION, severity = SEVERITY_LEVELS$ERROR)
                }
                return(error_sim_id) # Return the ID of the error simulation state
            }) # Added parentheses
        }
    ),
    private = list(
        store = NULL,
        error_boundaries = NULL,
        sessions = NULL # Store sessions by page_id
    )
)

# Create global instance
SIMULATION_ADAPTER <- SimulationAdapter$new(get_store())

#' Helper function to get adapter instance
#' @return SimulationAdapter instance
get_simulation_adapter <- function() {
    SIMULATION_ADAPTER
}
