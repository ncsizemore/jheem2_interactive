# Simulation Components

## Overview
The simulation components manage loading, processing, and comparison of JHEEM2 simulations. These components provide a consistent interface for both prerun and custom intervention simulations, along with functionality for baseline comparisons.

## Directory Contents

### baseline_loader.R
Handles loading of baseline (no intervention) simulations:
- Loads baseline simulations from configured providers
- Supports both prerun and custom intervention modes
- Configuration-driven behavior for different pages
- Provides consistent access to baseline data for comparisons

## Baseline Comparison Architecture

### Configuration
Baseline comparison is controlled through the visualization configuration:

```yaml
# Baseline simulations configuration
baseline_simulations:
  enabled: true
  # Global settings that apply to both prerun and custom
  default_file_pattern: "base/{location}_base.Rdata"
  default_label: "Baseline (No Intervention)"
  
  # Page-specific settings
  prerun:
    enabled: true
    # Use provider from page config
    use_provider: true
    
  custom:
    enabled: true
    # For custom, we can choose to reuse the base simulation
    reuse_base_simset: true
```

### Loading Approaches
The system uses two different approaches for baseline simulations:

1. **Prerun Mode**: 
   - Loads baseline from a file using the configured provider
   - Uses the `load_baseline_simulation` function in `baseline_loader.R`
   - File pattern determined by configuration

2. **Custom Mode**:
   - Reuses the original base simulation used to create the intervention
   - Retrieves it using the store's `get_original_base_simulation` method
   - Falls back to loading from file if original base not available

### State Storage
For custom interventions, the original base simulation is:
- Stored at the top level of the simulation state
- Preserved during any transformations of the results object
- Maintained independently of the transformed simulation results

### Data Retrieval Flow
When plotting simulations with baselines:

1. Check if baseline comparison is enabled for the page
2. For custom interventions:
   - Try to get the original base simulation from the store
   - This retrieves it from the top level of the simulation state
3. If no original base simulation (or for prerun mode):
   - Load baseline using the provider via `load_baseline_simulation`
4. Create plot with both simulations for comparison

## Key Components

### load_baseline_simulation
Main function for loading baseline simulations from file:
- Uses the configured provider (local or onedrive)
- Derives file path based on settings and configuration
- Supports customizable file patterns
- Returns a JHEEM2 simulation set

```r
# Function signature
load_baseline_simulation <- function(page_id, settings) {
  # Implementation that loads appropriate baseline
  # based on page_id and configuration
}
```

### Baseline Retrieval Method
In the state store:
```r
# Method to get original base simulation
get_original_base_simulation = function(page_id) {
  # Gets the simulation ID for the page
  sim_id <- self$get_current_simulation_id(page_id)
  
  # Gets the full simulation state
  sim_state <- self$get_simulation(sim_id)
  
  # Returns the original_base_simset from top level
  return(sim_state$original_base_simset)
}
```

## Common Usage Patterns

### Loading Baseline for Comparison

```r
# Pattern used in plot_panel.R
baseline_simset <- NULL

# For custom interventions, try to get the original base simulation
if (id == "custom") {
  baseline_simset <- store$get_original_base_simulation(id)
}

# Fallback for when original base simulation isn't available
if (is.null(baseline_simset)) {
  baseline_simset <- load_baseline_simulation(id, sim_settings)
}

# Use both simulations in the plot
if (!is.null(baseline_simset) && !is.null(sim_state$simset)) {
  plot <- simplot(
    baseline_simset, sim_state$simset,
    outcomes = current_settings$outcomes,
    facet.by = current_settings$facet.by,
    summary.type = current_settings$summary.type
  )
}
```

### Storing Original Base Simulation

```r
# In simulation_adapter.R during custom intervention creation:
if (mode == "custom") {
  # Store a copy of the original base simulation for comparison
  original_base_simset <- simset
  
  # Run the intervention on the base simulation
  simset <- runner$run_intervention(intervention, simset)
  
  # Later, when updating the state:
  if (mode == "custom" && exists("original_base_simset")) {
    # Store at top level of simulation state (not in results)
    update_data$original_base_simset <- original_base_simset
  }
}
```

## Important Design Decisions

### Top-Level Storage vs Results Storage
Original base simulations are stored at the top level of the simulation state rather than inside the results object. This is because:

1. The results object undergoes transformation for table display
2. During transformation, fields not recognized by the transform function could be lost
3. By storing at the top level, the original base simulation is preserved regardless of results transformations

### Configuration-Driven Behavior
The baseline comparison feature is fully configurable through the visualization configuration:

- Global enable/disable for all pages
- Page-specific enable/disable
- Customizable file patterns for baseline loading
- Option to reuse original base simulation for custom interventions

This allows the feature to be tuned to specific deployment needs.

### Cascading Retrieval Approach
The plot panel uses a cascading approach to get the baseline:

1. First try to get the original base simulation for custom interventions
2. If that fails, fall back to loading from file
3. Only display the single intervention simulation if no baseline is available

This maximizes availability while maintaining performance.

## Future Improvements

1. **Baseline Toggling**: Add UI control to toggle baseline display
2. **Legend Naming**: Improve legend with more descriptive labels
3. **Multiple Baselines**: Support comparing interventions to multiple baselines
4. **Difference Analysis**: Add ability to show difference between baseline and intervention

## Implementation Notes

1. For custom interventions, the original base simulation should always be available unless:
   - The intervention was created in an earlier version without this feature
   - The simulation was loaded from cache that didn't include the original base
   - There was an error during the original simulation storage

2. For prerun mode, the baseline file must exist on the provider (local or onedrive).

3. Configuration parameters allow flexible setup for different environments and use cases.
