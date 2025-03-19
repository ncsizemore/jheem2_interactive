# UnifiedCacheManager.R
#
# A centralized cache management system that coordinates OneDrive cache and
# simulation cache operations to efficiently manage disk space and memory.

library(R6)
library(jsonlite)

# Null coalescing operator for default values
`%||%` <- function(x, y) if (is.null(x)) y else x

#' UnifiedCacheManager class
#'
#' Manages all caching operations for the JHEEM application, including:
#' - OneDrive file downloads
#' - Simulation results caching
#' - Disk space management
#' - Registry of cached files with metadata
#' - Retention policies based on memory pressure
#'
#' @export
UnifiedCacheManager <- R6::R6Class(
  "UnifiedCacheManager",
  public = list(
    #' Initialize the cache manager
    #' @param config Cache configuration from caching.yaml
    initialize = function(config) {
      print("[UCACHE] Starting UnifiedCacheManager initialization")
      print(sprintf("[UCACHE] Config type: %s, class: %s", typeof(config), paste(class(config), collapse=",")))
      
      # Default values if config is missing
      if (is.null(config)) {
        print("[UCACHE] Warning: Config is NULL, using default values")
        config <- list(
          unified_cache = list(
            base_path = "cache",
            max_disk_usage_mb = 1500,
            memory_threshold_mb = 6000,
            cleanup_interval_ms = 600000,
            emergency_threshold_mb = 100,
            retain_referenced = TRUE,
            retention_policy = list(
              critical = 86400, # 1 day
              high = 43200, # 12 hours
              normal = 7200, # 2 hours
              low = 1800 # 30 minutes
            )
          )
        )
      }

      # Store config for later use
      private$config <- config

      # Set up base paths
      private$base_path <- config$unified_cache$base_path %||% "cache"
      private$onedrive_path <- file.path(private$base_path, "onedrive")
      private$simulations_path <- file.path(private$base_path, "simulations")
      private$registry_path <- file.path(private$base_path, "registry.json")

      # Set up configuration
      private$max_disk_usage_mb <- config$unified_cache$max_disk_usage_mb %||% 1500
      private$memory_threshold_mb <- config$unified_cache$memory_threshold_mb %||% 6000
      private$emergency_threshold_mb <- config$unified_cache$emergency_threshold_mb %||% 100
      private$retain_referenced <- config$unified_cache$retain_referenced %||% TRUE

      # Initialize registry
      private$registry <- list(
        last_updated = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
        files = list(),
        stats = list(
          total_size_kb = 0,
          simulation_count = 0,
          onedrive_count = 0
        )
      )

      # Create directories
      tryCatch(
        {
          dir.create(private$base_path, recursive = TRUE, showWarnings = FALSE)
          dir.create(private$onedrive_path, recursive = TRUE, showWarnings = FALSE)
          dir.create(private$simulations_path, recursive = TRUE, showWarnings = FALSE)

          print(sprintf("[UCACHE] Initialized directories: %s", private$base_path))
          print(sprintf("[UCACHE] - OneDrive cache: %s", private$onedrive_path))
          print(sprintf("[UCACHE] - Simulations cache: %s", private$simulations_path))
        },
        error = function(e) {
          print(sprintf("[UCACHE] Error creating directories: %s", e$message))
        }
      )

      # Load registry if it exists
      private$load_registry()

      print("[UCACHE] UnifiedCacheManager initialized successfully")
    },

    # ---- PATH ACCESSOR METHODS ----

    #' Get the path to the OneDrive cache directory
    #' @return String path to the OneDrive cache directory
    get_onedrive_cache_path = function() {
      private$onedrive_path
    },

    #' Get the path to the simulations cache directory
    #' @return String path to the simulations cache directory
    get_simulations_cache_path = function() {
      private$simulations_path
    },

    # ---- FILE OPERATIONS ----

    #' Download a file from OneDrive
    #' @param sharing_link OneDrive sharing link
    #' @param filename Filename to use for the downloaded file
    #' @return Path to the downloaded file or NULL on failure
    download_file = function(sharing_link, filename) {
      # Defensive handling of sharing_link type
      if (is.list(sharing_link)) {
        print("[UCACHE] WARNING: sharing_link is a list, attempting to extract string value")
        # Try to extract sharing_link from the list
        if (!is.null(sharing_link$sharing_link)) {
          sharing_link <- sharing_link$sharing_link
          print(sprintf("[UCACHE] Extracted sharing_link: %s", sharing_link))
        } else {
          print("[UCACHE] Could not extract sharing_link from list")
          return(NULL)
        }
      }

      # Add debug info to see the types of arguments
      print(sprintf("[UCACHE] sharing_link type: %s, class: %s", typeof(sharing_link), paste(class(sharing_link), collapse=",")))
      print(sprintf("[UCACHE] sharing_link value: %s", sharing_link))
      print(sprintf("[UCACHE] filename type: %s, class: %s", typeof(filename), paste(class(filename), collapse=",")))
      print(sprintf("[UCACHE] filename value: %s", filename))
      
      print(sprintf("[UCACHE] Downloading OneDrive file: %s", filename))
      
      # Debug paths
      print(sprintf("[UCACHE] onedrive_path type: %s, value: %s", 
                   typeof(private$onedrive_path), private$onedrive_path))
      
      # Create file path
      tryCatch({
        print("[UCACHE] Creating file_path...")
        file_path <- file.path(private$onedrive_path, filename)
        print(sprintf("[UCACHE] file_path created: %s", file_path))
      }, error = function(e) {
        print(sprintf("[UCACHE] Error creating file_path: %s", e$message))
        return(NULL)
      })
      
      # Check if file exists and is in registry (recently accessed)
      tryCatch({
        print("[UCACHE] Checking if file exists...")
        if (file.exists(file_path)) {
          print("[UCACHE] File exists, checking registry...")
          
          print(sprintf("[UCACHE] registry type: %s", typeof(private$registry)))
          print(sprintf("[UCACHE] registry$files type: %s", 
                       if(is.null(private$registry$files)) "NULL" else typeof(private$registry$files)))
          
          if (!is.null(private$registry$files) && file_path %in% names(private$registry$files)) {
            print("[UCACHE] File found in registry, updating access time...")
            private$update_registry_access(file_path)
            private$save_registry()
            print(sprintf("[UCACHE] Using cached OneDrive file: %s", filename))
            return(file_path)
          } else {
            print("[UCACHE] File exists but not in registry")
          }
        } else {
          print("[UCACHE] File does not exist, will download")
        }
      }, error = function(e) {
        print(sprintf("[UCACHE] Error checking file existence: %s", e$message))
      })

      # Create file path
      file_path <- file.path(private$onedrive_path, filename)

      # Check if file exists and is in registry (recently accessed)
      if (file.exists(file_path)) {
        if (file_path %in% names(private$registry$files)) {
          # Update access time in registry
          private$update_registry_access(file_path)
          private$save_registry()
          print(sprintf("[UCACHE] Using cached OneDrive file: %s", filename))
          return(file_path)
        }
      }

      # Get file size estimate (assume 20MB if unknown)
      estimated_size_mb <- 20

      # Ensure we have space for the download
      if (!self$ensure_space_for(estimated_size_mb)) {
        print("[UCACHE] Not enough space for download")
        return(NULL)
      }

      # Download the file
      temp_file <- tempfile()
      download_success <- FALSE

      tryCatch({
        # Add download parameter to sharing link if needed
        if (!grepl("\\?download=1", sharing_link)) {
          if (grepl("\\?", sharing_link)) {
            sharing_link <- paste0(sharing_link, "&download=1")
          } else {
            sharing_link <- paste0(sharing_link, "?download=1")
          }
        }

        # Add a cache buster to avoid CDN caching
        sharing_link <- paste0(sharing_link, "&_cb=", as.integer(Sys.time()))

        # Download to temp file first
        print(sprintf("[UCACHE] Downloading from link: %s", sharing_link))
        utils::download.file(
          url = sharing_link,
          destfile = temp_file,
          mode = "wb", # Binary mode for cross-platform compatibility
          quiet = FALSE,
          method = "auto"
        )

        # Check if download was successful
        if (file.exists(temp_file) && file.info(temp_file)$size > 0) {
          # Move to final location
          file.copy(temp_file, file_path, overwrite = TRUE)
          download_success <- TRUE
          print(sprintf(
            "[UCACHE] Download successful: %s (%.2f MB)",
            filename, file.info(file_path)$size / 1e6
          ))
        } else {
          print("[UCACHE] Download failed: file empty or missing")
        }
      }, error = function(e) {
        print(sprintf("[UCACHE] Download error: %s", e$message))

        # Try fallback without download parameter
        print("[UCACHE] Trying fallback download without download parameter")

        # Remove download parameter and cache buster
        clean_link <- sub("\\?download=1.*$", "", sharing_link)
        clean_link <- sub("&download=1.*$", "", clean_link)

        tryCatch(
          {
            utils::download.file(
              url = clean_link,
              destfile = temp_file,
              mode = "wb",
              quiet = FALSE,
              method = "auto"
            )

            if (file.exists(temp_file) && file.info(temp_file)$size > 0) {
              # Move to final location
              file.copy(temp_file, file_path, overwrite = TRUE)
              download_success <- TRUE
              print(sprintf("[UCACHE] Fallback download successful: %s", filename))
            } else {
              print("[UCACHE] Fallback download failed: file empty or missing")
            }
          },
          error = function(e2) {
            print(sprintf("[UCACHE] Fallback download error: %s", e2$message))
          }
        )
      }, finally = {
        # Clean up temp file
        if (file.exists(temp_file)) {
          file.remove(temp_file)
        }
      })

      # If download was successful, add to registry
      if (download_success) {
        # Add to registry
        private$add_to_registry(
          file_path = file_path,
          type = "onedrive",
          priority = "normal",
          references = list(),
          metadata = list(
            sharing_link = sharing_link,
            original_filename = filename
          )
        )

        return(file_path)
      }

      return(NULL)
    },

    # ---- SIMULATION CACHE OPERATIONS ----

    #' Cache a simulation
    #' @param settings Simulation settings
    #' @param mode Simulation mode
    #' @param sim_state Simulation state to cache
    #' @return TRUE if caching was successful, FALSE otherwise
    cache_simulation = function(settings, mode, sim_state) {
      print(sprintf("[UCACHE] Caching simulation for mode: %s", mode))

      # Generate key for the simulation
      key <- private$generate_simulation_key(settings, mode)

      # Create file path
      file_path <- file.path(private$simulations_path, paste0(key, ".RData"))

      # Get file size estimate (if available from sim_state)
      estimated_size_mb <- 20 # Default if unknown

      # Ensure we have space
      if (!self$ensure_space_for(estimated_size_mb)) {
        print("[UCACHE] Not enough space for simulation")
        return(FALSE)
      }

      # Save simulation to file
      save_success <- FALSE
      tryCatch(
        {
          print(sprintf("[UCACHE] Saving simulation to %s", file_path))

          # Save main simulation file
          save(sim_state, file = file_path)

          # Also save metadata separately
          meta_path <- paste0(file_path, ".meta")

          # Create metadata
          metadata <- list(
            key = key,
            cached_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
            version = sim_state$cache_metadata$version %||% "unknown",
            mode = mode,
            settings = settings,
            saved_with = "unified_cache"
          )

          # Save metadata file
          saveRDS(metadata, meta_path)

          save_success <- TRUE
        },
        error = function(e) {
          print(sprintf("[UCACHE] Error saving simulation: %s", e$message))
          save_success <- FALSE
        }
      )

      # If save was successful, add to registry
      if (save_success) {
        # Find OneDrive file dependencies
        dependencies <- private$find_simulation_dependencies(sim_state)

        # Add to registry
        private$add_to_registry(
          file_path = file_path,
          type = "simulation",
          priority = "normal",
          references = dependencies,
          metadata = list(
            version = sim_state$cache_metadata$version %||% "unknown",
            location = sim_state$settings$location %||% "unknown",
            mode = mode
          )
        )

        return(TRUE)
      }

      return(FALSE)
    },

    #' Get a simulation from cache
    #' @param settings Simulation settings
    #' @param mode Simulation mode
    #' @return Simulation state or NULL if not found or error
    get_cached_simulation = function(settings, mode) {
      # Generate key
      key <- private$generate_simulation_key(settings, mode)

      # Create file path
      file_path <- file.path(private$simulations_path, paste0(key, ".RData"))

      # Check if file exists
      if (!file.exists(file_path)) {
        print(sprintf("[UCACHE] Simulation not found in cache: %s", key))
        return(NULL)
      }

      # Update access time in registry
      if (file_path %in% names(private$registry$files)) {
        private$update_registry_access(file_path)
        private$save_registry()
      } else {
        # File exists but not in registry, add it
        print(sprintf("[UCACHE] Found simulation file that's not in registry: %s", key))

        # Try to get metadata
        meta_path <- paste0(file_path, ".meta")
        metadata <- NULL
        if (file.exists(meta_path)) {
          tryCatch(
            {
              metadata <- readRDS(meta_path)
            },
            error = function(e) {
              print(sprintf("[UCACHE] Error reading metadata: %s", e$message))
            }
          )
        }

        # Add to registry
        private$add_to_registry(
          file_path = file_path,
          type = "simulation",
          priority = "normal",
          references = list(),
          metadata = if (!is.null(metadata)) {
            list(
              version = metadata$version %||% "unknown",
              location = if (!is.null(metadata$settings)) metadata$settings$location else "unknown",
              mode = metadata$mode %||% mode
            )
          } else {
            list(
              version = "unknown",
              location = "unknown",
              mode = mode
            )
          }
        )
      }

      # Load the simulation
      tryCatch(
        {
          # Load the simulation from the file
          env <- new.env()
          load(file_path, envir = env)

          # Find the simulation object in the environment
          var_names <- ls(env)

          if (length(var_names) == 0) {
            print("[UCACHE] No objects found in simulation file")
            return(NULL)
          }

          # Look for "sim_state" first, then fall back to first object
          sim_var <- if ("sim_state" %in% var_names) "sim_state" else var_names[1]
          sim_state <- get(sim_var, envir = env)

          # Add loaded_from_cache flag
          if (is.list(sim_state) && is.null(sim_state$cache_metadata)) {
            sim_state$cache_metadata <- list()
          }

          if (is.list(sim_state)) {
            sim_state$cache_metadata$loaded_from_cache <- TRUE
            sim_state$cache_metadata$load_time <- Sys.time()
          }

          print(sprintf("[UCACHE] Successfully loaded simulation: %s", key))
          return(sim_state)
        },
        error = function(e) {
          print(sprintf("[UCACHE] Error loading simulation: %s", e$message))
          return(NULL)
        }
      )
    },

    #' Check if a simulation exists in cache
    #' @param settings Simulation settings
    #' @param mode Simulation mode
    #' @return TRUE if simulation exists in cache, FALSE otherwise
    is_simulation_cached = function(settings, mode) {
      # Generate key
      key <- private$generate_simulation_key(settings, mode)

      # Create file path
      file_path <- file.path(private$simulations_path, paste0(key, ".RData"))

      # Check if file exists
      exists <- file.exists(file_path)

      if (exists) {
        print(sprintf("[UCACHE] Simulation exists in cache: %s", key))

        # Update access time if in registry
        if (file_path %in% names(private$registry$files)) {
          private$update_registry_access(file_path)
          private$save_registry()
        } else {
          print("[UCACHE] File exists but not in registry")

          # Try to add it to registry
          # Try to get metadata
          meta_path <- paste0(file_path, ".meta")
          metadata <- NULL
          if (file.exists(meta_path)) {
            tryCatch(
              {
                metadata <- readRDS(meta_path)
              },
              error = function(e) {
                print(sprintf("[UCACHE] Error reading metadata: %s", e$message))
              }
            )
          }

          # Add to registry
          private$add_to_registry(
            file_path = file_path,
            type = "simulation",
            priority = "normal",
            references = list(),
            metadata = if (!is.null(metadata)) {
              list(
                version = metadata$version %||% "unknown",
                location = if (!is.null(metadata$settings)) metadata$settings$location else "unknown",
                mode = metadata$mode %||% mode
              )
            } else {
              list(
                version = "unknown",
                location = "unknown",
                mode = mode
              )
            }
          )
        }
      } else {
        print(sprintf("[UCACHE] Simulation not found in cache: %s", key))
      }

      return(exists)
    },

    # ---- SPACE MANAGEMENT ----

    #' Clean up cache based on retention policy
    #' @param force If TRUE, remove all files regardless of references
    #' @param target_mb Target amount of space to free in MB
    #' @return TRUE if cleanup successful, FALSE otherwise
    cleanup = function(force = FALSE, target_mb = NULL) {
      print(sprintf("[UCACHE] Running cache cleanup (force: %s)", force))

      # Get current cache size
      current_size_mb <- private$get_cache_size() / 1024
      print(sprintf("[UCACHE] Current cache size: %.2f MB", current_size_mb))

      # If target_mb is specified, adjust it to be the amount we need to free
      if (!is.null(target_mb)) {
        # Calculate how much space we need to free
        free_mb <- private$max_disk_usage_mb - current_size_mb

        # If we already have enough space, no cleanup needed
        if (free_mb >= target_mb && !force) {
          print(sprintf(
            "[UCACHE] Already have enough space (%.2f MB free, need %.2f MB)",
            free_mb, target_mb
          ))
          return(TRUE)
        }

        # Adjust target to be the amount we need to free
        target_mb <- target_mb - free_mb
        if (target_mb <= 0) target_mb <- 1 # Ensure positive value
      }

      # Get list of referenced files
      referenced_files <- private$get_referenced_files()
      print(sprintf("[UCACHE] Found %d referenced files", length(referenced_files)))

      # Get retention times based on memory pressure
      retention_times <- private$get_retention_times()
      print("[UCACHE] Retention times (seconds):")
      print(sprintf("  - Critical: %d", retention_times$critical))
      print(sprintf("  - High: %d", retention_times$high))
      print(sprintf("  - Normal: %d", retention_times$normal))
      print(sprintf("  - Low: %d", retention_times$low))

      # Get current time
      current_time <- Sys.time()

      # Prepare lists for tracking
      to_remove <- list()
      kept <- list()
      errors <- list()

      # First pass - classify files for removal
      for (file_path in names(private$registry$files)) {
        # Skip if file doesn't exist
        if (!file.exists(file_path)) {
          to_remove[[file_path]] <- "File doesn't exist"
          next
        }

        # Get file info
        file_info <- private$registry$files[[file_path]]

        # Skip referenced files unless force is TRUE
        if (!force && file_path %in% referenced_files) {
          kept[[file_path]] <- "Referenced file"
          next
        }

        # Get last accessed time
        if (is.null(file_info$last_accessed)) {
          file_info$last_accessed <- format(file.info(file_path)$mtime, "%Y-%m-%d %H:%M:%S")
          private$registry$files[[file_path]]$last_accessed <- file_info$last_accessed
        }

        # Parse the last accessed time
        last_accessed <- as.POSIXct(file_info$last_accessed, format = "%Y-%m-%d %H:%M:%S")

        # Get age in seconds
        age <- as.numeric(difftime(current_time, last_accessed, units = "secs"))

        # Get retention time based on priority
        priority <- file_info$priority %||% "normal"
        retention_time <- retention_times[[priority]] %||% retention_times$normal

        # Check if file is older than retention time
        if (age > retention_time) {
          to_remove[[file_path]] <- sprintf(
            "Age %.2f hours > retention %.2f hours",
            age / 3600, retention_time / 3600
          )
        } else {
          kept[[file_path]] <- sprintf(
            "Age %.2f hours <= retention %.2f hours",
            age / 3600, retention_time / 3600
          )
        }
      }

      print(sprintf(
        "[UCACHE] Classified %d files for removal, %d to keep",
        length(to_remove), length(kept)
      ))

      # If we have a target, prioritize removals to meet the target
      removed_size_mb <- 0
      if (!is.null(target_mb) && length(to_remove) > 0) {
        # Sort files by priority (lowest first) and age (oldest first)
        files_by_priority <- list()

        for (file_path in names(to_remove)) {
          # Get file info
          file_info <- private$registry$files[[file_path]]
          priority <- file_info$priority %||% "normal"

          # Convert priority to numeric value
          priority_val <- switch(priority,
            "low" = 1,
            "normal" = 2,
            "high" = 3,
            "critical" = 4,
            2
          ) # Default to normal

          # Add to list by priority
          if (is.null(files_by_priority[[priority_val]])) {
            files_by_priority[[priority_val]] <- list()
          }

          files_by_priority[[priority_val]][[file_path]] <- file_info
        }

        # Clear to_remove list for rebuilding
        to_remove <- list()

        # Add files back to to_remove in priority order until we reach target
        for (priority_val in 1:4) {
          if (is.null(files_by_priority[[priority_val]])) next

          # Sort files by age within this priority
          files <- files_by_priority[[priority_val]]
          file_paths <- names(files)

          # Sort by last accessed time (oldest first)
          sorted_paths <- file_paths[order(sapply(file_paths, function(path) {
            file_info <- files[[path]]
            if (is.null(file_info$last_accessed)) {
              return(Sys.time())
            }
            as.POSIXct(file_info$last_accessed, format = "%Y-%m-%d %H:%M:%S")
          }))]

          # Add files until we reach target
          for (file_path in sorted_paths) {
            file_info <- files[[file_path]]
            file_size_mb <- (file_info$size_kb %||% 0) / 1024

            # Add to removal list
            priority_name <- switch(as.character(priority_val),
              "1" = "low",
              "2" = "normal",
              "3" = "high",
              "4" = "critical",
              "normal"
            )

            to_remove[[file_path]] <- sprintf(
              "Priority %s, size %.2f MB",
              priority_name, file_size_mb
            )

            # Update removed size
            removed_size_mb <- removed_size_mb + file_size_mb

            # Check if we've reached the target
            if (removed_size_mb >= target_mb) break
          }

          # Check if we've reached the target
          if (removed_size_mb >= target_mb) break
        }
      }

      # Second pass - actually remove files
      removed <- list()
      for (file_path in names(to_remove)) {
        tryCatch(
          {
            # Check if file exists to avoid errors
            if (file.exists(file_path)) {
              # Get file size for reporting
              file_size <- file.info(file_path)$size / 1024 / 1024 # MB

              # Remove the file
              file.remove(file_path)
              removed[[file_path]] <- sprintf(
                "Removed (%.2f MB): %s",
                file_size, to_remove[[file_path]]
              )

              # Also remove metadata file if it exists
              meta_path <- paste0(file_path, ".meta")
              if (file.exists(meta_path)) {
                file.remove(meta_path)
              }

              # Remove from registry
              private$registry$files[[file_path]] <- NULL
            } else {
              # File doesn't exist, just remove from registry
              private$registry$files[[file_path]] <- NULL
              removed[[file_path]] <- "Missing file removed from registry"
            }
          },
          error = function(e) {
            errors[[file_path]] <- sprintf("Error removing: %s", e$message)
          }
        )
      }

      # Update registry stats
      private$update_registry_stats()

      # Save registry
      private$save_registry()

      # Report results
      print(sprintf(
        "[UCACHE] Cleanup complete: %d removed, %d kept, %d errors",
        length(removed), length(kept), length(errors)
      ))

      return(length(errors) == 0)
    },

    #' Schedule periodic cleanup
    #' @param interval_ms Interval in milliseconds between cleanups
    schedule_cleanup = function(interval_ms = 600000) {
      # Placeholder for app.R to call
      print(sprintf("[UCACHE] Cleanup scheduled for every %d ms", interval_ms))
    },

    #' Ensure there is enough space for a new file
    #' @param required_mb Size in MB that needs to be available
    #' @return TRUE if space is available or was freed, FALSE otherwise
    ensure_space_for = function(required_mb) {
      # Get current disk usage
      current_usage_mb <- private$get_cache_size() / 1024
      print(sprintf("[UCACHE] Current disk usage: %.2f MB", current_usage_mb))

      # Check if we have enough space
      free_mb <- private$max_disk_usage_mb - current_usage_mb
      print(sprintf("[UCACHE] Free space: %.2f MB", free_mb))

      # If we have enough space, return TRUE
      if (free_mb >= required_mb) {
        print(sprintf("[UCACHE] Already have enough space (need %.2f MB)", required_mb))
        return(TRUE)
      }

      # Otherwise, run cleanup to free space
      space_needed_mb <- required_mb - free_mb
      print(sprintf("[UCACHE] Need to free %.2f MB", space_needed_mb))

      # Run normal cleanup first
      self$cleanup(force = FALSE, target_mb = required_mb)

      # Check if we have enough space now
      current_usage_mb <- private$get_cache_size() / 1024
      free_mb <- private$max_disk_usage_mb - current_usage_mb

      # If still not enough, use emergency cleanup
      if (free_mb < required_mb) {
        print("[UCACHE] Emergency cleanup needed")
        self$cleanup(force = TRUE, target_mb = required_mb)

        # Check again
        current_usage_mb <- private$get_cache_size() / 1024
        free_mb <- private$max_disk_usage_mb - current_usage_mb
      }

      # Return result
      result <- free_mb >= required_mb
      if (result) {
        print("[UCACHE] Successfully freed enough space")
      } else {
        print(sprintf("[UCACHE] Failed to free enough space. Only %.2f MB available", free_mb))
      }

      return(result)
    },

    #' Get cache statistics
    #' @return List with cache statistics
    get_stats = function() {
      # Update registry stats first
      private$update_registry_stats()

      # Get current cache size
      current_size_kb <- private$get_cache_size()
      current_size_mb <- current_size_kb / 1024

      # Get memory info
      mem_info <- private$get_memory_info()

      # Return stats
      return(list(
        cache_files = list(
          total_count = length(names(private$registry$files)),
          simulation_count = private$registry$stats$simulation_count,
          onedrive_count = private$registry$stats$onedrive_count
        ),
        cache_space = list(
          total_size_mb = current_size_mb,
          max_size_mb = private$max_disk_usage_mb,
          free_mb = private$max_disk_usage_mb - current_size_mb,
          usage_percent = (current_size_mb / private$max_disk_usage_mb) * 100
        ),
        system_memory = mem_info,
        last_updated = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
      ))
    }
  ),
  private = list(
    # ---- CORE PROPERTIES ----

    # Core properties
    config = NULL,
    base_path = NULL,
    onedrive_path = NULL,
    simulations_path = NULL,
    registry_path = NULL,

    # Configuration
    max_disk_usage_mb = NULL,
    memory_threshold_mb = NULL,
    emergency_threshold_mb = NULL,
    retain_referenced = NULL,

    # Registry
    registry = NULL,

    #' Load the registry from disk or initialize if not found
    load_registry = function() {
      if (file.exists(private$registry_path)) {
        tryCatch(
          {
            private$registry <- jsonlite::read_json(private$registry_path)
            print(sprintf(
              "[UCACHE] Loaded existing registry with %d files",
              length(names(private$registry$files))
            ))

            # Validate and update registry stats
            private$update_registry_stats()
          },
          error = function(e) {
            print(sprintf("[UCACHE] Error loading registry: %s", e$message))
            print("[UCACHE] Initializing new registry")

            # Initialize a new registry
            private$registry <- list(
              last_updated = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
              files = list(),
              stats = list(
                total_size_kb = 0,
                simulation_count = 0,
                onedrive_count = 0
              )
            )
          }
        )
      } else {
        print("[UCACHE] Registry file not found, initializing new registry")

        # Initialize a new registry
        private$registry <- list(
          last_updated = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
          files = list(),
          stats = list(
            total_size_kb = 0,
            simulation_count = 0,
            onedrive_count = 0
          )
        )

        # Save the new registry
        private$save_registry()
      }
    },

    #' Save the registry to disk
    save_registry = function() {
      # Update last_updated timestamp
      private$registry$last_updated <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

      # Create backup of existing registry
      if (file.exists(private$registry_path)) {
        backup_path <- paste0(private$registry_path, ".bak")
        file.copy(private$registry_path, backup_path, overwrite = TRUE)
      }

      # Save registry as JSON
      tryCatch(
        {
          jsonlite::write_json(private$registry, private$registry_path, pretty = TRUE, auto_unbox = TRUE)
          return(TRUE)
        },
        error = function(e) {
          print(sprintf("[UCACHE] Error saving registry: %s", e$message))
          return(FALSE)
        }
      )
    },

    #' Add a file to the registry
    #' @param file_path Path to the file
    #' @param type Type of file ("simulation" or "onedrive")
    #' @param priority Priority of the file ("critical", "high", "normal", "low")
    #' @param references List of paths to files that this file references
    #' @param metadata Additional metadata to store
    add_to_registry = function(file_path, type, priority = "normal", references = list(), metadata = list()) {
      # Check if file exists
      if (!file.exists(file_path)) {
        print(sprintf("[UCACHE] Cannot add non-existent file to registry: %s", file_path))
        return(FALSE)
      }

      # Get file size in KB
      size_kb <- file.info(file_path)$size / 1024

      # Create registry entry
      entry <- list(
        type = type,
        size_kb = size_kb,
        created = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
        last_accessed = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
        priority = priority,
        references = references,
        metadata = metadata
      )

      # Add to registry
      private$registry$files[[file_path]] <- entry

      # Update stats
      private$update_registry_stats()

      # Save registry
      private$save_registry()

      return(TRUE)
    },

    #' Update access time for a file in registry
    #' @param file_path Path to the file
    update_registry_access = function(file_path) {
      # Check if file is in registry
      if (file_path %in% names(private$registry$files)) {
        # Update access time
        private$registry$files[[file_path]]$last_accessed <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
        return(TRUE)
      }
      return(FALSE)
    },

    #' Find OneDrive files referenced by a simulation
    #' @param sim_state Simulation state
    #' @return List of file paths
    find_simulation_dependencies = function(sim_state) {
      dependencies <- list()

      # Check if simulation has OneDrive dependencies
      if (!is.null(sim_state) && !is.null(sim_state$results) && !is.null(sim_state$results$simset)) {
        # If simset has an 'original_file' property (common in OneDrive-loaded simsets)
        if (!is.null(sim_state$results$simset$original_file)) {
          onedrive_path <- file.path(private$onedrive_path, basename(sim_state$results$simset$original_file))
          if (file.exists(onedrive_path)) {
            dependencies <- c(dependencies, onedrive_path)
          }
        }

        # Check for cache_metadata with OneDrive references
        if (!is.null(sim_state$cache_metadata) && !is.null(sim_state$cache_metadata$onedrive_files)) {
          for (filename in sim_state$cache_metadata$onedrive_files) {
            onedrive_path <- file.path(private$onedrive_path, filename)
            if (file.exists(onedrive_path)) {
              dependencies <- c(dependencies, onedrive_path)
            }
          }
        }
      }

      return(unique(dependencies))
    },

    #' Get currently referenced files
    #' @return List of file paths
    get_referenced_files = function() {
      referenced_files <- list()

      # Get store instance (if available)
      store <- tryCatch(
        {
          get_store()
        },
        error = function(e) {
          NULL
        }
      )

      if (!is.null(store)) {
        # Try to get simulation stats
        stats <- tryCatch(
          {
            store$get_simulation_stats()
          },
          error = function(e) {
            NULL
          }
        )

        # Find currently referenced simulations
        if (!is.null(stats) && !is.null(stats$referenced_ids)) {
          for (id in stats$referenced_ids) {
            # Try to get the simulation
            sim_state <- tryCatch(
              {
                store$get_simulation(id)
              },
              error = function(e) {
                NULL
              }
            )

            if (!is.null(sim_state)) {
              # Get key from simulation settings
              key <- private$generate_simulation_key(sim_state$settings, sim_state$mode)
              sim_path <- file.path(private$simulations_path, paste0(key, ".RData"))

              # Add simulation and its dependencies
              if (file.exists(sim_path)) {
                referenced_files <- c(referenced_files, sim_path)

                # Add dependencies
                dependencies <- private$find_simulation_dependencies(sim_state)
                if (length(dependencies) > 0) {
                  referenced_files <- c(referenced_files, dependencies)
                }
              }
            }
          }
        }
      }

      # Return unique list
      return(unique(referenced_files))
    },

    #' Generate a cache key for a simulation
    #' @param settings Simulation settings
    #' @param mode Simulation mode
    #' @return String key
    generate_simulation_key = function(settings, mode) {
      # Make sure digest package is available
      if (!requireNamespace("digest", quietly = TRUE)) {
        stop("Package 'digest' is required for cache key generation")
      }

      print(sprintf("[UCACHE] Generating cache key for mode: %s", mode))

      # Create a safer copy of settings
      settings_copy <- settings
      if (is.list(settings_copy)) {
        # Remove any large data structures that aren't needed for the key
        settings_copy$data <- NULL
        settings_copy$results <- NULL
        settings_copy$parameters <- NULL

        # Normalize location code if present
        if (!is.null(settings_copy$location) && is.character(settings_copy$location)) {
          # Get normalize_location_code function if available
          normalize_fn <- tryCatch(
            {
              get("normalize_location_code", mode = "function")
            },
            error = function(e) {
              function(x) x # Fallback to identity function
            }
          )

          settings_copy$location <- normalize_fn(settings_copy$location)
        }
      }

      # Create a hash based on the settings and mode
      key_parts <- list(
        settings = settings_copy,
        mode = mode
      )

      # Create hash
      hash <- tryCatch(
        {
          digest::digest(key_parts, algo = "md5")
        },
        error = function(e) {
          # Fallback to simple hash
          digest::digest(paste0(mode, "_", Sys.time()), algo = "md5")
        }
      )

      # Create key in format: sim_[mode]_[hash]
      key <- paste0("sim_", mode, "_", hash)

      # Sanitize for file system storage
      key <- gsub("[^a-zA-Z0-9_-]", "_", key)

      return(key)
    },

    #' Calculate total size of the cache
    #' @return Size in KB
    get_cache_size = function() {
      total_size <- 0

      # Use registry if available
      if (!is.null(private$registry) && !is.null(private$registry$files)) {
        # Sum sizes from registry
        total_size <- sum(sapply(private$registry$files, function(info) {
          info$size_kb %||% 0
        }))
      } else {
        # Fallback: scan directories and sum file sizes
        tryCatch(
          {
            # Get all files in cache directories
            onedrive_files <- list.files(private$onedrive_path, full.names = TRUE, recursive = TRUE)
            simulation_files <- list.files(private$simulations_path, full.names = TRUE, recursive = TRUE)

            # Combine and get total size
            all_files <- c(onedrive_files, simulation_files)
            if (length(all_files) > 0) {
              # Get file sizes and sum
              total_size <- sum(file.info(all_files)$size, na.rm = TRUE) / 1024
            }
          },
          error = function(e) {
            print(sprintf("[UCACHE] Error calculating cache size: %s", e$message))
            # Return a reasonable default
            total_size <- 0
          }
        )
      }

      return(total_size)
    },

    #' Get retention times adjusted for memory pressure
    #' @return List of retention times
    get_retention_times = function() {
      # Get base retention policy from config
      retention_policy <- private$config$unified_cache$retention_policy %||% list(
        critical = 86400, # 1 day
        high = 43200, # 12 hours
        normal = 7200, # 2 hours
        low = 1800 # 30 minutes
      )

      # Check system memory pressure
      mem_info <- private$get_memory_info()
      mem_used_pct <- mem_info$used_percent

      print(sprintf("[UCACHE] Memory pressure: %.2f%%", mem_used_pct))

      # Adjust retention times based on memory pressure
      if (mem_used_pct > 90) {
        # Severe pressure: retain only critical files
        factor <- 0.1
        print("[UCACHE] SEVERE memory pressure - applying 90% reduction")
      } else if (mem_used_pct > 80) {
        # High pressure: reduce retention times significantly
        factor <- 0.25
        print("[UCACHE] HIGH memory pressure - applying 75% reduction")
      } else if (mem_used_pct > 70) {
        # Moderate pressure: reduce retention times moderately
        factor <- 0.5
        print("[UCACHE] MODERATE memory pressure - applying 50% reduction")
      } else {
        # Normal operation
        factor <- 1.0
        print("[UCACHE] NORMAL memory pressure - no reduction applied")
      }

      # Apply adjustment factor
      adjusted_policy <- list()
      for (priority in names(retention_policy)) {
        adjusted_policy[[priority]] <- retention_policy[[priority]] * factor
      }

      return(adjusted_policy)
    },

    #' Update registry statistics
    update_registry_stats = function() {
      # Initialize counters
      total_size_kb <- 0
      simulation_count <- 0
      onedrive_count <- 0

      # Process each file in registry
      if (!is.null(private$registry$files)) {
        for (file_path in names(private$registry$files)) {
          file_info <- private$registry$files[[file_path]]

          # Update size counter
          total_size_kb <- total_size_kb + (file_info$size_kb %||% 0)

          # Update file type counters
          if (!is.null(file_info$type)) {
            if (file_info$type == "simulation") {
              simulation_count <- simulation_count + 1
            } else if (file_info$type == "onedrive") {
              onedrive_count <- onedrive_count + 1
            }
          }
        }
      }

      # Update registry stats
      private$registry$stats <- list(
        total_size_kb = total_size_kb,
        simulation_count = simulation_count,
        onedrive_count = onedrive_count,
        last_updated = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
      )

      return(invisible(NULL))
    },

    #' Get system memory information
    #' @return List with memory stats
    get_memory_info = function() {
      tryCatch(
        {
          if (.Platform$OS.type == "windows") {
            # Windows memory check
            if (requireNamespace("utils", quietly = TRUE)) {
              mem_info <- system2("wmic", "OS get FreePhysicalMemory,TotalVisibleMemorySize /Value", stdout = TRUE)
              mem_info <- grep("=", mem_info, value = TRUE)

              total <- as.numeric(sub(".*=(.*)", "\\1", grep("TotalVisibleMemorySize", mem_info, value = TRUE))) / 1024
              free <- as.numeric(sub(".*=(.*)", "\\1", grep("FreePhysicalMemory", mem_info, value = TRUE))) / 1024

              used <- total - free
              used_percent <- used / total * 100
            } else {
              # Fallback if system2 isn't available
              return(list(
                total_mb = 8000, # Assume 8GB
                used_mb = 4000, # Assume 50% usage
                free_mb = 4000,
                used_percent = 50
              ))
            }
          } else {
            # Linux/Mac memory check
            if (Sys.info()["sysname"] == "Darwin") {
              # MacOS
              if (requireNamespace("utils", quietly = TRUE)) {
                mem_info <- system("vm_stat", intern = TRUE)

                # Parse page size
                page_size <- as.numeric(sub(".*page size of ([0-9]+) bytes.*", "\\1", grep("page size", mem_info, value = TRUE)))
                page_size_mb <- page_size / 1024 / 1024

                # Parse free pages
                free_pages <- as.numeric(sub(".*free: *([0-9]+).*", "\\1", grep("Pages free", mem_info, value = TRUE)))
                free <- free_pages * page_size_mb

                # Parse used pages (active + inactive + wired)
                active_pages <- as.numeric(sub(".*active: *([0-9]+).*", "\\1", grep("Pages active", mem_info, value = TRUE)))
                inactive_pages <- as.numeric(sub(".*inactive: *([0-9]+).*", "\\1", grep("Pages inactive", mem_info, value = TRUE)))
                wired_pages <- as.numeric(sub(".*wired down: *([0-9]+).*", "\\1", grep("Pages wired", mem_info, value = TRUE)))

                used <- (active_pages + inactive_pages + wired_pages) * page_size_mb
                total <- used + free
                used_percent <- used / total * 100
              } else {
                # Fallback
                return(list(
                  total_mb = 8000,
                  used_mb = 4000,
                  free_mb = 4000,
                  used_percent = 50
                ))
              }
            } else {
              # Linux
              if (requireNamespace("utils", quietly = TRUE)) {
                mem_info <- system("free -m", intern = TRUE)
                mem_line <- strsplit(mem_info[2], "\\s+")[[1]]
                total <- as.numeric(mem_line[2])
                used <- as.numeric(mem_line[3])
                free <- total - used
                used_percent <- used / total * 100
              } else {
                # Fallback
                return(list(
                  total_mb = 8000,
                  used_mb = 4000,
                  free_mb = 4000,
                  used_percent = 50
                ))
              }
            }
          }

          # Return memory info
          return(list(
            total_mb = total,
            used_mb = used,
            free_mb = free,
            used_percent = used_percent
          ))
        },
        error = function(e) {
          # Fallback if we can't get memory info
          print(sprintf("[UCACHE] Error getting memory info: %s", e$message))
          return(list(
            total_mb = 8000, # Assume 8GB
            used_mb = 4000, # Assume 50% usage
            free_mb = 4000,
            used_percent = 50
          ))
        }
      )
    }
  )
)
