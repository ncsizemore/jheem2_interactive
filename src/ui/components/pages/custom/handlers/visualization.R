#' Initialize visualization toggle handlers for custom page
#' @param input Shiny session object
#' @param output Shiny output object
#' @param session Shiny session object
#' @param vis_manager Visualization manager instance
initialize_visualization_handlers <- function(input, output, session, vis_manager) {
    ns <- session$ns

    # Handle plot toggle
    observeEvent(input[["custom-toggle_plot"]],
        {
            print("\n=== Plot Toggle Event ===")
            print(paste("1. Event triggered at:", Sys.time()))

            store <- get_store()
            tryCatch(
                {
                    state <- store$get_panel_state("custom")
                    print("2. Current store state:")
                    print(state$visualization)
                },
                error = function(e) {
                    print("Error getting store state:", e$message)
                }
            )

            # Update both store and UI state
            vis_manager$set_display_type("plot")
            vis_manager$set_visibility("visible")
            updateTextInput(session, "custom-display_type", value = "plot")
            updateTextInput(session, "custom-visualization_state", value = "visible")

            # Update button states - use exact IDs
            removeClass(id = "custom-toggle_table", class = "active", asis = TRUE)
            addClass(id = "custom-toggle_plot", class = "active", asis = TRUE)

            tryCatch(
                {
                    state <- store$get_panel_state("custom")
                    print("3. Updated store state:")
                    print(state$visualization)
                },
                error = function(e) {
                    print("Error getting updated store state:", e$message)
                }
            )
        },
        ignoreInit = TRUE
    )

    # Handle table toggle
    observeEvent(input[["custom-toggle_table"]],
        {
            print("\n=== Table Toggle Event ===")
            print(paste("1. Event triggered at:", Sys.time()))

            store <- get_store()
            tryCatch(
                {
                    state <- store$get_panel_state("custom")
                    print("2. Current store state:")
                    print(state$visualization)
                },
                error = function(e) {
                    print("Error getting store state:", e$message)
                }
            )

            # Update both store and UI state
            vis_manager$set_display_type("table")
            vis_manager$set_visibility("visible")
            updateTextInput(session, "custom-display_type", value = "table")
            updateTextInput(session, "custom-visualization_state", value = "visible")

            # Update button states - use exact IDs
            removeClass(id = "custom-toggle_plot", class = "active", asis = TRUE)
            addClass(id = "custom-toggle_table", class = "active", asis = TRUE)

            tryCatch(
                {
                    state <- store$get_panel_state("custom")
                    print("3. Updated store state:")
                    print(state$visualization)
                },
                error = function(e) {
                    print("Error getting updated store state:", e$message)
                }
            )
        },
        ignoreInit = TRUE
    )
}
