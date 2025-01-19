# components/common/state/visualization.R

#' Create a visualization state manager
#' @param session Shiny session object
#' @param page_id Character: page identifier
#' @param id Character: component identifier
#' @return List of handler functions
create_visualization_manager <- function(session, page_id, id) {
    ns <- session$ns
    store <- get_store()
    
    list(
        # Update visualization state
        set_visibility = function(visibility) {
            store$update_visualization_state(
                page_id,
                visibility = visibility
            )
            
            # Maintain compatibility with current implementation
            updateTextInput(
                session,
                ns("visualization_state"),
                value = visibility
            )
        },
        
        # Update plot status
        set_plot_status = function(status) {
            store$update_visualization_state(
                page_id,
                plot_status = status
            )
            
            # Maintain compatibility with current implementation
            updateTextInput(
                session,
                ns("plot_status"),
                value = status
            )
        },
        
        # Set error state
        set_error = function(message) {
            store$update_visualization_state(
                page_id,
                plot_status = "error",
                error_message = message
            )
            
            # Maintain compatibility with current implementation
            updateTextInput(
                session,
                ns("plot_status"),
                value = "error"
            )
            updateTextInput(
                session,
                ns("error_message"),
                value = message
            )
        },
        
        # Clear error state
        clear_error = function() {
            store$update_visualization_state(
                page_id,
                plot_status = "ready",
                error_message = ""
            )
            
            # Maintain compatibility with current implementation
            updateTextInput(
                session,
                ns("plot_status"),
                value = "ready"
            )
            updateTextInput(
                session,
                ns("error_message"),
                value = ""
            )
        },
        
        # Reset all states
        reset = function() {
            store$update_visualization_state(
                page_id,
                visibility = "hidden",
                plot_status = "ready",
                error_message = ""
            )
            
            # Maintain compatibility with current implementation
            updateTextInput(
                session,
                ns("visualization_state"),
                value = "hidden"
            )
            updateTextInput(
                session,
                ns("plot_status"),
                value = "ready"
            )
            updateTextInput(
                session,
                ns("error_message"),
                value = ""
            )
        },
        
        # Get current visualization state
        get_state = function() {
            panel_state <- store$get_panel_state(page_id)
            panel_state$visualization
        }
    )
}

#' Create a reactive visualization state source
#' @param page_id Character: page identifier
#' @return Reactive expression returning current visualization state
create_visualization_state_source <- function(page_id) {
    store <- get_store()
    reactive({
        panel_state <- store$get_panel_state(page_id)
        panel_state$visualization
    })
}