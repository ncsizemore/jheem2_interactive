# src/utils/logging/init.R
#
# Initialization module for JHEEM logging system

# Source required modules
source("src/utils/logging/core.R")

#' Initialize the logging system
#' @param config Optional configuration override
#' @return Logging context (invisible)
initialize_logging_system <- function(config = NULL) {
  # Step 1: Try to load configuration
  if (is.null(config)) {
    tryCatch({
      config <- get_component_config("logging")
      message("[LOGGING] Loaded configuration from YAML")
    }, error = function(e) {
      message("[LOGGING] No configuration found, using defaults")
      # Default configuration
      config <- list(
        enabled = TRUE,
        log_dir = "logs",
        capture_messages = TRUE,
        max_file_size_mb = 10,
        max_files = 100,
        max_days = 30
      )
    })
  }
  
  # Step 2: Check if logging is enabled
  if (!is.null(config$enabled) && !config$enabled) {
    message("[LOGGING] Logging system disabled by configuration")
    return(invisible(NULL))
  }
  
  # Step 3: Clean up any existing logging
  was_active <- cleanup_logging()
  if (was_active) {
    message("[LOGGING] Cleaned up previous logging session")
  }
  
  # Step 4: Create session ID and set up basic context
  session_id <- generate_session_id()
  logging_ctx <- list(
    session_id = session_id,
    config = config,
    start_time = Sys.time(),
    enabled = TRUE
  )
  
  # Step 5: Set up log directory
  log_dir <- config$log_dir
  if (is.null(log_dir) || !nzchar(log_dir)) {
    log_dir <- "logs"
  }
  logging_ctx$log_dir <- log_dir
  
  # Step 6: Create log file
  log_file <- create_log_file(log_dir, session_id)
  if (is.null(log_file)) {
    message("[LOGGING] Failed to create log file, logging will be limited to console")
    logging_ctx$enabled <- FALSE
    assign("JHEEM_LOGGING", logging_ctx, envir = .GlobalEnv)
    return(invisible(logging_ctx))
  }
  logging_ctx$log_file <- log_file
  
  # Step 7: Set up console redirection
  capture_messages <- config$capture_messages
  if (is.null(capture_messages)) capture_messages <- TRUE
  
  connections <- setup_output_redirection(log_file, capture_messages)
  if (is.null(connections)) {
    message("[LOGGING] Failed to set up output redirection, logging will be limited")
    logging_ctx$connections <- list()
  } else {
    logging_ctx$connections <- connections
  }
  
  # Step 8: Clean up old log files
  max_days <- config$max_days %||% 30
  max_files <- config$max_files %||% 100
  removed_count <- cleanup_old_logs(log_dir, max_days, max_files)
  
  if (removed_count > 0) {
    log_message(sprintf("Cleaned up %d old log files", removed_count), "INFO")
  }
  
  # Step 9: Store logging context
  assign("JHEEM_LOGGING", logging_ctx, envir = .GlobalEnv)
  
  # Step 10: Log initialization message
  log_message(sprintf("Logging system initialized - Session ID: %s", session_id), "INFO")
  log_message(sprintf("Log file: %s", log_file), "INFO")
  
  # Return logging context
  invisible(logging_ctx)
}

#' Get current logging context
#' @return Logging context or NULL if logging not initialized
get_logging_context <- function() {
  if (exists("JHEEM_LOGGING", envir = .GlobalEnv)) {
    get("JHEEM_LOGGING", envir = .GlobalEnv)
  } else {
    NULL
  }
}

#' Check if logging is initialized and enabled
#' @return TRUE if logging is active, FALSE otherwise
is_logging_active <- function() {
  ctx <- get_logging_context()
  return(!is.null(ctx) && ctx$enabled)
}

#' Shutdown logging system
#' @param log_message Whether to log shutdown message
#' @return TRUE if shutdown occurred, FALSE otherwise
shutdown_logging <- function(log_message = TRUE) {
  if (!is_logging_active()) {
    return(FALSE)
  }
  
  if (log_message) {
    log_info("Logging system shutting down")
  }
  
  cleanup_logging()
  return(TRUE)
}
