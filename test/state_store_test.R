# test/state_store_test.R

library(shiny)
source("src/ui/state/types.R")
source("src/ui/state/store.R")

# Test UI
ui <- fluidPage(
    titlePanel("State Store Test"),
    
    fluidRow(
        column(4,
               # Test controls
               actionButton("show_plot", "Show Plot"),
               actionButton("hide_plot", "Hide Plot"),
               actionButton("set_error", "Set Error"),
               actionButton("clear_error", "Clear Error")
        ),
        column(8,
               # State display
               verbatimTextOutput("current_state")
        )
    )
)

# Test server
server <- function(input, output, session) {
    # Get store instance
    store <- get_store()
    
    # Show plot handler
    observeEvent(input$show_plot, {
        store$update_visualization_state(
            "prerun",
            visibility = "visible",
            plot_status = "ready"
        )
    })
    
    # Hide plot handler
    observeEvent(input$hide_plot, {
        store$update_visualization_state(
            "prerun",
            visibility = "hidden"
        )
    })
    
    # Set error handler
    observeEvent(input$set_error, {
        store$update_visualization_state(
            "prerun",
            plot_status = "error",
            error_message = "Test error message"
        )
    })
    
    # Clear error handler
    observeEvent(input$clear_error, {
        store$update_visualization_state(
            "prerun",
            plot_status = "ready",
            error_message = ""
        )
    })
    
    # Display current state
    output$current_state <- renderPrint({
        # Force reactivity on panel state changes
        invalidateLater(100)
        state <- store$get_panel_state("prerun")
        str(state)
    })
}

# Run the test app if file is executed directly
if (interactive()) {
    shinyApp(ui = ui, server = server)
}