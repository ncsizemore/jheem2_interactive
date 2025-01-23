# server/handlers/prerun_handlers.R

#' Initialize handlers for pre-run page
#' @param input Shiny input object
#' @param output Shiny output object
#' @param session Shiny session object
#' @param plot_state Reactive value for plot state
initialize_prerun_handlers <- function(input, output, session, plot_state) {
  ns <- session$ns
  print("\n=== Prerun Handler Initialization ===")
  print("1. Session namespace test:")
  print(paste("- Toggle plot ID:", "prerun-toggle_plot"))
  print(paste("- Toggle table ID:", "prerun-toggle_table"))
  
  # Create visualization manager with explicit page ID
  print("\n2. Creating Visualization Manager:")
  vis_manager <- create_visualization_manager(session, "prerun", ns("visualization"))
  print("- Visualization manager created")
  print("- Manager functions available:")
  print(names(vis_manager))
  
  # Reset downstream selections when location changes
  observeEvent(input$int_location_prerun, {
    print(paste("Location selected:", input$int_location_prerun))
    
    if (input$int_location_prerun == 'none') {
      updateRadioButtons(session, "int_aspect_prerun", selected = "none")
    }
  })
  
  print("\n3. Setting up toggle observers...")
  observeEvent(input[["prerun-toggle_plot"]], {
    print("\n=== Plot Toggle Event ===")
    print(paste("1. Event triggered at:", Sys.time()))
    
    store <- get_store()
    tryCatch({
      state <- store$get_panel_state("prerun")
      print("2. Current store state:")
      print(state$visualization)
    }, error = function(e) {
      print("Error getting store state:", e$message)
    })
    
    # Update both store and UI state
    vis_manager$set_display_type("plot")
    vis_manager$set_visibility("visible")  # Add this
    updateTextInput(session, "prerun-display_type", value = "plot")
    updateTextInput(session, "prerun-visualization_state", value = "visible")  # Add this
    
    tryCatch({
      state <- store$get_panel_state("prerun")
      print("3. Updated store state:")
      print(state$visualization)
    }, error = function(e) {
      print("Error getting updated store state:", e$message)
    })
  }, ignoreInit = TRUE)
  
  observeEvent(input[["prerun-toggle_table"]], {
    print("\n=== Table Toggle Event ===")
    print(paste("1. Event triggered at:", Sys.time()))
    
    # Add input state debugging
    print("Current input states:")
    print(paste("visualization_state:", input[["prerun-visualization_state"]]))
    print(paste("display_type:", input[["prerun-display_type"]]))
    print(paste("plot_status:", input[["prerun-plot_status"]]))
    
    store <- get_store()
    tryCatch({
      state <- store$get_panel_state("prerun")
      print("2. Current store state:")
      print(state$visualization)
    }, error = function(e) {
      print("Error getting store state:", e$message)
    })
    
    # Update both store and UI state
    vis_manager$set_display_type("table")
    vis_manager$set_visibility("visible")  # Add this
    updateTextInput(session, "prerun-display_type", value = "table")
    updateTextInput(session, "prerun-visualization_state", value = "visible")  # Add this
    
    tryCatch({
      state <- store$get_panel_state("prerun")
      print("3. Updated store state:")
      print(state$visualization)
    }, error = function(e) {
      print("Error getting updated store state:", e$message)
    })
  }, ignoreInit = TRUE)
  
  # Handle generate button
  observeEvent(input$generate_projections_prerun, {
    print("\n=== Generate Button Event ===")
    print("1. Validating inputs...")
    if (validate_prerun_inputs(input)) {
      print("2. Collecting settings...")
      settings <- collect_prerun_settings(input)
      print("Settings collected:")
      print(settings)
      
      print("3. Updating visualization state...")
      updateTextInput(session, session$ns("prerun-visualization_state"), value = "visible")
      
      print("4. Calling update_display...")
      update_display(session, input, output, 'prerun', settings, plot_state)
    }
  })
}

validate_prerun_inputs <- function(input) {
  location <- isolate(input$int_location_prerun)
  aspect <- isolate(input$int_intervention_aspects_prerun)
  
  print("Validating prerun inputs:")
  print(paste("- Location:", location))
  print(paste("- Aspect:", aspect))
  
  if (is.null(location) || is.null(aspect) || 
      location == 'none' || aspect == 'none') {
    print("- Validation failed: missing location or aspect")
    showNotification(
      "Please select a location and intervention settings first",
      type = "warning"
    )
    return(FALSE)
  }
  print("- Validation successful")
  return(TRUE)
}

collect_prerun_settings <- function(input) {
  print("Collecting prerun settings:")
  settings <- list(
    location = isolate(input$int_location_prerun),
    aspect = isolate(input$int_intervention_aspects_prerun),
    population = isolate(input$int_population_groups_prerun),
    timeframe = isolate(input$int_timeframes_prerun),
    intensity = isolate(input$int_intensities_prerun)
  )
  print("Settings collected:")
  print(settings)
  settings
}