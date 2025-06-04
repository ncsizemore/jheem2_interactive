#!/usr/bin/env Rscript

# atomic_plot_generator_extracted.R
# This script generates atomic plots that EXACTLY match the app's plots
# by directly using the exact code extracted from plot_panel.R.

# Load necessary libraries
suppressPackageStartupMessages({
  library(plotly)
  library(jheem2)
  library(argparse)
  library(yaml)
  library(ggplot2)
  library(htmlwidgets)
  library(jsonlite)
  library(locations) # For get.location.name
})

# Export all jheem2 internal functions to the global environment
pkg_env <- asNamespace("jheem2")
internal_fns <- ls(pkg_env, all.names = TRUE)
for (fn in internal_fns) {
  if (exists(fn, pkg_env, inherits = FALSE) && is.function(get(fn, pkg_env))) {
    assign(fn, get(fn, pkg_env), envir = .GlobalEnv)
  }
}

# Source required utils and our extracted components
tryCatch({
  source("src/utils/simplot_local_mods.R")
  source("src/utils/plotting_local.R")
  source("src/ui/config/load_config.R")
  source("src/ui/components/common/display/plot_panel.R") # For helper functions
  source("plot_data_preparation.R")  # Our extracted data prep logic
  source("plot_rendering.R")         # Our extracted rendering logic
  source("baseline_loading.R")       # Our direct baseline loading
}, error = function(e) {
  cat(sprintf("Error sourcing required files: %s\n", e$message))
  quit(status = 1)
})

# Set up logging
log_to_file <- function(message, debug = FALSE) {
  if (debug) {
    timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    message <- sprintf("[%s] %s", timestamp, message)
  }
  cat(message, "\n")
}

# Create argument parser
parser <- ArgumentParser(description = "Generate atomic plots matching app exactly")
parser$add_argument("--city", type = "character", required = TRUE, help = "City to plot (e.g., C.12580)")
parser$add_argument("--scenario", type = "character", required = TRUE, help = "Scenario to plot (e.g., cessation)")
parser$add_argument("--outcome", type = "character", required = TRUE, help = "Outcome to plot (e.g., incidence)")
parser$add_argument("--statistic_type", type = "character", required = TRUE, help = "Statistic type to plot (e.g., mean.and.interval)")
parser$add_argument("--facet_choice", type = "character", required = TRUE, help = "Facet choice to plot (e.g., sex or None)")
parser$add_argument("--output_dir", type = "character", default = "plots", help = "Directory to save plots")
parser$add_argument("--debug", action = "store_true", default = FALSE, help = "Enable debug mode")
parser$add_argument("--selfcontained", action = "store_true", default = FALSE, help = "Generate selfcontained HTML (requires pandoc)")

# Parse arguments
args <- parser$parse_args()

# Function to generate output path
generate_output_path <- function(city, scenario, outcome, statistic_type, facet_choice, output_dir) {
  # Create directory structure: output_dir/city/scenario/
  city_dir <- file.path(output_dir, city)
  scenario_dir <- file.path(city_dir, scenario)
  
  if (!dir.exists(city_dir)) {
    dir.create(city_dir, recursive = TRUE, showWarnings = FALSE)
  }
  if (!dir.exists(scenario_dir)) {
    dir.create(scenario_dir, recursive = TRUE, showWarnings = FALSE)
  }
  
  # Generate filename: outcome_statisticType_facetChoice.html
  if (facet_choice == "None") {
    facet_part <- "unfaceted"
  } else {
    facet_part <- paste0("facet_", facet_choice)
  }
  
  filename <- paste0(outcome, "_", statistic_type, "_", facet_part, ".html")
  filepath <- file.path(scenario_dir, filename)
  
  return(filepath)
}

# Mock store object to replace the app's store
create_mock_store <- function() {
  list(
    get_simulation = function(sim_id) {
      list(
        status = "ready",
        settings = sim_id$settings,
        error_message = NULL
      )
    },
    get_current_simulation_data = function(id) {
      list(
        simset = sim_id$simset
      )
    },
    get_original_base_simulation = function(id) {
      NULL # We'll handle this with our direct loading
    }
  )
}

