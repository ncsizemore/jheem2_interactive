library(cachem)

# Null coalescing operator (used for default values)
`%||%` <- function(x, y) if (is.null(x)) y else x

# Source utilities
# We no longer need to source a separate utils file

#' Normalize location code format
#' @param location_code Location code to normalize
#' @return Normalized location code
normalize_location_code <- function(location_code) {
    # Return as-is if NULL or not a character
    if (is.null(location_code) || !is.character(location_code)) {
        return(location_code)
    }
    
    # Strip whitespace and convert to uppercase
    location_code <- toupper(trimws(location_code))
    
    # If it's a numeric code with "C." prefix, ensure consistent format
    if (grepl("^C\\.[0-9]+$", location_code)) {
        # Extract the number part
        num_part <- as.numeric(gsub("C\\.", "", location_code))
        # Reformat consistently
        return(paste0("C.", num_part))
    }
    
    return(location_code)
}

# Global cache instances
.CACHE <- list()
#' Normalize cache path for consistency
#' @param path Path to normalize
#' @return Normalized path
normalize_cache_path <- function(path) {
    # Handle NULL or empty paths
    if (is.null(path) || path == "") {
        return("./cache/default")
    }
    
    # Ensure path is a character vector
    if (!is.character(path)) {
        warning("Path is not a character string, converting")
        path <- as.character(path)
    }
    
    # Ensure path starts with ./ or / for better consistency
    if (!grepl("^(\\./|/)", path)) {
        path <- paste0("./", path)
    }
    
    # Remove trailing slashes
    path <- gsub("/+$", "", path)
    
    # Replace backslashes with forward slashes for cross-platform compatibility
    path <- gsub("\\\\", "/", path)
    
    return(path)
}

#' Validate a path before using in file operations
#' @param path Path to validate
#' @return Validated path or stops with error
validate_path <- function(path) {
    # Check if path is valid
    if (is.null(path)) {
        stop("Invalid path: NULL")
    }
    
    if (!is.character(path) || length(path) != 1) {
        stop("Invalid path: must be a single character string")
    }
    
    # Normalize path for consistency
    path <- normalize_cache_path(path)
    
    return(path)
}

#' Initialize caches based on config
#' @param config Cache configuration from get_component_config("caching")
initialize_caches <- function(config) {
    # Print debug info for cache configuration
    print("\n[CACHE] Initializing caches with configuration:")
    print(sprintf("  - Simulation cache enabled: %s", 
                  !is.null(config$simulation_cache) && config$simulation_cache$enable_disk_cache))
    
    # Print more detailed debug info about configuration
    print("[CACHE DEBUG] Full caching configuration:")
    if (!is.null(config$simulation_cache)) {
        print(sprintf("  - Provider: %s", config$simulation_cache$provider %||% "disk"))
        print(sprintf("  - Path: %s", config$simulation_cache$path %||% "<not specified>"))
        print(sprintf("  - Max size: %s", format(config$simulation_cache$max_size, scientific = FALSE)))
        print(sprintf("  - Version checking: %s", 
                      !is.null(config$simulation_cache$check_version) && config$simulation_cache$check_version))
        print(sprintf("  - Expected version: %s", 
                      config$simulation_cache$simulation_version %||% "none"))
    }
    
    # Check if we're reinitializing an existing cache
    existing_cache <- !is.null(.CACHE) && length(.CACHE) > 0
    if (existing_cache) {
        print("[CACHE DEBUG] Re-initializing existing cache")
    }
    
    if (!is.null(config$simulation_cache)) {
        print(sprintf("  - Version checking: %s", 
                      !is.null(config$simulation_cache$check_version) && config$simulation_cache$check_version))
        print(sprintf("  - Expected version: %s", 
                      config$simulation_cache$simulation_version %||% "none"))
    }
    
    # Initialize backward compatibility caches
    .CACHE$cache1 <<- cache_disk(
        max_size = config$cache1$max_size,
        evict = config$cache1$evict_strategy
    )

    .CACHE$cache2 <<- cache_disk(
        max_size = config$cache2$max_size,
        evict = config$cache2$evict_strategy
    )
    
    # Initialize simulation cache if enabled
    if (!is.null(config$simulation_cache) && 
        (!is.null(config$simulation_cache$enable_disk_cache) && 
         config$simulation_cache$enable_disk_cache)) {
        
        # Create cache directory if it doesn't exist
        cache_dir <- config$simulation_cache$path
        print(sprintf("[CACHE DEBUG] Cache directory from config: '%s'", cache_dir))
        
        if (is.null(cache_dir) || cache_dir == "") {
            cache_dir <- "cache/simulations"  # Use default if not specified
            print(sprintf("[CACHE DEBUG] Using default cache directory: '%s'", cache_dir))
        }
        
        # Normalize the path for consistency
        cache_dir <- normalize_cache_path(cache_dir)
        print(sprintf("[CACHE DEBUG] Normalized cache directory: '%s'", cache_dir))
        
        tryCatch({
            # Validate and check if directory exists
            if (!is.character(cache_dir)) {
                stop("Cache directory is not a character string")
            }
            
            print(sprintf("[CACHE DEBUG] Checking if directory exists: '%s'", cache_dir))
            if (!dir.exists(cache_dir)) {
                print(sprintf("[CACHE DEBUG] Creating cache directory: '%s'", cache_dir))
                dir.create(cache_dir, recursive = TRUE, showWarnings = TRUE)
                print(sprintf("[CACHE DEBUG] Post-creation check: directory exists = %s", 
                             ifelse(dir.exists(cache_dir), "TRUE", "FALSE")))
            } else {
                print(sprintf("[CACHE DEBUG] Directory already exists: '%s'", cache_dir))
            }
            
            # Get current working directory
            current_dir <- getwd()
            print(sprintf("[CACHE DEBUG] Current working directory: '%s'", current_dir))
            
            # Check absolute path
            absolute_path <- normalizePath(cache_dir, mustWork = FALSE)
            print(sprintf("[CACHE DEBUG] Absolute path: '%s'", absolute_path))
            print(sprintf("[CACHE DEBUG] Absolute path exists: %s", dir.exists(absolute_path)))
        }, error = function(e) {
            print(sprintf("[CACHE ERROR] Error checking/creating cache directory: %s", e$message))
            # Use a fallback directory if needed - use local assignment, not global
            cache_dir <- "./cache"
            print(sprintf("[CACHE DEBUG] Using fallback cache directory: '%s'", cache_dir))
            if (!dir.exists(cache_dir)) {
                dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
            }
        })
        
        # Determine provider to use
        provider <- config$simulation_cache$provider %||% "disk"
        
        # Initialize based on provider type
        if (provider == "disk" || provider == "") {
            # Standard disk cache
            .CACHE$simulation_cache <<- cache_disk(
                dir = cache_dir,
                max_size = config$simulation_cache$max_size,
                evict = config$simulation_cache$evict_strategy
            )
            
            print(sprintf("[CACHE] Initialized disk simulation cache (max: %s MB)", 
                          config$simulation_cache$max_size / 1000000))
        } else if (provider == "onedrive") {
            # OneDrive provider
            if (file.exists("src/data/providers/onedrive_provider.R")) {
                # Try to load OneDrive provider
                tryCatch({
                    source("src/data/providers/onedrive_provider.R")
                    print("[CACHE] Initializing OneDrive provider...")
                    
                    # Create OneDrive cache
                    .CACHE$simulation_cache <<- create_onedrive_cache(config$simulation_cache)
                    print("[CACHE] Initialized OneDrive simulation cache")
                }, error = function(e) {
                    # Fall back to disk cache on error
                    print(sprintf("[CACHE] OneDrive provider error: %s. Using disk cache", e$message))
                    .CACHE$simulation_cache <<- cache_disk(
                        dir = cache_dir,
                        max_size = config$simulation_cache$max_size,
                        evict = config$simulation_cache$evict_strategy
                    )
                })
            } else {
                print("[CACHE] OneDrive provider not available - using disk cache instead")
                .CACHE$simulation_cache <<- cache_disk(
                    dir = cache_dir,
                    max_size = config$simulation_cache$max_size,
                    evict = config$simulation_cache$evict_strategy
                )
            }
        } else if (provider == "aws") {
            # AWS provider (will be implemented in Phase 6)
            if (file.exists("src/data/providers/aws_provider.R")) {
                # Try to load AWS provider
                tryCatch({
                    source("src/data/providers/aws_provider.R")
                    # Create AWS provider (this code would be implemented in Phase 6)
                    print("[CACHE] AWS provider not yet implemented - using disk cache instead")
                    .CACHE$simulation_cache <<- cache_disk(
                        dir = cache_dir,
                        max_size = config$simulation_cache$max_size,
                        evict = config$simulation_cache$evict_strategy
                    )
                }, error = function(e) {
                    # Fall back to disk cache on error
                    print(sprintf("[CACHE] AWS provider error: %s. Using disk cache", e$message))
                    .CACHE$simulation_cache <<- cache_disk(
                        dir = cache_dir,
                        max_size = config$simulation_cache$max_size,
                        evict = config$simulation_cache$evict_strategy
                    )
                })
            } else {
                print("[CACHE] AWS provider not available - using disk cache instead")
                .CACHE$simulation_cache <<- cache_disk(
                    dir = cache_dir,
                    max_size = config$simulation_cache$max_size,
                    evict = config$simulation_cache$evict_strategy
                )
            }
        } else {
            # Unknown provider, fall back to disk
            print(sprintf("[CACHE] Unknown provider '%s' - using disk cache", provider))
            .CACHE$simulation_cache <<- cache_disk(
                dir = cache_dir,
                max_size = config$simulation_cache$max_size,
                evict = config$simulation_cache$evict_strategy
            )
        }
    } else {
        print("[CACHE] Simulation cache disabled or not configured")
    }
}

