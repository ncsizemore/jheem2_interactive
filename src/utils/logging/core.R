# src/utils/logging/core.R
#
# Core logging functionality for JHEEM application
# Handles file-based logging with console redirection

#' Generate a unique session ID for logging
#' @return Character session ID
generate_session_id <- function() {
  paste0(
    "s", format(Sys.time(), "%Y%m%d%H%M%S"), "-", 
    paste0(sample(c(letters, 0:9), 6, replace = TRUE), collapse = "")
  )
}

#' Create logging directory if it doesn't exist
#' @param log_dir Path to logging directory
#' @return TRUE if successful, FALSE otherwise
create_log_directory <- function(log_dir) {
  if (!dir.exists(log_dir)) {
    tryCatch({
      dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)
      return(file.exists(log_dir))
    }, error = function(e) {
      message(sprintf("[LOGGING] Error creating log directory: %s", e$message))
      return(FALSE)
    })
  }
  return(TRUE)
}

#' Create a log file with session ID
#' @param log_dir Path to logging directory
#' @param session_id Unique session identifier
#' @return Path to created log file or NULL on failure
create_log_file <- function(log_dir, session_id) {
  if (!dir.exists(log_dir)) {
    if (!create_log_directory(log_dir)) {
      return(NULL)
    }
  }
  
  # Generate filename with timestamp and session ID
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  filename <- paste0("jheem_", timestamp, "_", session_id, ".log")
  log_file <- file.path(log_dir, filename)
  
  # Write header to log file
  tryCatch({
    cat(paste0(
      "=== JHEEM Application Log ===\n",
      "Session: ", session_id, "\n",
      "Started: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n",
      "Environment: ", Sys.getenv("R_CONFIG_ACTIVE", "development"), "\n",
      "Host: ", Sys.info()[["nodename"]], "\n",
      "R Version: ", R.version$version.string, "\n",
      "==========================\n\n"
    ), file = log_file, append = FALSE)
    
    return(log_file)
  }, error = function(e) {
    message(sprintf("[LOGGING] Error creating log file: %s", e$message))
    return(NULL)
  })
}

#' Set up console redirection to log file
#' @param log_file Path to log file
#' @param capture_messages Whether to capture messages/warnings
#' @return List with connection objects or NULL on failure
setup_output_redirection <- function(log_file, capture_messages = TRUE) {
  if (!file.exists(log_file)) {
    message("[LOGGING] Log file does not exist, cannot redirect output")
    return(NULL)
  }
  
  tryCatch({
    # Open connection to log file
    log_conn <- file(log_file, open = "a")
    
    # Redirect console output, keeping it visible in console too
    sink(log_conn, type = "output", split = TRUE)
    
    # Optionally redirect messages/warnings
    if (capture_messages) {
      # For messages, we can't use split, so it won't show in console
      sink(log_conn, type = "message")
    }
    
    # Return connection objects
    list(
      output_conn = log_conn,
      message_conn = if (capture_messages) log_conn else NULL
    )
  }, error = function(e) {
    message(sprintf("[LOGGING] Error setting up output redirection: %s", e$message))
    return(NULL)
  })
}

