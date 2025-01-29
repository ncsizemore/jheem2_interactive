# Provider interface for simulation data access
SimulationProvider <- R6::R6Class(
    "SimulationProvider",
    public = list(
        load_simset = function(simset_key) {
            stop("Abstract method: must be implemented by provider")
        }
    )
)
