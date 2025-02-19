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

    # Create the component
    tags$div(
        class = paste(classes, collapse = " "),
        tags$label(config$label, class = "date-range-label"),

        # Start date
        tags$div(
            class = "date-input",
            tags$label(start_config$label),
            create_input_by_type(
                type = start_config$type,
                id = paste0(id, "_start"),
                config = start_config
            )
        ),

        # End date
        tags$div(
            class = "date-input",
            tags$label(end_config$label),
            create_input_by_type(
                type = end_config$type,
                id = paste0(id, "_end"),
                config = end_config
            )
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
        
        # Title from config
        tags$h4(fixed_group$label),

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
