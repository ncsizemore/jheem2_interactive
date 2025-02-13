#' Creates the intervention panel content
#' @param config Page configuration
create_intervention_content <- function(config) {
    # Create all possible selectors
    selectors <- list(
        create_location_selector("prerun"),
        create_intervention_selector("prerun"),
        create_population_selector("prerun"),
        create_timeframe_selector("prerun"),
        create_intensity_selector("prerun")
    )
    
    # Filter out NULL selectors (those not configured)
    selectors <- Filter(Negate(is.null), selectors)
    
    tagList(
        # Selectors container
        tags$div(
            class = "intervention-options",
            # Spread the selectors
            selectors,

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