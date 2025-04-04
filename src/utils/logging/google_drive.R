# src/utils/logging/google_drive.R
#
# Google Drive integration for JHEEM logging system

# Default cache path for storing auth tokens
DEFAULT_GDRIVE_AUTH_CACHE_PATH <- file.path(tempdir(), "jheem_gdrive_auth")

#' Initialize Google Drive logging integration
#' @param logging_ctx Logging context
#' @return Updated logging context with Google Drive info
initialize_gdrive_logging <- function(logging_ctx) {
  # Check if googledrive package is available
  if (!requireNamespace("googledrive", quietly = TRUE)) {
    log_warn("googledrive package not available, Google Drive logging disabled")
    logging_ctx$gdrive_enabled <- FALSE
    return(logging_ctx)
  }
  
  # Check if Google Drive logging is enabled in config
  if (is.null(logging_ctx$config$google_drive) || 
      !isTRUE(logging_ctx$config$google_drive$enabled)) {
    log_info("Google Drive logging disabled in configuration")
    logging_ctx$gdrive_enabled <- FALSE
    return(logging_ctx)
  }
  
  # Extract Google Drive configuration
  gdrive_config <- logging_ctx$config$google_drive
  
  # Set up default values
  gdrive_settings <- list(
    enabled = TRUE,
    folder_name = gdrive_config$folder_name %||% "JHEEM Logs",
    upload_interval = gdrive_config$upload_interval_seconds %||% 300,
    retention_days = gdrive_config$retention_days %||% 30,
    max_files = gdrive_config$max_files %||% 100,
    auth_method = gdrive_config$auth_method %||% "auto"
  )
  
  # Add service account path if specified
  if (!is.null(gdrive_config$service_account_path)) {
    gdrive_settings$service_account_path <- gdrive_config$service_account_path
    gdrive_settings$auth_method <- "service_account"
  }
  
  # Store settings
  logging_ctx$gdrive <- gdrive_settings
  
  # Attempt authentication
  auth_result <- tryCatch({
    authenticate_with_google_drive(logging_ctx)
  }, error = function(e) {
    log_error(paste("Google Drive authentication failed:", e$message))
    FALSE
  })
  
  if (!auth_result) {
    log_warn("Google Drive integration disabled due to authentication failure")
    logging_ctx$gdrive_enabled <- FALSE
    return(logging_ctx)
  }
  
  # Set up upload scheduling if later package available
  if (requireNamespace("later", quietly = TRUE)) {
    schedule_gdrive_uploads(logging_ctx)
    log_info(sprintf("Scheduled Google Drive uploads every %d seconds", 
                   gdrive_settings$upload_interval))
  } else {
    log_warn("later package not available, scheduled Google Drive uploads disabled")
    # We'll still allow manual uploads
  }
  
  # Mark as enabled
  logging_ctx$gdrive_enabled <- TRUE
  return(logging_ctx)
}

#' Authenticate with Google Drive
#' @param logging_ctx Logging context
#' @return TRUE if authentication successful, FALSE otherwise
authenticate_with_google_drive <- function(logging_ctx) {
  log_info("Authenticating with Google Drive...")
  
  tryCatch({
    # Decide authentication method
    if (logging_ctx$gdrive$auth_method == "service_account" &&
        !is.null(logging_ctx$gdrive$service_account_path)) {
      
      # Service account authentication
      service_account_path <- logging_ctx$gdrive$service_account_path
      
      if (!file.exists(service_account_path)) {
        log_error(sprintf("Service account JSON file not found: %s", service_account_path))
        return(FALSE)
      }
      
      # Authenticate with service account
      googledrive::drive_auth(path = service_account_path)
      log_info("Authenticated with Google Drive using service account")
      
    } else {
      # Token-based authentication
      # This will use a cached token if available or prompt for authentication

      # Create auth cache dir if needed
      auth_cache <- DEFAULT_GDRIVE_AUTH_CACHE_PATH
      if (!dir.exists(auth_cache)) {
        dir.create(auth_cache, recursive = TRUE, showWarnings = FALSE)
      }
      
      # Use googledrive's caching system
      googledrive::drive_auth(cache = TRUE)
      log_info("Authenticated with Google Drive using token")
    }
    
    # Verify we're authenticated
    account_info <- googledrive::drive_user()
    log_info(sprintf("Google Drive authenticated as: %s", account_info$emailAddress))
    
    # Set up or find logging folder
    folder_id <- find_or_create_gdrive_folder(logging_ctx$gdrive$folder_name)
    if (is.null(folder_id)) {
      log_error("Failed to find or create Google Drive folder")
      return(FALSE)
    }
    
    # Store folder ID
    logging_ctx$gdrive$folder_id <- folder_id
    log_info(sprintf("Using Google Drive folder: %s (ID: %s)", 
                   logging_ctx$gdrive$folder_name, folder_id))
    
    # Update global context
    assign("JHEEM_LOGGING", logging_ctx, envir = .GlobalEnv)
    
    return(TRUE)
  }, error = function(e) {
    log_error(paste("Google Drive authentication error:", e$message))
    return(FALSE)
  })
}

