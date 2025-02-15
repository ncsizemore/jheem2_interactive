# src/ui/components/pages/custom/handlers/initialize.R

#' Initialize a component's validation and observers
#' @param component_name Name of the component
#' @param component Component configuration
#' @param group_num Subgroup number
#' @param input Shiny input object
#' @param output Shiny output object
#' @param session Shiny session object
#' @param validation_manager Validation manager instance
#' @param config Page configuration
initialize_component <- function(component_name, component, group_num, input, output, 
                               session, validation_manager, config) {
    # Get selector config for this component and group
    selector_config <- get_selector_config(component_name, "custom", group_num)
    enabled_id <- paste0(selector_config$id, "_enabled")
    
    # Create validation boundary for this component
    validation_boundary <- create_validation_boundary(
        session,
        output,
        "custom",
        paste0(component_name, "_validation_", group_num),
        validation_manager = validation_manager
    )
    
    # For each input in the compound component
    for (input_name in names(component$inputs)) {
        if (input_name == "enabled") next
        
        local({
            input_config <- component$inputs[[input_name]]
            value_id <- paste0(selector_config$id, "_", input_name)
            
            # Create validation rules
            create_validation_rules <- function() {
                rules <- list(
                    validation_boundary$rules$required(
                        sprintf("%s is required", input_config$label)
                    )
                )
                
                if (input_config$type == "numeric") {
                    rules[[length(rules) + 1]] <- validation_boundary$rules$range(
                        min = input_config$min,
                        max = input_config$max,
                        message = sprintf(
                            "%s must be between %s and %s",
                            input_config$label,
                            input_config$min,
                            input_config$max
                        )
                    )
                }
                rules
            }
            
            # Add enabled state observer
            observeEvent(input[[enabled_id]], {
                if (!input[[enabled_id]]) {
                    validation_manager$update_field(value_id, TRUE)
                    runjs(sprintf("
                        $('#%s').removeClass('is-invalid');
                        $('#%s_error').hide();
                    ", value_id, value_id))
                }
            })
            
            # Add value change observer
            observeEvent(input[[value_id]], {
                req(input[[enabled_id]])
                
                if (isTRUE(input[[enabled_id]])) {
                    req(input[[value_id]])
                    
                    valid <- validation_boundary$validate(
                        input[[value_id]],
                        create_validation_rules(),
                        field_id = value_id
                    )
                    
                    if (!valid) {
                        error_state <- validation_manager$get_field_state(value_id)
                        runjs(sprintf("
                            $('#%s').addClass('is-invalid');
                            $('#%s_error').text('%s').show();
                        ", value_id, value_id, error_state$message))
                    } else {
                        runjs(sprintf("
                            $('#%s').removeClass('is-invalid');
                            $('#%s_error').hide();
                        ", value_id, value_id))
                    }
                }
            })
        })
    }
}

#' Initialize components for a subgroup
#' @param group_num Subgroup number
#' @param input Shiny input object
#' @param output Shiny output object
#' @param session Shiny session object
#' @param validation_manager Validation manager instance
#' @param config Page configuration
initialize_subgroup_components <- function(group_num, input, output, session, validation_manager, config) {
    # Get intervention components from config
    for (component_name in names(config$interventions$components)) {
        local({
            # Get component config
            component <- config$interventions$components[[component_name]]
            
            # Skip non-compound components
            if (component$type != "compound") return()
            
            # Initialize this component
            initialize_component(
                component_name,
                component,
                group_num,
                input,
                output,
                session,
                validation_manager,
                config
            )
        })
    }
}

#' Initialize a specific section
#' @param section Section name
#' @param input Shiny input object
#' @param output Shiny output object
#' @param session Shiny session object
#' @param validation_manager Validation manager instance
#' @param config Page configuration
initialize_section <- function(section, input, output, session, validation_manager, config) {
    print(sprintf("Initializing section: %s", section))
    
    # Create validation boundary for this section
    validation_boundary <- create_validation_boundary(
        session, output, "custom", 
        paste0(section, "_validation"),
        validation_manager = validation_manager
    )
    
    # Handle each section type
    switch(section,
        "location" = {
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
        },
        "subgroups" = {
            # Validate subgroup count
            observe({
                req(input$subgroups_count_custom)
                req(config$subgroups$min)
                
                count <- tryCatch({
                    val <- as.numeric(input$subgroups_count_custom)
                    if (is.na(val) || val < config$subgroups$min || val > config$subgroups$max) {
                        validation_boundary$validate(
                            input$subgroups_count_custom,
                            list(
                                validation_boundary$rules$range(
                                    min = config$subgroups$min,
                                    max = config$subgroups$max,
                                    message = sprintf("Must be between %d and %d", 
                                                    config$subgroups$min, 
                                                    config$subgroups$max)
                                )
                            ),
                            field_id = "subgroups_count_custom"
                        )
                        config$subgroups$min
                    } else {
                        val
                    }
                }, error = function(e) {
                    config$subgroups$min
                })
                
                # Render subgroup panels
                output$subgroup_panels_custom <- renderUI({
                    tagList(
                        lapply(1:count, function(i) {
                            create_subgroup_panel(i, "custom")
                        })
                    )
                })
            })
        },
        "demographics" = {
            # Demographics validation is handled per-subgroup in interventions
            NULL
        },
        "interventions" = {
            # Main intervention observer
            observe({
                req(input$subgroups_count_custom)
                req(config$subgroups$min)
                
                count <- as.numeric(input$subgroups_count_custom)
                
                # For each subgroup
                for (i in 1:count) {
                    local({
                        group_num <- i
                        
                        # Initialize components for this subgroup
                        initialize_subgroup_components(
                            group_num,
                            input,
                            output,
                            session,
                            validation_manager,
                            config
                        )
                    })
                }
            })
        }
    )
}

#' Initialize handlers for custom page
#' @param input Shiny session object
#' @param output Shiny output object
#' @param session Shiny session object
#' @param plot_state Reactive value for plot state
initialize_custom_handlers <- function(input, output, session, plot_state) {
    ns <- session$ns

    # Get configuration and required sections
    config <- get_page_complete_config("custom")
    defaults_config <- get_defaults_config()
    required_sections <- defaults_config$page_requirements$custom$required_sections
    print("Required sections:")
    str(required_sections)

    # Create visualization manager with explicit page ID
    vis_manager <- create_visualization_manager(session, "custom", ns("visualization"))

    # Initialize visualization handlers
    initialize_custom_visualization_handlers(input, output, session, vis_manager)

    # Create managers
    validation_manager <- create_validation_manager(session, "custom", ns("validation"))

    # Store validation manager in session for access by other functions
    session$userData$validation_manager <- validation_manager

    # Initialize each required section
    for (section in required_sections) {
        initialize_section(section, input, output, session, validation_manager, config)
    }

    # Handle generate button
    observeEvent(input$generate_custom, {
        print("Generate button pressed (custom)")

        if (validation_manager$is_valid()) {
            subgroup_count <- isolate(input$subgroups_count_custom)
            settings <- collect_custom_settings(input, subgroup_count)

            print("Collected settings:")
            str(settings)

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