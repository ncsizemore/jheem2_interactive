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

    # Validate subgroups count
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

    # Validate location
    valid_location <- validation_boundary$validate(
        inputs$int_location_custom,
        list(
            validation_boundary$rules$required("Please select a location")
        )
    )

    if (!valid_location) {
        return(FALSE)
    }

    # Validate subgroups
    subgroup_count <- inputs$subgroups_count_custom
    for (i in 1:subgroup_count) {
        # Validate demographics for each subgroup
        valid_demographics <- validate_subgroup_demographics(
            validation_boundary,
            inputs,
            i,
            config$demographics
        )

        if (!valid_demographics) {
            return(FALSE)
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
        paste0("int_", field, "_", group_num, "_custom")
    }

    # Validate each demographic field
    for (field in names(config)) {
        field_config <- config[[field]]
        field_id <- get_input_id(field)

        # Skip if not a checkbox type (handles potential future demographic types)
        if (field_config$type != "checkbox") next

        valid <- validation_boundary$validate(
            inputs[[field_id]],
            list(
                validation_boundary$rules$required(
                    sprintf(
                        "Please select %s for subgroup %d",
                        field_config$label,
                        group_num
                    )
                ),
                validation_boundary$rules$custom(
                    test_fn = function(value) {
                        all(value %in% names(field_config$options))
                    },
                    message = sprintf(
                        "Invalid %s selection for subgroup %d",
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
        enabled_id <- paste0("int_", component_name, "_", group_num, "_custom_enabled")

        # If intervention is enabled, validate its inputs
        if (inputs[[enabled_id]]) {
            # Validate each input in the compound component
            for (input_name in names(component$inputs)) {
                input_config <- component$inputs[[input_name]]
                if (input_name == "enabled") next # Skip enabled checkbox

                value_id <- paste0("int_", component_name, "_", group_num, "_custom_", input_name)

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

    date_config <- config$dates

    # Validate start date
    valid_start <- validation_boundary$validate(
        inputs[[start_id]],
        list(
            validation_boundary$rules$required("Start date is required"),
            validation_boundary$rules$custom(
                test_fn = function(value) {
                    year <- as.numeric(value)
                    year >= date_config$start$options$from &&
                        year <= date_config$start$options$to
                },
                message = sprintf(
                    "Start date must be between %d and %d",
                    date_config$start$options$from,
                    date_config$start$options$to
                )
            )
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
                    year <- as.numeric(value)
                    year >= date_config$end$options$from &&
                        year <= date_config$end$options$to &&
                        year > as.numeric(inputs[[start_id]])
                },
                message = sprintf(
                    "End date must be between %d and %d and after start date",
                    date_config$end$options$from,
                    date_config$end$options$to
                )
            )
        )
    )

    valid_end
}
