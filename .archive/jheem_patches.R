# jheem_patches.R
# Consolidated workarounds and patches for the jheem2 package

#' Initialize and load all internal jheem2 functions
#' Makes internal functions accessible in the global environment
#' @param force_reload Whether to force reload even if already done
#' @return TRUE if successful
load_jheem_internals <- function(force_reload = FALSE) {
  # Check if we've already loaded internals
  if (!exists("JHEEM_INTERNALS_LOADED") || force_reload) {
    # Make sure jheem2 is loaded
    if (!requireNamespace("jheem2", quietly = TRUE)) {
      stop("The jheem2 package is not installed. Use remotes::install_github('tfojo1/jheem2@dev')")
    }
    
    # Access internal functions
    pkg_env <- asNamespace("jheem2")
    internal_fns <- ls(pkg_env, all.names = TRUE)
    
    message("Loading internal jheem2 functions...")
    count <- 0
    
    for (fn in internal_fns) {
      if (exists(fn, pkg_env, inherits = FALSE) && is.function(get(fn, pkg_env))) {
        assign(fn, get(fn, pkg_env), envir = .GlobalEnv)
        count <- count + 1
      }
    }
    
    message(paste("Loaded", count, "internal jheem2 functions"))
    
    # Mark that we've loaded internals
    assign("JHEEM_INTERNALS_LOADED", TRUE, envir = .GlobalEnv)
    
    # Apply additional patches
    patch_misspelled_functions()
    
    return(TRUE)
  } else {
    message("jheem2 internals already loaded")
    return(FALSE)
  }
}

#' Patch for misspelled functions in the jheem2 package
patch_misspelled_functions <- function() {
  # Fix the misspelled get.intervention.from.code.from.code function
  assign("get.intervention.from.code.from.code", function(code, throw.error.if.missing = TRUE) {
    # Redirect to the correct function
    get.intervention.from.code(code, throw.error.if.missing)
  }, envir = .GlobalEnv)
  
  message("Applied patches for misspelled functions")
}

#' Define required R6 classes that might be missing at runtime
define_required_classes <- function() {
  # Define JHEEM.RUN.METADATA class if needed
  if (!exists("JHEEM.RUN.METADATA")) {
    JHEEM.RUN.METADATA <<- R6::R6Class(
      'jheem.run.metadata',
      
      public = list(
        initialize = function(run.time, preprocessing.time, diffeq.time, postprocessing.time, n.trials) {
          private$i.run.time = run.time
          private$i.preprocessing.time = preprocessing.time
          private$i.diffeq.time = diffeq.time
          private$i.postprocessing.time = postprocessing.time
          private$i.n.trials = n.trials
        },
        
        subset = function(x) {
          JHEEM.RUN.METADATA$new(
            run.time = private$i.run.time[,x, drop=F],
            preprocessing.time = private$i.preprocessing.time[,x, drop=F],
            diffeq.time = private$i.diffeq.time[,x, drop=F],
            postprocessing.time = private$i.postprocessing.time[,x, drop=F],
            n.trials = private$i.n.trials[,x, drop=F]
          )
        }
      ),
      
      active = list(
        run.time = function(value) {
          if (missing(value)) private$i.run.time
          else stop("Cannot modify a run.metadata's 'run.time' - it is read-only")
        },
        
        preprocessing.time = function(value) {
          if (missing(value)) private$i.preprocessing.time
          else stop("Cannot modify a run.metadata's 'preprocessing.time' - it is read-only")
        },
        
        diffeq.time = function(value) {
          if (missing(value)) private$i.diffeq.time
          else stop("Cannot modify a run.metadata's 'diffeq.time' - it is read-only")
        },
        
        postprocessing.time = function(value) {
          if (missing(value)) private$i.postprocessing.time
          else stop("Cannot modify a run.metadata's 'postprocessing.time' - it is read-only")
        },
        
        n.trials = function(value) {
          if (missing(value)) private$i.n.trials
          else stop("Cannot modify a run.metadata's 'n.trials' - it is read-only")
        },
        
        n.sim = function(value) {
          if (missing(value)) dim(private$i.run.time)[2]
          else stop("Cannot modify a run.metadata's 'n.sim' - it is read-only")
        }
      ),
      
      private = list(
        i.run.time = NULL,
        i.preprocessing.time = NULL,
        i.diffeq.time = NULL,
        i.postprocessing.time = NULL,
        i.n.trials = NULL
      )
    )
    
    message("Defined JHEEM.RUN.METADATA class")
  }
  
  # Initialize WHOLE.POPULATION if needed
  if (!exists("WHOLE.POPULATION")) {
    WHOLE.POPULATION <<- create.target.population(name = 'Whole Population')
    message("Initialized global WHOLE.POPULATION target")
  }
}

