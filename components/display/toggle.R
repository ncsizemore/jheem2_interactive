# components/display/toggle.R

#' Create display type toggle
#' @param id Component identifier
#' @return Shiny tags object for display toggle
create_display_toggle <- function(id) {
  ns <- NS(id)
  
  tags$div(
    class = "flex items-center space-x-4 mb-4",
    
    # Toggle buttons
    tags$div(
      class = "inline-flex rounded-md shadow-sm",
      
      # Plot button
      tags$button(
        id = ns("toggle_plot"),
        type = "button",
        class = paste(
          "px-4 py-2 text-sm font-medium",
          "border border-gray-300 rounded-l-lg",
          "focus:z-10 focus:outline-none",
          "toggle-button toggle-button-active"  # Default active state
        ),
        tags$span(
          class = "flex items-center",
          tags$i(class = "fas fa-chart-line mr-2"),  # Optional: if using Font Awesome
          "Plot"
        )
      ),
      
      # Table button
      tags$button(
        id = ns("toggle_table"),
        type = "button",
        class = paste(
          "px-4 py-2 text-sm font-medium",
          "border border-gray-300 rounded-r-lg",
          "focus:z-10 focus:outline-none",
          "toggle-button"
        ),
        tags$span(
          class = "flex items-center",
          tags$i(class = "fas fa-table mr-2"),  # Optional: if using Font Awesome
          "Table"
        )
      )
    )
  )
}

#' Display toggle server logic
#' @param id Component identifier
#' @param vis_manager Visualization manager instance
#' @return None
display_toggle_server <- function(id, vis_manager) {
  moduleServer(id, function(input, output, session) {
    # Handle plot toggle
    observeEvent(input$toggle_plot, {
      vis_manager$set_display_type("plot")
      
      # Update button states
      shinyjs::addClass(selector = "#toggle_plot", class = "toggle-button-active")
      shinyjs::removeClass(selector = "#toggle_table", class = "toggle-button-active")
    })
    
    # Handle table toggle
    observeEvent(input$toggle_table, {
      vis_manager$set_display_type("table")
      
      # Update button states
      shinyjs::addClass(selector = "#toggle_table", class = "toggle-button-active")
      shinyjs::removeClass(selector = "#toggle_plot", class = "toggle-button-active")
    })
  })
}