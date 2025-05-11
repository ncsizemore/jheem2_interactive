# app_prerun.R - Entry point for Prerun Scenarios Shiny Application

# Source common application setup
source("src/common_startup.R") # Handles common sourcing, library loading, and onStart

# Source common UI elements
source("src/common_ui_elements.R")

# Source common server logic
source("src/common_server_logic.R")

# Source specific layout for prerun
source("src/ui/components/pages/prerun/layout.R")
# Source specific handlers for prerun
source("src/ui/components/pages/prerun/index.R") # Contains initialize_prerun_handlers

# Load PRERUN configuration (similar to app.R)
# Need to ensure get_page_complete_config is available, likely via common_startup.R
# For now, we might need to source it directly if common_startup.R isn't made first.
# Configuration loading is now handled by common_startup.R
print("Loading PRERUN page config for app_prerun.R...")
PRERUN_CONFIG <- get_page_complete_config("prerun")
print("PRERUN_CONFIG loaded.")

# UI for Prerun App
ui_prerun <- function() {
    create_common_ui_shell(
        app_title = "JHEEM Prerun Scenarios",
        tags$div(
            class = "container-fluid", # Mimic Bootstrap container
            tags$div(
                class = "tab-content", # Mimic Bootstrap tab content container
                tags$div(
                    class = "tab-pane active", # Mimic Bootstrap active tab pane
                    create_prerun_layout(config = PRERUN_CONFIG)
                )
            )
        )
    )
}

# Server for Prerun App
server_prerun <- function(input, output, session) {
    common_logic <- initialize_common_server_logic(input, output, session)

    # Specific prerun initializations
    plot_state_prerun <- reactiveVal(NULL) # Dedicated plot_state for this app instance

    # Initialize prerun handlers
    initialize_prerun_handlers(input, output, session, plot_state = plot_state_prerun, config = PRERUN_CONFIG)

    # Initialize panel servers (plot and table) for the "prerun" page
    plot_panel_server(
        "prerun",
        settings = reactive({
            get_control_settings(input, "prerun") # get_control_settings from src/ui/state/controls.R
        }),
        # Pass the scenario options from the globally loaded config
        scenario_options_config = PRERUN_CONFIG$selectors$scenario$options
    )

    table_panel_server(
        "prerun",
        settings = reactive({
            get_control_settings(input, "prerun")
        })
    )

    # Conditional model specification loading after UI is flushed
    session$onFlushed(function() {
        should_load_model <- TRUE # Default to load
        if (!is.null(PRERUN_CONFIG$execution) &&
            !is.null(PRERUN_CONFIG$execution$requires_full_model_load) &&
            PRERUN_CONFIG$execution$requires_full_model_load == FALSE) {
            should_load_model <- FALSE
        }

        if (should_load_model) {
            message("[APP_PRERUN] UI rendered, auto-loading model specification...")
            # Use model_status from common_logic or session$userData$load_model_spec
            common_logic$model_status$load_model_spec()
        } else {
            message("[APP_PRERUN] UI rendered. Skipping model specification load based on PRERUN_CONFIG.")
            # Optionally, update model status to indicate spec is not loaded by design
            # common_logic$model_status$set_status("not_loaded_by_design", "Model specification not loaded as per Prerun configuration.")
        }
    })
}

# Run the Prerun Application
# The onStart logic will eventually be handled by common_startup.R
shinyApp(
    ui = ui_prerun,
    server = server_prerun,
    onStart = get_common_onStart_function() # Defined in common_startup.R
)
