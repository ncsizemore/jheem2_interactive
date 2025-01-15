#' Plot panel component
#' Provides visualization functionality integrated with existing plot controls
#' @importFrom shiny NS moduleServer plotOutput renderPlot
#' @importFrom htmltools tags

library(shiny)
library(ggplot2)

#' Create the plot panel UI component
#' @param id Panel identifier
#' @param type Plot type ('static' or 'interactive')
#' @return Shiny UI element containing the plot panel
create_plot_panel <- function(id, type = "static") {
    ns <- NS(id)
    
    tags$div(
        class = "main-panel main-panel-plot",
        tags$div(
            class = "plot-panel-container",
            tags$div(
                class = "plot_holder",
                tags$div(
                    class = "plot-container",
                    style = "max-width: 100%; overflow-x: hidden;",
                    plotOutput(ns("mainPlot"), 
                               height = "600px",
                               width = "100%")
                ),
                tags$div(
                    class = "loading-indicator",
                    id = ns("plotLoading"),
                    style = "display: none;",
                    "Generating plot..."
                )
            )
        )
    )
}

#' Plot panel server logic
#' @param id Panel identifier
#' @param data Reactive source for simset data
#' @param settings Reactive source for plot settings
#' @return None
plot_panel_server <- function(id, data, settings) {
    moduleServer(id, function(input, output, session) {
        # Create reactive to handle settings
        current_settings <- reactive({
            s <- settings()
            # Debug prints
            print("Plot settings:")
            print("Summary type value:")
            print(s$summary.type)
            print("Valid values are: individual.simulation, mean.and.interval, median.and.interval")
            s
        })
        
        # Get reactive dimensions from session
        dims <- reactive({
            session$clientData[[paste0('output_', session$ns('mainPlot'), '_width')]]
        })
        
        # Render plot using simplot
        output$mainPlot <- renderPlot({
            # Force redraw when dimensions change
            dims()
            
            # Get settings from reactive
            s <- current_settings()
            
            # Validate settings
            if (is.null(s$outcomes) || 
                length(s$outcomes) == 0) {
                return(NULL)
            }
            
            # Show loading state
            shinyjs::show(id = "plotLoading")
            
            # Generate plot
            plot <- tryCatch({
                simplot(
                    data(),  # simset
                    outcomes = s$outcomes,
                    facet.by = s$facet.by,
                    summary.type = s$summary.type
                )
            }, error = function(e) {
                print("Error in simplot:")
                print(e)
                NULL
            })
            
            # Hide loading state
            shinyjs::hide(id = "plotLoading")
            
            plot
        }, height = function() {
            # Dynamic height based on panel height
            600 # You could make this reactive to panel height if needed
        })
    })
}

#' Helper to initialize plot settings
#' @return List of default plot settings
initialize_plot_settings <- function() {
    list(
        outcomes = NULL,
        facet.by = NULL,
        summary.type = "mean.and.interval"  # Make sure this matches simplot's requirements
    )
}