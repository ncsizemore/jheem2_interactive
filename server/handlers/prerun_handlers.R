# server/handlers/prerun_handlers.R

#' Initialize handlers for pre-run page
#' @param input Shiny input object
#' @param output Shiny output object
#' @param session Shiny session object
#' @param plot_state Reactive value for plot state
initialize_prerun_handlers <- function(input, output, session, plot_state) {
    # Reset downstream selections when location changes
    observeEvent(input$int_location_prerun, {
        print(paste("Location selected:", input$int_location_prerun))
        
        if (input$int_location_prerun == 'none') {
            updateRadioButtons(session, "int_aspect_prerun", selected = "none")
        }
    })
    
    # Log selection changes for debugging
    observeEvent(input$int_aspect_prerun, {
        print(paste("Intervention aspect selected:", input$int_aspect_prerun))
    })
    
    observeEvent(input$int_tpop_prerun, {
        print(paste("Target population selected:", input$int_tpop_prerun))
    })
    
    observeEvent(input$int_timeframe_prerun, {
        print(paste("Time frame selected:", input$int_timeframe_prerun))
    })
    
    observeEvent(input$int_intensity_prerun, {
        print(paste("Intensity selected:", input$int_intensity_prerun))
    })
    
    # Handle generate button
    observeEvent(input$generate_projections_prerun, {
        print("Generate button pressed (prerun)")
        if (validate_prerun_inputs(input)) {
            settings <- collect_prerun_settings(input)
            print("Settings collected:")
            print(settings)
            
            # Use proper namespacing
            updateTextInput(session, session$ns("prerun-visualization_state"), value = "visible")
            print("Updated visualization state")
            
            update_display(session, input, output, 'prerun', settings, plot_state)
        }
    })
}

#' Validate pre-run page inputs
#' @param input Shiny input object
#' @return Boolean indicating if inputs are valid
validate_prerun_inputs <- function(input) {
    location <- isolate(input$int_location_prerun)
    aspect <- isolate(input$int_intervention_aspects_prerun)  # Changed from int_aspect_prerun
    
    print("Validating prerun inputs:")
    print(paste("Location:", location))
    print(paste("Aspect:", aspect))
    
    if (is.null(location) || is.null(aspect) || 
        location == 'none' || aspect == 'none') {
        showNotification(
            "Please select a location and intervention settings first",
            type = "warning"
        )
        return(FALSE)
    }
    return(TRUE)
}

#' Collect pre-run page settings
#' @param input Shiny input object
#' @return List of settings
collect_prerun_settings <- function(input) {
    list(
        location = isolate(input$int_location_prerun),
        aspect = isolate(input$int_intervention_aspects_prerun),  # Changed
        population = isolate(input$int_population_groups_prerun),
        timeframe = isolate(input$int_timeframes_prerun),
        intensity = isolate(input$int_intensities_prerun)
    )
}