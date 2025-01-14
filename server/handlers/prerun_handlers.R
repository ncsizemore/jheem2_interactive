# server/handlers/prerun_handlers.R

#' Initialize handlers for pre-run page
#' @param input Shiny input object
#' @param output Shiny output object
#' @param session Shiny session object
initialize_prerun_handlers <- function(input, output, session) {
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
        if (validate_prerun_inputs(input)) {
            settings <- collect_prerun_settings(input)
            
            # Log settings
            print("Generating projections with settings:")
            print(settings)
            
            # Show visualization
            shinyjs::show(id = "visualization-area-prerun")
            shinyjs::show(id = "settings-settings-panel")
            
            showNotification(
                "Starting projection generation...",
                type = "message"
            )
        }
    })
}

#' Validate pre-run page inputs
#' @param input Shiny input object
#' @return Boolean indicating if inputs are valid
validate_prerun_inputs <- function(input) {
    location <- isolate(input$int_location_prerun)
    aspect <- isolate(input$int_aspect_prerun)
    
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
        aspect = isolate(input$int_aspect_prerun),
        population = isolate(input$int_tpop_prerun),
        timeframe = isolate(input$int_timeframe_prerun),
        intensity = isolate(input$int_intensity_prerun)
    )
}