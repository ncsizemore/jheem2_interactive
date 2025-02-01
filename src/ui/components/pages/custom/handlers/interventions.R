# src/ui/components/pages/custom/handlers/interventions.R

#' Initialize intervention handlers for custom page
#' @param input Shiny session object
#' @param output Shiny output object
#' @param session Shiny session object
#' @param validation_manager Validation manager instance
#' @param config Page configuration
initialize_intervention_handlers <- function(input, output, session, validation_manager, config) {
    # Create observers for intervention inputs
    observe({
        # Get current subgroup count, handle NA/invalid values
        subgroup_count <- tryCatch(
            {
                count <- as.numeric(input$subgroups_count_custom)
                if (is.na(count) || count < config$subgroups$min || count > config$subgroups$max) {
                    config$subgroups$min # Default to min if invalid
                } else {
                    count
                }
            },
            error = function(e) {
                config$subgroups$min # Default to min on error
            }
        )

        # For each subgroup
        for (i in 1:subgroup_count) {
            local({
                group_num <- i # Need local binding

                # For each intervention component in config
                for (component_name in names(config$interventions$components)) {
                    local({
                        component <- config$interventions$components[[component_name]]

                        # Skip if not a compound type with numeric/select inputs
                        if (component$type != "compound") {
                            return()
                        }

                        enabled_id <- paste0("int_", component_name, "_", group_num, "_custom_enabled")

                        # For each input in the compound component
                        for (input_name in names(component$inputs)) {
                            input_config <- component$inputs[[input_name]]
                            if (input_name == "enabled") next # Skip enabled checkbox

                            value_id <- paste0("int_", component_name, "_", group_num, "_custom_", input_name)

                            # Add input change observer
                            observeEvent(input[[enabled_id]], {
                                if (!input[[enabled_id]]) {
                                    # Clear validation state for this field
                                    validation_manager$update_field(value_id, TRUE)
                                    # Clear UI validation state
                                    runjs(sprintf("
                                        $('#%s').removeClass('is-invalid');
                                        $('#%s_error').hide();
                                    ", value_id, value_id))
                                }
                            })

                            observeEvent(input[[value_id]], {
                                if (input[[enabled_id]]) {
                                    validation_boundary <- create_validation_boundary(
                                        session,
                                        output,
                                        "custom",
                                        paste0(component_name, "_validation_", group_num),
                                        validation_manager = validation_manager
                                    )

                                    # Create validation rules based on input type
                                    rules <- list(
                                        validation_boundary$rules$required(
                                            sprintf("%s is required", input_config$label)
                                        )
                                    )

                                    if (input_config$type == "numeric") {
                                        rules[[length(rules) + 1]] <- validation_boundary$rules$range(
                                            min = input_config$min,
                                            max = input_config$max,
                                            message = sprintf(
                                                "%s must be between %s and %s",
                                                input_config$label,
                                                input_config$min,
                                                input_config$max
                                            )
                                        )
                                    }

                                    # Validate and update UI
                                    valid <- validation_boundary$validate(input[[value_id]], rules, field_id = value_id)
                                    if (!valid) {
                                        error_state <- validation_manager$get_field_state(value_id)
                                        runjs(sprintf("
                                            $('#%s').addClass('is-invalid');
                                            $('#%s_error').text('%s').show();
                                        ", value_id, value_id, error_state$message))
                                    } else {
                                        runjs(sprintf("
                                            $('#%s').removeClass('is-invalid');
                                            $('#%s_error').hide();
                                        ", value_id, value_id))
                                    }
                                }
                            })
                        }
                    })
                }
            })
        }
    })
}

#' Collect settings for all subgroups
#' @param input Shiny input object
#' @param subgroup_count Number of subgroups
#' @return List of settings
collect_custom_settings <- function(input, subgroup_count) {
    print("Collecting custom settings")

    # Get plot control settings
    plot_settings <- get_control_settings(input, "custom")
    print("Plot settings:")
    str(plot_settings)

    # Get intervention settings
    intervention_settings <- list(
        location = isolate(input$int_location_custom),
        subgroups = lapply(1:subgroup_count, function(i) {
            collect_subgroup_settings(input, i)
        })
    )
    print("Intervention settings:")
    str(intervention_settings)

    # Combine both types of settings
    c(plot_settings, intervention_settings)
}

#' Collect settings for a single subgroup
#' @param input Shiny input object
#' @param group_num Subgroup number
#' @return List of subgroup settings
collect_subgroup_settings <- function(input, group_num) {
    list(
        demographics = list(
            age_groups = isolate(input[[paste0("int_age_groups_", group_num, "_custom")]]),
            race_ethnicity = isolate(input[[paste0("int_race_ethnicity_", group_num, "_custom")]]),
            biological_sex = isolate(input[[paste0("int_biological_sex_", group_num, "_custom")]]),
            risk_factor = isolate(input[[paste0("int_risk_factor_", group_num, "_custom")]])
        ),
        interventions = list(
            dates = list(
                start = isolate(input[[paste0("int_intervention_dates_", group_num, "_custom_start")]]),
                end = isolate(input[[paste0("int_intervention_dates_", group_num, "_custom_end")]])
            ),
            testing = if (isolate(input[[paste0("int_testing_", group_num, "_custom_enabled")]])) {
                list(frequency = isolate(input[[paste0("int_testing_", group_num, "_custom_frequency")]]))
            },
            prep = if (isolate(input[[paste0("int_prep_", group_num, "_custom_enabled")]])) {
                list(coverage = isolate(input[[paste0("int_prep_", group_num, "_custom_coverage")]]))
            },
            suppression = if (isolate(input[[paste0("int_suppression_", group_num, "_custom_enabled")]])) {
                list(proportion = isolate(input[[paste0("int_suppression_", group_num, "_custom_proportion")]]))
            }
        )
    )
}
