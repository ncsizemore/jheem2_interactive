# First, source the section header component
source("src/ui/components/common/display/section_header.R")

#' Creates the intervention panel content
#' @param config Page configuration
create_intervention_content <- function(config) {
    # Create sections with grouped selectors
    sections <- list()
    
    # Location section
    location_section_config <- config$sections$location %||% list(title = "Location", description = NULL)
    sections$location <- tagList(
        create_section_header(location_section_config$title, location_section_config$description),
        create_location_selector("prerun")
    )
    
    # Intervention section - only include if configured
    if (!is.null(config$intervention_aspects)) {
        intervention_section_config <- config$sections$intervention %||% list(title = "Intervention", description = NULL)
        sections$intervention <- tagList(
            create_section_header(intervention_section_config$title, intervention_section_config$description),
            create_intervention_selector("prerun"),
            create_population_selector("prerun"),
            create_timeframe_selector("prerun"),
            create_intensity_selector("prerun")
        )
    }
    
    # Only include sections that are configured
    sections <- Filter(Negate(is.null), sections)
    
    tagList(
        # Selectors container
        tags$div(
            class = "intervention-options",
            # Spread the sections
            sections,

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

#' Creates the plot controls for the right panel
#' @param config Page configuration
create_prerun_plot_controls <- function(config) {
    print("=== Creating Prerun Plot Controls ===")

    # Update source path
    source("src/ui/components/common/plot_controls/control_section.R")

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