#' Sanitize cache key to meet cachem requirements
#' @param key Original key
#' @return Sanitized key
sanitize_key <- function(key) {
    # Replace any non-alphanumeric characters with underscore
    # Convert to lowercase
    tolower(gsub("[^a-zA-Z0-9]", "_", key))
}

#' Generate a file path for a simulation based on LocalProvider pattern
#' @param settings Simulation settings
#' @param mode Simulation mode ("prerun" or "custom")
#' @return File path string
get_simulation_file_path <- function(settings, mode) {
    if (mode == "prerun") {
        # Get pattern from prerun config
        prerun_config <- tryCatch({
            get_page_complete_config("prerun")$prerun_simulations
        }, error = function(e) {
            # Default pattern if config not available
            list(file_pattern = "prerun/{location}/{aspect}_{population}_{timeframe}_{intensity}.Rdata")
        })
        
        # Extract pattern without prerun/ prefix and .Rdata suffix
        pattern <- prerun_config$file_pattern
        pattern <- gsub("^prerun/", "", pattern)
        pattern <- gsub("\\.Rdata$", "", pattern)
        
        # Extract placeholders
        placeholders <- regmatches(pattern, gregexpr("\\{([^}]+)\\}", pattern))[[1]]
        selectors <- gsub("[{}]", "", placeholders)
        
        # Replace placeholders with values
        file_path <- pattern
        for (selector in selectors) {
            value <- settings[[selector]]
            if (is.null(value)) {
                value <- "default"
            }
            file_path <- gsub(paste0("\\{", selector, "\\}"), value, file_path)
        }
        
        return(file_path)
    } else {
        # For custom mode, just use location as the base
        if (is.null(settings$location)) {
            return("custom/default")
        }
        return(paste0("custom/", settings$location))
    }
}

#' Generate a cache key for simulation settings
#' @param settings Simulation settings
#' @param mode Simulation mode ("prerun" or "custom")
#' @return A deterministic cache key
generate_simulation_cache_key <- function(settings, mode) {
    # Make sure digest package is available
    if (!requireNamespace("digest", quietly = TRUE)) {
        stop("Package 'digest' is required for cache key generation")
    }
    
    print(sprintf("[CACHE DEBUG] Generating cache key for mode: %s", mode))
    print("[CACHE DEBUG] Settings:")
    print(str(settings))
    
    # Create a safer copy of settings
    settings_copy <- settings
    if (is.list(settings_copy)) {
        # Remove any large data structures that aren't needed for the key
        settings_copy$data <- NULL
        settings_copy$results <- NULL
        settings_copy$parameters <- NULL
        
        # Normalize location code if present
        if (!is.null(settings_copy$location)) {
            settings_copy$location <- normalize_location_code(settings_copy$location)
            print(sprintf("[CACHE DEBUG] Normalized location: %s", settings_copy$location))
        }
        
        # Log scenario specifically (important for caching)
        if (!is.null(settings_copy$scenario)) {
            print(sprintf("[CACHE DEBUG] Using scenario '%s' in cache key", settings_copy$scenario))
        }
    }
    
    # Get a consistent identifier for the simulation
    # Use a path-like approach similar to LocalProvider
    sim_path <- tryCatch({
        get_simulation_file_path(settings, mode)
    }, error = function(e) {
        # If path generation fails, create a fallback path
        # based on the mode and first few settings values
        print(sprintf("[CACHE DEBUG] Error generating path: %s", e$message))
        
        fallback <- paste0(mode, "/")
        
        if (is.list(settings) && !is.null(settings$location)) {
            fallback <- paste0(fallback, settings$location)
        } else {
            fallback <- paste0(fallback, "unknown")
        }
        
        print(sprintf("[CACHE DEBUG] Using fallback path: %s", fallback))
        fallback
    })
    
    print(sprintf("[CACHE DEBUG] Simulation path: %s", sim_path))
    
    # Create a hash based on the path and additional settings
    key_parts <- list(
        path = sim_path,
        mode = mode
    )
    
    # Add additional settings not in the path
    if (mode == "custom" && is.list(settings_copy)) {
        # For custom simulations, include all settings
        # We already removed large data structures above
        key_parts$settings <- settings_copy
    }
    
    # Create hash
    hash <- tryCatch({
        digest::digest(key_parts, algo = "md5")
    }, error = function(e) {
        # Fallback - use a simplified hash if digest fails
        print(sprintf("[CACHE DEBUG] Error creating hash: %s", e$message))
        # Create a simple hash from the path and mode
        fallback_hash <- digest::digest(paste0(sim_path, "_", mode), algo = "md5")
        print(sprintf("[CACHE DEBUG] Using fallback hash: %s", fallback_hash))
        fallback_hash
    })
    
    print(sprintf("[CACHE DEBUG] Generated hash: %s", hash))
    
    # Create key in format: sim_[mode]_[hash]
    key <- paste0("sim_", mode, "_", hash)
    
    # Sanitize for cache storage
    key <- sanitize_key(key)
    print(sprintf("[CACHE DEBUG] Final cache key: %s", key))
    
    key
}

