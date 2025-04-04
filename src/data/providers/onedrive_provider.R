#' OneDrive implementation of SimulationProvider using sharing links
#' @export
OneDriveProvider <- R6::R6Class(
    "OneDriveProvider",
    inherit = SimulationProvider,
    public = list(
        root_dir = NULL,
        config = NULL,
        mode = NULL,
        sharing_links = NULL,
        temp_dir = NULL,
        cache_manager = NULL,

        #' Initialize the provider
        #' @param root_dir Root directory (model version) for simulation files on OneDrive
        #' @param config Provider configuration
        #' @param mode Mode ("prerun" or "custom")
        initialize = function(root_dir = NULL, config = NULL, mode = "prerun") {
            # If root_dir is not provided, try to get it from base config
            if (is.null(root_dir)) {
                base_config <- tryCatch({
                    get_base_config()
                }, error = function(e) {
                    list(simulation_root = "simulations/ryan-white")
                })
                
                root_dir <- base_config$simulation_root %||% "simulations/ryan-white"
                print(sprintf("[ONEDRIVE] Using simulation root directory from config: %s", root_dir))
            }
            
            self$root_dir <- root_dir
            self$config <- config
            self$mode <- mode
            
            print(sprintf("[ONEDRIVE] OneDriveProvider initialized with mode: %s", mode))
            print("[ONEDRIVE] Config:")
            print(str(config))
            
            # Get unified cache manager (if available)
            tryCatch({
                self$cache_manager <- get_cache_manager()
                print("[ONEDRIVE] Using UnifiedCacheManager for caching")
                
                # Use unified cache path for temp directory
                self$temp_dir <- self$cache_manager$get_onedrive_cache_path()
                print(sprintf("[ONEDRIVE] Using unified cache path: %s", self$temp_dir))
            }, error = function(e) {
                print(sprintf("[ONEDRIVE] UnifiedCacheManager not available: %s", e$message))
                print("[ONEDRIVE] Falling back to temporary directory for caching")
                
                # Fallback to temp directory
                self$temp_dir <- file.path(tempdir(), "onedrive_cache")
                if (!dir.exists(self$temp_dir)) {
                    dir.create(self$temp_dir, recursive = TRUE)
                }
                print(sprintf("[ONEDRIVE] Created temp directory: %s", self$temp_dir))
            })
            
            # Load sharing links configuration
            self$load_sharing_links()
        },

        #' Load sharing links from configuration file
        load_sharing_links = function() {
            # Get config file path from config
            config_file <- self$config$config_file %||% "src/data/providers/onedrive_resources/onedrive_sharing_links.json"
            
            print(sprintf("[ONEDRIVE] Loading sharing links from: %s", config_file))
            
            if (!file.exists(config_file)) {
                stop(sprintf("[ONEDRIVE] Sharing links configuration file not found: %s", config_file))
            }
            
            tryCatch({
                # Read and parse JSON
                links_json <- jsonlite::read_json(config_file)
                
                # Validate format
                if (is.null(links_json$format_version) || is.null(links_json$simulations)) {
                    stop("[ONEDRIVE] Invalid sharing links configuration format")
                }
                
                print(sprintf("[ONEDRIVE] Loaded %d sharing links for model: %s", 
                            length(links_json$simulations), 
                            links_json$model_version %||% "unknown"))
                
                # Store in provider
                self$sharing_links <- links_json
                
            }, error = function(e) {
                stop(sprintf("[ONEDRIVE] Error loading sharing links: %s", e$message))
            })
        },

        #' Load a simulation set based on settings
        #' @param settings List of settings that determine the simulation
        load_simset = function(settings) {
            print("\n=== [ONEDRIVE] load_simset ===")
            print("[ONEDRIVE] Settings:")
            print(str(settings))
            
            # Get file path and corresponding sharing link
            file_info <- private$get_file_info(settings)
            
            if (is.null(file_info) || is.null(file_info$sharing_link)) {
                stop(sprintf("[ONEDRIVE] No sharing link found for settings: %s", 
                           paste(names(settings), collapse = ", ")))
            }
            
            # Download and load the file
            local_path <- private$download_file(file_info$sharing_link, file_info$filename)
            
            if (is.null(local_path)) {
                stop("[ONEDRIVE] Failed to download file")
            }
            
            # Load the file
            simset <- private$load_file(local_path)
            
            # Return the simulation set
            return(simset)
        },

        #' Check if a simulation exists based on settings
        #' @param settings List of settings
        #' @return Boolean indicating if simulation exists
        has_simset = function(settings) {
            file_info <- private$get_file_info(settings)
            return(!is.null(file_info) && !is.null(file_info$sharing_link))
        },

        #' Get metadata about a simulation
        #' @param settings List of settings
        #' @return List with metadata
        get_simset_metadata = function(settings) {
            file_info <- private$get_file_info(settings)
            
            if (is.null(file_info)) {
                return(NULL)
            }
            
            # Get defaults config to check if we're in test mode
            defaults_config <- get_defaults_config()
            test_mode <- !is.null(defaults_config$testing) && defaults_config$testing$enabled
            
            if (test_mode) {
                return(list(
                    test_mode = TRUE,
                    path = file_info$filename,
                    sharing_link = file_info$sharing_link
                ))
            } else {
                return(list(
                    settings = settings,
                    path = file_info$filename,
                    sharing_link = file_info$sharing_link
                ))
            }
        },
        
        #' Clean up temporary files
        #' @param older_than Age in seconds to keep files (default: 1 day)
        cleanup_temp_files = function(older_than = 86400) {
            # If using UnifiedCacheManager, cleanup is handled there
            if (!is.null(self$cache_manager)) {
                print("[ONEDRIVE] Cleanup handled by UnifiedCacheManager")
                return(invisible(NULL))
            }
            
            # Otherwise, use original cleanup logic
            if (!dir.exists(self$temp_dir)) {
                return(invisible(NULL))
            }
            
            # Get all files in temp directory
            temp_files <- list.files(self$temp_dir, full.names = TRUE)
            
            if (length(temp_files) == 0) {
                return(invisible(NULL))
            }
            
            # Get current time
            current_time <- Sys.time()
            
            # Check each file
            for (file_path in temp_files) {
                # Get file info
                file_info <- file.info(file_path)
                
                # Calculate age
                age <- as.numeric(difftime(current_time, file_info$mtime, units = "secs"))
                
                # Remove if older than threshold
                if (age > older_than) {
                    tryCatch({
                        file.remove(file_path)
                        print(sprintf("[ONEDRIVE] Removed old temp file: %s (age: %.1f hours)", 
                                     basename(file_path), age / 3600))
                    }, error = function(e) {
                        print(sprintf("[ONEDRIVE] Error removing temp file: %s", e$message))
                    })
                }
            }
            
            invisible(NULL)
        }
    ),
    private = list(
        #' Get file information based on settings
        #' @param settings List of settings
        #' @return List with filename and sharing_link
        get_file_info = function(settings) {
            print("\n=== [ONEDRIVE] get_file_info ===")
            
            # Check if we have sharing links
            if (is.null(self$sharing_links) || is.null(self$sharing_links$simulations)) {
                stop("[ONEDRIVE] Sharing links not loaded")
            }
            
            # Check if we're in test mode
            defaults_config <- get_defaults_config()
            test_mode <- !is.null(defaults_config$testing) && defaults_config$testing$enabled
            
            if (test_mode) {
                print("[ONEDRIVE] In test mode - getting test file")
                test_file <- defaults_config$testing$simulations[[self$mode]]$file
                print(sprintf("[ONEDRIVE] Test file: %s", test_file))
                
                # Extract location from test file path for consistency
                test_location <- private$extract_location_from_path(test_file)
                if (!is.null(test_location)) {
                    settings$location <- test_location
                }
                
                # Look for a matching test file in sharing links
                test_filename <- basename(test_file)
                test_path <- dirname(test_file)
                
                # Try to find matching key in sharing links
                for (key in names(self$sharing_links$simulations)) {
                    sim_info <- self$sharing_links$simulations[[key]]
                    
                    # Debug sharing links
                    print(sprintf("[ONEDRIVE] Checking sim_info for key: %s", key))
                    print(str(sim_info))
                    
                    # Check if the filename matches
                    if (!is.null(sim_info$filename) && endsWith(sim_info$filename, test_filename)) {
                        # Debug match
                        print(sprintf("[ONEDRIVE] Found match: %s -> %s", sim_info$filename, test_filename))
                        print("[ONEDRIVE] Returning info:")
                        result <- list(
                            key = key,
                            filename = test_filename,
                            sharing_link = sim_info$sharing_link
                        )
                        print(str(result))
                        return(result)
                    }
                }
                
                # If not found, return NULL
                print(sprintf("[ONEDRIVE] Test file not found in sharing links: %s", test_file))
                return(NULL)
            }
            
            # Not in test mode - validate settings
            if (is.null(settings) || is.null(settings$location)) {
                stop("[ONEDRIVE] Settings with location must be provided when not in test mode")
            }
            
            # Generate a filename based on the mode and pattern
            if (self$mode == "prerun") {
                # Get the pattern from config
                if (is.null(self$config) || is.null(self$config$file_pattern)) {
                    stop("[ONEDRIVE] No file pattern configured for prerun mode")
                }
                
                # Generate filename using pattern
                filename <- private$build_filename_from_pattern(settings)
                print(sprintf("[ONEDRIVE] Generated filename: %s", filename))
                
                # Try different approaches to find the sharing link
                
                # Approach 1: Try direct key lookup
                # For Ryan White model, this would be e.g., "C.12580_permanent_loss"
                location_key <- paste0(settings$location, "_", settings$scenario)
                if (!is.null(self$sharing_links$simulations[[location_key]])) {
                    sim_info <- self$sharing_links$simulations[[location_key]]
                    return(list(
                        key = location_key,
                        filename = basename(sim_info$filename),
                        sharing_link = sim_info$sharing_link
                    ))
                }
                
                # Approach 2: Search by filename match
                # This handles the pattern-based filenames
                for (key in names(self$sharing_links$simulations)) {
                    sim_info <- self$sharing_links$simulations[[key]]
                    
                    # Check if filename matches or ends with our generated filename
                    if (!is.null(sim_info$filename) && 
                        (sim_info$filename == filename || endsWith(sim_info$filename, filename))) {
                        return(list(
                            key = key,
                            filename = basename(sim_info$filename),
                            sharing_link = sim_info$sharing_link
                        ))
                    }
                }
                
                # Not found
                print(sprintf("[ONEDRIVE] No sharing link found for filename: %s", filename))
                return(NULL)
                
            } else if (self$mode == "custom") {
                # For custom mode, we need the base simulation file
                # This is typically named like "C.12580_base.Rdata"
                base_key <- paste0(settings$location, "_base")
                
                if (!is.null(self$sharing_links$simulations[[base_key]])) {
                    sim_info <- self$sharing_links$simulations[[base_key]]
                    return(list(
                        key = base_key,
                        filename = basename(sim_info$filename),
                        sharing_link = sim_info$sharing_link
                    ))
                }
                
                # Try to find by location and base in filename
                for (key in names(self$sharing_links$simulations)) {
                    sim_info <- self$sharing_links$simulations[[key]]
                    
                    # Check if the filename contains the location and "base"
                    if (!is.null(sim_info$filename) && 
                        grepl(settings$location, sim_info$filename, fixed = TRUE) && 
                        grepl("base", sim_info$filename, fixed = TRUE)) {
                        return(list(
                            key = key,
                            filename = basename(sim_info$filename),
                            sharing_link = sim_info$sharing_link
                        ))
                    }
                }
                
                # Not found
                print(sprintf("[ONEDRIVE] No base simulation found for location: %s", settings$location))
                return(NULL)
            }
            
            # Default - not found
            return(NULL)
        },

        #' Build a filename from pattern and settings
        #' @param settings List of settings
        #' @return String filename
        build_filename_from_pattern = function(settings) {
            print("\n=== [ONEDRIVE] build_filename_from_pattern ===")
            # Get pattern from config
            if (is.null(self$config) || is.null(self$config$file_pattern)) {
                stop(sprintf("No file pattern configured for %s mode", self$mode))
            }
            
            # Extract all placeholders from pattern {xyz}
            placeholders <- regmatches(
                self$config$file_pattern,
                gregexpr("\\{([^}]+)\\}", self$config$file_pattern)
            )[[1]]
            
            # Strip the braces
            selector_names <- gsub("[{}]", "", placeholders)
            
            # For custom mode, we only expect location
            if (self$mode == "custom") {
                if (!identical(selector_names, "location")) {
                    stop("Custom mode file pattern should only contain {location}")
                }
            } else {
                # For prerun, validate against selectors in the config
                config <- get_page_complete_config("prerun")
                
                # Get all valid selector IDs from the config (plus 'location' which is always valid)
                valid_selectors <- c("location", names(config$selectors))
                
                # Check that all our selectors correspond to config sections
                invalid_selectors <- setdiff(selector_names, valid_selectors)
                if (length(invalid_selectors) > 0) {
                    stop(sprintf(
                        "Invalid selectors in file pattern: %s. Valid selectors are: %s",
                        paste(invalid_selectors, collapse=", "),
                        paste(valid_selectors, collapse=", ")
                    ))
                }
            }
            
            # Replace each placeholder
            filename <- self$config$file_pattern
            for (selector in selector_names) {
                value <- settings[[selector]]
                if (is.null(value)) {
                    stop(sprintf("No value provided for required selector: %s", selector))
                }
                filename <- gsub(
                    sprintf("\\{%s\\}", selector),
                    value,
                    filename
                )
            }
            
            # Add .Rdata extension if not present
            if (!grepl("\\.Rdata$", filename)) {
                filename <- paste0(filename, ".Rdata")
            }
            
            filename
        },

        #' Download a file from a sharing link
        #' @param sharing_link OneDrive sharing link
        #' @param filename Filename to use for the downloaded file
        #' @return Path to downloaded file or NULL on failure
        download_file = function(sharing_link, filename) {
            # Debug the arguments
            print(sprintf("[ONEDRIVE] download_file called with sharing_link type: %s, class: %s", 
                         typeof(sharing_link), paste(class(sharing_link), collapse=",")))
            print(sprintf("[ONEDRIVE] sharing_link value: %s", 
                         if(is.list(sharing_link)) "LIST STRUCTURE" else as.character(sharing_link)))
            if (is.list(sharing_link)) {
                print("[ONEDRIVE] sharing_link contents:")
                print(str(sharing_link))
            }
            print(sprintf("[ONEDRIVE] filename type: %s, class: %s", 
                         typeof(filename), paste(class(filename), collapse=",")))
            print(sprintf("[ONEDRIVE] filename value: %s", filename))

            # Use UnifiedCacheManager if available
            if (!is.null(self$cache_manager)) {
                print(sprintf("[ONEDRIVE] Using UnifiedCacheManager to download: %s", filename))
                
                # Handle case where sharing_link is a list
                if (is.list(sharing_link) && !is.null(sharing_link$sharing_link)) {
                    sharing_link <- sharing_link$sharing_link
                }
                
                # Call UnifiedCacheManager's download_file method (no progress callback needed)
                print("[ONEDRIVE] Calling UnifiedCacheManager download_file method")
                result <- self$cache_manager$download_file(sharing_link, filename)
                print(sprintf("[ONEDRIVE] download_file result: %s", result))
                return(result)
            }
            
            # Fallback to original implementation
            print(sprintf("[ONEDRIVE] Downloading file: %s", filename))
            
            # Create temporary file path
            temp_file <- file.path(self$temp_dir, filename)
            
            # TEMP FIX: Always download a fresh copy, skipping the cache check
            print(sprintf("[ONEDRIVE] Bypassing cache check for: %s", temp_file))
            # Removing cache check to ensure fresh downloads every time
            if (file.exists(temp_file)) {
                print(sprintf("[ONEDRIVE] Removing existing cached file: %s", temp_file))
                file.remove(temp_file)
            }
            
            # Ensure the sharing link has the correct download parameter
            if (!grepl("\\?download=1", sharing_link)) {
                if (grepl("\\?", sharing_link)) {
                    sharing_link <- paste0(sharing_link, "&download=1")
                } else {
                    sharing_link <- paste0(sharing_link, "?download=1")
                }
            }
            
            # Add a cache buster to avoid CDN caching
            sharing_link <- paste0(sharing_link, "&_cb=", as.integer(Sys.time()))
            
            # Download the file
            print(sprintf("[ONEDRIVE] Downloading from: %s", sharing_link))
            
            tryCatch({
                # Ensure the directory exists
                dir.create(dirname(temp_file), recursive = TRUE, showWarnings = FALSE)
                
                # Download the file
                utils::download.file(
                    url = sharing_link,
                    destfile = temp_file,
                    mode = "wb",  # Binary mode for cross-platform compatibility
                    quiet = FALSE,
                    method = "auto"
                )
                
                # Check if download was successful
                if (file.exists(temp_file) && file.info(temp_file)$size > 0) {
                    print(sprintf("[ONEDRIVE] Download successful: %s (%.2f MB)", 
                                 filename, file.info(temp_file)$size / 1e6))
                    return(temp_file)
                } else {
                    print("[ONEDRIVE] Download failed: file empty or missing")
                    return(NULL)
                }
            }, error = function(e) {
                print(sprintf("[ONEDRIVE] Download error: %s", e$message))
                
                # Try fallback without download parameter
                print("[ONEDRIVE] Trying fallback download without download parameter")
                
                # Remove download parameter and cache buster
                clean_link <- sub("\\?download=1.*$", "", sharing_link)
                clean_link <- sub("&download=1.*$", "", clean_link)
                
                tryCatch({
                    utils::download.file(
                        url = clean_link,
                        destfile = temp_file,
                        mode = "wb",
                        quiet = FALSE,
                        method = "auto"
                    )
                    
                    if (file.exists(temp_file) && file.info(temp_file)$size > 0) {
                        print(sprintf("[ONEDRIVE] Fallback download successful: %s", filename))
                        return(temp_file)
                    } else {
                        print("[ONEDRIVE] Fallback download failed: file empty or missing")
                        return(NULL)
                    }
                }, error = function(e2) {
                    print(sprintf("[ONEDRIVE] Fallback download error: %s", e2$message))
                    return(NULL)
                })
                
                return(NULL)
            })
        },

        #' Helper to extract location from path
        #' @param path File path
        #' @return Extracted location code or NULL
        extract_location_from_path = function(path) {
            # For paths like "test/custom/C.12580_base_test.Rdata"
            # Extract C.12580
            matches <- regmatches(path, regexpr("C\\.[0-9]+", path))
            if (length(matches) > 0) {
                return(matches[1])
            }
            return(NULL)
        },
        
        #' Load a simulation file
        #' @param file_path Path to .Rdata file
        #' @return Loaded simulation set
        load_file = function(file_path) {
            print("\n=== [ONEDRIVE] load_file ===")
            print(sprintf("[ONEDRIVE] Loading file: %s", file_path))
            
            if (!file.exists(file_path)) {
                stop(paste("[ONEDRIVE] Simulation file not found:", file_path))
            }

            tryCatch(
                {
                    simset <- get(load(file_path))
                    return(simset)
                },
                error = function(e) {
                    stop(paste("[ONEDRIVE] Error loading simulation:", e$message))
                }
            )
        }
    )
)
