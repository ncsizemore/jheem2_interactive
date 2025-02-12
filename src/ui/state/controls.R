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

    # Get defaults from config
    config <- get_component_config("controls")
    print("=== Control Manager Creation ===")
    print("1. Raw config defaults:")
    str(config$plot_controls$outcomes$defaults)

    # Get the outcome IDs from the options
    outcome_ids <- sapply(config$plot_controls$outcomes$options, function(x) x$id)
    print("2. Available outcome IDs:")
    str(outcome_ids)

    # Map default IDs to their option keys
    default_outcomes <- config$plot_controls$outcomes$defaults
    print("3. Default outcomes:")
    str(default_outcomes)

    config_defaults <- list(
        outcomes = default_outcomes, # Use direct IDs instead of mapping
        facet.by = NULL,
        summary.type = "mean.and.interval"
    )
    print("4. Final config defaults:")
    str(config_defaults)

    # Initialize with config defaults
    settings_state <- reactiveVal(config_defaults)

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
        get_settings = function() {
            current <- settings_state()
            print("=== Getting Control Settings ===")
            print("Current settings:")
            str(current)
            return(current)
        },
        update_settings = function(settings) {
            if (is.null(settings)) {
                return()
            }
            print("=== Updating Control Settings ===")
            print("New settings:")
            str(settings)

            settings_state(settings)
            store$update_control_state(page_id, settings)

            print("After update:")
            str(settings_state())
        },
        reset = function() {
            print("=== Resetting Control Settings ===")
            print("Resetting to defaults:")
            str(config_defaults)

            settings_state(config_defaults)
            store$update_control_state(page_id, config_defaults)

            print("After reset:")
            str(settings_state())
        }
    )
}
