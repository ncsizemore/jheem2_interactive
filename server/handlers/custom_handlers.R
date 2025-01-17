# server/handlers/custom_handlers.R

#' Initialize handlers for custom page
#' @param input Shiny input object
#' @param output Shiny output object
#' @param session Shiny session object
#' @param plot_state Reactive value for plot state
initialize_custom_handlers <- function(input, output, session, plot_state) {
    # Handle subgroup count changes
    observeEvent(input$subgroups_count_custom, {
        print(paste("Subgroups count changed:", input$subgroups_count_custom))
    })
    
    # Render dynamic subgroup panels
    output$subgroup_panels_custom <- renderUI({
        req(input$subgroups_count_custom)
        
        # Get configuration
        config <- get_page_complete_config("custom")
        
        # Create panels for each subgroup
        panels <- lapply(1:input$subgroups_count_custom, function(i) {
            create_subgroup_panel(i, config)
        })
        
        do.call(tagList, panels)
    })
    
    # Handle generate button
    observeEvent(input$generate_custom, {
        if (validate_custom_inputs(input)) {
            # Get subgroup count and settings
            subgroup_count <- isolate(input$subgroups_count_custom)
            settings <- collect_custom_settings(input, subgroup_count)
            
            # Fix the namespacing to match prerun pattern
            updateTextInput(session, session$ns("custom-visualization_state"), value = "visible")
            print("Updated visualization state")
            
            # Call update_display with settings
            update_display(session, input, output, 'custom', settings, plot_state)
            
            showNotification(
                "Custom projections starting...",
                type = "message"
            )
        }
    })
}

#' Validate custom page inputs
#' @param input Shiny input object
#' @return Boolean indicating if inputs are valid
validate_custom_inputs <- function(input) {
    location <- isolate(input$int_location_custom)
    
    if (is.null(location) || location == 'none') {
        showNotification(
            "Please select a location first",
            type = "warning"
        )
        return(FALSE)
    }
    return(TRUE)
}

#' Collect settings for a single subgroup
#' @param input Shiny input object
#' @param group_num Subgroup number
#' @return List of subgroup settings
collect_subgroup_settings <- function(input, group_num) {
    list(
        demographics = list(
            age_groups = isolate(input[[paste0("int_age_groups_", group_num, "_custom")]]),
            race_ethnicity = isolate(input[[paste0("int_race_ethnicity_", group_num, "_custom")]]),
            biological_sex = isolate(input[[paste0("int_biological_sex_", group_num, "_custom")]]),
            risk_factor = isolate(input[[paste0("int_risk_factor_", group_num, "_custom")]])
        ),
        interventions = list(
            dates = list(
                start = isolate(input[[paste0("int_intervention_dates_", group_num, "_custom_start")]]),
                end = isolate(input[[paste0("int_intervention_dates_", group_num, "_custom_end")]])
            ),
            testing = if (isolate(input[[paste0("int_testing_", group_num, "_custom_enabled")]])) {
                list(frequency = isolate(input[[paste0("int_testing_", group_num, "_custom_frequency")]]))
            },
            prep = if (isolate(input[[paste0("int_prep_", group_num, "_custom_enabled")]])) {
                list(coverage = isolate(input[[paste0("int_prep_", group_num, "_custom_coverage")]]))
            },
            suppression = if (isolate(input[[paste0("int_suppression_", group_num, "_custom_enabled")]])) {
                list(proportion = isolate(input[[paste0("int_suppression_", group_num, "_custom_proportion")]]))
            }
        )
    )
}


#' Collect all custom page settings
#' @param input Shiny input object
#' @param subgroup_count Number of subgroups
#' @return List of all settings
collect_custom_settings <- function(input, subgroup_count) {
    print("Collecting custom settings")
    
    # Get plot control settings
    plot_settings <- get.control.settings(input, "custom")
    print("Plot settings:")
    str(plot_settings)
    
    # Get intervention settings
    intervention_settings <- list(
        location = isolate(input$int_location_custom),
        subgroups = lapply(1:subgroup_count, function(i) {
            collect_subgroup_settings(input, i)
        })
    )
    print("Intervention settings:")
    str(intervention_settings)
    
    # Combine both types of settings
    c(plot_settings, intervention_settings)
}