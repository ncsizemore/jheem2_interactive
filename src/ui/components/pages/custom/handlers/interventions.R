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
        req(input$subgroups_count_custom)
        req(config$subgroups$min)

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

        # Only proceed if we have a valid subgroup count
        if (!is.null(subgroup_count) && subgroup_count > 0) {
            # For each subgroup
            for (i in 1:subgroup_count) {
                local({
                    group_num <- i

                    # Get intervention components from config
                    for (component_name in names(config$interventions$components)) {
                        local({
                            # Get component config using config system
                            component <- config$interventions$components[[component_name]]

                            # Skip if not a compound type
                            if (component$type != "compound") {
                                return()
                            }

                            # Get selector config for this component and group
                            selector_config <- get_selector_config(component_name, "custom", group_num)
                            enabled_id <- paste0(selector_config$id, "_enabled")

                            # For each input in the compound component
                            for (input_name in names(component$inputs)) {
                                if (input_name == "enabled") next # Skip enabled checkbox

                                input_config <- component$inputs[[input_name]]
                                value_id <- paste0(selector_config$id, "_", input_name)

                                # Create validation rules based on input type
                                create_validation_rules <- function() {
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

                                    rules
                                }

                                # Create validation boundary for this component
                                validation_boundary <- create_validation_boundary(
                                    session,
                                    output,
                                    "custom",
                                    paste0(component_name, "_validation_", group_num),
                                    validation_manager = validation_manager
                                )

                                # Add enabled state observer
                                observeEvent(input[[enabled_id]], {
                                    if (!input[[enabled_id]]) {
                                        # Clear validation state
                                        validation_manager$update_field(value_id, TRUE)
                                        # Clear UI validation state
                                        runjs(sprintf("
                                            $('#%s').removeClass('is-invalid');
                                            $('#%s_error').hide();
                                        ", value_id, value_id))
                                    }
                                })

                                # Add value change observer
                                observeEvent(input[[value_id]], {
                                    req(input[[enabled_id]]) # Explicit dependency

                                    if (isTRUE(input[[enabled_id]])) { # Safe boolean check
                                        req(input[[value_id]]) # Ensure value exists

                                        # Validate using config-based rules
                                        valid <- validation_boundary$validate(
                                            input[[value_id]],
                                            create_validation_rules(),
                                            field_id = value_id
                                        )

                                        # Update UI error state
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

    # Get intervention settings using config-based IDs
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
    # Use get_selector_config to get proper IDs
    demographics_config <- list(
        age_groups = get_selector_config("age_groups", "custom", group_num),
        race_ethnicity = get_selector_config("race_ethnicity", "custom", group_num),
        biological_sex = get_selector_config("biological_sex", "custom", group_num),
        risk_factor = get_selector_config("risk_factor", "custom", group_num)
    )

    intervention_config <- list(
        testing = get_selector_config("testing", "custom", group_num),
        prep = get_selector_config("prep", "custom", group_num),
        suppression = get_selector_config("suppression", "custom", group_num)
    )

    list(
        demographics = list(
            age_groups = isolate(input[[demographics_config$age_groups$id]]),
            race_ethnicity = isolate(input[[demographics_config$race_ethnicity$id]]),
            biological_sex = isolate(input[[demographics_config$biological_sex$id]]),
            risk_factor = isolate(input[[demographics_config$risk_factor$id]])
        ),
        interventions = list(
            dates = list(
                start = isolate(input[[paste0("int_intervention_dates_", group_num, "_custom_start")]]),
                end = isolate(input[[paste0("int_intervention_dates_", group_num, "_custom_end")]])
            ),
            testing = if (isolate(input[[paste0(intervention_config$testing$id, "_enabled")]])) {
                list(frequency = isolate(input[[paste0(intervention_config$testing$id, "_frequency")]]))
            },
            prep = if (isolate(input[[paste0(intervention_config$prep$id, "_enabled")]])) {
                list(coverage = isolate(input[[paste0(intervention_config$prep$id, "_coverage")]]))
            },
            suppression = if (isolate(input[[paste0(intervention_config$suppression$id, "_enabled")]])) {
                list(proportion = isolate(input[[paste0(intervention_config$suppression$id, "_proportion")]]))
            }
        )
    )
}
