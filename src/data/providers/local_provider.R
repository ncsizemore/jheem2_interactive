# Local file system implementation of SimulationProvider
LocalProvider <- R6::R6Class(
    "LocalProvider",
    inherit = SimulationProvider,
    public = list(
        root_dir = NULL,
        initialize = function(root_dir = "simulations") {
            self$root_dir <- root_dir
        },
        load_simset = function(simset_key) {
            file_path <- file.path(self$root_dir, paste0(simset_key, ".Rdata"))
            if (!file.exists(file_path)) {
                stop(paste("Simulation file not found:", file_path))
            }
            get(load(file_path))
        }
    )
)
