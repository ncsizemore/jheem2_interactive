#' Creates the custom intervention content
#' @param config Page configuration
create_custom_intervention_content <- function(config) {
    tagList(
        # Location selector
        create_location_selector("custom"),

        # Subgroups configuration section
        tags$div(
            class = "subgroups-config",

            # Number of subgroups selector
            tags$div(
                class = "form-group subgroups-count",
                tags$label(
                    config$subgroups$label,
                    class = "control-label"
                ),
                numericInput(
                    "subgroups_count_custom",
                    label = NULL,
                    value = config$subgroups$value,
                    min = config$subgroups$min,
                    max = config$subgroups$max
                )
            ),

            # Dynamic subgroup panels
            uiOutput("subgroup_panels_custom")
        ),

        # Generate button using config settings
        tags$div(
            class = "generate-controls",
            actionButton(
                inputId = "generate_custom",
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
                            "chime_custom",
                            config$defaults$feedback$generate$chime_label,
                            value = FALSE
                        )
                    )
                }
            )
        )
    )
}

#' Creates the plot controls for the right panel
#' @param config Page configuration
create_custom_plot_controls <- function(config) {
    # Source shared control section implementation
    source("components/common/plot_controls/control_section.R")
    print("Creating custom plot controls")
    # Create namespace for controls
    ns <- NS("custom")

    plot_config <- config$plot_controls
    print("Plot config structure:")
    str(plot_config)

    tagList(
        # Outcomes section
        create_control_section(
            type = "outcomes",
            config = plot_config$outcomes,
            suffix = "custom",
            ns = ns # Add namespace
        ),

        # Stratification section
        create_control_section(
            type = "stratification",
            config = plot_config$stratification,
            suffix = "custom",
            ns = ns # Add namespace
        ),

        # Display options section
        create_control_section(
            type = "display",
            config = plot_config$display,
            suffix = "custom",
            ns = ns # Add namespace
        )
    )
}
