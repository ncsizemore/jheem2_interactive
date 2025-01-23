# server/handlers/custom_handlers.R

#' Initialize handlers for custom page
#' @param input Shiny input object
#' @param output Shiny output object
#' @param session Shiny session object
#' @param plot_state Reactive value for plot state
initialize_custom_handlers <- function(input, output, session, plot_state) {
  ns <- session$ns  # Get namespace function
  
  # Handle subgroup count changes
  observeEvent(input$subgroups_count_custom, {
    print(paste("Subgroups count changed:", input$subgroups_count_custom))
  })
  
  # Create visualization manager with explicit page ID
  vis_manager <- create_visualization_manager(session, "custom", ns("visualization"))
  
  # Handle toggle buttons
  # Handle toggle buttons
  observeEvent(input[["custom-toggle_plot"]], {
    print("\n=== Plot Toggle Event ===")
    print(paste("1. Event triggered at:", Sys.time()))
    
    store <- get_store()
    tryCatch({
      state <- store$get_panel_state("custom")
      print("2. Current store state:")
      print(state$visualization)
    }, error = function(e) {
      print("Error getting store state:", e$message)
    })
    
    # Update both store and UI state
    vis_manager$set_display_type("plot")
    vis_manager$set_visibility("visible")
    updateTextInput(session, "custom-display_type", value = "plot")
    updateTextInput(session, "custom-visualization_state", value = "visible")
    
    # Update button states
    removeClass(id = "custom-toggle_table", class = "active")
    addClass(id = "custom-toggle_plot", class = "active")
    
    tryCatch({
      state <- store$get_panel_state("custom")
      print("3. Updated store state:")
      print(state$visualization)
    }, error = function(e) {
      print("Error getting updated store state:", e$message)
    })
  }, ignoreInit = TRUE)
  
  observeEvent(input[["custom-toggle_table"]], {
    print("\n=== Table Toggle Event ===")
    print(paste("1. Event triggered at:", Sys.time()))
    
    store <- get_store()
    tryCatch({
      state <- store$get_panel_state("custom")
      print("2. Current store state:")
      print(state$visualization)
    }, error = function(e) {
      print("Error getting store state:", e$message)
    })
    
    # Update both store and UI state
    vis_manager$set_display_type("table")
    vis_manager$set_visibility("visible")
    updateTextInput(session, "custom-display_type", value = "table")
    updateTextInput(session, "custom-visualization_state", value = "visible")
    
    # Update button states
    removeClass(id = "custom-toggle_plot", class = "active")
    addClass(id = "custom-toggle_table", class = "active")
    
    tryCatch({
      state <- store$get_panel_state("custom")
      print("3. Updated store state:")
      print(state$visualization)
    }, error = function(e) {
      print("Error getting updated store state:", e$message)
    })
  }, ignoreInit = TRUE)
  
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
    print("Generate button pressed (custom)")
    if (validate_custom_inputs(input)) {
      # Get subgroup count and settings
      subgroup_count <- isolate(input$subgroups_count_custom)
      settings <- collect_custom_settings(input, subgroup_count)
      
      # Update visualization state
      updateTextInput(session, session$ns("custom-visualization_state"), value = "visible")
      
      # Call update_display with settings
      update_display(session, input, output, 'custom', settings, plot_state)
      
      showNotification(
        "Custom projections starting...",
        type = "message"
      )
    }
  })
}


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