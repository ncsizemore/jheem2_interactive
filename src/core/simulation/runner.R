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
    #' @param start_year Optional start year for simulation
    #' @param end_year Optional end year for simulation
    #' @param verbose Whether to print verbose output
    #' @param progress_callback Optional function to report progress
    run_intervention = function(intervention, simset,
                               start_year = NULL,
                               end_year = NULL,
                               verbose = TRUE,
                               progress_callback = NULL) {
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
          # Create listener function that wraps our progress_callback if provided
          listener <- NULL
          if (!is.null(progress_callback)) {
            listener <- function(index, total, done) {
              # Call the progress callback with current state
              progress_callback(index, total, done)
            }
          }
          
          # Run the intervention with the listener
          intervention$run(simset,
                          start.year = start_year,
                          end.year = end_year,
                          verbose = verbose,
                          listener = listener)
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
    #' @param start_year Optional start year for simulation
    #' @param end_year Optional end year for simulation
    #' @param verbose Whether to print verbose output
    #' @param progress_callback Optional function to report progress
    run_scenario = function(interventions, simset,
                           start_year = NULL,
                           end_year = NULL,
                           verbose = TRUE,
                           progress_callback = NULL) {
      # Validate inputs
      if (!is.list(interventions) || length(interventions) == 0) {
        stop("Interventions must be a non-empty list")
      }
      if (is.null(simset)) stop("Simulation set cannot be null")
      
      # Copy simset to avoid modifying original
      current_simset <- copy.simulation.set(simset)
      
      # Run each intervention sequentially
      # Get total count for progress tracking
      total_interventions <- length(interventions)
      
      for (i in seq_along(interventions)) {
        intervention <- interventions[[i]]
        
        # Create intervention-specific progress callback that wraps the main one
        intervention_progress <- NULL
        if (!is.null(progress_callback)) {
          intervention_progress <- function(index, total, done) {
            # Calculate overall progress
            # Each intervention gets an equal portion of the overall progress
            overall_index <- (i - 1) * total + index
            overall_total <- total_interventions * total
            
            # Call the main progress callback with the adjusted values
            progress_callback(overall_index, overall_total, done && i == total_interventions)
          }
        }
        
        current_simset <- self$run_intervention(
          intervention = intervention,
          simset = current_simset,
          start_year = start_year,
          end_year = end_year,
          verbose = verbose,
          progress_callback = intervention_progress
        )
      }
      
      current_simset
    }
  )
)
