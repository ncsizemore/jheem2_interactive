# components/display/plot_panel.R

#' Create the plot panel UI component
#' @param id Panel identifier
#' @param type Plot type ('static' or 'interactive')
#' @return Shiny UI element containing the plot panel
create_plot_panel <- function(id, type = "static") {
    ns <- NS(id)
    
    tags$div(
        class = "main-panel main-panel-plot",
        
        # Hidden input for visibility state
        tags$div(
            class = "hidden",
            textInput(
                ns("visualization_state"),
                label = NULL,
                value = "hidden"
            )
        ),
        
        # Main panel content
        conditionalPanel(
            condition = sprintf("input['%s'] === 'visible'", ns("visualization_state")),
            tags$div(
                class = "plot-panel-container",
                
                # Error displays at the top
                uiOutput(ns("error_display")),
                
                tags$div(
                    class = "plot_holder",
                    
                    # Plot container
                    tags$div(
                        class = "plot-container",
                        style = "max-width: 100%; overflow-x: hidden;",
                        
                        # Plot output
                        plotOutput(
                            ns("mainPlot"),
                            height = "600px",
                            width = "100%"
                        )
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
                    
                    # Hidden inputs for state management
                    tags$div(
                        class = "hidden",
                        textInput(
                            ns("plot_status"),
                            label = NULL,
                            value = "ready"
                        ),
                        textInput(
                            ns("error_message"),
                            label = NULL,
                            value = ""
                        )
                    )
                )
            )
        )
    )
}

#' Plot panel server logic
#' @param id Panel identifier
#' @param data Reactive source for plot data
#' @param settings Reactive source for plot settings
#' @return None
plot_panel_server <- function(id, data, settings) {
    moduleServer(id, function(input, output, session) {
        ns <- session$ns
        
        # Create state managers
        vis_manager <- create_visualization_manager(session, id, ns("visualization"))
        control_manager <- create_control_manager(session, id, ns("controls"), settings)
        
        # Create error boundaries
        validation_boundary <- create_validation_boundary(session, output, id, ns("validation"))
        plot_boundary <- create_plot_boundary(session, output, id, ns("plot"))
        
        # Create plot generation function that includes error handling
        generate_plot <- function(settings_to_use) {
            # Clear any previous errors first
            plot_boundary$clear()  # Changed from clear_error to clear
            
            # Generate plot with error handling
            result <- tryCatch({
                plot <- simplot(
                    data(),
                    outcomes = settings_to_use$outcomes,
                    facet.by = settings_to_use$facet.by,
                    summary.type = settings_to_use$summary.type
                )
                list(success = TRUE, plot = plot)
            }, error = function(e) {
                plot_boundary$set_error(conditionMessage(e), "plot")
                list(success = FALSE, error = conditionMessage(e))
            })
            
            # Return the plot if successful, otherwise NULL
            if (result$success) result$plot else NULL
        }
        
        # Combined observer for all control changes
        observe({
            print("=== Plot Panel Control Update ===")
            
            # Get all current control values
            outcomes <- input[[paste0("outcomes_", id)]]
            facet_by <- input[[paste0("facet_by_", id)]]
            summary_type <- input[[paste0("summary_type_", id)]]
            
            print("Current control values:")
            print(paste("- outcomes:", paste(outcomes, collapse=", ")))
            print(paste("- facet_by:", paste(facet_by, collapse=", ")))
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
                
                print("Settings for plot:")
                str(new_settings)
                
                # Update state and plot within isolate
                isolate({
                    # Update control state
                    control_manager$update_settings(new_settings)
                    
                    # Update plot output
                    output$mainPlot <- renderPlot({
                        generate_plot(new_settings)
                    })
                })
            }
        })
        
        # Initial plot rendering
        output$mainPlot <- renderPlot({
            print("=== Initial Plot Render ===")
            print(paste("Visualization state:", input$visualization_state))
            
            req(input$visualization_state == "visible")
            
            # Set loading state
            vis_manager$set_plot_status("loading")
            
            # Get current settings
            current_settings <- control_manager$get_settings()
            print("Initial settings:")
            str(current_settings)
            
            # Validate data
            validate(need(
                !is.null(data()),
                "No simulation data available"
            ))
            
            # Generate plot
            plot <- generate_plot(current_settings)
            
            if (!is.null(plot)) {
                vis_manager$set_plot_status("ready")
            }
            
            plot
        })
        
        # Reset states when visibility changes
        observeEvent(input$visualization_state, {
            if (input$visualization_state == "hidden") {
                vis_manager$reset()
                control_manager$reset()
                validation_boundary$clear()  # Changed from clear_error to clear
                plot_boundary$clear()  # Changed from clear_error to clear
            }
        })
        
        # Add error boundary UI
        output[[ns("error_display")]] <- renderUI({
            tags$div(
                class = "error-displays",
                validation_boundary$ui(),
                plot_boundary$ui()
            )
        })
    })
}