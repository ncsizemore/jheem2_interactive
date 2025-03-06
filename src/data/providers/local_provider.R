#' Local file system implementation of SimulationProvider
#' @export
LocalProvider <- R6::R6Class(
    "LocalProvider",
    inherit = SimulationProvider,
    public = list(
        root_dir = NULL,
        config = NULL,
        mode = NULL,

        initialize = function(root_dir = NULL, config = NULL, mode = "prerun") {
            # If root_dir is not provided, try to get it from base config
            if (is.null(root_dir)) {
                base_config <- tryCatch({
                    get_base_config()
                }, error = function(e) {
                    list(simulation_root = "simulations")
                })
                
                root_dir <- base_config$simulation_root %||% "simulations"
                print(sprintf("Using simulation root directory from config: %s", root_dir))
            }
            
            self$root_dir <- root_dir
            self$config <- config
            self$mode <- mode
            
            if (!dir.exists(root_dir)) {
                dir.create(root_dir, recursive = TRUE)
            }
            print(sprintf("LocalProvider initialized with mode: %s", mode))
            print("Config:")
            print(str(config))
        },

        #' Load a simulation set based on settings
        #' @param settings List of settings that determine the simulation
        load_simset = function(settings) {
            print("\n=== load_simset ===")
            print("Settings:")
            print(str(settings))
            
            # First check if we're in test mode
            file_path <- private$get_file_path(settings)
            private$load_file(file_path)
        },

        has_simset = function(settings) {
            file_path <- private$get_file_path(settings)
            file.exists(file_path)
        },

        get_simset_metadata = function(settings) {
            file_path <- private$get_file_path(settings)
            defaults_config <- get_defaults_config()
            test_mode <- !is.null(defaults_config$testing) && defaults_config$testing$enabled
            
            if (test_mode) {
                list(
                    test_mode = TRUE,
                    path = file_path
                )
            } else {
                list(
                    settings = settings,
                    path = file_path
                )
            }
        }
    ),
    private = list(
        #' Get the appropriate file path based on mode and settings
        #' @param settings List of settings
        #' @return String file path
        get_file_path = function(settings) {
            print("\n=== get_file_path ===")
            # Check if we're in test mode
            defaults_config <- get_defaults_config()
            print("Defaults config:")
            print(str(defaults_config))
            
            test_mode <- !is.null(defaults_config$testing) && defaults_config$testing$enabled
            print(sprintf("Test mode: %s", test_mode))
            
            if (test_mode) {
                print("In test mode - getting test file")
                test_file <- defaults_config$testing$simulations[[self$mode]]$file
                print(sprintf("Test file: %s", test_file))
                
                # Extract location from test file path to ensure consistent settings
                test_location <- private$extract_location_from_path(test_file)
                if (!is.null(test_location)) {
                    print(sprintf("Extracted test location: %s (original: %s)", 
                                 test_location, settings$location))
                    # Update settings with test location for consistent cache keys
                    settings$location <- test_location
                }
                
                return(file.path(self$root_dir, test_file))
            }
            
            print("Not in test mode - validating settings")
            # Not in test mode - validate settings
            if (is.null(settings) || is.null(settings$location)) {
                stop("Settings with location must be provided when not in test mode")
            }
            
            # Get filename using pattern
            filename <- private$build_filename_from_pattern(settings)
            file.path(self$root_dir, filename)
        },

        #' Build filename from pattern and settings
        #' @param settings List of settings
        #' @return String filename
        build_filename_from_pattern = function(settings) {
            print("\n=== build_filename_from_pattern ===")
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

        #' Load a simulation file
        #' @param file_path Path to .Rdata file
        # Helper to extract location from path
        extract_location_from_path = function(path) {
            # For paths like "test/custom/C.12580_base_test.Rdata"
            # Extract C.12580
            matches <- regmatches(path, regexpr("C\\.[0-9]+", path))
            if (length(matches) > 0) {
                return(matches[1])
            }
            return(NULL)
        },
        
        load_file = function(file_path) {
            print("\n=== load_file ===")
            print(sprintf("Loading file: %s", file_path))
            if (!file.exists(file_path)) {
                stop(paste("Simulation file not found:", file_path))
            }

            tryCatch(
                {
                    simset <- get(load(file_path))
                    return(simset)
                },
                error = function(e) {
                    stop(paste("Error loading simulation:", e$message))
                }
            )
        }
    )
)