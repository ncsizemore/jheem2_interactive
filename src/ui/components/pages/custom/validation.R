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
        if (section %in% names(config$selectors)) {
            next
        }

        # If not found in either place, it's missing
        stop(sprintf(
            "Missing required section '%s'. Must be defined either in page config or in common selectors.",
            section
        ))
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
