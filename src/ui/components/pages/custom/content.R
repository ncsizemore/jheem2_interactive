# First, source the section builder
source("src/ui/components/common/layout/section_builder.R")

#' Creates the custom intervention content
#' @param config Page configuration
create_custom_intervention_content <- function(config) {
    print("Creating custom intervention content")
    print("Config structure:")
    str(config)

    # Get current session and output
    session <- getDefaultReactiveDomain()
    output <- if (!is.null(session)) session$output else NULL
    
    # Create sections based on configuration with error handling
    section_result <- create_sections_from_config(
        config = config, 
        page_type = "custom",
        session = session,
        output = output
    )
    
    # Extract sections and error displays
    sections <- section_result
    error_displays <- section_result$error_displays
    sections$error_displays <- NULL
    
    # Special handling for subgroups if not already handled
    if (!is.null(config$subgroups) && !config$subgroups$fixed && !is.null(config$subgroups$selector) &&
        !any(grepl("subgroups_count_custom", capture.output(print(sections))))) {
        # Create subgroups section
        subgroups_section_config <- config$sections$subgroups %||% list(
            title = "Subgroups", 
            description = "Define the number of intervention target groups"
        )
        sections$subgroups <- tagList(
            create_section_header(subgroups_section_config$title, subgroups_section_config$description),
            tags$div(
                class = "form-group subgroups-count",
                tags$label(
                    config$subgroups$selector$label,
                    class = "control-label"
                ),
                numericInput(
                    "subgroups_count_custom",
                    label = NULL,
                    value = config$subgroups$selector$value,
                    min = config$subgroups$selector$min,
                    max = config$subgroups$selector$max
                )
            )
        )
    }
    
    # Special handling for dates if needed
    dates_section <- NULL
    if (!is.null(config$interventions$dates)) {
        timing_section_config <- config$sections$timing %||% list(
            title = "Intervention Timing", 
            description = "Define when the intervention starts and is fully implemented"
        )
        dates_section <- tagList(
            create_section_header(timing_section_config$title, timing_section_config$description),
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
        )
    }
    
    tagList(
        # Include error displays if present
        if (!is.null(error_displays)) error_displays,
        
        # Main content container
        tags$div(
            class = "custom-container",
            
            # Location and other section content
            lapply(sections, function(section) section),
            
            # Intervention configuration section (for special components)
            tags$div(
                class = "intervention-config",
                
                # Include dates section if created
                dates_section,

                # Subgroup panels placeholder
                if (!is.null(config$subgroups)) {
                    uiOutput("subgroup_panels_custom")
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