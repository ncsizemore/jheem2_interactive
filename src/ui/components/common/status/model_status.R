# src/ui/components/common/status/model_status.R

#' Create model status UI component
#' @return Shiny UI component
create_model_status_ui <- function() {
  # Create a full page overlay for loading
  div(
    id = "model-loading-overlay",
    class = "model-loading-overlay hidden",
    div(
      class = "model-loading-content",
      div(class = "model-spinner"),
      h3("Loading JHEEM"),
      p("Preparing simulation environment...")
    )
  )
}

#' Create a model state manager
#' @param session Shiny session object
#' @param error_boundary Error boundary for model errors
#' @return List of functions for managing model state
create_model_status_manager <- function(session, error_boundary = NULL) {
    store <- get_store()
    
    # Create output for error message
    output <- session$output
    output$model_error_message <- renderText({
        # Get the current error message (in reactive context)
        store$get_model_state()$error_message
    })
    
    # Create a reactive timer to check model status periodically
    model_timer <- reactiveTimer(500)
    
    # Create a reactive to synchronize status with UI
    observe({
        # Trigger the timer
        model_timer()
        
        # Get current status
        status <- store$get_model_state()$status
        
        # Update input value
        updateTextInput(session, "model_status", value = status)
        
        # Update UI visibility based on status
        if (status == "loading") {
            runjs("$('#model-loading-overlay').removeClass('hidden');")
        } else if (status == "error") {
            # For errors, we could add an error message or toast notification instead
            runjs("$('#model-loading-overlay').addClass('hidden');")
            # Show error toast or another UI element for errors
        } else if (status == "loaded") {
            runjs("$('#model-loading-overlay').addClass('hidden');")
        }
    })
    
    list(
        # Load the model specification
        load_model_spec = function() {
            # Update store state
            store$update_model_state(status = "loading")
            
            # Source the model specification
            tryCatch({
                message("=== Starting model specification loading ===")
                source_model_specification()
                
                # Update store state on success
                store$update_model_state(status = "loaded")
                
                message("=== Completed model specification loading ===")
                TRUE
            }, error = function(e) {
                error_msg <- paste("Error loading simulation environment:", e$message)
                message(paste("ERROR:", error_msg))
                
                # Update store state on error
                store$update_model_state(
                    status = "error",
                    error_message = error_msg
                )
                
                # Use error boundary to show error if provided
                if (!is.null(error_boundary)) {
                    error_boundary$set_error(
                        message = error_msg,
                        type = "MODEL_LOAD_ERROR",
                        severity = "ERROR"
                    )
                }
                
                FALSE
            })
        },
        
        # Check if model spec is loaded
        is_loaded = function() {
            store$get_model_state()$status == "loaded"
        },
        
        # Get current status
        get_status = function() {
            store$get_model_state()$status
        },
        
        # Reset to initial state
        reset = function() {
            store$update_model_state(status = "loading", error_message = NULL)
            if (!is.null(error_boundary)) {
                error_boundary$clear()
            }
        }
    )
}