#' Find or create a Google Drive folder
#' @param folder_name Name of the folder
#' @return Folder ID or NULL on failure
find_or_create_gdrive_folder <- function(folder_name) {
  tryCatch({
    # First, try to find the folder
    folder_query <- sprintf("name = '%s' and mimeType = 'application/vnd.google-apps.folder' and trashed = false", folder_name)
    existing_folders <- googledrive::drive_find(q = folder_query, n_max = 1)
    
    if (nrow(existing_folders) > 0) {
      # Found existing folder
      return(existing_folders$id[1])
    }
    
    # Folder not found, create it
    folder <- googledrive::drive_mkdir(folder_name)
    return(folder$id)
  }, error = function(e) {
    log_error(paste("Error finding/creating Google Drive folder:", e$message))
    return(NULL)
  })
}

#' Schedule periodic uploads to Google Drive
#' @param logging_ctx Logging context
#' @return TRUE if scheduled, FALSE otherwise
schedule_gdrive_uploads <- function(logging_ctx) {
  if (!requireNamespace("later", quietly = TRUE)) {
    return(FALSE)
  }
  
  # Get upload interval
  upload_interval <- logging_ctx$gdrive$upload_interval
  
  # Define the upload function that will be called repeatedly
  upload_function <- function() {
    # Get the most recent context
    current_ctx <- get("JHEEM_LOGGING", envir = .GlobalEnv)
    
    # Check if still enabled
    if (!current_ctx$gdrive_enabled) {
      log_info("Google Drive uploads have been disabled, stopping scheduler")
      return(FALSE)
    }
    
    # Upload log file
    result <- upload_current_log_to_gdrive(current_ctx)
    
    # Clean up old logs on Google Drive
    cleanup_old_gdrive_logs(current_ctx)
    
    # Schedule next upload
    later::later(upload_function, delay = upload_interval)
    
    return(TRUE)
  }
  
  # Store the function in context
  logging_ctx$gdrive$upload_function <- upload_function
  assign("JHEEM_LOGGING", logging_ctx, envir = .GlobalEnv)
  
  # Schedule first upload after a delay
  later::later(upload_function, delay = upload_interval)
  
  return(TRUE)
}

#' Upload current log file to Google Drive
#' @param logging_ctx Logging context
#' @return TRUE if successful, FALSE otherwise
upload_current_log_to_gdrive <- function(logging_ctx) {
  # Check that we have a log file to upload
  if (is.null(logging_ctx$log_file) || !file.exists(logging_ctx$log_file)) {
    log_warn("No log file available to upload to Google Drive")
    return(FALSE)
  }
  
  # Check that we have a folder ID
  if (is.null(logging_ctx$gdrive$folder_id)) {
    log_warn("No Google Drive folder ID available")
    return(FALSE)
  }
  
  # Generate a timestamped name for the log file
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  upload_name <- paste0(
    "jheem_log_", 
    logging_ctx$session_id, 
    "_", 
    timestamp, 
    ".log"
  )
  
  # Implement retry logic
  max_retries <- 3
  retry_count <- 0
  success <- FALSE
  last_error <- NULL
  
  while (!success && retry_count < max_retries) {
    tryCatch({
      # Upload file to Google Drive
      uploaded_file <- googledrive::drive_upload(
        media = logging_ctx$log_file,
        path = googledrive::as_id(logging_ctx$gdrive$folder_id),
        name = upload_name,
        type = "text/plain",
        overwrite = FALSE
      )
      
      # Update last upload time and file
      logging_ctx$gdrive$last_upload_time <- Sys.time()
      logging_ctx$gdrive$last_upload_file <- upload_name
      assign("JHEEM_LOGGING", logging_ctx, envir = .GlobalEnv)
      
      log_info(sprintf("Successfully uploaded log to Google Drive: %s", upload_name))
      success <- TRUE
      
    }, error = function(e) {
      retry_count <- retry_count + 1
      last_error <- e$message
      log_warn(sprintf("Google Drive upload attempt %d failed: %s", 
                     retry_count, e$message))
      
      # Wait with exponential backoff before retry
      if (retry_count < max_retries) {
        Sys.sleep(2^retry_count)
      }
    })
  }
  
  if (!success) {
    log_error(sprintf("Failed to upload log to Google Drive after %d attempts: %s",
                    max_retries, last_error))
  }
  
  return(success)
}

