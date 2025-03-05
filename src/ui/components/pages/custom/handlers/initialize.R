#' Initialize validation for a specific component
#' @param session Shiny session object
#' @param output Shiny output object
#' @param validation_manager Validation manager instance
#' @param config Configuration to use
#' @param component_name Name of the component to validate
#' @param group_num Group number
#' @param input Shiny input object
initialize_component_validation <- function(session, output, validation_manager, config, component_name, group_num, input) {
    # Create validation boundary for this component
    validation_boundary <- create_validation_boundary(
        session,
        output,
        "custom",
        sprintf("validation_group_%d_%s", group_num, component_name),
        validation_manager = validation_manager
    )
    
    component <- config$interventions$components[[component_name]]
    value_id <- paste0("int_", component_name, "_", group_num, "_custom")
    
    if (component$type == "numeric") {
        # Add validation for numeric input
        observeEvent(input[[value_id]], {
            rules <- list(
                validation_boundary$rules$required(
                    sprintf("%s is required", component$label)
                ),
                validation_boundary$rules$range(
                    min = component$min,
                    max = component$max,
                    message = sprintf(
                        "%s must be between %d and %d",
                        component$label,
                        component$min,
                        component$max
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
                    runjs(sprintf('
                        $("#%s").addClass("is-invalid");
                        $("#%s_error").text("%s").show();
                    ', value_id, value_id, error_state$message))
                }
            } else {
                runjs(sprintf('
                    $("#%s").removeClass("is-invalid");
                    $("#%s_error").hide();
                ', value_id, value_id))
            }
        })
    } else if (component$type == "compound") {
        # Add validation for compound input
        enabled_id <- paste0(value_id, "_enabled")
        # Get all input names from the config
        if (!is.null(component$inputs)) {
            # Find the first numeric input for validation (usually called "value")
            value_input_name <- names(component$inputs)[sapply(component$inputs, function(input) input$type == "numeric")][1]
            if (is.null(value_input_name) || length(value_input_name) == 0) {
                value_input_name <- "value" # Default to "value" if no numeric input found
            }
        } else {
            value_input_name <- "value" # Default
        }
        value_input_id <- paste0(value_id, "_", value_input_name)
        print(paste("Using value input ID:", value_input_id, "from input name:", value_input_name))

        # Validate enabled state
        observeEvent(input[[enabled_id]], {
            enabled_rules <- list(
                validation_boundary$rules$required(
                    sprintf("%s selection is required", component$label)
                )
            )

            enabled_valid <- validation_boundary$validate(
                input[[enabled_id]],
                enabled_rules,
                field_id = enabled_id
            )

            # Update UI error state for enabled checkbox
            if (!enabled_valid) {
                error_state <- validation_manager$get_field_state(enabled_id)
                if (!is.null(error_state) && !is.null(error_state$message)) {
                    runjs(sprintf('
                        $("#%s").addClass("is-invalid");
                        $("#%s_error").text("%s").show();
                    ', enabled_id, enabled_id, error_state$message))
                }
            } else {
                runjs(sprintf('
                    $("#%s").removeClass("is-invalid");
                    $("#%s_error").hide();
                ', enabled_id, enabled_id))
            }
        })

        # Validate value if enabled
        observeEvent(input[[value_input_id]], {
            if (input[[enabled_id]]) {
                value_rules <- list(
                    validation_boundary$rules$required(
                        sprintf("%s value is required", component$label)
                    ),
                    validation_boundary$rules$range(
                        min = component$inputs[[value_input_name]]$min,
                        max = component$inputs[[value_input_name]]$max,
                        message = sprintf(
                            "%s must be between %d and %d",
                            component$label,
                            component$inputs[[value_input_name]]$min,
                            component$inputs[[value_input_name]]$max
                        )
                    )
                )

                value_valid <- validation_boundary$validate(
                    as.numeric(input[[value_input_id]]),
                    value_rules,
                    field_id = value_input_id
                )

                # Update UI error state for value input - use simpler selectors
                if (!value_valid) {
                    error_state <- validation_manager$get_field_state(value_input_id)
                    if (!is.null(error_state) && !is.null(error_state$message)) {
                        # Use basic selectors to avoid quoting issues
                        js <- sprintf('
                            // First hide any current errors
                            $(".input-error-message").hide();
                            
                            // Apply error styling
                            $("#%s").addClass("is-invalid");
                            
                            // Show specific error
                            $("#%s_error").text("%s").show();
                        ',
                        value_input_id,
                        value_input_id,
                        error_state$message)
                        
                        runjs(js)
                    }
                } else {
                    # Also use simpler selectors for clearing
                    js <- sprintf('
                        // Clear validation styling
                        $("#%s").removeClass("is-invalid");
                        $("#%s_error").hide();
                    ',
                    value_input_id,
                    value_input_id)
                    
                    runjs(js)
                }
            }
        })
    }
}#' Initialize handlers for custom page
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

    # Create validation manager
    validation_manager <- create_validation_manager(session, "custom", ns("validation"))
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

    # Initialize group panels and components
    if (!is.null(config$subgroups)) {
        cat("\n\n***** CRITICAL DEBUG *****\n")
        cat("Available intervention components: ", paste(names(config$interventions$components), collapse=", "), "\n")
        for (component_name in names(config$interventions$components)) {
            cat("Component ", component_name, " is type: ", config$interventions$components[[component_name]]$type, "\n")
        }
        cat("*************************\n\n")

        # Render the group panels
        output$subgroup_panels_custom <- renderUI({
            print("Creating group panels...")

            # For fixed groups (ryan-white case)
            if (config$subgroups$fixed) {
                print(paste("Creating", config$subgroups$count, "fixed groups"))
                panels <- lapply(1:config$subgroups$count, function(i) {
                    print(paste("Creating panel for fixed group", i))
                    group <- config$subgroups$groups[[i]]
                    create_subgroup_panel(i, config, fixed_group = group)
                })
                do.call(tagList, panels)
            } else {
                # For user-defined groups (main branch case)
                req(input$subgroups_count_custom)
                count <- as.numeric(input$subgroups_count_custom)
                print(paste("Creating", count, "user-defined groups"))
                panels <- lapply(1:count, function(i) {
                    create_subgroup_panel(i, config)
                })
                do.call(tagList, panels)
            }
        })

        # Initialize validation for components
        if (config$subgroups$fixed) {
            cat("\n\n***** CRITICAL DEBUG - FIXED GROUPS *****\n")
            cat("Initializing validation for ", config$subgroups$count, " fixed groups\n")
            cat("*************************************\n\n")
            for (i in 1:config$subgroups$count) {
                local({
                    group_num <- i
                    group <- config$subgroups$groups[[i]]
                    
                    # For each component in the group
                    for (component_name in names(config$interventions$components)) {
                        local({
                            initialize_component_validation(
                                session, 
                                output,
                                validation_manager,
                                config,
                                component_name,
                                group_num,
                                input
                            )
                        })
                    }
                })
            }
        } else {
            # User-defined groups
            observeEvent(input$subgroups_count_custom, {
                validation_boundary <- create_validation_boundary(
                    session,
                    output,
                    "custom",
                    "subgroups_validation",
                    validation_manager = validation_manager
                )

                count <- tryCatch(
                    as.numeric(input$subgroups_count_custom),
                    warning = function(w) NULL,
                    error = function(e) NULL
                )

                valid_count <- validation_boundary$validate(
                    count,
                    list(
                        validation_boundary$rules$required("Number of subgroups is required"),
                        validation_boundary$rules$range(
                            min = config$subgroups$selector$min,
                            max = config$subgroups$selector$max,
                            message = sprintf(
                                "Number of subgroups must be between %d and %d",
                                config$subgroups$selector$min,
                                config$subgroups$selector$max
                            )
                        )
                    ),
                    field_id = "subgroups_count_custom"
                )
                
                # If count is valid, set up validation for each subgroup's components
                if (valid_count && !is.null(count) && count > 0) {
                    cat("\n\n***** SETTING UP VALIDATION FOR USER-DEFINED GROUPS *****\n")
                    cat("Setting up validation for", count, "user-defined groups\n")
                    for (i in 1:count) {
                        for (component_name in names(config$interventions$components)) {
                            # Set up validation for this component in this subgroup
                            initialize_component_validation(
                                session, 
                                output,
                                validation_manager,
                                config,
                                component_name,
                                i,
                                input
                            )
                        }
                    }
                    cat("*************************************\n\n")
                }
            })
        }
    }

    # Handle generate button
    observeEvent(input$generate_custom, {
        print("Generate button pressed (custom)")

        # Check if EHE specification is loaded
        if (!is.null(session$userData$is_ehe_spec_loaded) && 
            !session$userData$is_ehe_spec_loaded()) {
            
            # Show loading notification
            showNotification(
                "Loading simulation environment before running...",
                id = "loading_for_generate",
                duration = NULL,
                type = "message"
            )
            
            # Trigger loading the EHE specification
            if (!is.null(session$userData$load_ehe_spec)) {
                # Load the EHE specification
                if (session$userData$load_ehe_spec()) {
                    # Successfully loaded, remove notification and proceed
                    removeNotification(id = "loading_for_generate")
                    generate_custom_simulation()
                } else {
                    # Loading failed
                    removeNotification(id = "loading_for_generate")
                    showNotification(
                        "Failed to load simulation environment. Please try again later.",
                        type = "error",
                        duration = NULL
                    )
                }
            } else {
                # Can't load the EHE specification
                removeNotification(id = "loading_for_generate")
                showNotification(
                    "Cannot load simulation environment.",
                    type = "error",
                    duration = NULL
                )
            }
        } else {
            # EHE specification is already loaded, proceed directly
            generate_custom_simulation()
        }
    })
    
    # Function to handle the actual generate logic
    generate_custom_simulation <- function() {

        if (validation_manager$is_valid()) {
            # Collect settings based on configuration
            settings <- list(
                location = isolate(input$int_location_custom),
                dates = list(
                    start = isolate(input$int_dates_start_custom),
                    end = isolate(input$int_dates_end_custom)
                )
            )

            # Collect component settings based on group type
            if (config$subgroups$fixed) {
                # Fixed groups - collect settings by group
                settings$components <- isolate({
                    lapply(1:config$subgroups$count, function(i) {
                        group <- config$subgroups$groups[[i]]
                        lapply(names(config$interventions$components), function(component_name) {
                            component <- config$interventions$components[[component_name]]
                            if (component$type == "numeric") {
                                list(
                                    group = group$id,
                                    type = component_name,
                                    value = input[[paste0("int_", component_name, "_", i, "_custom")]]
                                )
                            } else if (component$type == "compound") {
                                enabled_id <- paste0("int_", component_name, "_", i, "_custom_enabled")
                                # Find numeric input name
                                value_input_name <- names(component$inputs)[sapply(component$inputs, function(input) input$type == "numeric")][1]
                                if (is.null(value_input_name) || length(value_input_name) == 0) {
                                    value_input_name <- "value" # Default
                                }
                                value_input_id <- paste0("int_", component_name, "_", i, "_custom_", value_input_name)
                                
                                if (!input[[enabled_id]]) {
                                    NULL  # Skip if not enabled
                                } else {
                                    list(
                                        group = group$id,
                                        type = component_name,
                                        enabled = TRUE,
                                        value = input[[value_input_id]]
                                    )
                                }
                            }
                        })
                    })
                })
            } else {
                # User-defined groups - collect demographic and intervention settings
                settings$components <- isolate({
                    count <- as.numeric(input$subgroups_count_custom)
                    lapply(1:count, function(i) {
                        # Get demographics from configuration
                        demographic_fields <- names(config$demographics)
                        
                        # Collect demographics dynamically
                        demographics <- lapply(demographic_fields, function(field) {
                            input[[paste0("int_", field, "_", i, "_custom")]]
                        })
                        names(demographics) <- demographic_fields
                        
                        # Get abbreviations from config
                        abbreviations <- config$abbreviations$dimensions
                        default_len <- abbreviations$default_length %||% 2
                        
                        # Create abbreviated group ID
                        id_components <- lapply(demographic_fields, function(field) {
                            value <- demographics[[field]][1]  # Take first selected value
                            if (is.null(value)) return("any")
                            
                            # Try to get pre-defined abbreviation
                            abbrev <- abbreviations$values[[value]]
                            if (is.null(abbrev)) {
                                # Create generic abbreviation
                                abbrev <- substr(gsub("[-_]", "", value), 1, default_len)
                            }
                            abbrev
                        })
                        
                        # Create group ID
                        group_id <- paste(id_components, collapse="-")
                        
                        # Create flattened component list with group IDs
                        components <- lapply(names(config$interventions$components), function(name) {
                            component <- config$interventions$components[[name]]
                            comp_data <- NULL
                            
                            if (component$type == "numeric") {
                                comp_data <- list(
                                    group = group_id,
                                    type = name,
                                    value = input[[paste0("int_", name, "_", i, "_custom")]]
                                )
                            } else if (component$type == "compound") {
                                enabled_id <- paste0("int_", name, "_", i, "_custom_enabled")
                                if (!input[[enabled_id]]) {
                                    return(NULL)
                                }
                                
                                # Handle different input types within compound component
                                # Find the first non-enabled input (either numeric or select)
                                value_input_names <- names(component$inputs)[names(component$inputs) != "enabled"]
                                if (length(value_input_names) == 0) {
                                    return(NULL) # No value inputs found
                                }
                                
                                value_input_name <- value_input_names[1]
                                value_input_id <- paste0("int_", name, "_", i, "_custom_", value_input_name)
                                value <- input[[value_input_id]]
                                
                                print(paste("For component", name, "using input", value_input_name, "with value", value))
                                
                                comp_data <- list(
                                    group = group_id,
                                    type = name,
                                    enabled = TRUE,
                                    value = value
                                )
                            }
                            
                            return(comp_data)
                        })
                        
                        # Filter out NULL values
                        components <- components[!sapply(components, is.null)]
                        return(components)
                    })
                })
            }

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
    }

    # Initialize display handlers
    initialize_display_handlers(session, input, output, vis_manager, "custom")
    initialize_display_setup(session, input)
}
