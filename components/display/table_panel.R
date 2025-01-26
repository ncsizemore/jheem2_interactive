# components/display/table_panel.R

#' Create the table panel UI component
#' @param id Panel identifier
#' @return Shiny UI element containing the table panel
create_table_panel <- function(id) {
  ns <- NS(id)
  
  tags$div(
    class = "main-panel main-panel-table",
    style = "display: flex; flex-direction: column;",
    conditionalPanel(
      condition = sprintf(
        "input['%s'] === 'visible' && input['%s'] === 'table'", 
        ns("visualization_state"),
        ns("display_type")
      ),
      tags$div(
        class = "plot-panel-container",
        style = "flex: 1;",
        tags$div(
          class = "plot_holder",
          style = "height: 600px; overflow-y: auto;",
          tableOutput(ns("mainTable")),
          conditionalPanel(
            condition = sprintf("input['%s'] === 'loading'", ns("plot_status")),
            tags$div(
              class = "loading-indicator",
              tags$div(
                class = "loading-content",
                tags$span(class = "loading-spinner"),
                tags$span("Generating table...")
              )
            )
          ),
          tags$div(
            class = "hidden",
            textInput(ns("plot_status"), label = NULL, value = "ready")
          )
        )
      )
    ),
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
    
    # Get config once at initialization
    config <- get_defaults_config()
    
    # Create state managers
    vis_manager <- create_visualization_manager(session, id, ns("visualization"))
    control_manager <- create_control_manager(session, id, ns("controls"), settings)
    
    # Create validation boundary
    validation_boundary <- create_validation_boundary(
      session, 
      output, 
      id, 
      "validation",
      state_manager = vis_manager
    )
    
    # Initial table output definition
    output$mainTable <- renderTable({
      req(input$visualization_state == "visible")
      req(input$display_type == "table")
      
      vis_manager$set_plot_status("loading")
      current_settings <- control_manager$get_settings()
      
      tryCatch({
        # Get and format data using data layer
        transformed <- get_table_data(data(), current_settings)
        display_data <- format_table_data(transformed, config)
        
        output$error_message <- renderText({ NULL })
        vis_manager$set_plot_status("ready")
        
        display_data
      }, error = function(e) {
        print(paste("Error in table creation:", conditionMessage(e)))
        output$error_message <- renderText({
          sprintf("Error: %s", conditionMessage(e))
        })
        NULL
      })
    })
    
    # Combined observer for all control changes
    observe({
      print("=== Table Panel Control Update ===")
      
      # Get all current control values
      outcomes <- input[[paste0("outcomes_", id)]]
      facet_by <- input[[paste0("facet_by_", id)]]
      summary_type <- input[[paste0("summary_type_", id)]]
      
      print("Current control values:")
      print(paste("- outcomes:", paste(outcomes, collapse=", ")))
      print(paste("- facet_by:", paste(facet_by, collapse=", ")))
      print(paste("- summary_type:", summary_type))
      
      # Only proceed if we have a visible table and any controls are set
      if (!is.null(input$visualization_state) && 
          input$visualization_state == "visible" &&
          input$display_type == "table" &&
          (!is.null(outcomes) || !is.null(facet_by) || !is.null(summary_type))) {
        
        # Get current settings with isolate
        current_settings <- isolate(control_manager$get_settings())
        
        # Create settings update
        new_settings <- list(
          outcomes = if (!is.null(outcomes)) as.character(outcomes) else current_settings$outcomes,
          facet.by = if (!is.null(facet_by)) as.character(facet_by) else current_settings$facet.by,
          summary.type = if (!is.null(summary_type)) summary_type else current_settings$summary.type
        )
        
        print("Settings for table:")
        str(new_settings)
        
        # Update state and table together
        isolate({
          # Update control state
          control_manager$update_settings(new_settings)
          
          # Direct table update using data layer
          vis_manager$set_plot_status("loading")
          output$mainTable <- renderTable({
            tryCatch({
              transformed <- get_table_data(data(), new_settings)
              display_data <- format_table_data(transformed, config)
              
              output$error_message <- renderText({ NULL })
              vis_manager$set_plot_status("ready")
              
              display_data
            }, error = function(e) {
              print(paste("Error in table update:", conditionMessage(e)))
              output$error_message <- renderText({
                sprintf("Error: %s", conditionMessage(e))
              })
              NULL
            })
          })
        })
      }
    })
    
    # Reset states when visibility changes
    observeEvent(input$visualization_state, {
      if (input$visualization_state == "hidden") {
        vis_manager$reset()
        control_manager$reset()
        validation_boundary$clear()
        output$error_message <- renderText({ NULL })
      }
    })
  })
}