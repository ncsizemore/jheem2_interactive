#' Run simulations with interventions
#' @param provider SimulationProvider instance for data access
#' @export
SimulationRunner <- R6::R6Class(
  "SimulationRunner",
  public = list(
    provider = NULL,
    initialize = function(provider) {
      self$provider <- provider
    },
    
    #' Load a simulation set
    #' @param simset_key String identifying the simset
    #' @return JHEEM2 simulation set
    load_simset = function(simset_key) {
      self$provider$load_simset(simset_key)
    },
    
    #' Run a single intervention
    #' @param intervention JHEEM2 intervention object
    #' @param simset JHEEM2 simulation set
    run_intervention = function(intervention, simset,
                               start_year = NULL,
                               end_year = NULL,
                               verbose = TRUE) {
      # Validate inputs
      if (is.null(intervention)) stop("Intervention cannot be null")
      if (is.null(simset)) stop("Simulation set cannot be null")
      
      # Copy simset to avoid modifying original
      simset <- copy.simulation.set(simset)
      
      # Check if this is a NULL intervention
      if (is(intervention, "null.intervention")) {
        if (verbose) {
          cat("Using null intervention - returning original simset\n")
        }
        return(simset)
      }
      
      # Basic validation of intervention structure
      if (verbose) {
        cat("Running intervention:", intervention$code, "\n")
        if (!is.null(intervention$effects)) {
          cat("Intervention has", length(intervention$effects), "effects\n")
        } else if (!is.null(intervention$foregrounds)) {
          cat("Intervention has", length(intervention$foregrounds), "foregrounds\n")
        }
      }
      
      # Run intervention
      tryCatch({
        if (is.function(intervention$run)) {
          intervention$run(simset,
                          start.year = start_year,
                          end.year = end_year,
                          verbose = verbose)
        } else {
          stop("Intervention does not have a run method")
        }
      }, error = function(e) {
        stop(sprintf("Error running intervention: %s", e$message))
      })
    },
    
    #' Run multiple interventions sequentially
    #' @param interventions List of JHEEM2 intervention objects
    #' @param simset JHEEM2 simulation set
    run_scenario = function(interventions, simset,
                           start_year = NULL,
                           end_year = NULL,
                           verbose = TRUE) {
      # Validate inputs
      if (!is.list(interventions) || length(interventions) == 0) {
        stop("Interventions must be a non-empty list")
      }
      if (is.null(simset)) stop("Simulation set cannot be null")
      
      # Copy simset to avoid modifying original
      current_simset <- copy.simulation.set(simset)
      
      # Run each intervention sequentially
      for (intervention in interventions) {
        current_simset <- self$run_intervention(
          intervention = intervention,
          simset = current_simset,
          start_year = start_year,
          end_year = end_year,
          verbose = verbose
        )
      }
      
      current_simset
    }
  )
)
