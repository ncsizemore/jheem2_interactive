#' Create a compound input component (checkbox + additional inputs)
#' @param id Base ID for the inputs
#' @param config UI configuration from YAML
#' @param container_class Additional CSS class for container
create_compound_input <- function(id, config, container_class = NULL) {
    # Debug print
    print("Creating compound input with config:")
    print(str(config))
    
    # Extract configuration - handle both direct and nested label cases
    label <- if (!is.null(config$label)) {
        config$label
    } else if (!is.null(config$ui$label)) {
        config$ui$label
    }
    
    inputs <- config$inputs
    
    # Create container classes
    classes <- c("compound-input")
    if (!is.null(container_class)) {
        classes <- c(classes, container_class)
    }
    
    # Create the component with conditional display
    tags$div(
        class = paste(classes, collapse = " "),
        
        # Main checkbox
        checkboxInput(
            inputId = paste0(id, "_enabled"),
            label = label,  # This should now have the correct label
            value = FALSE
        ),
        
        # Additional inputs in a container that shows only when enabled
        conditionalPanel(
            condition = sprintf("input['%s_enabled'] == true", id),
            class = "compound-input-controls",
            
            # Create each additional input based on type
            lapply(names(inputs), function(input_name) {
                if (input_name != "enabled") {
                    input_config <- inputs[[input_name]]
                    input_id <- paste0(id, "_", input_name)
                    
                    tags$div(
                        class = "input-group",
                        if (!is.null(input_config$label)) {
                            tags$label(input_config$label, `for` = input_id)
                        },
                        
                        switch(input_config$type,
                               "numeric" = numericInput(
                                   inputId = input_id,
                                   label = NULL,
                                   value = input_config$value %||% 0,
                                   min = input_config$min %||% 0,
                                   max = input_config$max %||% 100,
                                   step = input_config$step %||% 1
                               ),
                               "select" = selectInput(
                                   inputId = input_id,
                                   label = NULL,
                                   choices = input_config$options,
                                   selected = input_config$options[1]
                               )
                        )
                    )
                }
            })
        )
    )
}

#' Create a date range selector
#' @param id Base ID for the inputs
#' @param config Date range configuration from YAML
#' @param container_class Additional CSS class for container
create_date_range <- function(id, config, container_class = NULL) {
    # Debug print
    print("Creating date range with config:")
    print(str(config))
    
    # Extract configuration
    start_config <- config$start
    end_config <- config$end
    
    # Validate configuration
    if (is.null(start_config) || is.null(end_config)) {
        print("Missing start or end configuration")
        return(NULL)
    }
    
    # Ensure we have numeric values for the sequence
    from_year <- as.numeric(start_config$options$from)
    to_year <- as.numeric(end_config$options$to)
    
    if (is.na(from_year) || is.na(to_year)) {
        print("Invalid year values:")
        print(paste("from:", from_year))
        print(paste("to:", to_year))
        return(NULL)
    }
    
    # Create container classes
    classes <- c("date-range")
    if (!is.null(container_class)) {
        classes <- c(classes, container_class)
    }
    
    # Create the component
    tags$div(
        class = paste(classes, collapse = " "),
        
        tags$label(config$label, class = "date-range-label"),
        
        # Start date
        tags$div(
            class = "date-input",
            tags$label(start_config$label),
            selectInput(
                inputId = paste0(id, "_start"),
                label = NULL,
                choices = seq(from_year, to_year),
                selected = from_year
            )
        ),
        
        # End date
        tags$div(
            class = "date-input",
            tags$label(end_config$label),
            selectInput(
                inputId = paste0(id, "_end"),
                label = NULL,
                choices = seq(from_year, to_year),
                selected = to_year
            )
        )
    )
}

#' Create an intervention setting component
#' @param type Intervention type (e.g., "testing", "prep")
#' @param group_num Subgroup number
#' @param suffix Page suffix
create_intervention_setting <- function(type, group_num, suffix) {
    # Debug print
    print(paste("Creating intervention setting:", type, "group:", group_num, "suffix:", suffix))
    
    # Get configuration
    config <- get_selector_config(type, suffix, group_num)
    print("Got config:")
    print(str(config))
    
    # Create compound input with full configuration
    create_compound_input(
        id = config$id,
        config = config,  # Pass the full config
        container_class = paste0("intervention-", type)
    )
}

#' Create a complete subgroup panel
#' @param group_num Subgroup number
#' @param config_or_suffix Configuration object or page suffix
create_subgroup_panel <- function(group_num, config_or_suffix) {
    # Ensure we have a string for the page type
    suffix <- if (is.character(config_or_suffix)) {
        config_or_suffix
    } else {
        "custom"  # Default to custom if not a string
    }
    
    # Get config to check available interventions
    config <- get_page_complete_config(suffix)
    available_interventions <- names(config$interventions$components)
    
    # Get date range config
    date_config <- get_selector_config("intervention_dates", suffix, group_num)
    
    tags$div(
        class = "subgroup-panel",
        id = paste0("subgroup-", group_num),
        
        tags$h4(paste("Subgroup", group_num, "Characteristics:")),
        
        # Characteristics (demographics)
        tags$div(
            class = "characteristics-section",
            create_subgroup_characteristics(group_num, suffix)
        ),
        
        # Intervention components
        tags$div(
            class = "intervention-components",
            tags$h4("Intervention Components:"),
            
            # Date range
            tags$div(
                class = "intervention-dates",
                create_date_range(
                    id = date_config$id,
                    config = date_config
                )
            ),
            
            # Intervention settings in a grid
            tags$div(
                class = "intervention-settings-grid",
                # Only create settings for available interventions
                lapply(
                    available_interventions,
                    function(type) create_intervention_setting(type, group_num, suffix)
                )
            )
        )
    )
}

#' Create the subgroup characteristic selectors
#' @param group_num Subgroup number
#' @param suffix Page suffix (usually "custom")
create_subgroup_characteristics <- function(group_num, suffix) {
    # Debug print
    print(paste("Creating characteristics for group:", group_num, "suffix:", suffix))
    
    characteristics <- c("age_groups", "race_ethnicity", "biological_sex", "risk_factor")
    
    # Create container for all characteristics
    tags$div(
        class = "subgroup-characteristics",
        
        lapply(characteristics, function(char_type) {
            config <- get_selector_config(char_type, suffix, group_num)
            
            tags$div(
                class = paste0("characteristic-", char_type),
                tags$label(config$ui$label),
                checkboxGroupInput(
                    inputId = config$id,
                    label = NULL,
                    choices = setNames(
                        sapply(config$options, `[[`, "id"),
                        sapply(config$options, `[[`, "label")
                    )
                )
            )
        })
    )
}