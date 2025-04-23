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

      tryCatch(
        {
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
        },
        error = function(e) {
          print(sprintf("[UI_MESSENGER] Error sending start message: %s", e$message))
          invisible(FALSE)
        }
      )
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

      # Only log significant progress updates to reduce console clutter
      verbose_logging <- FALSE

      tryCatch(
        {
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
        },
        error = function(e) {
          print(sprintf("[UI_MESSENGER] Error sending progress message: %s", e$message))
          invisible(FALSE)
        }
      )
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

      tryCatch(
        {
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
        },
        error = function(e) {
          print(sprintf("[UI_MESSENGER] Error sending complete message: %s", e$message))
          invisible(FALSE)
        }
      )
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

      tryCatch(
        {
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
        },
        error = function(e) {
          print(sprintf("[UI_MESSENGER] Error sending error message: %s", e$message))
          invisible(FALSE)
        }
      )
    },

    #' Send a simulation start message
    #' @param id Simulation identifier
    #' @param description Short description of the simulation
    #' @param additional_data Optional list of additional data to include
    #' @return Invisible TRUE on success, FALSE on failure
    send_simulation_start = function(id, description = "Running Intervention", additional_data = NULL) {
      if (is.null(self$session)) {
        print("[UI_MESSENGER] Cannot send simulation start message - no valid session")
        return(invisible(FALSE))
      }

      tryCatch(
        {
          message_data <- list(
            id = id,
            description = description,
            timestamp = format(Sys.time(), "%H:%M:%S.%OS3")
          )

          # Add any additional data
          if (!is.null(additional_data) && is.list(additional_data)) {
            for (name in names(additional_data)) {
              message_data[[name]] <- additional_data[[name]]
            }
          }

          # Send message via both channels for compatibility
          self$session$sendCustomMessage("simulation_progress_start", message_data)

          message_data$action <- "start"
          self$session$sendCustomMessage("simulation_progress_update", message_data)

          print(sprintf("[UI_MESSENGER] Sent simulation start message for %s", id))
          invisible(TRUE)
        },
        error = function(e) {
          print(sprintf("[UI_MESSENGER] Error sending simulation start message: %s", e$message))
          invisible(FALSE)
        }
      )
    },

    #' Send a simulation progress update message
    #' @param id Simulation identifier
    #' @param current Current simulation index
    #' @param total Total number of simulations
    #' @param percent Progress percentage (0-100)
    #' @param description Optional simulation description
    #' @param additional_data Optional list of additional data to include
    #' @return Invisible TRUE on success, FALSE on failure
    send_simulation_progress = function(id, current, total, percent, description = NULL, additional_data = NULL) {
      if (is.null(self$session)) {
        return(invisible(FALSE))
      }

      tryCatch(
        {
          message_data <- list(
            action = "update",
            id = id,
            current = current,
            total = total,
            percent = percent,
            timestamp = format(Sys.time(), "%H:%M:%S.%OS3")
          )

          if (!is.null(description)) {
            message_data$description <- description
          }

          # Add any additional data
          if (!is.null(additional_data) && is.list(additional_data)) {
            for (name in names(additional_data)) {
              message_data[[name]] <- additional_data[[name]]
            }
          }

          self$session$sendCustomMessage("simulation_progress_update", message_data)
          invisible(TRUE)
        },
        error = function(e) {
          print(sprintf("[UI_MESSENGER] Error sending simulation progress message: %s", e$message))
          invisible(FALSE)
        }
      )
    },

    #' Send a simulation complete message
    #' @param id Simulation identifier
    #' @param description Optional simulation description
    #' @param additional_data Optional list of additional data to include
    #' @return Invisible TRUE on success, FALSE on failure
    send_simulation_complete = function(id, description = NULL, additional_data = NULL) {
      if (is.null(self$session)) {
        return(invisible(FALSE))
      }

      tryCatch(
        {
          message_data <- list(
            id = id,
            timestamp = format(Sys.time(), "%H:%M:%S.%OS3")
          )

          if (!is.null(description)) {
            message_data$description <- description
          }

          # Add any additional data
          if (!is.null(additional_data) && is.list(additional_data)) {
            for (name in names(additional_data)) {
              message_data[[name]] <- additional_data[[name]]
            }
          }

          # Send message via both channels for compatibility
          self$session$sendCustomMessage("simulation_progress_complete", message_data)

          message_data$action <- "complete"
          self$session$sendCustomMessage("simulation_progress_update", message_data)

          print(sprintf("[UI_MESSENGER] Sent simulation complete message for %s", id))
          invisible(TRUE)
        },
        error = function(e) {
          print(sprintf("[UI_MESSENGER] Error sending simulation complete message: %s", e$message))
          invisible(FALSE)
        }
      )
    },

    #' Send a simulation error message
    #' @param id Simulation identifier
    #' @param message Error message
    #' @param error_type Error type from ERROR_TYPES
    #' @param severity Error severity from SEVERITY_LEVELS
    #' @param additional_data Optional list of additional data to include
    #' @return Invisible TRUE on success, FALSE on failure
    send_simulation_error = function(id, message, error_type = ERROR_TYPES$SIMULATION,
                                     severity = SEVERITY_LEVELS$ERROR, additional_data = NULL) {
      if (is.null(self$session)) {
        return(invisible(FALSE))
      }

      tryCatch(
        {
          message_data <- list(
            id = id,
            message = message,
            error_type = error_type,
            severity = severity,
            timestamp = format(Sys.time(), "%H:%M:%S.%OS3")
          )

          # Add any additional data
          if (!is.null(additional_data) && is.list(additional_data)) {
            for (name in names(additional_data)) {
              message_data[[name]] <- additional_data[[name]]
            }
          }

          # Send message via both channels for compatibility
          self$session$sendCustomMessage("simulation_progress_error", message_data)

          message_data$action <- "error"
          self$session$sendCustomMessage("simulation_progress_update", message_data)

          print(sprintf("[UI_MESSENGER] Sent simulation error message for %s", id))
          invisible(TRUE)
        },
        error = function(e) {
          print(sprintf("[UI_MESSENGER] Error sending simulation error message: %s", e$message))
          invisible(FALSE)
        }
      )
    },

    #' Send a plot loading message
    #' @param indicator_id The DOM ID of the loading indicator element
    #' @return Invisible TRUE on success, FALSE on failure
    send_plot_loading = function(indicator_id) {
      if (is.null(self$session)) {
        print("[UI_MESSENGER] Cannot send plot loading message - no valid session")
        return(invisible(FALSE))
      }
      tryCatch(
        {
          message_data <- list(
            indicator_id = indicator_id,
            timestamp = format(Sys.time(), "%H:%M:%S.%OS3")
          )
          self$session$sendCustomMessage("plotLoading", message_data)
          
          # Extract page ID from indicator ID
          page_id <- sub("-visualization-loading_indicator", "", indicator_id)
          
          # Also show the global loading overlay
          js_code <- sprintf(
            "if($('#global-loading-overlay').length) {
              const targetArea = $('.%s-container .main-panel-plot');
              if (targetArea.length) {
                const rect = targetArea[0].getBoundingClientRect();
                $('#global-loading-overlay').css({
                  'position': 'fixed',
                  'top': rect.top + 'px',
                  'left': rect.left + 'px',
                  'width': rect.width + 'px',
                  'height': (rect.height || 400) + 'px',
                  'display': 'flex',
                  'z-index': '10000'
                });
              }
            }",
            page_id
          )
          self$session$sendCustomMessage("javascript", js_code)
          
          print(sprintf("[UI_MESSENGER] Sent plot loading message for %s", indicator_id))
          invisible(TRUE)
        },
        error = function(e) {
          print(sprintf("[UI_MESSENGER] Error sending plot loading message: %s", e$message))
          invisible(FALSE)
        }
      )
    },

    #' Send a plot ready message
    #' @param indicator_id The DOM ID of the loading indicator element
    #' @return Invisible TRUE on success, FALSE on failure
    send_plot_ready = function(indicator_id) {
      if (is.null(self$session)) {
        print("[UI_MESSENGER] Cannot send plot ready message - no valid session")
        return(invisible(FALSE))
      }
      tryCatch(
        {
          message_data <- list(
            indicator_id = indicator_id,
            timestamp = format(Sys.time(), "%H:%M:%S.%OS3")
          )
          self$session$sendCustomMessage("plotReady", message_data)
          
          # Use a direct custom message to hide our global overlay
          self$session$sendCustomMessage("hideLoadingOverlay", list())
          print("[UI_MESSENGER] Sent hide loading overlay message")
          
          print(sprintf("[UI_MESSENGER] Sent plot ready message for %s", indicator_id))
          invisible(TRUE)
        },
        error = function(e) {
          print(sprintf("[UI_MESSENGER] Error sending plot ready message: %s", e$message))
          invisible(FALSE)
        }
      )
    }
  )
)

#' Create a UIMessenger instance
#' @param session Shiny session object
#' @return UIMessenger instance
create_ui_messenger <- function(session) {
  UIMessenger$new(session)
}
