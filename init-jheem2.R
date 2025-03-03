# Initialize jheem2 by sourcing all components

# If debug_log function exists, use it; otherwise create a simple version
if (!exists("debug_log")) {
  debug_log <- function(msg) {
    message(msg)
    # Also write to a file
    cat(paste0(Sys.time(), ": ", msg, "\n"), file = "jheem2_init_log.txt", append = TRUE)
  }
  # Start fresh log
  if (file.exists("jheem2_init_log.txt")) file.remove("jheem2_init_log.txt")
  debug_log("Starting jheem2 initialization")
}
# This is a modified version of source_jheem2_package.R adjusted for local paths

if (!exists("JHEEM2.FUNCTION.NAMES"))
    JHEEM2.FUNCTION.NAMES = character()

PRE.SOURCE.JHEEM2.FUNCTION.NAMES = names(get(".GlobalEnv"))[sapply(get(".GlobalEnv"), is.function)]

# Adjust base paths to use local vendor directory
R_BASE = "vendor/jheem2/R"
SRC_BASE = "vendor/jheem2/src"

# Define a safe source function that logs errors
safe_source <- function(file_path) {
  debug_log(paste("Sourcing file:", file_path))
  if (!file.exists(file_path)) {
    debug_log(paste("ERROR: File does not exist:", file_path))
    return(FALSE)
  }
  
  tryCatch({
    source(file_path)
    debug_log(paste("Successfully sourced:", file_path))
    return(TRUE)
  }, error = function(e) {
    debug_log(paste("ERROR sourcing file:", file_path, "-", e$message))
    return(FALSE)
  })
}

# Define a safe Rcpp source function
safe_rcpp_source <- function(file_path) {
  debug_log(paste("Sourcing Rcpp file:", file_path))
  if (!file.exists(file_path)) {
    debug_log(paste("ERROR: Rcpp file does not exist:", file_path))
    return(FALSE)
  }
  
  tryCatch({
    Rcpp::sourceCpp(file_path)
    debug_log(paste("Successfully sourced Rcpp file:", file_path))
    return(TRUE)
  }, error = function(e) {
    debug_log(paste("ERROR sourcing Rcpp file:", file_path, "-", e$message))
    return(FALSE)
  })
}

# Source all files with adjusted paths
debug_log("Starting to source jheem2 files")

safe_source(file.path(R_BASE, "FILE_MANAGER_file_manager.R"))
safe_source(file.path(R_BASE, "ONTOLOGY_ontology_mappings.R"))
safe_rcpp_source(file.path(SRC_BASE, "ontology_mappings.cpp"))

source(file.path(R_BASE, "HELPERS_misc_helpers.R"))
source(file.path(R_BASE, "HELPERS_dim_names_helpers.R"))
source(file.path(R_BASE, "HELPERS_array_helpers.R"))
source(file.path(R_BASE, "HELPERS_age_year_helpers.R"))
source(file.path(R_BASE, "HELPERS_bundle_function.R"))
Rcpp::sourceCpp(file.path(SRC_BASE, "array_helpers.cpp"))

source(file.path(R_BASE, "ONTOLOGY_ontology.R"))
source(file.path(R_BASE, "ONTOLOGY_ontology_mappings.R"))
source(file.path(R_BASE, "JHEEM_outcome_location_mappings.R"))

source(file.path(R_BASE, "SPECIFICATION_links.R"))
source(file.path(R_BASE, "SPECIFICATION_metadata.R"))
source(file.path(R_BASE, "SPECIFICATION_scales.R"))
source(file.path(R_BASE, "SPECIFICATION_model_specification.R"))
source(file.path(R_BASE, "SPECIFICATION_compiled_specification.R"))

source(file.path(R_BASE, "SPECIFICATION_functional_forms.R"))
source(file.path(R_BASE, "SPECIFICATION_functional_form_alphas.R"))
Rcpp::sourceCpp(file.path(SRC_BASE, "functional_forms.cpp"))
source(file.path(R_BASE, "SPECIFICATION_evaluatable_value.R"))

source(file.path(R_BASE, "VERSIONS_version_manager.R"))

source(file.path(R_BASE, "INTERVENTIONS_target_populations.R"))
source(file.path(R_BASE, "INTERVENTIONS_intervention_effects.R"))
source(file.path(R_BASE, "INTERVENTIONS_main.R"))
source(file.path(R_BASE, "INTERVENTIONS_foreground.R"))
source(file.path(R_BASE, "INTERVENTIONS_criteria_based.R"))

source(file.path(R_BASE, "JHEEM_entity.R"))
source(file.path(R_BASE, "JHEEM_diffeq_interface.R"))
source(file.path(R_BASE, "JHEEM_engine.R"))
source(file.path(R_BASE, "JHEEM_transmutation.R"))
Rcpp::sourceCpp(file.path(SRC_BASE, "engine_helpers.cpp"))
Rcpp::sourceCpp(file.path(SRC_BASE, "engine_optimizations.cpp"))
Rcpp::sourceCpp(file.path(SRC_BASE, "diffeq.cpp"))
Rcpp::sourceCpp(file.path(SRC_BASE, "outcomes.cpp"))

source(file.path(R_BASE, "JHEEM_run_metadata.R"))
source(file.path(R_BASE, "JHEEM_kernel.R"))
source(file.path(R_BASE, "JHEEM_simulation.R"))
source(file.path(R_BASE, "JHEEM_simset_collection.R"))
Rcpp::sourceCpp(file.path(SRC_BASE, "simulation_helpers.cpp"))

source(file.path(R_BASE, "DATA_MANAGER_data_manager.R"))
source(file.path(R_BASE, "PLOTS_simplot.R"))
source(file.path(R_BASE, "PLOTS_style_manager.R"))

source(file.path(R_BASE, "LIKELIHOODS_basic_likelihood.R"))
source(file.path(R_BASE, "LIKELIHOODS_basic_ratio_likelihood.R"))
source(file.path(R_BASE, "LIKELIHOODS_main.R"))
source(file.path(R_BASE, "LIKELIHOODS_joint_likelihood.R"))
source(file.path(R_BASE, "LIKELIHOODS_nested_proportion_likelihood.R"))
source(file.path(R_BASE, "LIKELIHOODS_bernoulli_likelihood.R"))
source(file.path(R_BASE, "LIKELIHOODS_ifelse_likelihood_instructions.R"))
source(file.path(R_BASE, "LIKELIHOODS_custom_likelihood.R"))
Rcpp::sourceCpp(file.path(SRC_BASE, "correlation_matrix_helpers.cpp"))
Rcpp::sourceCpp(file.path(SRC_BASE, "likelihood_helpers.cpp"))
Rcpp::sourceCpp(file.path(SRC_BASE, "nested_proportion_likelihood.cpp"))

source(file.path(R_BASE, "CALIBRATION_main.R"))

Rcpp::sourceCpp(file.path(SRC_BASE, "misc_helpers.cpp"))
Rcpp::sourceCpp(file.path(SRC_BASE, "lag_matrix.cpp"))

source(file.path(R_BASE, "DEBUGGING_error_manager.R"))

# Track all jheem2 functions that were added to the environment
JHEEM2.FUNCTION.NAMES = union(JHEEM2.FUNCTION.NAMES,
                            setdiff(names(get(".GlobalEnv"))[sapply(get(".GlobalEnv"), is.function)],
                                   PRE.SOURCE.JHEEM2.FUNCTION.NAMES))

cat("jheem2 initialized successfully via source methods\n")