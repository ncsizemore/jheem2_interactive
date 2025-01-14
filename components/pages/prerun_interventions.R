# components/pages/prerun_interventions.R

library(shiny)

#' Validate prerun configuration
#' @param config Configuration to validate
#' @return TRUE if valid, throws error if invalid
validate_prerun_config <- function(config) {
    # Check for required sections
    required_sections <- c(
        "intervention_aspects",
        "population_groups",
        "timeframes",
        "intensities"
    )
    
    missing <- setdiff(required_sections, names(config))
    if (length(missing) > 0) {
        stop(sprintf(
            "Missing required prerun configuration sections: %s",
            paste(missing, collapse = ", ")
        ))
    }
    TRUE
}

#' Creates the main layout for the pre-run interventions page
#' @param config Complete page configuration from get_page_complete_config("prerun")
create_prerun_layout <- function(config = get_page_complete_config("prerun")) {
    # Validate required config sections
    validate_prerun_config(config)
    
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
        create_plot_panel(
            id = "prerun",
            type = config$display$plot$defaultType %||% "static"
        ),
        
        # Right panel with plot controls
        create_panel(
            id = "settings",
            type = "right",
            config = config,
            content = create_plot_controls(config)
        )
    )
}

#' Creates the intervention panel content
#' @param config Page configuration
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

#' Creates the plot controls for the right panel
#' @param config Page configuration
create_plot_controls <- function(config) {
    # Debug prints
    print("Creating plot controls with config:")
    print("Available config sections:")
    print(names(config))
    print("Plot controls section:")
    print(str(config$plot_controls))
    
    plot_config <- config$plot_controls
    
    tagList(
        # Outcomes section
        create_control_section(
            type = "outcomes",
            config = plot_config$outcomes
        ),
        
        # Stratification section
        create_control_section(
            type = "stratification",
            config = plot_config$stratification
        ),
        
        # Display options section
        create_control_section(
            type = "display",
            config = plot_config$display
        )
    )
}

#' Helper to create a control section
#' @param type Type of control section
#' @param config Section configuration
create_control_section <- function(type, config) {
    # Debug prints
    print("Creating control section:")
    print(paste("Type:", type))
    print("Config:")
    print(str(config))
    print(paste("UI type:", config$type))
    
    tags$div(
        class = paste("plot-control-section", type),
        
        # Section label
        tags$label(config$label),
        
        # Create appropriate input based on type
        switch(as.character(config$type),  # Ensure we have a character vector
               "checkbox" = checkboxGroupInput(
                   inputId = paste0(type, "_prerun"),
                   label = NULL,
                   choices = setNames(
                       sapply(config$options, `[[`, "id"),
                       sapply(config$options, `[[`, "label")
                   )
               ),
               "radio" = radioButtons(
                   inputId = paste0(type, "_prerun"),
                   label = NULL,
                   choices = setNames(
                       sapply(config$options, `[[`, "id"),
                       sapply(config$options, `[[`, "label")
                   )
               ),
               stop(sprintf("Unknown control type: %s", config$type))
        )
    )
}