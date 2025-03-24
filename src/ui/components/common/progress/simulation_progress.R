# src/ui/components/common/progress/simulation_progress.R

#' Create a simulation progress component
#' @param id Module ID
#' @param store StateStore instance
#' @return Shiny module server function
simulation_progress_server <- function(id, store = get_store()) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    # Reactive values to track progress
    current_sim_id <- reactiveVal(NULL)
    show_progress <- reactiveVal(FALSE)
    
    # Get the page ID from the ID (assuming format "page_id-progress")
    page_id <- sub("-progress$", "", id)
    
    # Function to update progress
    update_progress <- function() {
      # Get current simulation ID
      sim_id <- store$get_current_simulation_id(page_id)
      
      # If no simulation, hide progress
      if (is.null(sim_id)) {
        show_progress(FALSE)
        return()
      }
      
      # Update current simulation ID
      current_sim_id(sim_id)
      
      # Get simulation state
      sim_state <- store$get_simulation(sim_id)
      
      # If status is running and we have progress data, show progress
      if (sim_state$status == "running" && !is.null(sim_state$progress)) {
        show_progress(TRUE)
      } else {
        # For completed or error states, or no progress data, hide after a delay
        later::later(function() {
          show_progress(FALSE)
        }, delay = 2)
      }
    }
    
    # Create reactive for current progress data
    progress_data <- reactive({
      # Get current simulation ID
      sim_id <- current_sim_id()
      
      # If no simulation, return empty progress
      if (is.null(sim_id)) {
        return(list(percentage = 0, current = 0, total = 0, done = FALSE))
      }
      
      # Try to get simulation state
      tryCatch({
        sim_state <- store$get_simulation(sim_id)
        
        # If we have progress data, return it
        if (!is.null(sim_state$progress)) {
          return(sim_state$progress)
        }
        
        # Otherwise, return empty progress
        list(percentage = 0, current = 0, total = 0, done = FALSE)
      }, error = function(e) {
        # If any error occurs, return empty progress
        list(percentage = 0, current = 0, total = 0, done = FALSE)
      })
    })
    
    # Observe current simulation ID changes
    observe({
      # Only for "custom" page
      if (page_id != "custom") return()
      
      sim_id <- store$get_current_simulation_id(page_id)
      
      # Skip if no change
      if (identical(sim_id, current_sim_id())) return()
      
      # Update current simulation ID and progress
      current_sim_id(sim_id)
      update_progress()
    })
    
    # Observe simulation status changes
    observe({
      # Only for "custom" page
      if (page_id != "custom") return()
      
      # Invalidate every 200ms to check progress (more responsive)
      invalidateLater(200)
      
      # Update progress
      update_progress()
    })
    
    # Render progress bar
    output$progress_bar <- renderUI({
      # Get progress data
      data <- progress_data()
      
      # If progress is not shown, return NULL
      if (!show_progress()) {
        return(NULL)
      }
      
      # Create progress bar
      div(
        class = "simulation-progress-container",
        div(
          class = "simulation-progress-item",
          div(
            class = "simulation-progress-header",
            h4("Running Intervention"),
            span(class = "progress-close", HTML("&times;"))
          ),
          div(
            class = "simulation-progress-text",
            sprintf(
              "Running simulation: %d of %d (%d%%)",
              data$current, data$total, data$percentage
            )
          ),
          div(
            class = "simulation-progress-bar",
            div(
              class = "simulation-progress-bar-inner",
              style = sprintf("width: %d%%;", data$percentage)
            )
          )
        )
      )
    })
    
    # JavaScript to handle close button
    session$sendCustomMessage("simulation_progress_init", list(id = ns("progress_bar")))
  })
}

#' Create a simulation progress UI
#' @param id Module ID
#' @return Shiny UI element
simulation_progress_ui <- function(id) {
  ns <- NS(id)
  
  # Container for progress bar
  uiOutput(ns("progress_bar"))
}