#' Check if a model contains specific elements
#' Robust version that tries multiple approaches
#' @param simset The simulation set to check
#' @param element_names Vector of element names to check
#' @return Named logical vector indicating existence of each element
check_model_elements <- function(simset, element_names) {
  results <- logical(length(element_names))
  names(results) <- element_names
  
  # Get the first simulation from the simset
  sim <- simset$simulations[[1]]
  
  # Function to check element existence with multiple approaches
  check_element <- function(element_name) {
    tryCatch({
      # Try different methods
      
      # Method 1: Access elements list directly
      if (!is.null(sim$jheem.kernel$model$elements) && 
          is.list(sim$jheem.kernel$model$elements)) {
        if (element_name %in% names(sim$jheem.kernel$model$elements)) {
          return(TRUE)
        }
      }
      
      # Method 2: Use element.exists function if available as method
      if (is.function(sim$jheem.kernel$model$element.exists)) {
        return(sim$jheem.kernel$model$element.exists(element_name))
      }
      
      # Method 3: Try has_element function
      if (is.function(sim$jheem.kernel$model$has_element)) {
        return(sim$jheem.kernel$model$has_element(element_name))
      }
      
      # Method 4: Inspect R6 fields
      if (is.null(sim$jheem.kernel$model[[element_name]])) {
        return(FALSE)
      } else {
        return(TRUE)
      }
      
    }, error = function(e) {
      message("Error checking for element '", element_name, "': ", e$message)
      return(FALSE)
    })
  }
  
  # Check each element
  for (i in seq_along(element_names)) {
    results[i] <- check_element(element_names[i])
  }
  
  return(results)
}

#' Load or create a Ryan White simset with robust error handling
#' @param simset_path Path to look for existing simset
#' @param ehe_simset_path Path to EHE simset for transmutation
#' @param force_transmute Whether to force a new transmutation even if file exists
#' @param interactive Whether to ask for confirmation before transmuting
#' @return The loaded or created Ryan White simset
load_rw_simset <- function(
  simset_path = "~/Downloads/rw_transmuted_simset.Rdata",
  ehe_simset_path = "~/Downloads/full.with.covid2_simset_2025-03-04_C.12580.Rdata",
  force_transmute = FALSE,
  interactive = TRUE
) {
  # Check for existing simset
  if (!force_transmute && file.exists(simset_path)) {
    message("Loading existing Ryan White simset from: ", simset_path)
    result <- tryCatch({
      loaded <- load(simset_path, envir = new.env())
      if (length(loaded) == 0) {
        stop("No objects found in the RData file")
      }
      get(loaded[1], envir = get(loaded))
    }, error = function(e) {
      message("Error loading simset: ", e$message)
      if (interactive) {
        response <- readline(prompt = "Attempt transmutation instead? (y/n): ")
        if (tolower(response) == "y") {
          force_transmute <- TRUE
          return(NULL)
        } else {
          stop("Simset loading cancelled")
        }
      } else {
        stop("Failed to load Ryan White simset")
      }
    })
    
    if (!is.null(result)) {
      return(result)
    }
  }
  
  # Transmute if needed
  if (force_transmute || !file.exists(simset_path)) {
    if (force_transmute) {
      message("Forcing new transmutation...")
    } else {
      message("Ryan White simset not found. Creating from EHE simset...")
    }
    
    # Ask for confirmation before proceeding with transmutation
    if (interactive && !force_transmute) {
      response <- readline(prompt = "Transmutation will take several minutes. Continue? (y/n): ")
      if (tolower(response) != "y") {
        stop("Transmutation cancelled by user.")
      }
    }
    
    # Check if EHE simset exists
    if (!file.exists(ehe_simset_path)) {
      stop("EHE simset not found at: ", ehe_simset_path)
    }
    
    # Load EHE simset
    ehe_env <- new.env()
    loaded_obj <- load(ehe_simset_path, envir = ehe_env)
    if (length(loaded_obj) == 0) {
      stop("No objects found in the EHE simset file")
    }
    ehe_simset <- ehe_env[[loaded_obj[1]]]
    
    # Load required Ryan White code files
    required_files <- c(
      "../jheem_analyses/applications/ryan_white/ryan_white_specification.R",
      "../jheem_analyses/applications/ryan_white/ryan_white_mcmc.R",
      "../jheem_analyses/applications/ryan_white/ryan_white_likelihoods.R",
      "../jheem_analyses/commoncode/locations_of_interest.R"
    )
    
    for (file in required_files) {
      if (!file.exists(file)) {
        stop("Required file not found: ", file)
      }
      message("Sourcing: ", file)
      source(file)
    }
    
    # Perform the transmutation
    message("Transmuting EHE simset to Ryan White simset (this may take several minutes)...")
    rw_simset <- tryCatch({
      fit.rw.simset(ehe_simset, verbose = TRUE, track.mcmc = FALSE)
    }, error = function(e) {
      stop("Error during transmutation: ", e$message)
    })
    
    message("Transmutation complete!")
    
    # Save the result
    message("Saving Ryan White simset to: ", simset_path)
    save(rw_simset, file = simset_path)
    
    return(rw_simset)
  }
}

#' Apply all necessary fixes and patches for JHEEM
#' @param force Whether to force reapplying patches
#' @return TRUE if successful
apply_all_jheem_patches <- function(force = FALSE) {
  # Load internal functions
  load_jheem_internals(force)
  
  # Define required classes
  define_required_classes()
  
  message("All JHEEM patches applied successfully")
  return(TRUE)
}
