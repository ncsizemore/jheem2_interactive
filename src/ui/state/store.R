# src/ui/state/store.R

library(R6)

# Source utilities for normalization functions
source("src/data/utils.R")

# Source comparison function
source("src/ui/state/compare_components.R")

#' State Store Class
#' @description Central state management for the application
StateStore <- R6Class("StateStore",
    public = list(
        #' @field panel_states List of ReactiveVal objects for each panel
        panel_states = NULL,

        #' @description Initialize the store
        #' @param page_ids Character vector of page identifiers
        initialize = function(page_ids = c("prerun", "custom")) {
            # Initialize base state
            private$state <- list()

            # Add model state
            private$state$model <- create_model_state()
            
            # Add download progress state
            private$state$downloads <- create_download_progress_state()

            # Setup other components
            private$setup_panel_states(page_ids)
            private$setup_simulation_storage()
            private$setup_page_error_states(page_ids)
        },

        #' @description Get the current model state
        #' @return List containing model state
        get_model_state = function() {
            private$state$model
        },

        #' @description Update model state
        #' @param status Character: new status
        #' @param error_message Character: new error message
        #' @return Invisible self (for chaining)
        update_model_state = function(status = NULL, error_message = NULL) {
            current <- private$state$model

            if (!is.null(status)) {
                current$status <- status
            }
            if (!is.null(error_message)) {
                current$error_message <- error_message
            }

            private$state$model <- validate_model_state(current)
            invisible(self)
        },

        # Panel State Methods ------------------------------------------------

        #' @description Get the current state for a panel
        #' @param page_id Character: panel identifier
        #' @return Current panel state
        get_panel_state = function(page_id) {
            if (is.null(self$panel_states[[page_id]])) {
                stop(sprintf("No state found for page: %s", page_id))
            }
            self$panel_states[[page_id]]()
        },

        #' @description Update visualization state for a panel
        #' @param page_id Character: panel identifier
        #' @param visibility Character: new visibility state
        #' @param plot_status Character: new plot status
        #' @param display_type Character: display type ("plot" or "table")
        #' @param error_message Character: new error message
        update_visualization_state = function(page_id,
                                              visibility = NULL,
                                              plot_status = NULL,
                                              display_type = NULL,
                                              error_message = NULL) {
            current_state <- self$get_panel_state(page_id)

            # Only update provided fields
            if (!is.null(visibility)) {
                current_state$visualization$visibility <- visibility
            }
            if (!is.null(plot_status)) {
                current_state$visualization$plot_status <- plot_status
            }
            if (!is.null(display_type)) {
                current_state$visualization$display_type <- display_type
            }
            if (!is.null(error_message)) {
                current_state$visualization$error_message <- error_message
            }

            # Validate and update
            current_state$visualization <- validate_visualization_state(
                current_state$visualization
            )
            self$panel_states[[page_id]](current_state)

            invisible(self)
        },

        #' @description Update control state for a panel
        #' @param page_id Character: panel identifier
        #' @param settings List: complete control settings
        update_control_state = function(page_id, settings) {
            if (is.null(settings)) {
                return()
            }

            current_state <- self$get_panel_state(page_id)

            # Update control state
            current_state$controls <- validate_control_state(settings)
            self$panel_states[[page_id]](current_state)

            invisible(self)
        },

        #' @description Update validation state for a panel
        #' @param page_id Character: panel identifier
        #' @param validation_state List: new validation state
        update_validation_state = function(page_id, validation_state) {
            current_state <- self$get_panel_state(page_id)

            # Update validation state
            current_state$validation <- validate_validation_state(validation_state)
            self$panel_states[[page_id]](current_state)

            invisible(self)
        },

        #' @description Get the current simulation's data for a page
        #' @param page_id Character: panel identifier
        #' @return List containing simset and transformed data
        get_current_simulation_data = function(page_id) {
            sim_id <- self$get_current_simulation_id(page_id)
            if (is.null(sim_id)) {
                stop("No current simulation set for page: ", page_id)
            }
            sim_state <- self$get_simulation(sim_id)
            sim_state$results
        },

        #' @description Get transformed data for current simulation
        #' @param page_id Character: panel identifier
        #' @param settings List: display settings (optional)
        #' @return List containing transformed data
        get_current_transformed_data = function(page_id, settings = NULL) {
            results <- self$get_current_simulation_data(page_id)

            # If settings changed or no transformed data exists, transform again
            if (is.null(results$transformed) ||
                (!is.null(settings) && !identical(settings, results$transformed$settings))) {
                print(sprintf("[STATE_STORE] Transforming data for simulation with new settings for page %s", page_id))
                results$transformed <- transform_simulation_data(results$simset, settings)

                # Update simulation state with new transformed data
                sim_id <- self$get_current_simulation_id(page_id)
                self$update_simulation(sim_id, list(
                    results = results
                ))
            }

            results$transformed
        },

        #' @description Reset state for a panel
        #' @param page_id Character: panel identifier
        reset_panel_state = function(page_id) {
            self$panel_states[[page_id]](create_panel_state(page_id))
            invisible(self)
        },

        # Simulation State Methods ------------------------------------------

        #' @description Add a new simulation to the store
        #' @param mode Character: simulation mode
        #' @param settings List: simulation settings
        #' @param results List: simulation results
        #' @return Character: simulation ID
        add_simulation = function(mode, settings, results) {
            id <- private$generate_simulation_id()
            print(paste0("[STATE_STORE] Creating new simulation with ID: ", id))

            # Create simulation state
            sim_state <- create_simulation_state(
                id = id,
                mode = mode,
                settings = settings,
                results = results
            )

            # Add cache metadata including version info
            sim_state$cache_metadata <- list(
                cached_at = Sys.time()
            )

            # If results contains a JHEEM simulation, record its metadata
            if (!is.null(results$simset) && inherits(results$simset, "jheem.simulation.set")) {
                print("[STATE_STORE] Adding JHEEM metadata for caching")
                simset <- results$simset

                # Store version if available
                if (!is.null(simset$version)) {
                    sim_state$cache_metadata$version <- simset$version
                }

                # Store any other useful metadata
                for (field in c("location", "code.iteration", "sub.version")) {
                    if (!is.null(simset[[field]])) {
                        sim_state$cache_metadata[[paste0("jheem_", field)]] <- simset[[field]]
                    }
                }
            } else {
                # Use configured version if available
                tryCatch(
                    {
                        cache_config <- get_component_config("caching")$simulation_cache
                        if (!is.null(cache_config$simulation_version)) {
                            sim_state$cache_metadata$version <- cache_config$simulation_version
                        }
                    },
                    error = function(e) {
                        # Default version if config not available
                        sim_state$cache_metadata$version <- "default"
                    }
                )
            }

            # Store in memory
            private$simulations[[id]] <- reactiveVal(sim_state)

            # Cache to disk if enabled with comprehensive error handling
            tryCatch(
                {
                    # First try to use unified cache manager
                    cache_manager <- tryCatch(
                        {
                            get_cache_manager()
                        },
                        error = function(e) {
                            print(sprintf("[STATE_STORE] UnifiedCacheManager not available: %s", e$message))
                            return(NULL)
                        }
                    )

                    # If we have a cache manager, use it
                    if (!is.null(cache_manager)) {
                        print("[STATE_STORE] Using UnifiedCacheManager for caching")

                        # Check if we have completed simulation results to cache
                        if (!is.null(sim_state$results) && !is.null(sim_state$results$simset)) {
                            print("[STATE_STORE] Simulation has results, proceeding with caching")
                            cache_manager$cache_simulation(settings, mode, sim_state)
                        } else {
                            print("[STATE_STORE] Simulation has no results yet, skipping cache")
                        }
                    } else {
                        # Fall back to old caching system
                        cache_config <- get_component_config("caching")$simulation_cache
                        print("[STATE_STORE DEBUG] Checking cache configuration for disk storage:")
                        print(sprintf("  - Cache config exists: %s", !is.null(cache_config)))

                        if (!is.null(cache_config)) {
                            print(sprintf(
                                "  - Disk cache enabled: %s",
                                !is.null(cache_config$enable_disk_cache) && cache_config$enable_disk_cache
                            ))
                            print(sprintf("  - Provider: %s", cache_config$provider %||% "<not specified>"))
                            print(sprintf("  - Path: %s", cache_config$path %||% "<not specified>"))
                        }

                        if (!is.null(cache_config) && !is.null(cache_config$enable_disk_cache) && cache_config$enable_disk_cache) {
                            print("[STATE_STORE] Caching simulation to disk")
                            # Use the cache module to store the simulation

                            # Check if we have completed simulation results to cache
                            if (!is.null(sim_state$results) && !is.null(sim_state$results$simset)) {
                                print("[STATE_STORE] Simulation has results, proceeding with caching")
                                cache_simulation(settings, mode, sim_state)
                            } else {
                                print("[STATE_STORE] Simulation has no results yet, skipping cache")
                            }
                        } else {
                            print("[STATE_STORE] Disk caching disabled in configuration")
                        }
                    }
                },
                error = function(e) {
                    print(sprintf("[STATE_STORE] Error caching to disk: %s", e$message))
                    # Continue without caching
                }
            )

            id
        },

        #' @description Get simulation by ID
        #' @param id Character: simulation identifier
        #' @return List: simulation state
        get_simulation = function(id) {
            if (is.null(private$simulations[[id]])) {
                stop(sprintf("No simulation found with ID: %s", id))
            }
            private$simulations[[id]]()
        },

        #' @description Update existing simulation
        #' @param id Character: simulation identifier
        #' @param updates List: fields to update
        update_simulation = function(id, updates) {
            if (is.null(private$simulations[[id]])) {
                stop(sprintf("No simulation found with ID: %s", id))
            }

            current_state <- private$simulations[[id]]()

            # Update provided fields
            print(sprintf(
                "[STATE_STORE] Updating simulation %s with status: %s",
                id, updates$status
            ))
            for (field in names(updates)) {
                current_state[[field]] <- updates[[field]]
            }

            # Validate and update
            current_state <- validate_simulation_state(current_state)
            private$simulations[[id]](current_state)

            invisible(self)
        },

        # Current Simulation Methods ---------------------------------------

        #' @description Find a simulation with matching settings
        #' @param settings List: simulation settings to match
        #' @param mode Character: simulation mode ("prerun" or "custom")
        #' @return Character: ID of matching simulation or NULL if no match found
        find_matching_simulation = function(settings, mode) {
            print(paste0("[STATE_STORE] Looking for matching simulation for mode: ", mode))
            print("[STATE_STORE DEBUG] Settings:")
            print(str(settings))

            # Step 1: Look through existing simulations in memory
            print("[STATE_STORE DEBUG] Step 1: Checking for matches in memory")
            sim_ids <- names(private$simulations)
            print(sprintf("[STATE_STORE DEBUG] Found %d simulations in memory", length(sim_ids)))

            for (id in sim_ids) {
                sim_state <- private$simulations[[id]]()

                # Only match simulations of the same mode
                if (sim_state$mode == mode) {
                    print(sprintf("[STATE_STORE DEBUG] Found simulation with matching mode: %s", id))
                    # Check if settings match
                    settings_match <- private$are_settings_equal(sim_state$settings, settings)
                    print(sprintf("[STATE_STORE DEBUG] Settings match: %s", settings_match))

                    if (settings_match) {
                        print(paste0("[STATE_STORE] Found matching simulation in memory with ID: ", id))
                        return(id)
                    }
                }
            }

            # Step 2: Check disk cache if enabled
            print("[STATE_STORE DEBUG] Step 2: Checking disk cache")

            # First try to use unified cache manager
            cache_manager <- tryCatch(
                {
                    get_cache_manager()
                },
                error = function(e) {
                    print(sprintf("[STATE_STORE] UnifiedCacheManager not available: %s", e$message))
                    return(NULL)
                }
            )

            if (!is.null(cache_manager)) {
                # Try to find a matching simulation using UnifiedCacheManager
                print("[STATE_STORE DEBUG] Using UnifiedCacheManager to check cache")

                # Get current Shiny session for progress updates
                current_session <- getDefaultReactiveDomain()

                if (cache_manager$is_simulation_cached(settings, mode)) {
                    print("[STATE_STORE] Found matching simulation in unified cache")

                    # Load from unified cache - get session for progress callback
                    shiny_session <- getDefaultReactiveDomain()
                    # Create progress callback
                    progress_callback <- NULL
                    if (!is.null(shiny_session)) {
                        # Create a unique ID for this operation
                        progress_id <- paste0("sim-", format(Sys.time(), "%Y%m%d%H%M%S"), "-", sample.int(10000, 1))

                        # Define callback function - used if any downloads are needed
                        progress_callback <- function(percent, file) {
                            # Pass progress updates to UI
                            shiny_session$sendCustomMessage("download_progress_update", list(
                                id = progress_id,
                                percent = percent,
                                filename = file
                            ))
                        }

                        # Initialize progress
                        shiny_session$sendCustomMessage("download_progress_start", list(
                            id = progress_id,
                            filename = paste0("Loading simulation for ", settings$location %||% "")
                        ))
                    }

                    # Call with progress callback
                    cached_sim <- tryCatch(
                        {
                            cache_manager$get_cached_simulation(settings, mode, progress_callback)
                        },
                        error = function(e) {
                            print(sprintf("[STATE_STORE] Error loading cached simulation: %s", e$message))

                            # Send error message to UI
                            if (!is.null(shiny_session)) {
                                shiny_session$sendCustomMessage("download_progress_error", list(
                                    id = progress_id,
                                    message = sprintf("Error loading simulation: %s", e$message)
                                ))
                            }

                            return(NULL)
                        }
                    )

                    if (!is.null(cached_sim)) {
                        # Create new simulation ID
                        id <- private$generate_simulation_id()

                        # Store in memory
                        private$simulations[[id]] <- reactiveVal(cached_sim)

                        print(paste0("[STATE_STORE] Loaded from unified cache as simulation ID: ", id))
                        return(id)
                    }
                }
            } else {
                # Fall back to original cache system
                tryCatch(
                    {
                        cache_config <- get_component_config("caching")$simulation_cache
                        print(sprintf(
                            "[STATE_STORE DEBUG] Cache enabled: %s",
                            !is.null(cache_config) && !is.null(cache_config$enable_disk_cache) &&
                                cache_config$enable_disk_cache
                        ))

                        if (!is.null(cache_config) && !is.null(cache_config$enable_disk_cache) && cache_config$enable_disk_cache) {
                            # Try to find a matching simulation in the disk cache
                            print("[STATE_STORE DEBUG] Calling is_simulation_cached()")

                            # Add debug info
                            debug_result <- debug_cache_key(settings, mode)
                            print("[STATE_STORE DEBUG] Debug cache key result:")
                            print(debug_result)

                            # Use the config path directly as fallback
                            cache_path <- cache_config$path
                            print(sprintf("[STATE_STORE DEBUG] Using cache path from config: '%s'", cache_path))

                            if (is_simulation_cached(settings, mode, explicit_cache_dir = cache_path)) {
                                print("[STATE_STORE] Found matching simulation in disk cache")

                                # Load from disk cache
                                print("[STATE_STORE DEBUG] Calling get_simulation_from_cache()")
                                cached_sim <- get_simulation_from_cache(settings, mode, explicit_cache_dir = cache_path)
                                print(sprintf("[STATE_STORE DEBUG] get_simulation_from_cache result: %s", !is.null(cached_sim)))

                                if (!is.null(cached_sim)) {
                                    # Create a new simulation ID for the loaded simulation
                                    id <- private$generate_simulation_id()
                                    print(sprintf("[STATE_STORE DEBUG] Generated new ID for cached sim: %s", id))

                                    # Handle both full simulation state or just JHEEM simulation object
                                    if (inherits(cached_sim, "jheem.simulation.set")) {
                                        # Got a direct JHEEM simulation object, wrap it in a simulation state
                                        print("[STATE_STORE DEBUG] Received direct JHEEM object, creating wrapper")

                                        # Try to load metadata
                                        meta_path <- file.path(
                                            cache_config$path,
                                            paste0(generate_simulation_cache_key(settings, mode), ".RData.meta")
                                        )
                                        metadata <- NULL
                                        if (file.exists(meta_path)) {
                                            print(sprintf("[STATE_STORE DEBUG] Loading metadata from %s", meta_path))
                                            metadata <- readRDS(meta_path)
                                        } else {
                                            print("[STATE_STORE DEBUG] No metadata file found, creating default metadata")
                                        }

                                        # Create a wrapper with either loaded or default metadata
                                        cache_metadata <- if (!is.null(metadata)) {
                                            # Make sure it has the required fields
                                            metadata$loaded_from_cache <- TRUE
                                            metadata$load_time <- Sys.time()
                                            metadata
                                        } else {
                                            list(
                                                loaded_from_cache = TRUE,
                                                load_time = Sys.time(),
                                                version = cached_sim$version
                                            )
                                        }

                                        cached_sim <- list(
                                            id = id,
                                            mode = mode,
                                            settings = settings,
                                            results = list(simset = cached_sim),
                                            timestamp = Sys.time(),
                                            status = "complete",
                                            loaded_from_cache = TRUE,
                                            cache_metadata = cache_metadata
                                        )
                                    } else {
                                        # Update ID and timestamp to reflect current state
                                        cached_sim$id <- id
                                        cached_sim$timestamp <- Sys.time()
                                        cached_sim$loaded_from_cache <- TRUE
                                    }

                                    # Store in memory
                                    private$simulations[[id]] <- reactiveVal(cached_sim)

                                    print(paste0("[STATE_STORE] Loaded from disk cache as simulation ID: ", id))
                                    return(id)
                                } else {
                                    print("[STATE_STORE DEBUG] Failed to load simulation from cache")
                                }
                            } else {
                                print("[STATE_STORE DEBUG] No matching simulation found in cache")
                            }
                        } else {
                            print("[STATE_STORE DEBUG] Disk cache is disabled")
                        }
                    },
                    error = function(e) {
                        print(sprintf("[STATE_STORE] Error checking disk cache: %s", e$message))
                        print("[STATE_STORE DEBUG] Stack trace:")
                        print(traceback())
                        # Continue without cache
                    }
                )
            }

            # No match found
            print("[STATE_STORE] No matching simulation found")
            NULL
        },

        #' @description Get the current simulation ID for a panel
        #' @param page_id Character: panel identifier
        #' @return Character: current simulation ID or NULL
        get_current_simulation_id = function(page_id) {
            current_state <- self$get_panel_state(page_id)
            current_state$current_simulation_id
        },

        #' @description Update the current simulation for a panel
        #' @param page_id Character: panel identifier
        #' @param simulation_id Character: simulation identifier
        set_current_simulation = function(page_id, simulation_id) {
            if (!is.null(simulation_id)) {
                # Verify simulation exists
                if (is.null(private$simulations[[simulation_id]])) {
                    stop(sprintf("No simulation found with ID: %s", simulation_id))
                }
            }

            current_state <- self$get_panel_state(page_id)
            current_state$current_simulation_id <- simulation_id
            self$panel_states[[page_id]](current_state)

            invisible(self)
        },

        #' @description Clean up old simulations to prevent memory issues
        #' @param max_age Numeric: maximum age in seconds before a simulation is considered old
        #' @param force Logical: whether to force removal of referenced simulations
        #' @return Invisible self (for chaining)
        cleanup_old_simulations = function(max_age = NULL, force = FALSE) {
            # Get cleanup config
            tryCatch(
                {
                    config <- get_component_config("state_management")

                    # Use config values if not explicitly provided
                    if (is.null(max_age)) {
                        max_age <- config$cleanup$default_max_age
                    }

                    high_count_threshold <- 20 # Default fallback
                    aggressive_max_age <- 900 # Default fallback: 15 minutes

                    # Safely access config values with defaults
                    if (!is.null(config$cleanup$high_count_threshold)) {
                        high_count_threshold <- config$cleanup$high_count_threshold
                    }

                    if (!is.null(config$cleanup$aggressive_max_age)) {
                        aggressive_max_age <- config$cleanup$aggressive_max_age
                    }
                },
                error = function(e) {
                    # If config can't be loaded, use reasonable defaults
                    print(sprintf("[STATE_STORE] Error loading config: %s. Using default values.", e$message))
                    if (is.null(max_age)) {
                        max_age <<- 1800 # 30 minutes default
                    }
                    high_count_threshold <<- 20
                    aggressive_max_age <<- 900
                }
            )

            # Ensure max_age has a value (in case both config and parameter fail)
            if (is.null(max_age)) {
                max_age <- 1800 # 30 minutes absolute fallback
            }

            current_time <- Sys.time()

            # Get list of simulation IDs to check
            sim_ids <- names(private$simulations)
            print(sprintf("[STATE_STORE] Running cleanup. Found %d simulations to check", length(sim_ids)))

            # If we have too many simulations, adjust the age threshold
            if (length(sim_ids) > high_count_threshold) {
                print(sprintf(
                    "[STATE_STORE] High simulation count (%d). Using shorter retention period.",
                    length(sim_ids)
                ))
                max_age <- min(max_age, aggressive_max_age)
            }

            removed_count <- 0
            for (id in sim_ids) {
                sim_state <- private$simulations[[id]]()
                age <- difftime(current_time, sim_state$timestamp, units = "secs")

                # Check if simulation is old enough to remove
                age_numeric <- as.numeric(age)
                if (!is.na(age_numeric) && (age_numeric > max_age || force)) {
                    # Check if this simulation is currently being referenced
                    is_referenced <- FALSE
                    for (page_id in names(self$panel_states)) {
                        current_sim_id <- self$get_current_simulation_id(page_id)
                        if (!is.null(current_sim_id) && current_sim_id == id) {
                            is_referenced <- TRUE
                            break
                        }
                    }

                    # Only remove if not referenced or force is TRUE
                    if (!is_referenced || force) {
                        private$simulations[[id]] <- NULL
                        removed_count <- removed_count + 1
                    }
                }
            }

            print(sprintf("[STATE_STORE] Cleanup complete. Removed %d simulations", removed_count))
            invisible(self)
        },

        #' @description Get statistics about simulations in the store
        #' @return List with statistics
        get_simulation_stats = function() {
            sim_ids <- names(private$simulations)

            # Count simulations by mode
            mode_counts <- list(
                prerun = 0,
                custom = 0
            )

            # Track other stats
            oldest_timestamp <- Sys.time()
            newest_timestamp <- as.POSIXct("1970-01-01")

            for (id in sim_ids) {
                sim_state <- private$simulations[[id]]()

                # Count by mode
                mode_counts[[sim_state$mode]] <- mode_counts[[sim_state$mode]] + 1

                # Track oldest/newest
                if (sim_state$timestamp < oldest_timestamp) {
                    oldest_timestamp <- sim_state$timestamp
                }
                if (sim_state$timestamp > newest_timestamp) {
                    newest_timestamp <- sim_state$timestamp
                }
            }

            # Get currently referenced simulations
            referenced_ids <- character()
            for (page_id in names(self$panel_states)) {
                sim_id <- self$get_current_simulation_id(page_id)
                if (!is.null(sim_id)) {
                    referenced_ids <- c(referenced_ids, sim_id)
                }
            }

            list(
                total_count = length(sim_ids),
                by_mode = mode_counts,
                oldest_timestamp = oldest_timestamp,
                newest_timestamp = newest_timestamp,
                referenced_count = length(unique(referenced_ids)),
                referenced_ids = unique(referenced_ids)
            )
        },
        
        # ---- DOWNLOAD MANAGEMENT METHODS ----
        
        #' Add a new download to the active downloads list
        #' @param id Unique identifier for the download
        #' @param filename Name of the file being downloaded
        #' @param total_size Total size of the file in bytes (if known)
        #' @return Invisible self (for chaining)
        #' Add a new download to the active downloads list
        #' @param id Unique identifier for the download
        #' @param filename Name of the file being downloaded
        #' @param total_size Total size of the file in bytes (if known)
        #' @return Invisible self (for chaining)
        add_download = function(id, filename, total_size = NULL) {
          timestamp <- format(Sys.time(), "%H:%M:%S.%OS3")
          print(sprintf("[STATE_STORE %s] Adding new download: ID=%s, Filename=%s", timestamp, id, filename))
          
          current_state <- private$state$downloads
          
          # Create new download entry
          entry <- create_download_entry(id, filename, total_size)
          
          # Log existing downloads before adding
          active_count <- length(names(current_state$active_downloads))
          print(sprintf("[STATE_STORE %s] Current active downloads: %d", timestamp, active_count))
          
          # Add to active downloads
          current_state$active_downloads[[id]] <- entry
          current_state$last_updated <- Sys.time()
          
          # Update state
          private$state$downloads <- validate_download_progress_state(current_state)
          
          # Log active downloads after adding
          new_count <- length(names(private$state$downloads$active_downloads))
          print(sprintf("[STATE_STORE %s] Active downloads after adding: %d (added: %s)", 
                        timestamp, new_count, new_count > active_count))
          
          invisible(self)
        },

        #' Update the progress of an active download
        #' @param id Download identifier
        #' @param percent Progress percentage (0-100)
        #' @return Invisible self (for chaining)
        #' Update the progress of an active download
        #' @param id Download identifier
        #' @param percent Progress percentage (0-100)
        #' @return Invisible self (for chaining)
        update_download_progress = function(id, percent) {
          timestamp <- format(Sys.time(), "%H:%M:%S.%OS3")
          print(sprintf("[STATE_STORE %s] Updating download progress: ID=%s, Progress=%d%%", timestamp, id, percent))
          
          current_state <- private$state$downloads
          
          # Check if download exists
          if (is.null(current_state$active_downloads[[id]])) {
            print(sprintf("[STATE_STORE %s] Warning: Cannot update non-existent download: %s", timestamp, id))
            return(invisible(self))
          }
          
          # Update progress
          current_state$active_downloads[[id]]$percent <- min(100, max(0, percent))
          current_state$active_downloads[[id]]$last_updated <- Sys.time()
          current_state$last_updated <- Sys.time()
          
          # Update state
          private$state$downloads <- validate_download_progress_state(current_state)
          print(sprintf("[STATE_STORE %s] Successfully updated progress for download %s", timestamp, id))
          
          invisible(self)
        },

        #' Mark a download as complete
        #' @param id Download identifier
        #' @return Invisible self (for chaining)
        #' Mark a download as complete
        #' @param id Download identifier
        #' @return Invisible self (for chaining)
        complete_download = function(id) {
          timestamp <- format(Sys.time(), "%H:%M:%S.%OS3")
          print(sprintf("[STATE_STORE %s] Marking download as complete: ID=%s", timestamp, id))
          
          current_state <- private$state$downloads
          
          # Check if download exists
          if (is.null(current_state$active_downloads[[id]])) {
            print(sprintf("[STATE_STORE %s] Warning: Cannot complete non-existent download: %s", timestamp, id))
            return(invisible(self))
          }
          
          # Move from active to completed
          entry <- current_state$active_downloads[[id]]
          entry$percent <- 100
          entry$completion_time <- Sys.time()
          current_state$completed_downloads[[id]] <- entry
          current_state$active_downloads[[id]] <- NULL
          current_state$last_updated <- Sys.time()
          
          # Update state
          private$state$downloads <- validate_download_progress_state(current_state)
          print(sprintf("[STATE_STORE %s] Successfully moved download %s to completed list", timestamp, id))
          
          # Log download counts after change
          active_count <- length(names(private$state$downloads$active_downloads))
          completed_count <- length(names(private$state$downloads$completed_downloads))
          print(sprintf("[STATE_STORE %s] After completion - Active: %d, Completed: %d", 
                        timestamp, active_count, completed_count))
          
          invisible(self)
        },

        #' Mark a download as failed
        #' @param id Download identifier
        #' @param message Error message
        #' @param type Error type from ERROR_TYPES
        #' @param severity Error severity from SEVERITY_LEVELS
        #' @return Invisible self (for chaining)
        fail_download = function(id, message, type = ERROR_TYPES$DOWNLOAD, severity = SEVERITY_LEVELS$ERROR) {
          current_state <- private$state$downloads
          
          # Check if download exists
          if (is.null(current_state$active_downloads[[id]])) {
            return(invisible(self))
          }
          
          # Move from active to failed
          entry <- current_state$active_downloads[[id]]
          entry$failure_time <- Sys.time()
          entry$error_message <- message
          entry$error_type <- type
          entry$error_severity <- severity
          current_state$failed_downloads[[id]] <- entry
          current_state$active_downloads[[id]] <- NULL
          current_state$last_updated <- Sys.time()
          
          # Update state
          private$state$downloads <- validate_download_progress_state(current_state)
          
          invisible(self)
        },

        #' Get all active downloads
        #' @return List of active downloads
        #' Get all active downloads
        #' @return List of active downloads
        get_active_downloads = function() {
          timestamp <- format(Sys.time(), "%H:%M:%S.%OS3")
          active_downloads <- private$state$downloads$active_downloads
          count <- length(names(active_downloads))
          print(sprintf("[STATE_STORE %s] get_active_downloads called, returning %d downloads", timestamp, count))
          
          # If there are active downloads, log them
          if (count > 0) {
            for (id in names(active_downloads)) {
              download <- active_downloads[[id]]
              print(sprintf("[STATE_STORE %s] Active download: ID=%s, Progress=%d%%, Filename=%s", 
                           timestamp, id, download$percent, download$filename))
            }
          }
          
          active_downloads
        },

        #' Get all completed downloads
        #' @return List of completed downloads
        get_completed_downloads = function() {
          private$state$downloads$completed_downloads
        },

        #' Get all failed downloads
        #' @return List of failed downloads
        get_failed_downloads = function() {
          private$state$downloads$failed_downloads
        },

        #' Clear completed downloads
        #' @param keep_count Number of recent completed downloads to keep (default: 0)
        #' @return Invisible self (for chaining)
        clear_completed_downloads = function(keep_count = 0) {
          current_state <- private$state$downloads
          
          # Sort completed downloads by completion time
          if (length(current_state$completed_downloads) > keep_count) {
            sorted_downloads <- current_state$completed_downloads[
              order(sapply(current_state$completed_downloads, function(d) d$completion_time), decreasing = TRUE)
            ]
            
            # Keep only the specified number of recent downloads
            current_state$completed_downloads <- sorted_downloads[1:min(keep_count, length(sorted_downloads))]
            current_state$last_updated <- Sys.time()
            
            # Update state
            private$state$downloads <- validate_download_progress_state(current_state)
          }
          
          invisible(self)
        },

        #' Clear failed downloads
        #' @param keep_count Number of recent failed downloads to keep (default: 0)
        #' @return Invisible self (for chaining)
        clear_failed_downloads = function(keep_count = 0) {
          current_state <- private$state$downloads
          
          # Sort failed downloads by failure time
          if (length(current_state$failed_downloads) > keep_count) {
            sorted_downloads <- current_state$failed_downloads[
              order(sapply(current_state$failed_downloads, function(d) d$failure_time), decreasing = TRUE)
            ]
            
            # Keep only the specified number of recent downloads
            current_state$failed_downloads <- sorted_downloads[1:min(keep_count, length(sorted_downloads))]
            current_state$last_updated <- Sys.time()
            
            # Update state
            private$state$downloads <- validate_download_progress_state(current_state)
          }
          
          invisible(self)
        },

        # Page Error State Methods ---------------------------------------

        #' @description Update error state for a page
        #' @param page_id Character: page identifier
        #' @param has_error Logical: whether an error exists
        #' @param message Character: error message
        #' @param type Character: error type
        #' @param severity Character: error severity
        #' @return Invisible self (for chaining)
        update_page_error_state = function(page_id, has_error, message = NULL, type = NULL, severity = NULL) {
            if (is.null(private$page_error_states[[page_id]])) {
                # Create reactive values object if it doesn't exist
                private$page_error_states[[page_id]] <- reactiveValues(
                    has_error = has_error,
                    message = message,
                    type = type,
                    severity = severity,
                    timestamp = Sys.time()
                )
            } else {
                # Update existing reactive values
                private$page_error_states[[page_id]]$has_error <- has_error
                private$page_error_states[[page_id]]$message <- message
                private$page_error_states[[page_id]]$type <- type
                private$page_error_states[[page_id]]$severity <- severity
                private$page_error_states[[page_id]]$timestamp <- Sys.time()
            }

            invisible(self)
        },

        #' @description Get error state for a page
        #' @param page_id Character: page identifier
        #' @return ReactiveValues object containing error state
        get_page_error_state = function(page_id) {
            if (is.null(private$page_error_states[[page_id]])) {
                # Create empty error state if it doesn't exist
                private$page_error_states[[page_id]] <- reactiveValues(
                    has_error = FALSE,
                    message = NULL,
                    type = NULL,
                    severity = NULL,
                    timestamp = NULL
                )
            }

            private$page_error_states[[page_id]]
        },

        #' @description Clear error state for a page
        #' @param page_id Character: page identifier
        #' @return Invisible self (for chaining)
        clear_page_error_state = function(page_id) {
            if (!is.null(private$page_error_states[[page_id]])) {
                private$page_error_states[[page_id]]$has_error <- FALSE
                private$page_error_states[[page_id]]$message <- NULL
                private$page_error_states[[page_id]]$type <- NULL
                private$page_error_states[[page_id]]$severity <- NULL
                private$page_error_states[[page_id]]$timestamp <- NULL
            }

            invisible(self)
        }
    ),
    private = list(
        #' @description Set up reactive panel states
        #' @param page_ids Character vector of page identifiers
        setup_panel_states = function(page_ids) {
            self$panel_states <- lapply(page_ids, function(id) {
                reactiveVal(create_panel_state(id))
            })
            names(self$panel_states) <- page_ids
        },

        #' @description Set up simulation storage
        setup_simulation_storage = function() {
            private$simulations <- list()
        },

        #' @description Set up page error states
        #' @param page_ids Character vector of page identifiers
        setup_page_error_states = function(page_ids) {
            private$page_error_states <- list()
            for (id in page_ids) {
                private$page_error_states[[id]] <- reactiveValues(
                    has_error = FALSE,
                    message = NULL,
                    type = NULL,
                    severity = NULL,
                    timestamp = NULL
                )
            }
        },

        #' @description Generate unique simulation ID
        #' @return Character: unique ID
        generate_simulation_id = function() {
            paste0(
                "sim_", format(Sys.time(), "%Y%m%d_%H%M%S"), "_",
                sprintf("%04d", sample.int(9999, 1))
            )
        },

        #' @description Compare two settings objects for equality
        #' @param settings1 First settings object
        #' @param settings2 Second settings object
        #' @return Logical: TRUE if settings are equivalent
        are_settings_equal = function(settings1, settings2) {
            print("[STATE_STORE DEBUG] Comparing settings for equality")
            print("[STATE_STORE DEBUG] Settings 1:")
            print(str(settings1))
            print("[STATE_STORE DEBUG] Settings 2:")
            print(str(settings2))

            # First check if both are lists
            if (!is.list(settings1) || !is.list(settings2)) {
                print("[STATE_STORE DEBUG] Settings not both lists")
                return(FALSE)
            }

            # Skip comparison if either is NULL
            if (is.null(settings1) || is.null(settings2)) {
                print("[STATE_STORE DEBUG] One or both settings are NULL")
                return(identical(settings1, settings2))
            }

            # Create normalized copies for comparison
            settings1_norm <- settings1
            settings2_norm <- settings2

            # Normalize location codes if present
            if (!is.null(settings1_norm$location) && is.character(settings1_norm$location)) {
                settings1_norm$location <- normalize_location_code(settings1_norm$location)
                print(sprintf("[STATE_STORE DEBUG] Normalized location 1: %s", settings1_norm$location))
            }

            if (!is.null(settings2_norm$location) && is.character(settings2_norm$location)) {
                settings2_norm$location <- normalize_location_code(settings2_norm$location)
                print(sprintf("[STATE_STORE DEBUG] Normalized location 2: %s", settings2_norm$location))
            }

            # Step 1: Check if location and dates match
            location_match <- identical(settings1_norm$location, settings2_norm$location)
            print(sprintf("[STATE_STORE DEBUG] Location match: %s", location_match))

            # If locations don't match, return FALSE immediately
            if (!location_match) {
                print("[STATE_STORE DEBUG] Locations don't match, settings not equal")
                return(FALSE)
            }

            # Check dates if they exist
            dates_match <- TRUE
            if (!is.null(settings1_norm$dates) && !is.null(settings2_norm$dates)) {
                dates_match <- compare_components(settings1_norm$dates, settings2_norm$dates)
                print(sprintf("[STATE_STORE DEBUG] Dates match: %s", dates_match))

                # If dates don't match, return FALSE
                if (!dates_match) {
                    print("[STATE_STORE DEBUG] Dates don't match, settings not equal")
                    return(FALSE)
                }
            }

            # Step 2: Check if components match
            components_match <- TRUE
            if (!is.null(settings1_norm$components) && !is.null(settings2_norm$components)) {
                components_match <- compare_components(settings1_norm$components, settings2_norm$components)
                print(sprintf("[STATE_STORE DEBUG] Components match: %s", components_match))

                # If components don't match, return FALSE
                if (!components_match) {
                    print("[STATE_STORE DEBUG] Components don't match, settings not equal")
                    return(FALSE)
                }
            }

            # If we've reached this point, all checks have passed
            print("[STATE_STORE DEBUG] All checks passed, settings are equal")
            return(TRUE)
        },



        #' @field simulations Internal storage for simulation ReactiveVals
        simulations = NULL,

        #' @field page_error_states Internal storage for page error states
        page_error_states = NULL,

        #' @field state Main state storage
        state = NULL
    )
)

# Create global store instance
STATE_STORE <- StateStore$new()

#' Helper function to get store instance
#' @return StateStore instance
get_store <- function() {
    STATE_STORE
}
