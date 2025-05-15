# src/common_ui_elements.R
# Defines common UI shell elements for the dedicated Shiny apps.

# This function will return a tagList of UI elements that are common
# to both prerun and custom applications.
create_common_ui_shell <- function(app_title = "JHEEM Application", ..., initial_overlay_hidden = FALSE) {
    # Ensure necessary UI-related packages/functions are available
    # shinyjs::useShinyjs() should be called once per UI.
    # Other sourced scripts from common_startup.R might provide functions used here.

    tagList(
        tags$html(
            style = "height:100%", # Ensure html tag takes full height
            tags$head(
                tags$title(app_title),
                shinyjs::useShinyjs(), # Initialize shinyjs

                # Add Bootstrap 3 CSS (commonly used by Shiny)
                tags$link(
                    rel = "stylesheet",
                    href = "https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css",
                    integrity = "sha384-BVYiiSIFeK1dGmJRAkycuHAHRg32OmUcww7on3RYdg4Va+PmSTsz/K68vbdEjh4u",
                    crossorigin = "anonymous"
                ),

                # Load JavaScript extensions (mirroring app.R)
                # These paths are relative to the www/ directory in the app root.
                shinyjs::extendShinyjs(
                    script = "js/layout/panel-controls.js",
                    functions = c("ping_display_size", "ping_display_size_onload", "set_input_value")
                ),
                shinyjs::extendShinyjs(
                    script = "js/interactions/download_plotly.js",
                    functions = c("download_plotly")
                ),
                shinyjs::extendShinyjs(
                    script = "js/interactions/sounds.js",
                    functions = c("chime", "chime_if_checked")
                ),
                shinyjs::extendShinyjs(
                    script = "js/interactions/download_progress.js", # Ensure this file exists and is needed
                    functions = c()
                ),

                # Load CSS files (mirroring app.R)
                # These paths are relative to the www/ directory in the app root.
                # Base styles, variables, and main layout structure
                tags$link(rel = "stylesheet", type = "text/css", href = "css/base/variables.css"),
                tags$link(rel = "stylesheet", type = "text/css", href = "css/color_schemes/theme_jh.css"), # Corrected path/name

                # Main application stylesheet (may import or override above)
                tags$link(rel = "stylesheet", type = "text/css", href = "css/main.css"),

                # Component-specific styles
                tags$link(rel = "stylesheet", type = "text/css", href = "css/components/feedback/download_progress.css"),
                tags$link(rel = "stylesheet", type = "text/css", href = "css/components/feedback/simulation_progress.css"),
                tags$link(rel = "stylesheet", type = "text/css", href = "css/components/feedback/immediate_loading.css"), # If still used
                tags$link(rel = "stylesheet", type = "text/css", href = "css/components/display/simulation_differences.css"), # If applicable

                # Load JavaScript files (mirroring app.R)
                # Base config scripts might not be needed if we simplify, or we pass base_config here.
                # For now, let's list the explicit scripts from app.R's UI.
                tags$script(src = "js/state/visualization-sync.js"),
                tags$script(src = "js/interactions/simulation_progress.js"),
                tags$script(src = "js/interactions/progress_positioning.js"),
                tags$script(src = "js/interactions/plot_progress.js"),
                tags$script(src = "js/plotly_download.js"), # Helper for Plotly downloads
                tags$link(rel = "stylesheet", href = "https://cdn.jsdelivr.net/npm/choices.js/public/assets/styles/choices.min.css"),
                tags$script(src = "https://cdn.jsdelivr.net/npm/choices.js/public/assets/scripts/choices.min.js"),
                tags$script("console.log('[COMMON_UI] Core JS and CSS loaded.');")
            ), # End of head
            tags$body(
                style = "height:100%;", # Ensure body tag takes full height

                # Model status indicator (assuming create_model_status_ui is available via common_startup.R)
                create_model_status_ui(start_hidden = initial_overlay_hidden),

                # Download progress container (rendered by download_manager in server logic)
                uiOutput("download_progress_container"),

                # Simulation progress container
                tags$div(id = "simulation-progress-container", class = "simulation-progress-container"),

                # Hidden input for status tracking (if still needed by JS)
                tags$input(type = "text", id = "model_status", style = "display:none;"),

                # Main content area where page-specific layout will be inserted
                ...
            ) # End of body
        ) # End of html
    ) # End of tagList
}

print("[COMMON_UI_ELEMENTS] Script loaded. create_common_ui_shell() is defined.")
