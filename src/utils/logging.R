# src/utils/logging.R
#
# Main logging module for JHEEM application
# This file serves as the public API for the logging system

# Load component modules
source("src/utils/logging/core.R")
source("src/utils/logging/init.R")
source("src/utils/logging/google_drive.R")

#' Initialize the logging system for JHEEM
#' @param token Legacy parameter (ignored, kept for compatibility)
#' @param tags Legacy parameter (ignored, kept for compatibility)
#' @param env Environment name
#' @param enabled Whether logging is enabled
#' @param upload_interval Seconds between Google Drive uploads
#' @param capture_messages Whether to capture message/warning output
#' @return Invisible NULL
initialize_logging <- function(
    token = Sys.getenv("LOGGLY_TOKEN", ""),
    tags = Sys.getenv("LOGGLY_TAGS", "r,shiny,jheem"),
    env = if(identical(Sys.getenv("R_CONFIG_ACTIVE"), "shinyapps")) "production" else "development",
    enabled = as.logical(Sys.getenv("ENABLE_LOGGING", "TRUE")),
    upload_interval = 60,
    capture_messages = TRUE,
    max_file_size = 5 * 1024 * 1024
) {
  # Try to load config from YAML
  config <- tryCatch({
    get_component_config("logging")
  }, error = function(e) {
    # Use default config
    list(
      enabled = enabled,
      log_dir = "logs",
      capture_messages = capture_messages,
      google_drive = list(
        enabled = TRUE,
        upload_interval_seconds = upload_interval,
        retention_days = 30,
        max_files = 100
      )
    )
  })
  
  # Override with function parameters
  config$enabled <- enabled
  config$capture_messages <- capture_messages
  config$google_drive$upload_interval_seconds <- upload_interval
  
  # Initialize core logging system
  logging_ctx <- initialize_logging_system(config)
  
  # Skip Google Drive integration if logging not enabled
  if (is.null(logging_ctx) || !logging_ctx$enabled) {
    return(invisible(NULL))
  }
  
  # Initialize Google Drive integration if enabled in config
  if (config$google_drive$enabled) {
    logging_ctx <- initialize_gdrive_logging(logging_ctx)
  }
  
  # Log successful initialization
  log_info(sprintf("JHEEM logging initialized - Session ID: %s", logging_ctx$session_id))
  log_info(sprintf("Environment: %s", env))
  
  if (logging_ctx$gdrive_enabled) {
    log_info(sprintf("Google Drive uploads enabled, interval: %d seconds", 
                  logging_ctx$gdrive$upload_interval))
  }
  
  # Write intro log
  log_info("=====================================================")
  log_info("JHEEM Application Started")
  log_info(sprintf("R Version: %s", R.version$version.string))
  log_info(sprintf("Platform: %s", R.version$platform))
  
  # Try to get package version
  pkg_version <- "unknown"
  tryCatch({
    pkg_version <- as.character(utils::packageVersion("jheem2"))
  }, error = function(e) {
    # Ignore error - package might not be loaded
  })
  log_info(sprintf("JHEEM Package Version: %s", pkg_version))
  log_info("=====================================================")
  
  invisible(NULL)
}

#' Write a message to the log
#' @param ... Message components to be concatenated
#' @param level Log level (INFO, WARN, ERROR, DEBUG)
#' @return Invisible TRUE if successful, FALSE otherwise
log <- function(..., level = "INFO") {
  message <- paste(..., collapse = " ")
  log_message(message, level)
}

#' Log an informational message
#' @param ... Message components
#' @return Result of log() call
info <- function(...) {
  log(..., level = "INFO")
}

#' Log a warning message
#' @param ... Message components
#' @return Result of log() call
warn <- function(...) {
  log(..., level = "WARN")
}

#' Log an error message
#' @param ... Message components
#' @return Result of log() call
error <- function(...) {
  log(..., level = "ERROR")
}

#' Log a debug message
#' @param ... Message components
#' @return Result of log() call
debug <- function(...) {
  log(..., level = "DEBUG")
}

#' Force log upload to Google Drive
#' @return TRUE if successful, FALSE otherwise
upload_logs_to_drive <- function() {
  force_upload_to_gdrive()
}

#' Get the current log file path
#' @return Path to current log file or NULL if logging not active
get_current_log_file <- function() {
  ctx <- get_logging_context()
  if (is.null(ctx) || !ctx$enabled) {
    return(NULL)
  }
  return(ctx$log_file)
}

#' Clean up and shut down logging
#' @return TRUE if shutdown occurred, FALSE otherwise
shutdown_logging <- function() {
  # Upload logs to Google Drive before shutting down
  tryCatch({
    force_upload_to_gdrive()
  }, error = function(e) {
    # Ignore errors during shutdown
  })
  
  # Perform shutdown
  return(shutdown_logging())
}

#' Get logging statistics
#' @return List with logging statistics
get_logging_stats <- function() {
  ctx <- get_logging_context()
  if (is.null(ctx)) {
    return(list(active = FALSE))
  }
  
  stats <- list(
    active = ctx$enabled,
    session_id = ctx$session_id,
    start_time = ctx$start_time,
    uptime_seconds = as.numeric(difftime(Sys.time(), ctx$start_time, units = "secs")),
    log_file = ctx$log_file,
    gdrive_enabled = ctx$gdrive_enabled
  )
  
  # Add Google Drive info if available
  if (ctx$gdrive_enabled) {
    stats$gdrive <- list(
      folder_name = ctx$gdrive$folder_name,
      folder_id = ctx$gdrive$folder_id,
      last_upload_time = ctx$gdrive$last_upload_time,
      last_upload_file = ctx$gdrive$last_upload_file,
      upload_interval = ctx$gdrive$upload_interval
    )
  }
  
  # Get log file size if available
  if (!is.null(ctx$log_file) && file.exists(ctx$log_file)) {
    file_info <- file.info(ctx$log_file)
    stats$log_file_size_bytes <- file_info$size
    stats$log_file_size_mb <- round(file_info$size / (1024 * 1024), 2)
  }
  
  return(stats)
}
