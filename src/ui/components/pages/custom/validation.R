#' Validate custom configuration
#' @param config Configuration to validate
#' @return TRUE if valid, throws error if invalid
validate_custom_config <- function(config) {
    # Get requirements from config
    defaults_config <- get_defaults_config()
    required_sections <- defaults_config$page_requirements$custom$required_sections
    
    if (is.null(required_sections)) {
        warning("No requirements defined for custom page")
        return(TRUE)
    }

    # For each required section
    for (section in required_sections) {
        # First check if section exists in page-specific config
        if (section %in% names(config)) {
            next
        }

        # If not in page config, check if it's in selectors (common sections)
        if (!is.null(config$selectors) && section %in% names(config$selectors)) {
            next
        }

        # If not found in either place, it's missing
        stop(sprintf(
            "Missing required configuration section '%s' for custom. Section must be defined either in page config or in common selectors.",
            section
        ))
    }
    
    TRUE
}

#' Validate custom intervention inputs
#' @param session Shiny session object
#' @param output Shiny output object
#' @param inputs Input values to validate
#' @param config Configuration to validate against
#' @return TRUE if valid, FALSE if invalid
validate_custom_inputs <- function(session, output, inputs, config) {
    validation_boundary <- create_validation_boundary(
        session,
        output,
        "custom",
        "intervention_validation"
    )

    # Validate subgroups count if configured
    if (!is.null(config$subgroups)) {
        valid_count <- validation_boundary$validate(
            inputs$subgroups_count_custom,
            list(
                validation_boundary$rules$required("Number of subgroups is required"),
                validation_boundary$rules$range(
                    min = config$subgroups$min,
                    max = config$subgroups$max,
                    message = sprintf(
                        "Number of subgroups must be between %d and %d",
                        config$subgroups$min,
                        config$subgroups$max
                    )
                )
            )
        )

        if (!valid_count) {
            return(FALSE)
        }
    }

    # Validate location if present
    valid_location <- validation_boundary$validate(
        inputs$int_location_custom,
        list(
            validation_boundary$rules$required("Please select a location")
        )
    )

    if (!valid_location) {
        return(FALSE)
    }

    # Validate subgroups if configured
    if (!is.null(config$subgroups)) {
        subgroup_count <- inputs$subgroups_count_custom
        for (i in 1:subgroup_count) {
            # Validate demographics for each subgroup if configured
            if (!is.null(config$demographics)) {
                valid_demographics <- validate_subgroup_demographics(
                    validation_boundary,
                    inputs,
                    i,
                    config$demographics
                )

                if (!valid_demographics) {
                    return(FALSE)
                }
            }

            # Validate intervention settings for each subgroup
            valid_interventions <- validate_subgroup_interventions(
                validation_boundary,
                inputs,
                i,
                config$interventions
            )

            if (!valid_interventions) {
                return(FALSE)
            }
        }
    }

    TRUE
}

#' Validate demographics for a subgroup
#' @param validation_boundary Validation boundary object
#' @param inputs Input values
#' @param group_num Subgroup number
#' @param config Demographics configuration
#' @return TRUE if valid, FALSE if invalid
validate_subgroup_demographics <- function(validation_boundary, inputs, group_num, config) {
    get_input_id <- function(field) {
        paste0("demographic_", field, "_", group_num)
    }

    # Validate each demographic field
    for (field in names(config)) {
        field_config <- config[[field]]
        field_id <- get_input_id(field)
        field_value <- inputs[[field_id]]

        # If "all" is selected, skip other validations for this field
        if ("all" %in% field_value) {
            next
        }

        valid <- validation_boundary$validate(
            field_value,
            list(
                validation_boundary$rules$required(
                    sprintf(
                        "Please select at least one %s for subgroup %d",
                        field_config$label,
                        group_num
                    )
                ),
                validation_boundary$rules$not_empty(
                    sprintf(
                        "Please select at least one %s for subgroup %d",
                        field_config$label,
                        group_num
                    )
                )
            )
        )

        if (!valid) {
            return(FALSE)
        }
    }

    TRUE
}

