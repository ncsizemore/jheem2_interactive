# src/ui/state/store.R

library(R6)

#' State Store Class
#' @description Central state management for the application
StateStore <- R6Class("StateStore",
    public = list(
        #' @field panel_states List of ReactiveVal objects for each panel
        panel_states = NULL,

        #' @description Initialize the store
        #' @param page_ids Character vector of page identifiers
        initialize = function(page_ids = c("prerun", "custom")) {
            private$setup_panel_states(page_ids)
            private$setup_simulation_storage()
        },

        # Panel State Methods ------------------------------------------------

        #' @description Get the current state for a panel
        #' @param page_id Character: panel identifier
        #' @return Current panel state
        get_panel_state = function(page_id) {
            if (is.null(self$panel_states[[page_id]])) {
                stop(sprintf("No state found for page: %s", page_id))
            }
            self$panel_states[[page_id]]()
        },

        #' @description Update visualization state for a panel
        #' @param page_id Character: panel identifier
        #' @param visibility Character: new visibility state
        #' @param plot_status Character: new plot status
        #' @param display_type Character: display type ("plot" or "table")
        #' @param error_message Character: new error message
        update_visualization_state = function(page_id,
                                           visibility = NULL,
                                           plot_status = NULL,
                                           display_type = NULL,
                                           error_message = NULL) {
            current_state <- self$get_panel_state(page_id)

            # Only update provided fields
            if (!is.null(visibility)) {
                current_state$visualization$visibility <- visibility
            }
            if (!is.null(plot_status)) {
                current_state$visualization$plot_status <- plot_status
            }
            if (!is.null(display_type)) {
                current_state$visualization$display_type <- display_type
            }
            if (!is.null(error_message)) {
                current_state$visualization$error_message <- error_message
            }

            # Validate and update
            current_state$visualization <- validate_visualization_state(
                current_state$visualization
            )
            self$panel_states[[page_id]](current_state)

            invisible(self)
        },

        #' @description Update control state for a panel
        #' @param page_id Character: panel identifier
        #' @param settings List: complete control settings
        update_control_state = function(page_id, settings) {
            if (is.null(settings)) {
                return()
            }

            current_state <- self$get_panel_state(page_id)

            # Update control state
            current_state$controls <- validate_control_state(settings)
            self$panel_states[[page_id]](current_state)

            invisible(self)
        },

        #' @description Update validation state for a panel
        #' @param page_id Character: panel identifier
        #' @param validation_state List: new validation state
        update_validation_state = function(page_id, validation_state) {
            current_state <- self$get_panel_state(page_id)

            # Update validation state
            current_state$validation <- validate_validation_state(validation_state)
            self$panel_states[[page_id]](current_state)

            invisible(self)
        },

        #' @description Get the current simulation's data for a page
        #' @param page_id Character: panel identifier
        #' @return List containing simset and transformed data
        get_current_simulation_data = function(page_id) {
            sim_id <- self$get_current_simulation_id(page_id)
            if (is.null(sim_id)) {
                stop("No current simulation set for page: ", page_id)
            }
            sim_state <- self$get_simulation(sim_id)
            sim_state$results
        },

        #' @description Get transformed data for current simulation
        #' @param page_id Character: panel identifier
        #' @param settings List: display settings (optional)
        #' @return List containing transformed data
        get_current_transformed_data = function(page_id, settings = NULL) {
            results <- self$get_current_simulation_data(page_id)
            
            # If settings changed or no transformed data exists, transform again
            if (is.null(results$transformed) || 
                (!is.null(settings) && !identical(settings, results$transformed$settings))) {
                print(sprintf("[STATE_STORE] Transforming data for simulation with new settings for page %s", page_id))
                results$transformed <- transform_simulation_data(results$simset, settings)
                
                # Update simulation state with new transformed data
                sim_id <- self$get_current_simulation_id(page_id)
                self$update_simulation(sim_id, list(
                    results = results
                ))
            }
            
            results$transformed
        },

        #' @description Reset state for a panel
        #' @param page_id Character: panel identifier
        reset_panel_state = function(page_id) {
            self$panel_states[[page_id]](create_panel_state(page_id))
            invisible(self)
        },

        # Simulation State Methods ------------------------------------------

        #' @description Add a new simulation to the store
        #' @param mode Character: simulation mode
        #' @param settings List: simulation settings
        #' @param results List: simulation results
        #' @return Character: simulation ID
        add_simulation = function(mode, settings, results) {
            id <- private$generate_simulation_id()
            print(paste0("[STATE_STORE] Creating new simulation with ID: ", id))
            
            sim_state <- create_simulation_state(
                id = id,
                mode = mode,
                settings = settings,
                results = results
            )
            private$simulations[[id]] <- reactiveVal(sim_state)
            id
        },

        #' @description Get simulation by ID
        #' @param id Character: simulation identifier
        #' @return List: simulation state
        get_simulation = function(id) {
            if (is.null(private$simulations[[id]])) {
                stop(sprintf("No simulation found with ID: %s", id))
            }
            private$simulations[[id]]()
        },

        #' @description Update existing simulation
        #' @param id Character: simulation identifier
        #' @param updates List: fields to update
        update_simulation = function(id, updates) {
            if (is.null(private$simulations[[id]])) {
                stop(sprintf("No simulation found with ID: %s", id))
            }

            current_state <- private$simulations[[id]]()
            
            # Update provided fields
            print(sprintf("[STATE_STORE] Updating simulation %s with status: %s", 
                         id, updates$status))
            for (field in names(updates)) {
                current_state[[field]] <- updates[[field]]
            }

            # Validate and update
            current_state <- validate_simulation_state(current_state)
            private$simulations[[id]](current_state)

            invisible(self)
        },

        # Current Simulation Methods ---------------------------------------

        #' @description Find a simulation with matching settings
        #' @param settings List: simulation settings to match
        #' @param mode Character: simulation mode ("prerun" or "custom")
        #' @return Character: ID of matching simulation or NULL if no match found
        find_matching_simulation = function(settings, mode) {
            print("[STATE_STORE] Looking for matching simulation...")
            # Look through existing simulations for matching settings
            for (id in names(private$simulations)) {
                sim_state <- private$simulations[[id]]()
                
                # Only match simulations of the same mode
                if (sim_state$mode == mode) {
                    # Check if settings match
                    if (private$are_settings_equal(sim_state$settings, settings)) {
                        print(paste0("[STATE_STORE] Found matching simulation with ID: ", id))
                        return(id)
                    }
                }
            }
            
            # No match found
            print("[STATE_STORE] No matching simulation found")
            NULL
        },

        #' @description Get the current simulation ID for a panel
        #' @param page_id Character: panel identifier
        #' @return Character: current simulation ID or NULL
        get_current_simulation_id = function(page_id) {
            current_state <- self$get_panel_state(page_id)
            current_state$current_simulation_id
        },

        #' @description Update the current simulation for a panel
        #' @param page_id Character: panel identifier
        #' @param simulation_id Character: simulation identifier
        set_current_simulation = function(page_id, simulation_id) {
            if (!is.null(simulation_id)) {
                # Verify simulation exists
                if (is.null(private$simulations[[simulation_id]])) {
                    stop(sprintf("No simulation found with ID: %s", simulation_id))
                }
            }
            
            current_state <- self$get_panel_state(page_id)
            current_state$current_simulation_id <- simulation_id
            self$panel_states[[page_id]](current_state)
            
            invisible(self)
        },
        
        #' @description Clean up old simulations to prevent memory issues
        #' @param max_age Numeric: maximum age in seconds before a simulation is considered old
        #' @param force Logical: whether to force removal of referenced simulations
        #' @return Invisible self (for chaining)
        cleanup_old_simulations = function(max_age = NULL, force = FALSE) {
            # Get cleanup config
            tryCatch({
                config <- get_component_config("state_management")
                
                # Use config values if not explicitly provided
                if (is.null(max_age)) {
                    max_age <- config$cleanup$default_max_age
                }
                
                high_count_threshold <- 20 # Default fallback
                aggressive_max_age <- 900  # Default fallback: 15 minutes
                
                # Safely access config values with defaults
                if (!is.null(config$cleanup$high_count_threshold)) {
                    high_count_threshold <- config$cleanup$high_count_threshold
                }
                
                if (!is.null(config$cleanup$aggressive_max_age)) {
                    aggressive_max_age <- config$cleanup$aggressive_max_age
                }
            }, error = function(e) {
                # If config can't be loaded, use reasonable defaults
                print(sprintf("[STATE_STORE] Error loading config: %s. Using default values.", e$message))
                if (is.null(max_age)) {
                    max_age <<- 1800  # 30 minutes default
                }
                high_count_threshold <<- 20
                aggressive_max_age <<- 900
            })
            
            # Ensure max_age has a value (in case both config and parameter fail)
            if (is.null(max_age)) {
                max_age <- 1800  # 30 minutes absolute fallback
            }
            
            current_time <- Sys.time()
            
            # Get list of simulation IDs to check
            sim_ids <- names(private$simulations)
            print(sprintf("[STATE_STORE] Running cleanup. Found %d simulations to check", length(sim_ids)))
            
            # If we have too many simulations, adjust the age threshold
            if (length(sim_ids) > high_count_threshold) {
                print(sprintf("[STATE_STORE] High simulation count (%d). Using shorter retention period.", 
                               length(sim_ids)))
                max_age <- min(max_age, aggressive_max_age)
            }
            
            removed_count <- 0
            for (id in sim_ids) {
                sim_state <- private$simulations[[id]]()
                age <- difftime(current_time, sim_state$timestamp, units = "secs")
                
                # Check if simulation is old enough to remove
                age_numeric <- as.numeric(age)
                if (!is.na(age_numeric) && (age_numeric > max_age || force)) {
                    # Check if this simulation is currently being referenced
                    is_referenced <- FALSE
                    for (page_id in names(self$panel_states)) {
                        current_sim_id <- self$get_current_simulation_id(page_id)
                        if (!is.null(current_sim_id) && current_sim_id == id) {
                            is_referenced <- TRUE
                            break
                        }
                    }
                    
                    # Only remove if not referenced or force is TRUE
                    if (!is_referenced || force) {
                        private$simulations[[id]] <- NULL
                        removed_count <- removed_count + 1
                    }
                }
            }
            
            print(sprintf("[STATE_STORE] Cleanup complete. Removed %d simulations", removed_count))
            invisible(self)
        },
        
        #' @description Get statistics about simulations in the store
        #' @return List with statistics
        get_simulation_stats = function() {
            sim_ids <- names(private$simulations)
            
            # Count simulations by mode
            mode_counts <- list(
                prerun = 0,
                custom = 0
            )
            
            # Track other stats
            oldest_timestamp <- Sys.time()
            newest_timestamp <- as.POSIXct("1970-01-01")
            
            for (id in sim_ids) {
                sim_state <- private$simulations[[id]]()
                
                # Count by mode
                mode_counts[[sim_state$mode]] <- mode_counts[[sim_state$mode]] + 1
                
                # Track oldest/newest
                if (sim_state$timestamp < oldest_timestamp) {
                    oldest_timestamp <- sim_state$timestamp
                }
                if (sim_state$timestamp > newest_timestamp) {
                    newest_timestamp <- sim_state$timestamp
                }
            }
            
            # Get currently referenced simulations
            referenced_ids <- character()
            for (page_id in names(self$panel_states)) {
                sim_id <- self$get_current_simulation_id(page_id)
                if (!is.null(sim_id)) {
                    referenced_ids <- c(referenced_ids, sim_id)
                }
            }
            
            list(
                total_count = length(sim_ids),
                by_mode = mode_counts,
                oldest_timestamp = oldest_timestamp,
                newest_timestamp = newest_timestamp,
                referenced_count = length(unique(referenced_ids)),
                referenced_ids = unique(referenced_ids)
            )
        }
    ),

    private = list(
        #' @description Set up reactive panel states
        #' @param page_ids Character vector of page identifiers
        setup_panel_states = function(page_ids) {
            self$panel_states <- lapply(page_ids, function(id) {
                reactiveVal(create_panel_state(id))
            })
            names(self$panel_states) <- page_ids
        },

        #' @description Set up simulation storage
        setup_simulation_storage = function() {
            private$simulations <- list()
        },

        #' @description Generate unique simulation ID
        #' @return Character: unique ID
        generate_simulation_id = function() {
            paste0("sim_", format(Sys.time(), "%Y%m%d_%H%M%S"), "_", 
                   sprintf("%04d", sample.int(9999, 1)))
        },
        
        #' @description Compare two settings objects for equality
        #' @param settings1 First settings object
        #' @param settings2 Second settings object
        #' @return Logical: TRUE if settings are equivalent
        are_settings_equal = function(settings1, settings2) {
            # Basic implementation using deep comparison
            # This can be enhanced later for more complex comparisons
            identical(settings1, settings2)
        },

        #' @field simulations Internal storage for simulation ReactiveVals
        simulations = NULL
    )
)

# Create global store instance
STATE_STORE <- StateStore$new()

#' Helper function to get store instance
#' @return StateStore instance
get_store <- function() {
    STATE_STORE
}