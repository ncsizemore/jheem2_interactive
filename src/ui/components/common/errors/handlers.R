# src/ui/components/common/errors/handlers.R

#' Set component error in both boundary and direct output
#' @param boundary Error boundary object
#' @param output Shiny output object
#' @param error_id ID of the error output element
#' @param message Error message
#' @param type Error type from ERROR_TYPES
#' @param severity Error severity from SEVERITY_LEVELS
#' @param store Optional state store to update global error state
#' @param page_id Optional page ID for store update
set_component_error <- function(boundary, output, error_id, message,
                               type = ERROR_TYPES$SYSTEM,
                               severity = SEVERITY_LEVELS$ERROR,
                               store = NULL, page_id = NULL) {
  # Set in error boundary
  boundary$set_error(
    message = message,
    type = type,
    severity = severity
  )
  
  # Set direct error output
  output[[error_id]] <- renderText({
    sprintf("Error: %s", message)
  })
  
  # Update global error state if store provided
  if (!is.null(store) && !is.null(page_id)) {
    store$update_page_error_state(
      page_id,
      has_error = TRUE,
      message = message,
      type = type,
      severity = severity
    )
  }
}

#' Clear component error in both boundary and direct output
#' @param boundary Error boundary object
#' @param output Shiny output object
#' @param error_id ID of the error output element
#' @param store Optional state store to update global error state
#' @param page_id Optional page ID for store update
clear_component_error <- function(boundary, output, error_id, store = NULL, page_id = NULL) {
  # Clear error boundary
  boundary$clear()
  
  # Clear direct error output
  output[[error_id]] <- renderText({
    NULL
  })
  
  # Update global error state if store provided
  if (!is.null(store) && !is.null(page_id)) {
    store$update_page_error_state(
      page_id,
      has_error = FALSE,
      message = NULL,
      type = NULL,
      severity = NULL
    )
  }
}

#' Check if a component has an error
#' @param boundary Error boundary object
#' @return Boolean indicating if an error exists
has_component_error <- function(boundary) {
  if (is.null(boundary)) {
    return(FALSE)
  }
  
  tryCatch({
    return(boundary$has_error())
  }, error = function(e) {
    return(FALSE)
  })
}

#' Synchronize error state between components
#' @param source_boundary Source error boundary object
#' @param target_boundary Target error boundary object
#' @param output Shiny output object for target
#' @param error_id ID of the error output element for target
sync_error_state <- function(source_boundary, target_boundary, output, error_id) {
  if (is.null(source_boundary) || is.null(target_boundary)) {
    return(FALSE)
  }
  
  # Check if source has error
  if (source_boundary$has_error()) {
    # Get error state
    error_state <- source_boundary$get_state()
    
    # Set error in target
    target_boundary$set_error(
      message = error_state$message,
      type = error_state$type,
      severity = error_state$severity,
      details = error_state$details,
      source = error_state$source
    )
    
    # Set direct error message
    output[[error_id]] <- renderText({
      sprintf("Error: %s", error_state$message)
    })
    
    return(TRUE)
  } else {
    # Clear target if source has no error
    target_boundary$clear()
    output[[error_id]] <- renderText({ NULL })
    return(FALSE)
  }
}
