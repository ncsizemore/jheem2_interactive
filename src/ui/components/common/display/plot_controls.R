# src/ui/components/common/display/plot_controls.R

#' Create a plot control panel
#' @param suffix Page suffix (prerun or custom)
#' @return Shiny UI element containing plot controls
create_plot_control_panel <- function(suffix) {
  # Get control settings from config
  config <- get_component_config("controls")
  controls <- config$plot_controls

  tags$div(
    class = "controls controls_narrow",

    # Outcomes selection
    checkboxGroupInput(
      inputId = paste0("outcomes_", suffix),
      label = "Outcomes",
      choiceValues = controls$outcomes$values,
      choiceNames = controls$outcomes$names,
      selected = controls$outcomes$defaults
    ),

    # Faceting selection
    radioButtons(
      inputId = paste0("facet_by_", suffix),
      label = "What to Facet By",
      choiceValues = controls$facet_by$values,
      choiceNames = controls$facet_by$names,
      selected = controls$facet_by$default
    ),

    # Summary type selection
    radioButtons(
      inputId = paste0("summary_type_", suffix),
      label = "Summary Type",
      choiceValues = controls$summary_type$values,
      choiceNames = controls$summary_type$names,
      selected = controls$summary_type$default
    )
  )
}

#' Get current plot control settings
#' @param input Shiny input object
#' @param suffix Page suffix (prerun or custom)
#' @return List of plot control settings
get_control_settings <- function(input, suffix) {
  # Get control settings from config
  config <- get_component_config("controls")
  controls <- config$plot_controls

  print("Getting control settings:")
  print(paste("Suffix:", suffix))
  print("Input values:")
  print(paste("Outcomes:", paste(input[[paste0("outcomes_", suffix)]], collapse = ", ")))
  print(paste("Facet by:", input[[paste0("facet_by_", suffix)]]))
  print(paste("Summary type:", input[[paste0("summary_type_", suffix)]]))

  # Default settings if input is not yet initialized
  if (is.null(input[[paste0("outcomes_", suffix)]]) ||
    is.null(input[[paste0("facet_by_", suffix)]]) ||
    is.null(input[[paste0("summary_type_", suffix)]])) {
    return(list(
      outcomes = controls$outcomes$defaults,
      facet.by = NULL, # Default to no faceting
      summary.type = controls$summary_type$default
    ))
  }

  # Regular settings collection if inputs exist
  list(
    outcomes = get_selected_outcomes(input, suffix),
    facet.by = get_selected_facet_by(input, suffix),
    summary.type = get_selected_summary_type(input, suffix)
  )
}

#' Get selected outcomes
#' @param input Shiny input object
#' @param suffix Page suffix
#' @return Vector of selected outcomes
get_selected_outcomes <- function(input, suffix) {
  config <- get_component_config("controls")
  selected <- input[[paste0("outcomes_", suffix)]]
  if (is.null(selected)) {
    return(config$plot_controls$outcomes$defaults)
  }
  selected
}

#' Get selected faceting option
#' @param input Shiny input object
#' @param suffix Page suffix
#' @return Selected faceting option or NULL
get_selected_facet_by <- function(input, suffix) {
  selected <- input[[paste0("facet_by_", suffix)]]
  if (is.null(selected) || selected == "none") {
    return(NULL)
  }
  selected
}

#' Get selected summary type
#' @param input Shiny input object
#' @param suffix Page suffix
#' @return Selected summary type
get_selected_summary_type <- function(input, suffix) {
  config <- get_component_config("controls")
  selected <- input[[paste0("summary_type_", suffix)]]
  if (is.null(selected)) {
    return(config$plot_controls$summary_type$default)
  }
  selected
}
