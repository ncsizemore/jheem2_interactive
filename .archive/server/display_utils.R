# server/display_utils.R

#' Update display with new plot and table
#' @param session Shiny session object
#' @param input Shiny input object
#' @param output Shiny output object
#' @param suffix Page suffix ('prerun' or 'custom')
#' @param intervention.settings Settings for intervention
#' @param plot_state Reactive value for plot state
update_display <- function(session, input, output, suffix, intervention.settings, plot_state) {
  get.display.size(input, suffix)
  config <- get_defaults_config()
  
  print("Generating new plot and table")
  
  # Get display settings from control panel
  display_settings <- get_control_settings(input, suffix)
  print("Display settings:")
  str(display_settings)
  
  # Get and transform data using data layer
  settings <- list(
    outcomes = display_settings$outcomes,
    facet.by = display_settings$facet.by,
    summary.type = display_settings$summary.type
  )
  
  # Get appropriate simulation data
  simset <- get_simulation_data(intervention.settings, mode = suffix)
  
  # Transform the data
  transformed <- transform_simulation_data(simset, settings)
  
  # Create plot-and-table structure to match existing expectations
  new.plot.and.table <- list(
    plot = transformed$plot,
    main.settings = list(),
    control.settings = settings,
    int.settings = intervention.settings
  )
  
  if (!is.null(new.plot.and.table)) {
    print("Updating display state")
    # Update the state
    current_state <- plot_state()
    current_state[[suffix]] <- new.plot.and.table
    plot_state(current_state)
    
    # Update the UI
    set.display(input, output, suffix, new.plot.and.table)
    sync_buttons_to_plot(input, plot_state())
  }
}