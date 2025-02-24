# components/pages/custom_interventions.R

library(shiny)

#' Validate custom configuration
#' @param config Configuration to validate
#' @return TRUE if valid, throws error if invalid
validate_custom_config <- function(config) {
    required_sections <- c(
        "subgroups",
        "demographics",
        "interventions"
    )
    
    missing <- setdiff(required_sections, names(config))
    if (length(missing) > 0) {
        stop(sprintf(
            "Missing required custom configuration sections: %s",
            paste(missing, collapse = ", ")
        ))
    }
    TRUE
}

#' Creates the main layout for custom interventions page
#' @param config Complete page configuration from get_page_complete_config("custom")
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
    source('components/common/plot_controls/control_section.R')
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
            ns = ns  # Add namespace
        ),
        
        # Stratification section
        create_control_section(
            type = "stratification",
            config = plot_config$stratification,
            suffix = "custom",
            ns = ns  # Add namespace
        ),
        
        # Display options section
        create_control_section(
            type = "display",
            config = plot_config$display,
            suffix = "custom",
            ns = ns  # Add namespace
        )
    )
}