#' Validate intervention settings for a subgroup
#' @param validation_boundary Validation boundary object
#' @param inputs Input values
#' @param group_num Subgroup number
#' @param config Interventions configuration
#' @return TRUE if valid, FALSE if invalid
validate_subgroup_interventions <- function(validation_boundary, inputs, group_num, config) {
    # Validate dates using config
    dates_valid <- validate_intervention_dates(
        validation_boundary,
        inputs,
        group_num,
        config$dates
    )

    if (!dates_valid) {
        return(FALSE)
    }

    # Validate each intervention component
    for (component_name in names(config$components)) {
        component <- config$components[[component_name]]
        component_id <- paste0("int_", component_name, "_", group_num, "_custom")

        # Handle different component types
        if (component$type == "compound") {
            enabled_id <- paste0(component_id, "_enabled")

            # If intervention is enabled, validate its inputs
            if (inputs[[enabled_id]]) {
                # Validate each input in the compound component
                for (input_name in names(component$inputs)) {
                    input_config <- component$inputs[[input_name]]
                    if (input_name == "enabled") next # Skip enabled checkbox

                    value_id <- paste0(component_id, "_", input_name)

                    # Create validation rules based on input type
                    rules <- list(validation_boundary$rules$required(
                        sprintf("%s is required when enabled", component$label)
                    ))

                    # Add type-specific validation
                    if (input_config$type == "numeric") {
                        rules[[length(rules) + 1]] <- validation_boundary$rules$range(
                            min = input_config$min,
                            max = input_config$max,
                            message = sprintf(
                                "%s must be between %s and %s for subgroup %d",
                                input_config$label,
                                input_config$min,
                                input_config$max,
                                group_num
                            )
                        )
                    } else if (input_config$type == "select") {
                        rules[[length(rules) + 1]] <- validation_boundary$rules$custom(
                            test_fn = function(value) value %in% names(input_config$options),
                            message = sprintf("Invalid %s selection", input_config$label)
                        )
                    }

                    valid <- validation_boundary$validate(inputs[[value_id]], rules)
                    if (!valid) {
                        return(FALSE)
                    }
                }
            }
        } else if (component$type == "numeric") {
            # Direct numeric validation
            rules <- list(
                validation_boundary$rules$required(sprintf("%s is required", component$label)),
                validation_boundary$rules$range(
                    min = component$min,
                    max = component$max,
                    message = sprintf(
                        "%s must be between %d and %d",
                        component$label,
                        component$min,
                        component$max
                    )
                )
            )

            valid <- validation_boundary$validate(inputs[[component_id]], rules)
            if (!valid) {
                return(FALSE)
            }
        }
    }

    TRUE
}

#' Validate intervention dates
#' @param validation_boundary Validation boundary object
#' @param inputs Input values
#' @param group_num Subgroup number
#' @param config Date configuration from YAML
#' @return TRUE if valid, FALSE if invalid
validate_intervention_dates <- function(validation_boundary, inputs, group_num, config) {
    start_id <- paste0("int_intervention_dates_", group_num, "_custom_start")
    end_id <- paste0("int_intervention_dates_", group_num, "_custom_end")

    # Validate start date
    valid_start <- validation_boundary$validate(
        inputs[[start_id]],
        list(
            validation_boundary$rules$required("Start date is required")
        )
    )

    if (!valid_start) {
        return(FALSE)
    }

    # Validate end date
    valid_end <- validation_boundary$validate(
        inputs[[end_id]],
        list(
            validation_boundary$rules$required("End date is required"),
            validation_boundary$rules$custom(
                test_fn = function(value) {
                    as.numeric(value) > as.numeric(inputs[[start_id]])
                },
                message = "End date must be after start date"
            )
        )
    )

    valid_end
}