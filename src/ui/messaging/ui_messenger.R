# src/ui/messaging/ui_messenger.R
library(R6)

# Load error types and severity levels from boundaries
source("src/ui/components/common/errors/boundaries.R")

#' UIMessenger Class
#' 
#' A temporary solution for direct UI messaging that bypasses the reactive system
#' when immediate UI updates are required (e.g., for download progress).
#' 
#' This class will be refactored out when moving to an async download approach
#' or a more modern web framework.
UIMessenger <- R6Class("UIMessenger",
  public = list(
    #' @field session The Shiny session object
    session = NULL,
    
    #' Initialize the messenger with a session
    #' @param session Shiny session object
    initialize = function(session) {
      self$session <- session
      print("[UI_MESSENGER] Initialized with session")
    },
    
    #' Send a download start message
    #' @param id Download identifier
    #' @param filename Name of the file being downloaded
    #' @param additional_data Optional list of additional data to include
    #' @return Invisible TRUE on success, FALSE on failure
    send_download_start = function(id, filename, additional_data = NULL) {
      if (is.null(self$session)) {
        print("[UI_MESSENGER] Cannot send start message - no valid session")
        return(invisible(FALSE))
      }
      
      tryCatch({
        message_data <- list(
          id = id,
          filename = filename,
          timestamp = format(Sys.time(), "%H:%M:%S.%OS3")
        )
        
        # Add any additional data
        if (!is.null(additional_data) && is.list(additional_data)) {
          for (name in names(additional_data)) {
            message_data[[name]] <- additional_data[[name]]
          }
        }
        
        # Send message via both channels for compatibility
        self$session$sendCustomMessage("download_progress_start", message_data)
        
        message_data$action <- "start"
        self$session$sendCustomMessage("download_progress_update", message_data)
        
        print(sprintf("[UI_MESSENGER] Sent download start message for %s", id))
        invisible(TRUE)
      }, error = function(e) {
        print(sprintf("[UI_MESSENGER] Error sending start message: %s", e$message))
        invisible(FALSE)
      })
    },
    
    #' Send a download progress update message
    #' @param id Download identifier
    #' @param percent Progress percentage (0-100)
    #' @param filename Optional filename (if not provided, only id is used)
    #' @param additional_data Optional list of additional data to include
    #' @return Invisible TRUE on success, FALSE on failure
    send_download_progress = function(id, percent, filename = NULL, additional_data = NULL) {
      if (is.null(self$session)) {
        return(invisible(FALSE))
      }
      
      tryCatch({
        message_data <- list(
          action = "update",
          id = id,
          percent = percent,
          timestamp = format(Sys.time(), "%H:%M:%S.%OS3")
        )
        
        if (!is.null(filename)) {
          message_data$filename <- filename
        }
        
        # Add any additional data
        if (!is.null(additional_data) && is.list(additional_data)) {
          for (name in names(additional_data)) {
            message_data[[name]] <- additional_data[[name]]
          }
        }
        
        self$session$sendCustomMessage("download_progress_update", message_data)
        invisible(TRUE)
      }, error = function(e) {
        print(sprintf("[UI_MESSENGER] Error sending progress message: %s", e$message))
        invisible(FALSE)
      })
    },
    
    #' Send a download complete message
    #' @param id Download identifier
    #' @param filename Optional filename (if not provided, only id is used)
    #' @param additional_data Optional list of additional data to include
    #' @return Invisible TRUE on success, FALSE on failure
    send_download_complete = function(id, filename = NULL, additional_data = NULL) {
      if (is.null(self$session)) {
        return(invisible(FALSE))
      }
      
      tryCatch({
        message_data <- list(
          id = id,
          timestamp = format(Sys.time(), "%H:%M:%S.%OS3")
        )
        
        if (!is.null(filename)) {
          message_data$filename <- filename
        }
        
        # Add any additional data
        if (!is.null(additional_data) && is.list(additional_data)) {
          for (name in names(additional_data)) {
            message_data[[name]] <- additional_data[[name]]
          }
        }
        
        # Send message via both channels for compatibility
        self$session$sendCustomMessage("download_progress_complete", message_data)
        
        message_data$action <- "complete"
        self$session$sendCustomMessage("download_progress_update", message_data)
        
        print(sprintf("[UI_MESSENGER] Sent download complete message for %s", id))
        invisible(TRUE)
      }, error = function(e) {
        print(sprintf("[UI_MESSENGER] Error sending complete message: %s", e$message))
        invisible(FALSE)
      })
    },
    
    #' Send a download error message
    #' @param id Download identifier
    #' @param message Error message
    #' @param filename Optional filename
    #' @param error_type Error type from ERROR_TYPES
    #' @param severity Error severity from SEVERITY_LEVELS
    #' @param additional_data Optional list of additional data to include
    #' @return Invisible TRUE on success, FALSE on failure
    send_download_error = function(id, message, filename = NULL, 
                                   error_type = ERROR_TYPES$DOWNLOAD, 
                                   severity = SEVERITY_LEVELS$ERROR, 
                                   additional_data = NULL) {
      if (is.null(self$session)) {
        return(invisible(FALSE))
      }
      
      tryCatch({
        message_data <- list(
          id = id,
          message = message,
          error_type = error_type,
          severity = severity,
          timestamp = format(Sys.time(), "%H:%M:%S.%OS3")
        )
        
        if (!is.null(filename)) {
          message_data$filename <- filename
        }
        
        # Add any additional data
        if (!is.null(additional_data) && is.list(additional_data)) {
          for (name in names(additional_data)) {
            message_data[[name]] <- additional_data[[name]]
          }
        }
        
        # Send message via both channels for compatibility
        self$session$sendCustomMessage("download_progress_error", message_data)
        
        message_data$action <- "error"
        self$session$sendCustomMessage("download_progress_update", message_data)
        
        print(sprintf("[UI_MESSENGER] Sent download error message for %s", id))
        invisible(TRUE)
      }, error = function(e) {
        print(sprintf("[UI_MESSENGER] Error sending error message: %s", e$message))
        invisible(FALSE)
      })
    }
  )
)

#' Create a UIMessenger instance
#' @param session Shiny session object
#' @return UIMessenger instance
create_ui_messenger <- function(session) {
  UIMessenger$new(session)
}
