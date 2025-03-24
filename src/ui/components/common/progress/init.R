# src/ui/components/common/progress/init.R

source("src/ui/components/common/progress/simulation_progress.R")

#' Initialize progress tracking components 
#' @param input Shiny input object
#' @param output Shiny output object
#' @param session Shiny session object
#' @return List of progress component functions
init_progress_components <- function(input, output, session) {
  # Initialize simulation progress components
  simulation_progress_server("custom-progress")
  
  # Return list of progress functions
  list(
    simulation_progress_ui = simulation_progress_ui
  )
}
