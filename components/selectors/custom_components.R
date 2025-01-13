#' Create a compound input component (checkbox + additional inputs)
#' @param id Base ID for the inputs
#' @param config UI configuration from YAML
#' @param container_class Additional CSS class for container
create_compound_input <- function(id, config, container_class = NULL) {
    # Extract configuration
    label <- config$label
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
            label = label,
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
    # Extract configuration
    start_config <- config$start
    end_config <- config$end
    
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
                choices = seq(
                    start_config$options$from,
                    start_config$options$to
                ),
                selected = start_config$options$from
            )
        ),
        
        # End date
        tags$div(
            class = "date-input",
            tags$label(end_config$label),
            selectInput(
                inputId = paste0(id, "_end"),
                label = NULL,
                choices = seq(
                    end_config$options$from,
                    end_config$options$to
                ),
                selected = end_config$options$to
            )
        )
    )
}

#' Create an intervention settings component
#' @param type Intervention type (e.g., "testing", "prep")
#' @param group_num Subgroup number
#' @param suffix Page suffix (usually "custom")
create_intervention_setting <- function(type, group_num, suffix = "custom") {
    # Get configuration
    config <- get_selector_config(type, suffix, group_num)
    id <- config$id
    
    # Create compound input with type-specific configuration
    create_compound_input(
        id = id,
        config = config$ui,
        container_class = paste0("intervention-", type)
    )
}

#' Create the subgroup characteristic selectors
#' @param group_num Subgroup number
#' @param suffix Page suffix (usually "custom")
create_subgroup_characteristics <- function(group_num, suffix = "custom") {
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

#' Create a complete subgroup panel
#' @param group_num Subgroup number
#' @param suffix Page suffix (usually "custom")
create_subgroup_panel <- function(group_num, suffix = "custom") {
    # Get date range config
    date_config <- get_selector_config("intervention_dates", suffix, group_num)
    
    tags$div(
        class = "subgroup-panel",
        id = paste0("subgroup-", group_num),
        
        tags$h4(paste("Subgroup", group_num, "Characteristics:")),
        
        # Characteristics (demographics)
        create_subgroup_characteristics(group_num, suffix),
        
        # Intervention components
        tags$div(
            class = "intervention-components",
            tags$h4("Intervention Components:"),
            
            # Date range
            create_date_range(
                id = date_config$id,
                config = date_config$ui
            ),
            
            # Intervention settings
            lapply(
                c("testing", "prep", "suppression", "needle_exchange", "moud"),
                function(type) create_intervention_setting(type, group_num, suffix)
            )
        )
    )
}