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