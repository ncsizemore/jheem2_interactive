# src/ui/state/visualization.R

source("src/ui/components/common/display/button_control.R")

#' Create a visualization state manager
#' @param session Shiny session object
#' @param page_id Character: page identifier
#' @param id Character: component identifier
#' @return List of handler functions
create_visualization_manager <- function(session, page_id, id) {
    ns <- session$ns
    store <- get_store()

    # Define set_display first so it can be used by other functions
    set_display <- function(input, output, transformed_data) {
        print("[VISUALIZATION] === set_display called ===")
        # Use the full page_id prefix for input IDs
        vis_state_id <- paste0(page_id, "-visualization_state")
        display_type_id <- paste0(page_id, "-display_type")
        plot_status_id <- paste0(page_id, "-plot_status")

        # 1. Update store state
        store$update_visualization_state(
            page_id,
            visibility = "visible",
            display_type = "plot",
            plot_status = "ready"
        )

        # 2. Update UI inputs with full prefixed IDs
        updateTextInput(session, vis_state_id, value = "visible")
        updateTextInput(session, display_type_id, value = "plot")
        updateTextInput(session, plot_status_id, value = "ready")

        # 3. Get display size
        display_size <- get.display.size(input, page_id)

        # 4. Update plot output
        print("[VISUALIZATION] About to render plot...")
        output[[ns("mainPlot")]] <- renderPlot({
            # Validate outcomes before plotting
            if (is.null(transformed_data$plot$control.settings$outcomes) ||
                any(is.na(transformed_data$plot$control.settings$outcomes)) ||
                anyDuplicated(transformed_data$plot$control.settings$outcomes)) {
                stop("Invalid outcomes configuration. Please select valid outcomes without duplicates.")
            }

            transformed_data$plot
        })
        print("[VISUALIZATION] Plot render function set up")

        # 5. Update buttons state
        sync_buttons_to_plot(input, list(
            custom = if (page_id == "custom") transformed_data else NULL,
            prerun = if (page_id == "prerun") transformed_data else NULL
        ))
    }

    list(
        set_visibility = function(visibility) {
            store$update_visualization_state(
                page_id,
                visibility = visibility
            )
            updateTextInput(
                session,
                paste0(page_id, "-visualization_state"),
                value = visibility
            )
        },
        set_plot_status = function(status) {
            store$update_visualization_state(
                page_id,
                plot_status = status
            )
            updateTextInput(
                session,
                paste0(page_id, "-plot_status"),
                value = status
            )
        },
        set_display_type = function(type) {
            store$update_visualization_state(
                page_id,
                display_type = type
            )
            updateTextInput(
                session,
                paste0(page_id, "-display_type"),
                value = type
            )
        },
        # Add back the update_display function that handles simulation
        update_display = function(input, output, intervention_settings) {
            print("[VISUALIZATION] === update_display called ===")
            
            # Get current control state from store
            control_state <- store$get_panel_state(page_id)$controls
            print("[VISUALIZATION] Control state:")
            str(control_state)

            # Create settings structure
            settings <- list(
                outcomes = control_state$outcomes,
                facet.by = control_state$facet.by,
                summary.type = control_state$summary.type
            )

            # Set status to loading while we work
            store$update_visualization_state(page_id, plot_status = "loading")

            # Get/create simulation and set as current
            print("[VISUALIZATION] Getting simulation data...")
            sim_id <- get_simulation_adapter()$get_simulation_data(intervention_settings, mode = page_id)
            store$set_current_simulation(page_id, sim_id)
            
            # Get simulation state
            sim_state <- store$get_simulation(sim_id)
            
            # Transform data for display
            print("[VISUALIZATION] Transforming simulation data...")
            transformed <- transform_simulation_data(sim_state$results$simset, settings)
            
            # Update simulation state with transformed data
            store$update_simulation(sim_id, list(
                results = list(
                    simset = sim_state$results$simset,
                    transformed = transformed
                )
            ))

            # Create plot-and-table structure
            new_plot_and_table <- list(
                plot = transformed$plot,
                main.settings = list(),
                control.settings = settings,
                int.settings = intervention_settings
            )

            # Update display
            print("[VISUALIZATION] Updating display...")
            set_display(input, output, new_plot_and_table)
        },
        reset = function() {
            store$update_visualization_state(
                page_id,
                visibility = "hidden",
                plot_status = "ready",
                display_type = "plot"
            )
        },
        set_display = set_display
    )
}

#' Create a reactive visualization state source
#' @param page_id Character: page identifier
#' @return Reactive expression returning current visualization state
create_visualization_state_source <- function(page_id) {
    store <- get_store()
    reactive({
        panel_state <- store$get_panel_state(page_id)
        panel_state$visualization
    })
}
