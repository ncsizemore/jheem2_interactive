#' Local file system implementation of SimulationProvider
#' @export
LocalProvider <- R6::R6Class(
    "LocalProvider",
    inherit = SimulationProvider,
    public = list(
        root_dir = NULL,
        initialize = function(root_dir = "simulations") {
            self$root_dir <- root_dir
            if (!dir.exists(root_dir)) {
                dir.create(root_dir, recursive = TRUE)
            }
        },

        #' Load a production simulation set
        #' @param simset_key String in format "location_version_calibration"
        load_simset = function(simset_key) {
            private$validate_simset_key(simset_key)

            # Check if simset exists
            if (!self$has_simset(simset_key)) {
                metadata <- private$parse_simset_key(simset_key)
                stop(sprintf(
                    "No simulation set found for location '%s' with version '%s' and calibration '%s'",
                    metadata$location, metadata$version, metadata$calibration
                ))
            }

            private$load_file(private$get_simset_path(simset_key))
        },

        #' Load development test simset (no validation)
        #' @return JHEEM2 simulation set
        load_test_simset = function() {
            test_key <- "C.12580_v1_baseline"
            private$load_file(file.path(self$root_dir, paste0(test_key, ".Rdata")))
        },
        has_simset = function(simset_key) {
            private$validate_simset_key(simset_key)
            file.exists(private$get_simset_path(simset_key))
        },
        get_simset_metadata = function(simset_key) {
            private$validate_simset_key(simset_key)

            # Parse key parts
            parts <- strsplit(simset_key, "_")[[1]]
            list(
                location = parts[1],
                version = parts[2],
                calibration = parts[3],
                path = private$get_simset_path(simset_key)
            )
        }
    ),
    private = list(
        #' Load a simulation file
        #' @param file_path Path to .Rdata file
        load_file = function(file_path) {
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
        },
        get_simset_path = function(key) {
            file.path(self$root_dir, paste0(key, ".Rdata"))
        }
    )
)
