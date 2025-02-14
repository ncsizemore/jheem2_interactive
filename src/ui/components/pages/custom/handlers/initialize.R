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

    # Handle subgroups if configured
    if (!is.null(config$subgroups)) {
        # Subgroups validation and UI updates
        observeEvent(input$subgroups_count_custom, {
            print(paste("Subgroups count changed:", input$subgroups_count_custom))

            validation_boundary <- create_validation_boundary(
                session,
                output,
                "custom",
                "subgroups_validation",
                validation_manager = validation_manager
            )

            count <- tryCatch(
                {
                    as.numeric(input$subgroups_count_custom)
                },
                warning = function(w) NULL,
                error = function(e) NULL
            )

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

            if (!valid_count) {
                output$subgroup_panels_custom <- renderUI({
                    NULL
                })
                updateNumericInput(
                    session,
                    "subgroups_count_custom",
                    value = config$subgroups$min
                )
            } else {
                output$subgroup_panels_custom <- renderUI({
                    panels <- lapply(1:count, function(i) {
                        create_subgroup_panel(i, config)
                    })
                    do.call(tagList, panels)
                })
            }
        })
    }

    # Create observers for intervention components
    observe({
        for (component_name in names(config$interventions$components)) {
            local({
                component <- config$interventions$components[[component_name]]
                validation_boundary <- create_validation_boundary(
                    session,
                    output,
                    "custom",
                    sprintf("validation_%s", component_name),
                    validation_manager = validation_manager
                )

                if (component$type == "compound") {
                    # Handle compound components (full version)
                    enabled_id <- paste0("int_", component_name, "_custom_enabled")
                    
                    for (input_name in names(component$inputs)) {
                        if (input_name == "enabled") next
                        value_id <- paste0("int_", component_name, "_custom_", input_name)
                        
                        # Handle enabled state changes
                        observeEvent(input[[enabled_id]], {
                            if (!input[[enabled_id]]) {
                                validation_manager$update_field(value_id, TRUE)
                                runjs(sprintf("
                                    $('#%s').removeClass('is-invalid');
                                    $('#%s_error').hide();
                                ", value_id, value_id))
                            }
                        })

                        # Handle value changes
                        observeEvent(input[[value_id]], {
                            if (input[[enabled_id]]) {
                                input_config <- component$inputs[[input_name]]
                                rules <- list(validation_boundary$rules$required(
                                    sprintf("%s is required", component$label)
                                ))

                                if (input_config$type == "numeric") {
                                    rules[[length(rules) + 1]] <- validation_boundary$rules$range(
                                        min = input_config$min %||% 0,
                                        max = input_config$max %||% 100,
                                        message = sprintf(
                                            "%s must be between %d and %d",
                                            component$label,
                                            input_config$min %||% 0,
                                            input_config$max %||% 100
                                        )
                                    )
                                }

                                value <- if (input_config$type == "numeric") {
                                    as.numeric(input[[value_id]])
                                } else {
                                    input[[value_id]]
                                }

                                valid <- validation_boundary$validate(value, rules, field_id = value_id)

                                # Update UI error state
                                if (!valid) {
                                    error_state <- validation_manager$get_field_state(value_id)
                                    if (!is.null(error_state) && !is.null(error_state$message)) {
                                        runjs(sprintf("
                                            $('#%s').addClass('is-invalid');
                                            $('#%s_error').text('%s').show();
                                        ", value_id, value_id, error_state$message))
                                    }
                                } else {
                                    runjs(sprintf("
                                        $('#%s').removeClass('is-invalid');
                                        $('#%s_error').hide();
                                    ", value_id, value_id))
                                }
                            }
                        })
                    }
                } else if (component$type == "numeric") {
                    # Handle simple numeric inputs (ryan-white)
                    value_id <- paste0("int_", component_name, "_custom")

                    observeEvent(input[[value_id]], {
                        rules <- list(
                            validation_boundary$rules$required(
                                sprintf("%s is required", component$label)
                            ),
                            validation_boundary$rules$range(
                                min = component$min %||% 0,
                                max = component$max %||% 100,
                                message = sprintf(
                                    "%s must be between %d and %d",
                                    component$label,
                                    component$min %||% 0,
                                    component$max %||% 100
                                )
                            )
                        )

                        valid <- validation_boundary$validate(
                            as.numeric(input[[value_id]]),
                            rules,
                            field_id = value_id
                        )

                        # Update UI error state
                        if (!valid) {
                            error_state <- validation_manager$get_field_state(value_id)
                            if (!is.null(error_state) && !is.null(error_state$message)) {
                                runjs(sprintf("
                                    $('#%s').addClass('is-invalid');
                                    $('#%s_error').text('%s').show();
                                ", value_id, value_id, error_state$message))
                            }
                        } else {
                            runjs(sprintf("
                                $('#%s').removeClass('is-invalid');
                                $('#%s_error').hide();
                            ", value_id, value_id))
                        }
                    })
                }
            })
        }
    })

    # Modify generate button handler
    observeEvent(input$generate_custom, {
        print("Generate button pressed (custom)")

        if (validation_manager$is_valid()) {
            # Collect settings based on configuration
            settings <- list(
                location = isolate(input$int_location_custom),
                dates = list(
                    start = isolate(input$int_dates_start_custom),
                    end = isolate(input$int_dates_end_custom)
                ),
                components = lapply(names(config$interventions$components), function(name) {
                    component <- config$interventions$components[[name]]
                    if (component$type == "compound") {
                        # Collect compound component settings
                        enabled_id <- paste0("int_", name, "_custom_enabled")
                        if (isolate(input[[enabled_id]])) {
                            sapply(names(component$inputs), function(input_name) {
                                if (input_name == "enabled") return(NULL)
                                isolate(input[[paste0("int_", name, "_custom_", input_name)]])
                            })
                        }
                    } else if (component$type == "numeric") {
                        # Collect numeric input value
                        isolate(input[[paste0("int_", name, "_custom")]])
                    }
                })
            )

            # Update visualization state and display
            vis_manager$set_visibility("visible")
            vis_manager$update_display(input, output, settings)

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

    # Initialize display handlers
    initialize_display_handlers(session, input, output, vis_manager, "custom")
    initialize_display_setup(session, input)
}