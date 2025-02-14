#' Creates the custom intervention content
#' @param config Page configuration
create_custom_intervention_content <- function(config) {
    print("Creating custom intervention content")
    print("Config structure:")
    str(config)

    tagList(
        # Location selector
        create_location_selector("custom"),

        # Intervention configuration section
        tags$div(
            class = "intervention-config",
            
            # Date range selector
            if (!is.null(config$interventions$dates)) {
                tags$div(
                    class = "form-group date-range",
                    # Start date
                    tags$div(
                        class = "date-start",
                        selectInput(
                            "int_dates_start_custom",
                            label = config$interventions$dates$start$label,
                            choices = setNames(
                                sapply(config$interventions$dates$start$options, `[[`, "id"),
                                sapply(config$interventions$dates$start$options, `[[`, "label")
                            ),
                            selected = config$interventions$dates$start$value
                        )
                    ),
                    # End date
                    tags$div(
                        class = "date-end",
                        selectInput(
                            "int_dates_end_custom",
                            label = config$interventions$dates$end$label,
                            choices = setNames(
                                sapply(config$interventions$dates$end$options, `[[`, "id"),
                                sapply(config$interventions$dates$end$options, `[[`, "label")
                            ),
                            selected = config$interventions$dates$end$value
                        )
                    )
                )
            },

            # Intervention components
            if (!is.null(config$interventions$components)) {
                tags$div(
                    class = "intervention-components",
                    lapply(names(config$interventions$components), function(component_name) {
                        component <- config$interventions$components[[component_name]]
                        
                        tags$div(
                            class = paste("component", component_name),
                            if (component$type == "compound") {
                                # Compound component (for full version)
                                create_compound_component(component_name, component, "custom")
                            } else if (component$type == "numeric") {
                                # Simple numeric input (for ryan-white) with validation wrapper
                                tags$div(
                                    class = "input-validation-wrapper numeric",
                                    numericInput(
                                        paste0("int_", component_name, "_custom"),
                                        label = component$label,
                                        value = component$value %||% 0,
                                        min = component$min %||% 0,
                                        max = component$max %||% 100,
                                        step = component$step %||% 1
                                    ),
                                    tags$div(
                                        class = "input-error-message",
                                        id = paste0("int_", component_name, "_custom_error"),
                                        style = "display: none;"
                                    )
                                )
                            }
                        )
                    })
                )
            }
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
                if (!is.null(config$defaults$feedback$generate$show_chime) && 
                    config$defaults$feedback$generate$show_chime) {
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
    # Update source path
    source("src/ui/components/common/plot_controls/control_section.R")
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