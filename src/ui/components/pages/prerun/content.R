# First, source the section builder
source("src/ui/components/common/layout/section_builder.R")

#' Creates the intervention panel content
#' @param config Page configuration
create_intervention_content <- function(config) {
    # Get current session and output
    session <- getDefaultReactiveDomain()
    output <- if (!is.null(session)) session$output else NULL
    
    # Create sections based on configuration with error handling
    section_result <- create_sections_from_config(
        config = config, 
        page_type = "prerun",
        session = session,
        output = output
    )
    
    # Extract sections and error displays
    sections <- section_result
    error_displays <- section_result$error_displays
    sections$error_displays <- NULL
    
    tagList(
        # Include error displays if present
        if (!is.null(error_displays)) error_displays,
        
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
                    if (!is.null(config$defaults$feedback$generate$show_chime) && 
                        config$defaults$feedback$generate$show_chime) {
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