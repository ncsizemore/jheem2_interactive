# components/common/state/store.R

library(R6)

#' State Store Class
#' @description Central state management for the application
StateStore <- R6Class("StateStore",
                      public = list(
                          #' @field panel_states List of ReactiveVal objects for each panel
                          panel_states = NULL,
                          
                          #' @description Initialize the store
                          #' @param page_ids Character vector of page identifiers
                          initialize = function(page_ids = c("prerun", "custom")) {
                              private$setup_panel_states(page_ids)
                          },
                          
                          #' @description Get the current state for a panel
                          #' @param page_id Character: panel identifier
                          #' @return Current panel state
                          get_panel_state = function(page_id) {
                              if (is.null(self$panel_states[[page_id]])) {
                                  stop(sprintf("No state found for page: %s", page_id))
                              }
                              self$panel_states[[page_id]]()
                          },
                          
                          #' @description Update visualization state for a panel
                          #' @param page_id Character: panel identifier
                          #' @param visibility Character: new visibility state
                          #' @param plot_status Character: new plot status
                          #' @param error_message Character: new error message
                          update_visualization_state = function(
        page_id,
        visibility = NULL,
        plot_status = NULL,
        error_message = NULL
                          ) {
                              current_state <- self$get_panel_state(page_id)
                              
                              # Only update provided fields
                              if (!is.null(visibility)) {
                                  current_state$visualization$visibility <- visibility
                              }
                              if (!is.null(plot_status)) {
                                  current_state$visualization$plot_status <- plot_status
                              }
                              if (!is.null(error_message)) {
                                  current_state$visualization$error_message <- error_message
                              }
                              
                              # Validate and update
                              current_state$visualization <- validate_visualization_state(
                                  current_state$visualization
                              )
                              self$panel_states[[page_id]](current_state)
                              
                              invisible(self)
                          },
        
        #' @description Update control state for a panel
        #' @param page_id Character: panel identifier
        #' @param settings List: complete control settings
        update_control_state = function(page_id, settings) {
            if (is.null(settings)) return()
            
            current_state <- self$get_panel_state(page_id)
            
            # Update control state
            current_state$controls <- validate_control_state(settings)
            self$panel_states[[page_id]](current_state)
            
            invisible(self)
        },
        
        #' @description Reset state for a panel
        #' @param page_id Character: panel identifier
        reset_panel_state = function(page_id) {
            self$panel_states[[page_id]](create_panel_state(page_id))
            invisible(self)
        }
                      ),
        
        private = list(
            #' @description Set up reactive panel states
            #' @param page_ids Character vector of page identifiers
            setup_panel_states = function(page_ids) {
                self$panel_states <- lapply(page_ids, function(id) {
                    reactiveVal(create_panel_state(id))
                })
                names(self$panel_states) <- page_ids
            }
        )
)

# Create global store instance
STATE_STORE <- StateStore$new()

#' Helper function to get store instance
#' @return StateStore instance
get_store <- function() {
    STATE_STORE
}