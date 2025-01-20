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
                
                # Error displays at the top - modified this part
                tags$div(
                    class = "error-display-debug",  # Added debug class
                    uiOutput(ns("error_display"))
                ),
                
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
        validation_boundary <- create_validation_boundary(
            session, output, id, ns("validation"),
            state_manager = vis_manager
        )
        
        plot_boundary <- create_plot_boundary(
            session, output, id, ns("plot"),
            state_manager = vis_manager
        )
        
        # Add debug observer here
        observe({
            print("=== Error State Debug ===")
            print("Plot boundary structure:")
            str(plot_boundary)
        })
        
        # Plot generation with error handling
        generate_plot_safely <- function(settings_to_use) {
            plot_boundary$clear()
            
            tryCatch({
                print("Attempting simplot...")
                simplot(
                    data(),
                    outcomes = settings_to_use$outcomes,
                    facet.by = settings_to_use$facet.by,
                    summary.type = settings_to_use$summary.type
                )
            }, error = function(e) {
                print(paste("Error in plot generation:", conditionMessage(e)))
                plot_boundary$set_error(
                    "Error generating plot",
                    type = ERROR_TYPES$PLOT,
                    details = conditionMessage(e)
                )
                NULL
            })
        }
        
        # Initial plot output definition - will be updated by observers
        output$mainPlot <- renderPlot({
            print("=== Initial Plot Render ===")
            req(input$visualization_state == "visible")
            
            vis_manager$set_plot_status("loading")
            current_settings <- control_manager$get_settings()
            
            plot <- generate_plot_safely(current_settings)
            if (!is.null(plot)) {
                vis_manager$set_plot_status("ready")
            }
            
            plot
        })
        
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
                
                # Update state and plot together
                isolate({
                    # Update control state
                    control_manager$update_settings(new_settings)
                    
                    # Direct plot update
                    vis_manager$set_plot_status("loading")
                    plot <- generate_plot_safely(new_settings)
                    if (!is.null(plot)) {
                        vis_manager$set_plot_status("ready")
                    }
                    output$mainPlot <- renderPlot({ plot })
                })
            }
        })
        
        # Reset states when visibility changes
        observeEvent(input$visualization_state, {
            if (input$visualization_state == "hidden") {
                vis_manager$reset()
                control_manager$reset()
                validation_boundary$clear()
                plot_boundary$clear()
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
