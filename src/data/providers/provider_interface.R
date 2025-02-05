#' Provider interface for simulation data access
#' @export
SimulationProvider <- R6::R6Class(
    "SimulationProvider",
    public = list(
        #' Load a simulation set
        #' @param simset_key String in format "location_version_calibration"
        #' @return JHEEM2 simulation set
        #' @throws If simset not found or invalid
        load_simset = function(simset_key) {
            stop("Abstract method: must be implemented by provider")
        },

        #' Check if a simulation set exists
        #' @param simset_key String identifying the simset
        #' @return Boolean indicating existence
        has_simset = function(simset_key) {
            stop("Abstract method: must be implemented by provider")
        },

        #' Get metadata about a simulation set
        #' @param simset_key String identifying the simset
        #' @return List with metadata (version, location, calibration, etc)
        get_simset_metadata = function(simset_key) {
            stop("Abstract method: must be implemented by provider")
        }
    ),
    private = list(
        #' Parse a simset key into its components
        #' @param key String to parse
        #' @return List with location, version, calibration
        parse_simset_key = function(key) {
            parts <- strsplit(key, "_")[[1]]
            list(
                location = parts[1],
                version = parts[2],
                calibration = parts[3]
            )
        },
        validate_simset_key = function(key) {
            if (!is.character(key) || length(key) != 1 || is.na(key)) {
                stop("Simset key must be a single non-NA string")
            }

            parts <- strsplit(key, "_")[[1]]
            if (length(parts) != 3) {
                stop("Simset key must be in format: location_version_calibration")
            }

            TRUE
        }
    )
)
