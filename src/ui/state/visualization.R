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
            display_type = "plot"
        )

        # Also set plot status
        store$set_plot_status(page_id, "ready")

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

    # Define set_plot_status here so it's in scope for update_display
    set_plot_status <- function(status) {
        # Update the reactive value in the store
        store$set_plot_status(page_id, status)
        # Update the hidden input (might be used elsewhere)
        updateTextInput(
            session,
            paste0(page_id, "-plot_status"),
            value = status
        )

        # Use UI Messenger to show/hide the loading indicator div
        ui_messenger <- session$userData$ui_messenger
        indicator_id <- ns("loading_indicator") # Get the namespaced ID

        if (!is.null(ui_messenger)) {
            if (status == "loading") {
                ui_messenger$send_plot_loading(indicator_id = indicator_id)
            } else {
                # Send ready for both "ready" and "error" statuses
                ui_messenger$send_plot_ready(indicator_id = indicator_id)
            }
        } else {
            warning("UI Messenger not available in session$userData")
        }
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
        set_plot_status = set_plot_status, # Reference the function defined above
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

            # Get current control state from store (using the new shared control state)
            control_state <- store$get_shared_control_state(page_id)
            print("[VISUALIZATION] Control state:")
            str(control_state)

            # Create settings structure
            settings <- list(
                outcomes = control_state$outcomes,
                facet.by = control_state$facet.by,
                summary.type = control_state$summary.type
            )

            # Set status to loading while we work using the manager's function
            set_plot_status("loading") # MODIFIED: Call self directly

            # Clear any previous error message
            output[[paste0(page_id, "-error_message")]] <- renderText({
                NULL
            })

            # Get/create simulation (now returns a promise)
            print("[VISUALIZATION ASYNC] Getting simulation data promise...")
            sim_adapter <- get_simulation_adapter()
            sim_id_promise <- sim_adapter$get_simulation_data(intervention_settings, mode = page_id)

            # Chain subsequent actions onto the promise
            # Wrap the anonymous functions in parentheses
            sim_id_promise %...>% (function(sim_id) {
                print(sprintf("[VISUALIZATION ASYNC] Promise resolved, got sim_id: %s", sim_id))

                # If simulation failed completely during find/load/run (returned NULL or error ID), stop processing
                if (is.null(sim_id)) {
                    print("[VISUALIZATION ASYNC] Simulation ID is NULL, stopping.")
                    # Ensure status is error if ID is null after promise resolves without explicit error
                    store$set_plot_status(page_id, "error")
                    return()
                }

                # Set as current simulation
                store$set_current_simulation(page_id, sim_id)

                # Get simulation state
                sim_state <- store$get_simulation(sim_id)

                # Check if simulation has error status
                if (sim_state$status == "error") {
                    print(sprintf("[VISUALIZATION ASYNC] Simulation has error status: %s", sim_state$error_message))
                    # Error message should have been set by the adapter/store
                    store$set_plot_status(page_id, "error")
                    store$update_visualization_state(page_id, visibility = "visible") # Ensure panel is visible to show error
                    return()
                }

                # Transform data for display
                print("[VISUALIZATION ASYNC] Transforming simulation data...")
                transformed <- tryCatch(
                    {
                        transform_simulation_data(sim_state$results$simset, settings)
                    },
                    error = function(e) {
                        # Handle transformation errors
                        print(sprintf("[VISUALIZATION ASYNC] Error transforming data: %s", conditionMessage(e)))
                        # Set error message
                        output[[paste0(page_id, "-error_message")]] <- renderText({
                            sprintf("Error transforming data: %s", conditionMessage(e))
                        })
                        # Update visualization state
                        store$set_plot_status(page_id, "error")
                        return(NULL) # Return NULL to indicate failure
                    }
                )

                # If transformation failed, stop processing
                if (is.null(transformed)) {
                    return()
                }

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

                # Update display (this sets status back to 'ready')
                print("[VISUALIZATION ASYNC] Updating display...")
                set_display(input, output, new_plot_and_table)
            }) %...!% (function(error) { # Added parentheses
                # Handle errors from the promise chain itself (e.g., adapter error)
                print(sprintf("[VISUALIZATION ASYNC] Error in promise chain: %s", conditionMessage(error)))
                output[[paste0(page_id, "-error_message")]] <- renderText({
                    sprintf("Error: %s", conditionMessage(error))
                })
                store$set_plot_status(page_id, "error")
                store$update_visualization_state(page_id, visibility = "visible")
            })

            # Return the promise itself so Shiny knows to wait
            return(sim_id_promise)
        },
        reset = function() {
            store$update_visualization_state(
                page_id,
                visibility = "hidden",
                display_type = "plot"
            )
            store$set_plot_status(page_id, "ready")
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
