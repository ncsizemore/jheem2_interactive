# src/ui/components/pages/custom/handlers/initialize.R

#' Initialize handlers for custom page
#' @param input Shiny session object
#' @param output Shiny output object
#' @param session Shiny session object
#' @param plot_state Reactive value for plot state
initialize_custom_handlers <- function(input, output, session, plot_state) {
    ns <- session$ns

    # Get configuration
    config <- get_page_complete_config("custom")

    # Create visualization manager with explicit page ID
    vis_manager <- create_visualization_manager(session, "custom", ns("visualization"))

    # Initialize visualization handlers
    initialize_visualization_handlers(input, output, session, vis_manager)

    # Create managers
    validation_manager <- create_validation_manager(session, "custom", ns("validation"))

    # Store validation manager in session for access by other functions
    session$userData$validation_manager <- validation_manager

    # Validate location selection
    validation_boundary <- create_validation_boundary(
        session,
        output,
        "custom",
        "location_validation",
        validation_manager = validation_manager
    )

    observeEvent(input$int_location_custom, {
        validation_boundary$validate(
            input$int_location_custom,
            list(
                validation_boundary$rules$required("Please select a location"),
                validation_boundary$rules$custom(
                    test_fn = function(value) !is.null(value) && value != "none",
                    message = "Please select a location"
                )
            ),
            field_id = "int_location_custom"
        )
    })

    # Handle subgroup count changes
    observeEvent(input$subgroups_count_custom, {
        print(paste("Subgroups count changed:", input$subgroups_count_custom))

        # Create validation boundary with validation manager
        validation_boundary <- create_validation_boundary(
            session,
            output,
            "custom",
            "subgroups_validation",
            validation_manager = validation_manager
        )

        # Get the numeric value, handle empty/NULL
        count <- tryCatch(
            {
                as.numeric(input$subgroups_count_custom)
            },
            warning = function(w) {
                NULL
            },
            error = function(e) {
                NULL
            }
        )

        # Validate subgroups count
        valid_count <- validation_boundary$validate(
            count,
            list(
                validation_boundary$rules$required("Number of subgroups is required"),
                validation_boundary$rules$range(
                    min = config$subgroups$min,
                    max = config$subgroups$max,
                    message = sprintf(
                        "Number of subgroups must be between %d and %d",
                        config$subgroups$min,
                        config$subgroups$max
                    )
                )
            ),
            field_id = "subgroups_count_custom"
        )

        # Clear existing panels if invalid
        if (!valid_count) {
            output$subgroup_panels_custom <- renderUI({
                NULL
            })
            # Reset the input to last valid value or min
            updateNumericInput(
                session,
                "subgroups_count_custom",
                value = config$subgroups$min
            )
        } else {
            # Only render subgroup panels if count is valid
            output$subgroup_panels_custom <- renderUI({
                panels <- lapply(1:count, function(i) {
                    create_subgroup_panel(i, config)
                })
                do.call(tagList, panels)
            })
        }
    })

    # Initialize intervention handlers
    initialize_intervention_handlers(input, output, session, validation_manager, config)

    # Modify generate button handler
    observeEvent(input$generate_custom, {
        print("Generate button pressed (custom)")

        # Check all validations
        validation_results <- validation_manager$is_valid()

        if (validation_results) {
            # Get subgroup count and settings
            subgroup_count <- isolate(input$subgroups_count_custom)
            settings <- collect_custom_settings(input, subgroup_count)

            # Update visualization state
            updateTextInput(session, ns("custom-visualization_state"), value = "visible")

            # Call update_display with settings and simset
            update_display(session, input, output, "custom", settings, plot_state)

            showNotification(
                "Custom projections starting...",
                type = "message"
            )
        } else {
            showNotification(
                "Please correct the highlighted errors before proceeding.",
                type = "error"
            )
        }
    })
}
