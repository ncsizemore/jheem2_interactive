# Custom interventions page implementation

#' Creates the main layout for custom interventions page
create_custom_layout <- function() {
    tags$div(
        class = "custom-container three-panel-container",
        id = "custom-page",
        
        # Left panel
        create_panel(
            id = "intervention-custom",
            config = config$layout$panels$left,
            content = create_custom_intervention_content(),
            position = "left"
        ),
        
        # Center panel - add page_type here
        create_visualization_panel(page_type = "custom"),  # <- Add this parameter
        
        # Right panel
        create_panel(
            id = "settings-custom",
            config = config$layout$panels$right,
            content = create_custom_plot_controls(),
            position = "right"
        )
    )
}

#' Creates the intervention specification content
create_custom_intervention_content <- function() {
    # Get configuration
    config <- load_intervention_config("custom")
    
    tagList(
        # Location selector at top
        create_location_selector("custom"),
        
        # Subgroups configuration
        tags$div(
            class = "subgroups-config",
            
            # Number of subgroups selector
            tags$div(
                class = "form-group subgroups-count",
                tags$label(
                    config$UI_CONFIG$subgroups$label,
                    class = "control-label"
                ),
                numericInput(
                    "subgroups_count_custom",
                    label = NULL,
                    value = config$UI_CONFIG$subgroups$value,
                    min = config$UI_CONFIG$subgroups$min,
                    max = config$UI_CONFIG$subgroups$max
                )
            ),
            
            # Dynamic subgroup panels
            uiOutput("subgroup_panels_custom")
        ),
        
        # Generate projections button
        tags$div(
            class = "generate-controls",
            
            # Main button
            actionButton(
                inputId = "generate_custom",
                label = "Generate Projections",
                class = "btn btn-primary"
            ),
            
            # Feedback area
            tags$div(
                class = "generate-feedback",
                tags$small("This will take 10-30 seconds"),
                tags$div(
                    class = "chime-option",
                    checkboxInput(
                        "chime_custom",
                        "Play a chime when done",
                        value = FALSE
                    )
                )
            )
        )
    )
}

#' Creates the custom plot controls
create_custom_plot_controls <- function() {
    # Get plot control configuration
    config <- get_plot_controls("custom")
    
    tagList(
        # Outcomes section
        tags$div(
            class = "plot-control-section outcomes",
            tags$label(config$outcomes$ui$label),
            checkboxGroupInput(
                inputId = "outcomes_custom",
                label = NULL,
                choices = setNames(
                    sapply(config$outcomes$options, `[[`, "id"),
                    sapply(config$outcomes$options, `[[`, "label")
                )
            )
        ),
        
        # Stratification options
        tags$div(
            class = "plot-control-section stratification",
            tags$label(config$projection_options$stratification$ui$label),
            checkboxGroupInput(
                inputId = "stratify_custom",
                label = NULL,
                choices = setNames(
                    sapply(config$projection_options$stratification$options, `[[`, "id"),
                    sapply(config$projection_options$stratification$options, `[[`, "label")
                )
            )
        ),
        
        # Summary options
        tags$div(
            class = "plot-control-section summary",
            tags$label(config$projection_options$summary$ui$label),
            
            # Summary type
            selectInput(
                inputId = "summary_type_custom",
                label = NULL,
                choices = config$projection_options$summary$ui$inputs$type$options
            ),
            
            # Time range
            tags$div(
                class = "time-range",
                # From year
                tags$div(
                    class = "range-input",
                    tags$label(
                        config$projection_options$summary$ui$inputs$time_range$inputs$from$label
                    ),
                    selectInput(
                        inputId = "summary_from_custom",
                        label = NULL,
                        choices = seq(
                            config$projection_options$summary$ui$inputs$time_range$inputs$from$options$from,
                            config$projection_options$summary$ui$inputs$time_range$inputs$from$options$to
                        )
                    )
                ),
                # To year
                tags$div(
                    class = "range-input",
                    tags$label(
                        config$projection_options$summary$ui$inputs$time_range$inputs$to$label
                    ),
                    selectInput(
                        inputId = "summary_to_custom",
                        label = NULL,
                        choices = seq(
                            config$projection_options$summary$ui$inputs$time_range$inputs$to$options$from,
                            config$projection_options$summary$ui$inputs$time_range$inputs$to$options$to
                        )
                    )
                )
            ),
            
            # Show change option
            checkboxInput(
                inputId = "show_change_custom",
                label = config$projection_options$summary$ui$inputs$show_change$label,
                value = TRUE
            )
        ),
        
        # Display options
        tags$div(
            class = "plot-control-section display",
            tags$label(config$projection_options$display$ui$label),
            radioButtons(
                inputId = "display_type_custom",
                label = NULL,
                choices = setNames(
                    sapply(config$projection_options$display$ui$options, `[[`, "id"),
                    sapply(config$projection_options$display$ui$options, `[[`, "label")
                )
            )
        ),
        
        # Adjust projections button
        tags$div(
            class = "plot-control-section adjust-controls",
            actionButton(
                inputId = "adjust_custom",
                label = "Adjust Projections",
                class = "btn btn-secondary"
            )
        )
    )
}

#' Server function to render subgroup panels
#' @param input Shiny input object
#' @param output Shiny output object
#' @param session Shiny session object
render_subgroup_panels <- function(input, output, session) {
    output$subgroup_panels_custom <- renderUI({
        req(input$subgroups_count_custom)
        
        # Create panel for each subgroup
        panels <- lapply(1:input$subgroups_count_custom, function(i) {
            create_subgroup_panel(i, "custom")
        })
        
        # Return all panels
        do.call(tagList, panels)
    })
}