# MAIN FUNCTION: Generate atomic plot matching the app exactly
generate_atomic_plot <- function() {
  tryCatch({
    # Log startup info
    log_to_file("Starting atomic plot generation with extracted app code:", args$debug)
    log_to_file(sprintf("  City: %s", args$city), args$debug)
    log_to_file(sprintf("  Scenario: %s", args$scenario), args$debug)
    log_to_file(sprintf("  Outcome: %s", args$outcome), args$debug)
    log_to_file(sprintf("  Statistic Type: %s", args$statistic_type), args$debug)
    log_to_file(sprintf("  Facet Choice: %s", args$facet_choice), args$debug)
    
    # ----- 1. Create the settings object (mimicking app's control_manager) -----
    current_settings <- list(
      outcomes = args$outcome,
      facet.by = if (args$facet_choice == "None") NULL else args$facet_choice,
      summary.type = args$statistic_type
    )
    
    # ----- 2. Load scenario simulation data -----
    log_to_file("Loading scenario simulation", args$debug)
    if (args$scenario == "base") {
      simset_file <- file.path("simulations/ryan-white/base", paste0(args$city, "_base.Rdata"))
    } else {
      simset_file <- file.path("simulations/ryan-white/prerun", args$city, paste0(args$scenario, ".Rdata"))
    }
    
    if (!file.exists(simset_file)) {
      stop(sprintf("Simulation file not found: %s", simset_file))
    }
    
    log_to_file(sprintf("Loading scenario simulation from: %s", simset_file), args$debug)
    loaded_data <- load(simset_file)
    scenario_simset <- get(loaded_data[1])
    
    # ----- 3. Create mock simulation ID (mimicking app's current_sim_id) -----
    current_sim_id <- list(
      settings = list(
        location = args$city,
        scenario = args$scenario
      ),
      simset = scenario_simset
    )
    
    # ----- 4. Create mock store (mimicking app's store) -----
    store <<- create_mock_store()
    sim_id <<- current_sim_id # Global for mock store to access
    
    # ----- 5. Load baseline simulation using our direct loader -----
    log_to_file("Loading baseline simulation directly", args$debug)
    baseline_simset <- load_baseline_direct(args$city, "prerun")
    
    # If we got a baseline, we need it available for the data preparation
    if (!is.null(baseline_simset)) {
      # Create a mock load_baseline_simulation function that returns our loaded baseline
      load_baseline_simulation <<- function(id, settings) {
        return(baseline_simset)
      }
    }
    
    # ----- 6. Load global config (mimicking app's global PRERUN_CONFIG) -----
    log_to_file("Loading global configuration", args$debug)
    scenario_options_config <- NULL
    tryCatch({
      PRERUN_CONFIG <- get_page_complete_config("prerun")
      scenario_options_config <- PRERUN_CONFIG$selectors$scenario$options
    }, error = function(e) {
      warning(paste("Error loading prerun config:", e$message))
    })
    
    # ----- 7. Call extracted data preparation function -----
    log_to_file("Preparing plot data using extracted logic", args$debug)
    plot_data <- prepare_plot_data(
      current_settings = current_settings,
      current_sim_id = current_sim_id,
      id = "prerun", # Hardcode for prerun mode
      scenario_options_config = scenario_options_config
    )
    
    # Check for data preparation errors
    if (isTRUE(plot_data$error)) {
      stop(sprintf("Data preparation failed: %s", plot_data$error_message))
    }
    
    # ----- 8. Call extracted rendering function -----
    log_to_file("Rendering plot using extracted logic", args$debug)
    render_result <- render_plot(plot_data, current_settings)
    
    # Check for rendering errors
    if (isTRUE(render_result$error)) {
      stop(sprintf("Plot rendering failed: %s", render_result$error_message))
    }
    
    plotly_fig <- render_result$plotly_fig
    
    # ----- 9. Save the plot -----
    output_path <- generate_output_path(
      args$city, 
      args$scenario, 
      args$outcome, 
      args$statistic_type,
      args$facet_choice, 
      args$output_dir
    )
    
    log_to_file(sprintf("Saving plotly object to: %s", output_path), args$debug)
    htmlwidgets::saveWidget(
      plotly_fig, 
      file = output_path, 
      selfcontained = args$selfcontained,
      libdir = if (!args$selfcontained) "lib" else NULL
    )
    
    # ----- 9.5. Save the plot as JSON for API consumption -----
    json_path <- paste0(tools::file_path_sans_ext(output_path), ".json")
    log_to_file(sprintf("Saving plotly JSON to: %s", json_path), args$debug)
    
    # Extract the plotly data and layout
    plotly_json <- list(
      data = plotly_fig$x$data,
      layout = plotly_fig$x$layout
    )
    
    # Save as JSON
    writeLines(toJSON(plotly_json, auto_unbox = TRUE, pretty = TRUE), json_path)
    
    # ----- 10. Save metadata -----
    log_to_file("Generating metadata", args$debug)
    metadata <- list(
      city = args$city,
      scenario = args$scenario,
      outcome = args$outcome,
      statistic_type = args$statistic_type,
      facet_choice = args$facet_choice,
      file_path = output_path,
      has_baseline = !is.null(baseline_simset),
      selfcontained = args$selfcontained,
      generation_time = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    )
    
    # Save metadata
    metadata_path <- paste0(tools::file_path_sans_ext(output_path), "_metadata.json")
    log_to_file(sprintf("Saving metadata to: %s", metadata_path), args$debug)
    writeLines(toJSON(metadata, pretty = TRUE), metadata_path)
    
    log_to_file("Atomic plot generation completed successfully", args$debug)
    return(list(success = TRUE, path = output_path))
    
  }, error = function(e) {
    error_message <- sprintf("Error generating plot: %s", e$message)
    log_to_file(error_message, args$debug)
    return(list(success = FALSE, error = error_message))
  })
}

# Run the plot generation
result <- generate_atomic_plot()

# Return appropriate exit code
if (!result$success) {
  log_to_file("Plot generation failed", args$debug)
  quit(status = 1)
} else {
  log_to_file("Plot generation completed successfully", args$debug)
  quit(status = 0)
}
