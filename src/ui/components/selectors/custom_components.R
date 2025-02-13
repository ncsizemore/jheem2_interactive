#' Create a compound input component (checkbox + additional inputs)
#' @param id Base ID for the inputs
#' @param config UI configuration from YAML
#' @param container_class Additional CSS class for container
create_compound_input <- function(id, config, container_class = NULL) {
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
        # Main checkbox
        create_input_by_type(
            type = "checkbox",
            id = paste0(id, "_enabled"),
            config = enabled_config
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

                # Create the input group
                tags$div(
                    class = "input-group",
                    create_input_by_type(
                        type = input_config$type,
                        id = input_id,
                        config = input_config
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
        config = config, # Pass the full config
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
        "custom" # Default to custom if not a string
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