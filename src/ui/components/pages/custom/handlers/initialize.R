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
    initialize_custom_visualization_handlers(input, output, session, vis_manager)

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
            warning = function(w) NULL,
            error = function(e) NULL
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

    # Create observers for intervention inputs
    observe({
        # Get current subgroup count
        subgroup_count <- tryCatch(
            {
                count <- as.numeric(input$subgroups_count_custom)
                if (is.na(count) || count < config$subgroups$min || count > config$subgroups$max) {
                    config$subgroups$min
                } else {
                    count
                }
            },
            error = function(e) config$subgroups$min
        )

        # For each subgroup
        for (i in 1:subgroup_count) {
            local({
                group_num <- i

                # For each intervention component in config
                for (component_name in names(config$interventions$components)) {
                    local({
                        component <- config$interventions$components[[component_name]]

                        # Skip if not a compound type with numeric/select inputs
                        if (component$type != "compound") {
                            return()
                        }

                        # Create validation boundary with unique ID for each field
                        validation_boundary <- create_validation_boundary(
                            session,
                            output,
                            "custom",
                            sprintf("validation_%s_%d", component_name, group_num),
                            validation_manager = validation_manager
                        )

                        enabled_id <- paste0("int_", component_name, "_", group_num, "_custom_enabled")

                        # For each input in the compound component
                        for (input_name in names(component$inputs)) {
                            input_config <- component$inputs[[input_name]]
                            if (input_name == "enabled") next

                            value_id <- paste0("int_", component_name, "_", group_num, "_custom_", input_name)

                            print(sprintf("Setting up validation for %s", value_id))

                            # Add input change observer
                            observeEvent(input[[enabled_id]], {
                                print(sprintf("Enabled state changed for %s: %s", value_id, input[[enabled_id]]))
                                if (!input[[enabled_id]]) {
                                    validation_manager$update_field(value_id, TRUE)
                                    runjs(sprintf("
                                        $('#%s').removeClass('is-invalid');
                                        $('#%s_error').hide();
                                    ", value_id, value_id))
                                }
                            })

                            observeEvent(input[[value_id]], {
                                print(sprintf("Value changed for %s: %s", value_id, input[[value_id]]))
                                if (input[[enabled_id]]) {
                                    # Debug input configuration
                                    print("Input config:")
                                    str(input_config)

                                    # Get the proper label from the component configuration
                                    field_label <- if (!is.null(component$inputs[[input_name]]$label)) {
                                        # First try component-specific input label from defaults.yaml
                                        component$inputs[[input_name]]$label
                                    } else if (!is.null(input_config$label)) {
                                        # Then try the direct input label from custom.yaml
                                        input_config$label
                                    } else if (!is.null(input_config$placeholder)) {
                                        # Fall back to placeholder if available
                                        gsub("\\.\\.\\.$", "", input_config$placeholder) # Remove trailing ellipsis
                                    } else if (!is.null(component$label)) {
                                        # Use parent component label as last resort
                                        sub("Intervene on ", "", component$label)
                                    } else {
                                        "Field"
                                    }

                                    print(sprintf("Using field label: %s", field_label))

                                    # Create validation rules based on input type
                                    rules <- list(
                                        validation_boundary$rules$required(
                                            message = sprintf("%s is required", field_label)
                                        )
                                    )

                                    if (input_config$type == "numeric") {
                                        # Get min/max from config with fallbacks
                                        min_val <- input_config$min %||% 0
                                        max_val <- input_config$max %||% 100

                                        message <- sprintf(
                                            "%s must be between %d and %d",
                                            field_label,
                                            min_val,
                                            max_val
                                        )

                                        # Add percentage if format is percentage
                                        if (!is.null(input_config$format) && input_config$format == "percentage") {
                                            message <- sprintf("%s%%", message)
                                        }

                                        print(sprintf("Creating range validation message: %s", message))

                                        rules[[length(rules) + 1]] <- validation_boundary$rules$range(
                                            min = min_val,
                                            max = max_val,
                                            message = message
                                        )
                                    }

                                    print("Created validation rules:")
                                    str(rules)

                                    # Convert input value to numeric for numeric fields
                                    value <- if (input_config$type == "numeric") {
                                        as.numeric(input[[value_id]])
                                    } else {
                                        input[[value_id]]
                                    }

                                    # Validate and update UI
                                    valid <- validation_boundary$validate(
                                        value,
                                        rules,
                                        field_id = value_id
                                    )

                                    print(sprintf("Validation result for %s: %s", value_id, valid))

                                    if (!valid) {
                                        error_state <- validation_manager$get_field_state(value_id)
                                        print("Error state:")
                                        str(error_state)

                                        if (!is.null(error_state) && !is.null(error_state$message)) {
                                            print(sprintf("Showing error for %s: %s", value_id, error_state$message))
                                            runjs(sprintf("
                                                $('#%s').addClass('is-invalid');
                                                $('#%s_error').text('%s').show();
                                            ", value_id, value_id, error_state$message))
                                        }
                                    } else {
                                        print(sprintf("Clearing error for %s", value_id))
                                        runjs(sprintf("
                                            $('#%s').removeClass('is-invalid');
                                            $('#%s_error').hide();
                                        ", value_id, value_id))
                                    }
                                }
                            })
                        }
                    })
                }
            })
        }
    })

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
