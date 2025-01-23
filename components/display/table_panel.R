#' Create the table panel UI component
#' @param id Panel identifier
#' @return Shiny UI element containing the table panel
#' Create the table panel UI component
#' @param id Panel identifier
#' @return Shiny UI element containing the table panel
create_table_panel <- function(id) {
  ns <- NS(id)
  
  tags$div(
    class = "main-panel main-panel-table",
    style = "display: flex; flex-direction: column;", # Add flex behavior
    conditionalPanel(
      condition = sprintf(
        "input['%s'] === 'visible' && input['%s'] === 'table'", 
        ns("visualization_state"),
        ns("display_type")
      ),
      tags$div(
        class = "plot-panel-container",  # Use same container class as plot
        style = "flex: 1;", # Match plot flex behavior
        # Table container
        tags$div(
          class = "plot_holder",  # Use same holder class as plot
          style = "height: 600px; overflow-y: auto;",
          tableOutput(ns("mainTable")),
          # Loading indicator
          conditionalPanel(
            condition = sprintf(
              "input['%s'] === 'loading'",
              ns("plot_status")
            ),
            tags$div(
              class = "loading-indicator",
              tags$div(
                class = "loading-content",
                tags$span(class = "loading-spinner"),
                tags$span("Generating table...")
              )
            )
          ),
          # Hidden status input
          tags$div(
            class = "hidden",
            textInput(
              ns("plot_status"),
              label = NULL,
              value = "ready"
            )
          )
        )
      )
    ),
    # Error display outside conditional panel
    tags$div(
      class = "plot-error error",
      textOutput(ns("error_message"))
    )
  )
}

#' Table panel server logic
#' @param id Panel identifier
#' @param data Reactive source for table data
#' @param settings Reactive source for display settings
#' @return None
table_panel_server <- function(id, data, settings) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    # Create state managers
    vis_manager <- create_visualization_manager(session, id, ns("visualization"))
    control_manager <- create_control_manager(session, id, ns("controls"), settings)
    
    # Create reactive value to store table data
    table_data <- reactiveVal(NULL)
    
    # Create table data when settings change
    observe({
      req(input$visualization_state == "visible")
      req(input$display_type == "table")
      current_settings <- settings()
      
      isolate({
        print("Preparing table data...")
        vis_manager$set_plot_status("loading")
        
        tryCatch({
          simset <- data()
          years <- seq(simset$from.year, simset$to.year)
          raw_data <- simset$get(
            outcomes = current_settings$outcomes[1],
            output = "value"
          )
          
          summarized_data <- data.frame(
            Year = years,
            Mean = apply(raw_data, 1, mean),
            Lower = apply(raw_data, 1, function(x) quantile(x, 0.025)),
            Upper = apply(raw_data, 1, function(x) quantile(x, 0.975))
          )
          
          table_data(summarized_data)
          vis_manager$set_plot_status("ready")
          output$error_message <- renderText({ NULL })
          
        }, error = function(e) {
          print(paste("Error preparing table data:", e$message))
          vis_manager$set_plot_status("error")
          output$error_message <- renderText({
            sprintf("Error: %s", conditionMessage(e))
          })
          table_data(NULL)
        })
      })
    })
    
    # Render table using cached data
    output$mainTable <- renderTable({
      req(input$visualization_state == "visible")
      req(input$display_type == "table")
      
      print("Rendering table from cached data")
      table_data()
    })
  })
}