#' Clean up old log files on Google Drive
#' @param logging_ctx Logging context
#' @return Number of files deleted
cleanup_old_gdrive_logs <- function(logging_ctx) {
  if (!logging_ctx$gdrive_enabled || is.null(logging_ctx$gdrive$folder_id)) {
    return(0)
  }
  
  tryCatch({
    # Get retention settings
    retention_days <- logging_ctx$gdrive$retention_days
    max_files <- logging_ctx$gdrive$max_files
    
    # Query for log files in the folder
    folder_id <- logging_ctx$gdrive$folder_id
    query <- sprintf("'%s' in parents and mimeType = 'text/plain' and name contains 'jheem_log' and trashed = false", folder_id)
    log_files <- googledrive::drive_find(q = query, orderBy = "modifiedTime desc")
    
    if (nrow(log_files) == 0) {
      return(0)
    }
    
    # Determine which files to delete
    files_to_delete <- data.frame()
    
    # First, files older than retention_days
    if (!is.null(retention_days) && retention_days > 0) {
      cutoff_date <- Sys.time() - as.difftime(retention_days, units="days")
      old_files <- log_files[log_files$drive_modified < cutoff_date, ]
      files_to_delete <- rbind(files_to_delete, old_files)
    }
    
    # Then, files beyond max_files limit
    if (!is.null(max_files) && max_files > 0 && nrow(log_files) > max_files) {
      excess_files <- log_files[(max_files+1):nrow(log_files), ]
      files_to_delete <- rbind(files_to_delete, excess_files)
    }
    
    # Remove duplicates
    files_to_delete <- unique(files_to_delete)
    
    # Delete files
    deleted_count <- 0
    if (nrow(files_to_delete) > 0) {
      for (i in 1:nrow(files_to_delete)) {
        file_id <- files_to_delete$id[i]
        file_name <- files_to_delete$name[i]
        
        tryCatch({
          googledrive::drive_trash(googledrive::as_id(file_id))
          deleted_count <- deleted_count + 1
          log_debug(sprintf("Deleted old log file from Google Drive: %s", file_name))
        }, error = function(e) {
          log_warn(sprintf("Failed to delete Google Drive file %s: %s", 
                         file_name, e$message))
        })
      }
    }
    
    if (deleted_count > 0) {
      log_info(sprintf("Cleaned up %d old log files from Google Drive", deleted_count))
    }
    
    return(deleted_count)
  }, error = function(e) {
    log_error(sprintf("Error cleaning up Google Drive logs: %s", e$message))
    return(0)
  })
}

#' Manual function to force log upload to Google Drive
#' @return TRUE if successful, FALSE otherwise
force_upload_to_gdrive <- function() {
  if (!is_logging_active()) {
    message("Logging not active, cannot upload to Google Drive")
    return(FALSE)
  }
  
  logging_ctx <- get("JHEEM_LOGGING", envir = .GlobalEnv)
  
  if (!logging_ctx$gdrive_enabled) {
    log_warn("Google Drive integration not enabled")
    return(FALSE)
  }
  
  log_info("Manually initiating Google Drive upload")
  return(upload_current_log_to_gdrive(logging_ctx))
}
