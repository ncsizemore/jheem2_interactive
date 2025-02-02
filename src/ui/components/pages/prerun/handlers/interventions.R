# src/ui/components/pages/prerun/handlers/interventions.R

#' Initialize intervention handlers for prerun page
#' @param input Shiny session object
#' @param output Shiny output object
#' @param session Shiny session object
#' @param validation_manager Validation manager instance
#' @param config Page configuration
initialize_intervention_handlers <- function(input, output, session, validation_manager, config) {
    validation_boundary <- create_validation_boundary(
        session,
        output,
        "prerun",
        "intervention_validation",
        validation_manager = validation_manager
    )

    # Helper to create validation rules based on selector config
    create_selector_validation <- function(selector_id) {
        # Get full selector config using the config system
        selector_config <- get_selector_config(selector_id, "prerun")

        list(
            validation_boundary$rules$required(
                sprintf("Please select %s", selector_config$label)
            ),
            validation_boundary$rules$custom(
                test_fn = function(value) {
                    valid_options <- names(selector_config$options)
                    valid_options <- valid_options[valid_options != "none"] # Exclude "none" from valid options
                    !is.null(value) && value %in% valid_options
                },
                message = sprintf("Please select a valid %s", selector_config$label)
            )
        )
    }

    # Helper to update UI error state
    update_error_state <- function(selector_id, is_valid) {
        selector_config <- get_selector_config(selector_id, "prerun")
        field_id <- selector_config$id

        if (!is_valid) {
            error_state <- validation_manager$get_field_state(field_id)
            runjs(sprintf("
                $('#%s').addClass('is-invalid');
                $('#%s_error').text('%s').show();
            ", field_id, field_id, error_state$message))
        } else {
            runjs(sprintf("
                $('#%s').removeClass('is-invalid');
                $('#%s_error').hide();
            ", field_id, field_id))
        }
    }

    # Validate each selector field
    selector_fields <- c(
        "intervention_aspects",
        "population_groups",
        "timeframes",
        "intensities"
    )

    # Create observers for each selector
    lapply(selector_fields, function(selector_id) {
        input_id <- paste0("int_", selector_id, "_prerun")

        observeEvent(input[[input_id]], {
            print(sprintf("Validating %s: %s", selector_id, input[[input_id]]))

            valid <- validation_boundary$validate(
                input[[input_id]],
                create_selector_validation(selector_id),
                field_id = input_id
            )

            update_error_state(selector_id, valid)

            # If this is intervention_aspects, handle downstream effects
            if (selector_id == "intervention_aspects" && input[[input_id]] == "none") {
                # Clear other selections if "none" is selected
                lapply(setdiff(selector_fields, "intervention_aspects"), function(field) {
                    updateRadioButtons(session, paste0("int_", field, "_prerun"), selected = "none")
                })
            }
        })
    })

    # Helper to collect all validation states
    get_all_validation_states <- function() {
        all_states <- lapply(selector_fields, function(selector_id) {
            input_id <- paste0("int_", selector_id, "_prerun")
            validation_manager$get_field_state(input_id)$valid
        })
        all(unlist(all_states))
    }

    # Export validation state checker
    session$userData$prerun_validation <- list(
        is_valid = get_all_validation_states
    )
}
