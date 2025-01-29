#' Creates the intervention control content
#' @param config Page configuration
#' @return Shiny UI elements for intervention controls
create_intervention_content <- function(config) {
    tagList(
        # Location selector
        create_location_selector("prerun"),

        # Intervention options container
        tags$div(
            class = "intervention-options",

            # Create each selector using helper functions
            create_intervention_selector("prerun"),
            create_population_selector("prerun"),
            create_timeframe_selector("prerun"),
            create_intensity_selector("prerun"),

            # Generate button using config settings
            tags$div(
                class = "generate-controls",
                actionButton(
                    inputId = "generate_projections_prerun",
                    label = config$defaults$buttons$generate$label,
                    class = paste(
                        "btn",
                        config$theme$buttons$primary_class
                    )
                ),

                # Feedback area using config
                tags$div(
                    class = "generate-feedback",
                    tags$small(config$defaults$feedback$generate$message),
                    if (config$defaults$feedback$generate$show_chime) {
                        tags$div(
                            class = "chime-option",
                            checkboxInput(
                                "chime_prerun",
                                config$defaults$feedback$generate$chime_label,
                                value = FALSE
                            )
                        )
                    }
                )
            )
        )
    )
}

#' Creates the visualization panel
#' @param ns Namespace function
#' @param config Page configuration
#' @return Shiny UI elements for visualization
create_visualization_panel <- function(ns, config) {
    tags$div(
        class = "panel panel-center",

        # Hidden state inputs at root level
        tags$div(
            class = "hidden",
            textInput(
                inputId = ns("visualization_state"),
                label = NULL,
                value = "hidden"
            ),
            textInput(
                inputId = ns("display_type"),
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
                    inputId = ns("toggle_plot"),
                    "Plot",
                    class = "btn btn-default active"
                ),
                actionButton(
                    inputId = ns("toggle_table"),
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
    )
}

#' Creates the plot controls for the right panel
#' @param config Page configuration
create_prerun_plot_controls <- function(config) {
    print("=== Creating Prerun Plot Controls ===")

    # Source shared control section implementation
    source("components/common/plot_controls/control_section.R")

    plot_config <- config$plot_controls

    # Create namespace for this module
    ns <- NS("prerun")

    tagList(
        # Outcomes section
        create_control_section(
            type = "outcomes",
            config = plot_config$outcomes,
            suffix = "prerun",
            ns = ns
        ),

        # Stratification section
        create_control_section(
            type = "stratification",
            config = plot_config$stratification,
            suffix = "prerun",
            ns = ns
        ),

        # Display options section
        create_control_section(
            type = "display",
            config = plot_config$display,
            suffix = "prerun",
            ns = ns
        )
    )
}
