# server/handlers/prerun_handlers.R

initialize_prerun_handlers <- function(input, output, session, plot_state) {
  ns <- session$ns
  
  # Reset downstream selections when location changes
  observeEvent(input$int_location_prerun, {
    print(paste("Location selected:", input$int_location_prerun))
    
    if (input$int_location_prerun == 'none') {
      updateRadioButtons(session, "int_aspect_prerun", selected = "none")
    }
  })
  
  # Create visualization manager with explicit page ID
  vis_manager <- create_visualization_manager(session, "prerun", ns("visualization"))
  
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
    vis_manager$set_visibility("visible")
    updateTextInput(session, "prerun-display_type", value = "plot")
    updateTextInput(session, "prerun-visualization_state", value = "visible")
    
    # Update button states - use exact IDs
    removeClass(id = "prerun-toggle_table", class = "active", asis = TRUE)
    addClass(id = "prerun-toggle_plot", class = "active", asis = TRUE)
    
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
    vis_manager$set_visibility("visible")
    updateTextInput(session, "prerun-display_type", value = "table")
    updateTextInput(session, "prerun-visualization_state", value = "visible")
    
    # Update button states - use exact IDs
    removeClass(id = "prerun-toggle_plot", class = "active", asis = TRUE)
    addClass(id = "prerun-toggle_table", class = "active", asis = TRUE)
    
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