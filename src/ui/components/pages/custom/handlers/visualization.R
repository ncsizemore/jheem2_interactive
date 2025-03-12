# src/ui/components/pages/custom/handlers/visualization.R

#' Initialize visualization toggle handlers for custom page
#' @param input Shiny session object
#' @param output Shiny output object
#' @param session Shiny session object
#' @param vis_manager Visualization manager instance
initialize_custom_visualization_handlers <- function(input, output, session, vis_manager) {
    # Register simulation error boundary for custom page
    get_simulation_adapter()$register_error_boundary("custom", session, output)
    print("[CUSTOM] Registered simulation error boundary")

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

            # Update only the central state - the sync system will handle UI
            vis_manager$set_display_type("plot")
            vis_manager$set_visibility("visible")
            
            # Debug log
            print("[CUSTOM] Plot toggle - updated store state only")
            print("[CUSTOM] Sync system should handle UI updates")

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

            # Update only the central state - the sync system will handle UI
            vis_manager$set_display_type("table")
            vis_manager$set_visibility("visible")
            
            # Debug log
            print("[CUSTOM] Table toggle - updated store state only")
            print("[CUSTOM] Sync system should handle UI updates")

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
