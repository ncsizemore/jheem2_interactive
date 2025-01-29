# Source dependencies
source("src/ui/components/pages/custom/validation.R")
source("src/ui/components/pages/custom/content.R")


#' Creates the main layout for custom interventions page
#' @param config Complete page configuration from get_page_complete_config("custom")
create_custom_layout <- function(config = get_page_complete_config("custom")) {
    # Validate required config sections
    validate_custom_config(config)

    # Create namespace for this module
    ns <- NS("custom")

    tags$div(
        class = paste(
            "custom-container",
            "three-panel-container",
            config$theme$layout$container_class
        ),

        # Left panel with intervention designer
        create_panel(
            id = "intervention-custom",
            type = "left",
            config = config,
            content = create_custom_intervention_content(config)
        ),

        # Main visualization panel
        tags$div(
            class = "panel panel-center",

            # Hidden state inputs at root level
            tags$div(
                class = "hidden",
                textInput(
                    ns("visualization_state"),
                    label = NULL,
                    value = "hidden"
                ),
                textInput(
                    ns("display_type"),
                    label = NULL,
                    value = "plot"
                )
            ),

            # Visualization container with toggle and panels
            tags$div(
                class = "visualization-container",
                style = "position: relative;",

                # Display toggle
                tags$div(
                    class = "display-toggle mb-4 inline-flex gap-2",
                    actionButton(
                        ns("toggle_plot"),
                        "Plot",
                        class = "btn btn-default active"
                    ),
                    actionButton(
                        ns("toggle_table"),
                        "Table",
                        class = "btn btn-default"
                    )
                ),

                # Visualization panels container
                tags$div(
                    class = "panels-container",
                    style = "position: absolute; top: 50px; left: 0; right: 0;",
                    create_plot_panel("custom"),
                    create_table_panel("custom")
                )
            )
        ),

        # Right panel with plot controls - now conditional on visualization state
        conditionalPanel(
            condition = sprintf("input['%s'] === 'visible'", ns("visualization_state")),
            create_panel(
                id = "settings-custom",
                type = "right",
                config = config,
                content = create_custom_plot_controls(config)
            )
        )
    )
}
