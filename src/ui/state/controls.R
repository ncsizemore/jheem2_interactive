# src/ui/state/controls.R

#' Create a control state manager
#' @param session Shiny session object
#' @param page_id Character: page identifier
#' @param id Character: component identifier
#' @param initial_settings Reactive source for initial settings
#' @return List of handler functions and reactive sources
create_control_manager <- function(session, page_id, id, initial_settings = NULL) {
    store <- get_store()
    ns <- session$ns

    # Initialize with strict structure defaults
    default_settings <- list(
        outcomes = NULL,
        facet.by = NULL, # Using dot notation consistently
        summary.type = "mean.and.interval" # Using dot notation consistently
    )

    settings_state <- reactiveVal(default_settings)

    # Initialize settings if provided
    observe({
        if (!is.null(initial_settings)) {
            init_settings <- initial_settings()
            if (!is.null(init_settings)) {
                # Ensure proper structure
                processed_settings <- list(
                    outcomes = init_settings$outcomes,
                    facet.by = init_settings$facet.by, # Using dot notation
                    summary.type = init_settings$summary.type # Using dot notation
                )
                settings_state(processed_settings)
                store$update_control_state(page_id, processed_settings)

                # Update UI to reflect initial settings
                if (!is.null(processed_settings$outcomes)) {
                    updateSelectInput(session,
                        ns("outcomes"),
                        selected = processed_settings$outcomes
                    )
                }
                if (!is.null(processed_settings$facet.by)) {
                    updateSelectInput(session,
                        ns("stratification"),
                        selected = processed_settings$facet.by
                    )
                }
            }
        }
    })

    list(
        # Update all settings at once
        update_settings = function(settings) {
            if (is.null(settings)) {
                return()
            }

            print("Control Manager: Updating settings")
            str(settings)

            # Process settings maintaining structure
            processed <- list(
                outcomes = if (!is.null(settings$outcomes)) as.character(settings$outcomes) else settings_state()$outcomes,
                facet.by = if (!is.null(settings$facet.by)) {
                    if (length(settings$facet.by) > 0) as.character(settings$facet.by) else NULL
                } else {
                    settings_state()$facet.by
                },
                summary.type = if (!is.null(settings$summary.type)) {
                    settings$summary.type
                } else {
                    settings_state()$summary.type
                }
            )

            print("Control Manager: Processed settings:")
            str(processed)

            # Update both reactive and store
            settings_state(processed)
            store$update_control_state(page_id, processed)
        },

        # Get current settings (reactive)
        get_settings = reactive({
            settings_state()
        }),

        # Reset settings with guaranteed structure
        reset = function() {
            print("Control Manager: Resetting to defaults:")
            str(default_settings)

            settings_state(default_settings)
            store$update_control_state(page_id, default_settings)
        }
    )
}
