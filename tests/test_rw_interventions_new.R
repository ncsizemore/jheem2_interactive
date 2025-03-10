# Test script for Ryan White interventions using the new approach

# Load required packages
library(jheem2)

# Access internal jheem2 functions
pkg_env <- asNamespace("jheem2")
internal_fns <- ls(pkg_env, all.names = TRUE)
for (fn in internal_fns) {
  if (exists(fn, pkg_env, inherits = FALSE) && is.function(get(fn, pkg_env))) {
    assign(fn, get(fn, pkg_env), envir = .GlobalEnv)
  }
}

# Source required files
source('../jheem_analyses/applications/ryan_white/ryan_white_specification.R')
source('../jheem_analyses/applications/ryan_white/ryan_white_mcmc.R')
source('../jheem_analyses/applications/ryan_white/ryan_white_likelihoods.R')
source('../jheem_analyses/commoncode/locations_of_interest.R')

# Source our model effects
source("src/adapters/interventions/model_effects.R")

# Define the JHEEM.RUN.METADATA class if needed
if (!exists("JHEEM.RUN.METADATA")) {
  JHEEM.RUN.METADATA = R6::R6Class(
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
}

# Create a global WHOLE.POPULATION if needed
if (!exists("WHOLE.POPULATION")) {
  WHOLE.POPULATION <- create.target.population(name = 'Whole Population')
}

# Load the simset
load_simset <- function() {
  simset_path <- "~/Downloads/rw_transmuted_simset.Rdata"
  if (file.exists(simset_path)) {
    message("Loading existing Ryan White simset...")
    return(get(load(simset_path)))
  } else {
    message("Ryan White simset not found. You'll need to create it from an EHE simset.")
    message("Please run the transmutation process first using:")
    message("ehe_simset <- get(load(\"~/Downloads/full.with.covid2_simset_2025-03-04_C.12580.Rdata\"))")
    message("rw_simset <- fit.rw.simset(ehe_simset, verbose=TRUE, track.mcmc=FALSE)")
    message("save(rw_simset, file=\"~/Downloads/rw_transmuted_simset.Rdata\")")
    stop("Simset not found")
  }
}

# Load the simset
simset <- load_simset()

# Verify that the model has the required elements
verify_model <- function(simset) {
  print("Checking if the model contains required elements in quantity.names:")
  
  # Check for the presence of required elements in quantity.names
  required_elements <- c(
    'adap.suppression.effect',
    'oahs.suppression.effect',
    'rw.support.suppression.effect'
  )
  
  # Get the quantity names from the simset
  quantity_names <- simset$jheem.kernel$quantity.names
  
  # Check each required element
  for (element in required_elements) {
    is_present <- element %in% quantity_names
    print(paste(element, ":", is_present))
  }
}

# Verify the model
verify_model(simset)

# Create effects for testing
create_test_effects <- function() {
  message("Creating test effects...")
  
  # Create ADAP effect (10% loss)
  adap_effect <- create_standard_effect(
    quantity_name = "adap.suppression.effect",
    scale = "proportion",
    start_time = 2025.5,
    end_time = 2025.8,
    value = 10,  # 10% loss
    group_id = "adap"
  )
  
  # Create OAHS effect (15% loss)
  oahs_effect <- create_standard_effect(
    quantity_name = "oahs.suppression.effect",
    scale = "proportion",
    start_time = 2025.5,
    end_time = 2025.8,
    value = 15,  # 15% loss
    group_id = "oahs"
  )
  
  # Create Other RW Support effect (20% loss)
  other_effect <- create_standard_effect(
    quantity_name = "rw.support.suppression.effect",
    scale = "proportion",
    start_time = 2025.5,
    end_time = 2025.8,
    value = 20,  # 20% loss
    group_id = "other"
  )
  
  return(list(
    adap = adap_effect,
    oahs = oahs_effect,
    other = other_effect
  ))
}

# Create test intervention
create_test_intervention <- function(effects) {
  message("Creating test intervention...")
  
  # Create combined intervention with all effects
  intervention <- create.intervention(
    WHOLE.POPULATION,  # WHOLE.POPULATION first
    effects$adap, effects$oahs, effects$other,  # Then all effects
    code = "testrwintervention"
  )
  
  return(intervention)
}

# Run the intervention
run_test_intervention <- function(intervention, simset) {
  message("Running test intervention...")
  
  # Create no-intervention baseline for comparison
  no_intervention <- get.null.intervention()
  no_intervention_simset <- no_intervention$run(simset, start.year=2025, end.year=2030, verbose=TRUE)
  
  # Run the test intervention
  intervention_simset <- intervention$run(simset, start.year=2025, end.year=2030, verbose=TRUE)
  
  # Compare results
  compare_results(no_intervention_simset, intervention_simset)
  
  return(list(
    baseline = no_intervention_simset,
    intervention = intervention_simset
  ))
}

# Compare results between baseline and intervention
compare_results <- function(baseline, intervention) {
  message("Comparing results between baseline and intervention...")
  
  # Define years to compare
  years <- 2025:2030
  
  # Pick relevant outcomes to compare
  outcomes <- c("new", "incidence", "adap.suppression", "oahs.suppression")
  
  for (outcome in outcomes) {
    message(paste("\nComparing outcome:", outcome))
    
    # Check if outcome exists in both simsets
    if (!outcome %in% names(baseline) || !outcome %in% names(intervention)) {
      message(paste("Outcome", outcome, "not available in both simsets"))
      next
    }
    
    # Get baseline and intervention data
    baseline_data <- baseline[[outcome]]
    intervention_data <- intervention[[outcome]]
    
    # Get years from dimnames
    years_available <- dimnames(baseline_data)[[1]]
    target_years <- as.character(years)[as.character(years) %in% years_available]
    
    if (length(target_years) == 0) {
      message("No target years available in the data")
      next
    }
    
    # Calculate means for each year (with the correct number of dimensions)
    print("Year-by-year comparison:")
    for (year in target_years) {
      # Calculate means for this year across all other dimensions
      baseline_mean <- mean(baseline_data[year,,,,,,], na.rm=TRUE)
      intervention_mean <- mean(intervention_data[year,,,,,,], na.rm=TRUE)
      
      # Print the comparison
      message(paste("Year", year, ":"))
      print(paste("  Baseline mean:", round(baseline_mean, 4)))
      print(paste("  Intervention mean:", round(intervention_mean, 4)))
      
      # Calculate percent change
      if (!is.na(baseline_mean) && baseline_mean != 0) {
        pct_change <- (intervention_mean - baseline_mean) / baseline_mean * 100
        print(paste("  Percent change:", round(pct_change, 2), "%"))
      } else {
        print("  Percent change: Unable to calculate (baseline is zero or NA)")
      }
    }
  }
}

# Run the complete test
run_complete_test <- function() {
  message("Starting Ryan White intervention test...")
  
  # Create effects
  effects <- create_test_effects()
  
  # Create intervention
  intervention <- create_test_intervention(effects)
  
  # Run intervention
  results <- run_test_intervention(intervention, simset)
  
  message("Ryan White intervention test complete.")
  
  return(results)
}

# Test our custom intervention adapter code
test_custom_intervention <- function() {
  message("Testing custom intervention creation via adapter...")
  
  # Source the intervention adapter
  source("src/adapters/intervention_adapter.R")
  
  # Create mock settings to match app structure
  settings <- list(
    dates = list(
      start = "2025.5",
      end = "2025.8"
    ),
    components = list(
      list(
        list(
          group = "adap",
          type = "suppression_loss",
          value = 10,
          enabled = TRUE
        ),
        list(
          group = "oahs",
          type = "suppression_loss",
          value = 15,
          enabled = TRUE
        ),
        list(
          group = "other",
          type = "suppression_loss",
          value = 20,
          enabled = TRUE
        )
      )
    )
  )
  
  # Create intervention using our adapter
  intervention <- create_custom_intervention(settings, session_id = "testsession")
  
  # Verify the intervention
  print("Created intervention:")
  print(paste("Code:", intervention$code))
  print(paste("Class:", paste(class(intervention), collapse=", ")))
  print(paste("Has run method:", "run" %in% names(intervention)))
  
  # Run intervention
  message("Running adapter-created intervention...")
  intervention_simset <- intervention$run(simset, start.year=2025, end.year=2030, verbose=TRUE)
  
  # Create baseline for comparison
  no_intervention <- get.null.intervention()
  no_intervention_simset <- no_intervention$run(simset, start.year=2025, end.year=2030, verbose=TRUE)
  
  # Compare results
  compare_results(no_intervention_simset, intervention_simset)
  
  message("Custom intervention adapter test complete.")
  
  return(list(
    baseline = no_intervention_simset,
    intervention = intervention_simset
  ))
}

# Uncomment below to run the tests
results <- run_complete_test()
adapter_results <- test_custom_intervention()