#' Serialize a simulation state for caching
#' @param sim_state Simulation state to serialize
#' @param key Cache key for storage
#' @return TRUE if serialization successful, FALSE otherwise
serialize_simulation_state <- function(sim_state, key) {
    # Add debugging for storage
    print("[CACHE DEBUG] Serializing simulation state for caching")
    print(sprintf("[CACHE DEBUG] - ID: %s", sim_state$id))
    print(sprintf("[CACHE DEBUG] - Mode: %s", sim_state$mode))
    print(sprintf("[CACHE DEBUG] - Has simset: %s", !is.null(sim_state$results) && !is.null(sim_state$results$simset)))
    
    # Add metadata about contained objects for better deserialization
    if (is.null(sim_state$cache_metadata)) {
        sim_state$cache_metadata <- list()
    }
    
    # Record timestamp for cache management
    sim_state$cache_metadata$cached_at <- Sys.time()
    
    # Check if cache directory exists
    cache_config <- tryCatch({
        get_component_config("caching")$simulation_cache
    }, error = function(e) {
        return(NULL)
    })
    
    if (is.null(cache_config) || is.null(cache_config$path)) {
        print("[CACHE DEBUG] No cache path configured")
        return(FALSE)
    }
    
    # Ensure cache directory exists
    cache_dir <- cache_config$path
    if (!dir.exists(cache_dir)) {
        dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
        print(sprintf("[CACHE DEBUG] Created cache directory: %s", cache_dir))
    }
    
    # Normalize cache directory for consistency
    cache_dir <- normalize_cache_path(cache_dir)
    
    # Create file path based on key
    file_path <- file.path(cache_dir, paste0(key, ".RData"))
    print(sprintf("[CACHE DEBUG] Saving to file: %s", file_path))
    
    # Save the entire simulation state using base R save function
    # This is consistent with how JHEEM typically saves files
    tryCatch({
        # Using 'save' instead of serializing for RDS
        result_var_name <- "sim_state"
        save(list = result_var_name, file = file_path, envir = environment())
        print(sprintf("[CACHE DEBUG] Saved simulation to file: %s", file_path))
        
        # Add logging to help diagnose the .rds file issue
        rds_path <- paste0(file_path, ".rds")
        if (file.exists(rds_path)) {
            print(sprintf("[CACHE DEBUG] Found unexpected .rds file: %s", rds_path))
            # Try to remove it
            tryCatch({
                file.remove(rds_path)
                print("[CACHE DEBUG] Removed unexpected .rds file")
            }, error = function(e) {
                print(sprintf("[CACHE DEBUG] Could not remove .rds file: %s", e$message))
            })
        }
        
        # Verify the file was created
        if (file.exists(file_path)) {
            print(sprintf("[CACHE DEBUG] File exists: %s, size: %d bytes", 
                          file_path, file.info(file_path)$size))
            return(TRUE)
        } else {
            print("[CACHE DEBUG] File was not created!")
            return(FALSE)
        }
    }, error = function(e) {
        print(sprintf("[CACHE DEBUG] Error saving simulation: %s", e$message))
        return(FALSE)
    })
}

#' Save a simulation state to a file for caching
#' @param sim_state Simulation state to save
#' @param key Cache key for storage
#' @param cache_dir Directory to save the cache file
#' @return TRUE if save successful, FALSE otherwise
save_simulation_to_file <- function(sim_state, key, cache_dir) {
    # Add debugging for storage
    print("[CACHE DEBUG] Saving simulation state to file")
    print(sprintf("[CACHE DEBUG] - ID: %s", sim_state$id))
    print(sprintf("[CACHE DEBUG] - Mode: %s", sim_state$mode))
    print(sprintf("[CACHE DEBUG] - Has simset: %s", !is.null(sim_state$results) && !is.null(sim_state$results$simset)))
    
    # Create file path based on key
    file_path <- file.path(cache_dir, paste0(key, ".RData"))
    print(sprintf("[CACHE DEBUG] Saving to file: %s", file_path))
    
    # Check if we have a JHEEM simulation
    if (!is.null(sim_state$results$simset) && 
        inherits(sim_state$results$simset, "jheem.simulation.set")) {
        
        # Use direct save instead of JHEEM's native save method to avoid directory structure issues
        print("[CACHE DEBUG] Using direct save for JHEEM simulation")
        tryCatch({
            # Extract the simset directly
            simset <- sim_state$results$simset
            
            # Use standard R save function directly
            save(simset, file = file_path)
            
            # Save metadata separately for our cache system
            metadata <- list(
                key = key,
                cached_at = Sys.time(),
                version = sim_state$cache_metadata$version,
                settings = sim_state$settings,
                mode = sim_state$mode,
                id = sim_state$id,
                saved_with = "direct_save"
            )
            
            meta_path <- paste0(file_path, ".meta")
            print(sprintf("[CACHE DEBUG] Saving metadata: %s", meta_path))
            saveRDS(metadata, meta_path)
            print(sprintf("[CACHE DEBUG] Saved metadata to: %s", meta_path))
            
            # Check for unexpected .rds file
            rds_path <- paste0(file_path, ".rds")
            if (file.exists(rds_path)) {
                print(sprintf("[CACHE DEBUG] Found unexpected .rds file: %s", rds_path))
                # Try to remove it
                tryCatch({
                    file.remove(rds_path)
                    print("[CACHE DEBUG] Removed unexpected .rds file")
                }, error = function(e) {
                    print(sprintf("[CACHE DEBUG] Could not remove .rds file: %s", e$message))
                })
            }
            
            # Verify the file was created
            if (file.exists(file_path)) {
                print(sprintf("[CACHE DEBUG] File exists: %s, size: %d bytes", 
                              file_path, file.info(file_path)$size))
                return(TRUE)
            } else {
                print("[CACHE DEBUG] File was not created!")
                return(FALSE)
            }
        }, error = function(e) {
            print(sprintf("[CACHE DEBUG] Error using direct save method: %s, falling back to standard save", e$message))
            # Fall through to standard save method
        })
    }
    
    # Fall back to standard R save method
    print("[CACHE DEBUG] Using standard R save method")
    tryCatch({
        # Create a named variable for saving
        simulation <- sim_state
        
        # Use standard R save method
        save(simulation, file = file_path)
        print(sprintf("[CACHE DEBUG] Saved simulation to file: %s", file_path))
        
        # We'll avoid creating an rds file completely - just use the meta file
        # Save metadata separately for our cache system
        metadata <- list(
            key = key,
            cached_at = Sys.time(),
            version = sim_state$cache_metadata$version,
            settings = sim_state$settings,
            mode = sim_state$mode,
            id = sim_state$id,
            saved_with = "standard_save"
        )
        
        meta_path <- paste0(file_path, ".meta")
        print(sprintf("[CACHE DEBUG] Saving metadata: %s", meta_path))
        saveRDS(metadata, meta_path)
        print(sprintf("[CACHE DEBUG] Saved metadata to: %s", meta_path))
        
        # Check for unexpected .rds file
        rds_path <- paste0(file_path, ".rds")
        if (file.exists(rds_path)) {
            print(sprintf("[CACHE DEBUG] Found unexpected .rds file: %s", rds_path))
            # Try to remove it
            tryCatch({
                file.remove(rds_path)
                print("[CACHE DEBUG] Removed unexpected .rds file")
            }, error = function(e) {
                print(sprintf("[CACHE DEBUG] Could not remove .rds file: %s", e$message))
            })
        }
        
        # Verify the file was created
        if (file.exists(file_path)) {
            print(sprintf("[CACHE DEBUG] File exists: %s, size: %d bytes", 
                          file_path, file.info(file_path)$size))
            return(TRUE)
        } else {
            print("[CACHE DEBUG] File was not created!")
            return(FALSE)
        }
    }, error = function(e) {
        print(sprintf("[CACHE DEBUG] Error saving simulation: %s", e$message))
        return(FALSE)
    })
}

