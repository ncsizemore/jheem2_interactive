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
            
            # Added debugging
            cat("*** INTERVENTION RUN DEBUG ***\n")
            cat("Intervention class:", paste(class(intervention), collapse=", "), "\n")
            cat("Has run method:", "run" %in% names(intervention), "\n")
            
            # Check effect structure
            if (!is.null(intervention$effects)) {
                cat("Number of effects:", length(intervention$effects), "\n")
                for (i in seq_along(intervention$effects)) {
                    effect <- intervention$effects[[i]]
                    cat("Effect", i, "type:", paste(class(effect), collapse=", "), "\n")
                    cat("Effect", i, "quantity:", effect$quantity.name, "\n")
                    
                    # Check times attribute
                    if (!is.null(effect$times)) {
                        cat("Effect", i, "times:", paste(effect$times, collapse=", "), "\n")
                        cat("Effect", i, "times class:", class(effect$times), "\n")
                        cat("Effect", i, "times length:", length(effect$times), "\n")
                    } else {
                        cat("Effect", i, "times: NULL\n")
                    }
                    
                    # Check effect values
                    if (is.language(effect$effect.values)) {
                        cat("Effect", i, "values: (expression)", deparse(effect$effect.values), "\n")
                    } else {
                        cat("Effect", i, "values:", paste(effect$effect.values, collapse=", "), "\n")
                        cat("Effect", i, "values class:", class(effect$effect.values), "\n")
                        cat("Effect", i, "values length:", length(effect$effect.values), "\n")
                    }
                    
                    # Check other important attributes
                    cat("Effect", i, "scale:", effect$scale, "\n")
                    cat("Effect", i, "start.time:", effect$start.time, "\n")
                    if (!is.null(effect$end.time)) {
                        cat("Effect", i, "end.time:", effect$end.time, "\n")
                    }
                }
            }

            # Run intervention with more error trapping
            tryCatch(
                {
                    if (is.function(intervention$run)) {
                        cat("About to call intervention$run()...\n")
                        # Try capturing and printing more info about any error
                        withCallingHandlers(
                            intervention$run(simset,
                                start.year = start_year,
                                end.year = end_year,
                                verbose = verbose
                            ),
                            error = function(e) {
                                cat("Error in intervention$run:", conditionMessage(e), "\n")
                                cat("Error call:", deparse(conditionCall(e)), "\n")
                                if (!is.null(e$call)) {
                                    cat("Error call detail:", deparse(e$call), "\n")
                                }
                            }
                        )
                    } else {
                        cat("ERROR: intervention$run is not a function\n")
                        stop("Intervention does not have a run method")
                    }
                },
                error = function(e) {
                    stop(sprintf("Error running intervention: %s", e$message))
                }
            )
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
