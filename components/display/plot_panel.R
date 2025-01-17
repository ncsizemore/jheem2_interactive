# components/display/plot_panel.R

#' Create the plot panel UI component
#' @param id Panel identifier
#' @param type Plot type ('static' or 'interactive')
#' @return Shiny UI element containing the plot panel
create_plot_panel <- function(id, type = "static") {
    ns <- NS(id)
    
    tags$div(
        class = "main-panel main-panel-plot",
        
        # Hidden input for visibility state - wrap in div with hidden class
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
                    
                    # Error display
                    conditionalPanel(
                        condition = sprintf("input['%s'] !== ''", ns("error_message")),
                        tags$div(
                            class = "error-container",
                            textOutput(ns("errorText"))
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
                
                # Get base settings and update with all current control values
                settings_copy <- isolate(settings())
                
                if (!is.null(outcomes)) {
                    settings_copy$outcomes <- as.character(outcomes)
                }
                
                if (!is.null(facet_by)) {
                    settings_copy$facet.by <- if(length(facet_by) > 0) as.character(facet_by) else NULL
                }
                
                if (!is.null(summary_type)) {
                    settings_copy$summary.type <- summary_type
                }
                
                print("Final settings for plot:")
                str(settings_copy)
                
                # Update the plot
                output$mainPlot <- renderPlot({
                    print("Rendering plot with settings:")
                    str(settings_copy)
                    
                    simplot(
                        data(),
                        outcomes = settings_copy$outcomes,
                        facet.by = settings_copy$facet.by,
                        summary.type = settings_copy$summary.type
                    )
                })
            }
        })
        
        # Create a reactive value to track plot completion
        plot_rendered <- reactiveVal(FALSE)
        
        # Initial plot rendering
        output$mainPlot <- renderPlot({
            print("=== Initial Plot Render ===")
            print(paste("Visualization state:", input$visualization_state))
            
            req(input$visualization_state == "visible")
            
            # Reset plot completion flag
            plot_rendered(FALSE)
            
            # Set loading state
            updateTextInput(session, "plot_status", value = "loading")
            
            # Get current settings
            settings_to_use <- settings()
            print("Initial settings:")
            str(settings_to_use)
            
            # Validate requirements
            validate(need(
                !is.null(settings_to_use$outcomes) && length(settings_to_use$outcomes) > 0,
                "Please select at least one outcome to display"
            ))
            
            validate(need(
                !is.null(data()),
                "No simulation data available"
            ))
            
            # Clear any previous error
            updateTextInput(session, "error_message", value = "")
            
            # Generate plot
            tryCatch({
                plot <- simplot(
                    data(),
                    outcomes = settings_to_use$outcomes,
                    facet.by = settings_to_use$facet.by,
                    summary.type = settings_to_use$summary.type
                )
                
                print("Initial plot generated successfully")
                plot_rendered(TRUE)
                
                plot
            }, error = function(e) {
                print("Error in plot generation:")
                print(conditionMessage(e))
                updateTextInput(session, "plot_status", value = "error")
                updateTextInput(session, "error_message", value = conditionMessage(e))
                NULL
            })
        })
        
        # Watch for plot completion
        observe({
            if (plot_rendered()) {
                updateTextInput(session, "plot_status", value = "ready")
            }
        })
        
        # Error message output
        output$errorText <- renderText({
            input$error_message
        })
        
        # Reset states when visibility changes
        observeEvent(input$visualization_state, {
            if (input$visualization_state == "hidden") {
                updateTextInput(session, "plot_status", value = "ready")
                updateTextInput(session, "error_message", value = "")
                plot_rendered(FALSE)
            }
        })
    })
}