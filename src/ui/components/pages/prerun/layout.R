# Source dependencies
source("src/ui/components/pages/prerun/validation.R")
source("src/ui/components/pages/prerun/content.R")


#' Creates the main layout for the pre-run interventions page
#' @param config Complete page configuration from get_page_complete_config("prerun")
create_prerun_layout <- function(config = get_page_complete_config("prerun")) {
    print("=== Creating Prerun Layout ===")

    # Validate required config sections
    validate_prerun_config(config)

    # Create namespace for this module
    ns <- NS("prerun")

    tags$div(
        class = paste(
            "prerun-container",
            "three-panel-container",
            config$theme$layout$container_class
        ),

        # Left panel with intervention controls
        create_panel(
            id = "intervention",
            type = "left",
            config = config,
            content = create_intervention_content(config)
        ),

        # Main visualization panel
        tags$div(
            class = "panel panel-center",

            # Hidden state inputs at root level
            tags$div(
                class = "hidden",
                textInput(
                    inputId = ns("visualization_state"), # Keep ns()
                    label = NULL,
                    value = "hidden"
                ),
                textInput(
                    inputId = ns("display_type"), # Keep ns()
                    label = NULL,
                    value = "plot"
                )
            ),

            # Visualization container
            tags$div(
                class = "visualization-container",
                style = "position: relative;",
                # Display toggle
                tags$div(
                    class = "display-toggle mb-4 inline-flex gap-2",
                    actionButton(
                        inputId = ns("toggle_plot"), # Add ns() back
                        "Plot",
                        class = "btn btn-default active"
                    ),
                    actionButton(
                        inputId = ns("toggle_table"), # Add ns() back
                        "Table",
                        class = "btn btn-default"
                    )
                ),

                # Visualization panels container
                tags$div(
                    class = "panels-container",
                    style = "position: absolute; top: 50px; left: 0; right: 0;",
                    create_plot_panel("prerun"),
                    create_table_panel("prerun")
                )
            )
        ),

        # Right panel with plot controls - using proper namespace for condition
        conditionalPanel(
            condition = sprintf("input['%s'] === 'visible'", ns("visualization_state")),
            create_panel(
                id = "settings",
                type = "right",
                config = config,
                content = create_prerun_plot_controls(config)
            )
        )
    )
}
