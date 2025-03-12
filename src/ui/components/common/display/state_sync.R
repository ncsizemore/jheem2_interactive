# src/ui/components/common/display/state_sync.R

#' Create a visualization state synchronization system
#' 
#' This module synchronizes the central state with the UI display.
#' It ensures that toggle buttons and panels properly reflect the state.
#' 
#' @param page_id Character: panel identifier ("prerun" or "custom")
#' @param session Shiny session object
#' @return Invisible NULL
create_visualization_sync <- function(page_id, session) {
  store <- get_store()
  
  # Create observer to sync state → UI
  observe({
    # Get current state 
    state <- store$get_panel_state(page_id)$visualization
    
    # Sync UI based on current state
    # This observer runs whenever the state changes
    
    # 1. Update display type state (plot vs table)
    # Create appropriate input element IDs
    toggle_plot_id <- paste0(page_id, "-toggle_plot")
    toggle_table_id <- paste0(page_id, "-toggle_table")
    
    # Log for debugging
    print(sprintf("[STATE_SYNC][%s] Current display type: %s", page_id, state$display_type))
    
    # Update toggle button active states using the current classes
    # Note: This uses the existing Shiny.js patterns but could be replaced
    # with a custom JavaScript handler in the future
    if (state$display_type == "plot") {
      # Make plot button active, table button inactive
      removeClass(id = toggle_table_id, class = "active", asis = TRUE)
      addClass(id = toggle_plot_id, class = "active", asis = TRUE)
    } else {
      # Make table button active, plot button inactive
      removeClass(id = toggle_plot_id, class = "active", asis = TRUE)
      addClass(id = toggle_table_id, class = "active", asis = TRUE)
    }
    
    # 2. Update panel visibility
    # Send a custom message to update panel visibility based on state
    # This relies on our custom JavaScript handler
    session$sendCustomMessage("updateVisualizationDisplay", list(
      page_id = page_id,
      display_type = state$display_type,
      visibility = state$visibility,
      plot_status = state$plot_status
    ))
  })
  
  invisible(NULL)
}
