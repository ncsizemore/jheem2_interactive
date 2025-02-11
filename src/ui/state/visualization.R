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
        output[[ns("mainPlot")]] <- renderPlot({
            # Validate outcomes before plotting
            if (is.null(transformed_data$plot$control.settings$outcomes) ||
                any(is.na(transformed_data$plot$control.settings$outcomes)) ||
                anyDuplicated(transformed_data$plot$control.settings$outcomes)) {
                stop("Invalid outcomes configuration. Please select valid outcomes without duplicates.")
            }

            transformed_data$plot
        })

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
            print("=== update_display called ===")

            # Get current control state from store
            control_state <- store$get_panel_state(page_id)$controls
            print("Control state:")
            str(control_state)

            # Create settings structure to match existing format
            settings <- list(
                outcomes = control_state$outcomes,
                facet.by = control_state$facet_by,
                summary.type = control_state$summary_type
            )

            # Transform data using control state
            print("Getting simulation data...")
            simset <- get_simulation_data(intervention_settings, mode = page_id)
            print("Transforming simulation data...")
            transformed <- transform_simulation_data(simset, settings)
            print("Transformed data:")
            str(transformed)

            # Create plot-and-table structure to match existing expectations
            new_plot_and_table <- list(
                plot = transformed$plot,
                main.settings = list(),
                control.settings = settings,
                int.settings = intervention_settings
            )

            # Update visualization state
            store$update_visualization_state(
                page_id,
                visibility = "visible",
                plot_status = "ready"
            )

            # Update display using the set_display function defined above
            print("Calling set_display...")
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
