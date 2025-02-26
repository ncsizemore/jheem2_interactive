# src/ui/components/common/display/plot_panel.R


#' Create the plot panel UI component
#' @param id Panel identifier
#' @param type Plot type ('static' or 'interactive')
#' @return Shiny UI element containing the plot panel
create_plot_panel <- function(id, type = "static") {
  ns <- NS(id)

  tags$div(
    class = "main-panel main-panel-plot",
    conditionalPanel(
      condition = sprintf(
        "input['%s'] === 'visible' && input['%s'] === 'plot'",
        ns("visualization_state"),
        ns("display_type")
      ),
      tags$div(
        class = "panel-container",
        tags$div(
          class = "panel-content",
          plotOutput(
            ns("mainPlot"),
            height = "600px",
            width = "100%"
          ),
          # Loading indicator
          conditionalPanel(
            condition = sprintf("input['%s'] === 'loading'", ns("plot_status")),
            tags$div(
              class = "loading-indicator",
              tags$div(
                class = "loading-content",
                tags$span(class = "loading-spinner"),
                tags$span("Generating plot...")
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
    # Use a unique ID for the plot panel error message
    tags$div(
      class = "plot-error error",
      textOutput(ns("plot_error_message"), inline = FALSE)
    ),
    # Add error boundary output for structured errors
    uiOutput(ns("error_display"))
  )
}

#' Plot panel server logic
#' @param id Panel identifier
#' @param data Reactive source for plot data
#' @param settings Reactive source for plot settings
#' @return None
plot_panel_server <- function(id, settings) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    store <- get_store()
    
    # Initialize error message with NULL so it doesn't display by default
    output$plot_error_message <- renderText({
      NULL
    })
    
    # Add diagnostic observer for debugging when needed
    # observe({
    #   # Wait for panel to become visible 
    #   req(input$visualization_state == "visible")
    #   
    #   # Set a timeout to update the error message
    #   invalidateLater(2000)
    #   
    #   # Set a direct test error message for debugging
    #   print("[PLOT_PANEL] Setting test error message after delay")
    #   output$error_message <- renderText({
    #     "DELAYED TEST ERROR MESSAGE - SHOULD APPEAR 2 SECONDS AFTER PANEL VISIBLE"
    #   })
    # })

    # Create state managers
    vis_manager <- create_visualization_manager(session, id, ns("visualization"))
    control_manager <- create_control_manager(session, id, ns("controls"), settings)

    # Create error boundaries
    validation_boundary <- create_validation_boundary(
      session, output, id, "validation",
      state_manager = vis_manager
    )

    plot_boundary <- create_plot_boundary(
      session, output, id, "plot",
      state_manager = vis_manager
    )
    
    # Create simulation error boundary
    sim_boundary <- create_simulation_boundary(
      session, output, id, "simulation",
      state_manager = vis_manager
    )

    # Initial plot output definition
    output$mainPlot <- renderPlot({
      req(input$visualization_state == "visible")

      # Check if there's an error in the current simulation first
      sim_id <- store$get_current_simulation_id(id)
      if (!is.null(sim_id)) {
        sim_state <- store$get_simulation(sim_id)
        if (sim_state$status == "error") {
          # If simulation has error, don't try to render plot
          # Use the simulation boundary to display the error
          sim_boundary$set_error(
            message = sim_state$error_message,
            type = ERROR_TYPES$SIMULATION,
            severity = SEVERITY_LEVELS$ERROR
          )
          
          # Also set direct error output as fallback
          output$plot_error_message <- renderText({
            sprintf("Error: %s", sim_state$error_message)
          })
          
          # Update global error state for cross-panel persistence
          store$update_page_error_state(
            id,
            has_error = TRUE,
            message = sim_state$error_message,
            type = ERROR_TYPES$SIMULATION,
            severity = SEVERITY_LEVELS$ERROR
          )
          
          vis_manager$set_plot_status("error")
          return(NULL) # Don't render anything
        }
      }

      vis_manager$set_plot_status("loading")
      current_settings <- control_manager$get_settings()

      tryCatch(
        {
          # Get current simulation data 
          sim_state <- store$get_current_simulation_data(id)
          
          # Create plot using raw simset
          plot <- simplot(
              sim_state$simset,
              outcomes = current_settings$outcomes,
              facet.by = current_settings$facet.by,
              summary.type = current_settings$summary.type
          )
          # When plot is created successfully, clear any errors
          sim_boundary$clear()
          plot_boundary$clear()
          validation_boundary$clear()
          output$plot_error_message <- renderText({
            NULL
          })
          
          # Clear global error state
          store$clear_page_error_state(id)
          
          vis_manager$set_plot_status("ready")
          plot
        },
        error = function(e) {
          print(paste("Error in plot creation:", conditionMessage(e)))
          # Use plot_boundary for plot errors
          plot_boundary$set_error(
            message = conditionMessage(e),
            type = ERROR_TYPES$PLOT,
            severity = SEVERITY_LEVELS$ERROR
          )
          
          # Also set direct error output as fallback
          output$plot_error_message <- renderText({
            sprintf("Error: %s", conditionMessage(e))
          })
          
          NULL
        }
      )
    })

    # Combined observer for all control changes
    observe({
      print("\n=== Plot Panel Control Update ===")

      # Get all current control values
      outcomes <- input[[paste0("outcomes_", id)]]
      facet_by <- input[[paste0("facet_by_", id)]]
      summary_type <- input[[paste0("summary_type_", id)]]

      print("Current control values:")
      print(paste("- outcomes:", paste(outcomes, collapse = ", ")))
      print(paste("- facet_by:", paste(facet_by, collapse = ", ")))
      print(paste("- summary_type:", summary_type))

      # Only proceed if we have a visible plot and any controls are set
      if (!is.null(input$visualization_state) &&
        input$visualization_state == "visible" &&
        (!is.null(outcomes) || !is.null(facet_by) || !is.null(summary_type))) {
        # Get current settings with isolate
        current_settings <- isolate(control_manager$get_settings())

        # Create settings update
        new_settings <- list(
          outcomes = if (!is.null(outcomes)) as.character(outcomes) else current_settings$outcomes,
          facet.by = if (!is.null(facet_by)) as.character(facet_by) else current_settings$facet.by,
          summary.type = if (!is.null(summary_type)) summary_type else current_settings$summary.type
        )

        print("\nSettings for plot:")
        str(new_settings)

        # Update state and plot together
        isolate({
          # Update control state
          control_manager$update_settings(new_settings)

          # Direct plot update
          vis_manager$set_plot_status("loading")
          
          # Check if there's an error in the current simulation first
          sim_id <- store$get_current_simulation_id(id)
          if (!is.null(sim_id)) {
            sim_state <- store$get_simulation(sim_id)
            if (sim_state$status == "error") {
              # If simulation has error, don't try to render plot
              # Use the simulation boundary to display the error
              sim_boundary$set_error(
                message = sim_state$error_message,
                type = ERROR_TYPES$SIMULATION,
                severity = SEVERITY_LEVELS$ERROR
              )
              
              # Also set direct error output as fallback
              output$plot_error_message <- renderText({
                sprintf("Error: %s", sim_state$error_message)
              })
              
              vis_manager$set_plot_status("error")
              return() # Exit early
            }
          }
          
          output$mainPlot <- renderPlot({
            tryCatch(
              {
                # Get current simulation data
                sim_state <- store$get_current_simulation_data(id)
                
                # Create plot using raw simset
                plot <- simplot(
                    sim_state$simset,
                    outcomes = new_settings$outcomes,
                    facet.by = new_settings$facet.by,
                    summary.type = new_settings$summary.type
                )
                # When plot is updated successfully, clear any errors
                sim_boundary$clear()
                plot_boundary$clear()
                validation_boundary$clear()
                output$plot_error_message <- renderText({
                  NULL
                })
                vis_manager$set_plot_status("ready")
                plot
              },
              error = function(e) {
                print(paste("Error in plot update:", conditionMessage(e)))
                # Use plot_boundary for plot errors
                plot_boundary$set_error(
                  message = conditionMessage(e),
                  type = ERROR_TYPES$PLOT,
                  severity = SEVERITY_LEVELS$ERROR
                )
                
                # Also set direct error output as fallback
                output$plot_error_message <- renderText({
                  sprintf("Error: %s", conditionMessage(e))
                })
                
                NULL
              }
            )
          })
        })
      }
    })

    # Watch for current simulation changes and errors
    observe({
      # Get current simulation ID
      sim_id <- store$get_current_simulation_id(id)
      
      if (!is.null(sim_id)) {
        # Check if simulation has error status
        sim_state <- store$get_simulation(sim_id)
        
        if (sim_state$status == "error" && !is.null(sim_state$error_message)) {
          # Set the error using simulation boundary
          sim_boundary$set_error(
            message = sim_state$error_message,
            type = ERROR_TYPES$SIMULATION,
            severity = SEVERITY_LEVELS$ERROR
          )
          
          # Also set direct error output as fallback
          output$plot_error_message <- renderText({
            sprintf("Error: %s", as.character(sim_state$error_message))
          })
          
          # Update visualization status
          vis_manager$set_plot_status("error")
        }
      }
    })
    
    # Error persistence observer to sync with global error state
    observe({
      # Get page error state
      page_error_state <- store$get_page_error_state(id)
      
      # Check if there's a global error for this page
      if (page_error_state$has_error && !is.null(page_error_state$message)) {
        # Set error in local boundary
        sim_boundary$set_error(
          message = page_error_state$message,
          type = page_error_state$type %||% ERROR_TYPES$SIMULATION,
          severity = page_error_state$severity %||% SEVERITY_LEVELS$ERROR
        )
        
        # Also set direct error output
        output$plot_error_message <- renderText({
          sprintf("Error: %s", page_error_state$message)
        })
      }
    })
    
    # Debug observer for error state visibility
    # Create a tracker for last error state
    last_error_state <- reactiveVal(list(has_error = FALSE, message = NULL))
    
    observe({
      # Check error boundary state
      error_state <- if (!is.null(sim_boundary)) sim_boundary$get_state() else NULL
      error_visible <- !is.null(error_state) && error_state$has_error
      
      # Check direct error output
      has_direct_error <- FALSE
      tryCatch({
        direct_error <- output$plot_error_message()
        has_direct_error <- !is.null(direct_error) && nchar(direct_error) > 0
      }, error = function(e) {
        # Just catch any errors silently
      })
      
      # Only log when error state changes
      current <- list(
        has_error = error_visible,
        message = if(error_visible) error_state$message else NULL,
        direct_error = has_direct_error
      )
      
      prev <- last_error_state()
      if (!identical(current$has_error, prev$has_error) || 
          !identical(current$message, prev$message) ||
          !identical(current$direct_error, prev$direct_error)) {
        
        # Log debug info if there's any error state
        if(error_visible || has_direct_error) {
          print(sprintf("[DEBUG][%s] Error boundary: %s, Direct error: %s", 
                      id, 
                      if(error_visible) "VISIBLE" else "HIDDEN",
                      if(has_direct_error) "VISIBLE" else "HIDDEN"))
          if(error_visible) {
            print(sprintf("  Message: %s", error_state$message))
          }
        }
        
        # Update last state
        last_error_state(current)
      }
    })
    
    # Reset states when visibility changes
    observeEvent(input$visualization_state, {
      if (input$visualization_state == "hidden") {
        vis_manager$reset()
        control_manager$reset()
        validation_boundary$clear()
        plot_boundary$clear()
        sim_boundary$clear()
        output$plot_error_message <- renderText({
          NULL
        })
        
        # Clear global error state
        store$clear_page_error_state(id)
        
        # Clear simulation errors for this page if they exist
        sim_adapter <- get_simulation_adapter()
        if (!is.null(sim_adapter$error_boundaries) && !is.null(sim_adapter$error_boundaries[[id]])) {
          sim_adapter$error_boundaries[[id]]$clear()
        }
      } else if (input$visualization_state == "visible") {
        # Check for errors when becoming visible
        sim_id <- store$get_current_simulation_id(id)
        if (!is.null(sim_id)) {
          sim_state <- store$get_simulation(sim_id)
          if (sim_state$status == "error" && !is.null(sim_state$error_message)) {
            # Use the simulation boundary to display the error
            sim_boundary$set_error(
              message = sim_state$error_message,
              type = ERROR_TYPES$SIMULATION,
              severity = SEVERITY_LEVELS$ERROR
            )
            
            # Also set direct error output as fallback
            output$plot_error_message <- renderText({
              sprintf("Error: %s", sim_state$error_message)
            })
            
            vis_manager$set_plot_status("error")
          }
        }
      }
    })
  })
}