#' Clean up existing logging setup
#' @return TRUE if cleanup was needed, FALSE otherwise
cleanup_logging <- function() {
  needs_cleanup <- FALSE
  
  # Check if global logging context exists
  if (exists("JHEEM_LOGGING", envir = .GlobalEnv)) {
    needs_cleanup <- TRUE
    logging_ctx <- get("JHEEM_LOGGING", envir = .GlobalEnv)
    
    # Log cleanup message
    if (!is.null(logging_ctx$log_file) && file.exists(logging_ctx$log_file)) {
      cat(sprintf("\n[%s] [INFO] Cleaning up previous logging session\n", 
                format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
          file = logging_ctx$log_file, append = TRUE)
    }
    
    # Close connections and remove sinks
    if (!is.null(logging_ctx$connections)) {
      # Remove sinks
      tryCatch({
        sink(NULL, type = "output")
      }, error = function(e) {
        # Silent fail - sink might not be active
      })
      
      tryCatch({
        sink(NULL, type = "message")
      }, error = function(e) {
        # Silent fail - sink might not be active
      })
      
      # Close connections
      for (conn in logging_ctx$connections) {
        if (!is.null(conn) && isOpen(conn)) {
          tryCatch({
            close(conn)
          }, error = function(e) {
            # Silent fail - just try to close anything that might be open
          })
        }
      }
    }
  }
  
  # Clear global context
  if (exists("JHEEM_LOGGING", envir = .GlobalEnv)) {
    rm("JHEEM_LOGGING", envir = .GlobalEnv)
  }
  
  return(needs_cleanup)
}

#' Remove old log files to prevent disk space issues
#' @param log_dir Path to logs directory
#' @param max_days Maximum age in days to keep logs
#' @param max_files Maximum number of log files to keep
#' @return Number of files removed
cleanup_old_logs <- function(log_dir, max_days = 30, max_files = 100) {
  if (!dir.exists(log_dir)) {
    return(0)
  }
  
  # Get all log files
  log_files <- list.files(
    path = log_dir, 
    pattern = "^jheem_.*\\.log$", 
    full.names = TRUE
  )
  
  if (length(log_files) == 0) {
    return(0)
  }
  
  # Get file info with modification time
  file_info <- file.info(log_files)
  file_info$path <- log_files
  
  # Sort by modification time (newest first)
  file_info <- file_info[order(file_info$mtime, decreasing = TRUE), ]
  
  # Calculate age in days
  file_info$age_days <- as.numeric(difftime(Sys.time(), file_info$mtime, units = "days"))
  
  # Determine which files to remove
  files_to_remove <- character(0)
  
  # First, identify files older than max_days
  old_files <- file_info[file_info$age_days > max_days, "path"]
  files_to_remove <- c(files_to_remove, old_files)
  
  # Then, if we still have too many files, remove oldest ones beyond max_files
  if (length(log_files) > max_files) {
    extra_files <- file_info$path[(max_files + 1):min(length(log_files), nrow(file_info))]
    files_to_remove <- c(files_to_remove, extra_files)
  }
  
  # Remove duplicates
  files_to_remove <- unique(files_to_remove)
  
  # Delete files
  removed_count <- 0
  for (file in files_to_remove) {
    tryCatch({
      unlink(file)
      removed_count <- removed_count + 1
    }, error = function(e) {
      # Just count successful removals
    })
  }
  
  return(removed_count)
}

#' Write a timestamped log message to the current log file
#' @param message Message to log
#' @param level Log level
#' @return TRUE if successful, FALSE otherwise
log_message <- function(message, level = "INFO") {
  if (!exists("JHEEM_LOGGING", envir = .GlobalEnv)) {
    # If logging isn't initialized, just print to console
    formatted_msg <- sprintf("[%s] %s", level, message)
    message(formatted_msg)
    return(FALSE)
  }
  
  logging_ctx <- get("JHEEM_LOGGING", envir = .GlobalEnv)
  
  # Format message with timestamp and level
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  formatted_msg <- sprintf("[%s] [%s] %s\n", timestamp, level, message)
  
  # If we have direct console output, we can write directly
  if (!is.null(logging_ctx$log_file) && file.exists(logging_ctx$log_file)) {
    tryCatch({
      cat(formatted_msg, file = logging_ctx$log_file, append = TRUE)
      return(TRUE)
    }, error = function(e) {
      # Fall back to console if we can't write to file
      message(formatted_msg)
      return(FALSE)
    })
  } else {
    # No log file, print to console
    message(formatted_msg)
    return(FALSE)
  }
}

# Convenience functions for different log levels
log_info <- function(message) log_message(message, "INFO")
log_warn <- function(message) log_message(message, "WARN")
log_error <- function(message) log_message(message, "ERROR")
log_debug <- function(message) log_message(message, "DEBUG")
