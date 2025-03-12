# src/ui/components/pages/prerun/handlers/visualization.R

#' Initialize visualization toggle handlers for prerun page
#' @param input Shiny session object
#' @param output Shiny output object
#' @param session Shiny session object
#' @param vis_manager Visualization manager instance
initialize_prerun_visualization_handlers <- function(input, output, session, vis_manager) {
    # Register simulation error boundary for prerun page
    get_simulation_adapter()$register_error_boundary("prerun", session, output)
    print("[PRERUN] Registered simulation error boundary")

    # Handle plot toggle
    observeEvent(input[["prerun-toggle_plot"]],
        {
            print("\n=== Plot Toggle Event ===")
            print(paste("1. Event triggered at:", Sys.time()))

            store <- get_store()
            tryCatch(
                {
                    state <- store$get_panel_state("prerun")
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
            print("[PRERUN] Plot toggle - updated store state only")
            print("[PRERUN] Sync system should handle UI updates")

            tryCatch(
                {
                    state <- store$get_panel_state("prerun")
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
    observeEvent(input[["prerun-toggle_table"]],
        {
            print("\n=== Table Toggle Event ===")
            print(paste("1. Event triggered at:", Sys.time()))

            store <- get_store()
            tryCatch(
                {
                    state <- store$get_panel_state("prerun")
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
            print("[PRERUN] Table toggle - updated store state only")
            print("[PRERUN] Sync system should handle UI updates")

            tryCatch(
                {
                    state <- store$get_panel_state("prerun")
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
