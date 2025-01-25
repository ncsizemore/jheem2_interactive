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

#' Create formatted table from plot data
#' @param plot_data List containing df.sim and df.truth data frames
#' @return Data frame formatted for table display
create_table_from_plot_data <- function(plot_data) {
  # Validate input
  if (is.null(plot_data) || !all(c("df.sim", "df.truth") %in% names(plot_data))) {
    print("Error: Invalid plot_data structure")
    return(data.frame())
  }
  
  # Extract components
  df.sim <- plot_data$df.sim
  df.truth <- plot_data$df.truth
  
  print("Available columns in df.sim:")
  print(names(df.sim))
  
  # Helper functions
  format_number <- function(x) {
    if (is.null(x) || length(x) == 0) return(NA_character_)
    ifelse(is.na(x), "NA",
           ifelse(x >= 100, as.character(round(x)), 
                  as.character(round(x, 1))))
  }
  
  create_interval <- function(mean, lower, upper) {
    if (any(sapply(list(mean, lower, upper), function(x) is.null(x) || length(x) == 0))) {
      return(NA_character_)
    }
    paste0(format_number(mean), " (", 
           format_number(lower), "-",
           format_number(upper), ")")
  }
  
  # Create base simulation data frame
  sim_data <- data.frame(
    Year = as.integer(df.sim$year),
    Source = "Projected",
    Outcome = df.sim$outcome.display.name,
    stringsAsFactors = FALSE
  )
  
  # Add computed value column with clean name
  value_col_name <- if (!is.null(df.sim$summary.type) && 
                        length(df.sim$summary.type) > 0 && 
                        grepl("median", df.sim$summary.type[1], ignore.case=TRUE)) {
    "Median (95% CI)"
  } else {
    "Mean (95% CI)"
  }
  
  sim_data[[value_col_name]] <- mapply(
    create_interval,
    df.sim$value.mean,
    df.sim$value.lower,
    df.sim$value.upper,
    SIMPLIFY = TRUE,
    USE.NAMES = FALSE
  )
  
  # Create base truth data frame
  truth_data <- data.frame(
    Year = as.integer(df.truth$year),
    Source = "Historical",
    Outcome = df.truth$outcome.display.name,
    stringsAsFactors = FALSE
  )
  
  truth_data[[value_col_name]] <- sapply(df.truth$value, format_number)
  
  # Extract faceting columns, preferring non-facet.by versions
  all_cols <- names(df.sim)
  # Get base faceting columns (no facet.by prefix)
  facet_cols <- setdiff(all_cols[!grepl("^facet\\.by", all_cols)],
                        c("year", "simset", "outcome", "linewidth", "alpha", 
                          "outcome.display.name", "value.mean", "value.lower", 
                          "value.upper", "value", "stratum", "sim", "groupid"))
  
  print("Selected faceting columns:")
  print(facet_cols)
  
  if (length(facet_cols) > 0) {
    # Add faceting columns to both data frames
    for (col in facet_cols) {
      # Capitalize column names
      new_col <- paste0(toupper(substr(col, 1, 1)), substr(col, 2, nchar(col)))
      sim_data[[new_col]] <- df.sim[[col]]
      if (col %in% names(df.truth)) {
        truth_data[[new_col]] <- df.truth[[col]]
      } else {
        truth_data[[new_col]] <- NA
      }
    }
  }
  
  # Combine the data frames
  combined_data <- rbind(sim_data, truth_data)
  
  # Sort data
  sort_cols <- c("Year")
  if (length(facet_cols) > 0) {
    sort_cols <- c(sort_cols, paste0(toupper(substr(facet_cols, 1, 1)), 
                                     substr(facet_cols, 2, nchar(facet_cols))))
  }
  sort_cols <- c(sort_cols, "Source", "Outcome")
  
  combined_data <- combined_data[do.call(order, combined_data[sort_cols]), ]
  
  return(combined_data)
}

#' Table panel server logic
#' @param id Panel identifier
#' @param data Reactive source for table data
#' @param settings Reactive source for display settings
#' @return None
table_panel_server <- function(id, data, settings) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    # Create state managers - same as plot panel
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
        # Use prepare.simulations.plot.and.table with proper settings
        plot_and_table <- prepare.simulations.plot.and.table(
          simset = data(),
          outcomes = current_settings$outcomes,
          facet.by = current_settings$facet.by,
          summary.type = current_settings$summary.type
        )
        
        # Convert plot data to table format
        table_data <- create_table_from_plot_data(plot_and_table$plot)
        
        output$error_message <- renderText({ NULL })
        vis_manager$set_plot_status("ready")
        
        table_data
      }, error = function(e) {
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
          
          # Direct table update
          vis_manager$set_plot_status("loading")
          output$mainTable <- renderTable({
            tryCatch({
              plot_and_table <- prepare.simulations.plot.and.table(
                simset = data(),
                outcomes = new_settings$outcomes,
                facet.by = new_settings$facet.by,
                summary.type = new_settings$summary.type
              )
              
              table_data <- create_table_from_plot_data(plot_and_table$plot)
              
              output$error_message <- renderText({ NULL })
              vis_manager$set_plot_status("ready")
              
              table_data
            }, error = function(e) {
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