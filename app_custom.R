# app_custom.R - Entry point for Custom Simulations Shiny Application

# Source common application setup
source("src/common_startup.R") # Handles common sourcing, library loading, and onStart

# Source common UI elements
source("src/common_ui_elements.R")

# Source common server logic
source("src/common_server_logic.R")

# Source specific layout for custom
source("src/ui/components/pages/custom/layout.R")
# Source specific handlers for custom
source("src/ui/components/pages/custom/index.R") # Contains initialize_custom_handlers

# Load CUSTOM configuration (similar to app.R)
# Configuration loading is now handled by common_startup.R
print("Loading CUSTOM page config for app_custom.R...")
CUSTOM_CONFIG <- get_page_complete_config("custom")
print("CUSTOM_CONFIG loaded.")

# UI for Custom App
ui_custom <- function() {
    create_common_ui_shell(
        app_title = "JHEEM Custom Simulations",
        tags$div(
            class = "container-fluid", # Mimic Bootstrap container
            tags$div(
                class = "tab-content", # Mimic Bootstrap tab content container
                tags$div(
                    class = "tab-pane active", # Mimic Bootstrap active tab pane
                    create_custom_layout(config = CUSTOM_CONFIG)
                )
            )
        )
    )
}

# Server for Custom App
server_custom <- function(input, output, session) {
    common_logic <- initialize_common_server_logic(input, output, session)

    # Specific custom initializations
    plot_state_custom <- reactiveVal(NULL) # Dedicated plot_state for this app instance

    # Initialize custom handlers
    initialize_custom_handlers(input, output, session, plot_state = plot_state_custom, config = CUSTOM_CONFIG)

    # Initialize panel servers (plot and table) for the "custom" page
    plot_panel_server(
        "custom",
        settings = reactive({
            get_control_settings(input, "custom") # get_control_settings from src/ui/state/controls.R
        })
        # Note: Custom page did not pass scenario_options_config in original app.R
    )

    table_panel_server(
        "custom",
        settings = reactive({
            get_control_settings(input, "custom")
        })
    )

    # Custom simulations always load the model specification after UI is flushed
    session$onFlushed(function() {
        message("[APP_CUSTOM] UI rendered, auto-loading model specification...")
        # Use model_status from common_logic or session$userData$load_model_spec
        common_logic$model_status$load_model_spec()
    })
}

# Run the Custom Application
# The onStart logic will eventually be handled by common_startup.R
shinyApp(
    ui = ui_custom,
    server = server_custom,
    onStart = get_common_onStart_function() # Defined in common_startup.R
)
