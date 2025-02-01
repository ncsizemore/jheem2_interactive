# src/ui/state/validation.R

#' Create a validation state manager
#' @param session Shiny session object
#' @param page_id Character: page identifier
#' @param id Character: component identifier
#' @return List of handler functions and reactive sources
create_validation_manager <- function(session, page_id, id) {
    store <- get_store()

    list(
        # Update field validation state
        update_field = function(field_id, is_valid, message = NULL) {
            current_state <- store$get_panel_state(page_id)

            # Update field state
            current_state$validation$field_states[[field_id]] <- list(
                is_valid = is_valid,
                message = message
            )

            # Update overall validation state
            current_state$validation$is_valid <- all(
                vapply(
                    current_state$validation$field_states,
                    function(x) x$is_valid,
                    logical(1)
                )
            )

            # Update store
            store$update_validation_state(page_id, current_state$validation)
        },

        # Get validation state for a field
        get_field_state = function(field_id) {
            current_state <- store$get_panel_state(page_id)
            current_state$validation$field_states[[field_id]]
        },

        # Get overall validation state
        is_valid = function() {
            current_state <- store$get_panel_state(page_id)
            current_state$validation$is_valid
        },

        # Reset validation state
        reset = function() {
            store$update_validation_state(page_id, create_validation_state())
        }
    )
}
