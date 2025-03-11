# test_ryan_white_intervention.R

# Load required packages
library(jheem2)
pkg_env <- asNamespace("jheem2")
internal_fns <- ls(pkg_env, all.names = TRUE)

for (fn in internal_fns) {
  if (exists(fn, pkg_env, inherits = FALSE) && is.function(get(fn, pkg_env))) {
    assign(fn, get(fn, pkg_env), envir = .GlobalEnv)
  }
}

get.intervention.from.code.from.code <- function(code, throw.error.if.missing = TRUE) {
  # WORKAROUND: This function is misspelled in the JHEEM2 package
  # Redirect to the correct function
  jheem2:::get.intervention.from.code(code, throw.error.if.missing)
}

source('../jheem_analyses/applications/ryan_white/ryan_white_specification.R')
source('../jheem_analyses/applications/ryan_white/ryan_white_mcmc.R')
source('../jheem_analyses/applications/ryan_white/ryan_white_likelihoods.R')
source('../jheem_analyses/commoncode/locations_of_interest.R')

# Define the JHEEM.RUN.METADATA class
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

# Load EHE simset
ehe_simset <- get(load("~/Downloads/full.with.covid2_simset_2025-03-04_C.12580.Rdata"))

# Transmute EHE simset to RW simset
print("Transmuting EHE simset to Ryan White simset (this may take a few minutes)...")
rw_simset <- fit.rw.simset(ehe_simset, verbose=TRUE, track.mcmc=FALSE)
print("Transmutation complete!")

# Save the transmuted simset for future use
rw_simset$save()
save(rw_simset, file="~/Downloads/rw_transmuted_simset.Rdata")

# Use the RW simset for interventions
simset <- rw_simset

# Create WHOLE.POPULATION target
WHOLE.POPULATION = create.target.population(name = 'Whole Population')

no.intervention = get.null.intervention()
no.intervention.simset = no.intervention$run(simset, start.year=2025, end.year=2035, verbose=T)

# Create effects for all three quantities
adap_effect <- create.intervention.effect(
  quantity.name = 'adap.suppression.effect',
  start.time = 2025.5,
  effect.values = 0.9, # 10% loss -> 0.9 effect value
  apply.effects.as = 'value',
  scale = 'proportion',
  times = 2025.8,
  allow.values.less.than.otherwise = T,
  allow.values.greater.than.otherwise = F
)

# Create the other effects similarly
# ...

# Create combined intervention
combined_intervention <- create.intervention(
  adap_effect, #oahs_effect, rw_support_effect,
  WHOLE.POPULATION,
  code = "testIntervention"
)

# Run the intervention
result_simset <- combined_intervention$run(simset, start.year=2025, end.year=2026, verbose=T)

# Verify results by comparing with baseline
# Check specific outcomes to confirm intervention worked

# Diagnostic checks to confirm the model has the required elements
print("Checking if the model contains 'adap.suppression.effect':")
print(simset$simulations[[1]]$jheem.kernel$model$element.exists('adap.suppression.effect'))

# Display some results
print("Intervention run complete! Displaying results comparison:")

# Define a function to extract and compare key outcomes
compare_outcomes <- function(baseline, intervention) {
  # Example comparison - adjust to relevant outcomes for your model
  baseline_new_dx <- baseline$get.quantity('new.hiv.diagnoses', years=2025:2026)
  intervention_new_dx <- intervention$get.quantity('new.hiv.diagnoses', years=2025:2026)
  
  # Print summary
  print("Baseline new diagnoses:")
  print(baseline_new_dx$summary())
  print("Intervention new diagnoses:")
  print(intervention_new_dx$summary())
}

# Compare outcomes between baseline and intervention
compare_outcomes(no.intervention.simset, result_simset)
