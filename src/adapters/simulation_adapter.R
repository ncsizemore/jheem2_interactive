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
            private$sessions <- list()  # Store sessions to access UI messenger for progress updates
        },

        #' @description Register error boundary for a page
        #' @param page_id Character: page identifier
        #' @param session Shiny session object - Also used to access UI messenger for progress updates
        #' @param output Shiny output object
        #' 
        #' This method not only registers error boundaries but also stores the session object
        #' which is crucial for the dual approach to progress tracking. The stored session
        #' allows us to access the UI messenger even when the main thread is blocked.
        register_error_boundary = function(page_id, session, output) {
            if (!is.null(session) && !is.null(output)) {
                # Create a simulation boundary for the adapter
                private$error_boundaries[[page_id]] <- create_simulation_boundary(
                    session, output, page_id, "simulation",
                    state_manager = private$store
                )
                
                # Store the session for this page
                private$sessions[[page_id]] <- session

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

                return(sim_id)
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

            # Use the provider type from configuration
            provider_type <- sim_config$provider %||% "local"
            print(sprintf("[SIMULATION_ADAPTER] Using provider type: %s for mode: %s", provider_type, mode))

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

            tryCatch(
                {
                    # Load base simset
                    simset <- provider$load_simset(settings)

                    # For custom mode, run intervention
                    if (mode == "custom") {
                        print("Creating intervention...")
                        intervention <- create_intervention(settings, mode)
                        print("Created intervention:")
                        str(intervention)
                        runner <- SimulationRunner$new(provider)
                        
                        # Store a copy of the original base simulation for comparison
                        original_base_simset <- simset
                        print("=== DEBUG: original_base_simset storage ===")
                        print(paste("Original base simset class:", paste(class(original_base_simset), collapse=", ")))
                        print(paste("Original base simset exists:", exists("original_base_simset")))
                        print("Stored original base simulation for baseline comparison")
                        
                        # Create progress callback
                        progress_callback <- function(index, total, done) {
                            # Calculate progress percentage
                            percent <- 0
                            if (total > 0) {
                                percent <- round(min(100, (index / total) * 100))
                            }
                            
                            # Create progress state for the store
                            progress_state <- create_simulation_progress(
                                current = index,
                                total = total,
                                percentage = percent,
                                done = done
                            )
                            
                            # DUAL APPROACH FOR PROGRESS TRACKING
                            # 1. Update the state store for architectural consistency
                            # This maintains the standard state management pattern but won't update the UI
                            # when the main R thread is blocked during simulation
                            private$store$update_simulation(sim_id, list(
                                progress = progress_state
                            ))
                            
                            # 2. Send direct UI updates via UI Messenger to bypass Shiny's reactive system
                            # This ensures real-time updates even when the main thread is blocked
                            if (!is.null(private$sessions[[mode]])) {
                                ui_messenger <- private$sessions[[mode]]$userData$ui_messenger
                                if (!is.null(ui_messenger)) {
                                    ui_messenger$send_simulation_progress(
                                        id = sim_id,
                                        current = index,
                                        total = total,
                                        percent = percent,
                                        description = "Running Intervention"
                                    )
                                }
                            }
                            
                            # Log progress (only for significant steps to reduce console output)
                            if (index %% 10 == 0 || index == 1 || index == total || done) {
                                print(sprintf("[SIMULATION_ADAPTER] Progress: %d/%d (%d%%) - Done: %s", 
                                              index, total, percent, done))
                            }
                        }
                        
                        # Initialize progress tracking
                        
                        # Create initial progress state with zeros 
                        initial_progress <- create_simulation_progress(0, 0, 0, FALSE)
                        
                        # DUAL APPROACH (Part 1): Store initial progress in state store
                        # This is for state consistency and will be used by components
                        # that rely on the standard state management pattern
                        private$store$update_simulation(sim_id, list(
                            progress = initial_progress
                        ))
                        
                        # DUAL APPROACH (Part 2): Send initial progress notification via UI messenger
                        # This triggers the JavaScript handlers to show the progress UI
                        # immediately, even if the main thread will be blocked
                        if (!is.null(private$sessions[[mode]])) {
                            ui_messenger <- private$sessions[[mode]]$userData$ui_messenger
                            if (!is.null(ui_messenger)) {
                                ui_messenger$send_simulation_start(
                                    id = sim_id,
                                    description = "Running Intervention"
                                )
                            }
                        }
                        
                        # Run intervention with progress tracking
                        simset <- runner$run_intervention(
                            intervention = intervention, 
                            simset = simset,
                            progress_callback = progress_callback
                        )
                    }

                    # Handle simulation completion
                    final_progress <- NULL
                    if (mode == "custom") {
                        # Create final progress state with 100% completion
                        final_progress <- create_simulation_progress(
                            current = 100,  # Arbitrary value
                            total = 100,     # Same as current for 100%
                            percentage = 100,
                            done = TRUE
                        )
                        
                        # DUAL APPROACH FOR COMPLETION:
                        # Send direct completion message via UI messenger to ensure
                        # the UI shows the completed state immediately, even if Shiny's
                        # reactive system is still blocked or processing the queue
                        if (!is.null(private$sessions[[mode]])) {
                            ui_messenger <- private$sessions[[mode]]$userData$ui_messenger
                            if (!is.null(ui_messenger)) {
                                ui_messenger$send_simulation_complete(
                                    id = sim_id,
                                    description = "Simulation Complete"
                                )
                            }
                        }
                        # The store update happens below, as part of the results update
                    }
                    
                    # Update state with results and final progress
                    update_data <- list(
                        results = list(
                            simset = simset,
                            transformed = NULL
                        ),
                        status = "complete"
                    )
                    
                    # For custom mode, include the original base simulation at top level instead of in results
                    if (mode == "custom") {
                        print("=== DEBUG: Adding original_base_simset to top level ===")
                        print(paste("Mode:", mode))
                        print(paste("original_base_simset exists:", exists("original_base_simset")))
                        if (exists("original_base_simset")) {
                            print(paste("original_base_simset class:", paste(class(original_base_simset), collapse=", ")))
                            # Store at top level of simulation state
                            update_data$original_base_simset <- original_base_simset
                            print("Added original base simulation at top level for baseline comparison")
                            # Verify it was added
                            print(paste("Verification - original_base_simset in update_data:", !is.null(update_data$original_base_simset)))
                            print(paste("Keys in update_data after adding:", paste(names(update_data), collapse=", ")))
                        } else {
                            print("WARNING: original_base_simset doesn't exist, cannot add to update_data")
                        }
                    }
                    
                    # Add progress if we have it
                    if (!is.null(final_progress)) {
                        update_data$progress <- final_progress
                    }
                    
                    # Before updating the store, check what we're sending
                    print("=== DEBUG: Before updating simulation state ===")
                    print(paste("Update contains original_base_simset:", !is.null(update_data$results$original_base_simset)))
                    print(paste("Keys in update_data$results:", paste(names(update_data$results), collapse=", ")))
                    
                    private$store$update_simulation(sim_id, update_data)
                    
                    # After update, verify what's in the store
                    print("=== DEBUG: After updating simulation state ===")
                    sim_after_update <- private$store$get_simulation(sim_id)
                    print(paste("Results has original_base_simset after update:", 
                                !is.null(sim_after_update$results$original_base_simset)))
                    print(paste("Keys in results after update:", 
                                paste(names(sim_after_update$results), collapse=", ")))

                    # Explicitly try to cache the completed simulation
                    tryCatch(
                        {
                            # Only cache custom simulations, not prerun ones
                            if (mode == "custom") {
                                print("[SIMULATION_ADAPTER] Explicitly caching completed simulation")
                                sim_state <- private$store$get_simulation(sim_id)
                                cache_simulation(settings, mode, sim_state)
                            } else {
                                print("[SIMULATION_ADAPTER] Skipping cache for prerun simulation (already saved as simset)")
                            }
                        },
                        error = function(e) {
                            print(sprintf("[SIMULATION_ADAPTER] Error caching simulation: %s", e$message))
                        }
                    )

                    # Clear any errors that might have been set
                    if (!is.null(private$error_boundaries[[mode]])) {
                        private$error_boundaries[[mode]]$clear()
                    }

                    sim_id
                },
                error = function(e) {
                    # Convert error message to string and ensure it is properly formatted
                    error_message <- as.character(conditionMessage(e))
                    
                    # Handle error state for simulation progress
                    error_progress <- NULL
                    if (mode == "custom") {
                        # Create error progress state to mark the progress as complete but failed
                        error_progress <- create_simulation_progress(
                            current = 0,
                            total = 0,
                            percentage = 0,
                            done = TRUE  # Mark as done to stop progress tracking
                        )
                        
                        # DUAL APPROACH FOR ERROR HANDLING:
                        # 1. The error state will be stored in the state store below
                        # 2. Send direct error message via UI messenger to immediately update UI
                        #    This ensures users see the error even if Shiny's reactive system is blocked
                        if (!is.null(private$sessions[[mode]])) {
                            ui_messenger <- private$sessions[[mode]]$userData$ui_messenger
                            if (!is.null(ui_messenger)) {
                                ui_messenger$send_simulation_error(
                                    id = sim_id,
                                    message = error_message,
                                    error_type = ERROR_TYPES$SIMULATION,
                                    severity = SEVERITY_LEVELS$ERROR
                                )
                            }
                        }
                    }

                    # 1. Update simulation state with error info
                    update_data <- list(
                        status = "error",
                        error_message = error_message
                    )
                    
                    # Add progress if we have it
                    if (!is.null(error_progress)) {
                        update_data$progress <- error_progress
                    }
                    
                    private$store$update_simulation(sim_id, update_data)

                    # 2. Use error boundary for structured error communication
                    if (!is.null(private$error_boundaries[[mode]])) {
                        private$error_boundaries[[mode]]$set_error(
                            message = error_message,
                            type = ERROR_TYPES$SIMULATION,
                            severity = SEVERITY_LEVELS$ERROR,
                            details = as.character(e) # Include full error details
                        )
                    }

                    # Return the simulation ID despite the error
                    # This allows proper state management
                    sim_id
                }
            )
        }
    ),
    private = list(
        store = NULL,
        error_boundaries = NULL,
        sessions = NULL  # Store sessions by page_id
    )
)

# Create global instance
SIMULATION_ADAPTER <- SimulationAdapter$new(get_store())

#' Helper function to get adapter instance
#' @return SimulationAdapter instance
get_simulation_adapter <- function() {
    SIMULATION_ADAPTER
}