#' Load a simulation state from a cache file
#' @param key Cache key to retrieve
#' @param cache_dir Directory where cache files are stored
#' @return Restored simulation state or NULL on error
load_simulation_from_file <- function(key, cache_dir) {
    print("[CACHE DEBUG] Loading simulation state from file")
    
    # Normalize cache directory
    cache_dir <- normalize_cache_path(cache_dir)
    print(sprintf("[CACHE DEBUG] Using cache directory: '%s'", cache_dir))
    
    # Create file path based on key
    file_path <- file.path(cache_dir, paste0(key, ".RData"))
    print(sprintf("[CACHE DEBUG] Loading from file: %s", file_path))
    
    # First check if file exists
    if (!file.exists(file_path)) {
        # If it's a directory (from JHEEM native save method), look for Rdata files inside
        if (dir.exists(file_path)) {
            print("[CACHE DEBUG] Found directory instead of file - checking for Rdata files inside")
            # Search for Rdata files recursively
            rdata_files <- list.files(file_path, pattern = "\\.Rdata$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
            
            if (length(rdata_files) > 0) {
                print(sprintf("[CACHE DEBUG] Found %d Rdata files in directory", length(rdata_files)))
                file_path <- rdata_files[1] # Use the first one
                print(sprintf("[CACHE DEBUG] Using file: %s", file_path))
            } else {
                print("[CACHE DEBUG] No Rdata files found in directory structure")
                return(NULL)
            }
        } else {
            print(sprintf("[CACHE DEBUG] Cache file not found: %s", file_path))
            return(NULL)
        }
    }
    
    # Additional validation
    print(sprintf("[CACHE DEBUG] File exists: %s, size: %d bytes", 
                  file_path, file.info(file_path)$size))
    
    # Load the metadata first if available
    meta_path <- paste0(file_path, ".meta")
    metadata <- NULL
    if (file.exists(meta_path)) {
        tryCatch({
            metadata <- readRDS(meta_path)
            print(sprintf("[CACHE DEBUG] Loaded metadata: version=%s, saved_with=%s", 
                          metadata$version, metadata$saved_with))
        }, error = function(e) {
            print(sprintf("[CACHE DEBUG] Error loading metadata: %s", e$message))
        })
    }
    
    # Load the simulation using the same approach as LocalProvider
    tryCatch({
        # Create a new environment to load into
        sim_env <- new.env()
        
        # Load file into the environment
        loaded_vars <- load(file_path, envir = sim_env)
        print(sprintf("[CACHE DEBUG] Loaded variables: %s", paste(loaded_vars, collapse = ", ")))
        
        # Get the cached simulation using the get(load()) pattern from LocalProvider
        cached_sim <- NULL
        
        # Try to figure out which variable contains our simulation
        if (length(loaded_vars) > 0) {
            # Check each loaded variable to find our simulation
            for (var_name in loaded_vars) {
                var_value <- get(var_name, envir = sim_env)
                
                # If saved with standard method, look for 'simulation'
                if (var_name == "simulation") {
                    cached_sim <- var_value
                    print("[CACHE DEBUG] Found simulation object")
                    break
                }
                
                # If it's a JHEEM simulation set, it might be directly loaded
                if (inherits(var_value, "jheem.simulation.set")) {
                    # If we have metadata, wrap it in a simulation state
                    if (!is.null(metadata)) {
                        cached_sim <- list(
                            id = metadata$id,
                            mode = metadata$mode,
                            settings = metadata$settings,
                            results = list(simset = var_value),
                            timestamp = Sys.time(),
                            status = "complete",
                            cache_metadata = metadata
                        )
                    } else {
                        # No metadata, just return the simset
                        cached_sim <- var_value
                    }
                    print("[CACHE DEBUG] Found JHEEM simulation object")
                    break
                }
            }
            
            # If we still haven't found it, just take the first variable
            if (is.null(cached_sim)) {
                cached_sim <- get(loaded_vars[1], envir = sim_env)
                print(sprintf("[CACHE DEBUG] Using first loaded variable: %s", loaded_vars[1]))
            }
        }
        
        # Record that it was loaded from cache
        if (is.list(cached_sim) && is.null(cached_sim$cache_metadata)) {
            cached_sim$cache_metadata <- list()
        }
        
        if (is.list(cached_sim)) {
            cached_sim$cache_metadata$loaded_from_cache <- TRUE
            cached_sim$cache_metadata$load_time <- Sys.time()
            
            # Merge metadata if available
            if (!is.null(metadata)) {
                for (field in names(metadata)) {
                    if (is.null(cached_sim$cache_metadata[[field]])) {
                        cached_sim$cache_metadata[[field]] <- metadata[[field]]
                    }
                }
            }
        }
        
        return(cached_sim)
    }, error = function(e) {
        print(sprintf("[CACHE DEBUG] Error loading simulation: %s", e$message))
        return(NULL)
    })
}

# VERSION COMPATIBILITY FUNCTIONS

#' Safely get cache directory
#' @param create_if_missing If TRUE, create directory if it doesn't exist
#' @return Path to cache directory or NULL on error
get_cache_directory <- function(create_if_missing = FALSE, explicit_path = NULL) {
    # If an explicit path is provided, use that
    if (!is.null(explicit_path)) {
        # Normalize and validate the explicit path
        if (!is.character(explicit_path) || length(explicit_path) != 1) {
            print(sprintf("[CACHE DEBUG] Invalid explicit cache directory: %s", as.character(explicit_path)))
            return(NULL)
        }
        
        cache_dir <- normalize_cache_path(explicit_path)
        print(sprintf("[CACHE DEBUG] Using explicit cache directory: '%s'", cache_dir))
        
        # Create directory if requested and doesn't exist
        if (create_if_missing && !dir.exists(cache_dir)) {
            print(sprintf("[CACHE DEBUG] Creating explicit cache directory: '%s'", cache_dir))
            dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
        }
        
        # Return the explicit path
        return(cache_dir)
    }
    
    # Return NULL if cache is not initialized
    if (is.null(.CACHE$simulation_cache)) {
        print("[CACHE DEBUG] Cache not initialized, cannot get directory")
        return(NULL)
    }
    
    # Safely access the directory from the cache object
    tryCatch({
        # First, try to get it from the cache object's private dir
        cache_dir <- .CACHE$simulation_cache$.__enclos_env__$private$dir
        print(sprintf("[CACHE DEBUG] Accessed directory from cache object: '%s'", cache_dir))
        
        # Validate the directory path
        if (is.null(cache_dir) || !is.character(cache_dir) || length(cache_dir) != 1) {
            print(sprintf("[CACHE DEBUG] Invalid cache directory from object: %s", as.character(cache_dir)))
            
            # Fall back to config
            cache_config <- get_component_config("caching")$simulation_cache
            if (!is.null(cache_config) && !is.null(cache_config$path)) {
                cache_dir <- cache_config$path
                print(sprintf("[CACHE DEBUG] Using fallback from config: '%s'", cache_dir))
            } else {
                print("[CACHE DEBUG] No valid directory in config either")
                return(NULL)
            }
        }
        
        # Normalize the path for consistency
        cache_dir <- normalize_cache_path(cache_dir)
        print(sprintf("[CACHE DEBUG] Normalized cache directory: '%s'", cache_dir))
        
        # Create directory if requested and doesn't exist
        if (create_if_missing && !dir.exists(cache_dir)) {
            print(sprintf("[CACHE DEBUG] Creating cache directory: '%s'", cache_dir))
            dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
        }
        
        # Return directory path
        cache_dir
    }, error = function(e) {
        print(sprintf("[CACHE DEBUG] Error accessing cache directory: %s", e$message))
        NULL
    })
}

#' Check if cached simulation version is compatible with current version
#' @param cached_state Cached simulation state
#' @param config Optional direct config to use instead of loading from file
#' @return Boolean indicating compatibility
is_version_compatible <- function(cached_state, config = NULL) {
    # If no cache metadata or version, assume compatible
    if (is.null(cached_state$cache_metadata) || is.null(cached_state$cache_metadata$version)) {
        print("[CACHE] No version information in cached state - assuming compatible")
        return(TRUE)
    }
    
    # If config not provided, try to load it
    if (is.null(config)) {
        config <- tryCatch({
            get_component_config("caching")$simulation_cache
        }, error = function(e) {
            print("[CACHE] Error loading cache config - assuming compatible")
            return(NULL)
        })
    } else {
        # Config was provided directly
        print("[CACHE] Using provided config for version check")
        
        # Make sure we're using the simulation_cache part if given a full config
        if (!is.null(config$simulation_cache)) {
            config <- config$simulation_cache
        }
    }
    
    # If no config, assume compatible
    if (is.null(config)) {
        print("[CACHE] No cache config found - assuming compatible")
        return(TRUE)
    }
    
    # Debug output for version checking
    print(sprintf("[CACHE DEBUG] Version check configuration:"))
    print(sprintf("[CACHE DEBUG] - check_version: %s", !is.null(config$check_version) && config$check_version))
    print(sprintf("[CACHE DEBUG] - expected_version: %s", config$simulation_version %||% "none"))
    print(sprintf("[CACHE DEBUG] - cached_version: %s", cached_state$cache_metadata$version %||% "none"))
    
    # Check if version checking is enabled
    if (is.null(config$check_version) || !config$check_version) {
        print("[CACHE] Version checking disabled in config - assuming compatible")
        return(TRUE)
    }
    
    # Get expected version
    expected_version <- config$simulation_version
    
    # If no expected version, assume compatible
    if (is.null(expected_version)) {
        print("[CACHE] No expected version in config - assuming compatible")
        return(TRUE)
    }
    
    # Compare versions
    cached_version <- cached_state$cache_metadata$version
    result <- identical(cached_version, expected_version)
    
    if (!result) {
        print(sprintf("[CACHE] Version mismatch: cached=%s, expected=%s", 
                      cached_version, expected_version))
    } else {
        print(sprintf("[CACHE] Version match: %s", expected_version))
    }
    
    result
}

# SIMULATION CACHE FUNCTIONS

#' Check if a simulation exists in cache
#' @param settings Simulation settings
#' @param mode Simulation mode
#' @param explicit_cache_dir Optional explicit cache directory path
#' @return Boolean indicating if matching simulation exists
is_simulation_cached <- function(settings, mode, explicit_cache_dir = NULL) {
    # Return FALSE if cache is not initialized
    if (is.null(.CACHE$simulation_cache)) {
        print("[CACHE DEBUG] Cache not initialized, returning FALSE")
        return(FALSE)
    }
    
    # Generate a deterministic key for these settings
    key <- generate_simulation_cache_key(settings, mode)
    print(sprintf("[CACHE DEBUG] Checking for key: %s", key))
    
    # Get cache directory using our helper function
    cache_dir <- if (!is.null(explicit_cache_dir)) {
        # Use the explicitly provided directory
        print(sprintf("[CACHE DEBUG] Using explicitly provided cache directory: '%s'", explicit_cache_dir))
        normalize_cache_path(explicit_cache_dir)
    } else {
        # Try to get directory from cache object
        get_cache_directory(create_if_missing = TRUE)
    }
    
    # Check if we got a valid directory
    if (is.null(cache_dir)) {
        print("[CACHE DEBUG] Failed to get valid cache directory")
        return(FALSE)
    }
    
    print(sprintf("[CACHE DEBUG] Using cache directory: '%s'", cache_dir))
    print(sprintf("[CACHE DEBUG] Directory exists: %s", ifelse(dir.exists(cache_dir), "TRUE", "FALSE")))
    
    # List contents of cache directory for debugging
    print("[CACHE DEBUG] Listing cache directory contents:")
    tryCatch({
        if (dir.exists(cache_dir)) {
            files <- list.files(cache_dir, full.names = TRUE)
            if (length(files) == 0) {
                print("  (empty directory)")
            } else {
                for (f in files) {
                    print(sprintf("  %s", f))
                }
            }
        } else {
            print("  (directory does not exist)")
        }
    }, error = function(e) {
        print(sprintf("[CACHE DEBUG] Error listing directory: %s", e$message))
    })
    
    # Final directory check
    if (!dir.exists(cache_dir)) {
        print(sprintf("[CACHE DEBUG] Cache directory does not exist after creation attempt: %s", cache_dir))
        return(FALSE)
    }
    
    # Check if the file exists directly
    file_path <- file.path(cache_dir, paste0(key, ".RData"))
    file_exists <- file.exists(file_path)
    print(sprintf("[CACHE DEBUG] Checking file: %s, exists: %s", file_path, file_exists))
    
    # Check metadata if file exists
    if (file_exists) {
        print(sprintf("[CACHE] Found matching simulation in cache with key: %s", key))
        
        # Load metadata if available
        meta_path <- paste0(file_path, ".meta")
        if (file.exists(meta_path)) {
            tryCatch({
                metadata <- readRDS(meta_path)
                print(sprintf("[CACHE] Cached at: %s", metadata$cached_at))
                print(sprintf("[CACHE] Version: %s", metadata$version))
                if (!is.null(metadata$saved_with)) {
                    print(sprintf("[CACHE] Saved with: %s", metadata$saved_with))
                }
            }, error = function(e) {
                print(sprintf("[CACHE DEBUG] Error reading metadata: %s", e$message))
            })
        } else {
            print("[CACHE DEBUG] No metadata file found")
        }
    } else {
        print("[CACHE DEBUG] No cached data file found")
    }
    
    print(sprintf("[CACHE DEBUG] Final result of is_simulation_cached: %s", file_exists))
    file_exists
}

#' Get simulation from cache
#' @param settings Simulation settings
#' @param mode Simulation mode
#' @param check_version Logical: whether to check version compatibility (default: TRUE)
#' @param config Optional configuration to use for version check
#' @param explicit_cache_dir Optional explicit cache directory path
#' @return Cached simulation state or NULL if not found/error
get_simulation_from_cache <- function(settings, mode, check_version = TRUE, config = NULL, explicit_cache_dir = NULL) {
    # Return NULL if cache is not initialized
    if (is.null(.CACHE$simulation_cache)) {
        print("[CACHE DEBUG] Cache not initialized, returning NULL")
        return(NULL)
    }
    
    print("[CACHE DEBUG] Attempting to get simulation from cache")
    
    # Generate key
    key <- generate_simulation_cache_key(settings, mode)
    
    # Get cache directory using our helper function
    cache_dir <- if (!is.null(explicit_cache_dir)) {
        # Use the explicitly provided directory
        print(sprintf("[CACHE DEBUG] Using explicitly provided cache directory: '%s'", explicit_cache_dir))
        normalize_cache_path(explicit_cache_dir)
    } else {
        # Try to get directory from cache object
        get_cache_directory(create_if_missing = FALSE)
    }
    
    # Check if we got a valid directory
    if (is.null(cache_dir)) {
        print("[CACHE DEBUG] Failed to get valid cache directory")
        return(NULL)
    }
    
    print(sprintf("[CACHE DEBUG] Using cache directory: '%s'", cache_dir))
    
    # Create file path based on key
    file_path <- file.path(cache_dir, paste0(key, ".RData"))
    print(sprintf("[CACHE DEBUG] Looking for file: %s", file_path))
    
    # Check if file exists
    if (!file.exists(file_path)) {
        print(sprintf("[CACHE DEBUG] File not found: %s", file_path))
        return(NULL)
    }
    
    # Try to load metadata
    meta_path <- paste0(file_path, ".meta")
    metadata <- NULL
    if (file.exists(meta_path)) {
        tryCatch({
            metadata <- readRDS(meta_path)
            print(sprintf("[CACHE DEBUG] Loaded metadata for key: %s", key))
            
            # Version compatibility check (if enabled)
            if (check_version) {
                # If config not provided, try to load it
                if (is.null(config)) {
                    config <- tryCatch({
                        get_component_config("caching")
                    }, error = function(e) {
                        return(NULL)
                    })
                }
                
                # Check version compatibility
                if (!is.null(config) && 
                    !is.null(config$simulation_cache$check_version) && 
                    config$simulation_cache$check_version) {
                    
                    expected_version <- config$simulation_cache$simulation_version
                    cached_version <- metadata$version
                    
                    if (!is.null(expected_version) && !is.null(cached_version) && 
                        !identical(expected_version, cached_version)) {
                        print(sprintf("[CACHE] Version mismatch: cached=%s, expected=%s", 
                                     cached_version, expected_version))
                        return(NULL)
                    }
                }
            }
        }, error = function(e) {
            print(sprintf("[CACHE DEBUG] Error reading metadata: %s", e$message))
            # Continue without metadata
        })
    }
    
    # Load the simulation file
    tryCatch({
        # Use helper function to load the simulation
        cached_sim <- load_simulation_from_file(key, cache_dir)
        
        if (!is.null(cached_sim)) {
            print(sprintf("[CACHE] Successfully loaded simulation from cache with key: %s", key))
            return(cached_sim)
        } else {
            print("[CACHE DEBUG] Failed to load simulation from file")
            return(NULL)
        }
    }, error = function(e) {
        print(sprintf("[CACHE] Error retrieving from cache: %s", e$message))
        print("[CACHE DEBUG] Stack trace:")
        print(traceback())
        return(NULL)
    })
}

#' Cache a simulation state
#' @param settings Simulation settings
#' @param mode Simulation mode
#' @param sim_state Simulation state to cache
#' @param ttl Time-to-live in seconds (NULL for config default)
#' @return Invisible NULL
cache_simulation <- function(settings, mode, sim_state, ttl = NULL) {
    # Do nothing if cache is not initialized
    if (is.null(.CACHE$simulation_cache)) {
        print("[CACHE] Cache not initialized, cannot save simulation")
        return(invisible(NULL))
    }
    
    # Get TTL from config if not provided
    if (is.null(ttl)) {
        ttl <- tryCatch({
            get_component_config("caching")$simulation_cache$ttl
        }, error = function(e) {
            604800 # Default: 1 week
        })
    }
    
    # Get cache directory using our helper function
    cache_dir <- get_cache_directory(create_if_missing = TRUE, explicit_path = NULL)
    
    # If we couldn't get a cache directory, try to use the path from the config directly
    if (is.null(cache_dir)) {
        # Try to get it from config
        tryCatch({
            cache_config <- get_component_config("caching")$simulation_cache
            if (!is.null(cache_config) && !is.null(cache_config$path)) {
                cache_dir <- normalize_cache_path(cache_config$path)
                print(sprintf("[CACHE DEBUG] Using direct path from config: '%s'", cache_dir))
                
                # Create directory if it doesn't exist
                if (!dir.exists(cache_dir)) {
                    print(sprintf("[CACHE DEBUG] Creating missing cache directory from config: '%s'", cache_dir))
                    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
                    if (!dir.exists(cache_dir)) {
                        print("[CACHE DEBUG] Failed to create directory from config path")
                        return(invisible(NULL))
                    }
                }
            }
        }, error = function(e) {
            print(sprintf("[CACHE DEBUG] Error getting path from config: %s", e$message))
        })
    }
    
    # Check if we got a valid directory
    if (is.null(cache_dir)) {
        print("[CACHE DEBUG] Failed to get valid cache directory, cannot save simulation")
        return(invisible(NULL))
    }
    
    print(sprintf("[CACHE DEBUG] Using cache directory: '%s'", cache_dir))
    
    # Verify that we have proper permissions in the directory
    tryCatch({
        # Check for write permissions by creating a temporary file
        test_file <- tempfile(tmpdir = cache_dir)
        cat("test", file = test_file)
        if (file.exists(test_file)) {
            # We have write permissions, clean up the test file
            file.remove(test_file)
            print(sprintf("[CACHE DEBUG] Successfully verified write permissions to '%s'", cache_dir))
        } else {
            print(sprintf("[CACHE DEBUG] Failed to write test file to '%s', permissions issue", cache_dir))
        }
    }, error = function(e) {
        print(sprintf("[CACHE DEBUG] Error checking permissions: %s", e$message))
    })
    
    # Generate key
    key <- generate_simulation_cache_key(settings, mode)
    
    # Fix metadata in case it's missing
    if (is.null(sim_state$cache_metadata)) {
        sim_state$cache_metadata <- list()
    }
    
    # Add version if missing
    if (is.null(sim_state$cache_metadata$version)) {
        # Try to get version from config
        tryCatch({
            cache_config <- get_component_config("caching")$simulation_cache
            if (!is.null(cache_config$simulation_version)) {
                sim_state$cache_metadata$version <- cache_config$simulation_version
                print(sprintf("[CACHE DEBUG] Added version from config: %s", cache_config$simulation_version))
            }
        }, error = function(e) {
            # Default version
            sim_state$cache_metadata$version <- "ehe"
            print("[CACHE DEBUG] Added default version: ehe")
        })
    }
    
    # Save the simulation to file
    saved <- save_simulation_to_file(sim_state, key, cache_dir)
    
    if (saved) {
        # Also register in cachem for backward compatibility
        # But don't save additional files
        file_path <- file.path(cache_dir, paste0(key, ".RData"))
        # Check for any unexpected files created by cachem
        tryCatch({
            # List files before
            before_files <- list.files(cache_dir, full.names = TRUE)
            print("[CACHE DEBUG] Files before cachem registration:")
            for (f in before_files) {
                print(sprintf("  %s", f))
            }
            
            # Register with cachem
            .CACHE$simulation_cache$set(key, list(
                path = file_path,
                cache_metadata = sim_state$cache_metadata
            ))
            
            # List files after
            after_files <- list.files(cache_dir, full.names = TRUE)
            print("[CACHE DEBUG] Files after cachem registration:")
            for (f in after_files) {
                print(sprintf("  %s", f))
            }
            
            # Check for new files
            new_files <- setdiff(after_files, before_files)
            if (length(new_files) > 0) {
                print("[CACHE DEBUG] New files created by cachem:")
                for (f in new_files) {
                    print(sprintf("  %s", f))
                    # Try to remove if it's an rds file
                    if (grepl("\\.rds$", f)) {
                        print(sprintf("[CACHE DEBUG] Removing unexpected rds file: %s", f))
                        file.remove(f)
                    }
                }
            }
            
            print(sprintf("[CACHE] Successfully cached simulation with key: %s", key))
        }, error = function(e) {
            print(sprintf("[CACHE DEBUG] Error monitoring cachem: %s", e$message))
            print(sprintf("[CACHE] Successfully cached simulation with key: %s", key))
        })
    } else {
        print(sprintf("[CACHE] Failed to cache simulation with key: %s", key))
    }
    
    invisible(NULL)
}

# BACKWARD COMPATIBILITY FUNCTIONS

#' Check if a simset is cached (original function for backward compatibility)
#' @param key Cache key
#' @return Boolean indicating if key exists in cache
is_cached <- function(key) {
    if (is.null(.CACHE$cache1)) {
        return(FALSE)
    }
    safe_key <- sanitize_key(key)
    !is.null(.CACHE$cache1$get(safe_key))
}

#' Get simset from cache (original function for backward compatibility)
#' @param key Cache key
#' @return Cached simset or NULL if not found
get_from_cache <- function(key) {
    if (is.null(.CACHE$cache1)) {
        return(NULL)
    }
    safe_key <- sanitize_key(key)
    .CACHE$cache1$get(safe_key)
}

#' Store simset in cache (original function for backward compatibility)
#' @param key Cache key
#' @param value Simset to cache
cache_simset <- function(key, value) {
    if (is.null(.CACHE$cache1)) {
        return(NULL)
    }
    safe_key <- sanitize_key(key)
    .CACHE$cache1$set(safe_key, value)
}

#' Get cache statistics
#' @return List with cache statistics
get_cache_stats <- function() {
    stats <- list()
    
    # Add simulation cache stats if available
    if (!is.null(.CACHE$simulation_cache)) {
        # Get all cache keys
        keys <- .CACHE$simulation_cache$keys()
        
        # Get detailed stats about keys
        key_info <- list()
        if (length(keys) > 0) {
            for (key in keys) {
                item <- tryCatch({
                    .CACHE$simulation_cache$get(key)
                }, error = function(e) {
                    NULL
                })
                
                # Skip if item not found
                if (is.null(item)) {
                    next
                }
                
                # Get basic info
                info <- list(
                    key = key,
                    has_metadata = !is.null(item$cache_metadata)
                )
                
                # Add JHEEM specific info if available
                if (!is.null(item$cache_metadata)) {
                    if (!is.null(item$cache_metadata$jheem_version)) {
                        info$jheem_version <- item$cache_metadata$jheem_version
                    }
                    if (!is.null(item$cache_metadata$jheem_location)) {
                        info$location <- item$cache_metadata$jheem_location
                    }
                    if (!is.null(item$cache_metadata$cached_at)) {
                        info$age <- difftime(Sys.time(), item$cache_metadata$cached_at, units = "hours")
                    }
                }
                
                key_info[[key]] <- info
            }
        }
        
        stats$simulation_cache <- list(
            size = .CACHE$simulation_cache$size(),
            keys = length(keys),
            key_info = key_info,
            info = "Use .CACHE$simulation_cache$keys() to view all keys"
        )
    }
    
    # Add backward compatibility cache stats
    if (!is.null(.CACHE$cache1)) {
        stats$cache1 <- list(
            size = .CACHE$cache1$size(),
            keys = length(.CACHE$cache1$keys())
        )
    }
    
    if (!is.null(.CACHE$cache2)) {
        stats$cache2 <- list(
            size = .CACHE$cache2$size(),
            keys = length(.CACHE$cache2$keys())
        )
    }
    
    stats
}

#' Clean up old simulations from cache
#' @param max_age Maximum age in seconds (default: from config)
#' @param dry_run If TRUE, just report what would be removed
#' @return List with cleanup statistics
cleanup_simulation_cache <- function(max_age = NULL, dry_run = FALSE) {
    # Do nothing if cache is not initialized
    if (is.null(.CACHE$simulation_cache)) {
        return(list(error = "Cache not initialized"))
    }
    
    # Get cache directory using our helper function
    cache_dir <- get_cache_directory(create_if_missing = FALSE)
    
    # Check if we got a valid directory
    if (is.null(cache_dir)) {
        return(list(error = "Failed to get valid cache directory"))
    }
    
    print(sprintf("[CACHE] Using cache directory for cleanup: '%s'", cache_dir))
    
    # Get the TTL from config if not provided
    if (is.null(max_age)) {
        max_age <- tryCatch({
            get_component_config("caching")$simulation_cache$ttl
        }, error = function(e) {
            604800 # Default: 1 week
        })
    }
    
    print(sprintf("[CACHE] Starting cleanup with max age: %d seconds", max_age))
    
    # Get all cache keys
    keys <- .CACHE$simulation_cache$keys()
    if (length(keys) == 0) {
        return(list(removed = 0, total = 0, message = "No items in cache"))
    }
    
    # Get current time for comparison
    current_time <- Sys.time()
    
    # Prepare results
    removed <- list()
    kept <- list()
    errors <- list()
    
    # Process each key
    for (key in keys) {
        # Get cached item
        item <- tryCatch({
            .CACHE$simulation_cache$get(key)
        }, error = function(e) {
            errors[[key]] <- e$message
            next
        })
        
        # Skip if not found or no metadata
        if (is.null(item) || is.null(item$cache_metadata) || is.null(item$cache_metadata$cached_at)) {
            kept[[key]] <- "No timestamp"
            next
        }
        
        # Check age
        age <- difftime(current_time, item$cache_metadata$cached_at, units = "secs")
        age_numeric <- as.numeric(age)
        
        if (age_numeric > max_age) {
            # Remove if too old and not in dry run mode
            if (!dry_run) {
                tryCatch({
                    .CACHE$simulation_cache$remove(key)
                    removed[[key]] <- sprintf("Removed (age: %.1f hours)", age_numeric / 3600)
                }, error = function(e) {
                    errors[[key]] <- sprintf("Failed to remove: %s", e$message)
                })
            } else {
                removed[[key]] <- sprintf("Would remove (age: %.1f hours)", age_numeric / 3600)
            }
        } else {
            kept[[key]] <- sprintf("Kept (age: %.1f hours)", age_numeric / 3600)
        }
    }
    
    # Return results
    result <- list(
        removed = length(removed),
        kept = length(kept),
        total = length(keys),
        removed_keys = names(removed),
        kept_keys = names(kept),
        error_keys = names(errors),
        details = list(
            removed = removed,
            kept = kept,
            errors = errors
        ),
        dry_run = dry_run,
        max_age_hours = max_age / 3600
    )
    
    print(sprintf("[CACHE] Cleanup %s: %d removed, %d kept, %d errors (out of %d total)", 
                  if(dry_run) "simulation" else "complete", 
                  length(removed), length(kept), length(errors), length(keys)))
    
    result
}

#' Debug function to show details about cache keys
#' @param settings Simulation settings
#' @param mode Simulation mode
#' @return Generated key and cache status
debug_cache_key <- function(settings, mode) {
    print("\n=== Cache Key Debug Information ===")
    
    # Show input settings
    print("Settings:")
    print(str(settings))
    print(sprintf("Mode: %s", mode))
    
    # Generate key with normalized settings
    settings_norm <- settings
    if (is.list(settings_norm) && !is.null(settings_norm$location)) {
        original_location <- settings_norm$location
        settings_norm$location <- normalize_location_code(settings_norm$location)
        print(sprintf("Location: %s (normalized from: %s)", 
                     settings_norm$location, 
                     if(original_location != settings_norm$location) original_location else "same"))
    }
    
    # Get file path
    sim_path <- tryCatch({
        path <- get_simulation_file_path(settings_norm, mode)
        print(sprintf("Simulation path: %s", path))
        path
    }, error = function(e) {
        print(sprintf("Error getting simulation path: %s", e$message))
        return(NULL)
    })
    
    # Generate the key
    key <- generate_simulation_cache_key(settings, mode)
    print(sprintf("Generated key: %s", key))
    
    # Check if it's cached
    cached <- is_simulation_cached(settings, mode)
    print(sprintf("Is cached: %s", cached))
    
    # Check cache directory and file path
    cache_dir <- get_cache_directory(create_if_missing = FALSE)
    if (!is.null(cache_dir)) {
        file_path <- file.path(cache_dir, paste0(key, ".RData"))
        print(sprintf("Expected cache file: %s", file_path))
        print(sprintf("File exists: %s", file.exists(file_path)))
        
        # Check metadata file
        meta_path <- paste0(file_path, ".meta")
        print(sprintf("Metadata file exists: %s", file.exists(meta_path)))
        
        if (file.exists(meta_path)) {
            tryCatch({
                metadata <- readRDS(meta_path)
                print("Metadata contents:")
                print(str(metadata))
            }, error = function(e) {
                print(sprintf("Error reading metadata: %s", e$message))
            })
        }
    }
    
    # Return the generated key and cache status
    list(
        key = key,
        path = sim_path,
        cached = cached
    )
}

#' Dump information about all cached simulations
#' @return Invisible NULL
dump_cache_info <- function() {
    print("\n=== Dumping Cache Information ===")
    
    # Get cache directory
    cache_dir <- get_cache_directory(create_if_missing = FALSE)
    if (is.null(cache_dir)) {
        print("No valid cache directory found")
        return(invisible(NULL))
    }
    
    print(sprintf("Cache directory: %s", cache_dir))
    print(sprintf("Directory exists: %s", dir.exists(cache_dir)))
    
    if (!dir.exists(cache_dir)) {
        return(invisible(NULL))
    }
    
    # List all RData files in the cache
    files <- list.files(cache_dir, pattern = "\\.RData$", full.names = TRUE)
    print(sprintf("Found %d cached simulation files", length(files)))
    
    # Process each file
    for (file_path in files) {
        print(sprintf("\nFile: %s", basename(file_path)))
        print(sprintf("  Full path: %s", file_path))
        print(sprintf("  File size: %d bytes", file.info(file_path)$size))
        
        # Determine if it's a directory (JHEEM native save) or an actual file
        is_dir <- dir.exists(file_path)
        print(sprintf("  Is directory: %s", is_dir))
        
        # Load metadata
        meta_path <- paste0(file_path, ".meta")
        if (file.exists(meta_path)) {
            tryCatch({
                metadata <- readRDS(meta_path)
                print("  Metadata:")
                if (!is.null(metadata$key)) {
                    print(sprintf("    Key: %s", metadata$key))
                }
                if (!is.null(metadata$cached_at)) {
                    print(sprintf("    Cached at: %s", metadata$cached_at))
                    print(sprintf("    Age: %.1f hours", 
                                 as.numeric(difftime(Sys.time(), metadata$cached_at, units = "hours"))))
                }
                if (!is.null(metadata$version)) {
                    print(sprintf("    Version: %s", metadata$version))
                }
                if (!is.null(metadata$settings$location)) {
                    print(sprintf("    Location: %s", metadata$settings$location))
                }
                if (!is.null(metadata$mode)) {
                    print(sprintf("    Mode: %s", metadata$mode))
                }
                if (!is.null(metadata$saved_with)) {
                    print(sprintf("    Saved with: %s", metadata$saved_with))
                }
            }, error = function(e) {
                print(sprintf("  Error reading metadata: %s", e$message))
            })
        } else {
            print("  No metadata file found")
        }
        
        # If it's a directory, show its structure
        if (is_dir) {
            print("  Directory contents:")
            sub_files <- list.files(file_path, recursive = TRUE, full.names = TRUE)
            if (length(sub_files) > 10) {
                print(sprintf("    (%d files, showing first 10)", length(sub_files)))
                for (i in 1:min(10, length(sub_files))) {
                    print(sprintf("    %s", sub_files[i]))
                }
            } else {
                for (sub_file in sub_files) {
                    print(sprintf("    %s", sub_file))
                }
            }
        }
    }
    
    # Also dump cachem stats
    if (!is.null(.CACHE$simulation_cache)) {
        print("\nCache stats from cachem:")
        print(sprintf("  Size: %d", .CACHE$simulation_cache$size()))
        keys <- .CACHE$simulation_cache$keys()
        print(sprintf("  Keys: %d", length(keys)))
        if (length(keys) > 0) {
            print("  Key list:")
            for (key in keys) {
                print(sprintf("    %s", key))
            }
        }
    }
    
    invisible(NULL)
}

#' Test cache functionality
#' @return List with test results
test_cache_functionality <- function() {
    # Check if simulation cache is available
    if (is.null(.CACHE$simulation_cache)) {
        return(list(error = "Simulation cache not initialized"))
    }
    
    # Create test data
    test_settings <- list(location = "test", param1 = 123, param2 = "abc")
    test_mode <- "test"
    test_sim_state <- list(
        id = "test_sim_id",
        mode = test_mode,
        settings = test_settings,
        results = list(value = "test result"),
        timestamp = Sys.time()
    )
    
    # Run tests
    results <- list(
        key_generation = TRUE,
        serialization = TRUE,
        cache_write = FALSE,
        cache_check = FALSE,
        cache_read = FALSE,
        key = NULL
    )
    
    # Test key generation
    tryCatch({
        results$key <- generate_simulation_cache_key(test_settings, test_mode)
    }, error = function(e) {
        results$key_generation <- FALSE
        results$key_generation_error <- e$message
    })
    
    # Test serialization
    tryCatch({
        serialized <- serialize_simulation_state(test_sim_state)
        deserialized <- deserialize_simulation_state(serialized)
        results$serialization <- identical(deserialized$id, test_sim_state$id)
    }, error = function(e) {
        results$serialization <- FALSE
        results$serialization_error <- e$message
    })
    
    # Test cache write
    tryCatch({
        cache_simulation(test_settings, test_mode, test_sim_state)
        results$cache_write <- TRUE
    }, error = function(e) {
        results$cache_write_error <- e$message
    })
    
    # Test cache check
    if (results$cache_write) {
        tryCatch({
            results$cache_check <- is_simulation_cached(test_settings, test_mode)
        }, error = function(e) {
            results$cache_check_error <- e$message
        })
    }
    
    # Test cache read
    if (results$cache_check) {
        tryCatch({
            cached <- get_simulation_from_cache(test_settings, test_mode)
            results$cache_read <- !is.null(cached) && identical(cached$id, test_sim_state$id)
            
            if (results$cache_read) {
                # Clean up test data
                .CACHE$simulation_cache$remove(results$key)
                results$cleanup <- "Test data removed from cache"
            } else {
                results$cache_read_error <- "Retrieved data doesn't match original"
            }
        }, error = function(e) {
            results$cache_read_error <- e$message
        })
    }
    
    results
}
