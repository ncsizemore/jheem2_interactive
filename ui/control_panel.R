# ui/control_panel.R

create.plot.control.panel <- function(suffix) {
  # Get control settings from config
  config <- get_component_config("controls")
  controls <- config$plot_controls
  
  tags$div(
    class='controls controls_narrow',
    
    checkboxGroupInput(
      inputId = paste0('outcomes_', suffix),
      label = "Outcomes",
      choiceValues = controls$outcomes$values,
      choiceNames = controls$outcomes$names,
      selected = controls$outcomes$defaults
    ),
    
    radioButtons(
      inputId = paste0('facet_by_', suffix),
      label = "What to Facet By",
      choiceValues = controls$facet_by$values,
      choiceNames = controls$facet_by$names,
      selected = controls$facet_by$default
    ),
    
    radioButtons(
      inputId = paste0('summary_type_', suffix),
      label = "Summary Type",
      choiceValues = controls$summary_type$values,
      choiceNames = controls$summary_type$names,
      selected = controls$summary_type$default
    )
  )
}

get.control.settings <- function(input, suffix) {
  # Get control settings from config
  config <- get_component_config("controls")
  controls <- config$plot_controls
  
  print("Getting control settings:")
  print(paste("Suffix:", suffix))
  print("Input values:")
  print(paste("Outcomes:", paste(input[[paste0('outcomes_', suffix)]], collapse=", ")))
  print(paste("Facet by:", input[[paste0('facet_by_', suffix)]]))
  print(paste("Summary type:", input[[paste0('summary_type_', suffix)]]))
  
  # Default settings if input is not yet initialized
  if (is.null(input[[paste0('outcomes_', suffix)]]) ||
      is.null(input[[paste0('facet_by_', suffix)]]) ||
      is.null(input[[paste0('summary_type_', suffix)]])) {
    return(list(
      outcomes = controls$outcomes$defaults,
      facet.by = NULL,  # Default to no faceting
      summary.type = controls$summary_type$default
    ))
  }
  
  # Regular settings collection if inputs exist
  list(
    outcomes = get.selected.outcomes(input, suffix),
    facet.by = get.selected.facet.by(input, suffix),
    summary.type = get.selected.summary.type(input, suffix)
  )
}

get.main.settings <- function(input, suffix) {
  list()
}

get.selected.outcomes <- function(input, suffix) {
  config <- get_component_config("controls")
  selected <- input[[paste0('outcomes_', suffix)]]
  if (is.null(selected)) return(config$plot_controls$outcomes$defaults)
  selected
}

get.selected.facet.by <- function(input, suffix) {
  selected <- input[[paste0('facet_by_', suffix)]]
  if (is.null(selected) || selected == 'none') return(NULL)
  selected
}

get.selected.summary.type <- function(input, suffix) {
  config <- get_component_config("controls")
  selected <- input[[paste0('summary_type_', suffix)]]
  if (is.null(selected)) return(config$plot_controls$summary_type$default)
  selected
}