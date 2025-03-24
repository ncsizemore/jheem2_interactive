# src/ui/components/common/downloads/download_manager.R

# Note: This download manager serves two purposes:
# 1. It acts as a fallback mechanism in case direct UI messaging isn't available or fails
# 2. It maintains architectural consistency with the StateStore pattern
# 
# In the future, when moving to async downloads or a different framework,
# this observer-based approach would replace the direct UI messaging.
#
# Current architecture uses a dual approach:
# - StateStore updates for maintaining application state (standard pattern)
# - Direct UI messaging via UIMessenger for real-time progress updates
#   when the main R thread is blocked during downloads
#
# Important: Previous attempts to use later::later() and Sys.sleep() to yield control
# back to the reactive system caused downloads to hang at 95%. Those approaches have
# been removed in favor of relying solely on direct UI messaging, which works reliably
# to show progress updates in real-time.

# Required packages
library(shiny)
library(later) # For scheduled callbacks

# store.R is already sourced in app.R, so we don't need to source it again
# Just use get_store() to access the existing StateStore instance
source("src/ui/components/common/errors/boundaries.R")

#' Create a download manager component
#' @param session Shiny session object
#' @param output Shiny output object
#' @param page_id Page identifier for error boundary
#' @return List of download management functions
create_download_manager <- function(session, output, page_id = "downloads") {
  # Get store instance
  store <- get_store()
  
  # Create a download manager-specific store access to avoid cross-contamination with plot panels
  access_store_safely <- function(fn) {
    tryCatch({
      fn(store)
    }, error = function(e) {
      print(sprintf("[DOWNLOAD_MANAGER] Error accessing store: %s", e$message))
      NULL
    })
  }
  
  # Create error boundary for download errors without state manager
  error_boundary <- create_error_boundary(session, output, page_id, "download", state_manager = NULL)
  
  # Container is now created in app.R
  print("[DOWNLOAD_MANAGER] Using container created in app.R")
  
  # Create a reactive value to track downloads that have been displayed
  displayed_downloads <- reactiveVal(list())
  
  # Create a reactive value to track download state changes
  download_state <- reactiveVal(list())
  
  # Initialize it from the StateStore
  download_state(access_store_safely(function(s) s$get_active_downloads()))
  
  # Create a reactive timer to check for download updates - longer interval for cleaner logs
  download_timer <- reactiveTimer(2000)  # Increased to 2000ms to reduce log noise
  
  # Counter for observer executions
  observer_count <- 0
  
  # Disabling the download state polling observer
  # 
  # REASON FOR DISABLING: 
  # This observer was creating unnecessary overhead without providing actual functionality.
  # The polling mechanism can't update the UI during active downloads (when the main thread is blocked),
  # which is precisely when updates are most needed. The UI Messenger component already
  # handles real-time updates by bypassing Shiny's reactive system, making this polling redundant.
  # The State Store is still updated through direct method calls (add_download, update_progress, etc.)
  # 
  # See README.md for more discussion on this topic.
  #
  # observe({
  #   # Increment observer counter
  #   observer_count <<- observer_count + 1
  #   
  #   # Get the current time for precise logging
  #   current_time <- format(Sys.time(), "%H:%M:%S.%OS3")
  #   # Reduced logging - only show every 10th execution
  #   if (observer_count %% 10 == 0) {
  #     print(sprintf("[DOWNLOAD_MANAGER %s] State observer #%d running", current_time, observer_count))
  #   }
  #   
  #   # Trigger the timer to force re-evaluation
  #   download_timer()
  #   
  #   # Get active downloads safely with detailed logging
  #   active_downloads <- NULL
  #   tryCatch({
  #     # Silenced this log to reduce noise
  #     # print(sprintf("[DOWNLOAD_MANAGER %s] Accessing StateStore to get active downloads", current_time))
  #     active_downloads <- access_store_safely(function(s) s$get_active_downloads())
  #     # Only log if there are active downloads to reduce noise
  #     if (!is.null(active_downloads) && length(active_downloads) > 0) {
  #       print(sprintf("[DOWNLOAD_MANAGER %s] Got active downloads: %d downloads", 
  #                     current_time, length(active_downloads)))
  #     }
  #   }, error = function(e) {
  #     print(sprintf("[DOWNLOAD_MANAGER %s] ERROR accessing StateStore: %s", current_time, e$message))
  #   })
  #   
  #   # Log current state vs new state
  #   current_state <- download_state()
  #   # Skip these logs to reduce noise
  #   if (!is.null(active_downloads) && length(active_downloads) > 0) {
  #     print(sprintf("[DOWNLOAD_MANAGER %s] Current state has %s downloads", 
  #                current_time,
  #                if(is.null(current_state)) "0" else length(current_state)))
  #     print(sprintf("[DOWNLOAD_MANAGER %s] New state has %s downloads", 
  #                current_time,
  #                length(active_downloads)))
  #   }
  #   
  #   # Check if states are identical
  #   is_identical <- identical(active_downloads, current_state)
  #   # Only log if there are active downloads
  #   if (!is.null(active_downloads) && length(active_downloads) > 0) {
  #     print(sprintf("[DOWNLOAD_MANAGER %s] States are identical: %s", current_time, is_identical))
  #   }
  #   
  #   # FIX: ALWAYS update the reactive value, even if unchanged
  #   # This ensures downstream observers will ALWAYS be triggered
  #   # Only log updates when there are active downloads
  #   if (!is.null(active_downloads) && length(active_downloads) > 0) {
  #     print(sprintf("[DOWNLOAD_MANAGER %s] ALWAYS updating reactive value to maintain reactivity chain", current_time))
  #   }
  #   download_state(active_downloads)
  # })
  
  # Register UI updates based on reactive download state with enhanced logging
  observe({
    # Get the current time for precise logging
    current_time <- format(Sys.time(), "%H:%M:%S.%OS3")
    
    # Get the current active downloads from our reactive value
    active_downloads <- download_state()
    
    # Only log when there are active downloads to reduce noise
    if (!is.null(active_downloads) && length(active_downloads) > 0) {
      print(sprintf("[DOWNLOAD_MANAGER %s] UI observer running, found %d active downloads", 
                   current_time,
                   length(active_downloads)))
      
      print(sprintf("[DOWNLOAD_MANAGER %s] Active downloads detected!", current_time))
      for (id in names(active_downloads)) {
        download <- active_downloads[[id]]
        print(sprintf("[DOWNLOAD_MANAGER %s] Download ID: %s, Filename: %s, Progress: %d%%", 
                     current_time, id, download$filename, download$percent))
      }
    }
    
    # Only update UI if there are active downloads
    if (!is.null(active_downloads) && length(active_downloads) > 0) {
      # Get currently displayed downloads
      current_displayed <- displayed_downloads()
      
      print(sprintf("[DOWNLOAD_MANAGER %s] Currently tracking %d displayed downloads", 
                   current_time, length(current_displayed)))
      
      # Create updates for each active download
      for (id in names(active_downloads)) {
        download <- active_downloads[[id]]
        
        # Check if this is a new download that hasn't been displayed yet
        if (!id %in% names(current_displayed)) {
          # Send initial 'start' message to create UI element
          print(sprintf("[DOWNLOAD_MANAGER %s] Sending initial start message for new download: %s", 
                       current_time, id))
          print(sprintf("[DOWNLOAD_MANAGER %s] Download data: ID=%s, Filename=%s", 
                       current_time, id, download$filename))
          
          # Add trace ID to improve debugging
          trace_id <- paste0("dm-trace-", format(Sys.time(), "%H%M%S"), "-", sample.int(1000, 1))
          
          start_data <- list(
            id = id,
            filename = download$filename,
            trace_id = trace_id,
            timestamp = current_time
          )
          print(sprintf("[DOWNLOAD_MANAGER %s] Start data: %s", 
                       current_time, paste(names(start_data), collapse=",")))
          
          tryCatch({
            print(sprintf("[DOWNLOAD_MANAGER %s] Sending download_progress_start message", current_time))
            session$sendCustomMessage("download_progress_start", start_data)
            print(sprintf("[DOWNLOAD_MANAGER %s] Sent 'download_progress_start' message", current_time))
          }, error = function(e) {
            print(sprintf("[DOWNLOAD_MANAGER %s] ERROR sending start message: %s", current_time, e$message))
          })
          
          # Also send via the combined channel for compatibility
          tryCatch({
            print(sprintf("[DOWNLOAD_MANAGER %s] Sending download_progress_update with action='start'", current_time))
            session$sendCustomMessage("download_progress_update", list(
              action = "start",
              id = id,
              filename = download$filename,
              trace_id = trace_id,
              timestamp = current_time
            ))
            print(sprintf("[DOWNLOAD_MANAGER %s] Sent 'download_progress_update' with action='start'", current_time))
          }, error = function(e) {
            print(sprintf("[DOWNLOAD_MANAGER %s] ERROR sending combined start message: %s", current_time, e$message))
          })
          
          # Add to displayed downloads tracking
          current_displayed[[id]] <- TRUE
          displayed_downloads(current_displayed)
          print(sprintf("[DOWNLOAD_MANAGER %s] Added download %s to displayed_downloads tracking", current_time, id))
        }
        
        # Send regular progress update
        print(sprintf("[DOWNLOAD_MANAGER %s] Sending update for download %s: %d%%", 
                     current_time, id, download$percent))
                     
        tryCatch({
          session$sendCustomMessage("download_progress_update", list(
            action = "update",
            id = id,
            filename = download$filename,
            percent = download$percent,
            time = format(download$last_updated, "%H:%M:%S"),
            trace_id = paste0("dm-update-", format(Sys.time(), "%H%M%S")),
            timestamp = current_time
          ))
          print(sprintf("[DOWNLOAD_MANAGER %s] Successfully sent progress update message", current_time))
        }, error = function(e) {
          print(sprintf("[DOWNLOAD_MANAGER %s] ERROR sending progress update: %s", current_time, e$message))
        })
      }
    }
  })
  
  # Register download completion observer
  observe({
    # Trigger the timer to force re-evaluation
    download_timer()
    
    # Get recently completed downloads safely
    completed_downloads <- access_store_safely(function(s) s$get_completed_downloads())
    
    # Check for newly completed downloads
    if (!is.null(completed_downloads)) {
      # Get tracking list
      current_displayed <- displayed_downloads()
      
      for (id in names(completed_downloads)) {
        download <- completed_downloads[[id]]
        
        # Only process downloads completed in last 5 seconds
        if (!is.null(download$completion_time)) {
          time_diff <- difftime(Sys.time(), download$completion_time, units = "secs")
          if (time_diff < 5) {
            # Send completion messages (both types for compatibility)
            session$sendCustomMessage("download_progress_update", list(
              action = "complete",
              id = id,
              filename = download$filename
            ))
            # Also send via dedicated channel
            session$sendCustomMessage("download_progress_complete", list(
              id = id,
              filename = download$filename
            ))
            
            # Remove from displayed downloads tracking
            current_displayed[[id]] <- NULL
          }
        }
      }
      
      # Update tracking list
      displayed_downloads(current_displayed)
    }
  })
  
  # Register download failure observer
  observe({
    # Trigger the timer to force re-evaluation
    download_timer()
    
    # Get recently failed downloads safely
    failed_downloads <- access_store_safely(function(s) s$get_failed_downloads())
    
    # Check for newly failed downloads
    if (!is.null(failed_downloads)) {
      # Get tracking list
      current_displayed <- displayed_downloads()
      
      for (id in names(failed_downloads)) {
        download <- failed_downloads[[id]]
        
        # Only process downloads failed in last 5 seconds
        if (!is.null(download$failure_time)) {
          time_diff <- difftime(Sys.time(), download$failure_time, units = "secs")
          if (time_diff < 5) {
            # Send failure message (both types for compatibility)
            session$sendCustomMessage("download_progress_update", list(
              action = "error",
              id = id,
              filename = download$filename,
              message = download$error_message
            ))
            # Also send via dedicated channel
            session$sendCustomMessage("download_progress_error", list(
              id = id,
              filename = download$filename,
              message = download$error_message
            ))
            
            # Set error in boundary
            error_boundary$set_error(
              message = download$error_message,
              type = download$error_type %||% ERROR_TYPES$DOWNLOAD,
              severity = download$error_severity %||% SEVERITY_LEVELS$ERROR
            )
            
            # Remove from displayed downloads tracking
            current_displayed[[id]] <- NULL
          }
        }
      }
      
      # Update tracking list
      displayed_downloads(current_displayed)
    }
  })
  
  # Schedule automatic cleanup of completed/failed downloads
  observe({
    invalidateLater(60000) # Run every minute
    access_store_safely(function(s) s$clear_completed_downloads(10)) # Keep 10 most recent completed downloads
    access_store_safely(function(s) s$clear_failed_downloads(10)) # Keep 10 most recent failed downloads
  })
  
  # We'll add a test button observer later
  
  # Create and return the download manager interface
  download_manager <- list(
    # This version will explicitly send a message - for debugging
    start_download = function(id, filename, total_size = NULL) {
      print(sprintf("[DOWNLOAD_MANAGER] Explicitly starting download: %s - %s", id, filename))
      
      # Add to store safely
      access_store_safely(function(s) s$add_download(id, filename, total_size))
      
      # Send UI update (both types for compatibility)
      session$sendCustomMessage("download_progress_update", list(
        action = "start",
        id = id,
        filename = filename
      ))
      print("[DOWNLOAD_MANAGER] Sent 'download_progress_update' with action 'start'")
      
      # Also send via dedicated channel
      session$sendCustomMessage("download_progress_start", list(
        id = id,
        filename = filename
      ))
      print("[DOWNLOAD_MANAGER] Sent 'download_progress_start' message")
      
      invisible(NULL)
    },
    
    # Update download progress
    update_progress = function(id, percent) {
      access_store_safely(function(s) s$update_download_progress(id, percent))
      invisible(NULL)
    },
    
    # Complete a download
    complete_download = function(id) {
      access_store_safely(function(s) s$complete_download(id))
      invisible(NULL)
    },
    
    # Mark a download as failed
    fail_download = function(id, message, type = ERROR_TYPES$DOWNLOAD, severity = SEVERITY_LEVELS$ERROR) {
      access_store_safely(function(s) s$fail_download(id, message, type, severity))
      invisible(NULL)
    },
    

    
    # Get the error boundary
    get_error_boundary = function() {
      error_boundary
    }
  )
  
  download_manager
}
