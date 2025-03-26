#' Create a conditional component based on visibility rules
#' @param id Base ID for the component
#' @param component The component to conditionally display
#' @param config Configuration containing visibility rules
#' @return Component wrapped in conditional logic if needed
create_conditional_component <- function(id, component, config) {
    # If the config has visibility rules
    if (!is.null(config$visibility)) {
        # Get the field this depends on
        depends_on <- config$visibility$depends_on
        
        # Get the value that triggers visibility
        show_when_value <- config$visibility$show_when
        
        # Build the condition string for Shiny
        dependency_id <- paste0(id, "_", depends_on)
        condition <- if(isTRUE(show_when_value)) {
            sprintf("input['%s'] == true", dependency_id)
        } else {
            sprintf("input['%s'] == false", dependency_id)
        }
        
        # Return the component wrapped in a conditional panel
        conditionalPanel(
            condition = condition,
            component
        )
    } else {
        # No visibility rules, just return the component as-is
        component
    }
}

#' Create a compound input component (checkbox + additional inputs)
#' @param id Base ID for the inputs
#' @param config UI configuration from YAML
#' @param container_class Additional CSS class for container
create_compound_input <- function(id, config, container_class = NULL) {
    print(paste("Creating compound input with ID:", id))
    print(paste("Config:", paste(names(config), collapse=",")))
    # Validate inputs
    if (is.null(config) || is.null(config$inputs)) {
        warning(sprintf("Invalid config for compound input %s", id))
        return(NULL)
    }

    # Extract configuration
    label <- config$label
    inputs <- config$inputs

    # Create container classes
    classes <- c("compound-input")
    if (!is.null(container_class)) {
        classes <- c(classes, container_class)
    }

    # Ensure enabled config has default value
    enabled_config <- list(
        type = "checkbox",
        label = label,
        value = inputs$enabled$value %||% FALSE,
        input_style = "native"
    )

    # Get input names safely
    input_names <- names(inputs)
    if (is.null(input_names)) {
        warning(sprintf("No input names found for compound input %s", id))
        input_names <- character(0)
    }

    tags$div(
        class = paste(classes, collapse = " "),
        # Main checkbox with validation wrapper
        tags$div(
            class = "input-validation-wrapper checkbox",
            create_input_by_type(
                type = "checkbox",
                id = paste0(id, "_enabled"),
                config = enabled_config
            ),
            tags$div(
                class = "input-error-message",
                id = paste0(id, "_enabled_error"),
                style = "display: none;"
            )
        ),
        # Additional inputs
        conditionalPanel(
            condition = sprintf("input['%s_enabled'] == true", id),
            class = "compound-input-controls",
            lapply(input_names, function(input_name) {
                # Skip if input_name is NULL or empty
                if (is.null(input_name) || nchar(input_name) == 0) {
                    return(NULL)
                }

                # Skip the enabled input
                if (input_name == "enabled") {
                    return(NULL)
                }

                input_config <- inputs[[input_name]]
                if (is.null(input_config)) {
                    warning(sprintf("Missing config for input %s in compound input %s", input_name, id))
                    return(NULL)
                }

                input_id <- paste0(id, "_", input_name)
                print(paste("Creating compound input element with ID:", input_id))
                print(paste("Input config type:", input_config$type))

                # Create the input group
                tags$div(
                    class = "input-group",
                    tags$div(
                        class = paste("input-validation-wrapper", input_config$type),
                        create_input_by_type(
                            type = input_config$type,
                            id = input_id,
                            config = input_config
                        ),
                        tags$div(
                            class = "input-error-message",
                            id = paste0(input_id, "_error"),
                            style = "display: none;"
                        )
                    )
                )
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

    # Validate configuration
    if (is.null(start_config) || is.null(end_config)) {
        stop("Missing start or end configuration")
    }

    # Create container classes
    classes <- c("date-range")
    if (!is.null(container_class)) {
        classes <- c(classes, container_class)
    }
    
    # Check if modern UI style should be used (choicesSelect)
    use_choices_select <- (!is.null(start_config$input_style) && start_config$input_style == "choices") ||
                           (!is.null(end_config$input_style) && end_config$input_style == "choices")

    # Create start date selector
    start_selector <- if (use_choices_select) {
        # Format choices for choicesSelectInput
        choices <- lapply(names(start_config$options), function(name) {
            option <- start_config$options[[name]]
            list(value = option$id, label = option$label)
        })
        
        choicesSelectInput(
            paste0(id, "_start"),
            label = start_config$label,
            choices = choices,
            selected = start_config$value,
            placeholder = start_config$placeholder %||% "Select start year..."
        )
    } else {
        # Use standard selectInput
        selectInput(
            paste0(id, "_start"),
            label = start_config$label,
            choices = setNames(
                sapply(start_config$options, `[[`, "id"),
                sapply(start_config$options, `[[`, "label")
            ),
            selected = start_config$value
        )
    }
    
    # Create end date selector
    end_selector <- if (use_choices_select) {
        # Format choices for choicesSelectInput
        choices <- lapply(names(end_config$options), function(name) {
            option <- end_config$options[[name]]
            list(value = option$id, label = option$label)
        })
        
        choicesSelectInput(
            paste0(id, "_end"),
            label = end_config$label,
            choices = choices,
            selected = end_config$value,
            placeholder = end_config$placeholder %||% "Select end year..."
        )
    } else {
        # Use standard selectInput
        selectInput(
            paste0(id, "_end"),
            label = end_config$label,
            choices = setNames(
                sapply(end_config$options, `[[`, "id"),
                sapply(end_config$options, `[[`, "label")
            ),
            selected = end_config$value
        )
    }

    # Create the component
    tags$div(
        class = paste(classes, collapse = " "),
        
        # Start date
        tags$div(
            class = "date-input",
            tags$label(start_config$label),
            start_selector
        ),

        # End date
        tags$div(
            class = "date-input",
            tags$label(end_config$label),
            end_selector
        )
    )
}

#' Create an intervention setting component
#' @param type Intervention type (e.g., "testing", "prep")
#' @param group_num Subgroup number
#' @param suffix Page suffix
#' @param fixed_group Optional fixed group configuration
create_intervention_setting <- function(type, group_num, suffix, fixed_group = NULL) {
    print(paste("Creating intervention setting:", type, "group:", group_num, "suffix:", suffix))

    # Get configuration
    config <- get_selector_config(type, suffix, group_num)
    print("Got config:")
    print(str(config))

    # Modify label if we have a fixed group
    if (!is.null(fixed_group)) {
        config$label <- paste(fixed_group$label, "-", config$label)
    }

    # Generate the base ID
    base_id <- paste0("int_", type, "_", group_num, "_", suffix)

    if (config$type == "numeric") {
        # Simple numeric input with validation
        tags$div(
            class = paste("intervention-component", type),
            tags$div(
                class = "input-validation-wrapper numeric",
                numericInput(
                    inputId = base_id,
                    label = config$label,
                    value = config$value,
                    min = config$min,
                    max = config$max,
                    step = config$step
                ),
                tags$div(
                    class = "input-error-message",
                    id = paste0(base_id, "_error"),
                    style = "display: none;"
                )
            )
        )
    } else if (config$type == "compound") {
        # Compound input with checkbox and additional inputs
        config$id <- base_id  # Ensure ID is set correctly
        tags$div(
            class = paste("intervention-component", type),
            tags$div(
                class = "input-validation-wrapper compound",
                create_compound_input(
                    id = base_id,
                    config = config,
                    container_class = paste0("intervention-", type)
                )
            )
        )
    } else {
        warning(sprintf("Unknown component type: %s", config$type))
        NULL
    }
}

#' Create a complete subgroup panel
#' @param group_num Subgroup number
#' @param config_or_suffix Configuration object or page suffix
#' @param fixed_group Optional fixed group configuration for predefined groups
create_subgroup_panel <- function(group_num, config_or_suffix, fixed_group = NULL) {
    # Get page type string
    suffix <- if (is.character(config_or_suffix)) config_or_suffix else "custom"
    
    # Get config
    config <- get_page_complete_config(suffix)
    
    # Create base container
    tags$div(
        class = "subgroup-panel",
        id = paste0("subgroup-", group_num),
        
        # Title either from fixed group or generated for user-defined groups
        tags$h4(if (!is.null(fixed_group)) fixed_group$label else paste("Subgroup", group_num)),

        # Demographics selectors - only for user-defined groups
        if (is.null(fixed_group) && !is.null(config$demographics)) {
            tags$div(
                class = "demographics-section",
                tags$h4("Population Characteristics:"),
                create_subgroup_characteristics(group_num, suffix)
            )
        },

        # Intervention components section
        tags$div(
            class = "intervention-components",
            tags$h4("Intervention Components:"),
            
            # Create whatever components are specified for this group
            lapply(names(config$interventions$components), function(type) {
                create_intervention_setting(type, group_num, suffix, fixed_group)
            })
        )
    )
}

#' Create the subgroup characteristic selectors
#' @param group_num Subgroup number
#' @param suffix Page suffix (usually "custom")
create_subgroup_characteristics <- function(group_num, suffix) {
    print(paste("Creating characteristics for group:", group_num, "suffix:", suffix))

    # Get config to determine available characteristics
    config <- get_page_complete_config(suffix)
    demographic_fields <- names(config$demographics)

    # Create container for all characteristics
    tags$div(
        class = "subgroup-characteristics",
        lapply(demographic_fields, function(field_name) {
            # Get field config using existing config system
            field_config <- get_selector_config(field_name, suffix, group_num)

            # Debug what we're getting
            print(paste("Creating field:", field_name))
            print(str(field_config))

            tags$div(
                class = "demographic-field",
                create_input_by_type(
                    type = field_config$type,
                    id = field_config$id,
                    config = field_config
                )
            )
        })
    )
}

#' Create a date range selector with month/year components
#' @param id Base ID for the inputs
#' @param config Date range configuration from YAML
#' @param container_class Additional CSS class for container
create_date_range_month_year <- function(id, config, container_class = NULL) {
    # Extract configuration
    start_config <- config$start
    end_config <- config$end
    recovery_config <- config$recovery_duration

    # Validate configuration
    if (is.null(start_config) || is.null(end_config)) {
        stop("Missing start or end configuration")
    }

    # Create container classes
    classes <- c("date-range")
    if (!is.null(container_class)) {
        classes <- c(classes, container_class)
    }

    # Create the component
    container <- tags$div(
        class = paste(classes, collapse = " "),
        
        # Start date section
        tags$div(
            class = "date-section start-date-section",
            tags$label(start_config$label, class = "date-section-label"),
            # Month-Year selector container
            tags$div(
                class = "month-year-container",
                # Month selector
                tags$div(
                    class = "month-select",
                    choicesSelectInput(
                        paste0(id, "_start_month"),
                        label = "Month",
                        choices = lapply(names(start_config$month_options), function(name) {
                            option <- start_config$month_options[[name]]
                            list(value = option$id, label = option$label)
                        }),
                        selected = strsplit(start_config$value, "-")[[1]][2], # Extract month
                        placeholder = "Select month..."
                    )
                ),
                # Year selector
                tags$div(
                    class = "year-select",
                    choicesSelectInput(
                        paste0(id, "_start_year"),
                        label = "Year",
                        choices = lapply(names(start_config$year_options), function(name) {
                            option <- start_config$year_options[[name]]
                            list(value = option$id, label = option$label)
                        }),
                        selected = strsplit(start_config$value, "-")[[1]][1], # Extract year
                        placeholder = "Select year..."
                    )
                )
            )
        ),

        # End date section
        tags$div(
            class = "date-section end-date-section",
            tags$label(end_config$label, class = "date-section-label"),
            
            # Never returns option
            tags$div(
                class = "never-returns-option",
                checkboxInput(
                    paste0(id, "_end_never"),
                    label = end_config$never_option$label,
                    value = FALSE
                )
            ),
            
            # Conditional month-year selectors (only shown when not "never")
            conditionalPanel(
                condition = sprintf("!input['%s_end_never']", id),
                # Month-Year selector container
                tags$div(
                    class = "month-year-container",
                    # Month selector
                    tags$div(
                        class = "month-select",
                        choicesSelectInput(
                            paste0(id, "_end_month"),
                            label = "Month",
                            choices = lapply(names(end_config$month_options), function(name) {
                                option <- end_config$month_options[[name]]
                                list(value = option$id, label = option$label)
                            }),
                            selected = strsplit(end_config$value, "-")[[1]][2], # Extract month
                            placeholder = "Select month..."
                        )
                    ),
                    # Year selector
                    tags$div(
                        class = "year-select",
                        choicesSelectInput(
                            paste0(id, "_end_year"),
                            label = "Year",
                            choices = lapply(names(end_config$year_options), function(name) {
                                option <- end_config$year_options[[name]]
                                list(value = option$id, label = option$label)
                            }),
                            selected = strsplit(end_config$value, "-")[[1]][1], # Extract year
                            placeholder = "Select year..."
                        )
                    )
                )
            )
        )
    )
    
    # Look for any additional fields in the config beyond start/end
    additional_fields <- setdiff(names(config), c("start", "end"))
    
    # Process each additional field
    for (field_name in additional_fields) {
        field_config <- config[[field_name]]
        
        # Skip if not a configuration object
        if (!is.list(field_config)) {
            next
        }
        
        # Create the base component based on field type
        if (field_config$type == "select" && field_config$input_style == "choices") {
            # Create the field component with consistent styling
            field_component <- tags$div(
                class = paste0(field_name, "-section"),
                # Add label with consistent styling
                tags$label(field_config$label, class = paste0(field_name, "-label")),
                
                # Add description only if it exists (now above the selector)
                if (!is.null(field_config$description)) {
                    tags$div(class = paste0(field_name, "-description"), field_config$description)
                },
                
                # Create the actual input
                choicesSelectInput(
                    paste0(id, "_", field_name),
                    label = NULL,  # We're using our own label above
                    choices = lapply(names(field_config$options), function(name) {
                        option <- field_config$options[[name]]
                        list(value = option$id, label = option$label)
                    }),
                    selected = field_config$value,
                    placeholder = field_config$placeholder
                )
            )
        } else {
            # For other input types
            field_component <- tags$div(
                class = paste0(field_name, "-section"),
                create_input_by_type(
                    type = field_config$type,
                    id = paste0(id, "_", field_name),
                    config = field_config
                )
            )
        }
        
        # If there's no explicit visibility config but the field should logically
        # depend on the end date, add a default dependency
        if (is.null(field_config$visibility) && 
            (field_name == "recovery_duration" || grepl("recovery", field_name))) {
            field_config$visibility <- list(
                depends_on = "end_never",
                show_when = FALSE
            )
        }
        
        # Apply visibility rules if any
        final_component <- create_conditional_component(
            id = id,
            component = field_component,
            config = field_config
        )
        
        # Add to container
        container$children[[length(container$children) + 1]] <- final_component
    }
    
    return(container)
}